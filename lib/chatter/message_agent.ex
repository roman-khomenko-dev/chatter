defmodule Chatter.MessageAgent do
  use Agent

  def start_link(init) do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  def get do
    Agent.get(__MODULE__, & &1)
  end

  def add(pid, message) do
    Agent.update(pid, fn(state) -> [message | state] end)
  end
end
