defmodule Chats.Message do
  @moduledoc """
  ETS-based message storage for rooms
  """

  @table_name :messages

  def init do
    :ets.new(@table_name, [:ordered_set, :public, :named_table])
  end

  @doc """
  Add message to room
  Key: {room_hash, timestamp}
  Value: %{message_id, room_hash, body, user_id, nickname, timestamp}
  """
  def add(message) do
    key = {message.room_hash, message.timestamp}
    :ets.insert(@table_name, {key, message})
    message
  end

  @doc """
  Get all messages in room
  """
  def all(room_hash) do
    @table_name
    |> :ets.tab2list()
    |> Enum.filter(fn {{r_hash, _ts}, _msg} -> r_hash == room_hash end)
    |> Enum.map(fn {_key, msg} -> msg end)
    |> Enum.sort_by(& &1.timestamp, :asc)
  end

  @doc """
  Get last N messages in room
  """
  def last(room_hash, limit \\ 50) do
    @table_name
    |> :ets.tab2list()
    |> Enum.filter(fn {{r_hash, _ts}, _msg} -> r_hash == room_hash end)
    |> Enum.map(fn {_key, msg} -> msg end)
    |> Enum.sort_by(& &1.timestamp, DateTime)
    |> Enum.take(-limit)
  end

  @doc """
  Delete all messages in room
  """
  def truncate(room_hash) do
    @table_name
    |> :ets.tab2list()
    |> Enum.filter(fn {{r_hash, _ts}, _msg} -> r_hash == room_hash end)
    |> Enum.each(fn {key, _msg} -> :ets.delete(@table_name, key) end)
  end
end
