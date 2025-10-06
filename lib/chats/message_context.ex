defmodule Chats.MessageContext do
  @moduledoc """
  Context for message management operations using ETS
  """

  alias Chats.Message
  alias Chats.Utils

  @doc """
  New message in room
  """
  def create(room_hash, user_id, nickname, body) do
    %{
      message_id: Utils.gen_message_hash(),
      room_hash: room_hash,
      body: body,
      user_id: user_id,
      nickname: nickname,
      timestamp: DateTime.utc_now()
    }
    |> Message.add()
    |> format_one()
  end

  @doc """
  List all messages in room
  """
  def list(room_hash, limit \\ 50) do
    Message.last(room_hash, limit)
    |> format_list()
  end

  @doc """
  Format message for sending to client
  """
  def format_one(message) do
    %{
      message_id: message.message_id,
      room_hash: message.room_hash,
      body: message.body,
      user_id: message.user_id,
      nickname: message.nickname,
      timestamp: DateTime.to_iso8601(message.timestamp)
    }
  end

  @doc """
  Format list of messages for sending to client
  """
  def format_list(messages) do
    Enum.map(messages, &format_one/1)
  end

  @doc """
  Clear all messages in room
  """
  def clear(room_hash) do
    Message.truncate(room_hash)
  end
end
