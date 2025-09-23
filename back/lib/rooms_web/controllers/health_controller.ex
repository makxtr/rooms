defmodule RoomsWeb.HealthController do
  use RoomsWeb, :controller

  def check(conn, _params) do
    json(conn, %{status: "ok", message: "Rooms backend is running"})
  end
end