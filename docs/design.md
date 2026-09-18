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
- Realtime: WebSocket-события, presence (кто онлайн и с какой ролью), reconnect.
- Модерация: роли Guest/Member/Moderator/Admin/Owner, назначение ролей, баны на срок,
  приватные комнаты с очередью на вход.
- Обвязка: `slog`, graceful shutdown, rate limit, recover и request-id middleware, линтер,
  тесты с `-race`, testcontainers, Dockerfile, docker-compose, GitHub Actions.

### Не входит в v1

Rust (WASM-ядро разметки или realtime-gateway), приватные сообщения, OAuth, аватарки,
подписки и уведомления, список «мои комнаты», ранги, «стереть сообщения ниже», звуки,
переход к дате, политика хранения сообщений, мульти-инстанс, метрики и трейсинг.

### Фаза 2 (отдельный спек после v1)

Брокер (NATS), transactional outbox, распределённый presence, два инстанса за балансировщиком.

## 3. Архитектура

Модульный монолит, один бинарник, монорепо в текущем репозитории.

```
rooms/
├── api/openapi.yaml            единый контракт: REST + схемы payload-ов WS-событий
├── backend/
│   ├── cmd/server/main.go      composition root, ручная сборка зависимостей
│   └── internal/
│       ├── shared/ids/         shared kernel: только типы SessionID, RoomID, MessageID
│       ├── identity/           сессия, ник, статус, ignore-лист
│       ├── rooms/              комната, роли, баны, очередь на вход
│       ├── conversation/       сообщения
│       ├── realtime/           обобщённый WebSocket-hub, presence
│       └── platform/           конфиг, логгер, http-сервер, пул Postgres, часы, rate limit
├── web/                        React + Vite + TypeScript
├── legacy/                     Elixir-версия как образец до этапа M7
└── docs/
```

Внутри контекстов `identity`, `rooms`, `conversation`:

- `domain/` — агрегаты, value objects, события, ошибки. Импортирует только стандартную
  библиотеку и `shared/ids`. Не генерирует ID и не читает время: и то и другое приходит
  параметрами.
- `app/` — use case-ы и порты (репозитории, `EventPublisher`, `IDGenerator`, `RateLimiter`,
  порты к другим контекстам).
- `adapters/` — `postgres/` (sqlc), `memory/`, `http/`, `realtime/` (см. 3.1).

Для тонкого `identity` слои допускается схлопнуть, если каталоги окажутся пустой церемонией.

**Правила зависимостей** (проверяет `depguard` в CI, конфигурация закладывается в M0):

- зависимости направлены внутрь: `adapters → app → domain`;
- контекст не импортирует `domain/`, `app/` и `adapters/` другого контекста. Исключение —
  адаптер порта к другому контексту (пример: `conversation/adapters/roomaccess` импортирует
  `rooms/app`), и composition root;
- `shared/ids` и `platform` доступны всем; `realtime` доступен только из `adapters/` и `main`;
- `realtime` не импортирует ни один контекст.

**Идентичность в use case-ах.** Middleware загружает сессию и кладёт в `context`
`Principal{ID, Nickname, CreatedAt}`. Из `context` его читает только HTTP/WS-адаптер и
передаёт в use case явным аргументом.

**Контракт API — OpenAPI-first**, версия схемы `3.0.3`. Из `api/openapi.yaml` генерируются:
strict-сервер для Go (`oapi-codegen`, стандартный `net/http`, `skip-prune: true`, чтобы
схемы без ссылок из путей не вырезались) и типы + клиент для TS (`openapi-typescript`,
`openapi-fetch`). CI проверяет отсутствие дрейфа: `make generate && git diff --exit-code`.

### 3.1 Публикация событий

Каждый контекст объявляет в своём `app/` собственный порт `EventPublisher` со своими типами
событий. Реализация — в `adapters/realtime/` того же контекста: она переводит доменные
события в обобщённый конверт hub-а.

```
realtime.Envelope{Audience, Type, RoomID, Data}
realtime.Audience: Room(id) | RoomMinRole(id, role) | Session(id)
```

Hub ничего не знает о домене: он доставляет конверты, индексирует соединения по `SessionID`
и по `RoomID`, хранит для каждой подписки `{role, nickname, status}` и выполняет служебные
команды (`Unsubscribe`, `UpdateRole`, `UpdateProfile`), которые ему шлёт тот же адаптер.

