defmodule Server.Player do
    use GenServer
    require Logger

    @player_registry_name :player_process_registry

    # Just a simple struct to manage the state for this genserver
    # You could add additional attributes here to keep track of for a given account
    defstruct   player_id: 0,
                name: ""

    @doc """
    Starts a new account process for a given `account_id`.
    """
    def start_link(player_id) do
        GenServer.start_link(__MODULE__, [player_id], name: via_tuple(player_id))
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
        GenServer.call(via_tuple(player_id), {:update_state, name})
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
    def init([player_id]) do

        # Add a msg to the process mailbox to
        # tell this process to run `:fetch_data`
        # send(self(), :fetch_data)
        # send(self(), :set_terminate_timer)

        Logger.info("PState created... Player ID: #{player_id}")

        # Set initial state and return from `init`
        {:ok, %__MODULE__{ player_id: player_id }}
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
    Gracefully end this process
    """
    def handle_info(:end_process, state) do
        Logger.info("Process terminating... Account ID: #{state.account_id}")
        {:stop, :normal, state}
    end

    # # Create a new registry
    # # Key => playerID
    # # PID => new agent
    # def newPState(playerID) do
    #     # create new agent
    #     {:ok, pid} = Agent.start_link fn -> ["empty"] end
    #     # register 
    #     Registry.register(:test, playerID, pid)
    # end

    # # Get all keys from :pstates Registry
    # def getAllPStateIDs do
    #     Registry.keys("reg", self())
    # end

    # # Get state of player
    # def getPState(playerID) do
    #     # get pstates agentPid
    #     [{_, pid}] = Registry.lookup("reg", playerID)
    #     # get agent data
    #     Agent.get(pid, fn data -> data end)
    # end

    # # Update player's state
    # def updatePState(playerID, state) do
    #     # get pstate's agentPid
    #     data = Registry.lookup(:test, playerID)
    #     # if no id, create one with the given state
    #     case data do
    #         [] -> 
    #             IO.puts "Creating new pstate..."
    #             # create new pstate with given state
    #             newPState(playerID)
    #             updatePState(playerID, state)
    #         [{_, pid}] ->
    #             IO.puts "Updating pstate..."
    #             IO.puts getAllPStateIDs()
    #             # update agent data
    #             Agent.update(pid, fn _ -> state end)
    #     end
        
    # end


end