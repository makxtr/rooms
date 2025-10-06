defmodule Chats.Utils do
  @doc """
  Unique for room hash
  """
  def gen_room_hash do
    hash(8)
  end

  @doc """
  Unique for session hash
  16 bytes → 22 chars
  """
  def gen_session_hash do
    hash(16)
  end

  @doc """
  Unique for message hash
  16 bytes → 22 chars
  """
  def gen_message_hash do
    hash(16)
  end

  defp hash(size) do
    :crypto.strong_rand_bytes(size) |> Base.url_encode64(padding: false)
  end

  def gen_id_from_hash(hash) do
    :erlang.phash2(hash, 1_000_000)
  end

  @doc """
  Generates random nickname
  """
  def gen_random_nickname do
    adjectives = ["Быстрый", "Умный", "Добрый", "Смелый", "Веселый", "Тихий", "Яркий"]
    nouns = ["Кот", "Лис", "Волк", "Медведь", "Заяц", "Еж", "Белка"]

    adjective = Enum.random(adjectives)
    noun = Enum.random(nouns)
    number = :rand.uniform(999)

    "#{adjective}#{noun}#{number}"
  end
end
