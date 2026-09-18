// Package apitest keeps the implementation honest against api/openapi.yaml:
// API tests send requests through Do, which fails the test when the request or
// the response does not match the contract.
package apitest

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/getkin/kin-openapi/openapi3filter"
	"github.com/getkin/kin-openapi/routers/gorillamux"

	"github.com/makxtr/rooms/backend/internal/apigen"
)

// Do serves req with h and validates both directions against the contract.
func Do(t *testing.T, h http.Handler, req *http.Request) *httptest.ResponseRecorder {
	t.Helper()

	doc, err := apigen.GetSpec()
	if err != nil {
		t.Fatalf("load embedded openapi spec: %v", err)
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
