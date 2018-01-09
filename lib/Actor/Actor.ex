defmodule Server.Actor do
    def common_fields do
        [
            body: %Body{
                pos: %{x: 0, y: 0},
                size: %{x: 1, y: 1}
            },
        ]
    end

    def player_fields do
        common_fields() ++
        [
            stats: %{
                health: 100,
                speed: 0.2,
            },
            input: %{ 
                "w" => false, 
                "a" => false, 
                "s" => false, 
                "d" => false, 
                "lmb" => false
            },
            packets: %{0 => [], 1 => [], 2 => [], 3 => []}
        ]
    end

    def projectile_fields do
        common_fields() ++
        [
            stats: %{
                speed: 0.5
            },
            sprite_id: 0
        ]
    end
end

defmodule Server.Actor.PlayerState do
    defstruct Server.Actor.player_fields
end

defmodule Server.Actor.ProjectileState do
    defstruct Server.Actor.projectile_fields
end