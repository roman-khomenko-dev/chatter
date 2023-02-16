defmodule Chatter.Search do
  import Ecto.Changeset

  @types %{text: :string, likes_option: :string, likes: :integer}
  defstruct [:text, :likes_option, :likes]

  def changeset(struct, params) do
    cast({struct, @types}, params, Map.keys(@types))
  end

  def change_search(%Chatter.Search{} = search, attrs \\ %{}) do
    Chatter.Search.changeset(search, attrs)
  end

  def create(params) do
    with search <- %Chatter.Search{
           text: params["text"],
           likes_option: params["likes_option"],
           likes: get_likes(params)
         } do
      {:ok, search}
    end
  end

  defp get_likes(%{"likes" => ""} = _params), do: nil

  defp get_likes(%{"likes" => likes} = _params), do: String.to_integer(likes)
end
