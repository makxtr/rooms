// Package reqid carries the request identifier through a context. It lives
// apart from httpserver so that logging — and anything else below the
// transport — can read the id without importing HTTP plumbing.
package reqid

import "context"

type key struct{}

// With returns a context carrying id.
func With(ctx context.Context, id string) context.Context {
	return context.WithValue(ctx, key{}, id)
}

// From returns the id stored by With, or "".
func From(ctx context.Context) string {
	id, _ := ctx.Value(key{}).(string)
	return id
}
