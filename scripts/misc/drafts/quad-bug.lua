local time = 0
S.events:getListeners(C.SystemsPostSetup):add(C.Listener(function()
    local logger = C.TLog:forTag("quad-bug.lua")

    local q = C.Quad.new_Q_b(C.Quad:getNoQuad(), true)
    local qrs = q:getRegions()
    for i = 1, qrs.size do
        local qr = qrs.items[i] --[[@as QuadRegion]]
        -- qr:setDebugging(true)
    end
    -- q.debugging = true

    -- Broken:
    --[[
    S._render:addLayer(C.Layer(701, false, C.LayerRenderer(function(batch, delta, _, _)
        -- Behaves incorrectly when sclY is dynamic and angle is at some specific value
        -- Found the cause - LuaVM calls different methods depending on the value of parameters (calls both B7f and B9f)
        local coordX = math.sin(time)*128
        local coordY = math.cos(time)*128
        local oX = 64
        local oY = 64
        local sX = 128
        local sY = 128
        local sclX = 1+math.sin(time)*0.5
        local sclY = 1+math.cos(time)*0.5 -- this line + specific angle results in a bug
        local angle = (time*30)%360 -- 44.13

        -- logger:d("draw x: %s, y: %s, oX: %s, oY: %s, sX: %s, sY: %s, sclX: %s, sclY: %s, angle: %s", coordX, coordY, oX, oY, sX, sY, sclX, sclY, angle)
        q:draw(batch, coordX, coordY, oX, oY, sX, sY, sclX, sclY, angle)
        time = time + delta
    end)))
    ]]

    -- Fixed:
    local fQuadDraw = C.Quad:_findMethod("draw", C.Batch --[[@as Class]], java.float, java.float, java.float, java.float, java.float, java.float, java.float, java.float, java.float)
    S._render:addLayer(C.Layer.new(701, false, C.LayerRenderer(function(batch, delta, _, _)
        local coordX = math.sin(time)*128
        local coordY = math.cos(time)*128
        local oX = 64
        local oY = 64
        local sX = 128
        local sY = 128
        local sclX = 1+math.sin(time)*0.5
        local sclY = 1+math.cos(time)*0.5
        local angle = (time*30)%360

        fQuadDraw(q, batch, coordX, coordY, oX, oY, sX, sY, sclX, sclY, angle)
        time = time + delta
    end)))
end))