defmodule Server.Simulation do
    use GenServer

    @refresh_rate 50

    def start_link(opts \\ []) do
        GenServer.start_link(__MODULE__, :ok, opts)
    end

    def init(:ok) do
        mainLoop(%{})
    end

    def mainLoop(state) do

        # get players
        player_ids = Server.PlayerSupervisor.player_ids()
        # IO.puts playerIDs

        for player_id <- player_ids do
            # IO.puts "---Player #{playerID}---"
            state = Server.Player.get_state(player_id)
            %{"w" => w, "a" => a, "s" => s, "d" => d} = state.input

            newX = state.x
            newZ = state.z

            cond do
                w ->
                    newZ = newZ + 1
                a ->
                    newX = newX - 1
                s ->
                    newZ = newZ - 1
                d ->
                    newX = newX + 1 
                true -> true
            end 

            state = Map.merge(state, %{:x => newX, :z => newZ})
            Server.Player.update_state(player_id, state)

            # Kernel.send(pid, "hi")
            message = %{type: "player", id: player_id, x: state.x, y: 0, z: state.z}
            packet = MessagePack.pack!(message)
            Server.Player.send_packet_to_player(player_id, 0, packet)

        end

        # wait
        :timer.sleep(@refresh_rate)

        # recurse
        mainLoop(state)
    end


end