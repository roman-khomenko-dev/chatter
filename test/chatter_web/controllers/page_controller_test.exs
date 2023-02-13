defmodule ChatterWeb.PageControllerTest do
  use ChatterWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "[Write a new message]"
  end
end
