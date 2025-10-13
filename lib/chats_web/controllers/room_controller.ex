defmodule ChatsWeb.RoomController do
  use ChatsWeb, :controller

  alias Chats.RoomContext
  alias Chats.SessionContext

  @doc """
  GET /api/rooms/:hash
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
  POST /api/rooms
  """
  def create(conn, params) do
    params_with_creator =
      Map.put(
        params,
        "creator_session_id",
        SessionContext.get_creator_session_id(conn)
      )

    room = RoomContext.create_room(params_with_creator)

    conn
    |> put_status(:created)
    |> json(RoomContext.format_room_response(room))
  end

  @doc """
  POST /api/rooms/:hash/enter
  """
  def enter(conn, %{"hash" => hash} = _params) do
    room =
      RoomContext.find_or_create_room(hash, %{
        "creator_session_id" => SessionContext.get_creator_session_id(conn)
      })

    response =
      RoomContext.enter_room(
        room,
        get_session(conn, :session_data)
      )

    json(conn, response)
  end

  @doc """
  PATCH /api/rooms/:hash
  """
  def update(conn, %{"hash" => hash} = params) do
    case RoomContext.fetch_room_by_hash(hash) do
      {:ok, room} ->
        updated_room = RoomContext.update_room(room, params)

        ChatsWeb.Endpoint.broadcast("room:#{hash}", "room_updated", %{
          topic: updated_room.topic,
          watched: updated_room.watched,
          level: updated_room.level,
          searchable: updated_room.searchable
        })

        json(conn, RoomContext.format_room_response(updated_room))

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Room not found"})
    end
  end

  @doc """
  POST /api/rooms/search
  """
  def search(conn, _params) do
    room =
      case RoomContext.get_random_room() do
        nil ->
          RoomContext.find_or_create_room("general", %{
            "topic" => "Общий чат",
            "creator_session_id" => SessionContext.get_creator_session_id(conn)
          })

        room ->
          room
      end

    json(conn, RoomContext.format_room_response(room))
  end
end
