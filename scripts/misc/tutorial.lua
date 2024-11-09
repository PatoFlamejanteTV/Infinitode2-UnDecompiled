--[[
    - tutorial
--]]
local logger = C.TLog:forTag("misc/tutorial.lua")
logger:d("tutorial.lua included")
return {
    ADVINAS_TAG = "[#ffc107]ADVINAS:[]",
    ENSOR_TAG = "[#03A9F4]Ensor Inc.:[]",

    new = function(self, tutorialStages)
        tutorialStages = tutorialStages or {}

        local o = {}
        setmetatable(o, self)
        self.__index = self

        o.stages = tutorialStages;
        o.currentStage = 1;
        o.updateTimeAccumulator = 0;
        o.currentStageIsDone = false;
        o.delayedFunctions = {};
        o.conditions = {};

        return o
    end,

    start = function(self)
        for i = 1, #self.stages do
            self.currentStage = i
            if not self.stages[i].check() then
                self.stages[i].start()
                break
            end
        end
    end,

    delay = function(self, delayInSeconds, cb)
        table.insert(self.delayedFunctions, {
            delay = delayInSeconds,
            cb = cb
        })
    end,

    condition = function(self, condition, cb)
        self.conditions[#self.conditions + 1] = {
            condition = condition,
            cb = cb
        }
    end,

    startNextStage = function(self)
        self.currentStage = self.currentStage + 1
        if self.stages[self.currentStage] ~= nil then
            self.currentStageIsDone = false
            self.stages[self.currentStage].start()
        else
            logger:d("tutorial - no stages left")
        end
    end,

    update = function(self, realDeltaTime)
        for i = 1, #self.delayedFunctions do
            local e = self.delayedFunctions[i]
            if e ~= nil then
                e.delay = e.delay - realDeltaTime
                if e.delay <= 0 then
                    self.delayedFunctions[i] = nil
                    e.cb()
                end
            end
        end

        utils.compactnil(self.delayedFunctions)

        for i = 1, #self.conditions do
            local e = self.conditions[i]
            if e ~= nil then
                if e.condition() then
                    e.cb()
                    self.conditions[i] = nil
                end
            end
        end
        utils.compactnil(self.conditions)

        self.updateTimeAccumulator = self.updateTimeAccumulator + realDeltaTime
        if self.updateTimeAccumulator > 0.5 then
            self.updateTimeAccumulator = 0

            if self.stages[self.currentStage] ~= nil and not self.currentStageIsDone then
                -- Еще есть задания
                if self.stages[self.currentStage].check() then
                    self.stages[self.currentStage].done()
                    self.currentStageIsDone = true
                else
                    local updateHandler = self.stages[self.currentStage].update
                    if updateHandler ~= nil then updateHandler(realDeltaTime) end
                end
            end
        end
    end
}