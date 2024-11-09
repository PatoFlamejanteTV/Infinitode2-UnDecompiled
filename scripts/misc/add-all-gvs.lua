local tdi = com.prineside.tdi2

local screen = C.Game.i.screenManager:getCurrentScreen() --[[@as MapEditorScreen]]
if not C.MapEditorScreen:_isInstance(screen) then
    error("Must be called on map editor screen")
    return nil
end

local GameValueType = tdi.enums.GameValueType.class

local S = screen.S

local mapW = S.map:getMap():getWidth()
local mapH = S.map:getMap():getHeight()

local imprint = S._mapEditor:startActionRecord()
local x = 0
local y = 0
for i = 1, #GameValueType.values do
    local gv = GameValueType.values[i]
    if
        (string.sub(gv:name() --[[@as string]], 1, string.len("TOWER_TYPE_")) == "TOWER_TYPE_")
        or gv:name() == "MINER_COUNT_SCALAR"
        or gv:name() == "ABILITIES_MAX_ENERGY"
        or gv:name() == "MODIFIER_BALANCE_COUNT"
        or gv:name() == "TOWERS_STARTING_LEVEL"
    then
        x = x + 1
        y = 0
    end

    if y == mapH then
        x = x + 1
        y = 0
    end

    if x == mapW then
        break
    end

    local tile = C.Game.i.tileManager.F.GAME_VALUE:createTypeDelta(gv, 1)
    S.map:setTile(x, y, tile);
    y = y + 1
end
S._mapEditor:finishActionRecord(imprint)