package reqid_test

import (
	"context"
	"testing"

	"github.com/makxtr/rooms/backend/internal/platform/reqid"
)

func TestRoundTrip(t *testing.T) {
	ctx := reqid.With(context.Background(), "abc-123")
	if got := reqid.From(ctx); got != "abc-123" {
		t.Errorf("From() = %q, want abc-123", got)
	}
}

func TestFromEmptyContext(t *testing.T) {
	if got := reqid.From(context.Background()); got != "" {
		t.Errorf("From() = %q, want empty", got)
	}
}
