-- 4.8
local tutorial = require "scripts.misc.tutorial"

local i18n = function() return C.Game.i.localeManager.i18n end
local sm = function() return S._gameUi.storylineMessages end
local st = function() return S._gameUi.subtitles end

local BOSS_WAVE_NUMBER = 50
local forceSubtitles = false

local tut

S.events:getListeners(C.SystemsPostSetup):addStateAffecting(C.Listener(function (_)
    forceSubtitles = C.Game.i.basicLevelManager:getMaxReachedWave("4.8") >= BOSS_WAVE_NUMBER or S.gameState.gameIsContinued
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
                        tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_4_8_010_the_time_has_come"),
                        tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_4_8_020_it_is_like_stakey"),
                        tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_4_8_030_head_is_completely"),
                        tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_4_8_040_all_parts_of_body"),
                        tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_4_8_050_i_advise_you")
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
                        st():add(tut.ENSOR_TAG .. " " .. i18n():get("lvlsub_4_8_060_the_mobchain"))
                    end
                end)
            end)
        end,
        done = function()
            if not S.CFG.headless then
                local messages = {
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_4_8_070_good_job"),
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_4_8_080_i_want_to_congratulate"),
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_4_8_090_dont_stay_here")
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
