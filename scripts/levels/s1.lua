_G.StaticGemEnemies = require "scripts.misc.static-gem-enemies"

local logger = C.TLog:forTag("s1")

StaticGemEnemies.gemActions["bonus_reward"] = {
    -- bonus_reward|tier
    action = function(gem, args)
        local tier = tonumber(args[2]) --[[@as number]]

        local papersBase = S.loot.inventoryStatistics.papersPerHourEstimate
        papersBase = papersBase * 0.5
        if papersBase < 1000 then papersBase = 1000 end
        local papersMult = 0
        logger:d("Tier %s", tier, S._input)
        if tier == 1 then
            -- Tier 1
            papersMult = 0.007

            if S.gameState:randomFloat() < 0.025 then
                local newTile = C.Game.i.tileManager.F.PLATFORM:createRandom(0, S.gameState:getRandom())
                S.map:setTile(gem.x, gem.y, newTile)
            end
        elseif tier == 2 then
            -- Tier 2
            papersMult = 0.015

            if S.gameState:randomFloat() < 0.035 then
                local newTile = C.Game.i.tileManager.F.PLATFORM:createRandom(0.5, S.gameState:getRandom())
                S.map:setTile(gem.x, gem.y, newTile)
            end
        elseif tier == 3 then
            -- Tier 3
            papersMult = 0.02

            if S.gameState:randomFloat() < 0.05 then
                local newTile = C.Game.i.tileManager.F.PLATFORM:createRandom(1, S.gameState:getRandom())
                S.map:setTile(gem.x, gem.y, newTile)
            end
        elseif tier == 4 then
            -- Tier 4
            papersMult = 0.025

            if S.gameState:randomFloat() < 0.04 then
                local newTile = C.Game.i.tileManager.F.GAME_VALUE:createTypeDelta(C.GameValueType.TOWERS_RANGE, 5)
                S.map:setTile(gem.x, gem.y, newTile)
            end
        end

        if papersMult > 0 then
            -- Papers
            local stack = C.ItemStack.new_I_i(C.Item.D.GREEN_PAPER, papersBase * papersMult)
            local v2 = C.Vector2.new_V2(gem.enemy:getPosition())
            if S._input ~= nil then S._input.cameraController:mapToStage(v2) end
            S.gameState:addLootIssuedPrizes(stack, v2.x, v2.y, 2)
        end
    end,
    createMenuActor = function(table, gem, args)
        local container = C.Table.new()
        table:add(container):growX()

        local label = C.Label.new("???", C.Game.i.assetManager:getLabelStyle(CFG.FONT_SIZE_SMALL))
        container:add(label)
        container:add():height(1):growX()

        return container
    end
}

S.events:getListeners(C.EnemySpawn):addStateAffecting(C.Listener(function (e)
    ---@cast e EnemySpawn
    local enemy = e:getEnemy()
    if enemy.type == C.EnemyType.METAPHOR_BOSS then
        enemy:setMaxHealth(1000000)
        enemy:setHealth(1000000)
        enemy.lowAimPriority:addReason("script")
    elseif enemy.type == C.EnemyType.METAPHOR_BOSS_CREEP then
        enemy:setMaxHealth(1000000)
        enemy:setHealth(1000000)
        enemy.lowAimPriority:addReason("script")
    end
end))

S.events:getListeners(C.SystemsPostSetup):addStateAffecting(C.Listener(function (_)
    StaticGemEnemies.lowAimPriority = false

    -- Replace platforms with gem dummies

    _G.StaticGemEnemies.start()
end))