defmodule Rooms.OnlineUsers do
  @moduledoc """
  Manages online users in rooms using ETS - simple approach
  Users stay online until they explicitly leave
  """

  @table_name :online_users

  def init do
    # Создаем ETS таблицу при старте приложения
    :ets.new(@table_name, [:set, :public, :named_table])
  end

  @doc """
  Добавить пользователя в комнату
  Key: {room_hash, session_id}
  Value: %{session_id, nickname, joined_at}
  """
  def join_room(room_hash, session_id, nickname) do
    user_data = %{
      session_id: session_id,
      nickname: nickname,
      joined_at: DateTime.utc_now()
    }

    :ets.insert(@table_name, {{room_hash, session_id}, user_data})
  end

  @doc """
  Убрать пользователя из комнаты
  """
  def leave_room(room_hash, session_id) do
    :ets.delete(@table_name, {room_hash, session_id})
  end

  @doc """
  Получить всех онлайн пользователей в комнате
  """
  def get_online_users(room_hash) do
    pattern = {{room_hash, :_}, :_}

    @table_name
    |> :ets.match_object(pattern)
    |> Enum.map(fn {{_room_hash, _session_id}, user_data} -> user_data end)
  end

  @doc """
  Получить количество онлайн пользователей
  """
  def count_online_users(room_hash) do
    room_hash
    |> get_online_users()
    |> length()
  end

  @doc """
  Проверить онлайн ли пользователь в комнате
  """
  def user_online?(room_hash, session_id) do
    case :ets.lookup(@table_name, {room_hash, session_id}) do
      [_] -> true
      [] -> false
    end
  end

  @doc """
  Форматировать онлайн пользователей для API ответа
  """
  def format_online_users(room_hash) do
    room_hash
    |> get_online_users()
    |> Enum.map(fn user ->
      %{
        role_id: "role_#{user.session_id}",
        session_id: user.session_id,
        nickname: user.nickname,
        online: true
      }
    end)
  end

  @doc """
  Получить все комнаты где пользователь онлайн
  """
  def get_user_rooms(session_id) do
    pattern = {{:_, session_id}, :_}

    @table_name
    |> :ets.match_object(pattern)
    |> Enum.map(fn {{room_hash, _session_id}, _user_data} -> room_hash end)
  end
end