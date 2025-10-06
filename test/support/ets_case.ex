defmodule Chats.EtsCase do
  @moduledoc """
  This module defines the setup for tests using ETS storage.
  """

  use ExUnit.CaseTemplate

  setup _tags do
    if :ets.info(:rooms) == :undefined, do: Chats.Room.init()
    if :ets.info(:messages) == :undefined, do: Chats.Message.init()

    :ets.delete_all_objects(:rooms)
    :ets.delete_all_objects(:messages)

    on_exit(fn ->
      :ets.delete_all_objects(:rooms)
      :ets.delete_all_objects(:messages)
    end)

    :ok
  end
end
