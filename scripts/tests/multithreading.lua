local THREAD_COUNT = 2

local logger = C.TLog:forTag("multithreading.lua")
local gtn = function() return C.Thread:currentThread():getName() end

local tpe = C.Executors:newFixedThreadPool_i_TF(THREAD_COUNT, C.DaemonThreadFactory.new("Lua multithreading test", true))
local callables = C.ArrayList.new()

for i = 1, THREAD_COUNT do
    logger:d("add callable %s at %s", i, gtn())
    callables:add(C.Callable(function()
        logger:d("starting thread %s at %s", i, gtn())
        local hash = 0
        for j = 1, 2 do
            hash = hash * 31 + j
        end
        logger:d("thread %s finished at %s", i, gtn())
    end))
end

local mainThread = C.Thread.new_R_S(C.Runnable(function()
    logger:d("Starting the executor at %s", gtn())
    tpe:invokeAll(callables)
    logger:d("Invoked all callables at %s", gtn())
end), "Lua multithreading test main thread")

logger:d("Starting the main thread at %s", gtn())
mainThread:start()
mainThread:join()
logger:d("Finished at %s", gtn())