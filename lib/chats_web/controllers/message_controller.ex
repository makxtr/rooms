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
  POST /api/messages - Create message (legacy, не используется)
  Сообщения отправляются через WebSocket
  """
  def create(conn, _params) do
    conn
    |> put_status(:not_implemented)
    |> json(%{error: "Use WebSocket to send messages"})
  end
end
