-- This scripts generates sim variants and runs one of two sim variants (see the end of this script)

-- A single constant to rule them all:
local BOT_MODE = "Combined" -- nil / "PWR" / "XP level" / "Combined"

------------------------------------------------------------

-- Comment out towers that are not needed
local TOWER_TYPES = {
    C.TowerType.AIR,
    C.TowerType.BASIC,
    C.TowerType.BLAST,
    C.TowerType.CANNON,
    C.TowerType.CRUSHER,
    C.TowerType.FLAMETHROWER,
    C.TowerType.GAUSS,
    C.TowerType.LASER,
    C.TowerType.MINIGUN,
    C.TowerType.MISSILE,
    C.TowerType.MULTISHOT,
    C.TowerType.SNIPER,
    C.TowerType.SPLASH,
    C.TowerType.TESLA,
    C.TowerType.VENOM,
}

local MULTITHREADED_MODE = true
local MANUAL_VARIANTS_MODE = true

-- Configurations for all-combination variants
local PWR_VALUES = {
    0,
    10,
    20,
    30,
    40,
    50,
    60,
    90,
    120,
}
local XP_LEVEL_VALUES = {
    1, -- 0 is not possible
    5,
    10,
    15,
    20,
    25,
    30,
    35,
    40,
}
local UPGRADE_LEVELS = {
    10
}
local MANUAL_LVL_PWR_COMBOS = {
    { 1, 0 },
    { 2, 0.7 },
    { 3, 1.4 },
    { 4, 2.1 },
    { 5, 2.8 },
    { 6, 3.5 },
    { 7, 4.2 },
    { 8, 4.9 },
    { 9, 5.6 },
    { 10, 6.3 },
    { 11, 8.2 },
    { 12, 10.1 },
    { 13, 12.0 },
    { 14, 13.9 },
    { 15, 15.8 },
    { 16, 17.7 },
    { 17, 19.6 },
    { 18, 21.5 },
    { 19, 23.4 },
    { 20, 25.3 },
    { 21, 27.2 },
    { 22, 29.1 },
    { 23, 31 },
    { 24, 32.9 },
    { 25, 34.8 },
    { 26, 36.7 },
    { 27, 38.6 },
    { 28, 40.5 },
    { 29, 42.4 },
    { 30, 44.3 },
    { 31, 46.2 },
    { 32, 48.1 },
    { 33, 50 },
    { 34, 51.9 },
    { 35, 53.8 },
    { 36, 55.7 },
    { 37, 57.6 },
    { 38, 59.5 },
    { 39, 61.4 },
    { 40, 63.3 }
}

------

if BOT_MODE then
    if BOT_MODE == "PWR" then
        -- PWR charts
        XP_LEVEL_VALUES = { 1 }
        MANUAL_VARIANTS_MODE = false
    elseif BOT_MODE == "XP level" then
        -- XP level charts
        PWR_VALUES = { 0 }
        MANUAL_VARIANTS_MODE = false
    elseif BOT_MODE == "Combined" then
        -- Combined (manual variants)
        MANUAL_VARIANTS_MODE = true
    else
        error("Unknown bot mode: " .. tostring(BOT_MODE))
    end
end

------

local TOWER_AIM_MODE = C.Tower.AimStrategy.RANDOM
local TOWER_SPECIFIC_CONFIGS = {}
TOWER_SPECIFIC_CONFIGS[C.TowerType.TESLA] = function(_, tower)
    ---@cast tower TeslaTower
    tower:setAimStrategy(C.Tower.AimStrategy.FIRST)
end

local WAVE_COUNT = 700
local LEVEL_NAME = "towers_level_pwr_benchmark"

-- Disable instant wave calls
C.Game.i.settingsManager:setInstantAutoWaveCallEnabled(false)

local basicLevel = C.Game.i.basicLevelManager:getLevel(LEVEL_NAME)

