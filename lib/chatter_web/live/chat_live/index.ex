defmodule ChatterWeb.ChatLive.Index do
  use ChatterWeb, :live_view

  alias Chatter.{Message, MessageAgent, UsernameSpace.Generator, Search}
  import Ecto.Changeset

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Message.subscribe_global()
    socket =
      socket
      |> assign_default()
      |> assign_messages()

    subscribe_local_messages(socket)
    {:ok, socket}
  end

  @impl true
  def handle_info({Message, {:message, :created}, message}, socket) do
    {message, socket} |> created_response()
  end

  @impl true
  def handle_info({Message, {:message, :updated}, message}, socket) do
    {:noreply, stream_insert(socket, :messages, message, at: -1)}
  end

  @impl true
  def handle_info({Message, {:message, :removed}, message}, socket) do
    {:noreply, stream_delete(socket, :messages, message)}
  end

  @impl true
  def handle_event("validate", %{"message" => params}, socket) do
    changeset =
      %Message{}
      |> Message.change_message(params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> activate_show("show_write")
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"message" => params}, socket) do
    case Message.create(params) do
      {:ok, message} ->
        MessageAgent.add(message)
        {:noreply, assign(socket, changeset: Message.change_message(%Message{}))}

      _error ->
        {:noreply, socket |> put_flash(:error, "Creation failed")}
    end
  end

  @impl true
  def handle_event("search", %{"search" => params}, socket) do
    with {:ok, search} <- Search.create(params),
      search_messages <- user_shown_messages({search, socket.assigns.filter_option}) do
      broadcast_filtered_message(search_messages, socket.assigns.username)

      {:noreply,
       socket
       |> assign(search: Search.change_search(%Search{}, params))
       |> activate_show("show_menu")}
    end
  end

  @impl true
  def handle_event("filter_option", %{"option" => option} = _params, %{assigns: %{username: username}} = socket) do
    {option, search} = {String.to_existing_atom(option), apply_search(socket)}

    socket =
      socket
      |> assign_filter_option(option)
      |> activate_show("show_menu")

    {search, socket.assigns.filter_option}
    |> user_shown_messages()
    |> broadcast_filtered_message(username)

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_menu", _params, socket) do
    {:noreply, assign(socket, show_menu: false)}
  end

  @impl true
  def handle_event("like", %{"id" => id, "user" => user} = _params, socket) do
    MessageAgent.set_like(MessageAgent, {String.to_integer(id), user})

    {:noreply, socket}
  end

  def assign_default(socket) do
    socket
    |> assign(show_write: false)
    |> assign(show_menu: false)
    |> assign(changeset: Message.change_message(%Message{}))
    |> assign(username: elem(Generator.run(), 1))
    |> assign(:search, Search.change_search(%Search{}))
    |> assign(filter_option: nil)
  end

  def assign_messages(socket) do
    stream(socket, :messages, MessageAgent.get())
  end

  defp created_response({message, socket}) do
    search = apply_changes(socket.assigns.search)
    is_member =
      {search, socket.assigns.filter_option}
      |> user_shown_messages()
      |> Enum.member?(message)

    {is_member, message, socket} |> created_member_response()
  end

  defp created_member_response({false, _message, socket}), do: {:noreply, socket}

  defp created_member_response({true, message, socket}), do: {:noreply, stream_insert(socket, :messages, message, at: 0)}

  def user_shown_messages({search, nil = _filter_option}), do: get_search_messages(search)

  def user_shown_messages({search, filter_option}) do
    search_messages = get_search_messages(search)
    filter_option
      |> filter_messages_by_option()
      |> Enum.filter(fn message -> message in search_messages end)
  end

  def get_search_messages(search) do
    Enum.filter(MessageAgent.get(), &filter_message(&1, search))
  end

  def assign_filter_option(socket, option) do
    if socket.assigns.filter_option == option,
      do: assign(socket, filter_option: nil),
      else: assign(socket, filter_option: option)
  end

  def apply_search(socket), do: apply_changes(socket.assigns.search)

  defp activate_show(socket, "show_write") do
    if socket.assigns.show_write == false, do: assign(socket, show_write: true), else: socket
  end

  defp activate_show(socket, "show_menu") do
    if socket.assigns.show_menu == false, do: assign(socket, show_menu: true), else: socket
  end

  defp filter_message(message, search) do
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

  defp filter_messages_by_option(filter_option) do
    case filter_option do
      :with_likes_who_liked -> filter_with_likes_who_like()
      :without_likes_who_never_liked -> filter_without_likes_who_never_liked()
      :with_major_likes -> filter_with_major_likes()
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
      |> messages_with_likes_percent()
      |> Enum.sort_by(&Map.fetch(&1, :likes_percent), :desc)
      |> top_liked_messages()

    Enum.filter(MessageAgent.get(), fn message -> message.id in top_messages.ids end)
  end

  defp top_liked_messages(messages) do
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

  defp messages_with_likes_percent({messages, likes_summary}) do
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

  defp broadcast_filtered_message(filtered_messages, username) do
    Enum.each(MessageAgent.get(), fn message ->
      if message_in_filtered?(message, filtered_messages), do: broadcast_updated(message, username), else: broadcast_removed(message, username)
    end)
  end

  defp message_in_filtered?(message, filtered_messages), do: Enum.member?(filtered_messages, message)

  defp subscribe_local_messages(socket) when socket.assigns.username != nil, do: Message.subscribe_local(socket.assigns.username)

  defp broadcast_removed(message, username), do: Message.broadcast_change({:ok, message}, {:message, :removed}, "#{username}-messages")

  defp broadcast_updated(message, username), do: Message.broadcast_change({:ok, message}, {:message, :updated}, "#{username}-messages")
end
