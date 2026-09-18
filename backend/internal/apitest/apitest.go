// Package apitest keeps the implementation honest against api/openapi.yaml:
// API tests send requests through Do, which fails the test when the request or
// the response does not match the contract. The contract is loaded from disk
// (not from an embedded copy) so its bytes never depend on the Go toolchain
// that generated api.gen.go.
package apitest

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"sync"
	"testing"

	"github.com/getkin/kin-openapi/openapi3"
	"github.com/getkin/kin-openapi/openapi3filter"
	"github.com/getkin/kin-openapi/routers/gorillamux"
)

// contractPath is api/openapi.yaml, found by walking up from the current
// working directory. Go tests run with the package directory as cwd, and
// packages sit at different depths, so a fixed relative path would not work
// for all of them.
func contractPath() (string, error) {
	dir, err := os.Getwd()
	if err != nil {
		return "", fmt.Errorf("get working directory: %w", err)
	}
	for {
		candidate := filepath.Join(dir, "api", "openapi.yaml")
		if _, err := os.Stat(candidate); err == nil {
			return candidate, nil
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			return "", fmt.Errorf("api/openapi.yaml not found above %s", dir)
		}
		dir = parent
	}
}

// loadSpec loads and validates api/openapi.yaml once per test binary.
var loadSpec = sync.OnceValues(func() (*openapi3.T, error) {
	path, err := contractPath()
	if err != nil {
		return nil, err
	}
	doc, err := openapi3.NewLoader().LoadFromFile(path)
	if err != nil {
		return nil, fmt.Errorf("load %s: %w", path, err)
	}
	if err := doc.Validate(context.Background()); err != nil {
		return nil, fmt.Errorf("validate %s: %w", path, err)
	}
	return doc, nil
})

// Do serves req with h and validates both directions against the contract.
func Do(t *testing.T, h http.Handler, req *http.Request) *httptest.ResponseRecorder {
	t.Helper()

	doc, err := loadSpec()
	if err != nil {
		t.Fatalf("load openapi.yaml: %v", err)
	}
	router, err := gorillamux.NewRouter(doc)
	if err != nil {
		t.Fatalf("build openapi router: %v", err)
	}
	route, pathParams, err := router.FindRoute(req)
	if err != nil {
		t.Fatalf("%s %s is not described in openapi.yaml: %v", req.Method, req.URL.Path, err)
	}

	in := &openapi3filter.RequestValidationInput{Request: req, PathParams: pathParams, Route: route}
	if err := openapi3filter.ValidateRequest(req.Context(), in); err != nil {
		t.Fatalf("request violates openapi.yaml: %v", err)
	}

	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	out := &openapi3filter.ResponseValidationInput{
		RequestValidationInput: in,
		Status:                 rec.Code,
		Header:                 rec.Header(),
	}
	out.SetBodyBytes(rec.Body.Bytes())
	if err := openapi3filter.ValidateResponse(req.Context(), out); err != nil {
		t.Fatalf("response violates openapi.yaml: %v\nbody: %s", err, rec.Body.String())
	}
	return rec
}
