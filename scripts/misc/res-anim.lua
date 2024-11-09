require "scripts.misc.scenario_player"

local logger = C.TLog:forTag("res-anim.lua")

local Render = com.prineside.tdi2.events.global.Render.class

for i = 1, #C.ResearchType.values do
    local rt = C.ResearchType.values[i]
    if rt ~= C.ResearchType.ROOT and string.sub(rt:name(), 1, 10) ~= "TOWER_TYPE" then
        logger:i(rt:name())
        C.Game.i.researchManager:setInstalledLevel(rt, 0, false)
    end
end

local resGroups = {}
local function gather(research, idx) 
    if resGroups[idx] == nil then
        resGroups[idx] = {}
    end
    table.insert(resGroups[idx], research)

    for i = 1, research.linksToChildren.size do
        gather(research.linksToChildren.items[i].child, idx + 1)
    end
end
gather(C.Game.i.researchManager:getInstance(C.ResearchType.ROOT), 1)

local sp = scenarioPlayer:new()
local renderHandler = C.Listener(function(event)
    ---@cast event com.prineside.tdi2.events.global.Render
    sp:update(event:getDeltaTime())
end)

local nextActionHandler
local curIdx = 1
nextActionHandler = function()
    local group = resGroups[curIdx]
    if group ~= nil then
        logger:d(tostring(curIdx))
        for i = 1, #group do
            local research = group[i] --[[@as Research]]
            C.Game.i.researchManager:setInstalledLevel(research.type, research.maxEndlessLevel, true)
        end

        curIdx = curIdx + 1
        sp:addDelay(0.16, nextActionHandler)
    else
        C.Game.EVENTS:getListeners(Render):remove(renderHandler)
    end
end

sp:addDelay(3, nextActionHandler)

C.Game.EVENTS:getListeners(Render):add(renderHandler)