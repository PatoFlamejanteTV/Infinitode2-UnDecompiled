-- This script tests Lua's capability to run on multiple threads
-- It adds a new, fully scripted simulation of the game which works exactly the same as the default PerformanceBenchmark
-- You can run it through Settigns -> Debug -> Simulation

-- Important: Lua tables are not thread safe. Do not modify any table (including _G) if you are going to access / modify it from some other thread.
-- Threads.synchronize() can help with that, along with all of the Java's concurrent collections and data structures.
-- Multithreading is difficult, even more if you are running it on a language which has not been designed to be run on a multiple threads.

local logger = C.TLog:forTag("Lua test sim")

local SIM_NAME = "LuaPerformanceBenchmark"

--- @class LuaBenchmarkSim : com.prineside.tdi2.utils.simulation.Simulation
--- An implementation of Simulation, kinda Java's class and will behave exactly like one if you wrap it into Simulation proxy.
--- A simulation can run on the main thread (will freeze the UI), on a separate thread (won't freeze the UI and should 
--- be alsmost completely safe in terms of threading) or on any number of threads you like (will only work if threads do not interfere with each other).
--- Infinitode does not know how many threads you use, it is up to the Simulation to provide the state and progress of it.
--- In the scope of this class, "sim" is a single run of the simulation. Number of threads and repeats increase the number of "sim"s that will be run.
--- @field simConfig SimConfig a configured copy of the sim config
--- @field threadCount number number of threads to run the sim on
--- @field repeatCount number how many times each sim has to be run on each thread
--- @field frameCount number for how many frames each sim should be run
--- @field jobCount number calculated in the constructor - a number of sims that will be run in this Simulation
--- @field lastRunIsSuccessful AtomicBoolean a value for Simulation.isSuccessful()
--- @field progressByJob AtomicInteger[] current simulation progress per thread
--- @field simRunning AtomicBoolean a value for Simulation.isRunning()
--- @field onFinish Runnable? a runnable which can be passed to this Simulation to make it notify the simulation manager about a finish
--- @field log SimLogListener sim log listener which is normally set by the simulation manager. Default value logs to nowhere
local LuaBenchmarkSim = {
    ---- 🔼 Override (this is just a comment so I don't forget which method implements Simulation's methods)
    --- @return string
    getName = function(self)
        return "(Lua) Performance benchmark on " .. self.threadCount .. " threads, " .. self.repeatCount .. " repeats, " .. self.frameCount .. " frames, " .. tostring(self.simConfig)
    end,

    ---- 🔼 Override
    --- @return number (float)
    getProgress = function(self)
        local sum = 0
        for _, d in ipairs(self.progressByJob) do
            sum = sum + d:get()
        end
        return sum / self.jobCount / 100
    end,

    ---- 🔼 Override
    --- @return boolean
    isReadyToStart = function(self)
        return not self:isRunning()
    end,

    ---- 🔼 Override
    --- @return boolean
    isRunning = function(self)
        return self.simRunning:get()
    end,

    ---- 🔼 Override
    --- @return boolean
    isSuccessful = function(self)
        return self.lastRunIsSuccessful:get()
    end,

    ---- 🔼 Override
    --- @param onFinish java.lang.Runnable
    --- @return nil
    setSimFinishListener = function(self, onFinish)
        self.onFinish = onFinish
    end,

    ---- 🔼 Override
    --- @param listener com.prineside.tdi2.utils.simulation.SimLogListener
    --- @return nil
    setSimLogListener = function(self, listener)
        self.log = listener
    end,

    ---- 🔼 Override
    start = function(self)
        if self:isRunning() then
            error("Already running!")
        end

        for i = 1, self.jobCount do
            self.progressByJob[i]:set(0)
        end
        self.lastRunIsSuccessful:set(true)

        local mainThread = C.Thread.new_R_S(C.Runnable(function()
            self.simRunning:set(true)

            local tpe = C.Executors:newFixedThreadPool_i_TF(self.threadCount, C.DaemonThreadFactory.new("(Lua) Performance benchmark", true))
            local callables = C.ArrayList.new()

            local scenario = C.JustUpdateScenario.new(self.frameCount)
            for i = 1, self.jobCount do
                logger:d("add callable " .. i)
                callables:add(C.Callable(function()
                    utils.tryCatch(function()
                        self:startBenchmarkSingleThread(i, self.simConfig, scenario, self.progressByJob[i])
                    end, function(e)
                        logger:e("failed to start sim %s", i, e)
                        self.log:onLog(C.LogLevel.ERROR, "failed to start benchmark\n" .. tostring(e))
                    end)
                end))
            end
            
            self.simRunning:set(true)
            local _st = C.Game:getRealTickCount()
            self.log:onLog(C.LogLevel.INFO, "invoking " .. callables:size() .. " callables")
            tpe:invokeAll(callables)
            local sumFrameCount = self.frameCount * self.repeatCount * self.threadCount
            local runTimeMs = ((C.Game:getRealTickCount() - _st) * 0.001)
            self.log:onLog(C.LogLevel.INFO, "all sim threads finished in " .. runTimeMs .. "ms, " .. tostring(C.StringFormatter:commaSeparatedNumber(sumFrameCount)) .. " frames / " .. tostring(C.StringFormatter:commaSeparatedNumber(sumFrameCount / runTimeMs * 1000)) .. " UPS")

            self:stop()
            if self.onFinish ~= nil then
                C.Threads:i():runOnMainThread(self.onFinish)
            end
        end), "Lua benchmark sim main")
        mainThread:setDaemon(true)
        mainThread:start()
    end,

    ---- 🔼 Override
    stop = function(self)
        self.simRunning:set(false)
    end,

    ---- 🔼 Override
    ---@param simId number
    ---@param simConfig SimConfig
    ---@param scenario com.prineside.tdi2.utils.simulation.Scenario
    ---@param progressListener AtomicInteger
    startBenchmarkSingleThread = function(self, simId, simConfig, scenario, progressListener)
        logger:d("startBenchmarkSingleThread %s", simId)
        self.log:onLog(C.LogLevel.INFO, "starting sim #" .. simId)
        local S = C.SimConfig:createProgressSnapshotAndInitGSP(simConfig)
        local localScenario = scenario:cpy()
        localScenario:start(S)
        local _st = C.Game:getRealTickCount()
        while not localScenario:isFinished() do
            if not self:isRunning() then
                break
            end
            utils.tryCatch(function()
                S:updateSystems()
                localScenario:onUpdate()
                progressListener:set(localScenario:getProgress() * 100)
            end, function(e)
                logger:e("failed to update systems on sim %s", simId, e)
                self:stop()
                self.lastRunIsSuccessful:set(false)
                self.log:onLog(C.LogLevel.ERROR, "exception in sim, frame " .. S.gameState.updateNumber .. "\n" .. tostring(e))
            end)
        end
        self.log:onLog(C.LogLevel.INFO, "sim #" .. simId .. " finished in " .. ((C.Game:getRealTickCount() - _st) * 0.001) .. "ms, " .. S.gameState.updateNumber .. " frames, completed waves: " .. S.wave:getCompletedWavesCount())
    end
}

