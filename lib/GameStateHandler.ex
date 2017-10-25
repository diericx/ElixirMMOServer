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
        
        {:ok, bucket} = Server.Registry.lookup(Server.Registry, "GState")
        for  {k, v}  <-  Server.Bucket.getAll(bucket)  do
            IO.puts "#{k} --> #{v}"
        end

        # wait
        :timer.sleep(@refresh_rate)

        # recurse
        mainLoop()
    end


end