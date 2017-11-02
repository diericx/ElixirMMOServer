defmodule Server.GameStateHandler do
    use GenServer

    @refresh_rate 1000

    def start_link(opts \\ []) do
        GenServer.start_link(__MODULE__, :ok, opts)
        
    end

    def init(:ok) do
        mainLoop()
    end

    def mainLoop do
        IO.puts "Players: "

        # get players
        
        playerIDs = Server.PlayerSupervisor.player_ids()

        for playerID <- playerIDs do
            IO.puts "---Player #{playerID}---"
            state = Server.Player.get_state(playerID)
            for {k, v} <- state do
                IO.puts "#{k} --> #{v}"
            end
        end

        # wait
        :timer.sleep(@refresh_rate)

        # recurse
        mainLoop()
    end


end