package httpserver_test

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/makxtr/rooms/backend/internal/platform/httpserver"
	"github.com/makxtr/rooms/backend/internal/platform/reqid"
)

func discardLogger() *slog.Logger { return slog.New(slog.DiscardHandler) }

func TestChainOrder(t *testing.T) {
	var order []string
	mw := func(name string) func(http.Handler) http.Handler {
		return func(next http.Handler) http.Handler {
			return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				order = append(order, name)
				next.ServeHTTP(w, r)
			})
		}
	}
	h := httpserver.Chain(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		order = append(order, "handler")
	}), mw("outer"), mw("inner"))

	h.ServeHTTP(httptest.NewRecorder(), httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/", nil))

	if got := strings.Join(order, ","); got != "outer,inner,handler" {
		t.Errorf("order = %s", got)
	}
}

func TestRequestID(t *testing.T) {
	var seen string
	h := httpserver.RequestID(http.HandlerFunc(func(_ http.ResponseWriter, r *http.Request) {
		seen = reqid.From(r.Context())
	}))
	req := httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/", nil)
	req.Header.Set("X-Request-ID", "client-supplied")
	rec := httptest.NewRecorder()

	h.ServeHTTP(rec, req)

	got := rec.Header().Get("X-Request-ID")
	if got == "" || got != seen {
		t.Errorf("header = %q, context = %q; want equal and non-empty", got, seen)
	}
	if got == "client-supplied" {
		t.Error("client-supplied request id was trusted")
	}
}

func TestRecoverTurnsPanicIntoProblem(t *testing.T) {
	h := httpserver.Recover(discardLogger())(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		panic("boom")
	}))
	rec := httptest.NewRecorder()

	h.ServeHTTP(rec, httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/", nil))

	if rec.Code != http.StatusInternalServerError {
		t.Errorf("status = %d, want 500", rec.Code)
	}
	var body struct{ Code, Detail string }
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("body is not JSON: %v", err)
	}
	if body.Code != "internal" {
		t.Errorf("code = %q, want internal", body.Code)
	}
	if strings.Contains(rec.Body.String(), "boom") {
		t.Error("panic value leaked to the client")
	}
}

func TestAccessLogRecordsStatus(t *testing.T) {
	var buf bytes.Buffer
	log := slog.New(slog.NewJSONHandler(&buf, nil))
	h := httpserver.AccessLog(log)(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusTeapot)
	}))

	h.ServeHTTP(httptest.NewRecorder(), httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/brew", nil))

	var entry map[string]any
	if err := json.Unmarshal(buf.Bytes(), &entry); err != nil {
		t.Fatalf("log line is not JSON: %v (%s)", err, buf.String())
	}
	if entry["status"] != float64(http.StatusTeapot) || entry["path"] != "/brew" || entry["method"] != "GET" {
		t.Errorf("log entry = %v", entry)
	}
}

func TestAccessLogDefaultsTo200(t *testing.T) {
	var buf bytes.Buffer
	log := slog.New(slog.NewJSONHandler(&buf, nil))
	h := httpserver.AccessLog(log)(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte("ok"))
	}))

	h.ServeHTTP(httptest.NewRecorder(), httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/", nil))

	if !strings.Contains(buf.String(), `"status":200`) {
		t.Errorf("log = %s", buf.String())
	}
}

// countingWriter counts WriteHeader calls that reach the underlying writer.
type countingWriter struct {
	http.ResponseWriter
	headerCalls int
}

func (w *countingWriter) WriteHeader(status int) {
	w.headerCalls++
	w.ResponseWriter.WriteHeader(status)
}

// recoveredPanic runs f and returns the value it panicked with, or nil.
func recoveredPanic(f func()) (v any) {
	defer func() { v = recover() }()
	f()
	return nil
}

