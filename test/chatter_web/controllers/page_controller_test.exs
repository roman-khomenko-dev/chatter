defmodule ChatterWeb.PageControllerTest do
  @moduledoc false

  use ChatterWeb.ConnCase
  use Chatter.RepoCase

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "[Write a new message]"
  end
end
