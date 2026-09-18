# Rooms: rewrite на Go + TypeScript — дизайн v1

Дата: 2026-09-18

## 1. Контекст и цель

Rooms — анонимный real-time чат (клон talkrooms). Текущая версия: прототип бэкенда на
Phoenix (ETS вместо БД, ~1000 строк) и legacy-фронтенд на jQuery (~5500 строк).

Проблемы текущей версии, которые rewrite закрывает:

- stored XSS: текст сообщений вставляется в DOM без экранирования;
- нет авторизации: `user_id`/`nickname` принимаются из тела запроса, любой может
  редактировать чужие сообщения и настройки любой комнаты;
- хранилище в памяти: данные теряются при рестарте, ключ сообщения `{room, timestamp}`
  допускает перезапись, выборки — полный скан таблицы;
- фронтенд вызывает API, которого нет (роли, подписки, фильтры истории), пагинация не работает.

**Цель проекта** — портфолио для поиска работы Go-разработчиком: показать идиоматичный Go,
конкурентность, clean architecture и DDD-lite на задаче с настоящей доменной логикой.
Это не прод-продукт; эксплуатационная обвязка берётся в объёме «дёшево и видно».

**Принципы:**

- идиоматичный Go важнее канонов DDD: пакеты по контекстам, маленькие интерфейсы у
  потребителя, никаких Java-style слоёв;
- YAGNI: в v1 только то, что перечислено в скоупе;
- каждый этап заканчивается работающим результатом;

## 2. Скоуп

### Входит в v1

- Анонимная сессия: ник, статус, ignore-лист.
- Комнаты: создание, вход по хэшу (несуществующая комната создаётся, первый вошедший —
  владелец), случайная комната, настройки (тема, доступ, searchable, минимальный возраст
  сессии), закрытие.
- Сообщения: отправка, редактирование своих, удаление (своих — автор, чужих — модератор),
  история с курсорной пагинацией.
- Realtime: WebSocket-события, presence (кто онлайн), reconnect с догрузкой.
- Модерация: роли Guest/Member/Moderator/Admin/Owner, назначение ролей, баны на срок,
  приватные комнаты с очередью на вход.
- Обвязка: `slog`, graceful shutdown, rate limit на отправку сообщений, линтер, тесты с
  `-race`, testcontainers, Dockerfile, docker-compose, GitHub Actions.

### Не входит в v1

Rust (WASM-ядро разметки или realtime-gateway), приватные сообщения, OAuth, аватарки,
подписки и уведомления, ранги, «стереть сообщения ниже», звуки, переход к дате,
политика хранения сообщений, мульти-инстанс.

### Фаза 2 (отдельный спек после v1)

Брокер (NATS), transactional outbox, распределённый presence, два инстанса за балансировщиком.

## 3. Архитектура

Модульный монолит, один бинарник, монорепо в текущем репозитории.

```
rooms/
├── api/openapi.yaml            единый контракт: REST + схемы WS-событий
├── backend/
│   ├── cmd/server/main.go      composition root, ручная сборка зависимостей
│   └── internal/
│       ├── identity/           сессия, ник, статус, ignore-лист
│       ├── rooms/              комната, роли, баны, очередь на вход
│       ├── conversation/       сообщения
│       ├── realtime/           WebSocket-hub, presence
│       └── platform/           конфиг, логгер, http-сервер, пул Postgres, rate limit
├── web/                        React + Vite + TypeScript
├── legacy/                     Elixir-версия как образец до этапа M7
└── docs/
```

Внутри контекстов `identity`, `rooms`, `conversation`:

- `domain/` — агрегаты, value objects, события, ошибки. Импортирует только стандартную
  библиотеку и `google/uuid`.
- `app/` — use case-ы и порты (интерфейсы репозиториев, `EventPublisher`, порты к другим
  контекстам).
- `adapters/` — `postgres/` (sqlc), `memory/`, `http/`.

Для тонкого `identity` слои допускается схлопнуть, если каталоги окажутся пустой церемонией.

**Правила зависимостей:**

- зависимости направлены внутрь: `adapters → app → domain`;
- контекст не импортирует `domain/` и `adapters/` другого контекста; связь — через порт,
  объявленный у потребителя (пример: `conversation/app.RoomAccess`), адаптер порта
  вызывает use case другого контекста;
