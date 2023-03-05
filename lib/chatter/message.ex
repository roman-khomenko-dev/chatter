defmodule Chatter.Message do
  @moduledoc """
  Describing of Message model
  """
  alias Chatter.MessageAgent
  import Ecto.Changeset

  @types %{id: :string, text: :string, timestamp: DateTime, author: :string, likes: :array}
  @derive Jason.Encoder
  defstruct [:id, :text, :timestamp, :author, likes: []]

  @topic inspect(__MODULE__)

  def subscribe_global do
    Phoenix.PubSub.subscribe(Chatter.PubSub, @topic)
  end

  def subscribe_local(username) do
    Phoenix.PubSub.subscribe(Chatter.PubSub, "#{username}-messages")
  end

  def broadcast_change({:ok, result}, event, topic \\ @topic) do
    Phoenix.PubSub.broadcast(Chatter.PubSub, topic, {__MODULE__, event, result})
    {:ok, result}
  end

  def broadcast_change({:error, changeset}, _event, _topic), do: {:error, changeset}

  def changeset(struct, params) do
    {struct, @types}
    |> cast(params, Map.keys(@types))
    |> validate_length(:text, min: 3, max: 100)
  end

  def change_message(%Chatter.Message{} = message, attrs \\ %{}) do
    Chatter.Message.changeset(message, attrs)
  end

  def create(params) do
    with message <- %Chatter.Message{id: Enum.count(MessageAgent.get()) + 1, text: params["text"], timestamp: Timex.now(), author: params["author"]} do
      broadcast_change({:ok, message}, {:message, :created})
      {:ok, message}
    end
  end
end
