local logger = C.TLog:forTag("lb-headless")

local THREAD_COUNT = C.Runtime:getRuntime():availableProcessors()
local RUNS_COUNT = 3

---@class LootSimTask
---@field progress AtomicInteger
---@field variant LootSimVariant
---@field progressBar ProgressBar

---@param simVariants LootSimVariant[] sim variants
---@param printSimResults fun(statsReport:table) a function which will receive stats report when finished
return function(simVariants, printSimResults)
    ---@type LootSimTask[]
    local tasks = {}

    ---@type table
    local statsReport = {}

    local running = C.AtomicBoolean.new()
    running:set(true)

    local pbStyle = C.ProgressBarStyle.new_2D(
        C.Game.i.assetManager:getDrawable("blank"):tint(C.MaterialColor.GREY.P800),
        C.Game.i.assetManager:getDrawable("blank"):tint(C.MaterialColor.LIGHT_BLUE.P500)
    )
    for _, simVariant in pairs(simVariants) do
        tasks[#tasks + 1] = {
            variant = simVariant,
            progress = C.AtomicInteger.new(),
            progressBar = C.ProgressBar.new(0, 100, 1, false, pbStyle)
        }
    end

    -- Window
    local windowStyle = C.Game.i.assetManager:createDefaultWindowStyle()
    windowStyle.resizeable = true
    windowStyle.inheritWidgetMinSize = true
    local window = C.Window.new_WS(windowStyle)
    window:setTitle("Loot benchmark")
    window:addListener(C.WindowListener({
        closed = function(self)
            logger:d("Window is closed - stopping the benchmark")
            running:set(false)
        end
    }))
    local taskList = C.Table.new()
    window.main:add(taskList):grow()
    for _, task in ipairs(tasks) do
        local label = C.Label.new(tostring(task.variant), C.Game.i.assetManager:getDebugLabelStyle())
        taskList:add(label):fillX()
        taskList:add(task.progressBar):minWidth(100):growX():height(16):row()
    end
    window:clampWindowPosition()
    C.Game.i.uiManager:addWindow(window)
    window:fitToContentSimple()
    window:showAtCursor()

    local renderListener

    local stopSimulation = function()
        C.Game.EVENTS:getListeners(C.PreRender):remove(renderListener)
        running:set(false)
    end

    renderListener = C.Listener(function()
        for _, task in pairs(tasks) do
            task.progressBar:setValue(task.progress:get())
        end
    end)
    C.Game.EVENTS:getListeners(C.PreRender):add(renderListener)

    ---@param simVariant LootSimVariant
    ---@param progressCb function
    local runSim = function(simVariant, progressCb)
        if not running:get() then return nil end

        logger:d("configure " .. tostring(simVariant))
        local basicLevel = C.Game.i.basicLevelManager:getLevel(simVariant.levelName)
        local waveCount = simVariant.waves

        local simConfig = C.SimConfig.new()
        simConfig.basicLevelName = basicLevel.name
        simConfig.difficultyMode = C.DifficultyMode.ENDLESS_I
        simConfig.difficultyModeMultiplier = simVariant.difficultyMult
        simConfig.gameMode = C.GameMode.BASIC_LEVELS
        simConfig.startTimestamp = C.Game:getTimestampMillis()
        local S = C.SimConfig:initGSP(simConfig, C.Game.i.progressManager:createProgressSnapshotForState())
        S.gameState.gameStartTimestamp = C.Game:getTimestampMillis() + C.FastRandom:getFairInt(100000)
        simVariant.configurator(S)

        S.events:getListeners(C.WaveStart):add(C.Listener(function(event)
            ---@cast event WaveStart
            local progress = (event:getWave().waveNumber / waveCount) * 100
            if progress > 100 then progress = 100 end
            -- task.progress:set(progress)
            progressCb(progress)

            if event:getWave().waveNumber >= waveCount then
                S.gameState:triggerGameOver(C.GameOverReason.MANUAL)
            end
        end))
        S.wave:setAutoForceWaveEnabled(false)
        S.wave:startNextWave()

        while not S.gameState:isGameOver() and running:get() do
            S:updateSystems()
        end

        progressCb(100)

        if running:get() then
            -- Collect stats
            local loot = S.gameState:getGameLootIssuedItems()
            local rarityStats = S.loot.lootFillsByRarity
            C.Threads:i():runOnMainThread(C.Runnable(function()
                -- One way to synchronize things is to simply post a runnable to the main thread
                if statsReport[simVariant] then
                    statsReport[simVariant].issuedItems.items:addAll(loot.items)
                    for i = 1, #rarityStats do
                        statsReport[simVariant].rarityStats[i] = statsReport[simVariant].rarityStats[i] + rarityStats[i]
                    end
                else
                    statsReport[simVariant] = {
                        issuedItems = loot,
                        rarityStats = rarityStats
                    }
                end
            end))

            logger:d("done " .. tostring(simVariant) .. ", " .. S.gameState.updateNumber .. " frames, " .. S.wave.wave.waveNumber .. " waves, " .. (S.statistics:getStatistic(C.StatisticsType.PT) / 60) .. " in-game minutes")
        else
            logger:d("stopping " .. tostring(simVariant) .. ", " .. S.gameState.updateNumber .. " frames, " .. S.wave.wave.waveNumber .. " waves, " .. (S.statistics:getStatistic(C.StatisticsType.PT) / 60) .. " in-game minutes")
        end
    end

    local mainThread = C.Thread.new_R_S(C.Runnable(function()
        logger:d("Starting the simulation of %s variants on %s threads", #simVariants, THREAD_COUNT)
        local tpe = C.Executors:newFixedThreadPool_i_TF(THREAD_COUNT, C.DaemonThreadFactory.new("Loot benchmark", true))
        local callables = C.ArrayList.new()

        for _, task in pairs(tasks) do
            local simVariant = task.variant

            callables:add(C.Callable(function()
                utils.tryCatch(function()
                    for i = 1, RUNS_COUNT do
                        runSim(simVariant, function(p)
                            task.progress:set(p)
                        end)
                    end
                end, function(e)
                    logger:e("failed to run sim %s", simVariant, e)
                end)
            end))
        end
        tpe:invokeAll(callables)
        local forceStopped = not running:get()
        stopSimulation()

        if not forceStopped then
            -- Print results - post a runnable to make sure it is executed after every worker has saved the report
            C.Threads:i():postRunnable(C.Runnable(function()
                printSimResults(statsReport)
            end))
            logger:i("All done")
        else
            logger:i("Forcefully stopped")
        end
    end), "Loot benchmark sim main")
    mainThread:setDaemon(true)
    mainThread:start()
end