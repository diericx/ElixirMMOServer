defmodule Server.Player do
    use GenServer
    require Logger

    @player_registry_name :player_process_registry
    @refresh_rate 33

    # Just a simple struct to manage the state for this genserver
    # You could add additional attributes here to keep track of for a given account
    defstruct   socket: nil,
                player_id: 0,
                speed: 0.5,
                x: 0.0,
                y: 0.0,
                z: 0.0,
                rotX: 0,
                rotY: 0,
                rotZ: 0,
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
    Calls player's Serve function with socket so it can start listening for packets
    """
    def start_serving(player_id, socket) do
        GenServer.cast(via_tuple(player_id), {:serve, socket})
    end

    @doc """
    Stops this player's process
    """
    def stop_player_process(player_id) do
        Server.Simulation.player_left(player_id)
        GenServer.cast(via_tuple(player_id), :end_process)
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
        Server.Simulation.player_joined(player_id)
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
                    stop_player_process(player_id)
                    # send(via_tuple(player_id), :end_process)
            end
        end
    end

    @doc """
    Sends messages according to priority to this player's socket
    PrioMap: %{0 => [], 1 => []}
    """
    # TODO: Make this return a map of the packets that have been sent with the
    # "sent" variable changed to true
    def sendPackets(socket, player_id, prioMap, i) do
        case prioMap[i] do
            nil -> prioMap
            packets ->
                case packets do
                    [] -> sendPackets(socket, player_id, prioMap, i+1)
                    ps -> 
                        [head | tail] = ps
                        prioMap = Map.put(prioMap, i, tail)
                        case :gen_tcp.send(socket, head) do
                            {:error, error} -> 
                                Server.Player.stop_player_process(player_id)
                                IO.inspect "Error sending message: #{error}"
                            :ok -> 
                                sendPackets(socket, player_id, prioMap, i)
                        end
                end
        end
    end

    def go_through_prio_map(socket, player_id) do
        spawn fn ->
            # get player info
            case Server.Simulation.get_pstate(player_id) do
                {:error, error} ->
                    error
                {:ok, state} ->
                    # Send the packets
                    newPrioMap = sendPackets(socket, player_id, state.packets, 0)
                    # TODO: Merge this sentMessages priolist map with the state
                    # NOT update_state 
                    state = Map.put(state, :packets, newPrioMap)
                    Server.Simulation.update_pstate(player_id, state)

                    :timer.sleep(@refresh_rate)
                    go_through_prio_map(socket, player_id)
            end
        end
    end

    @doc """
    Parse packet binary
    """
    def parse_packet(data, player_id) do
        {:ok, {object, leftover}} = MessagePack.unpack_once(data)

        case object do
            %{"type" => "input", "w" => w, "a" => a, "s" => s, "d" => d} ->
                Server.Simulation.update_player_input(player_id, %{"w" => w, "a" => a, "s" => s, "d" => d})
            %{"type" => "rot", "x" => x, "y" => y, "z" => z} ->
                case Server.Simulation.get_pstate(player_id) do
                    {:ok, pstate} ->
                        newPState = Map.merge(pstate, %{:rotX => x, :rotY => y, :rotZ => z})
                        Server.Simulation.update_pstate(player_id, newPState)
                    _ ->
                        :error
                end
            packet ->
                IO.puts "No match for packet!"
                IO.inspect packet
        end

        # Server.PlayerSupervisor.find_or_create_process(ipStr)
        # Server.Player.update_state(ipStr, %{x: 99, y: 99})

        leftover
    end


    @doc """
    Starts listening for packets on the given socket
    """
    def handle_cast({:serve, socket}, state) do
        # {:ok, buffer_pid} = Buffer.create() # <--- this is next
        # Process.flag(:trap_exit, true)
        serve(socket, <<>>, state.player_id)
        go_through_prio_map(socket, state.player_id)
        {:noreply, state}
    end

    @doc """
    Gracefully end this process
    """
    def handle_cast(:end_process, state) do
        Logger.info("PROCESS TERMINATION: Player ID: #{state.player_id}")
        {:stop, :normal, state}
    end

end