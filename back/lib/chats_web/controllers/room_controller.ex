defmodule ChatsWeb.RoomController do
  use ChatsWeb, :controller

  alias Chats.RoomContext

  @doc """
  GET /api/rooms/:hash - получить данные комнаты
  """
  def show(conn, %{"hash" => hash}) do
    case RoomContext.fetch_room_by_hash(hash) do
      {:ok, room} ->
        json(conn, %{
          room: RoomContext.format_room_response(room)
        })

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Room not found"})
    end
  end

  @doc """
  POST /api/rooms - создать новую комнату
  """
  def create(conn, params) do
    # Получаем session_id из текущей сессии
    session_data = get_session(conn, "session_data")
    creator_session_id = if session_data, do: session_data[:session_id], else: nil

    # Добавляем creator_session_id в параметры
    params_with_creator = Map.put(params, "creator_session_id", creator_session_id)

    case RoomContext.create_room(params_with_creator) do
      {:ok, room} ->
        conn
        |> put_status(:created)
        |> json(RoomContext.format_room_response(room))  # Возвращаем напрямую для фронта

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_changeset_errors(changeset)})
    end
  end

  @doc """
  POST /api/rooms/:hash/enter - войти в комнату
  """
  def enter(conn, %{"hash" => hash} = params) do
    socket_id = Map.get(params, "socket_id")

    # Получаем session_id для случая создания новой комнаты
    session_data = get_session(conn, "session_data")
    creator_session_id = if session_data, do: session_data[:session_id], else: nil
    attrs = %{"creator_session_id" => creator_session_id}

    case RoomContext.find_or_create_room(hash, attrs) do
      {:ok, room} ->
        # Определяем права пользователя
        session_data = get_session(conn, "session_data")
        current_session_id = if session_data, do: session_data[:session_id], else: nil
        nickname = if session_data, do: session_data[:nickname], else: "Anonymous"

        # Создатель комнаты получает level 80 и права админа
        is_creator = room.creator_session_id == current_session_id
        level = if is_creator, do: 80, else: 0
        is_admin = level >= 70  # Админ (70) или создатель (80)

        json(conn, %{
          room: RoomContext.format_room_response(room),
          subscription: %{subscription_id: "temp_#{room.id}_#{socket_id}"},
          role: %{
            role_id: "temp_role_#{socket_id}",
            nickname: nickname,
            level: level,
            isAdmin: is_admin,
            user_id: session_data[:user_id]
          },
          roles_online: []
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_changeset_errors(changeset)})
    end
  end

  @doc """
  PATCH /api/rooms/:hash - обновить комнату
  """
  def update(conn, %{"hash" => hash} = params) do
    case RoomContext.fetch_room_by_hash(hash) do
      {:ok, room} ->
        case RoomContext.update_room(room, params) do
          {:ok, updated_room} ->
            json(conn, RoomContext.format_room_response(updated_room))

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{errors: format_changeset_errors(changeset)})
        end

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Room not found"})
    end
  end

  @doc """
  POST /api/rooms/search - найти случайную комнату
  """
  def search(conn, _params) do
    case RoomContext.get_random_room() do
      nil ->
        # Если нет комнат, создаем дефолтную
        case RoomContext.find_or_create_room("general", %{"topic" => "Общий чат"}) do
          {:ok, room} ->
            json(conn, RoomContext.format_room_response(room))  # Возвращаем напрямую для фронта

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{errors: format_changeset_errors(changeset)})
        end

      room ->
        json(conn, RoomContext.format_room_response(room))  # Возвращаем напрямую для фронта
    end
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
