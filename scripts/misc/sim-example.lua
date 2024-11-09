local logger = C.TLog:forTag("sim-example.lua")

logger:d("Started")
local sCfg = C.GameSystemProvider.SystemsConfig.new(C.GameSystemProvider.SystemsConfig.Setup.GAME, true)
local S = C.GameSystemProvider.new(sCfg)
logger:d("Created GSP")
S:createSystems()
logger:d("Created systems")

-- Configure systems
S.gameState.inUpdateStage = true
S.gameState.gameStartTimestamp = C.Game:getTimestampMillis()
S.gameState.difficultyMode = C.DifficultyMode.NORMAL
S.gameState.modeDifficultyMultiplier = 100 -- ProgressManager.clampModeDifficulty(difficultyMode, modeDifficultyMultiplier, snapshot);
S.gameState.gameMode = C.GameStateSystem.GameMode.BASIC_LEVELS
S.gameState.basicLevelName = "1.1"
-- S.gameState.startingAbilitiesConfiguration = abilitiesConfiguration;
-- S.gameState.canLootCases = canLootCases;
-- S.gameState.encryptedChestsInInventory = encryptedChestsInInventory;
-- S.gameState.lootBoostEnabled = lootBoostEnabled;
-- S.gameState.rarityBoostEnabled = rarityBoostEnabled;
-- S.gameState.userMapId = nil
-- S.gameState.userMapOriginalSeed = userMap.map:generateSeed()

local basicLevel = C.Game.i.basicLevelManager:getLevel("1.1")
-- if (basicLevel.enemyWaves != null) {
--     S.wave.mode = WaveSystem.Mode.PREDEFINED;
--     S.wave.predefinedWaveTemplates = basicLevel.enemyWaves;
-- }

S.gameState:setSeed(basicLevel.seed)

local map = basicLevel:getMap():cpy()
-- map.multiplyPortalsDifficulty(S.gameState.modeDifficultyMultiplier * 0.01f);
S.gameState.averageDifficulty = map:getAverageDifficulty()
S.map:setMap(map)

S.wave:setDifficultyExpectedPlaytime(basicLevel:getDifficultyExpectedPlaytime())
local wbs = map:getBossWaves();
if wbs then
    S.wave:setBossWaves(wbs:cpy())
end
S.wave:setBossWaves(map:getBossWaves())

local snapshot = C.GameValueManager:createSnapshot( -- GV snapshot (based on research / trophies / level)
    nil,
    S.gameState.difficultyMode,
    true,
    basicLevel,
    S.map:getMap():getTargetTileOrThrow():isUseStockGameValues(),
    false,
    C.Game.i.progressManager:createProgressSnapshotForState()
)
S.gameValue:setGlobalSnapshot(snapshot)

S.loot.inventoryStatistics = C.Game.i.progressManager:getInventoryStatistics()

-- if (DifficultyMode.isEndless(difficultyMode) && basicLevel != null && basicLevel.hasLeaderboards) {
--     S.map.getMap().targetTile.getGameValues().add(new GameValueConfig(GameValueType.ENEMIES_WALK_ON_PLATFORMS, 1, true, false));
--     S.map.getMap().targetTile.getGameValues().add(new GameValueConfig(GameValueType.ENEMIES_MAX_PATH_SEARCHES, 2, true, false));
-- }
logger:d("Configured systems")

S:setupSystems()
logger:d("Set-up systems")

S:postSetupSystems()
logger:d("Post set-up systems")

S.wave:startNextWave()
logger:d("Full start, frame: %s", S.gameState.updateNumber)
S:updateSystems()
logger:d("First update, frame: %s", S.gameState.updateNumber)

-- Add some listeners
-- S.gameState:addListener(GameStateSystemListener ...) - see other scripts for an example
-- To add some player actions, pre-fill GameStateSystem with pushAction(Action action, int updateNumber) at any frame prior
-- Actions can be added at any time, just make sure the target frame has not been simulated yet

-- Now just simulate everything
-- Any data can be retrieved from S's systems, anything can be modified on the go, any listeners can be added / removed etc

-- Example player action - build Basic tower on 3:2 at frame 50
local action = C.BuildTowerAction.new_TT_AS_2i(C.TowerType.BASIC, C.Tower.AimStrategy.RANDOM, 3, 2)
S.gameState:pushAction(action, 50)

local startTime = C.Game:getTimestampMillis()
local lastCoins = 0
while (not S.gameState:isGameOver()) do
    local dCoins = math.abs(lastCoins - S.gameState:getMoney())
    if dCoins >= 5 then
        -- Print only when coins changed by at least 5
        lastCoins = S.gameState:getMoney()
        logger:d("F: %s, C: %s", S.gameState.updateNumber, S.gameState:getMoney())
    end
    S:updateSystems()
end

logger:d("Simulated %s frames in %sms", S.gameState.updateNumber, C.Game:getTimestampMillis() - startTime)
logger:d("Game ended, score: %s", S.gameState:getScore())

-- Note: this simulation lasts for 20k+ frames, be careful with logging
-- At frame 50 coins should be reduced (Basic tower has been built)
-- Have fun