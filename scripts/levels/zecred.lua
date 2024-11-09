--[[
== Zecred ==

Enemies
explode,
miners give
bonuses.

--]]

local logger = C.TLog:forTag("zecred.lua")

-- global variables
local roadTiles = {} -- Fixed desync in 1.9.1: using SpawnTile as a table key works but fails during sync check, because two game sessions do not use shared SpawnTile objects. Using a string representation as a key instead

--- @type GameValueConfig
local gvProjSpeed

--- @type GameValueConfig
local gvRotationSpeed

--- @type GameValueConfig
local gvAttackSpeed

--- @type GameValueConfig
local gvUpgradeLevel

local coinsAdded = 0
local healthAdded = 0


local UIV = { -- UI variables / not sync checked
    _noSyncCheck = true,

    uiNeedsUpdate = false,
    uiLayer = nil, -- becomes nil after deserialization (UiLayer is not in registry)
    statsLabel = nil  -- becomes nil after deserialization (Label is not in registry)
}

---@param enemyType EnemyType
---@param speed number
---@param health number
---@param killScore number
---@param killBounty number
---@param killExp number
---@param tileX number
---@param tileY number
---@param sideShift number
local addEnemy = function(enemyType, speed, health, killScore, killBounty, killExp, tileX, tileY, sideShift)
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

local getSpawnTileId = function(spawnTile)
    return tostring(spawnTile:getX()) .. ":" .. tostring(spawnTile:getY())
end

-- System listeners --------------------------------------------------------------------------------

