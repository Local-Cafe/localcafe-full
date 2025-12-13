defmodule LocalCafe.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      LocalCafeWeb.Telemetry,
      LocalCafe.Repo,
      LocalCafe.CH_Repo,
      {DNSCluster, query: Application.get_env(:local_cafe, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: LocalCafe.PubSub},
      # Analytics tracker for real-time dashboard
      LocalCafe.AnalyticsTracker,
      # Start a worker by calling: LocalCafe.Worker.start_link(arg)
      # {LocalCafe.Worker, arg},
      # Start to serve requests, typically the last entry
      LocalCafeWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LocalCafe.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LocalCafeWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
