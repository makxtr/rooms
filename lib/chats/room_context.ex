defmodule Chats.RoomContext do
  @moduledoc """
  Context for room management operations
  """

  import Ecto.Query, warn: false
  alias Chats.Repo
  alias Chats.Room

  @doc """
  Gets a room by hash
  """
  def get_room_by_hash(hash) when is_binary(hash) do
    Room
    |> where([r], r.hash == ^hash)
    |> Repo.one()
  end

  @doc """
  Gets a room by hash, returns error tuple if not found
  """
  def fetch_room_by_hash(hash) do
    case get_room_by_hash(hash) do
      nil -> {:error, :not_found}
      room -> {:ok, room}
    end
  end

  @doc """
  Creates a new room
  """
  def create_room(attrs \\ %{}) do
    attrs
    |> Room.create_changeset()
    |> Repo.insert()
  end

  @doc """
  Creates a room with specific hash or generates random one
  """
  def create_room_with_hash(hash, attrs \\ %{}) do
    room_attrs = Map.merge(attrs, %{"hash" => hash})
    create_room(room_attrs)
  end

  @doc """
  Updates a room
  """
  def update_room(%Room{} = room, attrs) do
    room
    |> Room.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Finds or creates a room by hash
  """
  def find_or_create_room(hash, attrs \\ %{}) do
    case get_room_by_hash(hash) do
      nil ->
        create_room_with_hash(hash, attrs)
      room ->
        {:ok, room}
    end
  end

  @doc """
  Gets a random searchable room
  """
  def get_random_room do
    Room
    |> where([r], r.searchable == true and r.level == 0)
    |> order_by(fragment("RANDOM()"))
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Lists all searchable public rooms
  """
  def list_searchable_rooms do
    Room
    |> where([r], r.searchable == true and r.level == 0)
    |> order_by([r], desc: r.inserted_at)
    |> Repo.all()
  end

  @doc """
  Checks if room exists by hash
  """
  def room_exists?(hash) do
    Room
    |> where([r], r.hash == ^hash)
    |> Repo.exists?()
  end

  @doc """
  Formats room data for API response
  """
  def format_room_response(%Room{} = room) do
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