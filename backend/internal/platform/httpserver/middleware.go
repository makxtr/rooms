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

// statusRecorder remembers the final status code. Unwrap lets
// http.ResponseController (and WebSocket upgrades) reach the real writer.
type statusRecorder struct {
	http.ResponseWriter
	status int // 0 until the response starts
}

func (r *statusRecorder) WriteHeader(status int) {
	// 1xx responses are informational — more headers follow, so they are not
	// the outcome. 101 is the exception: it is the last status an upgrade sends.
	if r.status == 0 && (status >= 200 || status == http.StatusSwitchingProtocols) {
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

// ResponseStarted reports whether a final status or body bytes have already
// been sent on w. It sees what passed through AccessLog's recorder, looking
// through any wrappers that implement Unwrap. Error paths use it to avoid
// writing a second response on top of a started one.
func ResponseStarted(w http.ResponseWriter) bool {
	for {
		if rec, ok := w.(*statusRecorder); ok {
			return rec.status != 0
		}
		u, ok := w.(interface{ Unwrap() http.ResponseWriter })
		if !ok {
			return false
		}
		w = u.Unwrap()
	}
}

// AccessLog writes one line per request — including requests that end in a
// panic travelling up the stack (http.ErrAbortHandler), which are marked aborted.
func AccessLog(log *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()
			rec := &statusRecorder{ResponseWriter: w}
			completed := false
			defer func() {
				status := rec.status
				if status == 0 && completed {
					status = http.StatusOK // handler returned without writing: net/http sends 200
				}
				attrs := []slog.Attr{
					slog.String("method", r.Method),
					slog.String("path", r.URL.Path),
					slog.Int("status", status),
					slog.Duration("duration", time.Since(start)),
				}
				if !completed {
					attrs = append(attrs, slog.Bool("aborted", true))
				}
				log.LogAttrs(r.Context(), slog.LevelInfo, "http request", attrs...)
			}()
			next.ServeHTTP(rec, r)
			completed = true
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
				if ResponseStarted(w) {
					// Too late for a clean error: a problem document appended to a
					// half-sent response would corrupt it. Abort the connection so the
					// client sees a broken response rather than a seemingly complete one.
					panic(http.ErrAbortHandler)
				}
				problem.Write(w, http.StatusInternalServerError, "internal", "internal server error")
			}()
			next.ServeHTTP(w, r)
		})
	}
}
