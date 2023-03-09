defmodule Chatter.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages) do
      add :text, :string, null: false
      add :author, :string, null: false
      add :likes, {:array, :string}, default: []

      timestamps()
    end
  end
end