- доменные события идут через `EventPublisher`; в v1 его реализует `realtime`;
- правила проверяет `depguard` в CI.

**Контракт API — OpenAPI-first.** Из `api/openapi.yaml` генерируются: strict-сервер для Go
(`oapi-codegen`, стандартный `net/http`) и типы + клиент для TS (`openapi-typescript`,
`openapi-fetch`). Схемы WebSocket-событий лежат в `components/schemas` того же файла.
CI проверяет отсутствие дрейфа: `make generate && git diff --exit-code`.

**Один инстанс в v1.** Hub живёт в памяти процесса. Путь события всегда
`use case → доменное событие → EventPublisher → hub → сокеты`; HTTP-хендлеры не пишут в
сокеты, presence читается только через порт `PresenceTracker`. Благодаря этому
мульти-инстанс в фазе 2 — два новых адаптера без изменений в `domain/` и `app/`.

## 4. Доменная модель

Общие правила: время передаётся параметром `now time.Time`; методы агрегата возвращают
события или типизированную ошибку; восстановление из БД — через конструкторы `Restore…`
без валидации и событий.

### 4.1 Identity

Сущность `Session`:

- `SessionID` — публичный UUID; виден другим пользователям;
- `Nickname` — 1–32 символа после trim, без управляющих символов;
- `Status` — необязательный, до 140 символов;
- `RandNickname` — ник сгенерирован автоматически;
- `IgnoreList` — множество `SessionID`;
- `CreatedAt`.

Секретный токен сессии — не часть домена (см. 5.1). Ignore-лист хранится на сервере,
фильтрация ленты — на клиенте; модераторы видят всё.

Событие: `SessionProfileChanged`.

### 4.2 Rooms

Агрегат `Room`:

- `RoomID`, `Hash` (`[\w\-+]`, 3–32 символа), `Topic` (1–100 символов);
- `Access`: `Open` | `Private` | `Closed`;
- `Searchable` — участвует в выборе случайной комнаты;
- `MinSessionAge` — минимальный возраст сессии для входа (0 — выключено);
- `Version` — оптимистичная блокировка;
- `Membership{SessionID, Role, BannedUntil}` — записи внутри агрегата;
- `JoinRequests` — очередь на вход в приватную комнату.

Роли: `Guest`=0, `Member`=10, `Moderator`=50, `Admin`=70, `Owner`=80.

Записи `Membership` разреженные: существуют только для роли выше `Guest`, действующего
бана или заявки. Запись с ролью `Guest` и истёкшим баном отбрасывается при сохранении.

| Метод | Кто | Инварианты |
|---|---|---|
| `Enter(session, sessionCreatedAt, now)` | все | Решение: `Allowed(role)`, `Banned(until)`, `ApprovalRequired` (сессия добавлена в очередь), `SessionTooYoung(until)`, `Closed`. Порядок проверок: закрыта → бан → возраст сессии → приватность. Роли `Member` и выше проходят проверку возраста и приватности без ограничений. |
| `ChangeSettings(actor, …)` | ≥ Admin | Валидные `Topic`, `Access` ∈ {Open, Private}, `MinSessionAge` ≥ 0 |
| `SetRole(actor, target, role)` | ≥ Admin | Новая роль и текущая роль цели строго ниже роли актора; не себе; `Owner` не назначается |
| `Ban(actor, target, until, now)` | ≥ Moderator | Роль цели строго ниже роли актора; `until > now`; не себя |
| `Unban(actor, target)` | ≥ Moderator | Цель забанена |
| `ApproveJoin` / `RejectJoin(actor, target)` | ≥ Moderator | Цель в очереди; при одобрении — роль `Member` |
| `Close(actor)` | Owner | После закрытия любые изменения → `ErrRoomClosed` |

Создание: `NewRoom(hash, creator, now)` — создатель получает `Owner`.

Запросы для других контекстов: `CanPost(session, now)`, `CanModerate(session)`.

События: `RoomCreated`, `RoomSettingsChanged`, `RoleChanged`, `UserBanned`, `UserUnbanned`,
`JoinRequested`, `JoinApproved`, `JoinRejected`, `RoomClosed`.

