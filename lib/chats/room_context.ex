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
    hash = attrs["hash"] || Utils.gen_room_hash()
    topic = attrs["topic"] || "##{hash}"

    room = %{
      id: Utils.gen_id_from_hash(hash),
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

      room ->
        {:ok, room}
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
  def update_room(room, attrs) do
    case Room.get_by_hash(room.hash) do
      nil ->
        {:error, :not_found}

      room ->
        updated_room = %{
          room
          | topic: attrs["topic"] || room.topic,
            level: attrs["level"] || room.level,
            searchable: Map.get(attrs, "searchable", room.searchable),
            watched: Map.get(attrs, "watched", room.watched)
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

  @doc """
  Builds enter room response with user role and permissions
  """
  def enter_room(room, session_data, socket_id) do
    %{
      room: format_room_response(room),
      subscription: build_subscription(room, socket_id),
      role: build_user_role(room, session_data),
      roles_online: []
    }
  end

  # Private functions for building enter room response

  defp build_user_role(room, session_data) do
    user_id = get_user_id(session_data)
    nickname = get_nickname(session_data)
    permissions = calculate_permissions(room, session_data)

    %{
      nickname: nickname,
      level: permissions.level,
      isAdmin: permissions.is_admin,
      user_id: user_id
    }
  end

  defp get_user_id(nil), do: "guest_#{:rand.uniform(100_000)}"

  defp get_user_id(session_data) do
    session_data[:user_id] || session_data[:session_id]
  end

  defp get_nickname(nil), do: "Anonymous"
  defp get_nickname(session_data), do: session_data[:nickname] || "Anonymous"

  defp calculate_permissions(room, session_data) do
    current_session_id = if session_data, do: session_data[:session_id], else: nil
    is_creator = room.creator_session_id == current_session_id
    level = if is_creator, do: 80, else: 0

    %{level: level, is_admin: level >= 70}
  end

  defp build_subscription(room, socket_id) do
    %{subscription_id: "temp_#{room.id}_#{socket_id}"}
  end
end
