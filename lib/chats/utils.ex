defmodule Chats.Utils do
  @doc """
  Генерировать случайный hash
  """
  def gen_room_hash do
    hash(8)
  end

  @doc """
  Generates secure session ID
  """
  def gen_session_hash do
    hash(16)
  end

  defp hash(size) do
    :crypto.strong_rand_bytes(size) |> Base.url_encode64(padding: false)
  end

  # Генерировать ID из hash для совместимости с фронтом
  def gen_id_from_hash(hash) do
    # Создаем консистентный integer ID из hash для фронта
    :erlang.phash2(hash, 1_000_000)
  end


  @doc """
  Generates random nickname for anonymous users
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
