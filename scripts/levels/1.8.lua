-- 1.8
-- We need to save script's state to continue showing subtitles for boss wave but also need to make
-- sure no graphics is used in headless environment

local tutorial = require "scripts.misc.tutorial"

local logger = C.TLog:forTag("1.8.lua")

local i18n = function() return C.Game.i.localeManager.i18n end
local sm = function() return S._gameUi.storylineMessages end
local st = function() return S._gameUi.subtitles end

logger:d("script was successfully loaded")

local BOSS_WAVE_NUMBER = 40
local forceSubtitles = false

local tut

S.events:getListeners(C.SystemsPostSetup):addStateAffecting(C.Listener(function (_)
    forceSubtitles = C.Game.i.basicLevelManager:getMaxReachedWave("1.8") >= BOSS_WAVE_NUMBER or S.gameState.gameIsContinued
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
                if not S.gameState.gameIsContinued and S._gameUi ~= nil then
                    local messages = {
                        tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_1_8_010_on_this_level"),
                        tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_1_8_020_it_is_slow"),
                        tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_1_8_030_destroy_it"),
                        tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_1_8_040_i_was_analyzing")
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
                        st():add(tut.ENSOR_TAG .. " " .. i18n():get("lvlsub_1_8_050_few_waves_till_boss"))
                    end
                end)
            end)
        end,
        done = function()
            if not S.CFG.headless then
                local messages = {
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_1_8_060_finaly_new_step"),
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_1_8_070_ensor_given_access"),
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_1_8_080_and_seems_like")
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
