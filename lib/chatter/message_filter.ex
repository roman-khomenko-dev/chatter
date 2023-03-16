defmodule Chatter.MessageFilter do
  @moduledoc """
  Describe messages filtering functionality
  """

  import Ecto.Query, warn: false
  alias Chatter.{Messages.Message, Repo, Search}

  def filter_by_params({search, nil = _filter_option, :id = _mode}),
    do: Enum.map(get_search_messages(search), fn message -> message.id end)

  def filter_by_params({search, nil = _filter_option, :full = _mode}),
    do: get_search_messages(search)

  def filter_by_params({search, filter_option, :id = _mode}) do
    {search, filter_option, :full}
    |> filter_by_params()
    |> Enum.map(fn message -> message.id end)
  end

  def filter_by_params({search, filter_option, :full = _mode}) do
    search_messages = get_search_messages(search)

    filter_option
    |> filter_by_option()
    |> Enum.filter(fn message -> message in search_messages end)
  end

  def filter_by_option(filter_option) do
    case filter_option do
      :with_likes_who_liked ->
        filter_with_likes_who_like()

      :without_likes_who_never_liked ->
        filter_without_likes_who_never_liked()

      :with_major_likes ->
        filter_with_major_likes()
    end
  end

  def get_search_messages(search) do
    {query, search} =
      {from(m in Message, as: :message, order_by: [desc: m.id]), convert_blank_text(search)}

    {query, search}
    |> filter()
    |> Repo.all()
  end

  def filter({query, %Search{text: nil, likes: nil} = _search}), do: query

  def filter({query, %Search{text: text, likes: nil} = _search}) do
    ilike_text = "%#{text}%"
    query |> where([m], ilike(m.text, ^ilike_text))
  end

  def filter({query, %Search{text: nil, likes_option: option, likes: likes_count} = _search}) do
    likes_condition = likes_condition(option, likes_count)
    query |> where([m], ^likes_condition)
  end

  def filter({query, %Search{text: text, likes_option: option, likes: likes_count} = _search}) do
    {likes_condition, ilike_text} = {likes_condition(option, likes_count), "%#{text}%"}

    query
    |> where([m], ilike(m.text, ^ilike_text))
    |> where([m], ^likes_condition)
  end

  defp filter_with_likes_who_like do
    from(m in Message, where: m.author in subquery(list_likes({true, false})))
    |> order_by([m], desc: m.id)
    |> Repo.all()
  end

  defp filter_without_likes_who_never_liked do
    from(m in Message, where: m.author not in subquery(list_likes({true, true})) and m.likes == [])
    |> order_by([m], desc: m.id)
    |> Repo.all()
  end

  defp filter_with_major_likes do
    get_total_likes()
    |> with_likes_percent()
    |> top_liked()
    |> sort_by_last_inserted()
  end

  defp sort_by_last_inserted(messages),
    do: messages |> Enum.sort_by(fn message -> message.inserted_at end, :desc)

  defp get_total_likes do
    {false, true}
    |> list_likes()
    |> Repo.all()
    |> Enum.count()
  end

  defp top_liked(with_likes_percent) do
    top_liked = %{messages: [], percentage: 0}

    Enum.reduce_while(with_likes_percent, top_liked, fn data, acc ->
      acc = %{
        acc
        | messages: [data.message | acc.messages],
          percentage: acc.percentage + data.likes_percent
      }

      if acc.percentage < 80, do: {:cont, acc}, else: {:halt, acc}
    end)
    |> Map.get(:messages)
  end

  defp with_likes_percent(total_likes) do
    from(m in Message,
      select: %{
        message: m,
        likes_percent:
          (type(fragment("cardinality(?)", m.likes), :float) / ^total_likes * 100)
          |> selected_as(:likes_percent)
      },
      order_by: [desc: selected_as(:likes_percent)]
    )
    |> Repo.all()
  end

  defp likes_condition(option, likes_count) do
    case option do
      ">=" -> dynamic([m], fragment("cardinality(?)", m.likes) >= ^likes_count)
      "<=" -> dynamic([m], fragment("cardinality(?)", m.likes) <= ^likes_count)
      "=" -> dynamic([m], fragment("cardinality(?)", m.likes) == ^likes_count)
    end
  end

  defp list_likes({uniqueness, empty}) do
    where = empty_likes_condition(empty)

    from(m1 in Message,
      distinct: ^uniqueness,
      select: %{likes: fragment("unnest(?)", m1.likes)},
      where: ^where
    )
  end

  defp empty_likes_condition(empty),
    do: if(empty == false, do: dynamic([m1], m1.likes != []), else: true)

  defp convert_blank_text(%{text: nil} = search), do: search

  defp convert_blank_text(search),
    do: if(byte_size(search.text) == 0, do: %{search | text: nil}, else: search)
end
