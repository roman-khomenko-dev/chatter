defmodule AdvancedFilterComponent do
  @moduledoc """
  Define messages advanced filter component
  """
  use ChatterWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="dropdown d-grid gap-2">
      <button class="btn btn-sm btn-dark dropdown-toggle" type="button" data-bs-toggle="dropdown" data-bs-auto-close="false" aria-expanded="false">
        Advanced filters
      </button>
      <ul class="dropdown-menu">
        <li><a class={"dropdown-item #{if @filter_option == :with_likes_who_liked do "active" end}"} phx-click="filter_option" phx-value-option="with_likes_who_liked">
          with likes of those who has liked other
        </a></li>
        <li><a class={"dropdown-item #{if @filter_option == :without_likes_who_never_liked do "active" end}"} phx-click="filter_option" phx-value-option="without_likes_who_never_liked">
          without likes of those who never liked other
        </a></li>
        <li><a class={"dropdown-item #{if @filter_option == :with_major_likes do "active" end}"} phx-click="filter_option" phx-value-option="with_major_likes">
          smallest number of more than 80% of all likes
        </a></li>
      </ul>
      <span :if={@filter_option != nil} class="text-muted text-center">
        <%= "<#{String.replace(to_string(@filter_option), "_", " ")}>" %>
      </span>
    </div>
    """
  end
end
