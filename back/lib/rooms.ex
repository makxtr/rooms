defmodule Rooms do
  @moduledoc """
  Rooms keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  # Delegate room functions to RoomContext
  alias Rooms.RoomContext

  defdelegate get_room_by_hash(hash), to: RoomContext
  defdelegate fetch_room_by_hash(hash), to: RoomContext
  defdelegate create_room(attrs), to: RoomContext
  defdelegate create_room_with_hash(hash, attrs), to: RoomContext
  defdelegate update_room(room, attrs), to: RoomContext
  defdelegate find_or_create_room(hash, attrs), to: RoomContext
  defdelegate get_random_room(), to: RoomContext
  defdelegate list_searchable_rooms(), to: RoomContext
  defdelegate room_exists?(hash), to: RoomContext
  defdelegate format_room_response(room), to: RoomContext

  # Convenience functions with default params
  def create_room(), do: RoomContext.create_room(%{})
  def find_or_create_room(hash), do: RoomContext.find_or_create_room(hash, %{})
end
