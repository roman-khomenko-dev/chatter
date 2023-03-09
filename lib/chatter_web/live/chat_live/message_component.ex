defmodule MessageComponent do
  @moduledoc """
  Define message component
  """

  use ChatterWeb, :live_component

  def render(assigns) do
    ~H"""
    <div id="messages" phx-update="stream">
        <div :for={{message_id, message} <- @messages} class="card col-10 mx-auto d-block my-5 shadow mb-5 bg-white rounded" id={message_id}>
            <div class="card-body">
                <p class="card-text">
                    <%= message.text %>
                </p>
            </div>
            <div class="card-footer">
                <small class="text-muted row">
                <span class="col col-sm">
                        Written at <%= elem(Timex.format(message.timestamp, "%Y-%m-%d %H:%M:%S", :strftime),1) %> by
                        <%= "<#{message.author}>" %>
                    </span>
                    <span class="col col-1">
                        <a id={"like-#{message.id}"} class="like-icon ms-2" phx-value-id={message.id} phx-value-user={@username} data-toggle="tooltip" data-placement="top" title={Enum.map(message.likes, fn like -> like <> "\n" end)} phx-update="ignore" phx-click="like">
                            <%= Bootstrap.Icons.star_fill()%>
                        </a>
                        <%= length(message.likes) %>
                    </span>
                </small>
            </div>
        </div>
    </div>
    """
  end
end
