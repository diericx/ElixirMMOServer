defmodule Actor do
    def common_fields do
        [x: 0, y: 0, z: 0]
    end 
end

defmodule Player do
    # require Actor
    defstruct Actor.common_fields ++ [socket: nil]
end

defmodule Main do
    def test do
        IO.inspect %Player{}
    end
end

Main.test