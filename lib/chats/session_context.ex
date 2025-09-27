defmodule Chats.SessionContext do
  @moduledoc """
  Business logic for session management
  """
  alias Chats.Session

  @doc """
  Gets existing session from conn or creates a new one
  """
  def get_or_create(conn) do
    case Plug.Conn.get_session(conn, "session_data") do
      nil ->
        session_data = init()
        conn = Plug.Conn.put_session(conn, "session_data", session_data)
        {conn, session_data}

      existing_session ->
        {conn, existing_session}
    end
  end

  def init() do
    Session.init()
  end

  @doc """
  Updates session with new data
  """
  def update(conn, current_session, params) do
    updated_session = update_fields(current_session, params)
    conn = Plug.Conn.put_session(conn, "session_data", updated_session)
    {conn, updated_session}
  end

  @doc """
  Updates only allowed session fields
  """
  def update_fields(session, params) do
    allowed_fields = ["nickname", "ignores", "subscriptions"]

    Enum.reduce(allowed_fields, session, fn field, acc ->
      case Map.get(params, field) do
        nil -> acc
        value -> Map.put(acc, String.to_atom(field), value)
      end
    end)
  end
end
