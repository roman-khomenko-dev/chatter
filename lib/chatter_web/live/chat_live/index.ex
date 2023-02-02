defmodule ChatterWeb.ChatLive.Index do
  use ChatterWeb, :live_view

  alias Chatter.Message

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Message.subscribe()
    {:ok, assign_default(socket)}
  end

  @impl true
  def handle_info({Message, {:message, _action}, message}, socket) do
    {:noreply, assign(socket, messages: [message | socket.assigns.messages])}
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
      {:ok, _message} -> {:noreply, socket}
      _error -> {:noreply, socket |> put_flash(:error, "Creation failed")}
    end
  end

  defp assign_default(socket) do
    socket
    |> assign(show: false)
    |> assign(messages: [])
    |> assign(:changeset, Message.change_message(%Message{}))
  end

  defp activate_show(socket),
    do:
      if(socket.assigns.show == false,
        do: assign(socket, show: !socket.assigns.show),
        else: socket
      )
end
