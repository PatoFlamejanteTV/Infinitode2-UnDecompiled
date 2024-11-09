local logger = C.TLog:forTag("tbs-headless")

local THREAD_COUNT = C.Runtime:getRuntime():availableProcessors()

---@class SimTask
---@field progress AtomicInteger
---@field variant SimVariant
---@field progressBar ProgressBar

---@param basicLevel BasicLevel a level to run the sim on
---@param waveCount number number of waves to run each sim for
---@param simVariants SimVariant[] sim variants
---@param printSimResults fun(statsReport:table) a function which will receive stats report when finished
return function(basicLevel, waveCount, simVariants, printSimResults)
    ---@type SimTask[]
    local tasks = {}

    local statsReport = {}

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
    window:setTitle("Towers benchmark")
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
    end

    renderListener = C.Listener(function()
        for _, task in pairs(tasks) do
            task.progressBar:setValue(task.progress:get())
        end
    end)
    C.Game.EVENTS:getListeners(C.PreRender):add(renderListener)


    local mainThread = C.Thread.new_R_S(C.Runnable(function()
        logger:d("Starting the simulation of %s variants on %s threads", #simVariants, THREAD_COUNT)
        local tpe = C.Executors:newFixedThreadPool_i_TF(THREAD_COUNT, C.DaemonThreadFactory.new("Towers benchmark", true))
        local callables = C.ArrayList.new()

        local progressSnapshot = C.Game.i.progressManager:createProgressSnapshotForState()
        for _, task in pairs(tasks) do
            local simVariant = task.variant

            callables:add(C.Callable(function()
                utils.tryCatch(function()
                    logger:d("configure " .. tostring(simVariant))
                    local simConfig = C.SimConfig.new()
                    simConfig.basicLevelName = basicLevel.name
                    simConfig.difficultyMode = C.Game.i.progressManager:getDifficultyMode()
                    simConfig.difficultyModeMultiplier = C.Game.i.progressManager:getDifficultyModeDiffMultiplier(simConfig.difficultyMode)
                    simConfig.gameMode = C.GameMode.BASIC_LEVELS
                    simConfig.startTimestamp = C.Game:getTimestampMillis()
                    local S = C.SimConfig:initGSP(simConfig, progressSnapshot)
                    simVariant.configurator(S)

                    S.events:getListeners(C.WaveStart):add(C.Listener(function(event)
                        ---@cast event WaveStart
                        local progress = (event:getWave().waveNumber / waveCount) * 100
                        if progress > 100 then progress = 100 end
                        task.progress:set(progress)

                        if event:getWave().waveNumber >= waveCount then
                            S.gameState:triggerGameOver(C.GameOverReason.MANUAL)
                        end
                    end))
                    S.wave:setAutoForceWaveEnabled(true)
                    S.wave:startNextWave()

                    while not S.gameState:isGameOver() do
                        S:updateSystems()
                    end

                    -- Collect stats
                    local totalDamage = S.statistics:getCurrentGameStatistic(C.StatisticsType.TDD)
                    local mdps = S.damage:getTowersMaxDps()
                    C.Threads:i():runOnMainThread(C.Runnable(function()
                        -- One way to synchronize things is to simply post a runnable to the main thread
                        statsReport[simVariant] = {
                            damage = totalDamage,
                            mdps = mdps
                        }
                    end))

                    logger:d("done " .. tostring(simVariant) .. ", " .. S.gameState.updateNumber .. " frames")
                end, function(e)
                    logger:e("failed to run sim %s", simVariant, e)
                end)
            end))
        end
        tpe:invokeAll(callables)
        stopSimulation()

        -- Print results - post a runnable to make sure it is executed after every worker has saved the report
        C.Threads:i():postRunnable(C.Runnable(function()
            printSimResults(statsReport)
        end))
        logger:i("All done")
    end), "Towers benchmark sim main")
    mainThread:setDaemon(true)
    mainThread:start()
end