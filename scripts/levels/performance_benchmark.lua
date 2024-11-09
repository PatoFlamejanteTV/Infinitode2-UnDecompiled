S.events:getListeners(C.SystemsPostSetup):addStateAffecting(C.Listener(function (_)
    -- Build random towers everywhere
    local map = S.map:getMap()
    for y = 0, map:getHeight() - 1 do
        for x = 0, map:getWidth() - 1 do
            local tile = map:getTile(x, y)
            if tile ~= nil and C.PlatformTile:_isInstance(tile) and (tile --[[@as PlatformTile]]).building == nil then
                local towerType = C.TowerType.values[S.gameState:randomInt(#C.TowerType.values) + 1]
                while towerType == C.TowerType.GAUSS do
                    towerType = C.TowerType.values[S.gameState:randomInt(#C.TowerType.values) + 1]
                end

                local aimStrategy = C.Tower.AimStrategy.values[S.gameState:randomInt(#C.Tower.AimStrategy.values) + 1]
                S.tower:buildTower(towerType, aimStrategy, x, y)
            end
        end
    end
end))

local timeSinceTowerUpgrade = 0
local timeToNextTowerUpgrade = 2

S.events:getListeners(C.GameStateTick):addStateAffecting(C.Listener(function(event)
    ---@cast event GameStateTick
    timeSinceTowerUpgrade = timeSinceTowerUpgrade + event:getDeltaTime()
    if timeSinceTowerUpgrade > timeToNextTowerUpgrade then
        -- Upgrade one random tower
        timeSinceTowerUpgrade = timeSinceTowerUpgrade - timeToNextTowerUpgrade
        timeToNextTowerUpgrade = timeToNextTowerUpgrade + 0.005
        local tower = S.tower.towers:get(S.gameState:randomInt(S.tower.towers.size)) --[[@as Tower]]
        S.tower:upgradeTower(tower)

        -- Set its ability if possible
        local abilityIndex = S.gameState:randomInt(C.Tower.ABILITIES_COUNT)
        if tower:canAbilityBeInstalled(abilityIndex) then
            S.tower:setAbilityInstalled(tower, abilityIndex, true)
        end
    end
end))


