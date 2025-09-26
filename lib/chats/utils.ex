defmodule Chats.Utils do
  @doc """
  Генерировать случайный hash
  """
  def generate_hash do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
  end

  # Генерировать ID из hash для совместимости с фронтом
  def generate_id_from_hash(hash) do
    # Создаем консистентный integer ID из hash для фронта
    :erlang.phash2(hash, 1_000_000)
  end
end
