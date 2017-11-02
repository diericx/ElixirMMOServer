defmodule Server do
  use Application
  @moduledoc """
  Documentation for Server.
  """

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(Registry, [:unique, :player_process_registry]),
      supervisor(Server.PlayerSupervisor, []),
      # Server.PlayerHandler,
      # Server.BucketSupervisor,
      Server.Receiver,
      Server.GameStateHandler,
      # Server.PlayerHandler,
      # TODO - Create supervisor for game state
      # worker(Server.MessageReceiver, []),
      # worker(Server.GameStateHandler, [])
    ]

    opts = [strategy: :one_for_all, name: Server.Supervisor]
    Supervisor.start_link(children, opts)
    
  end

end
