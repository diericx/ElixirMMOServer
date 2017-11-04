defmodule Server.Simulation do
    use GenServer

    @refresh_rate 33

    def start_link(opts \\ []) do
        GenServer.start_link(__MODULE__, :ok, opts)
    end

    def init(:ok) do
        mainLoop()
    end

    def mainLoop do

        # get players
        playerIDs = Server.PlayerSupervisor.player_ids()
        # IO.puts playerIDs

        for playerID <- playerIDs do
            # IO.puts "---Player #{playerID}---"
            state = Server.Player.get_state(playerID)
            
            x = Map.get(state, :x)
            y = Map.get(state, :y)

            {:ok, pid} = Server.PlayerSupervisor.find_process(playerID)
            # Kernel.send(pid, "hi")
            message = %{type: "player", x: x, y: y}
            packet = MessagePack.pack!(message)
            Server.Player.send_packet_to_player(playerID, 0, packet)

            # IO.inspect "(#{x}, #{y})"
        end

        # wait
        :timer.sleep(@refresh_rate)

        # recurse
        mainLoop()
    end


end