defmodule ChatterWeb.ChatLive.Index do
  use ChatterWeb, :live_view

  alias Chatter.{Message, MessageAgent, UsernameSpace.Generator, Search}
  import Ecto.Changeset

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Message.subscribe()
    {:ok, assign_default(socket)}
  end

  @impl true
  def handle_info({Message, {:message, _action}, _message}, socket) do
    {:noreply, assign_search_messages(socket)}
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
    with {:ok, search} <- Search.create(params) do
      {:noreply,
       socket
       |> assign(messages: get_filtered_messages(search))
       |> assign(search: Search.change_search(%Search{}, params))
       |> activate_show("show_menu")}
    end
  end

  @impl true
  def handle_event("filter_option", %{"option" => option} = _params, socket) do
    option = String.to_atom(option)

    {:noreply,
     socket
     |> assign_filter_option(option)
     |> assign_filter_option_messages()
     |> activate_show("show_menu")}
  end

  @impl true
  def handle_event("close_menu", _params, socket) do
    {:noreply, assign(socket, show_menu: false)}
  end

  @impl true
  def handle_event("like", %{"uuid" => uuid, "user" => user} = _params, socket) do
    MessageAgent.set_like(MessageAgent, {uuid, user})

    {:noreply, assign_search_messages(socket)}
  end

  def assign_default(socket) do
    socket
    |> assign(show_write: false)
    |> assign(show_menu: false)
    |> assign(messages: MessageAgent.get())
    |> assign(changeset: Message.change_message(%Message{}))
    |> assign(username: elem(Generator.run(), 1))
    |> assign(search: Search.change_search(%Search{}))
    |> assign(filter_option: nil)
  end

  defp assign_search_messages(socket) do
    assign(socket,
      messages:
        socket.assigns.search
        |> apply_changes
        |> get_filtered_messages
    )
  end

  defp assign_filter_option_messages(socket) when socket.assigns.filter_option != nil do
    assign(socket, messages: filter_messages_by_option(socket.assigns.filter_option))
  end

  defp assign_filter_option_messages(socket) when is_nil(socket.assigns.filter_option) do
    assign_search_messages(socket)
  end

  defp assign_filter_option(socket, option) do
    if socket.assigns.filter_option == option,
      do: assign(socket, filter_option: nil),
      else: assign(socket, filter_option: option)
  end

  defp activate_show(socket, "show_write") do
    if socket.assigns.show_write == false, do: assign(socket, show_write: true), else: socket
  end

  defp activate_show(socket, "show_menu") do
    if socket.assigns.show_menu == false, do: assign(socket, show_menu: true), else: socket
  end

  defp get_filtered_messages(search) do
    Enum.filter(MessageAgent.get(), &filter_message(&1, search))
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

  defp filter_messages_by_option(option) do
    case option do
      :with_likes_who_liked -> filter_with_likes_who_like()
      :without_likes_who_never_liked -> filter_without_likes_who_never_liked()
      :with_major_likes -> filter_with_major_likes()
    end
  end

  defp filter_with_likes_who_like do
    Enum.filter(MessageAgent.get(), fn message ->
      if Enum.count(message.likes) > 0 && message.author in MessageAgent.get_all_likes(),
        do: message
    end)
  end

  defp filter_without_likes_who_never_liked do
    Enum.filter(MessageAgent.get(), fn message ->
      if Enum.empty?(message.likes) && message.author not in MessageAgent.get_all_likes(),
        do: message
    end)
  end

  defp filter_with_major_likes do
    top_messages =
      {MessageAgent.get(), Enum.count(MessageAgent.get_all_likes())}
      |> messages_with_likes_percent()
      |> Enum.sort_by(&Map.fetch(&1, :likes_percent), :desc)
      |> top_liked_messages()

    Enum.filter(MessageAgent.get(), fn message -> message.uuid in top_messages.uuids end)
  end

  defp top_liked_messages(messages) do
    messages
    |> Enum.reduce_while(%{uuids: [], percent: 0}, fn message_info, acc ->
      acc = %{
        acc
        | uuids: acc.uuids ++ [message_info.uuid],
          percent: acc.percent + message_info.likes_percent
      }

      if acc.percent < 80.0, do: {:cont, acc}, else: {:halt, acc}
    end)
  end

  defp messages_with_likes_percent({messages, likes_summary}) do
    messages
    |> Enum.reduce([], fn message, acc ->
      acc ++
        [
          %{
            uuid: message.uuid,
            likes_percent:
              message.likes
              |> Enum.count()
              |> calculate_likes_percent(likes_summary)
          }
        ]
    end)
  end

  defp calculate_likes_percent(message_likes, likes_summary) do
    message_likes
    |> Decimal.div(likes_summary)
    |> Decimal.to_float()
    |> Kernel.*(100)
  end
end
