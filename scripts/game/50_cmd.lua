local logger = C.TLog:forTag("game/cmd.lua")

cmd.hide_game_ui = function(a1)
    if (a1 == "?") then
        return {
            descr = "Hide in-game UI"
        }
    end

    for i = 1, C.Game.i.uiManager.layers do
        local mainLayer = C.Game.i.uiManager.layers[i]
        for j = 1, #mainLayer do
            local uiLayer = mainLayer:get(j) --[[@as UiLayer]]
            if uiLayer.name == "MainUi" or uiLayer.name == "ScreenBorderGradient" or uiLayer.name == "AbilityMenu" or uiLayer.name == "LiveLeaderboard" or uiLayer.name == "DeveloperConsole toggle button" or uiLayer.name == "QuestList" or uiLayer.name == "StatisticsChart" then
                uiLayer:getTable():setVisible(false)
            end
        end
    end
end

cmd.set_zoom = function(newZoom)
    if (newZoom == "?") then
        return {
            args = "double zoom",
            descr = "Set camera zooming level"
        }
    end

    local v = tonumber(newZoom)
    if v == nil then
        return logger:e("not a number: %s", newZoom)
    end

    local cameraController = S._input:getCameraController()
    cameraController:setZoom(v)
    logger:i("zoom level set to %s", cameraController.zoom)
end

cmd.set_game_speed = function(newSpeed)
    if (newSpeed == "?") then
        return {
            args = "double speed",
            descr = "Set game speed"
        }
    end

    local v = tonumber(newSpeed)
    if v == nil then
        return logger:e("not a number: %s", newSpeed)
    end

    if v < 0.0 then v = 0.0 end
    if v > 8 then v = 8 end

    S.gameState:setGameSpeed(v)
    logger:i("game speed set to %s", S.gameState:getGameSpeed())
end

cmd.add_coins = function(count)
    if (count == "?") then
        return {
            args = "int amount",
            descr = "Give coins"
        }
    end

    S.gameState:addMoney(count, false)
end

cmd.add_health = function(count)
    if (count == "?") then
        return {
            args = "int amount",
            descr = "Give health"
        }
    end

    S.gameState:addHealth(count)
end

cmd.set_tower_max_xp = function(a1)
    if (a1 == "?") then
        return {
            descr = "Set max exp for the selected tower"
        }
    end

    local tile = S._gameMapSelection:getSelectedTile()
    if not C.PlatformTile:_isInstance(tile) then ---@cast tile PlatformTile
        return logger:e("selected tile is not a platform")
    end

    local tower = tile.building
    if not C.Tower:_isInstance(tower) then ---@cast tower Tower
        return logger:e("selected has no tower")
    end

    S.experience:addExperienceRaw(tower, 50000)
end

cmd.build_tower = function(towerType, x, y)
    if (towerType == "?") then
        return {
            args = "TowerType towerType, int tileX, int tileY",
            descr = "Build tower on selected Platform tile"
        }
    end

    local towerTypeObj = nil
    utils.tryCatch(function()
        towerTypeObj = C.TowerType:valueOf(towerType)
    end)
    if not towerTypeObj then
        return logger:e("selected has no tower")
    end

    local map = S.map:getMap()
    local tile = map:getTile(x, y)

    if not C.PlatformTile.class:_isInstance(tile) then ---@cast tile PlatformTile
        return logger:e("selected tile is not a platform")
    end

    if tile.building then
        return logger:e("selected tile already has a building on it")
    end

    S._gameMapSelection:setSelectedTile(tile)
    S.tower:buildTowerActionOnSelectedTile(towerTypeObj)
    S._gameMapSelection:setSelectedTile(nil)
end

cmd.fill_with_tower = function(towerType)
    if (towerType == "?") then
        return {
            args = "TowerType towerType",
            descr = "Build tower on all empty Platform tiles"
        }
    end

    local map = S.map:getMap()
    for y = 0, map:getHeight() - 1 do
        for x = 0, map:getWidth() - 1 do
            local tile = map:getTile(x, y)
            if tile ~= nil and C.PlatformTile:_isInstance(tile) then ---@cast tile PlatformTile
                if not tile.building then
                    S._gameMapSelection:setSelectedTile(tile)
                    S.tower:buildTowerActionOnSelectedTile(towerType)
                end
            end
        end
    end
    S._gameMapSelection:setSelectedTile(nil)

    logger:i("Done")
end

cmd.fill_with_random_tower = function(a1)
    if (a1 == "?") then
        return {
            descr = "Build random tower on all empty Platform tiles"
        }
    end

    local map = S.map:getMap()
    for y = 0, map:getHeight() - 1 do
        for x = 0, map:getWidth() - 1 do
            local tile = map:getTile(x, y)
            if tile ~= nil and C.PlatformTile:_isInstance(tile) then ---@cast tile PlatformTile
                if not tile.building then
                    S._gameMapSelection:setSelectedTile(tile)
                    local towerType = C.TowerType.values[math.random(#C.TowerType.values)]
                    S.tower:buildTowerActionOnSelectedTile(towerType)
                end
            end
        end
    end
    S._gameMapSelection:setSelectedTile(nil)

    logger:i("Done")
end

cmd.add_enemy = function(enemyType, speed, health, killScore, killBounty, killExp, tileX, tileY, sideShift)
    if (enemyType == "?") then
        return {
            args = "EnemyType|string enemyType, float speed, float health, int killScore, int killBounty, int killExp, int tileX, int tileY, int sideShift",
            descr = "Spawn an enemy"
        }
    end

    enemyType = utils.toEnum(enemyType, C.EnemyType, true) --[[@as EnemyType]]
    if not enemyType then return nil end

    local creep = C.Game.i.enemyManager:getFactory(enemyType):obtain()
    creep:setSpeed(speed)
    creep.maxHealth = health
    creep:setHealth(health)
    creep.killScore = killScore
    creep.bounty = killBounty
    creep:setKillExp(killExp)

    local tile = S.map:getMap():getTile(tileX, tileY)
    S.enemy:addEnemyWithFirstSpawn(creep, tile, sideShift)
end