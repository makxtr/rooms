defmodule Chats.SessionService do
  @moduledoc """
  Business logic for session management
  """

  alias Chats.Utils

  @doc """
  Gets existing session from conn or creates a new one
  """
  def get_or_create_session(conn) do
    case Plug.Conn.get_session(conn, "session_data") do
      nil ->
        session_data = create_initial_session()
        conn = Plug.Conn.put_session(conn, "session_data", session_data)
        {conn, session_data}

      existing_session ->
        {conn, existing_session}
    end
  end

  @doc """
  Updates session with new data
  """
  def update_session(conn, current_session, params) do
    updated_session = update_session_fields(current_session, params)
    conn = Plug.Conn.put_session(conn, "session_data", updated_session)
    {conn, updated_session}
  end

  @doc """
  Creates initial session with default values
  """
  def create_initial_session do
    %{
      session_id: Utils.gen_session_hash(),
      user_id: nil,
      provider_id: nil,
      rand_nickname: true,
      nickname: Utils.gen_random_nickname(),
      # [user_ignores, session_ignores]
      ignores: [%{}, %{}],
      subscriptions: [],
      rooms: [],
      recent_rooms: [],
      created_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  @doc """
  Updates only allowed session fields
  """
  def update_session_fields(session, params) do
    allowed_fields = ["nickname", "ignores", "subscriptions"]

    Enum.reduce(allowed_fields, session, fn field, acc ->
      case Map.get(params, field) do
        nil -> acc
        value -> Map.put(acc, String.to_atom(field), value)
      end
    end)
  end
end
