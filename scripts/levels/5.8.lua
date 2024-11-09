-- 5.8
local tutorial = require "scripts.misc.tutorial"

local i18n = function() return C.Game.i.localeManager.i18n end
local sm = function() return S._gameUi.storylineMessages end
local st = function() return S._gameUi.subtitles end

local BOSS_WAVE_NUMBER = 5

local forceSubtitles = false
local walkablePlatformsEnabled = false

local tut

S.events:getListeners(C.SystemsPostSetup):add(C.Listener(function (_)
    forceSubtitles = C.Game.i.basicLevelManager:getMaxReachedWave("5.8") >= BOSS_WAVE_NUMBER or S.gameState.gameIsContinued
    if not S.CFG.headless then tut:start() end

    S.events:getListeners(C.GameStateTick):addStateAffecting(C.Listener(function(event)
        ---@cast event GameStateTick
        local deltaTime = event:getDeltaTime()
        if not walkablePlatformsEnabled then
            if S.wave:getCompletedWavesCount() >= 80 then
                walkablePlatformsEnabled = true

                -- Turn on Walkable tiles
                if not S.CFG.headless then
                    S.map:showTileWarningParticle(9, 15)
                end

                local tileFactory = C.Game.i.tileManager:getFactory(C.TileType.GAME_VALUE) --[[@as GameValueTileFactory]]
                local tile = tileFactory:createTypeDelta(C.GameValueType.ENEMIES_WALK_ON_PLATFORMS, 1)
                S.map:setTile(9, 15, tile)

                -- Remove red teleports
                local gates = S.map:getMap():getGatesByType(C.TeleportGate);
                local gatesToRemove = {}

                for i=0, gates.size - 1 do
                    local gate = gates:get(i) --[[@as TeleportGate]]
                    if gate.index == 0 then
                        table.insert(gatesToRemove, { gate:getX(), gate:getY(), gate:isLeftSide() })
                    end
                end

                for i, v in ipairs(gatesToRemove) do
                    S.map:setGate(v[1], v[2], v[3], nil)
                end
            end
        end

        tut:update(deltaTime)
    end))
end))

