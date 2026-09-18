defmodule ChatsWeb.SessionController do
  use ChatsWeb, :controller

  alias Chats.SessionContext

  def me(conn, _params) do
    {updated_conn, session_data} = SessionContext.get_or_create(conn)

    json(updated_conn, session_data)
  end

  def update(conn, params) do
    {conn, current_session} = SessionContext.get_or_create(conn)

    {updated_conn, _updated_session} =
      SessionContext.update(conn, current_session, params)

    json(updated_conn, %{status: "ok", updated: params})
  end
end
