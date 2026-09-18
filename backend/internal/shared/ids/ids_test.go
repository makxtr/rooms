package ids_test

import (
	"testing"

	"github.com/makxtr/rooms/backend/internal/shared/ids"
)

const sample = "0191e7a0-7c3a-7b1e-8d2f-3a4b5c6d7e8f"

func TestSessionID(t *testing.T) {
	id, err := ids.ParseSessionID(sample)
	if err != nil {
		t.Fatalf("ParseSessionID: %v", err)
	}
	if got := id.String(); got != sample {
		t.Errorf("String() = %q, want %q", got, sample)
	}
	if id.IsZero() {
		t.Error("parsed id reported as zero")
	}
	if got := id.UUID().String(); got != sample {
		t.Errorf("UUID() = %q, want %q", got, sample)
	}
	if !(ids.SessionID{}).IsZero() {
		t.Error("zero value not reported as zero")
	}
	if _, err := ids.ParseSessionID("nope"); err == nil {
		t.Error("ParseSessionID accepted garbage")
	}
}

func TestRoomID(t *testing.T) {
	id, err := ids.ParseRoomID(sample)
	if err != nil {
		t.Fatalf("ParseRoomID: %v", err)
	}
	if id.String() != sample || id.IsZero() || id.UUID().String() != sample {
		t.Errorf("round trip failed: %v", id)
	}
	if !(ids.RoomID{}).IsZero() {
		t.Error("zero value not reported as zero")
	}
	if _, err := ids.ParseRoomID("nope"); err == nil {
		t.Error("ParseRoomID accepted garbage")
	}
}

func TestMessageID(t *testing.T) {
	id, err := ids.ParseMessageID(sample)
	if err != nil {
		t.Fatalf("ParseMessageID: %v", err)
	}
	if id.String() != sample || id.IsZero() || id.UUID().String() != sample {
		t.Errorf("round trip failed: %v", id)
	}
	if !(ids.MessageID{}).IsZero() {
		t.Error("zero value not reported as zero")
	}
	if _, err := ids.ParseMessageID("nope"); err == nil {
		t.Error("ParseMessageID accepted garbage")
	}
}

func TestIDsAreMapKeys(t *testing.T) {
	a, _ := ids.ParseSessionID(sample)
	b, _ := ids.ParseSessionID(sample)
	set := map[ids.SessionID]struct{}{a: {}}
	if _, ok := set[b]; !ok {
		t.Error("equal ids are different map keys")
	}
}
