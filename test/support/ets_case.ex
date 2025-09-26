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
    if :ets.info(:online_users) == :undefined, do: Chats.OnlineUsers.init()

    # Очищаем таблицы перед и после каждого теста
    :ets.delete_all_objects(:rooms)
    :ets.delete_all_objects(:online_users)

    on_exit(fn ->
      :ets.delete_all_objects(:rooms)
      :ets.delete_all_objects(:online_users)
    end)

    :ok
  end
end
