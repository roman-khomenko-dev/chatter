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

  def get_by_id(id) do
    Enum.filter(get(), fn message -> message.id == id end)
  end

  def add(message) do
    Agent.update(__MODULE__, fn(state) -> [message | state] end)
  end

  def clear do
    Agent.update(__MODULE__, fn(_state) -> [] end)
  end

  def set_like(_pid, {id, user}) do
    Agent.update(__MODULE__, fn(state) -> Enum.map(state, fn message ->
      case Map.get(message, :id) == id do
        true ->
          message
          |> proceed_like(user)
          |> Message.broadcast_change({:message, :updated})
          |> elem(1)
        false -> message
      end
     end)
    end)
  end

  @spec get_all_likes :: list
  def get_all_likes do
    likes = []
    Agent.get(__MODULE__, & &1)
    |> Enum.reduce(likes, fn message, acc ->
      acc ++ message.likes
    end)
  end

  defp proceed_like(message, user), do: if Enum.member?(Map.get(message, :likes), user), do: remove_like(message, user), else: push_like(message, user)

  defp push_like(message, user) do
    message = Map.put(message, :likes, [user | Map.get(message, :likes)])
    {:ok, message}
  end

  defp remove_like(message, user) do
    message = Map.put(message, :likes, List.delete(Map.get(message, :likes), user))
    {:ok, message}
  end
end
