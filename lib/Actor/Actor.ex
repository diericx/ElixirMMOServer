defmodule Server.Actor do
    def common_fields(pos, rot, blocks) do
        [
            body: %Body{
                size: %{x: 1, y: 1},
                pos: pos,
                rot: rot,
                blocks: blocks
            }
        ]
    end

    def player_fields do
        common_fields(%{x: 0, y: 0}, %{y: 0}, 1) ++
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

    def projectile_fields(initPos, initRot) do
        common_fields(initPos, initRot, 0) ++
        [
            type: "projectile",
            initPos: initPos,
            maxDistance: 5,
            sender: nil,
            stats: %{
                speed: 0.5
            },
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
    Remove an actor 
    Returns
        updated gameState
    """
    def remove_dynamic_actor(state, id) do
        # send remove message to players so the client can update
        player_ids = Server.PlayerSupervisor.player_ids()
        message = %{type: "remove", id: id}
        packet = MessagePack.pack!(message)
        state = Server.Simulation.send_message_to_all_players(state, packet, 0, player_ids)
        # remove the actor
        actors_dynamic = Map.delete(state.actors_dynamic, id)
        Map.put(state, :actors_dynamic, actors_dynamic)
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
                cond do
                    weapon.cooldown == 0 ->
                        # update cooldown
                        weapon = Map.put(weapon, :cooldown, weapon.attackDelay)
                        # update equipment and actorState
                        equipment = Map.put(equipment, :weapon, weapon)
                        actorState = Map.put(actorState, :equipment, equipment)
                        # spawn projectile
                        state = Server.Actor.ProjectileState.spawn_projectile(state, actorState)
                        # return new states
                        {state, actorState}
                    weapon.cooldown > 0 ->
                        :cooldown_block
                end
            _ -> :no_weapon
        end
    end
end