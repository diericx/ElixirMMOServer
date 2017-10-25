defmodule Server.PlayerHandler do
    use GenServer

    @pstates "PStates"

    def start_link(opts \\ []) do
        GenServer.start_link(__MODULE__, :ok, opts)
    end

    def init(:ok) do
        Server.Registry.create(Server.Registry, @pstates)
        {:ok, 0}
    end

    # def getAllPData() do
    #     Agent.get(:PStates, fn states ->
    #         states    
    #     end)
    # end

    def getPState(p_id) do
        case Server.Registry.lookup(Server.Registry, @pstates) do
            {:ok, bucket} ->
                case Server.Bucket.get(bucket, p_id) do
                    nil -> Server.Bucket.put(bucket, p_id, %{})
                    state -> state
                end
            _ -> :error
        end
    end

    # def getPStateValue(p_id, value) do
    #     case Server.Registry.lookup(Server.Registry, @pstates) do
    #         {:ok, bucket} ->
    #             case Server.Bucket.get(bucket, p_id) do
    #                 nil -> Server.Bucket.put(bucket, p_id, %{})
    #                 state -> state
    #             end
    #         _ -> :error
    #     end
    # end

    # TODO: Make this more efficient and more diverse
    def updatePState(p_id, key, value) do
        case Server.Registry.lookup(Server.Registry, @pstates) do
            {:ok, bucket} ->
                case Server.Bucket.get(bucket, p_id) do
                    nil -> :error
                    state -> 
                        state = Map.put(state, key, value)
                        Server.Bucket.put(bucket, p_id, state)
                end
            _ -> :error
        end
    end

end