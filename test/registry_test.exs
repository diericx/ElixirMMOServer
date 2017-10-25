defmodule Server.RegistryTest do
    use ExUnit.Case, async: true
  
    setup do
      {:ok, registry} = start_supervised Server.Registry
      %{registry: registry}
    end
  
    test "spawns buckets", %{registry: registry} do
      assert Server.Registry.lookup(registry, "shopping") == :error
  
      Server.Registry.create(registry, "shopping")
      assert {:ok, bucket} = Server.Registry.lookup(registry, "shopping")
  
      Server.Bucket.put(bucket, "milk", 1)
      assert Server.Bucket.get(bucket, "milk") == 1
    end

    test "removes bucket on crash", %{registry: registry} do
      Server.Registry.create(registry, "shopping")
      {:ok, bucket} = Server.Registry.lookup(registry, "shopping")
    
      # Stop the bucket with non-normal reason
      Agent.stop(bucket, :shutdown)
      assert Server.Registry.lookup(registry, "shopping") == :error
    end
  end