Бан истекает сам: `BannedUntil` сравнивается с `now`; фоновых задач нет.

Роли находятся внутри `Room`, потому что правило «нельзя действовать на того, кто не ниже
тебя» требует согласованного знания ролей актора и цели в одной транзакции.

### 4.3 Conversation

Агрегат `Message` (отдельный от `Room`):

- `MessageID` — UUIDv7, он же курсор пагинации;
- `RoomID`, `AuthorSessionID`;
- `AuthorNickname` — снимок ника на момент отправки;
- `Body` — 1–2000 символов, нормализация переводов строк и пробелов по краям;
- `CreatedAt`, `EditedAt`, `DeletedAt`, `DeletedBy`.

Поведение: `Post(…)`; `Edit(actor, body, now)` — только автор, только неудалённое;
`Delete(actor, canModerate, now)` — автор или модератор, мягкое удаление. Тело удалённого
сообщения наружу не отдаётся.

Право писать проверяет use case через порт `RoomAccess`, а не агрегат.

События: `MessagePosted`, `MessageEdited`, `MessageDeleted`.

Сервер хранит сырой текст и не производит HTML. Разметку (`*em*`, `~~del~~`, ссылки,
`#room`) фронт разбирает в AST и рендерит React-узлами; `innerHTML` не используется.
Конструктор `Body` — точка расширения для будущего общего ядра разметки.

### 4.4 Известное ограничение

Личность равна cookie: забаненный может очистить cookie и вернуться. `MinSessionAge`
повышает цену обхода; полное решение (логин) — вне v1.

## 5. API и поток данных

### 5.1 Аутентификация

- Cookie `rooms_sid` содержит секретный токен (32 случайных байта, base64url):
  `HttpOnly`, `SameSite=Lax`, `Secure` в проде. В БД хранится только SHA-256 токена.
- Публичный `SessionID` — отдельный UUID; токен никогда не покидает пару cookie/сервер.
- Сессия создаётся при первом `GET /session`.
- Middleware кладёт `SessionID` в `context`; идентичность из тела запроса не читается.
- CSRF: проверка `Origin` на изменяющих запросах; тело — только `application/json`.
- WebSocket аутентифицируется той же cookie на апгрейде, `Origin` проверяется.
- CORS нет: в dev Vite проксирует `/api` и `/ws`; в проде Go раздаёт фронт из `embed.FS`.

### 5.2 REST `/api/v1`

| Ресурс | Эндпоинты |
|---|---|
| Служебное | `GET /health` |
| Сессия | `GET /session`, `PATCH /session`, `PUT /session/ignores/{sid}`, `DELETE /session/ignores/{sid}` |
| Комнаты | `POST /rooms`, `POST /rooms/random`, `POST /rooms/{hash}/enter`, `PATCH /rooms/{hash}`, `POST /rooms/{hash}/close` |
| Участники | `GET /rooms/{hash}/members`, `PUT /rooms/{hash}/members/{sid}/role`, `PUT /rooms/{hash}/members/{sid}/ban`, `DELETE /rooms/{hash}/members/{sid}/ban` |
| Заявки | `POST /rooms/{hash}/join-requests/{sid}/approve`, `POST /rooms/{hash}/join-requests/{sid}/reject` |
| Сообщения | `GET /rooms/{hash}/messages?before=&after=&limit=`, `POST /rooms/{hash}/messages`, `PATCH /messages/{id}`, `DELETE /messages/{id}` |

- `POST /rooms` создаёт комнату со случайным хэшем (8 байт, base64url); `enter` по
  несуществующему хэшу тоже создаёт комнату. В обоих случаях создатель — `Owner`.
- `enter`: `200 {room, myRole}` или `403` с `reason`: `banned` + `until`,
  `approval_required`, `session_too_young` + `until`, `closed`.
- `GET …/members` доступен ролям ≥ Moderator: роли, действующие баны, очередь заявок.
- `POST /rooms/random`: случайная комната с `Access=Open` и `Searchable=true`; если таких
  нет — `404`.
- Пагинация: `limit` 1–100 (по умолчанию 50); `before`/`after` — `MessageID`; без курсора —
  последние сообщения; порядок в ответе — по возрастанию ID.
