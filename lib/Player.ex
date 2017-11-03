defmodule Server.Player do
    use GenServer
    require Logger

    @player_registry_name :player_process_registry

    # Just a simple struct to manage the state for this genserver
    # You could add additional attributes here to keep track of for a given account
    defstruct   player_id: 0,
                socket: nil,
                name: ""

    @doc """
    Starts a new account process for a given `account_id`.
    """
    def start_link(player_id, socket) do
        GenServer.start_link(__MODULE__, [player_id, socket], name: via_tuple(player_id))
    end

    defp via_tuple(player_id), do: {:via, Registry, {@player_registry_name, player_id}}

    @doc """
    Return some details (state) for this PState process
    """
    def get_state(player_id) do
        GenServer.call(via_tuple(player_id), :get_state)
    end

    @doc """
    Updates the process's state (PState)
    """
    def update_state(player_id, name) do
        GenServer.cast(via_tuple(player_id), {:update_state, name})
    end

    @doc """
    Calls player's Serve function with socket so it can start listening for packets
    """
    def start_serving(player_id, socket) do
        GenServer.cast(via_tuple(player_id), {:serve, socket})
    end

    @doc """
    Returns the pid for the `player_id` stored in the registry
    """
    def whereis(player_id) do
        case Registry.lookup(@player_registry_name, player_id) do
            [{pid, _}] -> pid
            [] -> nil
        end
    end

    @doc """
    Init callback
    """
    def init([player_id, socket]) do
        {:ok, %__MODULE__{ player_id: player_id, socket: socket }}
    end

    @doc """
    Receive messages from this players socket
    """
    def serve(socket, buffer_pid) do
        case :gen_tcp.recv(socket, 0) do
            {:ok, data} ->
                IO.inspect data
                buffer_pid = maybe_recreate_buffer(buffer_pid) # <-- coming up next
                Buffer.receive(buffer_pid, data)
                serve(socket, buffer_pid)
            {:error, reason} ->
                Logger.info("Socket terminating: #{inspect reason}")
        end
    end

    @doc """
    Recreate buffer if need be
    """
    defp maybe_recreate_buffer(original_pid) do
        receive do
            {:EXIT, ^original_pid, _reason} ->
            {:ok, new_buffer_pid} = Buffer.create()
            new_buffer_pid
        after
            10 ->
            original_pid
        end
    end

    @doc """
    Returns the current state for Player process that matches player_id
    """
    def handle_call(:get_state, _from, state) do

        # maybe you'd want to transform the state a bit...
        response = %{
            id: state.player_id,
            name: state.name
        }

        {:reply, response, state}
    end

    @doc false
    def handle_call({:update_state, name}, _from, state) do
        
        newState = Map.put(state, :name, name)

        {:reply, {:ok, newState}, newState}
    end

    @doc """
    Starts listening for packets on the given socket
    """
    def handle_cast({:serve, socket}, state) do
        {:ok, buffer_pid} = Buffer.create() # <--- this is next
        Process.flag(:trap_exit, true)
        serve(socket, buffer_pid)
    end

    @doc """
    Gracefully end this process
    """
    def handle_info(:end_process, state) do
        Logger.info("Process terminating... Account ID: #{state.account_id}")
        {:stop, :normal, state}
    end

end