// Package apigen contains the HTTP server interface and models generated from
// api/openapi.yaml. Do not edit api.gen.go; change the contract and run
// `make generate`.
package apigen

//go:generate go tool oapi-codegen -config config.yaml ../../../api/openapi.yaml
