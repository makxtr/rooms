defmodule ChatsWeb.RoomChannel do
  use ChatsWeb, :channel
  alias ChatsWeb.Presence

  @impl true
  def join("room:" <> room_id, payload, socket) do
    try do
      if authorized?(payload) do
        user_id = Map.get(payload, "user_id")
        nickname = Map.get(payload, "nickname", "Гость")
        status = Map.get(payload, "status")

        socket = assign(socket, user_id: user_id)

        case Presence.track(socket, user_id, %{
               nickname: nickname,
               status: status
             }) do
          {:ok, _} ->
            send(self(), :after_join)

            {:ok,
             %{
               status: "joined",
               room_id: room_id,
               user_id: user_id,
               nickname: nickname
             }, socket}

          {:error, _reason} ->
            {:ok,
             %{
               status: "joined_no_presence",
               room_id: room_id,
               user_id: user_id,
               nickname: nickname
             }, socket}
        end
      else
        {:error, %{reason: "unauthorized"}}
      end
    rescue
      error ->
        {:error, %{reason: "join_error", details: inspect(error)}}
    end
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
  def handle_in("message", %{"body" => body}, socket) do
    message = %{
      message_id: :rand.uniform(10000),
      body: body,
      user_id: socket.assigns.user_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    broadcast(socket, "message", message)
    {:noreply, socket}
  end

  # Handle presence updates
  @impl true
  def handle_in("update_presence", payload, socket) do
    nickname = Map.get(payload, "nickname")
    status = Map.get(payload, "status")

    # Обновляем presence
    case Presence.update(socket, socket.assigns.user_id, %{
           nickname: nickname,
           status: status
         }) do
      {:ok, _} ->
        {:reply, {:ok, %{status: "updated"}}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  # Handle other events
  @impl true
  def handle_in(_event, _payload, socket) do
    {:noreply, socket}
  end

  # Handle after join message
  @impl true
  def handle_info(:after_join, socket) do
    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end

  # Add authorization logic here as required.
  defp authorized?(_payload) do
    # Для тестирования разрешаем всем
    true
  end
end