tut = tutorial:new({
    {
        check = function()
            return false
        end,
        start = function()
            if not S.gameState.gameIsContinued then
                local messages = {
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_5_8_010_so_we_got_to_the"),
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_5_8_020_apparently_ensor_uses"),
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_5_8_030_do_you_remember"),
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_5_8_040_but_our_goal")
                }
                if forceSubtitles then
                    st():schedule(messages, 2, 5)
                else
                    tut:delay(2, function()
                        sm():queue(messages)
                    end)
                end
            end

            -- Pre-boss subtitles
            -- W17 - Broot
            tut:condition(function() return S.wave.wave ~= nil and S.wave.wave.waveNumber >= 15 and S.wave.wave.waveNumber <= 19 end, function()
                st():schedule({
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_5_8_050_broot_will_appear")
                }, 2, 5)
            end)

            -- W20 - Broot dun
            tut:condition(function() return S.wave.wave ~= nil and S.wave.wave.waveNumber > 20 and S.wave.wave.waveNumber < 35 and S.wave:getCompletedWavesCount() >= 20 end, function()
                st():schedule({
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_5_8_060_okey_warming_up")
                }, 2, 5)
            end)

            -- W37 - Stakey
            tut:condition(function() return S.wave.wave ~= nil and S.wave.wave.waveNumber >= 35 and S.wave.wave.waveNumber <= 39 end, function()
                st():schedule({
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_5_8_070_stakey_is_coming")
                }, 2, 5)
            end)

            -- W40 - Stakey dun
            tut:condition(function() return S.wave.wave ~= nil and S.wave.wave.waveNumber > 40 and S.wave.wave.waveNumber < 55 and S.wave:getCompletedWavesCount() >= 40 end, function()
                st():schedule({
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_5_8_080_great_moving_on")
                }, 2, 5)
            end)

            -- W57 - Constructor
            tut:condition(function() return S.wave.wave ~= nil and S.wave.wave.waveNumber >= 55 and S.wave.wave.waveNumber <= 59 end, function()
                st():schedule({
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_5_8_090_a_few_waves")
                }, 2, 5)
            end)

            -- W60 - Constructor dun
            tut:condition(function() return S.wave.wave ~= nil and S.wave.wave.waveNumber > 60 and S.wave.wave.waveNumber < 65 and S.wave:getCompletedWavesCount() >= 60 end, function()
                st():schedule({
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_5_8_093_well_done_most_bosses")
                }, 2, 5)
            end)

            -- W75 - Mobchain
            tut:condition(function() return S.wave.wave ~= nil and S.wave.wave.waveNumber >= 75 and S.wave.wave.waveNumber <= 79 end, function()
                st():schedule({
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_5_8_096_well_quess_who_coming"),
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_5_8_097_but_we_have_something")
                }, 2, 5)
            end)

            -- W80 - Mobchain dun
            tut:condition(function() return S.wave.wave ~= nil and S.wave.wave.waveNumber > 80 and S.wave.wave.waveNumber < 85 and S.wave:getCompletedWavesCount() >= 80 end, function()
                st():schedule({
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_5_8_100_good_job_now_starts")
                }, 2, 5)
            end)

            -- W97 - Metaphor
            tut:condition(function() return S.wave.wave ~= nil and S.wave.wave.waveNumber >= 95 and S.wave.wave.waveNumber <= 99 end, function()
                st():schedule({
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_5_8_110_just_a_few_waves")
                }, 2, 5)
            end)

            -- W100 - Metaphor, the beginning
            tut:condition(function() return S.wave.wave ~= nil and S.wave.wave.waveNumber == 100 end, function()
                st():schedule({
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_5_8_120_uses_small_enemies")
                }, 2, 5)
                st():schedule({
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_5_8_130_seems_that_he_has")
                }, 12, 5)
            end)

            -- Metaphor on 75% hp
            tut:condition(function()
                if S.wave.wave ~= nil and S.wave.wave.waveNumber == 100 then
                    local boss = nil
                    for i = 0, S.map.spawnedEnemies.size - 1 do
                        local enemyRef = S.map.spawnedEnemies:get(i) --[[@as EnemyReference]]
                        if enemyRef.enemy ~= nil and enemyRef.enemy.type == C.EnemyType.METAPHOR_BOSS then
                            boss = enemyRef.enemy
                            break
                        end
                    end
                    if boss ~= nil then
                        if boss:getHealth() / boss.maxHealth < 0.75 then
                            return true
                        end
                    end
                end

                return false
            end, function()
                st():schedule({
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_5_8_140_he_turned_off"),
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_5_8_150_i_think_two_more")
                }, 2, 5)
            end)

            -- Metaphor on 25% hp
            tut:condition(function()
                if S.wave.wave ~= nil and S.wave.wave.waveNumber == 100 then
                    local boss = nil
                    for i = 0, S.map.spawnedEnemies.size - 1 do
                        local enemyRef = S.map.spawnedEnemies:get(i) --[[@as EnemyReference]]
                        if enemyRef.enemy ~= nil and enemyRef.enemy.type == C.EnemyType.METAPHOR_BOSS then
                            boss = enemyRef.enemy
                            break
                        end
                    end
                    if boss ~= nil then
                        if boss:getHealth() / boss.maxHealth < 0.25 then
                            return true
                        end
                    end
                end

                return false
            end, function()
                st():schedule({
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_5_8_160_just_a_little_more")
                }, 2, 5)
            end)

            -- W100 - Metaphor dun
            tut:condition(function() return S.wave.wave ~= nil and S.wave.wave.waveNumber > 100 and S.wave.wave.waveNumber < 110 and S.wave:getCompletedWavesCount() >= 100 end, function()
                st():schedule({
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_5_8_170_nothing_stands_in_my_way"),
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_5_8_180_i_leave_you_my_copy"),
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_5_8_190_one_more_thing"),
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_5_8_200_you_did_well")
                }, 2, 5)
            end)
        end,
        done = function() end
    }
})
tut._noSyncCheck = true