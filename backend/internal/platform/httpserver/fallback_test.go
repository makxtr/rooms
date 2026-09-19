package httpserver_test

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/makxtr/rooms/backend/internal/platform/httpserver"
)

func newFallbackMux() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /items/{id}", func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.WriteString(w, "item "+r.PathValue("id"))
	})
	return httpserver.WithProblemFallback(mux)
}

func problemCode(t *testing.T, rec *httptest.ResponseRecorder) string {
	t.Helper()
	if ct := rec.Header().Get("Content-Type"); ct != "application/problem+json" {
		t.Errorf("Content-Type = %q, want application/problem+json", ct)
	}
	var body struct{ Code string }
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("body is not JSON: %v (%s)", err, rec.Body.String())
	}
	return body.Code
}

// Matched routes must go through the mux itself: only ServeMux.ServeHTTP
// populates path values.
func TestFallbackServesMatchedRoutesWithPathValues(t *testing.T) {
	rec := httptest.NewRecorder()
	newFallbackMux().ServeHTTP(rec, httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/items/42", nil))

	if rec.Code != http.StatusOK || rec.Body.String() != "item 42" {
		t.Errorf("status = %d, body = %q", rec.Code, rec.Body.String())
	}
}

func TestFallbackUnknownPathIsProblem404(t *testing.T) {
	rec := httptest.NewRecorder()
	newFallbackMux().ServeHTTP(rec, httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/nope", nil))

	if rec.Code != http.StatusNotFound {
		t.Errorf("status = %d, want 404", rec.Code)
	}
	if code := problemCode(t, rec); code != "not_found" {
		t.Errorf("code = %q, want not_found", code)
	}
}

func TestFallbackWrongMethodIsProblem405WithAllow(t *testing.T) {
	rec := httptest.NewRecorder()
	newFallbackMux().ServeHTTP(rec, httptest.NewRequestWithContext(t.Context(), http.MethodPost, "/items/42", nil))

	if rec.Code != http.StatusMethodNotAllowed {
		t.Errorf("status = %d, want 405", rec.Code)
	}
	if allow := rec.Header().Get("Allow"); !strings.Contains(allow, http.MethodGet) {
		t.Errorf("Allow = %q, want it to list GET", allow)
	}
	if code := problemCode(t, rec); code != "method_not_allowed" {
		t.Errorf("code = %q, want method_not_allowed", code)
	}
}

// A non-canonical path that still matches nothing after ServeMux cleans it
// (e.g. collapsing the double slash) would otherwise earn a 307 redirect to a
// cleaned-up path that also 404s. We answer directly instead: it saves the
// client a round trip and there is no Location header to prove it.
func TestFallbackUnmatchedNonCanonicalPathIsProblem404(t *testing.T) {
	rec := httptest.NewRecorder()
	newFallbackMux().ServeHTTP(rec, httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/nope//x", nil))

	if rec.Code != http.StatusNotFound {
		t.Errorf("status = %d, want 404", rec.Code)
	}
	if code := problemCode(t, rec); code != "not_found" {
		t.Errorf("code = %q, want not_found", code)
	}
	if loc := rec.Header().Get("Location"); loc != "" {
		t.Errorf("Location = %q, want no redirect", loc)
	}
}

// "OPTIONS *" addresses the server itself, not a resource on it.
// ServeMux.ServeHTTP special-cases this before routing and answers 400 with
// Connection: close; mux.Handler does not implement that special case, so the
// wrapper must leave this request to the mux untouched rather than probing it.
func TestFallbackLeavesAsteriskRequestsToTheMux(t *testing.T) {
	req := httptest.NewRequestWithContext(t.Context(), http.MethodOptions, "*", nil)
	if req.RequestURI != "*" {
		t.Fatalf("RequestURI = %q, want \"*\" (precondition for this test)", req.RequestURI)
	}

	rec := httptest.NewRecorder()
	newFallbackMux().ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("status = %d, want 400", rec.Code)
	}
	if conn := rec.Header().Get("Connection"); conn != "close" {
		t.Errorf("Connection = %q, want close", conn)
	}
}
