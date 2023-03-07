defmodule MessagesComponent do
  @moduledoc """
  Define message component
  """

  use ChatterWeb, :live_component

  def render(assigns) do
    ~H"""
    <div id="messages" phx-update="stream">
        <div :for={message <- @messages} class="card col-10 mx-auto d-block my-5 shadow mb-5 bg-white rounded" id={elem(message,0)}>
            <div class="card-body">
                <p class="card-text">
                    <%= elem(message, 1).text %>
                </p>
            </div>
            <div class="card-footer">
                <small class="text-muted row">
                <span class="col col-sm">
                        Written at <%= elem(Timex.format(elem(message, 1).timestamp, "%Y-%m-%d %H:%M:%S", :strftime),1) %> by
                        <%= "<#{elem(message, 1).author}>" %>
                    </span>
                    <span class="col col-1">
                        <a id={"like-#{elem(message, 1).id}"} class="like-icon ms-2" phx-value-id={elem(message, 1).id} phx-value-user={@username} data-toggle="tooltip" data-placement="top" title={Enum.map(elem(message, 1).likes, fn like -> like <> "\n" end)} phx-update="ignore" phx-click="like">
                            <%= Bootstrap.Icons.star_fill()%>
                        </a>
                        <%= length(elem(message, 1).likes) %>
                    </span>
                </small>
            </div>
        </div>
    </div>
    """
  end
end
