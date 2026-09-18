defmodule ChatsWeb.CorsController do
  use ChatsWeb, :controller

  def options(conn, _params) do
    conn
    |> put_status(200)
    |> json(%{})
  end
end
