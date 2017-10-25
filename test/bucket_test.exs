defmodule Server.BucketTest do
    use ExUnit.Case

    test "are temporary workers" do
        assert Supervisor.child_spec(Server.Bucket, []).restart == :temporary
    end
end