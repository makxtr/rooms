.PHONY: generate generate-go generate-web test test-integration lint run dev web-install web-check

generate: generate-go generate-web

generate-go:
	cd backend && go generate ./...

generate-web:
	cd web && npm run generate

test:
	cd backend && go test -race ./...

test-integration:
	cd backend && go test -race -tags=integration ./...

lint:
	cd backend && golangci-lint run ./...

run:
	cd backend && go run ./cmd/server

dev:
	@trap 'kill 0' INT TERM EXIT; \
	(cd backend && go run ./cmd/server) & \
	(cd web && npm run dev) & \
	wait

web-install:
	cd web && npm install

web-check:
	cd web && npm run typecheck && npm test && npm run build
