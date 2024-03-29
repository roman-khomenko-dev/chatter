defmodule Chatter.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      ChatterWeb.Telemetry,
      # Start the Ecto repository
      Chatter.Repo,
      # Start MongoDB provider
      {Mongo, [name: :mongo, database: Application.get_env(:chatter, :db)[:name], pool_size: 5]},
      # Start the PubSub system
      {Phoenix.PubSub, name: Chatter.PubSub},
      # Start the Endpoint (http/https)
      ChatterWeb.Endpoint
      # Start a worker by calling: Chatter.Worker.start_link(arg)
      # {Chatter.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Chatter.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ChatterWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
