defmodule Chats.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Инициализируем ETS таблицы
    Chats.Room.init()
    Chats.OnlineUsers.init()

    children = [
      ChatsWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:chats, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Chats.PubSub},
      ChatsWeb.Presence,
      # Start a worker by calling: Rooms.Worker.start_link(arg)
      # {Rooms.Worker, arg},
      # Start to serve requests, typically the last entry
      ChatsWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Chats.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ChatsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
