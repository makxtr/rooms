defmodule ChatsWeb.MessageController do
  use ChatsWeb, :controller

  def index(conn, _params) do
    # Заглушка для получения сообщений
    messages = [
      %{
        message_id: 1,
        room_id: 1,
        role_id: 1,
        nickname: "User1",
        content: "Hello, world!",
        created: DateTime.utc_now() |> DateTime.to_iso8601(),
        recipient_role_id: nil
      },
      %{
        message_id: 2,
        room_id: 1,
        role_id: 2,
        nickname: "User2",
        content: "Hi there!",
        created: DateTime.utc_now() |> DateTime.to_iso8601(),
        recipient_role_id: nil
      }
    ]

    json(conn, messages)
  end

  def create(conn, params) do
    # Заглушка для отправки нового сообщения
    message_data = %{
      message_id: :rand.uniform(10000),
      room_id: params["room_id"] || 1,
      role_id: 1,
      nickname: "TestUser",
      content: params["content"] || "New message",
      created: DateTime.utc_now() |> DateTime.to_iso8601(),
      recipient_role_id: params["recipient_role_id"]
    }

    json(conn, message_data)
  end
end
