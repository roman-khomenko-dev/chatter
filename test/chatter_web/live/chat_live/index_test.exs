defmodule ChatterWeb.ChatLive.IndexTest do
  use ExUnit.Case
  use ChatterWeb.ConnCase
  import Phoenix.LiveViewTest
  alias ChatterWeb.ChatLive.Index
  alias Chatter.{Message, MessageAgent}

  defp create_socket(_) do
    %{socket: %Phoenix.LiveView.Socket{}}
  end

  describe "user interaction" do
    setup [:create_socket]

    test "when page load default values provided", %{socket: socket} do
      socket = Index.assign_default(socket)

      assert socket.assigns.messages == MessageAgent.get()
      assert socket.assigns.show == false
      assert socket.assigns.changeset == Message.change_message(%Message{})
      assert socket.assigns.username != nil
    end

    test "user create a message; validate, click like and unlike", %{socket: socket, conn: conn} do
      socket = Index.assign_default(socket)
      {:ok, view, _html} = live(conn, "/")

      assert render_change(view, :validate, %{message: %{"text" => "Hi"}}) =~ "should be at least 3 character(s)"

      view
      |> form("#message-form", %{message: %{"text" => "Greetings"}})
      |> render_submit()

      message = List.first(MessageAgent.get())
      assert message.text == "Greetings"

      render_click(view, :like, %{"uuid" => message.uuid, "user" => socket.assigns.username})
      assert List.first(MessageAgent.get()).likes == [socket.assigns.username]

      render_click(view, :like, %{"uuid" => message.uuid, "user" => socket.assigns.username})
      assert List.first(MessageAgent.get()).likes == []
    end
  end
end
