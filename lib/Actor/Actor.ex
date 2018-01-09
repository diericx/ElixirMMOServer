defmodule Server.Actor do
    def common_fields do
        [
            body: %Body{
                pos: %{x: 0, y: 0},
                size: %{x: 1, y: 1}
            },
            speed: 0.25,
        ]
    end
end