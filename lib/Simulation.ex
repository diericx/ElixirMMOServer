defmodule Server.Simulation do
    use GenServer

    @reg_name :state_registry
    @gstate_name :game_state
    @refresh_rate 33

    # Game State
    defstruct   players: %{}

    @doc """
    Starts a new account process for a given `account_id`.
    """
    def start_link() do
        GenServer.start_link(__MODULE__, [], name: via_tuple(:game_state))
    end

    defp via_tuple(id), do: {:via, Registry, {@reg_name, id}}

    @doc """
    Init callback
    """
    def init([]) do
        IO.puts "Running Simulation!"
        mainLoop()
        {:ok, %__MODULE__{ }}
    end

    def mainLoop() do
        spawn fn ->
            # get players
            player_ids = Server.PlayerSupervisor.player_ids()

            for player_id <- player_ids do
                state = Server.Simulation.get_state()
                # ---Update this player's data---
                pstate = state.players[player_id]
                %{"w" => w, "a" => a, "s" => s, "d" => d} = pstate.input

                sin = :math.sin( (pstate.rotY * :math.pi())/180 )
                cos = :math.cos( (pstate.rotY * :math.pi())/180 )
                sin2 = :math.sin( ((pstate.rotY * :math.pi())/180) - (:math.pi/2) )
                cos2 = :math.cos( ((pstate.rotY * :math.pi())/180) - (:math.pi/2) )
                {dX, dZ} = 
                    cond do
                        w -> 
                            {sin, cos}
                        s ->
                            {-sin, -cos}
                        true ->
                            {0, 0}
                    end
                {dX2, dZ2} = 
                    cond do
                        a -> 
                            {sin2, cos2}
                        d ->
                            {-sin2, -cos2}
                        true ->
                            {0, 0}
                    end

                pstate = Map.merge(pstate, %{:x => pstate.x + (dX + dX2) * pstate.speed, :z => pstate.z + (dZ + dZ2) * pstate.speed })

                # update state
                players = Map.put(state.players, player_id, pstate)
                state = Map.put(state, :players, players)
                Server.Simulation.update_state(state)


                # ---Send this player's data to everyone else! (Self including)---
                for other_player_id <- player_ids do
                    # if we are sending info to client's self, let it know!
                    is_client =
                        if (other_player_id == player_id) do
                            true
                        else 
                            false
                        end

                    message = %{type: "player", is_client: is_client, id: player_id, x: pstate.x, y: 0, z: pstate.z}
                    packet = MessagePack.pack!(message)

                    Server.Simulation.add_packet_to_player_queue(other_player_id, 0, packet)
                end

            end

            # wait
            :timer.sleep(@refresh_rate)

            # recurse
            mainLoop()
        end
    end

    @doc """
    Adds a pstate to the game state, or does nothing if the pstate is already found
    Returns 
    -> full game state map
    """
    def create_pstate(state, player_id) do
        case Map.fetch(state.players, player_id) do
            {:ok, _} -> state
            _ -> Map.put(state, :players, Map.put(state.players, player_id, %Server.Player{}))
        end
    end

    @doc """
    Removes a pstate from game state, or does nothing if player not found
    Returns 
    -> full game state map
    """
    def remove_pstate(state, player_id) do
        case Map.fetch(state.players, player_id) do
            {:ok, _} -> Map.put(state, :players, Map.delete(state.players, player_id))
            _ -> state
        end
    end

    @doc """
    Returns 
    -> pstate map
    -> {:eror, :player_does_not_exist} if player is not found
    """
    def get_pstate(state, player_id) do
        case Map.fetch(state.players, player_id) do
            {:ok, pstate} -> {:ok, pstate}
            _ -> {:error, :player_does_not_exist}
        end
    end

    @doc """
    Updates a pstate
    Returns 
    -> full game state map
    """
    def update_pstate(state, player_id, pstate) do
        newPlayers = Map.put(state.players, player_id, pstate)
        Map.put(state, :players, newPlayers)
    end

    @doc """
    Add a packet to a player's packet PrioMap
    Returns 
    -> full game state map
    -> :error
    """
    def add_packet_to_player_queue(state, player_id, priority, packet) do
        case get_pstate(state, player_id) do
            {:ok, pstate} ->
                newPriolist = pstate.packets[priority] ++ [packet]
                pstate = Map.put(pstate, :packets, Map.put(pstate.packets, priority, newPriolist))
                {:ok, update_pstate(state, player_id, pstate)}
            _ ->
                {:error, :player_does_not_exist}
        end

    end

    @doc """
    A Player has joined
    """
    def player_joined(player_id) do
        GenServer.call(via_tuple(@gstate_name), {:player_joined,  player_id})
    end

    @doc """
    A Player has left
    """
    def player_left(player_id) do
        GenServer.call(via_tuple(@gstate_name), {:player_left,  player_id})
    end

    @doc """
    Add a packet to a player's packet queue
    """
    def add_packet_to_player_queue(player_id, priority, packet) do
        GenServer.call(via_tuple(@gstate_name), {:add_packet_to_player_queue,  player_id, priority, packet})
    end

    @doc """
    Return the game state
    """
    def get_state() do
        GenServer.call(via_tuple(@gstate_name), :get_state)
    end

    @doc """
    Return's a specific player's state
    """
    def get_pstate(player_id) do
        GenServer.call(via_tuple(@gstate_name), {:get_pstate, player_id} )
    end

    @doc """
    Update the game state
    """
    def update_state(new_state) do
        GenServer.call(via_tuple(@gstate_name), {:update_state, new_state})
    end

    @doc """
    Update the game state
    """
    def update_pstate(player_id, new_state) do
        GenServer.call(via_tuple(@gstate_name), {:update_pstate, player_id, new_state})
    end

    @doc """
    Call create_pstate to create this player's pstate
    """
    def update_player_input(player_id, input_state) do
        GenServer.cast(via_tuple(@gstate_name), {:update_player_input, player_id, input_state})
    end

    @doc """
    Creates a new player state for the new player
    """
    def handle_call({:player_joined, player_id}, _from, state) do
        state = create_pstate(state, player_id)
        {:reply, :ok, state}
    end

    @doc """
    Removes this player's player state
    """
    def handle_call({:player_left, player_id}, _from, state) do
        state = remove_pstate(state, player_id)
        {:reply, :ok, state}
    end

    @doc """
    Add packet to player's packet queue
    """
    def handle_call({:add_packet_to_player_queue, player_id, priority, packet}, _from, state) do
        case add_packet_to_player_queue(state, player_id, priority, packet) do
            {:ok, new_state} ->
                {:reply, :ok, new_state}
            {:error, error} ->
                IO.inspect error
                {:reply, :ok, state}
        end
        
    end

    @doc """
    Update game state
    """
    def handle_call({:update_state, newState}, _from, _) do
        {:reply, :ok, newState}
    end

    @doc """
    Update specific player's state
    """
    def handle_call({:update_pstate, player_id, new_pstate}, _from, state) do
        {:reply, :ok, update_pstate(state, player_id, new_pstate)}
    end

    @doc """
    Returns the current game state
    """
    def handle_call(:get_state, _from, state) do
        {:reply, state, state}
    end

    @doc """
    Returns the current state for a specific player
    """
    def handle_call({:get_pstate, player_id}, _from, state) do
        {:reply, get_pstate(state, player_id), state}
    end

    @doc """
    Update player's input state
    """
    def handle_cast({:update_player_input, player_id, input_state}, state) do
        pstate = Map.put(state.players[player_id], :input, input_state)
        newPlayersState = Map.put(state.players, player_id, pstate )
        newState = Map.put(state, :players, newPlayersState)
        {:noreply, newState}
    end


end