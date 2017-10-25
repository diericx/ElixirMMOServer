defmodule Server.GameStateHandler do
    use GenServer

    @refresh_rate 1000

    def start_link(opts \\ []) do
        GenServer.start_link(__MODULE__, :ok, opts)
        
    end

    def init(:ok) do
        Server.Registry.create(Server.Registry, "GState")
        mainLoop()
    end

    def mainLoop do
        IO.puts "Players: "

        # get players
        
        {:ok, bucket} = Server.Registry.lookup(Server.Registry, "PStates")
        pstates = Server.Bucket.getAll(bucket)
        for  {ip, state}  <-  Server.Bucket.getAll(bucket)  do
            
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