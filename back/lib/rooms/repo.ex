defmodule Rooms.Repo do
  use Ecto.Repo,
    otp_app: :rooms,
    adapter: Ecto.Adapters.Postgres
end
