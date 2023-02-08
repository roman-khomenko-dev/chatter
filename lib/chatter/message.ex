defmodule Chatter.Message do
  @moduledoc """
  Describing of Message model
  """
  import Ecto.{Changeset, UUID}

  @types %{uuid: :string, text: :string, timestamp: DateTime, author: :string, likes: :array}
  defstruct [:uuid, :text, :timestamp, :author, likes: []]

  @topic inspect(__MODULE__)

  def subscribe do
    Phoenix.PubSub.subscribe(Chatter.PubSub, @topic)
  end

  def broadcast_change({:ok, result}, event) do
    Phoenix.PubSub.broadcast(Chatter.PubSub, @topic, {__MODULE__, event, result})
    {:ok, result}
  end

  def broadcast_change({:error, changeset}, _event), do: {:error, changeset}

  def changeset(struct, params) do
    {struct, @types}
    |> cast(params, Map.keys(@types))
    |> validate_length(:text, min: 3, max: 100)
  end

  def change_message(%Chatter.Message{} = message, attrs \\ %{}) do
    Chatter.Message.changeset(message, attrs)
  end

  def create(params) do
    with message <- %Chatter.Message{uuid: Ecto.UUID.generate(), text: params["text"], timestamp: Timex.now(), author: params["author"]} do
      broadcast_change({:ok, message}, {:message, :created})
      {:ok, message}
    end
  end
end
