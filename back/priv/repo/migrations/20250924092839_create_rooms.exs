defmodule Rooms.Repo.Migrations.CreateRooms do
  use Ecto.Migration

  def change do
    create table(:rooms) do
      add :hash, :string, null: false
      add :topic, :string, null: false
      add :level, :integer, default: 0, null: false  # 0=открытая, 20=приватная
      add :searchable, :boolean, default: true, null: false
      add :watched, :boolean, default: false, null: false
      add :creator_session_id, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:rooms, [:hash])
    create index(:rooms, [:searchable])
    create index(:rooms, [:level])
  end
end
