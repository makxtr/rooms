package httpserver

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"time"
)

// Serve handles requests on ln until ctx is cancelled, then shuts down
// gracefully: it stops accepting connections and waits up to shutdownTimeout
// for in-flight requests; if they do not finish in time it closes their
// connections and returns an error. It returns nil after a clean shutdown.
//
// Note for M4: http.Server.Shutdown does not wait for hijacked connections,
// so the WebSocket hub is closed separately, after Serve returns.
func Serve(ctx context.Context, ln net.Listener, h http.Handler, shutdownTimeout time.Duration, log *slog.Logger) error {
	srv := &http.Server{
		Handler:           h,
		ReadHeaderTimeout: 10 * time.Second,
		// Keep-alive connections that go quiet are reclaimed. ReadTimeout and
		// WriteTimeout stay unset on purpose: they would cut long-lived WebSocket
		// connections (M4); request bodies are bounded per handler instead.
		IdleTimeout: 2 * time.Minute,
		// net/http reports its own failures (a handler double-calling
		// WriteHeader, a panic reaching the server, an accept error) through
		// this logger, not through the handler. Without it they would reach
		// the process logger via the std-log bridge at INFO — mislabelled,
		// and lost once the process runs at warn level.
		ErrorLog: slog.NewLogLogger(log.Handler(), slog.LevelError),
	}

	errc := make(chan error, 1)
	go func() { errc <- srv.Serve(ln) }()

	select {
	case err := <-errc:
		return fmt.Errorf("http serve: %w", err)
	case <-ctx.Done():
	}

	log.InfoContext(ctx, "shutting down http server", "timeout", shutdownTimeout)
	// ctx is already cancelled; the shutdown deadline must not inherit that.
	sctx, cancel := context.WithTimeout(context.WithoutCancel(ctx), shutdownTimeout)
	defer cancel()
	if err := srv.Shutdown(sctx); err != nil {
		// The deadline passed with requests still in flight. Drop their
		// connections rather than leave handlers running behind a Serve that has
		// reported it is done.
		return fmt.Errorf("http shutdown: %w", errors.Join(err, srv.Close()))
	}
	return nil
}
