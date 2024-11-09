local logger = C.TLog:forTag("lua-threading-test")
local gtn = function() return C.Thread:currentThread():getName() end

print("Creating a new thread")
local newThread = C.Thread.new_R_S(C.Runnable(function()
    print("Other thread start")
    C.Thread:sleep_l(100)
    print("Other thread finished")
end), "Lua separate thread")

print("Starting the other thread")
newThread:start()
print("Joining the other thread")
newThread:join()
print("Finished main thread")

-- Multiple threads
local sharedTable = {}
local THREAD_COUNT = 32
local tpe = C.Executors:newFixedThreadPool_i_TF(THREAD_COUNT, C.DaemonThreadFactory.new("Lua multithreading test", true))
local callables = C.ArrayList.new()

for i = 1, THREAD_COUNT do
    logger:d("add callable %s", i)
    callables:add(C.Callable(function()
        logger:d("starting thread %s", i)
        for j = 1, 100 do
            C.Threads:i():synchronize(sharedTable, C.Runnable(function()
                local sum = sharedTable["sum"]
                if sum == nil then
                    sum = 0
                end
                for k, v in ipairs(sharedTable) do
                    sum = sum + v
                end
                sharedTable["sum"] = sum
                table.insert(sharedTable, 1)
            end))
        end
        logger:d("thread %s finished, sum: %s, values: %s", i, sharedTable["sum"], #sharedTable)
    end))
end
local mainThread = C.Thread.new_R_S(C.Runnable(function()
    logger:d("Starting the executor at %s", gtn())
    tpe:invokeAll(callables)
    logger:d("Invoked all callables at %s", gtn())
end), "Lua multithreading test main thread")

logger:d("Starting the main thread at %s", gtn())
mainThread:start()
logger:d("Finished at %s", gtn())