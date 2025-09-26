defmodule Chats.Room do
  @moduledoc """
  Manages rooms using ETS - simple approach like OnlineUsers
  """
  @table_name :rooms

  def init do
    :ets.new(@table_name, [:set, :public, :named_table])
  end

  @doc """
  Создать новую комнату
  Key: hash
  Value: %{hash, topic, level, searchable, watched, creator_session_id, created_at}
  """
  def create_room(attrs \\ %{}) do
    hash = attrs["hash"] || generate_hash()
    topic = attrs["topic"] || "##{hash}"

    room = %{
      id: generate_id_from_hash(hash),
      hash: hash,
      topic: topic,
      level: attrs["level"] || 0,           # 0=открытая, 20=приватная
      searchable: Map.get(attrs, "searchable", true),
      watched: Map.get(attrs, "watched", false),
      creator_session_id: attrs["creator_session_id"],
      created_at: DateTime.utc_now()
    }

    :ets.insert(@table_name, {hash, room})
    {:ok, room}
  end

  @doc """
  Получить комнату по hash
  """
  def get_room_by_hash(hash) do
    case :ets.lookup(@table_name, hash) do
      [{^hash, room}] -> room
      [] -> nil
    end
  end


  @doc """
  Обновить комнату
  """
  def update_room(hash, attrs) do
    case get_room_by_hash(hash) do
      nil ->
        {:error, :not_found}
      room_data ->
        updated_room = %{room_data |
          topic: attrs["topic"] || room_data.topic,
          level: attrs["level"] || room_data.level,
          searchable: Map.get(attrs, "searchable", room_data.searchable),
          watched: Map.get(attrs, "watched",room_data.watched)
        }

        :ets.insert(@table_name, {hash, updated_room})
        {:ok, updated_room}
    end
  end

  @doc """
  Список всех комнат
  """
  def list_all_rooms do
    @table_name
    |> :ets.tab2list()
    |> Enum.map(fn {_hash, room} -> room end)
  end

  @doc """
  Форматировать комнату для API ответа
  """
  def format_room_response(room) do
    %{
      room_id: room.id,
      hash: room.hash,
      topic: room.topic,
      level: room.level,
      searchable: room.searchable,
      watched: room.watched
    }
  end

  @doc """
  Генерировать случайный hash
  """
  def generate_hash do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
  end

  # Генерировать ID из hash для совместимости с фронтом
  defp generate_id_from_hash(hash) do
    # Создаем консистентный integer ID из hash для фронта
    :erlang.phash2(hash, 1_000_000)
  end
end
