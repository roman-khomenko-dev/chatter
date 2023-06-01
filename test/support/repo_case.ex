defmodule Chatter.RepoCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Chatter.Repo

      import Ecto
      import Ecto.Query
      import Chatter.RepoCase
    end
  end
end
