defmodule ChatWeb.LiveHelpers do
  @moduledoc false

  def classes(%{} = optionals), do: classes([], optionals)
  def classes(constants), do: classes(constants, %{})

  def classes(nil, optionals), do: classes([], optionals)

  def classes("" <> constant, optionals) do
    classes([constant], optionals)
  end

  def classes(constants, optionals) do
    [
      constants,
      optionals
      |> Enum.filter(&elem(&1, 1))
      |> Enum.map(&elem(&1, 0))
    ]
    |> Enum.concat()
    |> Enum.join(" ")
  end
end
