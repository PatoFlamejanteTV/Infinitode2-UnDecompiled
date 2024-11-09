-- Draws links between teleports if they are selected
-- Turned off by default - can be enabled by removing the underscore from this file's name
-- Note: this script may work incorrectly - it has been taken from a different version of the game which is no longer maintained and had different rules. Feel free to fix it heh

local Array = java.lang.reflect.Array.class

local blankTR = C.Game.i.assetManager:getBlankWhiteTextureRegion()

-- One way to define an array of float[] is to use regular table:
--local dataInLua = {
--    0, 0, MaterialColor.RED.P500:toFloatBits(),
--    100, 100, MaterialColor.GREEN.P500:toFloatBits()
--}
-- ...but this method works poorly when array has to be passed to Java as it allocates real float[] each time Java has to access this table
-- Another way is to use real float[] as userdata (also may be faster):
--local function toJavaFloatArray(tableOfFloats)
--    local arr = Array:newInstance(floatClass, #tableOfFloats)
--    for k, v in ipairs(tableOfFloats) do
--        Array:setFloat(arr, k-1, v)
--    end
--
--    return arr
--end
local logger = C.TLog:forTag("teleport-links-renderer.lua")

local SEGMENTS_PER_CURVE = 50

--- Gate link cache ---

local GateLinkCache = {}
GateLinkCache.links = {}

---@param gate TeleportGate
---@return integer
GateLinkCache.generateGateHash = function(gate)
    return gate:getX() + gate:getY() * 256 + (gate:isLeftSide() and 0 or 256 * 256)
end

GateLinkCache.clear = function()
    GateLinkCache.links = {}
end

---@param gateA TeleportGate
---@param gateB TeleportGate
GateLinkCache.markLinked = function(gateA, gateB)
    local hA = GateLinkCache.generateGateHash(gateA)
    local hB = GateLinkCache.generateGateHash(gateB)
    if hA < hB then
        if GateLinkCache.links[hA] == nil then
            GateLinkCache.links[hA] = {}
        end
        GateLinkCache.links[hA][hB] = true
    else
        if GateLinkCache.links[hB] == nil then
            GateLinkCache.links[hB] = {}
        end
        GateLinkCache.links[hB][hA] = true
    end
end

---@param gateA TeleportGate
---@param gateB TeleportGate
GateLinkCache.isLinked = function(gateA, gateB)
    local hA = GateLinkCache.generateGateHash(gateA)
    local hB = GateLinkCache.generateGateHash(gateB)
    if hA == hB then return true end
    if hA < hB then
        return GateLinkCache.links[hA] ~= nil and GateLinkCache.links[hA][hB] ~= nil
    else
        return GateLinkCache.links[hB] ~= nil and GateLinkCache.links[hB][hA] ~= nil
    end
end

local curves = {} -- Array of bezier curves to render (float arrays as userdata)

local curveHelperArray = Array:newInstance_C_i(java.float, (SEGMENTS_PER_CURVE + 1) * 3) --[=[@as number[]]=]

--- Vertex arrays pool ---

local CurveVertexArrayPool = {}
CurveVertexArrayPool.pool = {}

CurveVertexArrayPool.obtain = function()
    if #CurveVertexArrayPool.pool ~= 0 then
        local curve = CurveVertexArrayPool.pool[#CurveVertexArrayPool.pool]
        CurveVertexArrayPool.pool[#CurveVertexArrayPool.pool] = nil
        --log("Returning from pool: " .. tostring(curve))
        return curve
    else
        local curve = Array:newInstance_C_i(java.float, SEGMENTS_PER_CURVE * 20)
        --log("Creating new: " .. tostring(curve))
        return curve
    end
end

CurveVertexArrayPool.free = function(curve)
    CurveVertexArrayPool.pool[#CurveVertexArrayPool.pool + 1] = curve
end

--- Event handling ---
local mapSelectionListener = function()
    -- logger:d("mapSelectionListener")
    -- Update the array of curves
    for _, curve in ipairs(curves) do
        CurveVertexArrayPool.free(curve)
    end

    curves = {}
    GateLinkCache.clear()

    local selectedGates = S._mapEditor.selection.gates

    local outlineColorTransparent = C.Color.new_4f(0,0,0,0)
    local outlineColor = C.Color.new_4f(0,0,0,0.56)
    local map = S.map:getMap()
    for i = 1, selectedGates.size do
        if #curves >= 4096 then break end

        local gate = selectedGates.items[i] --[[@as Gate]]
        if S._mapEditor.selection:isFromInventory() then
            gate = gate:cloneGate()
            gate:setPosition(map:getWidth() + 8, map:getHeight() * 0.5, true)
        end
        if C.TeleportGate:_isInstance(gate) then
            ---@cast gate TeleportGate
            -- Searching for teleports with the same index
            local color = C.TeleportGate.INDEX_COLORS[gate.index + 1] -- :toFloatBits()
            local colorTransparent = color:cpy():mul(1,1,1,0)
            local bezierMul = 0.3
            local allGates = map:getAllGates()
            for j = 1, allGates.size do
                local otherGate = allGates.items[j] --[[@as Gate]]
                if C.TeleportGate:_isInstance(otherGate) then
                    ---@cast otherGate TeleportGate
                    if otherGate.index == gate.index then
                        if not GateLinkCache.isLinked(gate, otherGate) then
                            GateLinkCache.markLinked(gate, otherGate)

                            local bb = gate:getBoundingBox()
                            local aX, aY, aW, aH = bb.x, bb.y, bb.width, bb.height
                            bb = otherGate:getBoundingBox()
                            local bX, bY, bW, bH = bb.x, bb.y, bb.width, bb.height

                            local dist = math.sqrt(((aX - bX) ^ 2) + ((aY - bY) ^ 2))
                            local shiftDist = dist * bezierMul

                            ---@param g TeleportGate
                            ---@param toGate TeleportGate
                            local function getSideShift(g, toGate)
                                local ret
                                if g:isLeftSide() then
                                    -- Left side (vertical)
                                    local rTile = map:getTile(g:getX(), g:getY())
                                    local lTile = map:getTile(g:getX() - 1, g:getY())
                                    if rTile == nil and lTile ~= nil then
                                        ret = { shiftDist, 0 }
                                    elseif rTile ~= nil and lTile == nil then
                                        ret = { -shiftDist, 0 }
                                    else
                                        local gbb = g:getBoundingBox()
                                        local aaX = gbb.x + gbb.width * 0.5
                                        gbb = toGate:getBoundingBox()
                                        local bbX = gbb.x + gbb.width * 0.5
                                        if aaX < bbX then
                                            ret = { shiftDist, 0 }
                                        else
                                            ret = { -shiftDist, 0 }
                                        end
                                    end

                                    if toGate:isLeftSide() and g:getY() == toGate:getY() then
                                        ret[2] = 192
                                    end
                                else
                                    -- Bottom side (horizontal)
                                    local tTile = map:getTile(g:getX(), g:getY())
                                    local bTile = map:getTile(g:getX(), g:getY() - 1)
                                    if tTile == nil and bTile ~= nil then
                                        ret = { 0, shiftDist }
                                    elseif tTile ~= nil and bTile == nil then
                                        ret = { 0, -shiftDist }
                                    else
                                        local gbb = g:getBoundingBox()
                                        local aaY = gbb.y + gbb.height * 0.5
                                        gbb = toGate:getBoundingBox()
                                        local bbY = gbb.y + gbb.height * 0.5

                                        if aaY < bbY then
                                            ret = { 0, shiftDist }
                                        else
                                            ret = { 0, -shiftDist }
                                        end
                                    end

                                    if not toGate:isLeftSide() and g:getX() == toGate:getX() then
                                        ret[1] = 192
                                    end
                                end

                                return ret
                            end

                            local aS = getSideShift(gate, otherGate)
                            local bS = getSideShift(otherGate, gate)

                            if S._mapEditor.selection:isFromInventory() then
                                aS = { -dist * 0.3, 0 }
                            end

                            local bezierPoints = {}
                            bezierPoints[#bezierPoints + 1] = C.Vector2.new_2f(aX + aW * 0.5, aY + aH * 0.5)
                            bezierPoints[#bezierPoints + 1] = C.Vector2.new_2f(aX + aW * 0.5 + aS[1], aY + aH * 0.5 + aS[2])
                            bezierPoints[#bezierPoints + 1] = C.Vector2.new_2f(bX + bW * 0.5 + bS[1], bY + bH * 0.5 + bS[2])
                            bezierPoints[#bezierPoints + 1] = C.Vector2.new_2f(bX + bW * 0.5, bY + bH * 0.5)

                            -- Outline
                            local arr = CurveVertexArrayPool.obtain()
                            C.DrawUtils:prepareBezierCurve(curveHelperArray, bezierPoints, SEGMENTS_PER_CURVE, S._mapEditor.selection:isFromInventory() and outlineColorTransparent or outlineColor, outlineColor)
                            C.DrawUtils:getTexturedMultiLineVertices(arr, 10, blankTR, curveHelperArray, 0, #curveHelperArray)
                            curves[#curves + 1] = arr

                            -- Colored lines
                            arr = CurveVertexArrayPool.obtain()
                            C.DrawUtils:prepareBezierCurve(curveHelperArray, bezierPoints, SEGMENTS_PER_CURVE, S._mapEditor.selection:isFromInventory() and colorTransparent or color, color)
                            C.DrawUtils:getTexturedMultiLineVertices(arr, 4, blankTR, curveHelperArray, 0, #curveHelperArray)
                            curves[#curves + 1] = arr
                        end
                    end
                end
            end
        end
    end
end
S.events:getListeners(C.MapEditorSelectionChange):add(C.Listener(mapSelectionListener))

S.events:getListeners(com.prineside.tdi2.events.game.Render.class):addWithPriority(C.Listener(function(_)
    -- We are not forced to use RenderSystem and can draw during a regular Render event (but it is discouraged)
    local batch = C.Game.i.renderingManager.batch
    S._render:prepareBatch(batch, false)
    for _, curve in ipairs(curves) do
        batch:draw(blankTR:getTexture(), curve, 0, curve.length)
    end
    C.RenderingManager:prepareBatch(batch, false)
    batch:_M_end()
end), -100000)

logger:d("script started")