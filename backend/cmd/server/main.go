// Command server runs the Rooms backend.
package main

import (
	"context"
	"fmt"
	"log/slog"
	"net"
	"os"
	"os/signal"
	"syscall"

	"github.com/makxtr/rooms/backend/internal/bootstrap"
	"github.com/makxtr/rooms/backend/internal/platform/config"
	"github.com/makxtr/rooms/backend/internal/platform/httpserver"
	"github.com/makxtr/rooms/backend/internal/platform/logging"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "rooms:", err)
		os.Exit(1)
	}
}

func run() error {
	cfg, err := config.Load(os.Getenv)
	if err != nil {
		return fmt.Errorf("config: %w", err)
	}
	log := logging.New(os.Stderr, cfg.LogLevel, cfg.LogFormat)
	slog.SetDefault(log) // libraries that log through the default logger share our format

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	// Once shutdown has begun, give signals back their default behaviour: a
	// second Ctrl-C must kill a drain that is taking too long.
	context.AfterFunc(ctx, stop)

	ln, err := (&net.ListenConfig{}).Listen(ctx, "tcp", cfg.HTTPAddr)
	if err != nil {
		return fmt.Errorf("listen %s: %w", cfg.HTTPAddr, err)
	}
	log.Info("listening", "addr", ln.Addr().String())

	return httpserver.Serve(ctx, ln, bootstrap.NewHandler(log), cfg.ShutdownTimeout, log)
}
