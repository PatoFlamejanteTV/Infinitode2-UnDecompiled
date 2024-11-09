local Render = com.prineside.tdi2.events.game.Render.class

S.events:getListeners(C.SystemsPostSetup):add(C.Listener(function (_)
    -- S.wave:setWaveGenerator(luajava.createProxy(GNS.."systems.WaveSystem$WaveGenerator", {
    --     generate = function(waveNumber, defaultWave, S, difficultWavesMultiplier, difficulty)
    --         for i = 1, defaultWave.enemyGroups.size do
    --             local eg = defaultWave.enemyGroups.items[i]
    --             if eg.count > 10 then
    --                 eg.count = 10
    --             end
    --             eg.interval = 0.01
    --         end
    --         return defaultWave
    --     end
    -- }))

    -- Call the first wave
    local startFirstWaveCb
    startFirstWaveCb = C.Listener(function(_)
        if S.wave.status == C.WaveSystem.Status.NOT_STARTED then
            S.wave:forceNextWaveAction()
            S.events:getListeners(C.GameStateTick):remove(startFirstWaveCb)
        end
    end)
    S.events:getListeners(C.GameStateTick):addStateAffecting(startFirstWaveCb)

    S.events:getListeners(C.GiveDamageToEnemy):addStateAffecting(C.Listener(function(event)
        ---@cast event GiveDamageToEnemy
        local record = event:getRecord()
        local enemy = record:getEnemy()
        if (enemy.passedTiles > 3 + enemy.sideShiftIndex * 0.08) or enemy.existsTime > 15 then
            record:setDamage(100000000)
        end
    end))

    S.events:getListeners(C.EnemyReachTarget):addStateAffectingWithPriority(C.Listener(function(event)
        ---@cast event EnemyReachTarget
        event:setFactDamage(0)
    end), C.EventListeners.PRIORITY_HIGHEST)

    S.gameState:setGameSpeed(8192)
    S.wave:setAutoForceWaveEnabled(true)
end))

-- Restore max speed on state restore
S.events:getListeners(C.SystemsStateRestore):addStateAffecting(C.Listener(function (_)
    local speedRestoreCb
    speedRestoreCb = C.Listener(function(_)
        S.gameState:setGameSpeed(8192)
        S.wave:setAutoForceWaveEnabled(true)
        S.events:getListeners(Render):remove(speedRestoreCb)
    end)
    S.events:getListeners(Render):add(speedRestoreCb)
end))
