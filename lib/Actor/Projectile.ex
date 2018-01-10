defmodule Server.Actor.ProjectileState do
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

    def spawn_projectile(state, sender) do
        projectiles = state.projectiles
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
                newProjectile = Map.new Server.Actor.projectile_fields(sender.body.pos, sender.body.rot.x)
                # add to actor map
                Server.Actor.add_dynamic_actor(state, newProjectile, id)
        end
    end

    def remove_projectile(_, [], cum) do cum end
    def remove_projectile(id, projectiles, cum) do
        [head | tail] = projectiles
        cond do
            head == id ->
                cum ++ tail
            true ->
                remove_projectile(id, tail, cum ++ head)
        end
    end

    def update(actor) do
        newX = actor.body.pos.x + (:math.cos(actor.body.rot * (:math.pi/180)) * actor.stats.speed)
        newY = actor.body.pos.y + (:math.sin(actor.body.rot * (:math.pi/180)) * actor.stats.speed)
        body = Body.updatePos(actor.body, newX, newY)
        Map.put(actor, :body, body)
    end

    def has_reached_max_distance(actor) do
        initPos = actor.initPos
        pos = actor.body.pos
        dist = :math.sqrt(:math.pow(initPos.x - pos.x, 2) + :math.pow(initPos.y - pos.y, 2))
        dist >= actor.maxDistance
    end

    @doc """
    goes through all the projectile actorIds and sends each one to the player
    """
    def update_projectiles(state, []) do state end
    def update_projectiles(state, projectiles) do
        [projectile_id | tail] = projectiles
        actorState = state.actors_dynamic[projectile_id]
        case has_reached_max_distance(actorState) do
            true ->
                # remove the projectile actor
                state = Server.Actor.remove_dynamic_actor(state, projectile_id)
                # remove the projectile id from 'projectiles' list
                state = Map.put(state, :projectiles, remove_projectile(projectile_id, state.projectiles, []))
                # recurse
                update_projectiles(state, tail)
            false ->
                updatedActorsDyn = Map.put(state.actors_dynamic, projectile_id, update(actorState))
                state = Map.put(state, :actors_dynamic, updatedActorsDyn)
                update_projectiles(state, tail)
        end

    end
end