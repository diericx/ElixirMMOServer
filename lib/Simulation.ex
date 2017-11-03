defmodule Server.Simulation do
    use GenServer

    @refresh_rate 1000

    def start_link(opts \\ []) do
        GenServer.start_link(__MODULE__, :ok, opts)
    end

    def init(:ok) do
        mainLoop()
    end

    def mainLoop do

        # get players
        playerIDs = Server.PlayerSupervisor.player_ids()
        IO.puts playerIDs

        for playerID <- playerIDs do
            IO.puts "---Player #{playerID}---"
            test = Server.Player.get_state(playerID)
            IO.inspect test
            # {:reply, state} = Server.Player.get_state(playerID)
            # for {k, v} <- state do
            #     IO.puts "#{k} --> #{v}"
            # end
        end

        # wait
        :timer.sleep(@refresh_rate)

        # recurse
        mainLoop()
    end


end