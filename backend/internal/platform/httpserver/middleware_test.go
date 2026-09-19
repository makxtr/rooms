package httpserver_test

import (
	"bytes"
	"encoding/json"
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
