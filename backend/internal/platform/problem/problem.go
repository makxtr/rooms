// Package problem writes RFC 7807 "application/problem+json" error responses.
// Every API error goes through here, so clients can rely on one shape and on
// the machine-readable Code field.
package problem

import (
	"encoding/json"
	"net/http"
)

type Problem struct {
	Type   string `json:"type"`
	Title  string `json:"title"`
	Status int    `json:"status"`
	Code   string `json:"code"`
	Detail string `json:"detail,omitempty"`
}

// Write sends a problem response. code is the stable machine-readable
// identifier ("room.banned"); detail is for humans and may be empty.
func Write(w http.ResponseWriter, status int, code, detail string) {
	w.Header().Set("Content-Type", "application/problem+json")
	w.WriteHeader(status)
	// The response is already committed; an encoding error here can only
	// mean the client went away, so there is nothing useful to do with it.
	_ = json.NewEncoder(w).Encode(Problem{
		Type:   "about:blank",
		Title:  http.StatusText(status),
		Status: status,
		Code:   code,
		Detail: detail,
	})
}
