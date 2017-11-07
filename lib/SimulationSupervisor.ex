defmodule Server.SimulationSupervisor do 
    use Supervisor
    require Logger

    @reg_name :state_registry

    @doc """
    Starts the supervisor.
    """
    def start_link, do: Supervisor.start_link(__MODULE__, [], name: __MODULE__)

    def get_sim_process() do
        case Registry.lookup(@reg_name, 0) do
            [] -> {:error, :sim_not_started_yet}
            value -> value
        end
    end

    def start_sim() do
        Process.flag(:trap_exit, true)
        # create child
        case Supervisor.start_child(__MODULE__, []) do
            {:ok, pid} -> {:ok, pid}
            {:error, {:already_created, _pid}} -> {:error, :process_already_exists}
            other -> {:error, other}
        end
    end

    @doc false
    def init(_) do
        children = [
            worker(Server.Simulation, [], restart: :temporary)
        ]

        # strategy set to `:simple_one_for_one` to handle dynamic child processes.
        supervise(children, strategy: :one_for_one)
    end

end
