defmodule Chats.RoomContextTest do
  use ExUnit.Case, async: true
  use Chats.DataCase
  alias Chats.RoomContext
  alias Chats.Room

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

  describe "get_room_by_hash/1" do
    test "returns room when it exists" do
      room = room_fixture()
      found_room = RoomContext.get_room_by_hash(room.hash)

      assert found_room.id == room.id
      assert found_room.hash == room.hash
      assert found_room.topic == room.topic
    end

    test "returns nil when room doesn't exist" do
      result = RoomContext.get_room_by_hash("nonexistent")
      assert result == nil
    end
  end

  describe "fetch_room_by_hash/1" do
    test "returns {:ok, room} when room exists" do
      room = room_fixture()
      assert {:ok, found_room} = RoomContext.fetch_room_by_hash(room.hash)
      assert found_room.id == room.id
    end

    test "returns {:error, :not_found} when room doesn't exist" do
      assert {:error, :not_found} = RoomContext.fetch_room_by_hash("nonexistent")
    end
  end

  describe "create_room/1" do
    test "creates room with valid attributes" do
      attrs = %{
        "hash" => "valid-room",
        "topic" => "Valid Room Topic"
      }

      assert {:ok, room} = RoomContext.create_room(attrs)
      assert room.hash == "valid-room"
      assert room.topic == "Valid Room Topic"
      assert room.level == 0  # default
      assert room.searchable == true  # default
    end

    test "generates hash when not provided" do
      attrs = %{"topic" => "Room without hash"}

      assert {:ok, room} = RoomContext.create_room(attrs)
      assert is_binary(room.hash)
      assert String.length(room.hash) > 0
    end

    test "fails with invalid attributes" do
      attrs = %{"hash" => ""}  # empty hash

      assert {:error, changeset} = RoomContext.create_room(attrs)
      assert %{hash: ["can't be blank"]} = errors_on(changeset)
    end

    test "fails with duplicate hash" do
      room = room_fixture()
      attrs = %{"hash" => room.hash, "topic" => "Duplicate"}

      assert {:error, changeset} = RoomContext.create_room(attrs)
      assert %{hash: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "find_or_create_room/2" do
    test "returns existing room when found" do
      existing_room = room_fixture()

      assert {:ok, room} = RoomContext.find_or_create_room(existing_room.hash)
      assert room.id == existing_room.id
    end

    test "creates new room when not found" do
      hash = "new-room-#{System.unique_integer([:positive])}"
      attrs = %{"topic" => "New Room"}

      assert {:ok, room} = RoomContext.find_or_create_room(hash, attrs)
      assert room.hash == hash
      assert room.topic == "New Room"
    end
  end

  describe "get_random_room/0" do
    test "returns nil when no searchable rooms exist" do
      # Create private room (not searchable for random)
      room_fixture(%{"searchable" => false})

      assert RoomContext.get_random_room() == nil
    end

    test "returns random searchable room" do
      room = room_fixture(%{"searchable" => true, "level" => 0})

      result = RoomContext.get_random_room()
      assert result.id == room.id
    end
  end

  describe "room_exists?/1" do
    test "returns true when room exists" do
      room = room_fixture()
      assert RoomContext.room_exists?(room.hash) == true
    end

    test "returns false when room doesn't exist" do
      assert RoomContext.room_exists?("nonexistent") == false
    end
  end

  describe "format_room_response/1" do
    test "formats room for API response" do
      room = room_fixture()
      response = RoomContext.format_room_response(room)

      assert response.room_id == room.id
      assert response.hash == room.hash
      assert response.topic == room.topic
      assert response.level == room.level
      assert response.searchable == room.searchable
      assert response.watched == room.watched
    end
  end

end