defmodule ChatterWeb.ChatLive.IndexTest do
  use ExUnit.Case
  use ChatterWeb.ConnCase
  import Phoenix.{LiveViewTest, Component}
  alias ChatterWeb.ChatLive.Index
  alias Chatter.{Message, MessageAgent, MessageFilter, Search}
  alias Chatter.UsernameSpace.Generator

  defp create_socket(_) do
    %{socket: %Phoenix.LiveView.Socket{}}
  end

  describe "user interaction" do
    setup [:create_socket]

    test "when page load default values provided", %{socket: socket} do
      socket = Index.assign_default(socket)

      assert socket.assigns.show_write == false
      assert socket.assigns.show_menu == false
      assert socket.assigns.changeset == Message.change_message(%Message{})
      assert socket.assigns.username != nil
      assert socket.assigns.search == Search.change_search(%Search{})
      assert Index.apply_search(socket) == %Chatter.Search{}
    end

    test "message validation, likes operation and search goes right", %{
      socket: socket,
      conn: conn
    } do
      MessageAgent.clear()
      socket = Index.assign_default(socket)
      {:ok, view, _html} = live(conn, "/")

      assert render_change(view, :validate, %{message: %{"text" => "Hi"}}) =~
               "should be at least 3 character(s)"

      view
      |> form("#message-form", %{message: %{"text" => "Greetings"}})
      |> render_submit()

      message = List.first(MessageAgent.get())
      assert message.text == "Greetings"

      render_click(view, :like, %{
        "id" => Integer.to_string(message.id),
        "user" => socket.assigns.username
      })

      assert List.first(MessageAgent.get()).likes == [socket.assigns.username]

      render_click(view, :like, %{
        "id" => Integer.to_string(message.id),
        "user" => socket.assigns.username
      })

      assert MessageAgent.get_all_likes() == []

      view
      |> form("#message-form", %{message: %{"text" => "Hello"}})
      |> render_submit()

      socket = assign(socket, messages: MessageAgent.get())
      assert Enum.count(socket.assigns.messages) == 2

      search = Search.change_search(%Search{text: "Greet", likes_option: "=", likes: 0})
      socket = assign(socket, search: search)

      {messages, all_likes} = {MessageAgent.get(), MessageAgent.get_all_likes()}

      assert {Index.apply_search(socket), socket.assigns.filter_option}
             |> shown_filter_messages({messages, all_likes}) == 1
    end

    test "using the advanced message filter happens correctly", %{socket: socket, conn: conn} do
      MessageAgent.clear()
      socket = Index.assign_default(socket)
      {:ok, view, _html} = live(conn, "/")

      Enum.each(1..5, fn step ->
        view
        |> form("#message-form", %{
          message: %{"text" => "Message #{step}", author: elem(Generator.run(), 1)}
        })
        |> render_submit()
      end)

      message_authors =
        Enum.map(MessageAgent.get(), fn message -> %{id: message.id, author: message.author} end)

      socket = assign(socket, messages: MessageAgent.get())

      render_click(view, :like, %{
        "id" => Integer.to_string(Enum.at(message_authors, 0).id),
        "user" => Enum.at(message_authors, 1).author
      })

      render_click(view, :like, %{
        "id" => Integer.to_string(Enum.at(message_authors, 1).id),
        "user" => Enum.at(message_authors, 0).author
      })

      {messages, all_likes} = {MessageAgent.get(), MessageAgent.get_all_likes()}

      socket = Index.assign_filter_option(socket, :with_likes_who_liked)

      assert {Index.apply_search(socket), :with_likes_who_liked}
             |> shown_filter_messages({messages, all_likes}) == 2

      socket = Index.assign_filter_option(socket, :without_likes_who_never_liked)

      assert {Index.apply_search(socket), :without_likes_who_never_liked}
             |> shown_filter_messages({messages, all_likes}) == 3

      Enum.each(2..4, fn message_index ->
        render_click(view, :like, %{
          "id" => Integer.to_string(Enum.at(message_authors, 1).id),
          "user" => Enum.at(message_authors, message_index).author
        })
      end)

      socket = Index.assign_filter_option(socket, :with_major_likes)

      assert {Index.apply_search(socket), :with_major_likes}
             |> shown_filter_messages({messages, all_likes}) == 1
    end
  end

  defp shown_filter_messages(params, messages) do
    params
    |> MessageFilter.filter_by_params(messages)
    |> Enum.count()
  end
end
