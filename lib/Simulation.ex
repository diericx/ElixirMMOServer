defmodule Server.Simulation do
    use GenServer

    # Alias' for libraries
    alias Server.Actor, as: Actor
    alias Server.Player, as: Player

    @reg_name :state_registry
    @gstate_name :game_state
    @refresh_rate 33

    # Game State
    # TODO - Move this data to an Actor thread
    defstruct   actors_dynamic: %{},
                projectiles: [],
                next_actorId: 0

    @doc """
    Starts a new process for gamestate
    """
    def start_link() do
        GenServer.start_link(__MODULE__, [], name: via_tuple(:game_state))
    end

    @doc """
    Get the location of a process in the registry via id
    """
    defp via_tuple(id), do: {:via, Registry, {@reg_name, id}}

    @doc """
    Init callback
    """
    def init([]) do
        IO.puts "Running Simulation!"

        # {:ok, binBalance} = Ethereumex.HttpClient.eth_get_balance("0x627306090abaB3A6e1400e9345bC60c78a8BEf57")
        # binBalance = String.slice(binBalance, 2..34)
        # {integer, remainder} = Integer.parse(binBalance, 16)
        # IO.puts integer

        # {:ok, accounts} = Ethereumex.HttpClient.eth_accounts
        # IO.inspect accounts
        # [head | tail] = accounts

        # transaction = %{
        #     "from" => head,
        #     "to" => "0xf25186b5081ff5ce73482ad761db0eb0d25abfbf",
        #     "data" => "0x7749cf230000000000000000000000000000000000000000000000000000000000000000"
        # }
        # result = Ethereumex.HttpClient.eth_call(transaction)
        # IO.inspect result

        mainLoop()
        {:ok, %__MODULE__{ }}
    end

    def mainLoop() do
        spawn fn ->
            # get actors_dynamic
            player_ids = Server.PlayerSupervisor.player_ids()

            for player_id <- player_ids do
                state = Server.Simulation.get_state()

                # ---Update projectiles---
                state = Server.Actor.ProjectileState.update_projectiles(state, state.projectiles)

                # ---Update this player's position---
                pstate = state.actors_dynamic[player_id]
                body = pstate.body
                %{"w" => w, "a" => a, "s" => s, "d" => d, "lmb" => lmb} = pstate.input

                newX = 
                    cond do
                        d -> 
                            body.pos.x + (1 * pstate.stats.speed)
                        a -> body.pos.x - (1 * pstate.stats.speed)
                        true -> 
                            body.pos.x
                    end
                newY = 
                    cond do
                        w -> body.pos.y + (1 * pstate.stats.speed)
                        s -> body.pos.y - (1 * pstate.stats.speed)
                        true -> body.pos.y
                    end

                # Body with future position
                body = Body.updatePos(pstate.body, newX, newY)

                # ---Update player weapon cooldown---
                pstate = Actor.PlayerState.update_weapon_cooldown(pstate)
                
                # ---attempt to attack---
                {state, pstate} = 
                    if lmb do
                        case Actor.PlayerState.fire_weapon(state, pstate) do
                            {s, ps} -> {s, ps}
                            :cooldown_block -> {state, pstate}
                        end
                    else
                        {state, pstate}
                    end
                
                # ---check for collisions---
                # if it isnt intersecting in the new position, then move it
                # TODO - put this in same loop as sending messages so its not 2n^2
                pstate = 
                    case checkForCollisions(state, player_id, body) do
                        true -> 
                            # call collision functions
                            pstate
                        false -> 
                            # update body position
                            Map.merge(pstate, %{:body => body})
                    end

                # update state
                actors_dynamic = Map.put(state.actors_dynamic, player_id, pstate)
                state = Map.put(state, :actors_dynamic, actors_dynamic)
                Server.Simulation.update_state(state)

                # ---Send Projectile data to this player---
                send_projectiles_to_player(state, player_id, state.projectiles)

                # ---Send this player's data to everyone else! (Self including)---
                for other_player_id <- player_ids do
                    # if we are sending info to client's self, let it know!
                    is_client =
                        if (other_player_id == player_id) do
                            true
                        else 
                            false
                        end
                    message = %{type: "player", is_client: is_client, id: player_id, x: pstate.body.pos.x, y: pstate.body.pos.y, z: 0}
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
    goes through all the projectile actorIds and sends each one to the player
    """
    def send_projectiles_to_player(state, _, []) do state end
    def send_projectiles_to_player(state, player_id, projectiles) do
        [projectile_id | tail] = projectiles
        actorState = state.actors_dynamic[projectile_id]
        message = %{type: "projectile", id: projectile_id, x: actorState.body.pos.x, y: actorState.body.pos.y, z: 0}
        packet = MessagePack.pack!(message)
        Server.Simulation.add_packet_to_player_queue(player_id, 0, packet)
        # recurse
        send_projectiles_to_player(state, player_id, tail)
    end

    @doc """
    [Local]
    Add a message to every player's priority queue
    Returns
        Updated State
    """
    def send_message_to_all_players(state, _, _, []) do state end
    def send_message_to_all_players(state, packet, priority, player_ids) do
        [player_id | tail] = player_ids
        case Server.Simulation.add_packet_to_player_queue(state, player_id, priority, packet) do
            {:ok, state} -> 
                send_message_to_all_players(state, packet, priority, tail)
            {:error, _} -> 
                IO.puts "Failed to send message!"
                send_message_to_all_players(state, packet, priority, player_id)
        end
    end

    @doc """
    Recursively Check players for collisions
    Returns True/False
    """
    # base case
    def checkForPlayerCollisions(_, [], _, _) do false end
    def checkForPlayerCollisions(actors_dynamic, [head | tail], player_id, future_body) do
        if (head == player_id) do
            checkForPlayerCollisions(actors_dynamic, tail, player_id, future_body)
        else
            case Body.intersect(actors_dynamic[head].body, future_body) do
                true -> 
                    case actors_dynamic[head].body.blocks do
                        1 -> true
                        0 -> false
                    end
                false -> 
                    checkForPlayerCollisions(actors_dynamic, tail, player_id, future_body)
            end
        end
    end

    def checkForCollisions(state, player_id, future_body) do
        checkForPlayerCollisions(state.actors_dynamic, Map.keys(state.actors_dynamic), player_id, future_body)
    end

    @doc """
    Adds a pstate to the game state, or does nothing if the pstate is already found
    Returns 
    -> full game state map
    """
    def create_pstate(state, player_id) do
        case Map.fetch(state.actors_dynamic, player_id) do
            {:ok, _} -> state
            _ -> Map.put(state, :actors_dynamic, Map.put(state.actors_dynamic, player_id, %Actor.PlayerState{}))
        end
    end

    @doc """
    Removes a pstate from game state, or does nothing if player not found
    Returns 
        -> GameState
    """
    def remove_pstate(state, player_id) do
        case Map.fetch(state.actors_dynamic, player_id) do
            {:ok, _} -> Map.put(state, :actors_dynamic, Map.delete(state.actors_dynamic, player_id))
            _ -> state
        end
    end

    @doc """
    Retrieves a player state
    Returns 
        -> pstate map
        -> {:eror, :player_does_not_exist} if player is not found
    """
    def get_pstate(state, player_id) do
        case Map.fetch(state.actors_dynamic, player_id) do
            {:ok, pstate} -> {:ok, pstate}
            _ -> {:error, :player_does_not_exist}
        end
    end

    @doc """
    Updates a player state
    Returns 
    -> full game state map
    """
    def update_pstate(state, player_id, pstate) do
        newactors_dynamic = Map.put(state.actors_dynamic, player_id, pstate)
        Map.put(state, :actors_dynamic, newactors_dynamic)
    end

    @doc """
    Adds an actor id to the projectiles map
    Returns
        updated gameState
    """
    def add_projectile_id(state, id) do
        projectiles = Map.put(state.projectiles, id, true)
        Map.put(state, :projectiles, projectiles)
    end

    @doc """
    [Internal]
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
    [Internal]
    Return the next actor id
    """
    def get_next_actorId(state) do
        actorId = state.next_actorId
        IO.inspect actorId
        state = Map.put(state, :next_actorId, state.next_actorId+1)
        IO.inspect state.next_actorId
        {actorId, state}
    end

    # ---------------------------------------------------------
    # --- Functions meant for external use, Genserver calls ---
    # ---------------------------------------------------------

    @doc """
    [External]
    Handle a player joining 
    """
    def player_joined(player_id) do
        GenServer.call(via_tuple(@gstate_name), {:player_joined,  player_id})
    end

    @doc """
    [External]
    Handle a player leaving
    """
    def player_left(player_id) do
        GenServer.call(via_tuple(@gstate_name), {:player_left,  player_id})
    end

    @doc """
    [External]
    Add a packet to a player's packet queue
    """
    def add_packet_to_player_queue(player_id, priority, packet) do
        GenServer.call(via_tuple(@gstate_name), {:add_packet_to_player_queue,  player_id, priority, packet})
    end

    @doc """
    [External]
    Return the game state
    """
    def get_state() do
        GenServer.call(via_tuple(@gstate_name), :get_state)
    end

    @doc """
    [External]
    Return the next actor id
    """
    def get_next_actorId() do
        GenServer.call(via_tuple(@gstate_name), :get_next_actorId)
    end

    @doc """
    [External]
    Return's a specific player's state
    """
    def get_pstate(player_id) do
        GenServer.call(via_tuple(@gstate_name), {:get_pstate, player_id} )
    end

    @doc """
    [External]
    Update the game state
    """
    def update_state(new_state) do
        GenServer.call(via_tuple(@gstate_name), {:update_state, new_state})
    end

    @doc """
    [External]
    Update the game state
    """
    def update_pstate(player_id, new_state) do
        GenServer.call(via_tuple(@gstate_name), {:update_pstate, player_id, new_state})
    end

    @doc """
    [External]
    Call create_pstate to create this player's pstate
    """
    def update_player_input(player_id, input_state) do
        GenServer.cast(via_tuple(@gstate_name), {:update_player_input, player_id, input_state})
    end

    # ---------------------------------------------------------
    # ---     Internal Genserver call/cast handlers         ---
    # ---------------------------------------------------------

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
    Returns the next actor id
    """
    def handle_call(:get_next_actorId, _from, state) do
        {actorId, state} = get_next_actorId(state)
        {:reply, actorId, state}
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
        pstate = Map.put(state.actors_dynamic[player_id], :input, input_state)
        newactors_dynamicState = Map.put(state.actors_dynamic, player_id, pstate )
        newState = Map.put(state, :actors_dynamic, newactors_dynamicState)
        {:noreply, newState}
    end


end