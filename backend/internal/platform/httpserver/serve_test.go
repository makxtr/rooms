package httpserver_test

import (
	"context"
	"net"
	"net/http"
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
		defer resp.Body.Close()
		got <- result{status: resp.StatusCode}
	}()

	const limit = 5 * time.Second
	select {
	case <-started:
	case <-time.After(limit):
		t.Fatal("handler never started")
	}
	cancel()
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
