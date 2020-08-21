defmodule SecretConfig.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {SecretConfig.Cache.Server, name: SecretConfig.Cache.Server}
    ]

    opts = [strategy: :one_for_one, name: SecretConfig.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
