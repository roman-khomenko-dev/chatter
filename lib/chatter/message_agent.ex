defmodule Chatter.MessageAgent do
  @moduledoc """
  Message state management
  """

  use Agent
  alias Chatter.Message

  def start_link(_init) do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  def get do
    Agent.get(__MODULE__, & &1)
  end

  def add(message) do
    Agent.update(__MODULE__, fn(state) -> [message | state] end)
  end

  def set_like(_pid, {uuid, user}) do
    Agent.update(__MODULE__, fn(state) -> Enum.map(state, fn message ->
      case Map.get(message, :uuid) == uuid do
        true ->
          message = proceed_like(message, user)
          elem(Message.broadcast_change({:ok, message}, {:message, :updated}), 1)
        false -> message
      end
     end)
    end)
  end

  defp proceed_like(message, user), do: if Enum.member?(Map.get(message, :likes), user), do: remove_like(message, user), else: push_like(message, user)

  defp push_like(message, user) do
    Map.put(message, :likes, [user | Map.get(message, :likes)])
  end

  defp remove_like(message, user) do
    Map.put(message, :likes, List.delete(Map.get(message, :likes), user))
  end
end