**Один инстанс в v1.** Путь события всегда
`use case → доменное событие → EventPublisher → адаптер → hub → сокеты`; HTTP-хендлеры не
пишут в сокеты. Мульти-инстанс в фазе 2 — замена транспорта между адаптером и hub-ами без
изменений в `domain/` и `app/`.

## 4. Доменная модель

Общие правила:

- время передаётся параметром `now time.Time` (UTC, усечено до микросекунд на границе
  `platform`-часов — совпадает с точностью Postgres);
- ID генерируются в use case через порт `IDGenerator` и передаются в конструкторы;
- командные методы агрегата возвращают `([]Event, error)`; ожидаемый бизнес-отказ при
  проверке доступа — значение `Decision`, а не ошибка;
- use case сохраняет агрегат, только если метод вернул события;
- восстановление из БД — через конструкторы `Restore…` без валидации и событий;
- длины считаются в рунах.

### 4.1 Identity

Сущность `Session`:

- `SessionID` — публичный UUID; виден другим пользователям;
- `Nickname` — 1–32 руны после trim; без управляющих символов и категории Unicode `Cf`
  (bidi, zero-width);
- `Status` — необязательный, до 140 рун;
- `RandNickname` — ник сгенерирован автоматически;
- `IgnoreList` — множество `SessionID`, не более 500;
- `CreatedAt`.

Секретный токен сессии — не часть домена (см. 5.1). Ignore-лист хранится на сервере,
фильтрация ленты — на клиенте; модераторы видят всё.

Событие: `SessionProfileChanged`.

### 4.2 Rooms

Агрегат `Room`:

- `RoomID`, `Hash` (ASCII `[A-Za-z0-9_\-+]`, 3–32 символа, чувствителен к регистру),
  `Topic` (1–100 рун);
- `Access`: `Open` | `Private`;
- `ClosedAt` — закрытие необратимо, хэш остаётся занятым;
- `Searchable` — участвует в выборе случайной комнаты;
- `MinSessionAge` — минимальный возраст сессии для входа (0 — выключено);
- `Version` — оптимистичная блокировка;
- `Memberships` — записи `{SessionID, Role, BannedUntil}`;
- `JoinRequests` — отдельная коллекция `{SessionID, RequestedAt}`, не более 100.

Роли: `Guest`=0, `Member`=10, `Moderator`=50, `Admin`=70, `Owner`=80.

`Memberships` разреженные: запись существует только при роли выше `Guest` или действующем
бане. Мутирующие методы отбрасывают записи с ролью `Guest` и истёкшим баном.

`NewRoom(id, hash, creator, now)`: `Topic` = `#<hash>`, `Access=Open`, `Searchable=true`,
`MinSessionAge=0`, создатель — `Owner`.

**Проверка доступа** — чистый запрос без побочных эффектов:

`Access(session, sessionCreatedAt, now) Decision`, где `Decision{Kind, Role, Until}`.
Порядок проверок: `Closed` → `Banned(until)` → `SessionTooYoung(until)` →
`ApprovalRequired` → `Allowed(role)`. Роли `Member` и выше проходят проверки возраста и
приватности без ограничений. `Allowed` даёт право читать и писать.

**Эффективная роль.** У актора с действующим баном прав нет: любая команда возвращает
`ErrBanned`. В закрытой комнате любая команда возвращает `ErrRoomClosed`.

| Команда | Кто | Инварианты |
|---|---|---|
| `RequestJoin(session, now)` | `Decision` = `ApprovalRequired` | Идемпотентна: повторная заявка не создаёт события; очередь полна → `ErrQueueFull` |
| `ChangeSettings(actor, …)` | ≥ Admin | Валидные `Topic`, `Access`, `MinSessionAge` ≥ 0. Переход в `Private` не выгоняет уже вошедших (см. 5.4) |
| `SetRole(actor, target, role)` | ≥ Admin | Новая роль и текущая роль цели строго ниже роли актора; не себе; `Owner` не назначается |
| `Ban(actor, target, until, now)` | ≥ Moderator | Роль цели строго ниже роли актора; `until > now`; не себя; цель удаляется из `JoinRequests` |
| `Unban(actor, target)` | ≥ Moderator | Цель забанена; не себя |
| `ApproveJoin` / `RejectJoin(actor, target)` | ≥ Moderator | Цель в очереди; при одобрении — роль `Member` |
| `Close(actor, now)` | Owner | Один раз |

`RoleOf(session, now)` — эффективная роль; используется другими контекстами.

