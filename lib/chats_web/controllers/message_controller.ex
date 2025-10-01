defmodule ChatsWeb.MessageController do
  use ChatsWeb, :controller

  def index(conn, _params) do
    # Заглушка для получения сообщений
    messages = [
      %{
        message_id: 1,
        room_id: 1,
        user_id: "user_1",
        nickname: "User1",
        content: "Hello, world!",
        created: DateTime.utc_now() |> DateTime.to_iso8601(),
        recipient_user_id: nil
      },
      %{
        message_id: 2,
        room_id: 1,
        user_id: "user_2",
        nickname: "User2",
        content: "Hi there!",
        created: DateTime.utc_now() |> DateTime.to_iso8601(),
        recipient_user_id: nil
      }
    ]

    json(conn, messages)
  end

  def create(conn, params) do
    # Заглушка для отправки нового сообщения
    message_data = %{
      message_id: :rand.uniform(10000),
      room_id: params["room_id"] || 1,
      user_id: params["user_id"] || "user_1",
      nickname: "TestUser",
      content: params["content"] || "New message",
      created: DateTime.utc_now() |> DateTime.to_iso8601(),
      recipient_user_id: params["recipient_user_id"]
    }

    json(conn, message_data)
  end
end
