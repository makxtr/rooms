package config_test

import (
	"log/slog"
	"strings"
	"testing"
	"time"

	"github.com/makxtr/rooms/backend/internal/platform/config"
)

func env(m map[string]string) func(string) string {
	return func(k string) string { return m[k] }
}

func TestLoadDefaults(t *testing.T) {
	cfg, err := config.Load(env(nil))
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	want := config.Config{
		HTTPAddr:        ":8080",
		LogLevel:        slog.LevelInfo,
		LogFormat:       "text",
		ShutdownTimeout: 10 * time.Second,
	}
	if cfg != want {
		t.Errorf("Load() = %+v, want %+v", cfg, want)
	}
}

func TestLoadOverrides(t *testing.T) {
	cfg, err := config.Load(env(map[string]string{
		"ROOMS_HTTP_ADDR":        "127.0.0.1:9000",
		"ROOMS_LOG_LEVEL":        "debug",
		"ROOMS_LOG_FORMAT":       "json",
		"ROOMS_SHUTDOWN_TIMEOUT": "3s",
	}))
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	want := config.Config{
		HTTPAddr:        "127.0.0.1:9000",
		LogLevel:        slog.LevelDebug,
		LogFormat:       "json",
		ShutdownTimeout: 3 * time.Second,
	}
	if cfg != want {
		t.Errorf("Load() = %+v, want %+v", cfg, want)
	}
}

func TestLoadReportsEveryInvalidVariable(t *testing.T) {
	_, err := config.Load(env(map[string]string{
		"ROOMS_LOG_LEVEL":        "loud",
		"ROOMS_LOG_FORMAT":       "xml",
		"ROOMS_SHUTDOWN_TIMEOUT": "-1s",
	}))
	if err == nil {
		t.Fatal("Load accepted invalid values")
	}
	for _, name := range []string{"ROOMS_LOG_LEVEL", "ROOMS_LOG_FORMAT", "ROOMS_SHUTDOWN_TIMEOUT"} {
		if !strings.Contains(err.Error(), name) {
			t.Errorf("error %q does not mention %s", err, name)
		}
	}
}
