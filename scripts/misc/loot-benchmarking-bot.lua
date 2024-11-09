-- Get a reference loot count in a different scenarios, to be compared later with the new system
-- DifficultyMode is always ENDLESS_I, it simply increases loot drop rate by x1.5

-- LOOT_FREQUENCY 100 <=> 1120
-- LOOT_RARITY 100 <=> 1145
local LOOT_FREQUENCIES = { 100, 200, 500, 1120 } -- 100, 200, 300, 400, 500, 600, 700, 800, 900, 950, 1000, 1020, 1040, 1060, 1080, 1100, 1120
local LOOT_RARITIES = { 100, 200, 500, 1145 } -- 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000, 1100, 1145
local WAVE_COUNTS = { 50, 100, 200, 250 }
local LEVEL_NAMES = { "1.1", "3.2", "5.4" }
local DIFFICULTY_MULTIPLIERS = { 100, 250, 500, 900 } -- endless mode difficulty

local ZSCALE = 0.25
local BD_SHIFT = 0 -- -500

-- Disable instant wave calls
C.Game.i.settingsManager:setInstantAutoWaveCallEnabled(false)

---@class LootSimVariant
---@field lootFrequency number
---@field lootRarity number
---@field waves number
---@field levelName string
---@field difficultyMult number
---@field configurator fun(S:GameSystemProvider)

---@type LootSimVariant[]
local simVariants = {}

