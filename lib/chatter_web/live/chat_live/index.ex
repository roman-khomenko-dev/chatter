defmodule ChatterWeb.ChatLive.Index do
  use ChatterWeb, :live_view

  alias Chatter.{Message, MessageAgent, UsernameSpace.Generator}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Message.subscribe()
    {:ok, assign_default(socket)}
  end

  @impl true
  def handle_info({Message, {:message, _action}, _message}, socket) do
    {:noreply, assign(socket, messages: MessageAgent.get())}
  end

  @impl true
  def handle_event("validate", %{"message" => params}, socket) do
    changeset =
      %Message{}
      |> Message.change_message(params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> activate_show()
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
  def handle_event("like", %{"uuid" => uuid, "user" => user} = _params, socket) do
    MessageAgent.set_like(MessageAgent, {uuid, user})
    {:noreply, socket}
  end

  def assign_default(socket) do
    socket
    |> assign(show: false)
    |> assign(messages: MessageAgent.get())
    |> assign(changeset: Message.change_message(%Message{}))
    |> assign(username: elem(Generator.run(), 1))
  end

  defp activate_show(socket),
    do:
      if(socket.assigns.show == false,
        do: assign(socket, show: !socket.assigns.show),
        else: socket
      )
end
