// Package httpserver holds transport plumbing shared by every HTTP endpoint:
// middleware and the graceful server loop.
package httpserver

import (
	"errors"
	"log/slog"
	"net/http"
	"runtime/debug"
	"time"

	"github.com/google/uuid"

	"github.com/makxtr/rooms/backend/internal/platform/problem"
	"github.com/makxtr/rooms/backend/internal/platform/reqid"
)

// Chain wraps h so that the first middleware listed is the outermost one.
func Chain(h http.Handler, mws ...func(http.Handler) http.Handler) http.Handler {
	for i := len(mws) - 1; i >= 0; i-- {
		h = mws[i](h)
	}
	return h
}

// RequestID assigns every request a fresh identifier, exposes it in the
// X-Request-ID response header and stores it in the context (package reqid).
// A client-supplied header is ignored: it would let callers forge log
// correlation.
func RequestID(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id := uuid.NewString()
		w.Header().Set("X-Request-ID", id)
		next.ServeHTTP(w, r.WithContext(reqid.With(r.Context(), id)))
	})
}

// statusRecorder remembers the status code. Unwrap lets
// http.ResponseController (and WebSocket upgrades) reach the real writer.
type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (r *statusRecorder) WriteHeader(status int) {
	if r.status == 0 {
		r.status = status
	}
	r.ResponseWriter.WriteHeader(status)
}

func (r *statusRecorder) Write(b []byte) (int, error) {
	if r.status == 0 {
		r.status = http.StatusOK
	}
	return r.ResponseWriter.Write(b)
}

func (r *statusRecorder) Unwrap() http.ResponseWriter { return r.ResponseWriter }

// AccessLog writes one line per request.
func AccessLog(log *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()
			rec := &statusRecorder{ResponseWriter: w}
			next.ServeHTTP(rec, r)
			status := rec.status
			if status == 0 {
				status = http.StatusOK
			}
			log.InfoContext(r.Context(), "http request",
				"method", r.Method,
				"path", r.URL.Path,
				"status", status,
				"duration", time.Since(start),
			)
		})
	}
}

// Recover converts a handler panic into a 500 problem response and logs the
// stack. The panic value never reaches the client.
func Recover(log *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			defer func() {
				rec := recover()
				if rec == nil {
					return
				}
				if err, ok := rec.(error); ok && errors.Is(err, http.ErrAbortHandler) { // sentinel panic value; net/http compares it by identity too
					panic(rec)
				}
				log.ErrorContext(r.Context(), "panic recovered",
					"panic", rec,
					"stack", string(debug.Stack()),
				)
				problem.Write(w, http.StatusInternalServerError, "internal", "internal server error")
			}()
			next.ServeHTTP(w, r)
		})
	}
}
