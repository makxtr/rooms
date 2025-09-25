defmodule ChatsWeb.Router do
  use ChatsWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ChatsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
  end

  scope "/", ChatsWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # API routes
  scope "/api", ChatsWeb do
    pipe_through :api

    get "/health", HealthController, :check

    # Sessions
    get "/sessions/me", SessionController, :me
    patch "/sessions/me", SessionController, :update

    # Sockets
    post "/sockets", SocketController, :create
    get "/sockets/:socket_id", SocketController, :show

    # Rooms
    get "/rooms/:hash", RoomController, :show
    post "/rooms", RoomController, :create
    post "/rooms/:hash/enter", RoomController, :enter
    post "/rooms/search", RoomController, :search
    patch "/rooms/:hash", RoomController, :update

    # Messages
    get "/messages", MessageController, :index
    post "/messages", MessageController, :create

    # Roles
    get "/roles/:role_id", RoleController, :show
    get "/roles", RoleController, :index
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:chats, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ChatsWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