`SetRole`, `Ban` принимают произвольный `SessionID`: внешних ключей между контекстами нет,
существование сессии не проверяется (действие над несуществующей сессией безвредно).

Повторная заявка после `RejectJoin` разрешена; злоупотребление лечится баном.

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
- `Body` — 1–2000 рун, нормализация переводов строк и пробелов по краям;
- `CreatedAt`, `EditedAt`, `DeletedAt`, `DeletedBy`.

Поведение: `Post(id, room, author, nickname, body, now)`; `Edit(actor, body, now)` — только
автор, только неудалённое; `Delete(actor, canModerate, now)` — автор или модератор, мягкое
удаление. Удалённое сообщение отдаётся наружу как tombstone: без тела и ника.

Порт `RoomAccess` (объявлен в `conversation/app`, адаптер вызывает `rooms/app`):

- `Check(ctx, roomRef, principal) (RoomID, Decision, error)` — `roomRef` — хэш или ID;
  разрешает хэш в `RoomID` и возвращает решение одним вызовом;
- `RoleOf(ctx, roomID, sessionID) (Role, error)`.

**Таблица доступа Conversation:**

| Операция | Условие |
|---|---|
| Список сообщений | `Decision` = `Allowed` |
| Отправка | `Decision` = `Allowed`; `RateLimiter.Allow(session)` |
| Редактирование | `Decision` = `Allowed` и актор — автор |
| Удаление своего | `Decision` = `Allowed` и актор — автор |
| Удаление чужого | `Decision` = `Allowed`, роль актора ≥ Moderator и строго выше текущей роли автора |

События: `MessagePosted`, `MessageEdited`, `MessageDeleted`.

Сервер хранит сырой текст и не производит HTML. Разметку (`*em*`, `~~del~~`, ссылки,
`#room`) фронт разбирает в AST и рендерит React-узлами; `innerHTML` не используется.
Автоссылка — только для `http://` и `https://` после проверки через `new URL()`;
`rel="noopener noreferrer"`. Конструктор `Body` — точка расширения для будущего общего ядра
разметки.

### 4.4 Известные ограничения

- Личность равна cookie: забаненный может очистить cookie и вернуться. `MinSessionAge`
  повышает цену обхода; полное решение (логин) — вне v1.
- Владелец, потерявший cookie, теряет комнату: передачи владения нет.
- Курсор UUIDv7 отражает порядок генерации ID, а не коммита; ID монотонны только в пределах
  одного процесса. В v1 это безвредно, потому что после reconnect лента перезагружается
  (см. 5.4); для мульти-инстанса фазы 2 вопрос решается заново.
- Создание сессий ограничено только лимитом по IP; серьёзной защиты от ботов нет.

## 5. API и поток данных

### 5.1 Аутентификация

- Cookie `rooms_sid` содержит секретный токен (32 случайных байта, base64url):
  `HttpOnly`, `SameSite=Lax`, `Path=/`, `Max-Age` 1 год, `Secure` в проде. В БД хранится
  только SHA-256 токена.
- Публичный `SessionID` — отдельный UUID; токен никогда не покидает пару cookie/сервер.
- Сессия создаётся только в `POST /session` (идемпотентно: вернуть существующую или
  создать). Cookie выставляет session-middleware, потому что strict-хендлер не имеет доступа
  к `ResponseWriter`. Создание ограничено token bucket по IP. Остальные эндпоинты без
  валидной cookie отвечают `401`.
- Идентичность из тела запроса не читается.
- CSRF: `http.CrossOriginProtection` (учитывает `Sec-Fetch-Site` и `Origin`; запросы без
  обоих заголовков — небраузерные клиенты и тесты — пропускаются); тело — только
  `application/json`.
- WebSocket аутентифицируется той же cookie на апгрейде; проверка `Origin` — средствами
  `coder/websocket` (`OriginPatterns` из конфига).
- CORS нет: в dev Vite проксирует `/api` и `/ws` без `changeOrigin`; в проде Go раздаёт
  фронт из `embed.FS` с заголовком `Content-Security-Policy`.

### 5.2 REST `/api/v1`