- Ошибки: `application/problem+json` (RFC 7807) с машинным полем `code`
  (`room.insufficient_role`, `room.target_not_lower`, `room.closed`, `message.not_author`,
  `validation.failed` и т.д.). Один маппер «доменная ошибка → статус + code» в HTTP-адаптере.
- Rate limit отправки: token bucket на сессию, 5 сообщений за 5 секунд; превышение —
  `429` + `Retry-After`.

### 5.3 Путь команды

```
HTTP-запрос
  → middleware: сессия → ctx, Origin, rate limit
  → http-адаптер (strict-интерфейс) → use case
      1. проверки через порты (RoomAccess)
      2. загрузка агрегата / создание
      3. метод домена → события | ошибка
      4. repo.Save (транзакция; для Room — проверка version)
      5. publisher.Publish(события) — после коммита
  ← ответ
```

Конфликт версий `Room`: один повтор use case-а, затем `409`.

Компромисс v1: публикация после коммита в памяти процесса; при падении между коммитом и
публикацией push теряется, данные — нет, клиент восстанавливается догрузкой. Outbox — фаза 2.

### 5.4 WebSocket `/ws`

Одно соединение на вкладку, конверт `{type, room, data}`.

Клиент → сервер: `subscribe {room}` (сервер проверяет право входа через Rooms),
`unsubscribe {room}`.

Сервер → клиент: `message.posted`, `message.edited`, `message.deleted`,
`room.settings_changed`, `room.closed`, `member.role_changed`, `member.banned`,
`member.unbanned`, `join.requested`, `join.approved`, `join.rejected`, `presence.state`
(один раз после подписки), `presence.joined`, `presence.left`, `presence.updated`, `error`.

Аудитории: вся комната; модераторы комнаты (`join.requested`); конкретная сессия
(`join.approved`, `join.rejected`, `member.banned` — с принудительной отпиской). Аудиторию
выбирает realtime-адаптер, домен о ней не знает.

Reconnect: backoff на клиенте, повторный `subscribe`, догрузка
`GET …/messages?after=<последний ID>`. Буферов повтора на сервере нет.

### 5.5 Hub и presence

- На соединение — горутина чтения и горутина записи; буферизованный канал отправки.
- Буфер полон → соединение закрывается; hub никогда не блокируется на клиенте.
- Состоянием владеет одна горутина-цикл; `subscribe/unsubscribe/publish/disconnect` —
  команды по каналу; мьютексов нет.
- Presence выводится из подписок: сессия в комнате, пока подписана хотя бы одна её вкладка
  (счётчик соединений на пару сессия+комната).
- `SessionProfileChanged` → `presence.updated` во всех комнатах сессии.
- Graceful shutdown: прекращение приёма, закрытие соединений с кодом «going away»,
  ожидание завершения горутин с таймаутом.

## 6. Хранилище

```
sessions            id uuid PK, token_hash bytea UNIQUE, nickname, status NULL,
                    rand_nickname bool, created_at, last_seen_at
session_ignores     (session_id, ignored_session_id) PK
rooms               id uuid PK, hash text UNIQUE, topic, access smallint, searchable bool,
                    min_session_age_sec int, version int, created_at, closed_at NULL
room_memberships    (room_id, session_id) PK, role smallint, banned_until NULL
room_join_requests  (room_id, session_id) PK, requested_at
messages            id uuid PK, room_id FK, author_session_id, author_nickname, body,
                    created_at, edited_at NULL, deleted_at NULL, deleted_by NULL
                    INDEX (room_id, id DESC)
```

- Порты: `SessionRepository`, `RoomRepository{GetByHash, Save, RandomSearchable}`,
  `MessageRepository{Get, Save, List}`.
- Postgres-адаптер: SQL в `.sql`-файлах → `sqlc` поверх `pgx/v5`; мапперы строк в домен.
- Сохранение `Room`: одна транзакция; `UPDATE … WHERE id=$1 AND version=$2`, 0 строк →
  `ErrConflict`; `memberships` и `join_requests` перезаписываются целиком (осознанное
  упрощение, записи разреженные).
