defmodule Server.Receiver do
    use GenServer
    require Logger
    require Integer 

    def start_link(opts \\ []) do
        GenServer.start_link(__MODULE__, :ok, opts)
    end

    def init (:ok) do
        {:ok, _socket} = :gen_udp.open(21337, [:binary])
    end

    # Handle UDP data
    def handle_info({:udp, socket, ip, port, data}, state) do
        IO.puts "---inspect source---"
        IO.inspect socket
        IO.inspect ip
        IO.inspect port
        IO.puts "----"

        parse_packet(ip, data)
        # TODO: mess with the opperator <>
        # Logger.info "Received a secret message!" <> inspect(message)

        {:noreply, state}
    end

    # Ignore everything else
    def handle_info({_, _socket}, state) do
        {:noreply, state}
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