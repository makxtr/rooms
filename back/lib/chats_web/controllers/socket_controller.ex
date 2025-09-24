defmodule ChatsWeb.SocketController do
  use ChatsWeb, :controller

  def create(conn, _params) do
    # Заглушка для создания WebSocket соединения
    socket_data = %{
      socket_id: "socket_" <> :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower),
      token: "token_" <> :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower),
      status: "created"
    }

    json(conn, socket_data)
  end

  def show(conn, %{"socket_id" => socket_id}) do
    # Заглушка для проверки существования сокета
    json(conn, %{socket_id: socket_id, status: "active"})
  end
end