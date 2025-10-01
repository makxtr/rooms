defmodule ChatsWeb.RoomController do
  use ChatsWeb, :controller

  alias Chats.RoomContext
  alias Chats.SessionContext

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
    params_with_creator =
      Map.put(
        params,
        "creator_session_id",
        SessionContext.get_creator_session_id(conn)
      )

    {:ok, room} = RoomContext.create_room(params_with_creator)

    conn
    |> put_status(:created)
    |> json(RoomContext.format_room_response(room))
  end

  @spec enter(Plug.Conn.t(), map()) :: Plug.Conn.t()
  @doc """
  POST /api/rooms/:hash/enter - войти в комнату
  """
  def enter(conn, %{"hash" => hash} = params) do
    socket_id = Map.get(params, "socket_id")
    attrs = %{"creator_session_id" => SessionContext.get_creator_session_id(conn)}

    {:ok, room} = RoomContext.find_or_create_room(hash, attrs)
    session_data = get_session(conn, :session_data)

    response = RoomContext.enter_room(room, session_data, socket_id)

    json(conn, response)
  end

  @doc """
  PATCH /api/rooms/:hash - обновить комнату
  """
  def update(conn, %{"hash" => hash} = params) do
    case RoomContext.fetch_room_by_hash(hash) do
      {:ok, room} ->
        {:ok, updated_room} = RoomContext.update_room(room, params)
        json(conn, RoomContext.format_room_response(updated_room))

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
        {:ok, room} = RoomContext.find_or_create_room("general", %{"topic" => "Общий чат"})
        json(conn, RoomContext.format_room_response(room))

      room ->
        json(conn, RoomContext.format_room_response(room))
    end
  end
end
