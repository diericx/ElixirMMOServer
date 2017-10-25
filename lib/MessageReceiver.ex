defmodule Server.MessageReceiver do
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
    def handle_info({:udp, _socket, ip, _port, data}, state) do
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

        <<
            header        :: signed-integer-size(8), # 30 bytes * 8 = 240 bits
        >> = data
        
        playerData = Server.PlayerHandler.getAllPData(ipStr)
        Logger.info(playerData)
        # End Testing
    
        message = %{
          header: header,
        }

        Logger.info(header)

        # Part 2 Testing game state
        # Server.PlayerHandler.updatePData(ipStr, "note", header)
        # End Testing

        # msg = MessagePack.unpack!(data) #=> [1,2,3]
        # [head | rest] = msg
        # Logger.info(head)
      end
end