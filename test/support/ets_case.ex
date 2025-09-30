defmodule Chats.EtsCase do
  @moduledoc """
  This module defines the setup for tests using ETS storage.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import helpful functions
    end
  end

  setup _tags do
    # Инициализируем ETS таблицы для тестов, если еще не созданы
    if :ets.info(:rooms) == :undefined, do: Chats.Room.init()

    # Очищаем таблицы перед и после каждого теста
    :ets.delete_all_objects(:rooms)

    on_exit(fn ->
      :ets.delete_all_objects(:rooms)
    end)

    :ok
  end
end
