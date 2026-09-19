package bootstrap_test

import (
	"bytes"
	"encoding/json"
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
