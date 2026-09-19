package httpserver_test

import (
	"bytes"
	"context"
	"errors"
	"log/slog"
	"net"
	"net/http"
	"runtime"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/makxtr/rooms/backend/internal/platform/httpserver"
)

// The request is already being handled when shutdown begins; Serve must let
// it finish and then return nil.
func TestServeFinishesInFlightRequestOnShutdown(t *testing.T) {
	started := make(chan struct{})
	release := make(chan struct{})
	h := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		close(started)
		<-release
		w.WriteHeader(http.StatusNoContent)
	})

	ln, err := (&net.ListenConfig{}).Listen(t.Context(), "tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	ctx, cancel := context.WithCancel(t.Context())
	defer cancel()

	served := make(chan error, 1)
	go func() { served <- httpserver.Serve(ctx, ln, h, 5*time.Second, discardLogger()) }()

	type result struct {
		status int
		err    error
	}
	got := make(chan result, 1)
	go func() {
		req, err := http.NewRequestWithContext(context.Background(), http.MethodGet, "http://"+ln.Addr().String()+"/", nil)
		if err != nil {
			got <- result{err: err}
			return
		}
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			got <- result{err: err}
			return
		}
		defer func() { _ = resp.Body.Close() }()
		got <- result{status: resp.StatusCode}
	}()

	const limit = 5 * time.Second
	select {
	case <-started:
	case <-time.After(limit):
		t.Fatal("handler never started")
	}
	cancel()
	waitUntilListenerCloses(t, ln.Addr().String(), limit)
	close(release)

	select {
	case r := <-got:
		if r.err != nil || r.status != http.StatusNoContent {
			t.Errorf("in-flight request: status=%d err=%v, want 204", r.status, r.err)
		}
	case <-time.After(limit):
		t.Fatal("in-flight request never finished")
	}
	select {
	case err := <-served:
		if err != nil {
			t.Errorf("Serve returned %v, want nil", err)
		}
	case <-time.After(limit):
		t.Fatal("Serve never returned")
	}
}

func TestServeReturnsListenerError(t *testing.T) {
	ln, err := (&net.ListenConfig{}).Listen(t.Context(), "tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	_ = ln.Close() // Serve must fail immediately on a closed listener

	err = httpserver.Serve(t.Context(), ln, http.NotFoundHandler(), time.Second, discardLogger())
	if err == nil {
		t.Fatal("Serve on a closed listener returned nil")
	}
}

// waitUntilListenerCloses returns once new connections are refused, i.e. once
// Shutdown has begun. It polls without sleeping: the listener closes within
// microseconds of cancellation, and Gosched lets the server goroutine run.
func waitUntilListenerCloses(t *testing.T, addr string, limit time.Duration) {
	t.Helper()
	deadline := time.Now().Add(limit)
	for time.Now().Before(deadline) {
		conn, err := (&net.Dialer{}).DialContext(context.Background(), "tcp", addr)
		if err != nil {
			return
		}
		_ = conn.Close()
		runtime.Gosched()
	}
	t.Fatal("listener never closed: shutdown did not start")
}

// When the drain deadline passes, Serve must not return while handlers keep
// running on open connections: it force-closes them.
func TestServeForceClosesConnectionsWhenDrainDeadlinePasses(t *testing.T) {
	started := make(chan struct{})
	release := make(chan struct{})
	t.Cleanup(func() { close(release) }) // let the handler goroutine end with the test
	h := http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		close(started)
		<-release
	})

	ln, err := (&net.ListenConfig{}).Listen(t.Context(), "tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	ctx, cancel := context.WithCancel(t.Context())
	defer cancel()

	served := make(chan error, 1)
	go func() { served <- httpserver.Serve(ctx, ln, h, 50*time.Millisecond, discardLogger()) }()

	clientErr := make(chan error, 1)
	go func() {
		req, err := http.NewRequestWithContext(context.Background(), http.MethodGet, "http://"+ln.Addr().String()+"/", nil)
		if err != nil {
			clientErr <- err
			return
		}
		resp, err := http.DefaultClient.Do(req)
		if err == nil {
			_ = resp.Body.Close()
		}
		clientErr <- err
	}()

	const limit = 5 * time.Second
	select {
	case <-started:
	case <-time.After(limit):
		t.Fatal("handler never started")
	}
	cancel()

	select {
	case err := <-served:
		if !errors.Is(err, context.DeadlineExceeded) {
			t.Errorf("Serve returned %v, want an error wrapping context.DeadlineExceeded", err)
		}
	case <-time.After(limit):
		t.Fatal("Serve never returned")
	}
	select {
	case err := <-clientErr:
		if err == nil {
			t.Error("client got a response; want its connection force-closed")
		}
	case <-time.After(limit):
		t.Fatal("client connection was left open after Serve returned")
	}
}

// lockedBuffer is a bytes.Buffer safe for concurrent use: the server logs
// net/http's own errors from its own goroutine, independently of the request
// and shutdown goroutines this test also touches.
type lockedBuffer struct {
	mu  sync.Mutex
	buf bytes.Buffer
}

func (b *lockedBuffer) Write(p []byte) (int, error) {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.buf.Write(p)
}

func (b *lockedBuffer) String() string {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.buf.String()
}

// net/http reports its own failures (a handler double-calling WriteHeader, a
// panic reaching the server, an accept error) through http.Server.ErrorLog,
// not through the handler. Serve must route that logger into ours, at error
// level, or these failures are mislabelled as INFO by the std-log bridge and
// lost entirely once ROOMS_LOG_LEVEL=warn.
func TestServeLogsNetHTTPErrorsAtErrorLevel(t *testing.T) {
	var buf lockedBuffer
	log := slog.New(slog.NewJSONHandler(&buf, &slog.HandlerOptions{Level: slog.LevelWarn}))

	h := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.WriteHeader(http.StatusOK) // triggers net/http's "superfluous response.WriteHeader call"
	})

	ln, err := (&net.ListenConfig{}).Listen(t.Context(), "tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	ctx, cancel := context.WithCancel(t.Context())
	defer cancel()

	served := make(chan error, 1)
	go func() { served <- httpserver.Serve(ctx, ln, h, 5*time.Second, log) }()

	const limit = 5 * time.Second
	reqDone := make(chan struct{})
	go func() {
		defer close(reqDone)
		req, err := http.NewRequestWithContext(context.Background(), http.MethodGet, "http://"+ln.Addr().String()+"/", nil)
		if err != nil {
			return
		}
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			return
		}
		_ = resp.Body.Close()
	}()
	select {
	case <-reqDone:
	case <-time.After(limit):
		t.Fatal("request never completed")
	}

	cancel()
	select {
	case err := <-served:
		if err != nil {
			t.Errorf("Serve returned %v, want nil", err)
		}
	case <-time.After(limit):
		t.Fatal("Serve never returned")
	}

	// All of the server's goroutines for this request are done now that Serve
	// has returned, so the buffer is safe to inspect without racing writes.
	got := buf.String()
	if !strings.Contains(got, "superfluous") {
		t.Errorf("log = %s, want it to mention net/http's superfluous WriteHeader warning", got)
	}
	if !strings.Contains(got, `"level":"ERROR"`) {
		t.Errorf("log = %s, want the entry at ERROR level", got)
	}
}
