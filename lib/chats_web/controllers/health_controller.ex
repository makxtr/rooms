defmodule ChatsWeb.HealthController do
  use ChatsWeb, :controller

  def check(conn, _params) do
    json(conn, %{status: "ok", message: "Chats backend is running"})
  end
end
