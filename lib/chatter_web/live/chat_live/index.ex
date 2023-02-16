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
  end

  defp assign_search_messages(socket) do
    assign(socket,
      messages:
        socket.assigns.search
        |> apply_changes
        |> get_filtered_messages
    )
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

  defp filter_text(message, search) do
    if String.length(search.text) > 0, do: message.text =~ search.text, else: message
  end

  defp filter_likes(message, %{likes: nil} = _search), do: message

  defp filter_likes(message, %{likes_option: option, likes: count} = _search) do
    case option do
      ">=" -> length(message.likes) >= count
      "<=" -> length(message.likes) <= count
      "=" -> length(message.likes) == count
    end
  end
end
