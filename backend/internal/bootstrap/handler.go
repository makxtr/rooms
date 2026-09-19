// Package bootstrap assembles the application: it is the only place that
// knows about every bounded context. main and the API tests both build the
// HTTP handler through here, so tests exercise the real wiring.
package bootstrap

import (
	"log/slog"
	"net/http"

	"github.com/makxtr/rooms/backend/internal/apigen"
	"github.com/makxtr/rooms/backend/internal/platform/health"
	"github.com/makxtr/rooms/backend/internal/platform/httpserver"
	"github.com/makxtr/rooms/backend/internal/platform/problem"
)

// apiHandlers satisfies the generated interface by embedding one handler per
// bounded context; their methods are promoted onto this struct.
type apiHandlers struct {
	health.Handler
}

var _ apigen.StrictServerInterface = apiHandlers{}

// NewHandler returns the complete HTTP handler: API routes plus middleware.
func NewHandler(log *slog.Logger) http.Handler {
	mux := http.NewServeMux()

	badRequest := func(w http.ResponseWriter, _ *http.Request, err error) {
		problem.Write(w, http.StatusBadRequest, "validation.failed", err.Error())
	}
	strict := apigen.NewStrictHandlerWithOptions(apiHandlers{}, nil, apigen.StrictHTTPServerOptions{
		RequestErrorHandlerFunc: badRequest,
		// Handlers return domain errors; mapping them to status + code is added
		// here as contexts appear. Anything unmapped is a 500.
		ResponseErrorHandlerFunc: func(w http.ResponseWriter, r *http.Request, err error) {
			if httpserver.ResponseStarted(w) {
				// The handler's own response was already on the wire when writing it
				// failed — in practice a client that went away. There is nothing left
				// to send, and it is not a server fault.
				log.WarnContext(r.Context(), "response write failed", "error", err)
				return
			}
			log.ErrorContext(r.Context(), "unhandled handler error", "error", err)
			problem.Write(w, http.StatusInternalServerError, "internal", "internal server error")
		},
	})
	apigen.HandlerWithOptions(strict, apigen.StdHTTPServerOptions{
		BaseURL:          "/api/v1",
		BaseRouter:       mux,
		ErrorHandlerFunc: badRequest,
	})

	return httpserver.Chain(httpserver.WithProblemFallback(mux),
		httpserver.RequestID,
		httpserver.AccessLog(log),
		httpserver.Recover(log),
	)
}
