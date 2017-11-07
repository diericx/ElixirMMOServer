defmodule Server.Simulation do
    use GenServer

    @refresh_rate 33

    def start_link(opts \\ []) do
        GenServer.start_link(__MODULE__, :ok, opts)
    end

    def init(:ok) do
        mainLoop(%{})
    end

    def mainLoop(state) do

        # get players
        player_ids = Server.PlayerSupervisor.player_ids()

        for player_id <- player_ids do
            # ---Update this player's data---
            state = Server.Player.get_state(player_id)
            %{"w" => w, "a" => a, "s" => s, "d" => d} = state.input

            newZ = 
                cond do
                    w -> state.z + 0.4
                    s -> state.z - 0.4
                    true -> state.z
                end
            newX = 
                cond do
                    a -> state.x - 0.4
                    d -> state.x + 0.4
                    true -> state.x
                end

            state = Map.merge(state, %{:x => newX, :z => newZ})
            Server.Player.update_state(player_id, state)

            # ---Send this player's data to everyone else! (Self including)---
            for other_player_id <- player_ids do
                # if we are sending info to client's self, let it know!
                is_client =
                    if (other_player_id == player_id) do
                        true
                    else 
                        false
                    end

                message = %{type: "player", is_client: is_client, id: player_id, x: state.x, y: 0, z: state.z}
                packet = MessagePack.pack!(message)
                Server.Player.send_packet_to_players_client(other_player_id, 0, packet)
            end

        end

        # wait
        :timer.sleep(@refresh_rate)

        # recurse
        mainLoop(state)
    end


end