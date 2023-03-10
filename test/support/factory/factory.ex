defmodule Chatter.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: Chatter.Repo
  alias Chatter.{Messages.Message, UsernameSpace.Generator}
  alias Faker

  def message_factory(attrs) do
    message = %Message{
      id: sequence(:id, fn number -> number end),
      text: Faker.Lorem.sentence(5),
      author: Generator.run() |> elem(1),
      likes: [],
      inserted_at: DateTime.now("Etc/UTC") |> elem(1),
      updated_at: DateTime.now("Etc/UTC") |> elem(1)
    }

    # merge attributes and evaluate lazy attributes at the end to emulate
    # ExMachina's default behavior
    message
    |> merge_attributes(attrs)
    |> evaluate_lazy_attributes()
  end
end
