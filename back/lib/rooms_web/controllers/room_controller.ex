defmodule RoomsWeb.RoomController do
  use RoomsWeb, :controller

  def show(conn, %{"hash" => hash}) do
    # Заглушка для получения данных комнаты
    room_data = %{
      room_id: 1,
      hash: hash,
      topic: "Test Room",
      level: 0,
      searchable: true,
      watched: false
    }

    json(conn, room_data)
  end

  def create(conn, _params) do
    # Заглушка для создания новой комнаты
    room_data = %{
      room_id: :rand.uniform(1000),
      hash: "room_" <> :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower),
      topic: "New Room",
      level: 0,
      searchable: true,
      watched: false
    }

    json(conn, room_data)
  end

  def enter(conn, %{"hash" => hash}) do
    # Заглушка для входа в комнату
    json(conn, %{status: "entered", room_hash: hash})
  end

  def search(conn, _params) do
    # Заглушка для поиска случайной комнаты
    room_data = %{
      room_id: :rand.uniform(1000),
      hash: "room_" <> :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower),
      topic: "Random Room",
      level: 0,
      searchable: true,
      watched: false
    }

    json(conn, room_data)
  end
end