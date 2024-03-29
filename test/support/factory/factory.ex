defmodule Chatter.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: Chatter.Repo
  alias Chatter.{Messages.Message, UsernameSpace.Generator}
  alias Faker

  def message_factory(attrs) do
    message = %Message{
      id: Mongo.object_id() |> BSON.ObjectId.encode!(),
      text: Faker.Lorem.sentence(5),
      author: Generator.run() |> elem(1),
      likes: [],
      inserted_at: DateTime.now!("Etc/UTC"),
      updated_at: DateTime.now!("Etc/UTC")
    }

    # merge attributes and evaluate lazy attributes at the end to emulate
    # ExMachina's default behavior
    message
    |> merge_attributes(attrs)
    |> evaluate_lazy_attributes()
  end
end