local onEnemySpawn = C.Listener(function(event)
    ---@cast event EnemySpawn

    local enemy = event:getEnemy()
    if enemy.wave == nil or not enemy.spawnTile then
        return nil
    end

    local roads = roadTiles[getSpawnTileId(enemy.spawnTile)]
    if not roads then return nil end

    local countMult = 1 + enemy.wave.waveNumber * 0.05

    local spawnedEnemies = S.map.spawnedEnemies.size
    local maxEnemies = 12000
    if spawnedEnemies > maxEnemies then
        countMult = 0
    else
        local used = spawnedEnemies / maxEnemies
        if used > 0.5 then
            countMult = countMult * (1 - used)
        end
    end
    while countMult > 0 do
        if countMult < 1 and S.gameState:randomFloat() > countMult then
            countMult = 0
        else
            local road = roads[S.gameState:randomInt(#roads) + 1]
            addEnemy(
                    enemy.type,
                    enemy:getSpeed(),
                    enemy.maxHealth,
                    0,
                    0,
                    enemy:getKillExp(),
                    road:getX(),
                    road:getY(),
                    -1)

            countMult = countMult - 1
        end
    end
end)

local onMinerResourceChange = C.Listener(function(event)
    ---@cast event MinerResourceChange

    if event:isMined() then
        local resourceType = event:getResourceType()
        local delta = event:getDelta()

        S.gameState:removeResources(resourceType, delta);

        if resourceType == C.ResourceType.SCALAR then
            S.gameState:addMoney(5 * delta, true)
            coinsAdded = coinsAdded + 5 * delta
        elseif resourceType == C.ResourceType.VECTOR then
            gvProjSpeed:setValue(gvProjSpeed:getValue() + 1)
            gvRotationSpeed:setValue(gvRotationSpeed:getValue() + 1)
        elseif resourceType == C.ResourceType.MATRIX then
            gvAttackSpeed:setValue(gvAttackSpeed:getValue() + 1)
        elseif resourceType == C.ResourceType.TENSOR then
            S.gameState:addHealth(delta)
            healthAdded = healthAdded + delta
        elseif resourceType == C.ResourceType.INFIAR then
            if gvUpgradeLevel:getValue() < 9 then
                gvUpgradeLevel:setValue(gvUpgradeLevel:getValue() + 1)
            end
        end

        S.gameValue:recalculate()

        UIV.uiNeedsUpdate = true
    end
end)

-- Functions and script system listeners -----------------------------------------------------------

--- Listens for state restoration (state being deserialized)
--- It is a proper place to restore bindings and recreate UI
--- You can also do that during runtime by checking whether the variable became empty with == nil
local function initializeUI()
    if not S.CFG.headless then
        UIV.uiLayer = C.Game.i.uiManager:addLayer(C.MainUiLayer.SCREEN, 9009, "zecred stats")
        UIV.statsLabel = C.Label.new("", C.Game.i.assetManager:getLabelStyle(C.Config.FONT_SIZE_SMALL))
        UIV.statsLabel:setAlignment(0)

        local cell = UIV.uiLayer:getTable():add(UIV.statsLabel)
        cell:expandY():bottom():padBottom(16 + math.random() * 10)

        S.events:getListeners(com.prineside.tdi2.events.game.Render.class):add(C.Listener(function(_)
            if UIV.uiNeedsUpdate and UIV.uiLayer ~= nil then
                UIV.uiNeedsUpdate = false
                UIV.statsLabel:setText("Projectile and rotation speed: " .. gvProjSpeed:getValue() .. "\n"
                        .. "Attack speed: " .. gvAttackSpeed:getValue() .. "\n"
                        .. "Upgrade level: " .. gvUpgradeLevel:getValue() .. "\n"
                        .. "Coins: " .. coinsAdded .. "\n"
                        .. "Health: " .. healthAdded)
            end
        end))
        UIV.uiNeedsUpdate = true

        logger:d("UI recreated")
    end
    logger:d("State restored")
end

S.events:getListeners(C.SystemsPostSetup):addStateAffecting(C.Listener(function()
    local mod = C.BaseExplodesOnEnemyPass.new()
    mod.baseCooldown = 1
    mod.baseRange = 16
    S.gameplayMod:activateMod(mod, "zecred script")

    local spawnTiles = S.map:getMap():getTilesByType(C.SpawnTile)
    local allRoadTiles = S.map:getMap():getTilesByType(C.RoadTile)
    for j = 1, spawnTiles.size do
        local spawnTile = spawnTiles.items[j] --[[@as SpawnTile]]
        local linkedRoads = {}

        for i = 1, allRoadTiles.size do
            local roadTile = allRoadTiles.items[i] --[[@as RoadTile]]
            local distX = math.abs(roadTile:getX() - spawnTile:getX())
            local distY = math.abs(roadTile:getY() - spawnTile:getY())
            if distX < 10 and distY < 10 then
                linkedRoads[#linkedRoads + 1] = allRoadTiles.items[i]
            end
        end

        --logger:d("roads linked to %s: %s", spawnTile, utils.printr(linkedRoads))
        if #linkedRoads ~= 0 then
            roadTiles[getSpawnTileId(spawnTile)] = linkedRoads
        end
    end

    local targetTile = S.map:getMap():getTargetTileOrThrow()
    gvProjSpeed = C.GameValueConfig.new(C.GameValueType.TOWERS_PROJECTILE_SPEED, 0, false, false)
    targetTile:addGameValue(gvProjSpeed)
    gvRotationSpeed = C.GameValueConfig.new(C.GameValueType.TOWERS_ROTATION_SPEED, 0, false, false)
    targetTile:addGameValue(gvRotationSpeed)
    gvAttackSpeed = C.GameValueConfig.new(C.GameValueType.TOWERS_ATTACK_SPEED, 0, false, false)
    targetTile:addGameValue(gvAttackSpeed)
    gvUpgradeLevel = C.GameValueConfig.new(C.GameValueType.TOWERS_MAX_UPGRADE_LEVEL, 0, false, false)
    targetTile:addGameValue(gvUpgradeLevel)

    S.events:getListeners(C.SystemsDispose):addStateAffecting(C.Listener(function(_)
        if UIV.uiLayer ~= nil then
            C.Game.i.uiManager:removeLayer(UIV.uiLayer)
            UIV.uiLayer = nil
        end
    end))

    S.events:getListeners(C.EnemyDie):addStateAffecting(C.Listener(function(event)
        ---@cast event EnemyDie

        local record = event:getLastDamage()
        local enemy = record:getEnemy()
        local explosion = S.explosion.F.GENERIC:obtain() --[[@as GenericExplosion]]
        local tower = record:getTower()

        local enemyFactory = C.Game.i.enemyManager:getFactory(enemy.type)
        explosion:setup(
            tower,
            enemy:getPosition().x,
            enemy:getPosition().y,
            enemy.maxHealth * 0.05,
            1.25,
            0,
            0,
            0,
            enemyFactory:getColor(),
            enemyFactory:getColor()
        )
        S.explosion:register(explosion)
        explosion:explode()
    end))
    S.events:getListeners(C.EnemySpawn):addStateAffecting(onEnemySpawn)
    S.events:getListeners(C.MinerResourceChange):addStateAffecting(onMinerResourceChange)

    initializeUI()
end))

S.events:getListeners(C.SystemsStateRestore):addStateAffecting(C.Listener(initializeUI))
