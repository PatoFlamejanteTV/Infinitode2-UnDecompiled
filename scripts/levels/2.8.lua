-- 2.8
local tutorial = require "scripts.misc.tutorial"

local i18n = function() return C.Game.i.localeManager.i18n end
local sm = function() return S._gameUi.storylineMessages end
local st = function() return S._gameUi.subtitles end

local BOSS_WAVE_NUMBER = 46
local forceSubtitles = false

local tut

S.events:getListeners(C.SystemsPostSetup):addStateAffecting(C.Listener(function (_)
    forceSubtitles = C.Game.i.basicLevelManager:getMaxReachedWave("2.8") >= BOSS_WAVE_NUMBER or S.gameState.gameIsContinued
    tut:start()

    S.events:getListeners(C.GameStateTick):addStateAffecting(C.Listener(function(event)
        ---@cast event GameStateTick
        tut:update(event:getDeltaTime())
    end))
end))

tut = tutorial:new({
    {
        check = function()
            return S.wave:getCompletedWavesCount() >= BOSS_WAVE_NUMBER
        end,
        start = function()
            tut:delay(2, function()
                if not S.CFG.headless then
                    local messages = {
                        tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_2_8_010_new_boss_incoming"),
                        tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_2_8_020_it_is_a_representation"),
                        tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_2_8_030_data_we_need"),
                        tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_2_8_040_just_try_to")
                    }

                    if forceSubtitles then
                        -- subtitles
                        st():schedule(messages, 0, 5)
                    else
                        -- story line messages
                        sm():queue(messages)
                    end
                end

                tut:condition(function() return S.wave.wave ~= nil and S.wave.wave.waveNumber >= BOSS_WAVE_NUMBER - 3 end, function()
                    if not S.CFG.headless then
                        st():add(tut.ENSOR_TAG .. " " .. i18n():get("lvlsub_2_8_050_you_have_few_waves"))
                    end
                end)
            end)
        end,
        done = function()
            if not S.CFG.headless then
                local messages = {
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_2_8_060_great_job"),
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_2_8_070_we_got_access"),
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_2_8_080_lets_move_on")
                }
                if forceSubtitles then
                    st():schedule(messages, 1, 5)
                else
                    sm():queue(messages)
                end
            end
        end
    }
})
tut._noSyncCheck = true