| Ресурс | Эндпоинты |
|---|---|
| Служебное | `GET /health` |
| Сессия | `POST /session`, `PATCH /session`, `PUT /session/ignores/{sid}`, `DELETE /session/ignores/{sid}` |
| Комнаты | `POST /rooms`, `POST /rooms/random`, `POST /rooms/{hash}/enter`, `PATCH /rooms/{hash}`, `POST /rooms/{hash}/close` |
| Участники | `GET /rooms/{hash}/members`, `PUT /rooms/{hash}/members/{sid}/role`, `PUT /rooms/{hash}/members/{sid}/ban`, `DELETE /rooms/{hash}/members/{sid}/ban` |
| Заявки | `POST /rooms/{hash}/join-requests/{sid}/approve`, `POST /rooms/{hash}/join-requests/{sid}/reject` |
| Сообщения | `GET /rooms/{hash}/messages?before=&limit=`, `POST /rooms/{hash}/messages`, `PATCH /messages/{id}`, `DELETE /messages/{id}` |

- `POST /rooms` создаёт комнату со случайным хэшем (8 байт, base64url). `enter` по
  несуществующему хэшу тоже создаёт комнату. В обоих случаях создатель — `Owner`. Создание
  комнат ограничено: 5 за 10 минут на сессию.
- Use case `enter`: загрузить или создать комнату → `Access`; при `ApprovalRequired` —
  `RequestJoin`. Ответ: `200 {room, myRole}` или `403` problem+json с `code`:
  `room.banned` + `until`, `room.approval_required`, `room.session_too_young` + `until`,
  `room.closed`.
- `GET …/members` доступен ролям ≥ Moderator: роли, действующие баны, очередь заявок.
- `POST /rooms/random`: случайная незакрытая комната с `Access=Open`, `Searchable=true`, в
  которой сейчас кто-то онлайн (порт `PresenceTracker`, его реализует `realtime`); если
  таких нет — `404`.
- Пагинация: `limit` 1–100 (по умолчанию 50); `before` — `MessageID`; без курсора —
  последние сообщения; порядок в ответе — по возрастанию ID; tombstone-ы входят в выдачу.
- Ошибки: `application/problem+json` (RFC 7807) с машинным полем `code`
  (`room.insufficient_role`, `room.target_not_lower`, `room.banned`, `room.closed`,
  `message.not_author`, `validation.failed`, `rate_limited` и т.д.). Хендлеры возвращают
  `error`; один маппер на `errors.Is/As` в `ResponseErrorHandlerFunc` превращает его в
  статус + `code`. Общий `components/responses/Problem` подключён как `default`.
- Rate limit отправки: порт `RateLimiter` в use case, token bucket на сессию, 5 сообщений за
  5 секунд; превышение — `429` + `Retry-After`. Неактивные bucket-ы вычищаются.

### 5.3 Путь команды

```
HTTP-запрос
  → middleware: recover, request-id, сессия → Principal, CrossOriginProtection
  → http-адаптер (strict-интерфейс) → use case(ctx, principal, …)
      1. проверки через порты (RoomAccess, RateLimiter)
      2. загрузка агрегата / создание
      3. метод домена → события | ошибка
      4. repo.Save — только если есть события (транзакция; для Room — проверка version)
      5. publisher.Publish(context.WithoutCancel(ctx), события) — после коммита
  ← ответ
```

Конфликт версий `Room` (включая гонку создания по одному хэшу): use case повторяется до
3 раз с перезагрузкой агрегата, затем `409`.

Публикация не зависит от отмены HTTP-запроса; отправка команды hub-у выходит по закрытию
hub-а, чтобы горутина не зависла при остановке.

Компромисс v1: публикация после коммита в памяти процесса; при падении процесса push
теряется, данные — нет, клиенты переподключаются и перезагружают состояние. Outbox — фаза 2.

### 5.4 WebSocket `/ws`

Одно соединение на вкладку, до 5 подписок на соединение. Конверт `{type, room, data}`:
`room` — хэш (hub внутри работает по `RoomID`). В OpenAPI описаны схемы payload-ов и enum
`type`; конверт в Go написан вручную, в TS — mapped type поверх сгенерированных схем.

Клиент → сервер: `subscribe {room}`, `unsubscribe {room}`. При `subscribe` горутина чтения
соединения вызывает use case `rooms` (`Access`); hub-у уходит команда только при `Allowed`,
вместе с `RoomID`, ролью и профилем. Отказ — событие `error` с тем же `code`, что в REST.

**Таблица событий:**

