defmodule Chats.RoomContext do
  @moduledoc """
  Context for room management operations using ETS
  """

  alias Chats.Room

  @doc """
  Gets a room by hash
  """
  def get_room_by_hash(hash) when is_binary(hash) do
    Room.get_room_by_hash(hash)
  end

  @doc """
  Gets a room by hash, returns error tuple if not found
  """
  def fetch_room_by_hash(hash) do
    case Room.get_room_by_hash(hash) do
      nil -> {:error, :not_found}
      room -> {:ok, room}
    end
  end

  @doc """
  Creates a new room
  """
  def create_room(attrs \\ %{}) do
    Room.create_room(attrs)
  end

  @doc """
  Creates a room with specific hash or generates random one
  """
  def create_room_with_hash(hash, attrs \\ %{}) do
    room_attrs = Map.merge(attrs, %{"hash" => hash})
    Room.create_room(room_attrs)
  end

  @doc """
  Finds or creates a room by hash
  """
  def find_or_create_room(hash, attrs \\ %{}) do
    case Room.get_room_by_hash(hash) do
      nil ->
        room_attrs = Map.merge(attrs, %{"hash" => hash})
        Room.create_room(room_attrs)
      room_data ->
        {:ok, room_data}
    end
  end

  @doc """
  Lists all rooms
  """
  def list_all_rooms do
    Room.list_all_rooms()
  end

  @doc """
  Updates a room
  """
  def update_room(room_data, attrs) do
    Room.update_room(room_data.hash, attrs)
  end

  @doc """
  Gets a random searchable room
  """
  def get_random_room do
    searchable_rooms =
      Room.list_all_rooms()
      |> Enum.filter(& &1.searchable)

    case searchable_rooms do
      [] -> nil
      rooms -> Enum.random(rooms)
    end
  end

  @doc """
  Checks if room exists by hash
  """
  def room_exists?(hash) do
    case Room.get_room_by_hash(hash) do
      nil -> false
      _ -> true
    end
  end

  @doc """
  Formats room data for API response
  """
  def format_room_response(room_data) do
    Room.format_room_response(room_data)
  end
end
