defmodule Server.Actor do
    def common_fields do
        [
            body: %Body{
                size: %{x: 1, y: 1}
            }
        ]
    end

    def player_fields do
        common_fields() ++
        [
            type: "player",
            stats: %{
                health: 100,
                speed: 0.2,
                attack: 10
            },
            equipment: %{
                weapon: %Server.Item{}
            },
            input: %{ 
                "w" => false, 
                "a" => false, 
                "s" => false, 
                "d" => false, 
                "lmb" => false
            },
            packets: %{0 => [], 1 => [], 2 => [], 3 => []}
        ]
    end

    def projectile_fields do
        common_fields() ++
        [
            type: "projectile",
            sender: nil,
            stats: %{
                speed: 0.5
            },
            direction: 0,
            damage: 0,
            sprite_id: 0
        ]
    end

    @doc """
    Adds an actor to the actors_dynamic map at a specific id location
    Returns
        updated gameState
    """
    def add_dynamic_actor(state, actorState, id) do
        actors_dynamic = Map.put(state.actors_dynamic, id, actorState)
        Map.put(state, :actors_dynamic, actors_dynamic)
    end

    @doc """
    Adds a projectile to game state
    Returns
        updated gameState
    """
    def add_projectile_id([], id) do [id] end
    def add_projectile_id(projectiles, id) do
        [head | tail] = projectiles
        cond do
            head == id ->
                :id_already_exists
            true ->
                add_projectile_id(tail, id)
        end
    end

    def spawn_projectile(state) do
        projectiles = state.projectiles
        IO.inspect projectiles
        # get actorId for projectile
        {id, state} = Server.Simulation.get_next_actorId(state)
        # attempt to add this id to the list of projectiles
        attempt_to_add_id = add_projectile_id(state.projectiles, id)
        case attempt_to_add_id do
            :id_already_exists -> 
                IO.puts "Error: Projectile ID already exists"
                state
            [id] ->
                # update projectile id list
                projectiles = projectiles ++ [id]
                state = Map.put(state, :projectiles, projectiles)
                # Create and return new projectile and new state
                # Note: we use Map.new because the module for ProjectileState
                #   is not created yet
                newProjectile = Map.new projectile_fields()
                add_dynamic_actor(state, newProjectile, id)
        end

    end
end

defmodule Server.Actor.PlayerState do
    defstruct Server.Actor.player_fields

    def update_weapon_cooldown(pstate) do
        cond do
            pstate.equipment.weapon.cooldown > 0 ->
                weapon = Map.put(pstate.equipment.weapon, :cooldown, pstate.equipment.weapon.cooldown - 1)
                equipment = Map.put(pstate.equipment, :weapon, weapon)
                Map.put(pstate, :equipment, equipment)
            true ->
                pstate
        end
    end

    def fire_weapon(state, actorState) do
        # Check to make sure the given state has equipment (player, npc, etc.)
        case actorState do
            %{:equipment => %{:weapon => weapon}} -> 
                equipment = actorState.equipment
                weapon = equipment.weapon
                cond do
                    weapon.cooldown == 0 ->
                        # update cooldown
                        weapon = Map.put(weapon, :cooldown, weapon.attackDelay)
                        # update equipment and actorState
                        equipment = Map.put(equipment, :weapon, weapon)
                        actorState = Map.put(actorState, :equipment, equipment)
                        # spawn projectile
                        state = Server.Actor.spawn_projectile(state)
                        # return new states
                        {state, actorState}
                    weapon.cooldown > 0 ->
                        :cooldown_block
                end
            _ -> :no_weapon
        end
    end
end

defmodule Server.Actor.ProjectileState do
    defstruct Server.Actor.projectile_fields
end