-- Used by tower-pwr-benchmarking-bot.lua and should not be included directly.
-- Run from the main menu.
-- This script runs the same map over and over again, changing the map's configuration and building a specific tower type each time.
-- It is slower than the "headless" multithreaded simulation (see global/add_test_sim.lua) but it runs the full game (+UI) and allows
-- to interact with the map / see if the map is properly configured.
-- Game speed can be changed during the run - the simulation of the level will end as soon as wave WAVE_COUNT is reached.
-- To stop the simulation, simply exit to the main menu.
-- Each run will be 100% predictable (except the loot, probably - but it is not important), because seed is taken from the BasicLevel.
-- Disable particles and other stuff to save up some FPS.
local logger = C.TLog:forTag("tbs-full")

if not C.MainMenuScreen:_isInstance(C.Game.i.screenManager:getCurrentScreen()) then
    return logger:e("This script must be run from the main menu")
end

-- Remove the previous listener, just in case it exists (very unlikely)
local postRenderListeners = C.Game.EVENTS:getListeners(C.PostRender)
local existingListeners = postRenderListeners:getEntriesBackingArray()
for i = 1, postRenderListeners:size() do
    local listener = existingListeners[i]
    if listener ~= nil and listener:getName() == "tower-pwr-benchmarking-bot" then
        logger:w("Removing previous bot listener")
        listener:remove()
    end
end

local GAME_SPEED = 65536 -- 16384

local TASK_START_LEVEL = "START_LEVEL"
local TASK_CONFIGURE_LEVEL = "CONFIGURE_LEVEL"
local TASK_START_THE_RUN = "START_THE_RUN"
local TASK_SIMULATE_WAVES = "SIMULATE_WAVES"
local TASK_COLLECT_STATISTICS = "COLLECT_STATISTICS"
local TASK_FINISH_RUN = "FINISH_RUN"
local TASK_PRINT_STATISTICS = "PRINT_STATISTICS"

---@param basicLevel BasicLevel
---@param waveCount number
---@param simVariants SimVariant[]
---@param printSimResults fun(statsReport:table)
return function(basicLevel, waveCount, simVariants, printSimResults)
    local statsReport = {}

    logger:i("Starting benchmark for " .. #simVariants .. " variants")

    local currentVariant = 1
    local currentTask = TASK_START_LEVEL

    local setTask = function(task)
        logger:i("Switching task %s -> %s", currentTask, task)
        currentTask = task
    end

    local renderListener

    local stopSimulation = function()
        C.Game.EVENTS:getListeners(C.PostRender):remove(renderListener)
        C.Notifications:i():addSuccess("Simulation stopped")
    end

    renderListener = C.Listener(function()
       utils.tryCatch(function()
            local currentScreen = C.Game.i.screenManager:getCurrentScreen()
            local requireS = function()
                if C.GameScreen:_isInstance(currentScreen) then
                    ---@cast currentScreen GameScreen
                    local S = currentScreen.S
                    if not S then
                        error("GameScreen.S is nil - aborting")
                    else
                        return S
                    end
                else
                    error("Not on the GameScreen - aborting")
                end
            end

            -- Draw current sim info
            local batch = C.Game.i.renderingManager.batch
            C.RenderingManager:prepareBatch(batch, false)
            local font = C.Game.i.assetManager:getFont(C.Config.FONT_SIZE_XX_SMALL)

            local simVariant = simVariants[currentVariant]
            if simVariant then
                local msg =  "Sim " .. currentVariant .. " / " .. #simVariants .. "\n"
                msg = msg .. "Task: " .. currentTask .. "\n"
                msg = msg .. "Tower type: " .. simVariant.towerType:name() .. "\n"
                msg = msg .. "PWR: " .. simVariant.pwr .. "\n"
                msg = msg .. "Upgrade level: " .. simVariant.upgLvl .. "\n"
                msg = msg .. "XP level: " .. simVariant.xpLvl .. "\n"
                font:draw(batch, msg, 20, 540)
            else
                font:draw(batch, "No sim variant, task: " .. currentTask, 20, 540)
            end
            batch:_M_end()

            if currentTask == TASK_START_LEVEL then
                -- Task: start a map
                if not C.GameScreen:_isInstance(currentScreen) then
                    -- We are not on the GameScreen - starting the map
                    logger:d("not on GameScreen - starting a new map")
                    C.Game.i.screenManager:startNewBasicLevel(basicLevel, nil)
                else
                    -- We are in the game - starting next task
                    logger:d("a run has started, configuring the map")
                    C.Notifications:i():addSuccess("Sim started: " .. tostring(currentVariant) .. " / " .. tostring(#simVariants))
                    setTask(TASK_CONFIGURE_LEVEL)
                end
            elseif currentTask == TASK_CONFIGURE_LEVEL then
                -- Task: configure the map
                logger:d("configuring the map")
                local S = requireS()

                simVariant.configurator(S)

                setTask(TASK_START_THE_RUN)
            elseif currentTask == TASK_START_THE_RUN then
                -- Task: start the run
                logger:d("starting the run")
                local S = requireS()

                S.gameState.inUpdateStage = true

                -- Stop the game when wave is reached
                -- Using in-game listener to stop the sim precisely at the target wave - using Render listener may (actually, will) 
                -- miss the wave, because thousands of ticks happen in one frame
                S.events:getListeners(C.WaveStart):add(C.Listener(function(event)
                    ---@cast event WaveStart
                    if event:getWave().waveNumber >= waveCount then
                        logger:d("target wave reached")
                        S.gameState:setGameSpeed(1)
                        S.gameState:triggerGameOver(C.GameOverReason.MANUAL)
                        setTask(TASK_COLLECT_STATISTICS)
                    end
                end))

                S.wave:setAutoForceWaveEnabled(true)
                S.gameState:setGameSpeed(GAME_SPEED)
                S.wave:startNextWave()

                setTask(TASK_SIMULATE_WAVES)
            elseif currentTask == TASK_SIMULATE_WAVES then
                -- Task: simulate for WAVE_COUNT waves - do nothing, just wait
                requireS()
            elseif currentTask == TASK_COLLECT_STATISTICS then
                logger:d("collecting statistics")

                local S = requireS()
                statsReport[simVariant] = {
                    damage = S.statistics:getCurrentGameStatistic(C.StatisticsType.TDD),
                    mdps = S.damage:getTowersMaxDps()
                }

                setTask(TASK_FINISH_RUN)
            elseif currentTask == TASK_FINISH_RUN then
                C.Game.i.screenManager:goToMainMenu()

                currentVariant = currentVariant + 1
                if simVariants[currentVariant] then
                    logger:d("starting the next sim")
                    setTask(TASK_START_LEVEL)
                else
                    -- End of all simulations
                    setTask(TASK_PRINT_STATISTICS)
                end
            elseif currentTask == TASK_PRINT_STATISTICS then
                logger:i("all sims finished, printing statistics:")

                printSimResults(statsReport)

                logger:i("All done")
                stopSimulation()
            end
         end,
         function(e)
             logger:e("Simulation failed, currentVariant: %s, currentTask: %s", currentVariant, currentTask, e)
             stopSimulation()
         end)
    end)
    C.Game.EVENTS:getListeners(C.PostRender):add(renderListener):setName("tower-pwr-benchmarking-bot")
end