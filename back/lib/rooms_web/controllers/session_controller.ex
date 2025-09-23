defmodule RoomsWeb.SessionController do
  use RoomsWeb, :controller

  def me(conn, _params) do
    {updated_conn, session_data} = get_or_create_session(conn)

    # Добавляем информацию о версии приложения
    session_data = Map.put(session_data, :talkrooms, %{
      version: 39,
      whatsnew: "Базовая версия TalkRooms с анонимными сессиями"
    })

    json(updated_conn, session_data)
  end

  def update(conn, params) do
    {conn, current_session} = get_or_create_session(conn)

    updated_session = update_session_fields(current_session, params)

    conn = put_session(conn, "session_data", updated_session)

    json(conn, %{status: "ok", updated: params})
  end

  defp get_or_create_session(conn) do
    case get_session(conn, "session_data") do
      nil ->
        # Создаем новую анонимную сессию
        session_data = create_initial_session()
        # Сохраняем в сессии (куки)
        conn = put_session(conn, "session_data", session_data)
        {conn, session_data}

      existing_session ->
        {conn, existing_session}
    end
  end

  defp create_initial_session do
    session_id = generate_session_id()

    %{
      session_id: session_id,
      user_id: nil,
      provider_id: nil,
      rand_nickname: true,
      nickname: generate_random_nickname(),
      ignores: [%{}, %{}], # [user_ignores, session_ignores]
      subscriptions: [],
      rooms: [],
      recent_rooms: [],
      created_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp update_session_fields(session, params) do
    # Разрешенные для обновления поля
    allowed_fields = ["nickname", "ignores", "subscriptions"]

    Enum.reduce(allowed_fields, session, fn field, acc ->
      case Map.get(params, field) do
        nil -> acc
        value -> Map.put(acc, String.to_atom(field), value)
      end
    end)
  end

  defp generate_session_id do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end

  defp generate_random_nickname do
    adjectives = ["Быстрый", "Умный", "Добрый", "Смелый", "Веселый", "Тихий", "Яркий"]
    nouns = ["Кот", "Лис", "Волк", "Медведь", "Заяц", "Еж", "Белка"]

    adjective = Enum.random(adjectives)
    noun = Enum.random(nouns)
    number = :rand.uniform(999)

    "#{adjective}#{noun}#{number}"
  end
end
