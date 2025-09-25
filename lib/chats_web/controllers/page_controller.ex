defmodule ChatsWeb.PageController do
  use ChatsWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
