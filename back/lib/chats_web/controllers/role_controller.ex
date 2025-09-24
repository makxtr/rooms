defmodule ChatsWeb.RoleController do
  use ChatsWeb, :controller

  def show(conn, %{"role_id" => role_id}) do
    # Заглушка для получения данных роли
    role_data = %{
      role_id: role_id,
      nickname: "TestUser",
      room_id: 1,
      online: true,
      last_seen: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    json(conn, role_data)
  end

  def index(conn, _params) do
    # Заглушка для получения списка ролей в комнате
    roles = [
      %{
        role_id: 1,
        nickname: "User1",
        room_id: 1,
        online: true,
        last_seen: DateTime.utc_now() |> DateTime.to_iso8601()
      },
      %{
        role_id: 2,
        nickname: "User2",
        room_id: 1,
        online: false,
        last_seen: DateTime.utc_now() |> DateTime.add(-3600) |> DateTime.to_iso8601()
      }
    ]

    json(conn, roles)
  end
end