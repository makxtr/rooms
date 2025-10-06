defmodule Chats.MessageContext do
  @moduledoc """
  Context for message management operations using ETS
  """

  alias Chats.Message

  @doc """
  Создает новое сообщение в комнате
  """
  def create(room_hash, user_id, nickname, body) do
    %{
      message_id: generate_message_id(),
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
  Получает историю сообщений комнаты
  """
  def list(room_hash, limit \\ 50) do
    Message.last(room_hash, limit)
    |> format_list()
  end

  @doc """
  Форматирует сообщение для отправки клиенту
  """
  def format_one(message) do
    %{
      message_id: message.message_id,
      body: message.body,
      user_id: message.user_id,
      nickname: message.nickname,
      timestamp: DateTime.to_iso8601(message.timestamp)
    }
  end

  @doc """
  Форматирует список сообщений для отправки клиенту
  """
  def format_list(messages) do
    Enum.map(messages, &format_one/1)
  end

  @doc """
  Удаляет все сообщения комнаты
  """
  def clear(room_hash) do
    Message.truncate(room_hash)
  end

  # Генерация уникального ID сообщения
  defp generate_message_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end
