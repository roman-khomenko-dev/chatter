defmodule Chatter.UsernameSpace.Generator do
  @moduledoc """
  Describing of Message model
  """
  def run do
    with username <- get_data("characteristic") <> " " <> get_data("animal") do
      {:ok, username}
    end
  end

  defp get_data(type) when type in ["animal", "characteristic"] do
    with {:ok, content} <- File.read(get_path() <> "/" <> "#{type}.txt") do
      content
      |> String.split("\n", trim: true)
      |> Enum.random()
    end
  end

  defp get_path do
    Path.join(:code.priv_dir(:chatter), "static/username_space")
  end
end
