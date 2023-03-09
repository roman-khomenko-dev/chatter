defmodule ChatterWeb.ChatLive.Index do
  use ChatterWeb, :live_view

  alias Chatter.{Messages, Messages.Message, MessageAgent, UsernameSpace.Generator, Search, MessageFilter}
  import Ecto.Changeset

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Messages.subscribe_global()
    socket =
      socket
      |> assign_default()
      |> assign_messages()

    subscribe_local_messages(socket)
    {:ok, socket}
  end

  @impl true
  def handle_info({Messages, {:message, :created}, message}, socket) do
    message = Map.put(message, :likes, [])
    {message, socket} |> created_response()
  end

  @impl true
  def handle_info({Messages, {:message, :updated}, message}, socket) do
    {:noreply, stream_insert(socket, :messages, message, at: -1)}
  end

  @impl true
  def handle_info({Messages, {:message, :removed}, message}, socket) do
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
    with {:ok, message} <- Messages.create_message(params) do
      Messages.broadcast_change({:ok, message}, {:message, :created})
      {:noreply, assign(socket, changeset: Message.change_message(%Message{}))}
    end
  end

  @impl true
  def handle_event("search", %{"search" => params}, %{assigns: %{filter_option: filter_option, username: username}} = socket) do
    with {:ok, search} <- Search.create(params),
      search_messages <- MessageFilter.filter_by_params({search, filter_option, :full}) do
      broadcast_filtered_message(search_messages, username)

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

    {search, socket.assigns.filter_option, :full}
    |> MessageFilter.filter_by_params()
    |> broadcast_filtered_message(username)

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_menu", _params, socket) do
    {:noreply, assign(socket, show_menu: false)}
  end

  @impl true
  def handle_event("like", %{"id" => id, "user" => user} = _params, socket) do
    message = Messages.get_message!(id)
    {:ok, message} = message |> Messages.update_message(%{likes: proceed_like(message, user)})

    broadcast_updated(message, socket.assigns.username)

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
    stream(socket, :messages, Messages.list_messages())
  end

  defp created_response({message, socket}) do
    search = apply_changes(socket.assigns.search)
    is_member =
      {search, socket.assigns.filter_option, :id}
      |> MessageFilter.filter_by_params()
      |> Enum.member?(message.id)

    {is_member, message, socket} |> created_member_response()
  end

  defp created_member_response({false, _message, socket}), do: {:noreply, socket}

  defp created_member_response({true, message, socket}), do: {:noreply, stream_insert(socket, :messages, message, at: 0)}

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

  defp message_in_filtered?(message, filtered_messages), do: Enum.member?(filtered_messages, message)

  defp subscribe_local_messages(socket) when socket.assigns.username != nil, do: Messages.subscribe_local(socket.assigns.username)

  defp broadcast_filtered_message(filtered_messages, username) do
    Enum.each(Messages.list_messages(), fn message ->
      if message_in_filtered?(message, filtered_messages), do: broadcast_updated(message, username), else: broadcast_removed(message, username)
    end)
  end

  defp broadcast_removed(message, username), do: Messages.broadcast_change({:ok, message}, {:message, :removed}, "#{username}-messages")

  defp broadcast_updated(message, username), do: Messages.broadcast_change({:ok, message}, {:message, :updated}, "#{username}-messages")

  defp proceed_like(message, user), do: if Enum.member?(Map.get(message, :likes), user), do: remove_like(message, user), else: push_like(message, user)

  defp push_like(message, user) do
    [user | Map.get(message, :likes)]
  end

  defp remove_like(message, user) do
    List.delete(Map.get(message, :likes), user)
  end
end
