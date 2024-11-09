--[[
    - scenarioPlayer
--]]
_G.scenarioPlayer = {
    new = function(self)
        local o = {}
        setmetatable(o, self)
        self.__index = self

        self.actions = {};
        self.time = 0;
        self.delayedFunctions = {};
        self.intervalFunctions = {};
        self.conditions = {};

        return o
    end,

    addAction = function(self, delay, cb)
        local inst = {
            done = false,

            delay = delay,
            cb = cb
        }

        table.insert(self.actions, inst)

        return inst
    end,

    removeAction = function(self, action)
        utils.tableRemoveVal(self.actions, action)
    end,

    addDelay = function(self, delayInSeconds, cb)
        local inst = {
            delay = delayInSeconds,
            cb = cb
        }

        table.insert(self.delayedFunctions, inst)

        return inst
    end,

    removeDelay = function(self, delay)
        utils.tableRemoveVal(self.delayedFunctions, delay)
    end,

    addInterval = function(self, intervalInSeconds, job, repeatTimes, cb)
        local inst = {
            timeSinceLastJob = 0,
            repeatedTimes = 0,

            repeatTimes = repeatTimes,
            job = job,
            interval = intervalInSeconds,
            cb = cb
        }

        table.insert(self.intervalFunctions, inst)

        return inst
    end,

    removeInterval = function(self, interval)
        utils.tableRemoveVal(self.intervalFunctions, interval)
    end,

    addCondition = function(self, condition, cb)
        local inst = {
            condition = condition,
            cb = cb
        }

        table.insert(self.conditions, inst)

        return inst
    end,

    removeCondition = function(self, condition)
        utils.tableRemoveVal(self.conditions, condition)
    end,

    update = function(self, deltaTime)
        -- Delayed functions
        for i = 1, #self.delayedFunctions do
            local e = self.delayedFunctions[i]
            if e ~= nil then
                e.delay = e.delay - deltaTime
                if e.delay <= 0 then
                    self.delayedFunctions[i] = nil
                    e.cb()
                end
            end
        end
        utils.compactnil(self.delayedFunctions)

        -- Functions called on an interval
        for i = 1, #self.intervalFunctions do
            local e = self.intervalFunctions[i]
            if e ~= nil then
                e.timeSinceLastJob = e.timeSinceLastJob + deltaTime
                if e.timeSinceLastJob >= e.interval then
                    e.job()
                    e.timeSinceLastJob = e.timeSinceLastJob - e.interval
                    e.repeatedTimes = e.repeatedTimes + 1
                    if e.repeatedTimes == e.repeatTimes then
                        if e.cb ~= nil then e.cb() end
                        self.intervalFunctions[i] = nil
                    end
                end
            end
        end
        utils.compactnil(self.intervalFunctions)

        -- Conditions
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

        self.time = self.time + deltaTime
        for i = 1, #self.actions do
            local a = self.actions[i]
            if not a.done and a.delay <= self.time then
                a.done = true
                a.cb()
            end
        end
    end
}