defmodule ChatsWeb.RoomChannel do
  use ChatsWeb, :channel
  alias ChatsWeb.Presence

  @impl true
  def join("room:" <> room_id, payload, socket) do
    try do
      if authorized?(payload) do
        user_id = get_user_id(payload)
        nickname = get_nickname(payload)

        socket =
          socket
          |> assign(:room_id, room_id)
          |> assign(:user_id, user_id)
          |> assign(:nickname, nickname)

        # Track user presence
        case Presence.track(socket, socket.assigns.user_id, %{
               nickname: socket.assigns.nickname,
               online_at: inspect(System.system_time(:second))
             }) do
          {:ok, _} ->
            # Send message to self to push presence state after join completes
            send(self(), :after_join)

            {:ok,
             %{
               status: "joined",
               room_id: room_id,
               user_id: user_id,
               nickname: nickname
             }, socket}

          {:error, _reason} ->
            # Fallback: join without presence
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
  def handle_in("message", %{"body" => body} = _payload, socket) do
    message = %{
      message_id: :rand.uniform(10000),
      body: body,
      user_id: socket.assigns.user_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    broadcast(socket, "message", message)
    {:noreply, socket}
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

  defp get_user_id(payload) do
    # Генерируем временный ID если не передан
    payload["user_id"] || "temp_user_#{:rand.uniform(100_000)}"
  end

  defp get_nickname(payload) do
    # Используем переданное имя или генерируем случайное
    payload["nickname"] || "Гость#{:rand.uniform(1000)}"
  end
end
