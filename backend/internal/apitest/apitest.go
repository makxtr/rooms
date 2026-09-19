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
	"github.com/getkin/kin-openapi/routers"
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

// contract is a loaded, validated OpenAPI document ready to check exchanges.
// It is built once per test binary and shared by every Do call: the router
// and the document are only read after construction, so tests must not
// mutate them.
type contract struct {
	router routers.Router
}

func newContract(path string) (*contract, error) {
	doc, err := openapi3.NewLoader().LoadFromFile(path)
	if err != nil {
		return nil, fmt.Errorf("load %s: %w", path, err)
	}
	if err := doc.Validate(context.Background()); err != nil {
		return nil, fmt.Errorf("validate %s: %w", path, err)
	}
	router, err := gorillamux.NewRouter(doc)
	if err != nil {
		return nil, fmt.Errorf("build router for %s: %w", path, err)
	}
	return &contract{router: router}, nil
}

// serve runs req through h and reports the first way the exchange departs
// from the contract. The recorder is nil when the request never reached the
// handler (an unknown route or an invalid request); it is non-nil, for
// diagnostics, when the response itself violated the contract.
func (c *contract) serve(h http.Handler, req *http.Request) (*httptest.ResponseRecorder, error) {
	route, pathParams, err := c.router.FindRoute(req)
	if err != nil {
		return nil, fmt.Errorf("%s %s is not described in openapi.yaml: %w", req.Method, req.URL.Path, err)
	}
	in := &openapi3filter.RequestValidationInput{
		Request:    req,
		PathParams: pathParams,
		Route:      route,
		Options: &openapi3filter.Options{
			// Without this a status the operation does not document passes silently.
			IncludeResponseStatus: true,
			// Whether a session is valid is the handler's job, not the validator's.
			AuthenticationFunc: openapi3filter.NoopAuthenticationFunc,
		},
	}
	if err := openapi3filter.ValidateRequest(req.Context(), in); err != nil {
		return nil, fmt.Errorf("request violates openapi.yaml: %w", err)
	}

	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	out := &openapi3filter.ResponseValidationInput{
		RequestValidationInput: in,
		Status:                 rec.Code,
		Header:                 rec.Header(),
		// ValidateResponse reads Options from this struct, not from
		// RequestValidationInput, so IncludeResponseStatus must be repeated here.
		Options: in.Options,
	}
	out.SetBodyBytes(rec.Body.Bytes())
	if err := openapi3filter.ValidateResponse(req.Context(), out); err != nil {
		return rec, fmt.Errorf("response violates openapi.yaml: %w\nbody: %s", err, rec.Body.String())
	}
	return rec, nil
}

// loadContract loads api/openapi.yaml once per test binary.
var loadContract = sync.OnceValues(func() (*contract, error) {
	path, err := contractPath()
	if err != nil {
		return nil, err
	}
	return newContract(path)
})

// Do serves req with h and fails the test unless both the request and the
// response — status code included — conform to api/openapi.yaml.
func Do(t *testing.T, h http.Handler, req *http.Request) *httptest.ResponseRecorder {
	t.Helper()

	c, err := loadContract()
	if err != nil {
		t.Fatalf("load openapi.yaml: %v", err)
	}
	rec, err := c.serve(h, req)
	if err != nil {
		t.Fatal(err)
	}
	return rec
}
