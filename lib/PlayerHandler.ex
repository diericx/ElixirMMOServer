defmodule Server.PlayerHandler do
    use GenServer

    @pstates "PStates"

    def start_link(opts \\ []) do
        GenServer.start_link(__MODULE__, :ok, opts)
    end

    def init(:ok) do
        IO.puts "ok"
        v = Server.Registry.create(Server.Registry, @pstates)
        {:ok, 0}
    end

    # def getAllPData() do
    #     Agent.get(:PStates, fn states ->
    #         states    
    #     end)
    # end

    def getAllPData(p_id) do
        case Server.Registry.lookup(Server.Registry, @pstates) do
            {:ok, bucket} ->
                case Server.Bucket.get(bucket, p_id) do
                    :error -> Server.Bucket.put(bucket, p_id, %{})
                    data -> data
                end
            _ -> :error
        end
    end

    # def updatePData(p_id, key, value) do
    #     case Server.Registry.lookup(Server.Registry, @PS) do
    #         {:ok, bucket} ->
    #             Server.Bucket.put(bucket, key, value)
    #         _ -> :error
    #     end
    # end

end