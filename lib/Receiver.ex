defmodule Server.Receiver do
    use GenServer
    require Logger
    require Integer 

    def start_link(opts \\ []) do
        # ip = Application.get_env :gen_tcp, :ip, {127,0,0,1}
        port = Application.get_env :gen_tcp, :port, 6666
        GenServer.start_link(__MODULE__,[port],[])
    end

    def init [port] do
        start(port)
        {:ok, []}
    end

    def start(port) do
        spawn fn ->
            case :gen_tcp.listen(port, [:binary, active: false, reuseaddr: true]) do
                {:ok, socket} ->
                    Logger.info("Connected.")
                    accept_connection(socket)
                {:error, reason} ->
                    Logger.error("Could not listen: #{reason}")
            end
        end
    end

    def accept_connection(socket) do
        {:ok, client} = :gen_tcp.accept(socket)
        IO.puts "Accepting new client socket: "
        IO.inspect client
        player_id = Server.Simulation.get_next_actorId()
        # Create a new player process for the new connection
        {:ok, player_id} = Server.PlayerSupervisor.create_player_process(player_id, socket)
        # Make the process start collecting packets
        Server.Player.start_serving(player_id, client)
        # Recurse
        accept_connection(socket)
    end
end