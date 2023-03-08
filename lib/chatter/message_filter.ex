defmodule Chatter.MessageFilter do
  @moduledoc """
  Describe messages filtering functionality
  """

  alias Chatter.{MessageAgent, Search}

  def filter_by_params({search, nil = _filter_option}), do: get_search_messages(search)

  def filter_by_params({search, filter_option}) do
    search_messages = get_search_messages(search)
    filter_option
      |> filter_by_option()
      |> Enum.filter(fn message -> message in search_messages end)
  end

  def filter_by_option(filter_option) do
    case filter_option do
      :with_likes_who_liked -> filter_with_likes_who_like()
      :without_likes_who_never_liked -> filter_without_likes_who_never_liked()
      :with_major_likes -> filter_with_major_likes()
    end
  end

  def get_search_messages(search), do: Enum.filter(MessageAgent.get(), &filter(&1, search))

  def filter(message, search) do
    filter_text(message, search) && filter_likes(message, search)
  end

  defp filter_text(message, %Search{text: nil} = _search), do: message

  defp filter_text(message, %Search{text: search_text} = _search), do: message.text =~ search_text

  defp filter_likes(message, %{likes: nil} = _search), do: message

  defp filter_likes(message, %{likes_option: option, likes: likes_count} = _search) do
    case option do
      ">=" -> Enum.count(message.likes) >= likes_count
      "<=" -> Enum.count(message.likes) <= likes_count
      "=" -> Enum.count(message.likes) == likes_count
    end
  end

  defp filter_with_likes_who_like do
    all_likes = MessageAgent.get_all_likes()
    Enum.filter(MessageAgent.get(), fn message ->
      if Enum.count(message.likes) > 0 && message.author in all_likes, do: message
    end)
  end

  defp filter_without_likes_who_never_liked do
    all_likes = MessageAgent.get_all_likes()
    Enum.filter(MessageAgent.get(), fn message ->
      if Enum.empty?(message.likes) && message.author not in all_likes, do: message
    end)
  end

  defp filter_with_major_likes do
    top_messages =
      {MessageAgent.get(), Enum.count(MessageAgent.get_all_likes())}
      |> with_likes_percent()
      |> Enum.sort_by(&Map.fetch(&1, :likes_percent), :desc)
      |> top_liked()

    Enum.filter(MessageAgent.get(), fn message -> message.id in top_messages.ids end)
  end

  defp top_liked(messages) do
    messages
    |> Enum.reduce_while(%{ids: [], percent: 0}, fn message_info, acc ->
      acc = %{
        acc
        | ids: acc.ids ++ [message_info.id],
          percent: acc.percent + message_info.likes_percent
      }

      if acc.percent < 80.0, do: {:cont, acc}, else: {:halt, acc}
    end)
  end

  defp with_likes_percent({messages, likes_summary}) do
    messages
    |> Enum.reduce([], fn message, acc ->
        [
          %{
            id: message.id,
            likes_percent:
              message.likes
              |> Enum.count()
              |> calculate_likes_percent(likes_summary)
          } | acc
        ]
    end)
    |> Enum.reverse()
  end

  defp calculate_likes_percent(_message_likes, 0 = _likes_summary), do: 0

  defp calculate_likes_percent(message_likes, likes_summary) do
    message_likes
    |> Decimal.div(likes_summary)
    |> Decimal.to_float()
    |> Kernel.*(100)
  end
end
