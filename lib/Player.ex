defmodule Server.Player do
    use GenServer
    require Logger

    @player_registry_name :player_process_registry
    @refresh_rate 33

    # Just a simple struct to manage the state for this genserver
    # You could add additional attributes here to keep track of for a given account
    defstruct   socket: nil,
                player_id: 0,
                x: 0,
                y: 0,
                z: 0,
                input: %{"w" => false, "a" => false, "s" => false, "d" => false},
                packets: %{0 => [], 1 => [], 2 => [], 3 => []}

    @doc """
    Starts a new account process for a given `account_id`.
    """
    def start_link(player_id, socket) do
        GenServer.start_link(__MODULE__, [player_id, socket], name: via_tuple(player_id))
    end

    defp via_tuple(player_id), do: {:via, Registry, {@player_registry_name, player_id}}

    @doc """
    Return some details (state) for this PState process
    """
    def get_state(player_id) do
        GenServer.call(via_tuple(player_id), :get_state)
    end

    @doc """
    Updates the process's state (PState)
    """
    def update_state(player_id, newState) do
        GenServer.cast(via_tuple(player_id), {:update_state, newState})
    end

    @doc """
    Calls player's Serve function with socket so it can start listening for packets
    """
    def start_serving(player_id, socket) do
        GenServer.cast(via_tuple(player_id), {:serve, socket})
    end

    @doc """
    Sends a packet to the player to be queued for sending
    """
    def send_packet_to_player(player_id, priority, packet) do
        GenServer.cast(via_tuple(player_id), {:packet, priority, packet})
    end

    @doc """
    Returns the pid for the `player_id` stored in the registry
    """
    def whereis(player_id) do
        case Registry.lookup(@player_registry_name, player_id) do
            [{pid, _}] -> pid
            [] -> nil
        end
    end

    @doc """
    Init callback
    """
    def init([player_id, socket]) do
        {:ok, %__MODULE__{ player_id: player_id, socket: socket }}
    end

    @doc """
    Receive messages from this player's socket
    """
    def serve(socket, buffer, player_id) do
        spawn fn ->
            case :gen_tcp.recv(socket, 0) do
                {:ok, data} ->
                    leftover = parse_packet(data <> buffer, player_id)
                    serve(socket, leftover, player_id)
                {:error, reason} ->
                    # TODO: Handle disconnects
                    Logger.info("Socket terminating: #{inspect reason}")
                    Logger.info("WARNING: Player has not been properly removed!")
                    # send(via_tuple(player_id), :end_process)
            end
        end
    end

    @doc """
    Sends messages according to priority to this player's socket
    PrioMap: %{0 => [], 1 => []}
    """
    def sendPackets(socket, prioMap, i) do
        case prioMap[i] do
            nil -> prioMap
            packets ->
                case packets do
                    [] -> sendPackets(socket, prioMap, i+1)
                    ps -> 
                        [head | tail] = ps
                        prioMap = Map.put(prioMap, i, tail)
                        case :gen_tcp.send(socket, head) do
                            {:error, error} -> IO.inspect "Error sending message: #{error}"
                            :ok -> 
                                sendPackets(socket, prioMap, i)
                        end
                end
        end
    end

    def send_messages(socket, player_id) do
        spawn fn ->
            # get player info
            state = Server.Player.get_state(player_id)
            # Send the packets
            newPrioMap = sendPackets(socket, state.packets, 0)
            # TODO: Update this with the leftover from send packets
            state = Map.put(state, :packets, newPrioMap)
            Server.Player.update_state(player_id, state)

            :timer.sleep(@refresh_rate)
            send_messages(socket, player_id)
        end
    end

    @doc """
    Parse packet binary
    """
    def parse_packet(data, player_id) do
        {:ok, {object, leftover}} = MessagePack.unpack_once(data)

        case object do
            %{"type" => "input", "w" => w, "a" => a, "s" => s, "d" => d} ->
                state = Server.Player.get_state(player_id)
                input = state.input
                newInput = Map.merge(input, %{"w" => w, "a" => a, "s" => s, "d" => d})
                newState = Map.put(state, :input, newInput)
                Server.Player.update_state(player_id, newState)
            packet ->
                IO.puts "No match for packet!"
                IO.inspect packet
        end

        # Server.PlayerSupervisor.find_or_create_process(ipStr)
        # Server.Player.update_state(ipStr, %{x: 99, y: 99})

        leftover
      end

    @doc """
    Returns the current state for Player process that matches player_id
    """
    def handle_call(:get_state, _from, state) do
        # maybe you'd want to transform the state a bit...
        # response = %{
        #     id: 0,
        #     name: state.name
        # }

        {:reply, state, state}
    end

    @doc false
    def handle_cast({:update_state, newState}, state) do

        {:noreply, newState}
    end

    @doc """
    Starts listening for packets on the given socket
    """
    def handle_cast({:serve, socket}, state) do
        # {:ok, buffer_pid} = Buffer.create() # <--- this is next
        # Process.flag(:trap_exit, true)
        serve(socket, <<>>, state.player_id)
        send_messages(socket, state.player_id)
        {:noreply, state}
    end

    @doc """
    Adds packet to the queue
    """
    def handle_cast({:packet, priority, packet}, state) do
        {:ok, prioMap} = Map.fetch(state, :packets)
        {:ok, packets} = Map.fetch(prioMap, priority)
        
        packets = packets ++ [packet]

        prioMap = Map.put(prioMap, priority, packets)
        newState = Map.put(state, :packets, prioMap)

        {:noreply, newState}
    end

    @doc """
    Gracefully end this process
    """
    def handle_info(:end_process, state) do
        Logger.info("Process terminating... Account ID: #{state.account_id}")
        {:stop, :normal, state}
    end

end