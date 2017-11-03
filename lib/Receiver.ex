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
        # {:ok,listen_socket}= :gen_tcp.listen(port,[:binary,{:packet, 0},{:active,true},{:ip,ip}])
        # {:ok,socket } = :gen_tcp.accept listen_socket
        # {:ok, %{ip: ip,port: port,socket: socket}}
        start(port)
        {:ok, []}
    end

    def start(port) do
        # spawn fn ->
            case :gen_tcp.listen(port, [:binary, active: false, reuseaddr: true]) do
                {:ok, socket} ->
                    Logger.info("Connected.")
                    accept_connection(socket, 0) # <--- We'll handle this next.
                {:error, reason} ->
                    Logger.error("Could not listen: #{reason}")
            end
        # end
    end

    def accept_connection(socket, player_id) do
        {:ok, client} = :gen_tcp.accept(socket)
        IO.puts "Accepting new client socket: "
        IO.inspect client

        {:ok, player_id} = Server.PlayerSupervisor.create_player_process(player_id, socket)
        IO.inspect player_id

        Server.Player.start_serving(player_id, client)

        # spawn fn ->
        #     {:ok, buffer_pid} = Buffer.create() # <--- this is next
        #     Process.flag(:trap_exit, true)
        #     serve(client, buffer_pid) # <--- and then we'll cover this
        # end

        accept_connection(socket, player_id + 1)
    end

    @doc """
    Receive messages from this players socket
    """
    def serve(socket, buffer_pid) do
        IO.inspect socket
        case :gen_tcp.recv(socket, 0) do
            {:ok, data} ->
                IO.inspect data
                buffer_pid = maybe_recreate_buffer(buffer_pid) # <-- coming up next
                Buffer.receive(buffer_pid, data)
                serve(socket, buffer_pid)
            {:error, reason} ->
                Logger.info("Socket terminating: #{inspect reason}")
        end
    end

    @doc """
    Recreate buffer if need be
    """
    defp maybe_recreate_buffer(original_pid) do
        receive do
            {:EXIT, ^original_pid, _reason} ->
            {:ok, new_buffer_pid} = Buffer.create()
            new_buffer_pid
        after
            10 ->
            original_pid
        end
    end

    # parse packet data
    def parse_packet(ip, data) do
        # DO NOT REMOVE THIS
        # << ip :: [size(4), integer, unsigned, little, unit(8) >>
        ipStr = ip |> Tuple.to_list |> Enum.join(".")

        data = MessagePack.unpack_once(data)

        IO.inspect data

        # Part 2 Testing game state
        Server.PlayerSupervisor.find_or_create_process(ipStr)
        Server.Player.update_state(ipStr, %{x: 99, y: 99})
        # Server.PlayerHandler.updatePData(ipStr, "note", header)
        # End Testing

        # msg = MessagePack.unpack!(data) #=> [1,2,3]
        # [head | rest] = msg
        # Logger.info(head)
      end
end