defmodule ChatsWeb.RoomChannel do
  use ChatsWeb, :channel
  alias ChatsWeb.Presence
  alias Chats.MessageContext

  @impl true
  def join("room:" <> room_hash, payload, socket) do
    user_id = Map.get(payload, "user_id")
    nickname = Map.get(payload, "nickname", "Гость")
    status = Map.get(payload, "status")

    socket =
      socket
      |> assign(:user_id, user_id)
      |> assign(:room_hash, room_hash)
      |> assign(:nickname, nickname)

    {:ok, _} =
      Presence.track(socket, user_id, %{
        nickname: nickname,
        status: status
      })

    send(self(), :after_join)

    {:ok,
     %{
       status: "joined",
       room_hash: room_hash,
       user_id: user_id,
       nickname: nickname
     }, socket}
  end

  # Handle after join message
  @impl true
  def handle_info(:after_join, socket) do
    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  @impl true
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (room:lobby).
  @impl true
  def handle_in("new_message", %{"body" => body}, socket) do
    message =
      MessageContext.create(
        socket.assigns.room_hash,
        socket.assigns.user_id,
        socket.assigns.nickname,
        body
      )

    broadcast(socket, "new_message", message)
    {:reply, {:ok, message}, socket}
  end

  # Handle presence updates
  @impl true
  def handle_in("update_presence", payload, socket) do
    nickname = Map.get(payload, "nickname")
    status = Map.get(payload, "status")

    {:ok, _} =
      Presence.update(socket, socket.assigns.user_id, %{
        nickname: nickname,
        status: status
      })

    {:noreply, socket}
  end

  # Handle other events
  @impl true
  def handle_in(_event, _payload, socket) do
    {:noreply, socket}
  end
end
