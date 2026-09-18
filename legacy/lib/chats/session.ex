defmodule Chats.Session do
  alias Chats.Utils

  @doc """
  Creates initial session with default values
  """
  def init do
    %{
      session_id: Utils.gen_session_hash(),
      user_id: nil,
      provider_id: nil,
      rand_nickname: true,
      nickname: Utils.gen_random_nickname(),
      status: nil,
      # [user_ignores, session_ignores]
      ignores: [%{}, %{}],
      subscriptions: [],
      rooms: [],
      recent_rooms: [],
      created_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end
end
