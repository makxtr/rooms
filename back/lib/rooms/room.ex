defmodule Rooms.Room do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @derive {Phoenix.Param, key: :hash}

  schema "rooms" do
    field :hash, :string
    field :topic, :string
    field :level, :integer, default: 0        # 0=открытая, 20=приватная
    field :searchable, :boolean, default: true
    field :watched, :boolean, default: false
    field :creator_session_id, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(room, attrs) do
    room
    |> cast(attrs, [:hash, :topic, :level, :searchable, :watched, :creator_session_id])
    |> validate_required([:hash, :topic])
    |> validate_length(:hash, min: 3, max: 50)
    |> validate_length(:topic, min: 1, max: 200)
    |> validate_inclusion(:level, [0, 20])
    |> validate_format(:hash, ~r/^[a-zA-Z0-9_\-+]+$/,
        message: "должен содержать только буквы, цифры, _, -, +")
    |> unique_constraint(:hash)
  end

  @doc """
  Changeset for creating a new room
  """
  def create_changeset(attrs) do
    # Generate defaults first
    hash = attrs["hash"] || generate_hash()
    topic = attrs["topic"] || "##{hash}"

    # Merge defaults into attrs
    attrs_with_defaults = Map.merge(attrs, %{"hash" => hash, "topic" => topic})

    %__MODULE__{}
    |> changeset(attrs_with_defaults)
  end

  @doc """
  Changeset for updating room
  """
  def update_changeset(room, attrs) do
    room
    |> cast(attrs, [:topic, :level, :searchable, :watched])
    |> validate_required([:topic])
    |> validate_length(:topic, min: 1, max: 200)
    |> validate_inclusion(:level, [0, 20])
  end

  defp generate_hash do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
  end
end