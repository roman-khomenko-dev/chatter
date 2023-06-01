defmodule Chatter.MessageFilter do
  @moduledoc """
  Describe messages filtering functionality
  """

  import Ecto.Query, warn: false
  alias Mongo.Ecto.Helpers
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
    search_messages = search |> get_search_messages() |> Enum.map(&Map.get(&1, :id))

    filter_option
    |> filter_by_option()
    |> Enum.filter(fn message -> message.id in search_messages end)
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
    text_regex = Helpers.regex("#{text}")

    query
    |> where(fragment(text: ["$regex": ^text_regex, "$options": "i"]))
  end

  def filter({query, %Search{text: nil, likes_option: option, likes: likes_count} = _search}) do
    query |> filter_likes_condition(option, likes_count)
  end

  def filter({query, %Search{text: text, likes_option: option, likes: likes_count} = _search}) do
    text_regex = Helpers.regex("#{text}")

    query
    |> where(fragment(text: ["$regex": ^text_regex, "$options": "i"]))
    |> filter_likes_condition(option, likes_count)
  end

  defp filter_with_likes_who_like do
    list_likes = list_likes()

    from(m in Message, where: m.author in ^list_likes)
    |> order_by([m], desc: m.id)
    |> Repo.all()
  end

  defp filter_without_likes_who_never_liked do
    list_likes = list_likes()

    from(m in Message, where: m.author not in ^list_likes and m.likes == [])
    |> order_by([m], desc: m.id)
    |> Repo.all()
  end

  defp filter_with_major_likes do
    get_total_likes()
    |> top_liked()
    |> Message.convert_query_result()
  end

  defp get_total_likes do
    Mongo.aggregate(:mongo, "messages", [
      %{
        "$project" => %{
          "likes_count" => %{"$size" => "$likes"}
        }
      },
      %{
        "$group" => %{
          "_id" => "null",
          "total_likes" => %{"$sum" => "$likes_count"}
        }
      }
    ])
    |> extract_query_data()
    |> Map.get("total_likes")
  end

  defp top_liked(total_likes) do
    Mongo.aggregate(:mongo, "messages", [
      %{
        "$addFields" => %{
          "message_total_likes" => %{
            "$size" => "$likes"
          }
        }
      },
      %{
        "$addFields" => %{
          "likes_percentage" => %{
            "$multiply" => [
              %{
                "$divide" => [100, total_likes]
              },
              "$message_total_likes"
            ]
          }
        }
      },
      %{
        "$sort" => %{
          "likes_percentage" => -1
        }
      },
      %{
        "$group" => %{
          "_id" => nil,
          "messages" => %{
            "$accumulator" => %{
              "init" => "function() {
                return {
                  likes_percentage_sum: 0,
                  selected_messages: []
                };
              }",
              "accumulateArgs" => ["$likes_percentage", "$$ROOT"],
              "accumulate" => "function(state, likesPercentage, message) {
                if (state.likes_percentage_sum < 80) {
                  state.likes_percentage_sum += likesPercentage;
                  state.selected_messages.push(message);
                }
                return state;
              }",
              "merge" => "function(state1, state2) {
                if (state1.likes_percentage_sum >= 80) {
                  return state1;
                }
                const merged = {
                  likes_percentage_sum: state1.likes_percentage_sum + state2.likes_percentage_sum,
                  selected_messages: state1.selected_messages.concat(state2.selected_messages)
                };
                return merged;
              }",
              "finalize" => "function(state) {
                return state.selected_messages;
              }",
              "lang" => "js"
            }
          }
        }
      },
      %{
        "$unwind" => "$messages"
      },
      %{
        "$replaceRoot" => %{
          "newRoot" => "$messages"
        }
      },
      %{
        "$project" => %{
          "_id" => 1,
          "text" => 1,
          "author" => 1,
          "likes" => 1,
          "inserted_at" => 1,
          "updated_at" => 1
        }
      },
      %{
        "$sort" => %{
          "inserted_at" => -1
        }
      }
    ])
    |> extract_query_data(:list)
  end

  defp filter_likes_condition(query, ">=", likes_count) do
    size = %{"$size": "$likes"}
    where(query, fragment("$expr": ["$gte": [^size, ^likes_count]]))
  end

  defp filter_likes_condition(query, "<=", likes_count) do
    size = %{"$size": "$likes"}
    where(query, fragment("$expr": ["$lte": [^size, ^likes_count]]))
  end

  defp filter_likes_condition(query, "=", likes_count) do
    size = %{"$size": "$likes"}
    where(query, fragment("$expr": ["$eq": [^size, ^likes_count]]))
  end

  defp list_likes do
    Mongo.aggregate(:mongo, "messages", [
      %{
        "$unwind" => %{
          "path" => "$likes"
        }
      },
      %{
        "$group" => %{
          "_id" => false,
          "likes" => %{
            "$addToSet" => "$likes"
          }
        }
      },
      %{
        "$project" => %{
          "_id" => 0,
          "likes" => 1
        }
      }
    ])
    |> extract_query_data()
    |> Map.get("likes")
  end

  defp extract_query_data(query, mode \\ :element)

  defp extract_query_data(query, :list), do: query |> Enum.to_list()

  defp extract_query_data(query, :element), do: query |> Enum.to_list() |> List.first()

  defp convert_blank_text(%{text: nil} = search), do: search

  defp convert_blank_text(search),
    do: if(byte_size(search.text) == 0, do: %{search | text: nil}, else: search)
end
