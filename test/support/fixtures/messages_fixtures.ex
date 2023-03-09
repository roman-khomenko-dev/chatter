defmodule Chatter.MessagesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Chatter.Messages` context.
  """

  @doc """
  Generate a message.
  """
  def message_fixture(attrs \\ %{}) do
    {:ok, message} =
      attrs
      |> Enum.into(%{

      })
      |> Chatter.Messages.create_message()

    message
  end
end
