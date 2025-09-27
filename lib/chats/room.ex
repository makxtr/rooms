defmodule Chats.Room do
  @moduledoc """
  """

  @table_name :rooms

  def init do
    :ets.new(@table_name, [:set, :public, :named_table])
  end

  @doc """
  Добавить/Обновить новую комнату
  Key: hash
  Value: %{hash, topic, level, searchable, watched, creator_session_id, created_at}
  """
  def insert(room) do
    :ets.insert(@table_name, {room.hash, room})
    {:ok, room}
  end

  @doc """
  Получить комнату по hash
  """
  def get_by_hash(hash) do
    case :ets.lookup(@table_name, hash) do
      [{^hash, room}] -> room
      [] -> nil
    end
  end

  @doc """
  Список всех комнат
  """
  def list do
    @table_name
    |> :ets.tab2list()
    |> Enum.map(fn {_hash, room} -> room end)
  end
end