- Unit of Work нет: каждый use case меняет один агрегат.
- Миграции: `goose`, SQL, встроены в бинарник; команда `server migrate`.
- In-memory адаптеры (`map` + `sync.RWMutex`) — для тестов и запуска
  `server --storage=memory` без Docker.

## 7. Фронтенд

React + Vite + TypeScript; `openapi-fetch`, TanStack Query; без стейт-менеджера, роутер-
библиотеки и UI-кита. CSS переносится из legacy.

```
web/src/
├── api/          сгенерированные типы, клиент, разбор problem+json
├── realtime/     socket (reconnect, subscribe), типы событий, useRoomEvents
├── markup/       parse (текст → AST), render (AST → React-узлы)
├── features/     session, hall, room, talk, moderation
├── app/          App, hash-роутер, queryClient
└── styles/
```

- Состояние — кэш TanStack Query: `['session']`, `['room', hash]`, `['messages', hash]`
  (infinite), `['members', hash]`, `['presence', hash]`. WS-события патчат кэш.
- Жизненный цикл комнаты: hash → `enter` → `200`: подписка + загрузка ленты; `403`:
  `RoomGate` по `reason`.
- Форма ответа: очередь отправки, учёт `429` и `Retry-After`.
- Роуты: `#` — холл, `#<hash>` — комната.

## 8. Тестирование

| Уровень | Что | Как |
|---|---|---|
| Домен | Инварианты, value objects, матрица прав «актор × цель × действие» | Табличные юнит-тесты, без моков |
| Use case-ы | Сценарии, конфликт версий, публикация событий | In-memory репозитории, записывающий fake-publisher, фиксированные часы; fake-и вручную |
| Контракт репозиториев | memory и Postgres ведут себя одинаково | Общий набор `repotest.Run…(t, factory)`; Postgres — `testcontainers-go`, build-тег `integration` |
| HTTP API | Коды, problem+json, аутентификация, rate limit | `httptest` + приложение на in-memory адаптерах; ответы валидируются по OpenAPI (`kin-openapi`) |
| Realtime | Подписки, аудитории, медленный клиент, presence с двумя вкладками | Юнит-тесты hub-а с fake-соединениями, `-race`, стресс-тест; один сквозной тест с двумя WS-клиентами |
| Фронт | Парсер разметки (XSS-кейсы), reconnect | `vitest`; один Playwright smoke в M7 |

CI (GitHub Actions): `golangci-lint` (с `depguard`), `go test -race ./...`, интеграционная
job, проверка дрейфа кодогенерации, фронт — typecheck + `vitest` + build.

Инструменты: Go 1.23+, `net/http`, `oapi-codegen`, `github.com/coder/websocket`, `pgx/v5`,
`sqlc`, `goose`, `slog`, `google/uuid`. `Makefile`: `generate`, `test`, `test-integration`,
`lint`, `run`, `dev`.

## 9. Этапы

| Этап | Содержание | Результат |
|---|---|---|
| M0 Каркас | Тег `legacy-elixir`, перенос Elixir в `legacy/`; монорепо, `Makefile`, `openapi.yaml` v0, кодогенерация, `platform/`, docker-compose, CI, скелет `web/` | `make dev` работает, `/health` отвечает, CI зелёный |
| M1 Identity | `Session`, use case-ы, ignore-лист, cookie/токен-middleware, репозитории, контрактный набор | Сессия, смена ника |
| M2 Rooms (ядро) | Создание, вход, настройки (без `Access=Private` — он в M6), случайная комната, `MinSessionAge`, закрытие, оптимистичная блокировка | Комнаты через API |
| M3 Conversation | `Message`, пагинация, `RoomAccess`, rate limit | Чат через REST |
| M4 Realtime | Hub, presence, публикация событий, WS-протокол, стресс-тест | Бэкенд — полноценный чат |
| M5 Фронт (ядро), параллельно M2–M4 | Холл, комната, лента, профиль, разметка, WS-клиент | Чат в браузере |
| M6 Модерация | Роли, баны, приватные комнаты и очередь, удаление чужих сообщений, адресные события, панель модерации | Скоуп v1 закрыт |
| M7 Упаковка | README (архитектура, диаграммы, «было → стало»), `embed` фронта, Dockerfile, Playwright smoke, удаление `legacy/` | Проект готов к показу |
