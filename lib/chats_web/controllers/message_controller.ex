defmodule ChatsWeb.MessageController do
  use ChatsWeb, :controller
  alias Chats.MessageContext

  @doc """
  GET /api/messages?room_hash=abc&limit=50
  Load messages from a room
  """
  def index(conn, params) do
    room_hash = Map.get(params, "room_hash")
    limit = Map.get(params, "limit", "50") |> String.to_integer()

    cond do
      is_nil(room_hash) || room_hash == "" ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "room_hash is required"})

      true ->
        # Load messages
        messages = MessageContext.list(room_hash, limit)
        json(conn, messages)
    end
  end

  @doc """
  POST /api/messages
  """
  def create(conn, params) do
    message =
      MessageContext.create(
        room_hash = Map.get(params, "room_hash"),
        Map.get(params, "user_id"),
        Map.get(params, "nickname", "Гость"),
        Map.get(params, "body")
      )

    ChatsWeb.Endpoint.broadcast("room:#{room_hash}", "new_message", message)

    conn
    |> put_status(:created)
    |> json(message)
  end
end
