defmodule ChatsWeb.RoomControllerTest do
  use ChatsWeb.ConnCase
  use Chats.EtsCase

  alias Chats.RoomContext

  # Fixture to create a test room
  defp room_fixture(attrs \\ %{}) do
    default_attrs = %{
      "hash" => "test-room-#{System.unique_integer([:positive])}",
      "topic" => "Test Room Topic",
      "level" => 0,
      "searchable" => true
    }

    attrs = Map.merge(default_attrs, attrs)
    {:ok, room} = RoomContext.create_room(attrs)
    room
  end

  describe "GET /api/rooms/:hash" do
    test "returns room data when room exists", %{conn: conn} do
      room = room_fixture()

      conn = get(conn, ~p"/api/rooms/#{room.hash}")

      assert json_response(conn, 200) == %{
        "room" => %{
          "room_id" => room.id,
          "hash" => room.hash,
          "topic" => room.topic,
          "level" => room.level,
          "searchable" => room.searchable,
          "watched" => room.watched
        }
      }
    end

    test "returns 404 when room doesn't exist", %{conn: conn} do
      conn = get(conn, ~p"/api/rooms/nonexistent")

      assert json_response(conn, 404) == %{
        "error" => "Room not found"
      }
    end
  end

  describe "POST /api/rooms" do
    test "creates room with valid data", %{conn: conn} do
      room_params = %{
        "hash" => "new-room",
        "topic" => "New Room Topic"
      }

      conn = post(conn, ~p"/api/rooms", room_params)
      response = json_response(conn, 201)

      assert %{
        "hash" => "new-room",
        "topic" => "New Room Topic",
        "level" => 0,
        "searchable" => true,
        "watched" => false
      } = response
    end

    test "generates hash when not provided", %{conn: conn} do
      room_params = %{"topic" => "Room without hash"}

      conn = post(conn, ~p"/api/rooms", room_params)
      response = json_response(conn, 201)

      assert %{"hash" => hash} = response
      assert is_binary(hash)
      assert String.length(hash) > 0
    end
  end

  describe "POST /api/rooms/:hash/enter" do
    test "enters existing room", %{conn: conn} do
      room = room_fixture()
      enter_params = %{"socket_id" => "test_socket_123"}

      conn = post(conn, ~p"/api/rooms/#{room.hash}/enter", enter_params)
      response = json_response(conn, 200)

      room_id = room.id
      hash = room.hash

      assert %{
        "room" => %{
          "room_id" => ^room_id,
          "hash" => ^hash
        },
        "subscription" => %{"subscription_id" => _},
        "role" => %{
          "role_id" => _,
          "nickname" => _
        },
        "roles_online" => []
      } = response
    end

    test "creates and enters new room", %{conn: conn} do
      hash = "new-room-#{System.unique_integer([:positive])}"
      enter_params = %{"socket_id" => "test_socket_123"}

      conn = post(conn, ~p"/api/rooms/#{hash}/enter", enter_params)
      response = json_response(conn, 200)

      assert %{
        "room" => %{
          "hash" => ^hash
        }
      } = response

      # Verify room was created
      assert RoomContext.room_exists?(hash)
    end
  end

  describe "POST /api/rooms/search" do
    test "returns random room when rooms exist", %{conn: conn} do
      room = room_fixture(%{"searchable" => true, "level" => 0})

      conn = post(conn, ~p"/api/rooms/search")
      response = json_response(conn, 200)

      room_id = room.id
      hash = room.hash

      assert %{
        "room_id" => ^room_id,
        "hash" => ^hash
      } = response
    end

    test "creates general room when no searchable rooms exist", %{conn: conn} do
      # Create only private/non-searchable rooms
      room_fixture(%{"searchable" => false})

      conn = post(conn, ~p"/api/rooms/search")
      response = json_response(conn, 200)

      assert %{
        "hash" => "general",
        "topic" => "Общий чат"
      } = response
    end
  end
end
