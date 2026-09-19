package logging_test

import (
	"bytes"
	"context"
	"encoding/json"
	"log/slog"
	"strings"
	"testing"

	"github.com/makxtr/rooms/backend/internal/platform/logging"
	"github.com/makxtr/rooms/backend/internal/platform/reqid"
)

func lastJSONLine(t *testing.T, buf *bytes.Buffer) map[string]any {
	t.Helper()
	var entry map[string]any
	if err := json.Unmarshal(buf.Bytes(), &entry); err != nil {
		t.Fatalf("log line is not JSON: %v (%s)", err, buf.String())
	}
	return entry
}

func TestRequestIDIsAddedFromContext(t *testing.T) {
	var buf bytes.Buffer
	log := logging.New(&buf, slog.LevelInfo, "json")

	log.InfoContext(reqid.With(context.Background(), "abc-123"), "hello")

	if got := lastJSONLine(t, &buf)["request_id"]; got != "abc-123" {
		t.Errorf("request_id = %v, want abc-123", got)
	}
}

func TestNoRequestIDWithoutOne(t *testing.T) {
	var buf bytes.Buffer
	log := logging.New(&buf, slog.LevelInfo, "json")

	log.InfoContext(context.Background(), "hello")

	if _, ok := lastJSONLine(t, &buf)["request_id"]; ok {
		t.Error("request_id present although the context carries none")
	}
}

// A derived logger must keep the behaviour: With() goes through WithAttrs,
// which would silently drop the wrapper if it were not re-applied.
func TestDerivedLoggerKeepsRequestID(t *testing.T) {
	var buf bytes.Buffer
	log := logging.New(&buf, slog.LevelInfo, "json").With("component", "test")

	log.InfoContext(reqid.With(context.Background(), "abc-123"), "hello")

	entry := lastJSONLine(t, &buf)
	if entry["request_id"] != "abc-123" || entry["component"] != "test" {
		t.Errorf("entry = %v", entry)
	}
}

func TestTextFormat(t *testing.T) {
	var buf bytes.Buffer
	log := logging.New(&buf, slog.LevelInfo, "text")

	log.InfoContext(reqid.With(context.Background(), "abc-123"), "hello")

	if !strings.Contains(buf.String(), "request_id=abc-123") {
		t.Errorf("log = %s", buf.String())
	}
}

func TestLevelFilter(t *testing.T) {
	var buf bytes.Buffer
	log := logging.New(&buf, slog.LevelInfo, "json")

	log.DebugContext(context.Background(), "hidden")

	if buf.Len() != 0 {
		t.Errorf("debug record written at info level: %s", buf.String())
	}
}