func TestRecoverRepanicsAbortHandlerWithoutWriting(t *testing.T) {
	h := httpserver.Recover(discardLogger())(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		panic(http.ErrAbortHandler)
	}))
	w := &countingWriter{ResponseWriter: httptest.NewRecorder()}
	req := httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/", nil)

	got := recoveredPanic(func() { h.ServeHTTP(w, req) })

	if err, ok := got.(error); !ok || !errors.Is(err, http.ErrAbortHandler) {
		t.Errorf("panic = %v, want http.ErrAbortHandler to propagate", got)
	}
	if w.headerCalls != 0 {
		t.Errorf("WriteHeader called %d times, want 0", w.headerCalls)
	}
}

// A problem document appended to a half-sent response would corrupt it; the
// only honest signal left is to abort the connection.
func TestRecoverAbortsWhenResponseAlreadyStarted(t *testing.T) {
	inner := httptest.NewRecorder()
	w := &countingWriter{ResponseWriter: inner}
	h := httpserver.AccessLog(discardLogger())(httpserver.Recover(discardLogger())(
		http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
			w.WriteHeader(http.StatusOK)
			_, _ = io.WriteString(w, "partial")
			panic("boom")
		})))
	req := httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/", nil)

	got := recoveredPanic(func() { h.ServeHTTP(w, req) })

	if err, ok := got.(error); !ok || !errors.Is(err, http.ErrAbortHandler) {
		t.Errorf("panic = %v, want http.ErrAbortHandler", got)
	}
	if w.headerCalls != 1 {
		t.Errorf("WriteHeader called %d times, want exactly 1", w.headerCalls)
	}
	if body := inner.Body.String(); body != "partial" {
		t.Errorf("body = %q, want the partial response untouched", body)
	}
}

func TestAccessLogRecordsAbortedRequests(t *testing.T) {
	var buf bytes.Buffer
	log := slog.New(slog.NewJSONHandler(&buf, nil))
	h := httpserver.AccessLog(log)(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		panic(http.ErrAbortHandler)
	}))
	req := httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/gone", nil)

	_ = recoveredPanic(func() { h.ServeHTTP(httptest.NewRecorder(), req) })

	var entry map[string]any
	if err := json.Unmarshal(buf.Bytes(), &entry); err != nil {
		t.Fatalf("no access log line for an aborted request: %v (%s)", err, buf.String())
	}
	if entry["aborted"] != true || entry["path"] != "/gone" {
		t.Errorf("log entry = %v", entry)
	}
}

func TestAccessLogIgnoresInformationalStatus(t *testing.T) {
	var buf bytes.Buffer
	log := slog.New(slog.NewJSONHandler(&buf, nil))
	h := httpserver.AccessLog(log)(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusEarlyHints)
		w.WriteHeader(http.StatusCreated)
	}))

	h.ServeHTTP(httptest.NewRecorder(), httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/", nil))

	if !strings.Contains(buf.String(), `"status":201`) {
		t.Errorf("log = %s, want status 201", buf.String())
	}
}

func TestResponseStarted(t *testing.T) {
	var before, after bool
	h := httpserver.AccessLog(discardLogger())(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		// One more wrapper in between, as later middleware may add.
		wrapped := &countingWriter{ResponseWriter: w}
		before = httpserver.ResponseStarted(unwrapper{wrapped})
		_, _ = io.WriteString(wrapped, "x")
		after = httpserver.ResponseStarted(unwrapper{wrapped})
	}))

	h.ServeHTTP(httptest.NewRecorder(), httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/", nil))

	if before || !after {
		t.Errorf("ResponseStarted before/after write = %v/%v, want false/true", before, after)
	}
	if httpserver.ResponseStarted(httptest.NewRecorder()) {
		t.Error("ResponseStarted is true for a writer no middleware has seen")
	}
}

// unwrapper exposes the wrapped writer the way http.ResponseController expects.
type unwrapper struct{ *countingWriter }

func (u unwrapper) Unwrap() http.ResponseWriter { return u.ResponseWriter }
