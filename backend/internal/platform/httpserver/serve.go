package httpserver

import (
	"context"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"time"
)

// Serve handles requests on ln until ctx is cancelled, then shuts down
// gracefully: it stops accepting connections and waits up to shutdownTimeout
// for in-flight requests. It returns nil after a clean shutdown.
//
// Note for M4: http.Server.Shutdown does not wait for hijacked connections,
// so the WebSocket hub is closed separately, after Serve returns.
func Serve(ctx context.Context, ln net.Listener, h http.Handler, shutdownTimeout time.Duration, log *slog.Logger) error {
	srv := &http.Server{
		Handler:           h,
		ReadHeaderTimeout: 10 * time.Second,
	}

	errc := make(chan error, 1)
	go func() { errc <- srv.Serve(ln) }()

	select {
	case err := <-errc:
		return fmt.Errorf("http serve: %w", err)
	case <-ctx.Done():
	}

	log.Info("shutting down http server", "timeout", shutdownTimeout)
	// ctx is already cancelled; the shutdown deadline must not inherit that.
	sctx, cancel := context.WithTimeout(context.WithoutCancel(ctx), shutdownTimeout)
	defer cancel()
	if err := srv.Shutdown(sctx); err != nil {
		return fmt.Errorf("http shutdown: %w", err)
	}
	return nil
}
