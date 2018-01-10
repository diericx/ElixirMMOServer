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