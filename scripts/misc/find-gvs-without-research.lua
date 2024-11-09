--- Prints GVs that are not yet upgradeable by research
local logger = C.TLog:forTag("find-gvs-without-research")

local researchAffectedEffects = {}

local researchArr = C.Game.i.researchManager:getInstances()
for i = 1, researchArr.size do
    local research = researchArr:get(i - 1) --[[@as Research]]
    for j = 1, #research.levels do
        local researchLevel = research.levels[j]
        for k = 1, #researchLevel.effects do
            local effect = researchLevel.effects[k]
            researchAffectedEffects[effect.type] = true
        end
    end
end

local cnt = 0
logger:i("List of GVs not affected by any research:")
for i = 1, #C.GameValueType.values do
    local gv = C.GameValueType.values[i]
    if not researchAffectedEffects[gv] then
        logger:i("- %s", gv)
        cnt = cnt + 1
    end
end
if cnt == 0 then
    logger:i("- No GVs found")
end