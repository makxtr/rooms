// Package logging builds the process logger.
package logging

import (
	"context"
	"io"
	"log/slog"

	"github.com/makxtr/rooms/backend/internal/platform/reqid"
)

// New returns a slog.Logger writing to w. format is "json" or anything else for text.
//
// Records logged through the *Context methods get a request_id attribute when
// the context carries one. Callers never add it by hand — and use cases could
// not: they may not import the transport package that assigns it.
func New(w io.Writer, level slog.Level, format string) *slog.Logger {
	opts := &slog.HandlerOptions{Level: level}
	var h slog.Handler
	if format == "json" {
		h = slog.NewJSONHandler(w, opts)
	} else {
		h = slog.NewTextHandler(w, opts)
	}
	return slog.New(contextHandler{h})
}

// contextHandler decorates records with values taken from the context.
type contextHandler struct{ slog.Handler }

func (h contextHandler) Handle(ctx context.Context, rec slog.Record) error {
	if id := reqid.From(ctx); id != "" {
		rec = rec.Clone() // a Record may share attribute storage with its copies
		rec.AddAttrs(slog.String("request_id", id))
	}
	return h.Handler.Handle(ctx, rec)
}

// WithAttrs and WithGroup must re-wrap: the embedded handler would otherwise
// return a bare handler and derived loggers would lose the decoration.
func (h contextHandler) WithAttrs(attrs []slog.Attr) slog.Handler {
	return contextHandler{h.Handler.WithAttrs(attrs)}
}

func (h contextHandler) WithGroup(name string) slog.Handler {
	return contextHandler{h.Handler.WithGroup(name)}
}
