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
  Get message by message_id
  """
  def get_by_id(message_id) do
    @table_name
    |> :ets.tab2list()
    |> Enum.find_value(fn {_key, msg} ->
      if msg.message_id == message_id, do: msg, else: nil
    end)
  end

  @doc """
  Update message content by message_id
  """
  def update(message_id, attrs) do
    case get_by_id(message_id) do
      nil ->
        {:error, :not_found}

      message ->
        updated_message = Map.merge(message, attrs)
        key = {message.room_hash, message.timestamp}
        :ets.insert(@table_name, {key, updated_message})
        {:ok, updated_message}
    end
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