--- Create a configured instance of this test simulation
--- @param simConfig SimConfig a config passed from the sim screen. Simulation will store a configured copy of it and won't mutate the value passed to this function
--- @param threadCount number number of threads
--- @param repeatCount number number of sim runs per thread
--- @param frameCount number number of frames to run each sim for
--- @return LuaBenchmarkSim an instance of Simulation ready to be started
LuaBenchmarkSim.new = function(simConfig, threadCount, repeatCount, frameCount)
    local o = {}
    setmetatable(o, { __index = LuaBenchmarkSim })

    o.simConfig = simConfig:cpy()
    o.simConfig.startTimestamp = 1692113508 * 1000
    o.threadCount = threadCount
    o.repeatCount = repeatCount
    o.frameCount = frameCount
    o.jobCount = repeatCount * threadCount

    o.progressByJob = {}
    for i = 1, o.jobCount do
        o.progressByJob[i] = C.AtomicInteger.new()
    end

    o.lastRunIsSuccessful = C.AtomicBoolean.new_b(true)
    o.simRunning = C.AtomicBoolean.new_b(false)

    o.log = C.SimLogListener(function() end)
    return o
end

local simProvider = C.SimTypeProvider({
    --- @return string
    getName = function(self)
        return SIM_NAME
    end,

    --- @param simScreen com.prineside.tdi2.screens.SimulationScreen
    --- @return nil
    prepareSimForm = function(self, simScreen)
        local formTable = simScreen.formTable

        local label = C.Label.new("Thread count", C.Game.i.assetManager:getLabelStyle(C.Config.FONT_SIZE_XX_SMALL))
        label:setColor(C.MaterialColor.GREY.P500)
        formTable:add(label):growX():row()

        local threadCountField = C.TextField.new("8", C.Game.i.assetManager:getTextFieldStyleWithFontAndVariant(C.Game.i.assetManager:getDebugFont(false), true))
        formTable:add(threadCountField):growX():padBottom(10):row()

        label = C.Label.new("Repeat count", C.Game.i.assetManager:getLabelStyle(C.Config.FONT_SIZE_XX_SMALL))
        label:setColor(C.MaterialColor.GREY.P500)
        formTable:add(label):growX():row()

        local repeatCountField = C.TextField.new("8", C.Game.i.assetManager:getTextFieldStyleWithFontAndVariant(C.Game.i.assetManager:getDebugFont(false), true))
        formTable:add(repeatCountField):growX():padBottom(10):row()

        label = C.Label.new("Frame count", C.Game.i.assetManager:getLabelStyle(C.Config.FONT_SIZE_XX_SMALL))
        label:setColor(C.MaterialColor.GREY.P500)
        formTable:add(label):growX():row()

        local frameCountField = C.TextField.new("400000", C.Game.i.assetManager:getTextFieldStyleWithFontAndVariant(C.Game.i.assetManager:getDebugFont(false), true))
        formTable:add(frameCountField):growX():padBottom(10):row()

        local addSimButton = C.RectButton.new("Add simulation", C.Game.i.assetManager:getLabelStyle(C.Config.FONT_SIZE_SMALL), C.Runnable(function()
            -- Add an actual simulation
            local threadCount = tonumber(threadCountField:getText()) --[[@as number]]
            local repeatCount = tonumber(repeatCountField:getText()) --[[@as number]]
            local frameCount = tonumber(frameCountField:getText()) --[[@as number]]
            local simulation = C.Simulation(LuaBenchmarkSim.new(simScreen.simConfig, threadCount, repeatCount, frameCount))
            print(simulation)
            print(simulation:isRunning())
            simScreen:addSimulation(simulation)
        end))
        formTable:add(addSimButton):height(40):growX():row()
    end
})

C.SimulationScreen.SIM_TYPE_PROVIDERS:put(SIM_NAME, simProvider)