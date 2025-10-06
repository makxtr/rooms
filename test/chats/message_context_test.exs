defmodule Chats.MessageContextTest do
  use ExUnit.Case, async: true
  use Chats.EtsCase
  alias Chats.MessageContext
  alias Chats.Utils

  defp message_fixture() do
    MessageContext.create(
      Utils.gen_room_hash(),
      Utils.gen_session_hash(),
      Utils.gen_random_nickname(),
      "Hello, world!"
    )
  end

  describe "create/4" do
    test "creates message ok" do
      message = message_fixture()

      assert is_binary(message.timestamp)
    end
  end

  describe "list/2 & clear" do
    test "create and list ok" do
      message = message_fixture()

      messages = MessageContext.list(message.room_hash)
      assert is_list(messages)
      assert length(messages) == 1

      MessageContext.clear(message.room_hash)

      assert MessageContext.list(message.room_hash) == []
    end
  end

  describe "Message.last/2 order" do
    test "returns messages in correct chronological order" do
      alias Chats.Message

      room_hash = Utils.gen_room_hash()

      timestamps = [
        ~U[2024-01-01 10:00:00Z],
        ~U[2024-01-01 10:05:00Z],
        ~U[2024-01-01 10:10:00Z],
        ~U[2024-01-01 10:15:00Z]
      ]

      Enum.each(timestamps, fn ts ->
        Message.add(%{
          message_id: Utils.gen_message_hash(),
          room_hash: room_hash,
          body: "Message at #{ts}",
          user_id: Utils.gen_session_hash(),
          nickname: Utils.gen_random_nickname(),
          timestamp: ts
        })
      end)

      messages = Message.last(room_hash, 10)

      assert length(messages) == 4

      Enum.each(0..2, fn i ->
        current = Enum.at(messages, i)
        next = Enum.at(messages, i + 1)
        assert DateTime.compare(current.timestamp, next.timestamp) == :lt
      end)
    end
  end
end
