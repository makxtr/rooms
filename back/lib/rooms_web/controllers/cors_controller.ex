defmodule RoomsWeb.CorsController do
  use RoomsWeb, :controller

  def options(conn, _params) do
    conn
    |> put_status(200)
    |> json(%{})
  end
end