defmodule Server.PlayerSupervisor do
    use Supervisor
    require Logger 
    @moduledoc """
    Supervisor to handle the creation of dynamic `Server.Player` processes using a 
    `simple_one_for_one` strategy. See the `init` callback at the bottom for details on that.

    These processes will spawn for each `player_id` provided to the 
    `Server.Player.start_link` function.

    Functions contained in this supervisor module will assist in the creation and retrieval of 
    new player processes.

    Also note the guards utilizing `is_integer(player_id)` on the functions. My feeling here is that
    if someone makes a mistake and tries sending a string-based key or an atom, I'll just _"let it crash"_.
    """

    @player_registry_name :player_process_registry

    @doc """
    Starts the supervisor.
    """
    def start_link, do: Supervisor.start_link(__MODULE__, [], name: __MODULE__)

    @doc """
    Will find the process identifier (in our case, the `player_id`) if it exists in the registry and
    is attached to a running `Server.Player` process.

    If the `player_id` is not present in the registry, it will create a new `Server.Player` 
    process and add it to the registry for the given `player_id`.

    Returns a tuple such as `{:ok, player_id}` or `{:error, reason}`
    """
    def find_or_create_process(player_id) do
        if player_process_exists?(player_id) do
            {:ok, player_id}
        else
            {:error}
            # player_id |> create_player_process
        end
    end
    
    @doc """
    Determines if a `Server.Player` process exists, based on the `player_id` provided.
    Returns a boolean.

    ## Example
        iex> RegistrySample.PlayerSupervisor.player_process_exists?(6)
        false
    """
    def player_process_exists?(player_id) do
        case Registry.lookup(@player_registry_name, player_id) do
            [] -> false
            _ -> true
        end
    end

    @doc """
    Creates a new player process, based on the `player_id`.

    Returns a tuple such as `{:ok, player}` if successful.
    If there is an issue, an `{:error, reason}` tuple is returned.
    """
    def create_player_process(player_id, socket) do
        # create buffer
        {:ok, buffer_pid} = Buffer.create() # <--- this is next
        Process.flag(:trap_exit, true)
        # create child
        case Supervisor.start_child(__MODULE__, [player_id, socket]) do
            {:ok, _pid} -> {:ok, player_id}
            {:error, {:already_created, _pid}} -> {:error, :process_already_exists}
            other -> {:error, other}
        end
    end

    @doc """
    Returns the count of `Server.Player` processes managed by this supervisor.
    ## Example
        iex> Server.PlayerSupervisor.player_process_count
        0
    """
    def player_process_count, do: Supervisor.which_children(__MODULE__) |> length

    @doc """
    Return a list of `player_id` integers known by the registry.

    ex - `[1, 23, 46]`
    """
    def player_ids do
        Supervisor.which_children(__MODULE__)
        |> Enum.map(fn {_, player_proc_pid, _, _} ->
            Registry.keys(@player_registry_name, player_proc_pid)
            |> List.first
        end)
        |> Enum.sort
    end

    @doc false
    def init(_) do
        children = [
            worker(Server.Player, [], restart: :temporary)
        ]

        # strategy set to `:simple_one_for_one` to handle dynamic child processes.
        supervise(children, strategy: :simple_one_for_one)
    end
    
end