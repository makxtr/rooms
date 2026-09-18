package ids_test

import (
	"bytes"
	"encoding/json"
	"log/slog"
	"strings"
	"testing"

	"github.com/makxtr/rooms/backend/internal/shared/ids"
)

const sample = "0191e7a0-7c3a-7b1e-8d2f-3a4b5c6d7e8f"

const wantJSON = `{"id":"0191e7a0-7c3a-7b1e-8d2f-3a4b5c6d7e8f"}`

func TestSessionIDJSON(t *testing.T) {
	id, err := ids.ParseSessionID(sample)
	if err != nil {
		t.Fatalf("ParseSessionID: %v", err)
	}
	type wrapper struct {
		ID ids.SessionID `json:"id"`
	}
	b, err := json.Marshal(wrapper{ID: id})
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}
	if got := string(b); got != wantJSON {
		t.Errorf("Marshal = %q, want %q", got, wantJSON)
	}
	var got wrapper
	if err := json.Unmarshal(b, &got); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}
	if got.ID != id {
		t.Errorf("round trip = %v, want %v", got.ID, id)
	}
	var bad wrapper
	if err := json.Unmarshal([]byte(`{"id":"nope"}`), &bad); err == nil {
		t.Error("Unmarshal accepted garbage")
	}
}

func TestRoomIDJSON(t *testing.T) {
	id, err := ids.ParseRoomID(sample)
	if err != nil {
		t.Fatalf("ParseRoomID: %v", err)
	}
	type wrapper struct {
		ID ids.RoomID `json:"id"`
	}
	b, err := json.Marshal(wrapper{ID: id})
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}
	if got := string(b); got != wantJSON {
		t.Errorf("Marshal = %q, want %q", got, wantJSON)
	}
	var got wrapper
	if err := json.Unmarshal(b, &got); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}
	if got.ID != id {
		t.Errorf("round trip = %v, want %v", got.ID, id)
	}
	var bad wrapper
	if err := json.Unmarshal([]byte(`{"id":"nope"}`), &bad); err == nil {
		t.Error("Unmarshal accepted garbage")
	}
}

func TestMessageIDJSON(t *testing.T) {
	id, err := ids.ParseMessageID(sample)
	if err != nil {
		t.Fatalf("ParseMessageID: %v", err)
	}
	type wrapper struct {
		ID ids.MessageID `json:"id"`
	}
	b, err := json.Marshal(wrapper{ID: id})
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}
	if got := string(b); got != wantJSON {
		t.Errorf("Marshal = %q, want %q", got, wantJSON)
	}
	var got wrapper
	if err := json.Unmarshal(b, &got); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}
	if got.ID != id {
		t.Errorf("round trip = %v, want %v", got.ID, id)
	}
	var bad wrapper
	if err := json.Unmarshal([]byte(`{"id":"nope"}`), &bad); err == nil {
		t.Error("Unmarshal accepted garbage")
	}
}

func TestSessionIDSlog(t *testing.T) {
	id, err := ids.ParseSessionID(sample)
	if err != nil {
		t.Fatalf("ParseSessionID: %v", err)
	}
	var buf bytes.Buffer
	logger := slog.New(slog.NewJSONHandler(&buf, nil))
	logger.Info("test", slog.Any("session_id", id))
	if !strings.Contains(buf.String(), sample) {
		t.Errorf("log output = %q, want it to contain %q", buf.String(), sample)
	}
}

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
