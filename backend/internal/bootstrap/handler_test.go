package bootstrap_test

import (
	"bytes"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/makxtr/rooms/backend/internal/apitest"
	"github.com/makxtr/rooms/backend/internal/bootstrap"
	"github.com/makxtr/rooms/backend/internal/platform/logging"
)

func newHandler() http.Handler { return bootstrap.NewHandler(slog.New(slog.DiscardHandler)) }

func TestHealth(t *testing.T) {
	req := httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/api/v1/health", nil)

	rec := apitest.Do(t, newHandler(), req) // also validates the response against openapi.yaml

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
	var body struct{ Status string }
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("body is not JSON: %v", err)
	}
	if body.Status != "ok" {
		t.Errorf("status = %q, want ok", body.Status)
	}
	if rec.Header().Get("X-Request-ID") == "" {
		t.Error("X-Request-ID is missing: middleware chain is not applied")
	}
}

func TestAccessLogCarriesTheResponseRequestID(t *testing.T) {
	var buf bytes.Buffer
	h := bootstrap.NewHandler(logging.New(&buf, slog.LevelInfo, "json"))
	rec := httptest.NewRecorder()

	h.ServeHTTP(rec, httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/api/v1/health", nil))

	id := rec.Header().Get("X-Request-ID")
	if id == "" {
		t.Fatal("X-Request-ID is missing")
	}
	if !strings.Contains(buf.String(), `"request_id":"`+id+`"`) {
		t.Errorf("access log does not carry request id %s: %s", id, buf.String())
	}
}

func TestUnknownAPIPathIsAProblem(t *testing.T) {
	req := httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/api/v1/nope", nil)
	rec := httptest.NewRecorder()

	newHandler().ServeHTTP(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Errorf("status = %d, want 404", rec.Code)
	}
	if ct := rec.Header().Get("Content-Type"); ct != "application/problem+json" {
		t.Errorf("Content-Type = %q", ct)
	}
	var body struct{ Code string }
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("body is not JSON: %v", err)
	}
	if body.Code != "not_found" {
		t.Errorf("code = %q, want not_found", body.Code)
	}
}

func TestWrongMethodIsAProblem405(t *testing.T) {
	rec := httptest.NewRecorder()
	newHandler().ServeHTTP(rec, httptest.NewRequestWithContext(t.Context(), http.MethodPost, "/api/v1/health", nil))

	if rec.Code != http.StatusMethodNotAllowed {
		t.Errorf("status = %d, want 405", rec.Code)
	}
	if allow := rec.Header().Get("Allow"); !strings.Contains(allow, http.MethodGet) {
		t.Errorf("Allow = %q, want it to list GET", allow)
	}
	if ct := rec.Header().Get("Content-Type"); ct != "application/problem+json" {
		t.Errorf("Content-Type = %q", ct)
	}
}

func TestPathsOutsideTheAPIAreProblemsToo(t *testing.T) {
	for _, path := range []string{"/nope", "/api"} {
		rec := httptest.NewRecorder()
		newHandler().ServeHTTP(rec, httptest.NewRequestWithContext(t.Context(), http.MethodGet, path, nil))

		if rec.Code != http.StatusNotFound || rec.Header().Get("Content-Type") != "application/problem+json" {
			t.Errorf("GET %s: status = %d, Content-Type = %q; want 404 problem+json",
				path, rec.Code, rec.Header().Get("Content-Type"))
		}
	}
}

// failingWriter accepts headers and then fails every body write, like a
// connection the client has already closed.
type failingWriter struct {
	header      http.Header
	headerCalls int
	status      int
}

func (w *failingWriter) Header() http.Header { return w.header }
func (w *failingWriter) WriteHeader(status int) {
	w.headerCalls++
	if w.status == 0 {
		w.status = status
	}
}
func (w *failingWriter) Write([]byte) (int, error) { return 0, errors.New("client went away") }

func TestFailedResponseWriteDoesNotStartASecondResponse(t *testing.T) {
	w := &failingWriter{header: make(http.Header)}

	newHandler().ServeHTTP(w, httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/api/v1/health", nil))

	if w.status != http.StatusOK || w.headerCalls != 1 {
		t.Errorf("status = %d, WriteHeader calls = %d; want 200 written exactly once", w.status, w.headerCalls)
	}
}
