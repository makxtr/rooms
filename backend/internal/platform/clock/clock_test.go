package clock_test

import (
	"testing"
	"time"

	"github.com/makxtr/rooms/backend/internal/platform/clock"
)

func TestSystemNowIsUTCWithMicrosecondPrecision(t *testing.T) {
	now := clock.System{}.Now()
	if now.Location() != time.UTC {
		t.Errorf("location = %v, want UTC", now.Location())
	}
	if now.Nanosecond()%1000 != 0 {
		t.Errorf("nanoseconds = %d, want a multiple of 1000 (Postgres precision)", now.Nanosecond())
	}
}

func TestFixed(t *testing.T) {
	want := time.Date(2026, 9, 18, 12, 0, 0, 0, time.UTC)
	if got := clock.Fixed(want).Now(); !got.Equal(want) {
		t.Errorf("Now() = %v, want %v", got, want)
	}
}
