defmodule RoomsWeb.SessionController do
  use RoomsWeb, :controller

  def me(conn, _params) do
    # Минимальная сессия для тестирования
    session_data = %{
      user_id: nil,
      provider_id: nil,
      rand_nickname: true,
      ignores: [],
      subscriptions: [],
      rooms: [],
      recent_rooms: []
    }

    json(conn, session_data)
  end

  def update(conn, params) do
    # Заглушка для обновления сессии
    json(conn, %{status: "ok", updated: params})
  end
end