---@class SimVariant
---@field towerType TowerType
---@field pwr number
---@field xpLvl number
---@field upgLvl number
---@field configurator fun(S:GameSystemProvider)

---@type SimVariant[]
local simVariants = {}

---@param pwr number
---@param xpLvl number
---@param towerType TowerType
---@param upgLvl number
local addSimVariant = function(pwr, xpLvl, towerType, upgLvl)
    local configurator = function(S)
        ---@cast S GameSystemProvider
        S.gameState.inUpdateStage = true

        -- Disable auto-installed abilities
        local abilityRules = S.tower.towerAbilityCategoryRules
        for i = 1, #abilityRules do
            abilityRules[i].autoInstallSingleVariant = false
        end

        -- Set tower PWR and XP level values
        local targetTile = S.map:getMap():getTargetTileOrThrow()
        local gvtStartExpLevel = C.Game.i.towerManager:getStartingLevelGameValueType(towerType)
        local gvtMaxExpLevel = C.Game.i.towerManager:getMaxExpLevelGameValueType(towerType)
        local gvtMaxUpgLevel = C.Game.i.towerManager:getMaxUpgradeLevelGameValueType(towerType)
        local gvtStartPwr = C.Game.i.towerManager:getStartingPwrGameValueType(towerType)
        local gvtPplTill = C.Game.i.towerManager:getPplTill10GameValueType(towerType)
        local gvtPplAfter = C.Game.i.towerManager:getPplAfter10GameValueType(towerType)

        targetTile:addGameValue(C.GameValueConfig.new(gvtStartExpLevel, xpLvl, true, false))
        targetTile:addGameValue(C.GameValueConfig.new(gvtMaxExpLevel, xpLvl, true, false))
        targetTile:addGameValue(C.GameValueConfig.new(gvtMaxUpgLevel, upgLvl, true, false))
        targetTile:addGameValue(C.GameValueConfig.new(gvtStartPwr, pwr, true, false))
        targetTile:addGameValue(C.GameValueConfig.new(gvtPplTill, 0, true, false))
        targetTile:addGameValue(C.GameValueConfig.new(gvtPplAfter, 0, true, false))

        targetTile:addGameValue(C.GameValueConfig.new(C.GameValueType.TOWER_FREEZING_MAX_EXP_LEVEL, 0, true, false))

        targetTile:addGameValue(C.GameValueConfig.new(C.GameValueType.TOWERS_STARTING_PWR, 0, true, false))
        targetTile:addGameValue(C.GameValueConfig.new(C.GameValueType.TOWERS_POWER_PER_LEVEL_TILL_10, 0, true, false))
        targetTile:addGameValue(C.GameValueConfig.new(C.GameValueType.TOWERS_POWER_PER_LEVEL_AFTER_10, 0, true, false))
        targetTile:addGameValue(C.GameValueConfig.new(C.GameValueType.TOWERS_STARTING_LEVEL, 0, true, false))
        targetTile:addGameValue(C.GameValueConfig.new(C.GameValueType.TOWERS_MAX_EXP_LEVEL, 0, true, false))
        targetTile:addGameValue(C.GameValueConfig.new(C.GameValueType.TOWERS_MAX_UPGRADE_LEVEL, 0, true, false))

        S.gameValue:recalculate()

        -- Build towers
        local extraTowerCfg = TOWER_SPECIFIC_CONFIGS[towerType]
        local platforms = S.map:getMap():getTilesByType(C.PlatformTile)
        for i = 1, platforms.size do
            local platform = platforms.items[i] --[[@as PlatformTile]]
            if platform.bonusType == C.SpaceTileBonusType.BONUS_COINS and not platform.building then
                local tower = S.tower:buildTower(towerType, TOWER_AIM_MODE, platform:getX(), platform:getY())
                tower:setUpgradeLevel(upgLvl)
                if extraTowerCfg then
                    extraTowerCfg(S, tower)
                end
                tower:updateCache()
            end
        end
    end

    ---@type SimVariant
    local simVariant = { pwr = pwr, xpLvl = xpLvl, towerType = towerType, upgLvl = upgLvl, configurator = configurator }
    setmetatable(simVariant, {
        __tostring = function(self)
            return "pwr:" .. self.pwr .. "/xpLvl:" .. self.xpLvl .. "/upgLvl:" .. self.upgLvl .. "/towerType:" .. tostring(self.towerType)
        end
    })
    simVariants[#simVariants + 1] = simVariant
end

if MANUAL_VARIANTS_MODE then
    -- Manual combinations
    for _, towerType in ipairs(TOWER_TYPES) do
        for _, lvlPwr in ipairs(MANUAL_LVL_PWR_COMBOS) do
            addSimVariant(lvlPwr[2], lvlPwr[1], towerType, 10)
        end
    end
else
    -- All combinations
    for _, pwr in ipairs(PWR_VALUES) do
        for _, xpLvl in ipairs(XP_LEVEL_VALUES) do
            for _, towerType in ipairs(TOWER_TYPES) do
                for _, upgLvl in ipairs(UPGRADE_LEVELS) do
                    addSimVariant(pwr, xpLvl, towerType, upgLvl)
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
            report = report,
        }
    end
    table.sort(resultsSorted, function(a, b)
        local aVariant = a.variant --[[@as SimVariant]]
        local bVariant = b.variant --[[@as SimVariant]]
        if aVariant.towerType:name() < bVariant.towerType:name() then
            return true
        elseif aVariant.towerType:name() > bVariant.towerType:name() then
            return false
        end

        if aVariant.xpLvl < bVariant.xpLvl then
            return true
        elseif aVariant.xpLvl > bVariant.xpLvl then
            return false
        end

        if aVariant.pwr < bVariant.pwr then
            return true
        elseif aVariant.pwr < bVariant.pwr then
            return false
        end

        if aVariant.upgLvl < bVariant.upgLvl then
            return true
        elseif aVariant.upgLvl > bVariant.upgLvl then
            return false
        end

        return false
    end)

    -- CSV
    local sb = "tower,xpLevel,upgradeLevel,pwr,damage,mdps,damageDifference,mdpsDifference\n"
    local baselines = {} -- TowerType -> Baseline
    for _, e in ipairs(resultsSorted) do
        local variant = e.variant
        local report = e.report

        local baseline = e
        if baselines[variant.towerType] then
            baseline = baselines[variant.towerType]
        else
            baselines[variant.towerType] = e
        end

        sb = sb .. variant.towerType:name() .. ","
        sb = sb .. variant.xpLvl .. ","
        sb = sb .. variant.upgLvl .. ","
        sb = sb .. variant.pwr .. ","
        sb = sb .. C.Long:toString_l(report.damage) .. "," -- Lua always uses double and casts it to the type needed. We pass double as long here to print the number as long
        sb = sb .. C.Long:toString_l(report.mdps) .. ","

        local damageDifference = report.damage / baseline.report.damage
        local mdpsDifference = report.mdps / baseline.report.mdps
        sb = sb .. C.StringFormatter:compactNumberWithPrecision(damageDifference, 3):toString() .. ","
        sb = sb .. C.StringFormatter:compactNumberWithPrecision(mdpsDifference, 3):toString() .. "\n"
    end
    C.TLog:forTag("towers-benchmark"):i("\n" .. sb:toString())
end

if MULTITHREADED_MODE then
    -- Headless run, multithreaded and much faster
    dofile("scripts/misc/tower-benchmark/headless.lua")(basicLevel, WAVE_COUNT, simVariants, printSimResults)
else
    -- Full run, single-threaded but allows to see what happens
    dofile("scripts/misc/tower-benchmark/full.lua")(basicLevel, WAVE_COUNT, simVariants, printSimResults)
end
