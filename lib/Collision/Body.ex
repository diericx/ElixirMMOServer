defmodule Body do

    defstruct   type: nil,
                pos:  %{x: 0, y: 0, z: 0},
                size: %{x: 0, y: 0, z: 0},
                rot:  %{x: 0, y: 0, z: 0},
                onCollide: nil

    # def isPointInside(%{x: x1, y: y1}, %{x: x2, y: y2}) do
    #     if x1 >= 
    # end

    def updatePos(body, x, y, z) do
        Map.put(body, :pos, Map.merge(body.pos, %{x: x, y: y, z: z}))
    end

    def updateRot(body, x, y, z) do
        Map.put(body, :rot, Map.merge(body.rot, %{x: x, y: y, z: z}))
    end

    def intersect(body1, body2) do
        aMin = %{x: body1.pos.x - body1.size.x/2, y: body1.pos.y - body1.size.y/2, z: body1.pos.z - body1.size.z/2}
        aMax = %{x: body1.pos.x + body1.size.x/2, y: body1.pos.y + body1.size.y/2, z: body1.pos.z + body1.size.z/2}        
        bMin = %{x: body2.pos.x - body2.size.x/2, y: body2.pos.y - body2.size.y/2, z: body2.pos.z - body2.size.z/2}
        bMax = %{x: body2.pos.x + body2.size.x/2, y: body2.pos.y + body2.size.y/2, z: body2.pos.z + body2.size.z/2}
        
        ((aMin.x <= bMax.x) && (aMax.x >= bMin.x) &&
        (aMin.y <= bMax.y) && (aMax.y >= bMin.y) &&
        (aMin.z <= bMax.z) && (aMax.z >= bMin.z))


    end


end