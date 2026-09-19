package apitest

import (
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// A contract with no `default` response: the only documented outcome of
// GET /ping is 200 with {"pong": string}.
const pingContract = `
openapi: 3.0.3
info: {title: t, version: "1"}
paths:
  /ping:
    get:
      operationId: ping
      responses:
        "200":
          description: ok
          content:
            application/json:
              schema:
                type: object
                required: [pong]
                properties:
                  pong: {type: string}
`

func writeContract(t *testing.T, body string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "openapi.yaml")
	if err := os.WriteFile(path, []byte(body), 0o600); err != nil {
		t.Fatalf("write contract: %v", err)
	}
	return path
}

func respond(status int, body string) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(status)
		_, _ = io.WriteString(w, body)
	})
}

func TestServe(t *testing.T) {
	c, err := newContract(writeContract(t, pingContract))
	if err != nil {
		t.Fatalf("newContract: %v", err)
	}
	for name, tc := range map[string]struct {
		path    string
		handler http.Handler
		wantErr string // substring; "" means the exchange conforms
	}{
		"conforming response":   {"/ping", respond(http.StatusOK, `{"pong":"x"}`), ""},
		"undocumented status":   {"/ping", respond(http.StatusInternalServerError, `{}`), "status"},
		"body violates schema":  {"/ping", respond(http.StatusOK, `{"pong":1}`), "response violates"},
		"undocumented endpoint": {"/nope", respond(http.StatusOK, `{}`), "not described"},
	} {
		t.Run(name, func(t *testing.T) {
			req := httptest.NewRequestWithContext(t.Context(), http.MethodGet, tc.path, nil)
			_, err := c.serve(tc.handler, req)
			switch {
			case tc.wantErr == "" && err != nil:
				t.Errorf("serve: unexpected error: %v", err)
			case tc.wantErr != "" && err == nil:
				t.Error("serve accepted an exchange that violates the contract")
			case tc.wantErr != "" && !strings.Contains(err.Error(), tc.wantErr):
				t.Errorf("error %q does not mention %q", err, tc.wantErr)
			}
		})
	}
}

func TestNewContractErrors(t *testing.T) {
	if _, err := newContract(filepath.Join(t.TempDir(), "missing.yaml")); err == nil {
		t.Error("newContract accepted a missing file")
	}
	if _, err := newContract(writeContract(t, "openapi: 3.0.3\ninfo: {title: t}\npaths: {}\n")); err == nil {
		t.Error("newContract accepted a contract that fails validation (info.version is required)")
	}
}