| Доменное событие | WS-тип | Аудитория | Действие hub-а |
|---|---|---|---|
| `MessagePosted/Edited/Deleted` | `message.posted/edited/deleted` | комната | — |
| `RoomSettingsChanged` | `room.settings_changed` | комната | — |
| `RoomClosed` | `room.closed` | комната | отписать всех |
| `RoleChanged` | `member.role_changed` | комната | обновить роль в подписке; в `Private`-комнате при новой роли `Guest` — отписать цель |
| `UserBanned` | `member.banned` | комната + сессия цели | отписать цель |
| `UserUnbanned` | `member.unbanned` | роль ≥ Moderator + сессия цели | — |
| `JoinRequested` | `join.requested` | роль ≥ Moderator | — |
| `JoinApproved/Rejected` | `join.approved/rejected` | роль ≥ Moderator + сессия цели | — |
| `SessionProfileChanged` | `presence.updated` | все комнаты сессии | обновить профиль в подписках |
| — (подписка/отписка) | `presence.state` (подписавшемуся), `presence.joined/left` | комната | — |

Адресные события доставляются по индексу `SessionID` независимо от подписок: сессия,
ждущая одобрения, не подписана на комнату, но `join.approved` получает. Элемент presence:
`{sessionId, nickname, status, role}`.

Переход комнаты в `Private` не отписывает уже вошедших гостей: они остаются до отключения,
новый вход потребует одобрения.

**Reconnect:** backoff на клиенте → повторный `enter` (заново проверяет доступ) →
`subscribe` (приходит свежий `presence.state`) → инвалидация запросов `messages`, `members`
и `room`. Буферов повтора на сервере нет; пропущенные правки, удаления и смены ролей
восстанавливаются перезагрузкой.

### 5.5 Hub и presence

- На соединение — горутина чтения и горутина записи; буферизованный канал отправки.
- Буфер полон → соединение закрывается; hub никогда не блокируется на клиенте.
- Живучесть: тикер с `conn.Ping(ctx)`, таймаут на каждую запись; соединение без ответа
  закрывается, пользователь уходит из presence.
- Состоянием владеет одна горутина-цикл; все операции — команды по каналу; мьютексов нет.
  В цикле нет ввода-вывода: проверки доступа выполняются до отправки команды.
- Presence выводится из подписок: сессия в комнате, пока подписана хотя бы одна её вкладка
  (счётчик соединений на пару сессия+комната).
- `PresenceTracker{OnlineRooms(ctx) []RoomID}` — порт в `rooms/app`, потребитель —
  `POST /rooms/random`.
- Graceful shutdown по порядку: прекратить приём → `http.Server.Shutdown` (не закрывает
  перехваченные соединения) → закрыть hub: соединения с кодом «going away», ожидание
  горутин с таймаутом.

## 6. Хранилище

```
sessions            id uuid PK, token_hash bytea UNIQUE, nickname, status NULL,
                    rand_nickname bool, created_at
session_ignores     (session_id, ignored_session_id) PK
rooms               id uuid PK, hash text UNIQUE, topic, access smallint, searchable bool,
                    min_session_age_sec int, version int, created_at, closed_at NULL
room_memberships    (room_id, session_id) PK, role smallint, banned_until NULL
room_join_requests  (room_id, session_id) PK, requested_at
messages            id uuid PK, room_id, author_session_id, author_nickname, body,
                    created_at, edited_at NULL, deleted_at NULL, deleted_by NULL
                    INDEX (room_id, id DESC)
```

Внешние ключи — только внутри контекста (`room_memberships`, `room_join_requests` →
`rooms`; `session_ignores.session_id` → `sessions`); между контекстами их нет.

- Порты: `SessionRepository`; `RoomRepository{GetByHash, GetByID, Save, ListSearchable}`;
  `MessageRepository{Get, Save, List}`.
- Postgres-адаптер: SQL в `.sql`-файлах → `sqlc` поверх `pgx/v5`; в `sqlc.yaml` — overrides
  `uuid → google/uuid.UUID`, `timestamptz → time.Time`, `emit_pointers_for_null_types`;
  мапперы строк в домен.
- Сохранение `Room` — одна транзакция:
  - новая комната (`Version=0`) → `INSERT`; нарушение `UNIQUE(hash)` → `ErrConflict`
    (повтор use case-а загрузит уже существующую комнату, и сессия войдёт гостем);
  - существующая → первым оператором `UPDATE … SET version=version+1 WHERE id=$1 AND
    version=$2`; 0 строк → `ErrConflict`;
  - `memberships` и `join_requests` перезаписываются целиком (осознанное упрощение: записи
    разреженные, очередь ограничена).
