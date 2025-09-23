defmodule RoomsWeb.PageController do
  use RoomsWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
