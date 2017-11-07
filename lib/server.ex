defmodule Server do
  use Application
  @moduledoc """
  Documentation for Server.
  """

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(Registry, [:unique, :player_process_registry], id: :player_process_registry),
      supervisor(Registry, [:unique, :state_registry], id: :state_registry),
      supervisor(Server.PlayerSupervisor, []),
      worker(Server.Receiver, []),
      worker(Server.Simulation, [])
    ]

    opts = [strategy: :one_for_all, name: Server.Supervisor]
    Supervisor.start_link(children, opts)
    
  end

end
