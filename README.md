# Rooms

Анонимный real-time чат. Бэкенд — Go (модульный монолит, clean architecture, DDD-lite),
фронтенд — React + TypeScript, контракт — OpenAPI.

Проект переписывается с прототипа на Phoenix. Прежняя версия лежит в `legacy/` и под тегом
`legacy-elixir`. Дизайн: `docs/design.md`.

## Запуск

    make web-install   # один раз
    make dev           # backend :8080 + frontend :5173

## Команды

    make generate      # кодогенерация из api/openapi.yaml (Go + TS)
    make test          # go test -race
    make lint          # golangci-lint
    make web-check     # typecheck + vitest + build
