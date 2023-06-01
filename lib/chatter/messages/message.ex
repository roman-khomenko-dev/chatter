defmodule Chatter.Messages.Message do
  @moduledoc """
  Message shema
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "messages" do
    field(:author, :string)
    field(:likes, {:array, :string}, default: [])
    field(:text, :string)

    timestamps()
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:text, :author, :likes])
    |> validate_required([:text, :author])
    |> validate_length(:text, min: 3, max: 100)
  end

  def change_message(%Chatter.Messages.Message{} = message, attrs \\ %{}) do
    changeset(message, attrs)
  end

  def convert_query_result(result) do
    Enum.map(result, fn message ->
      %Chatter.Messages.Message{
        id: message["_id"] |> BSON.ObjectId.encode!(),
        author: message["author"],
        likes: message["likes"],
        text: message["text"],
        inserted_at: message["inserted_at"],
        updated_at: message["updated_at"]
      }
    end)
  end
end
