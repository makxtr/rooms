// Package health implements the liveness endpoint.
package health

import (
	"context"

	"github.com/makxtr/rooms/backend/internal/apigen"
)

type Handler struct{}

func (Handler) GetHealth(context.Context, apigen.GetHealthRequestObject) (apigen.GetHealthResponseObject, error) {
	return apigen.GetHealth200JSONResponse{Status: "ok"}, nil
}
