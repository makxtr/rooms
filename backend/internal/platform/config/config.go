// Package config reads process configuration from environment variables.
package config

import (
	"errors"
	"fmt"
	"log/slog"
	"time"
)

type Config struct {
	HTTPAddr        string
	LogLevel        slog.Level
	LogFormat       string // "text" or "json"
	ShutdownTimeout time.Duration
}

// Load builds a Config from getenv (os.Getenv in production, a map in tests).
// It reports every invalid variable at once rather than stopping at the first.
func Load(getenv func(string) string) (Config, error) {
	cfg := Config{
		HTTPAddr:        valueOr(getenv("ROOMS_HTTP_ADDR"), ":8080"),
		LogFormat:       valueOr(getenv("ROOMS_LOG_FORMAT"), "text"),
		ShutdownTimeout: 10 * time.Second,
	}
	var errs []error

	if err := cfg.LogLevel.UnmarshalText([]byte(valueOr(getenv("ROOMS_LOG_LEVEL"), "info"))); err != nil {
		errs = append(errs, fmt.Errorf("ROOMS_LOG_LEVEL: %w", err))
	}
	if cfg.LogFormat != "text" && cfg.LogFormat != "json" {
		errs = append(errs, fmt.Errorf("ROOMS_LOG_FORMAT: %q is not \"text\" or \"json\"", cfg.LogFormat))
	}
	if raw := getenv("ROOMS_SHUTDOWN_TIMEOUT"); raw != "" {
		d, err := time.ParseDuration(raw)
		switch {
		case err != nil:
			errs = append(errs, fmt.Errorf("ROOMS_SHUTDOWN_TIMEOUT: %w", err))
		case d <= 0:
			errs = append(errs, fmt.Errorf("ROOMS_SHUTDOWN_TIMEOUT: %s is not positive", d))
		default:
			cfg.ShutdownTimeout = d
		}
	}

	if err := errors.Join(errs...); err != nil {
		return Config{}, err
	}
	return cfg, nil
}

func valueOr(v, fallback string) string {
	if v == "" {
		return fallback
	}
	return v
}