---@param lootFrequency number
---@param lootRarity number
local addSimVariant = function(lootFrequency, lootRarity, waveCount, levelName, difficultyMult)
    local configurator = function(S)
        ---@cast S GameSystemProvider
        S.gameState.inUpdateStage = true

        -- Set tower PWR and XP level values
        local targetTile = S.map:getMap():getTargetTileOrThrow()
        targetTile:addGameValue(C.GameValueConfig.new(C.GameValueType.TOWERS_DAMAGE, 200000, false, true))
        targetTile:addGameValue(C.GameValueConfig.new(C.GameValueType.LOOT_FREQUENCY, lootFrequency, true, false))
        targetTile:addGameValue(C.GameValueConfig.new(C.GameValueType.LOOT_RARITY, lootRarity, true, false))

        S.gameState:addMoney(1000000, false)
        S.gameValue:recalculate()

        -- Build towers
        local platforms = S.map:getMap():getTilesByType(C.PlatformTile)
        for i = 1, platforms.size do
            local platform = platforms.items[i] --[[@as PlatformTile]]
            if not platform.building then
                local tower = S.tower:buildTower(C.TowerType.SPLASH, C.Tower.AimStrategy.RANDOM, platform:getX(), platform:getY())
                tower:setUpgradeLevel(10)
                tower:updateCache()
            end
        end

        -- Do some actions periodically
        local ticksToAction = 30 * 60
        S.events:getListeners(C.GameStateTick):add(C.Listener(function()
            ticksToAction = ticksToAction - 1
            if ticksToAction == 0 then
                ticksToAction = 30 * 60
                S.gameState:registerPlayerActivity()
            end
        end))
    end

    ---@type LootSimVariant
    local simVariant = { 
        lootFrequency = lootFrequency, 
        lootRarity = lootRarity,
        waves = waveCount,
        levelName = levelName,
        difficultyMult = difficultyMult,
        configurator = configurator
    }
    setmetatable(simVariant, {
        __tostring = function(self)
            return "F:" .. self.lootFrequency .. ",R:" .. self.lootRarity .. ",W:" .. self.waves .. ",L:" .. self.levelName .. ",D:" .. self.difficultyMult
        end
    })
    simVariants[#simVariants + 1] = simVariant
end

for _, freq in ipairs(LOOT_FREQUENCIES) do
    for _, rar in ipairs(LOOT_RARITIES) do
        for _, waves in ipairs(WAVE_COUNTS) do
            for _, level in ipairs(LEVEL_NAMES) do
                for _, diffMul in ipairs(DIFFICULTY_MULTIPLIERS) do
                    addSimVariant(freq, rar, waves, level, diffMul)
                end
            end
        end
    end
end

local printSimResults = function(statsReport)
    local resultsSorted = {}
    for variant, report in pairs(statsReport) do
        resultsSorted[#resultsSorted + 1] = {
            variant = variant,
            report = report
        }
    end
    table.sort(resultsSorted, function(a, b)
        local aVariant = a.variant --[[@as LootSimVariant]]
        local bVariant = b.variant --[[@as LootSimVariant]]

        if aVariant.levelName < bVariant.levelName then
            return true
        elseif aVariant.levelName > bVariant.levelName then
            return false
        end

        if aVariant.waves < bVariant.waves then
            return true
        elseif aVariant.waves > bVariant.waves then
            return false
        end

        if aVariant.difficultyMult < bVariant.difficultyMult then
            return true
        elseif aVariant.difficultyMult > bVariant.difficultyMult then
            return false
        end

        if aVariant.lootFrequency < bVariant.lootFrequency then
            return true
        elseif aVariant.lootFrequency > bVariant.lootFrequency then
            return false
        end

        if aVariant.lootRarity < bVariant.lootRarity then
            return true
        elseif aVariant.lootRarity > bVariant.lootRarity then
            return false
        end

        return false
    end)

    local sb = "level,waves,difficulty,rarity,frequency,common,rare,veryRare,epic,legendary,total,bitDust\n"
    for _, e in ipairs(resultsSorted) do
        local variant = e.variant --[[@as LootSimVariant]]
        local issuedItems = e.report.issuedItems --[[@as IssuedItems]]
        local rarityStats = e.report.rarityStats
        ---@cast rarityStats number[]

        local rt = C.RarityType

        local byRarity = {}
        byRarity[C.RarityType.COMMON] = rarityStats[rt.COMMON:ordinal() + 1]
        byRarity[C.RarityType.RARE] = rarityStats[rt.RARE:ordinal() + 1]
        byRarity[C.RarityType.VERY_RARE] = rarityStats[rt.VERY_RARE:ordinal() + 1]
        byRarity[C.RarityType.EPIC] = rarityStats[rt.EPIC:ordinal() + 1]
        byRarity[C.RarityType.LEGENDARY] = rarityStats[rt.LEGENDARY:ordinal() + 1]
        local paperCount = 0
        local bdCount = 0

        for i = 0, issuedItems.items.size - 1 do
            local stack = issuedItems.items:get(i) --[[@as ItemStack]]
            local item = stack:getItem()
            if C.GreenPaperItem:_isInstance(item) then
                paperCount = paperCount + stack:getCount()
            elseif C.BitDustItem:_isInstance(item) then
                bdCount = bdCount + stack:getCount()
            else
                -- byRarity[item:getRarity()] = byRarity[item:getRarity()] + stack:getCount()
            end
        end

        local variantStr = variant.levelName .. "," .. variant.waves .. "," .. variant.difficultyMult .. "," .. variant.lootRarity .. "," .. variant.lootFrequency
        local cntCommon = byRarity[rt.COMMON] * ZSCALE
        local cntRare = byRarity[rt.RARE] * ZSCALE
        local cntVeryRare = byRarity[rt.VERY_RARE] * ZSCALE
        local cntEpic = byRarity[rt.EPIC] * ZSCALE
        local cntLegendary = byRarity[rt.LEGENDARY] * ZSCALE
        sb = sb .. variantStr .. ","
        sb = sb .. cntCommon .. ","
        sb = sb .. cntRare .. ","
        sb = sb .. cntVeryRare .. ","
        sb = sb .. cntEpic .. ","
        sb = sb .. cntLegendary .. ","
        sb = sb .. (cntCommon + cntRare + cntVeryRare + cntEpic + cntLegendary) .. ","
        sb = sb .. (bdCount * ZSCALE + BD_SHIFT)
        sb = sb .. "\n"
    end

    C.SFileHandle.new("cache/script-data/loot-drops.csv"):writeString(sb, false)
end

dofile("scripts/misc/loot-benchmark/headless.lua")(simVariants, printSimResults)
