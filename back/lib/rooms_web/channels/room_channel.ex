defmodule RoomsWeb.RoomChannel do
  use RoomsWeb, :channel

  @impl true
  def join("room:" <> room_id, payload, socket) do
    if authorized?(payload) do
      socket = assign(socket, :room_id, room_id)
      {:ok, %{status: "joined", room_id: room_id}, socket}
    else
      {:error, %{reason: "unauthorized"}}
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
  def handle_in(event, payload, socket) do
    IO.puts("Unhandled event: #{event}")
    IO.inspect(payload)
    {:noreply, socket}
  end

  # Add authorization logic here as required.
  defp authorized?(_payload) do
    # Для тестирования разрешаем всем
    true
  end
end
