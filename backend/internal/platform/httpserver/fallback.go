package httpserver

import (
	"net/http"

	"github.com/makxtr/rooms/backend/internal/platform/problem"
)

// WithProblemFallback serves mux, but answers requests that no pattern matches
// — unknown paths and wrong methods — as problem+json instead of net/http's
// plain-text defaults.
//
// A catch-all pattern cannot do this: it matches every method, so ServeMux
// would never produce a 405 again.
func WithProblemFallback(mux *http.ServeMux) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fallback, pattern := mux.Handler(r)
		if pattern != "" {
			// Serve through the mux itself: only ServeMux.ServeHTTP populates r.PathValue.
			mux.ServeHTTP(w, r)
			return
		}

		// Nothing matched. The mux's own fallback handler knows whether this is a
		// 404 or a 405 and which methods exist; run it against a scratch writer to
		// learn that, then answer in the API's error format.
		probe := &headerProbe{header: make(http.Header)}
		fallback.ServeHTTP(probe, r)

		if probe.status == http.StatusMethodNotAllowed {
			w.Header().Set("Allow", probe.header.Get("Allow"))
			problem.Write(w, http.StatusMethodNotAllowed, "method_not_allowed", "method not allowed for this endpoint")
			return
		}
		problem.Write(w, http.StatusNotFound, "not_found", "no such endpoint")
	})
}

// headerProbe records the status and headers a handler produces and discards the body.
type headerProbe struct {
	header http.Header
	status int
}

func (p *headerProbe) Header() http.Header { return p.header }

func (p *headerProbe) WriteHeader(status int) {
	if p.status == 0 {
		p.status = status
	}
}

func (p *headerProbe) Write(b []byte) (int, error) {
	if p.status == 0 {
		p.status = http.StatusOK
	}
	return len(b), nil
}