- Unit of Work нет: каждый use case меняет один агрегат.
- Миграции: `goose`, SQL, встроены в бинарник; команда `server migrate`.
- In-memory адаптеры (`map` + `sync.RWMutex`) копируют агрегат целиком на чтении и записи и
  воспроизводят `ErrConflict` — для тестов и запуска `server --storage=memory` без Docker.

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
- Лента: upsert по `MessageID` с сортировкой по ID, а не дописывание в конец — автор
  получает своё сообщение дважды (ответ `POST` и WS-push), а порядок push-ей не гарантирован.
- Жизненный цикл комнаты: hash → `enter` → `200`: подписка + загрузка ленты; `403`:
  `RoomGate` по `code`.
- Холл: создать комнату, случайная комната, «недавние комнаты» из `localStorage`.
- Форма ответа: очередь отправки, учёт `429` и `Retry-After`.
- Роуты: `#` — холл, `#<hash>` — комната.

## 8. Тестирование

| Уровень | Что | Как |
|---|---|---|
| Домен | Инварианты, value objects, матрица прав «актор × цель × действие», включая забаненного актора и закрытую комнату | Табличные юнит-тесты, без моков |
| Use case-ы | Сценарии, таблица доступа Conversation, конфликт версий, публикация событий | In-memory репозитории, записывающий fake-publisher, фиксированные часы и ID; fake-и вручную |
| Контракт репозиториев | memory и Postgres ведут себя одинаково, включая гонку создания по хэшу, `ErrConflict` и изоляцию копий | Общий набор `repotest.Run…(t, factory)`; Postgres — `testcontainers-go`, build-тег `integration` (добавлен в build-tags линтера) |
| HTTP API | Коды, problem+json, аутентификация, CSRF, rate limit | `httptest` + приложение на in-memory адаптерах; ответы валидируются по OpenAPI (`kin-openapi`) |
| Realtime | Подписки, аудитории, принудительная отписка, медленный клиент, ping-таймаут, presence с двумя вкладками | Юнит-тесты hub-а с fake-соединениями, `-race`, `testing/synctest` вместо `sleep`, `goleak`, стресс-тест; один сквозной тест с двумя WS-клиентами |
| Фронт | Парсер разметки (XSS-кейсы, `javascript:`-ссылки), upsert ленты, reconnect | `vitest`; один Playwright smoke в M7 |

CI (GitHub Actions): `golangci-lint` v2 (с `depguard`), `go test -race ./...`,
интеграционная job, проверка дрейфа кодогенерации, фронт — typecheck + `vitest` + build.

Инструменты: актуальный стабильный Go (не ниже 1.25), `net/http`, `oapi-codegen`,
`github.com/coder/websocket`, `pgx/v5`, `sqlc`, `goose`, `slog`, `google/uuid`,
`go.uber.org/goleak`. `Makefile`: `generate`, `test`, `test-integration`, `lint`, `run`, `dev`.

## 9. Этапы

| Этап | Содержание | Результат |
|---|---|---|
| M0 Каркас | Тег `legacy-elixir`, перенос Elixir в `legacy/`; монорепо, `Makefile`, `openapi.yaml` v0 (3.0.3), кодогенерация, `shared/ids`, `platform/`, правила `depguard`, docker-compose, CI, скелет `web/` | `make dev` работает, `/health` отвечает, CI зелёный |
| M1 Identity | `Session`, use case-ы, ignore-лист, cookie/токен-middleware, `Principal`, репозитории, контрактный набор | Сессия, смена ника |
| M2 Rooms (ядро) | Создание (включая гонку по хэшу), `Access`/`enter`, настройки (без `Access=Private` — он в M6), `MinSessionAge`, закрытие, оптимистичная блокировка | Комнаты через API |
| M3 Conversation | `Message`, пагинация, tombstone-ы, `RoomAccess`, таблица доступа, rate limit | Чат через REST |
| M4 Realtime | Hub (индексы по комнате и сессии, аудитории, роль в подписке), presence, ping, адаптеры публикации, WS-протокол, `PresenceTracker` + случайная комната, стресс-тест | Бэкенд — полноценный чат |
| M5 Фронт (ядро), параллельно M2–M4 | Холл, комната, лента, профиль, разметка, WS-клиент, reconnect | Чат в браузере |
| M6 Модерация | Роли, баны, приватные комнаты и очередь, удаление чужих сообщений, адресные события и принудительная отписка, панель модерации | Скоуп v1 закрыт |
| M7 Упаковка | README (архитектура, диаграммы, «было → стало»), `embed` фронта + CSP, Dockerfile, Playwright smoke, удаление `legacy/` | Проект готов к показу |
