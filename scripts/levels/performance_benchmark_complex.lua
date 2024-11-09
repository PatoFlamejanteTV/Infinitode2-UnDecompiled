-- Randomly builds, upgrades and sells stuff
local logger = C.TLog:forTag("perf_bench")

-- Upgrade
local timeSinceTowerUpgrade = 0
local timeToNextTowerUpgrade = 2

-- Sell
local timeSinceTowerSell = 0
local timeToNextTowerSell = 30

-- Build
local timeSinceBuild = 0
local timeToNextBuild = 13

S.events:getListeners(C.GameStateTick):addStateAffecting(C.Listener(function(event)
    ---@cast event GameStateTick

    -- Upgrade existing towers
    timeSinceTowerUpgrade = timeSinceTowerUpgrade + event:getDeltaTime()
    if timeSinceTowerUpgrade > timeToNextTowerUpgrade then
        timeSinceTowerUpgrade = timeSinceTowerUpgrade - timeToNextTowerUpgrade
        timeToNextTowerUpgrade = timeToNextTowerUpgrade + 0.005

        if S.tower.towers.size ~= 0 then
            -- Upgrade one random tower
            local tower = S.tower.towers:get(S.gameState:randomInt(S.tower.towers.size)) --[[@as Tower]]
            S.tower:upgradeTower(tower)

            -- Set its ability if possible
            local abilityIndex = S.gameState:randomInt(C.Tower.ABILITIES_COUNT)
            if tower:canAbilityBeInstalled(abilityIndex) then
                S.tower:setAbilityInstalled(tower, abilityIndex, true)
            end
        end

        if S.miner.miners.size ~= 0 then
            -- Upgrade one random miner
            local miner = S.miner.miners:get(S.gameState:randomInt(S.miner.miners.size)) --[[@as Miner]]
            if miner:getUpgradeLevel() < 5 then
                S.miner:upgradeMiner(miner)
            end
        end
    end

    -- Sell random towers or miners
    timeSinceTowerSell = timeSinceTowerSell + event:getDeltaTime()
    if timeSinceTowerSell > timeToNextTowerSell then
        timeSinceTowerSell = timeSinceTowerSell - timeToNextTowerSell
        timeToNextTowerSell = timeToNextTowerSell + 1
        if S.gameState:randomFloat() < 0.8 and S.tower.towers.size ~= 0 then
            -- Sell a tower
            local tower = S.tower.towers:get(S.gameState:randomInt(S.tower.towers.size)) --[[@as Tower]]
            S.tower:sellTower(tower)
        else
            -- Sell a modifier or a miner
            if S.gameState:randomFloat() < 0.5 then
                -- Miner, if exists
                if S.miner.miners.size ~= 0 then
                    local miner = S.miner.miners:get(S.gameState:randomInt(S.miner.miners.size)) --[[@as Miner]]
                    S.miner:sellMiner(miner:getTile():getX(), miner:getTile():getY())
                end
            else
                -- Modifier, if exists
                if S.modifier.modifiers.size ~= 0 then
                    local modifier = S.modifier.modifiers:get(S.gameState:randomInt(S.modifier.modifiers.size)) --[[@as com.prineside.tdi2.Modifier]]
                    S.modifier:sellModifier(modifier)
                end
            end
        end
    end

    -- Build random towers / modifiers / miners
    timeSinceBuild = timeSinceBuild + event:getDeltaTime()
    if timeSinceBuild > timeToNextBuild then
        -- Upgrade one random tower
        timeSinceBuild = timeSinceBuild - timeToNextBuild
        timeToNextBuild = timeToNextBuild + 0.1
        if S.gameState:randomFloat() < 0.8 then
            -- Try to build a tower
            local map = S.map:getMap()
            local platformTiles = map:getTilesByType(C.PlatformTile)
            for i = 1, platformTiles.size do
                local platformTile = platformTiles.items[i] --[[@as PlatformTile]]
                if platformTile.building == nil then
                    local towerType = C.TowerType.values[S.gameState:randomInt(#C.TowerType.values) + 1]
                    local aimStrategy = C.Tower.AimStrategy.values[S.gameState:randomInt(#C.Tower.AimStrategy.values) + 1]
                    S.tower:buildTower(towerType, aimStrategy, platformTile:getX(), platformTile:getY())
                    break
                end
            end
        else
            if S.gameState:randomFloat() < 0.5 then
                -- Try to build a miner
                local map = S.map:getMap()
                local sourceTiles = map:getTilesByType(C.SourceTile)
                for i = 1, sourceTiles.size do
                    local sourceTile = sourceTiles.items[i] --[[@as SourceTile]]
                    if sourceTile.miner == nil then
                        local minerType = C.MinerType.values[S.gameState:randomInt(#C.MinerType.values) + 1]
                        if S.miner:getBuildableMinersCount(minerType) ~= 0 then
                            S.miner:buildMiner(minerType, sourceTile:getX(), sourceTile:getY(), false, true)
                            break
                        end
                    end
                end
            else
                -- Try to build a modifier
                local map = S.map:getMap()
                local platformTiles = map:getTilesByType(C.PlatformTile)
                for i = 1, platformTiles.size do
                    local platformTile = platformTiles.items[i] --[[@as PlatformTile]]
                    if platformTile.building == nil then
                        local modifierType = C.ModifierType.values[S.gameState:randomInt(#C.ModifierType.values) + 1]
                        if S.modifier:getBuildableModifiersCount(modifierType) ~= 0 then
                            S.modifier:buildModifier(modifierType, platformTile:getX(), platformTile:getY())
                            break
                        end
                    end
                end
            end
        end
    end
end))


