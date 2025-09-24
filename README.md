# TalkRooms - Real-time Chat Application

Приложение для real-time чата, построенное на Elixir Phoenix (бэкенд) и vanilla JavaScript (фронтенд).

## Архитектура

- **Backend**: Elixir Phoenix с Phoenix Channels для WebSocket соединений
- **Frontend**: Vanilla JavaScript с jQuery
- **Database**: PostgreSQL в Docker контейнере
- **Real-time**: WebSocket через Phoenix Channels

## Требования

Убедитесь, что у вас установлены следующие компоненты:

- [Elixir](https://elixir-lang.org/install.html) (версия 1.15+)
- [Erlang/OTP](https://www.erlang.org/downloads) (версия 26+)
- [Phoenix Framework](https://hexdocs.pm/phoenix/installation.html)
- [Docker](https://docs.docker.com/get-docker/)
- [Node.js](https://nodejs.org/) (для фронтенда)
- [Python 3](https://www.python.org/downloads/) (для статического сервера)

## Установка и запуск

### Быстрый запуск с помощью Makefile

Для быстрого старта используйте команды Makefile:

```bash
# Первоначальная настройка проекта
make setup

# Запуск всех сервисов
make start

# Проверка статуса сервисов
make status

# Остановка всех сервисов
make stop

# Просмотр логов
make logs

# Запуск только бэкенда для разработки
make dev-backend

# Запуск только фронтенда для разработки
make dev-frontend
```

### Ручная установка

#### 1. Клонирование репозитория

```bash
git clone https://github.com/makxtr/rooms.git
cd rooms
```

#### 2. Настройка и запуск бэкенда

```bash
# Переходим в папку бэкенда
cd back

# Устанавливаем зависимости Elixir
mix deps.get

# Запускаем PostgreSQL в Docker
docker run -d --name chats_postgres \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=chats_dev \
  -p 5434:5432 \
  postgres:15

# Ждем запуска базы данных (5-10 секунд)
sleep 10

# Создаем базу данных и запускаем миграции
mix ecto.create
mix ecto.migrate

# Запускаем Phoenix сервер
mix phx.server
```

Бэкенд будет доступен по адресу: `http://localhost:4000`

#### 3. Настройка и запуск фронтенда

Откройте новый терминал:

```bash
# Переходим в папку front
cd front

# Запускаем статический HTTP сервер на Python
python3 -m http.server 3000
```

Фронтенд будет доступен по адресу: `http://localhost:3000`

## API Endpoints

Бэкенд предоставляет следующие API endpoints:

### Sessions
- `GET /api/sessions/me` - получить данные текущей сессии
- `PATCH /api/sessions/me` - обновить сессию

### Sockets
- `POST /api/sockets` - создать WebSocket соединение
- `GET /api/sockets/:socket_id` - проверить существование сокета

### Rooms
- `GET /api/rooms/:hash` - получить данные комнаты
- `POST /api/rooms` - создать новую комнату
- `POST /api/rooms/:hash/enter` - войти в комнату
- `POST /api/rooms/search` - найти случайную комнату

### Messages
- `GET /api/messages` - получить сообщения
- `POST /api/messages` - отправить новое сообщение

### Roles
- `GET /api/roles/:role_id` - получить данные роли
- `GET /api/roles` - получить список ролей в комнате

## WebSocket

WebSocket сервер доступен по адресу: `ws://localhost:4000/sockets/websocket`

Поддерживаемые каналы:
- `room:*` - каналы для комнат чата

## Разработка

### Структура проекта

```
talkrooms/
├── back/                 # Phoenix backend
│   ├── lib/
│   │   ├── rooms/       # Core application logic
│   │   └── rooms_web/   # Web layer (controllers, channels, etc.)
│   ├── config/          # Configuration files
│   ├── priv/           # Static assets and migrations
│   └── test/           # Tests
└── front/               # Frontend source
    ├── script/         # JavaScript files
    ├── style/          # CSS files
    └── index.html      # Main HTML file
```

### Полезные команды

```bash
# Проверка статуса всех сервисов
curl http://localhost:4000/api/health   # Backend health check
curl http://localhost:3000              # Frontend check

# Проверка WebSocket соединения
curl -I -N -H "Connection: Upgrade" -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: test" \
  http://localhost:4000/sockets/websocket

# Остановка Docker контейнера с PostgreSQL
docker stop rooms_postgres
docker rm rooms_postgres

# Перезапуск Phoenix сервера
# В терминале с запущенным Phoenix нажмите Ctrl+C, затем:
mix phx.server
```

### Отладка

1. **Логи бэкенда**: смотрите в терминале где запущен `mix phx.server`
2. **Логи фронтенда**: откройте Developer Tools в браузере (F12)
3. **База данных**: подключитесь к PostgreSQL на `localhost:5434`

```bash
# Подключение к базе данных
docker exec -it rooms_postgres psql -U postgres -d rooms_dev
```

## Развертывание

Для продакшена необходимо:

1. Настроить переменные окружения для Phoenix
2. Собрать фронтенд с помощью Gulp
3. Настроить реверс-прокси (nginx)
4. Использовать внешнюю базу данных PostgreSQL

## Лицензия

MIT License