defmodule Server do
  use Application
  @moduledoc """
  Documentation for Server.
  """

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      {Server.Registry, name: Server.Registry},
      Server.BucketSupervisor,
      Server.MessageReceiver,
      Server.PlayerHandler,
      Server.GameStateHandler
    ]

    opts = [strategy: :one_for_all, name: Server.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
