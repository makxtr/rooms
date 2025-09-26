defmodule ChatsWeb.SessionController do
  use ChatsWeb, :controller

  alias Chats.SessionService

  def me(conn, _params) do
    {updated_conn, session_data} = SessionService.get_or_create_session(conn)

    json(updated_conn, session_data)
  end

  def update(conn, params) do
    {conn, current_session} = SessionService.get_or_create_session(conn)

    {updated_conn, _updated_session} =
      SessionService.update_session(conn, current_session, params)

    json(updated_conn, %{status: "ok", updated: params})
  end
end
