defmodule Chatter.RepoCase do
  @moduledoc false

  use ExUnit.CaseTemplate
  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      alias Chatter.Repo

      import Ecto
      import Ecto.Query
      import Chatter.RepoCase

    end
  end

  setup tags do
    Chatter.RepoCase.setup_sandbox(tags)
    :ok
  end

  def setup_sandbox(tags) do
    pid = Sandbox.start_owner!(Chatter.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
  end
end
