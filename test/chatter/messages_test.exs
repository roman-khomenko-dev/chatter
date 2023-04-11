defmodule Chatter.MessagesTest do
  @moduledoc false

  use ChatterWeb.ConnCase
  use Chatter.RepoCase

  alias Chatter.Messages

  describe "messages" do
    alias Chatter.Messages.Message

    import Chatter.Factory

    @invalid_attrs %{text: Faker.Lorem.characters(2)}

    test "list_messages/0 returns all messages" do
      Mongo.Ecto.truncate(Chatter.Repo)
      message = insert(:message)
      assert Messages.list_messages() == [message]
    end

    test "get_message!/1 returns the message with given id" do
      message = insert(:message)
      assert Messages.get_message!(message.id) == message
    end

    test "create_message/1 with valid data creates a message" do
      valid_attrs = params_for(:message)

      assert {:ok, %Message{} = _message} = Messages.create_message(valid_attrs)
    end

    test "create_message/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Messages.create_message(@invalid_attrs)
    end

    test "update_message/2 with valid data updates the message" do
      message = insert(:message)
      update_attrs = %{text: Faker.Lorem.sentence(4)}

      assert {:ok, %Message{} = _message} = Messages.update_message(message, update_attrs)
    end

    test "update_message/2 with invalid data returns error changeset" do
      message = insert(:message)
      assert {:error, %Ecto.Changeset{}} = Messages.update_message(message, @invalid_attrs)
      assert message == Messages.get_message!(message.id)
    end

    test "delete_message/1 deletes the message" do
      message = insert(:message)
      assert {:ok, %Message{}} = Messages.delete_message(message)
      assert_raise Ecto.NoResultsError, fn -> Messages.get_message!(message.id) end
    end

    test "change_message/1 returns a message changeset" do
      message = insert(:message)
      assert %Ecto.Changeset{} = Messages.change_message(message)
    end
  end
end
