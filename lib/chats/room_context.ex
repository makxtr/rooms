defmodule Chats.RoomContext do
  @moduledoc """
  Context for room management operations using ETS
  """

  alias Chats.Room
  alias Chats.Utils

  @doc """
  Gets a room by hash
  """
  def get_room_by_hash(hash) when is_binary(hash) do
    Room.get_by_hash(hash)
  end

  @doc """
  Gets a room by hash, returns error tuple if not found
  """
  def fetch_room_by_hash(hash) do
    case Room.get_by_hash(hash) do
      nil -> {:error, :not_found}
      room -> {:ok, room}
    end
  end

  @doc """
  Creates a new room
  """
  def create_room(attrs \\ %{}) do
    hash = attrs["hash"] || Utils.generate_hash()
    topic = attrs["topic"] || "##{hash}"

    room = %{
      id: Utils.generate_id_from_hash(hash),
      hash: hash,
      topic: topic,
      # 0=открытая, 20=приватная
      level: attrs["level"] || 0,
      searchable: Map.get(attrs, "searchable", true),
      watched: Map.get(attrs, "watched", false),
      creator_session_id: attrs["creator_session_id"],
      created_at: DateTime.utc_now()
    }

    Room.insert(room)
  end

  @doc """
  Creates a room with specific hash or generates random one
  """
  def create_room_with_hash(hash, attrs \\ %{}) do
    room_attrs = Map.merge(attrs, %{"hash" => hash})
    create_room(room_attrs)
  end

  @doc """
  Finds or creates a room by hash
  """
  def find_or_create_room(hash, attrs \\ %{}) do
    case Room.get_by_hash(hash) do
      nil ->
        room_attrs = Map.merge(attrs, %{"hash" => hash})
        create_room(room_attrs)

      room_data ->
        {:ok, room_data}
    end
  end

  @doc """
  Lists all rooms
  """
  def list_all_rooms do
    Room.list()
  end

  @doc """
  Updates a room
  """
  def update_room(room_data, attrs) do
    case Room.get_by_hash(room_data.hash) do
      nil ->
        {:error, :not_found}

      room_data ->
        updated_room = %{
          room_data
          | topic: attrs["topic"] || room_data.topic,
            level: attrs["level"] || room_data.level,
            searchable: Map.get(attrs, "searchable", room_data.searchable),
            watched: Map.get(attrs, "watched", room_data.watched)
        }

        Room.insert(updated_room)
    end
  end

  @doc """
  Gets a random searchable room
  """
  def get_random_room do
    searchable_rooms =
      Room.list()
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
    case Room.get_by_hash(hash) do
      nil -> false
      _ -> true
    end
  end

  @doc """
  Formats room data for API response
  """
  def format_room_response(room) do
    %{
      room_id: room.id,
      hash: room.hash,
      topic: room.topic,
      level: room.level,
      searchable: room.searchable,
      watched: room.watched
    }
  end
end
