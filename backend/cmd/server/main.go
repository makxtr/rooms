// Command server runs the Rooms backend.
package main

import (
	"context"
	"fmt"
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

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	ln, err := (&net.ListenConfig{}).Listen(ctx, "tcp", cfg.HTTPAddr)
	if err != nil {
		return fmt.Errorf("listen %s: %w", cfg.HTTPAddr, err)
	}
	log.Info("listening", "addr", ln.Addr().String())

	return httpserver.Serve(ctx, ln, bootstrap.NewHandler(log), cfg.ShutdownTimeout, log)
}
