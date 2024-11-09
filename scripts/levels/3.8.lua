-- 3.8
local tutorial = require "scripts.misc.tutorial"

local i18n = function() return C.Game.i.localeManager.i18n end
local sm = function() return S._gameUi.storylineMessages end
local st = function() return S._gameUi.subtitles end

local BOSS_WAVE_NUMBER = 50
local forceSubtitles = false

local tut

S.events:getListeners(C.SystemsPostSetup):addStateAffecting(C.Listener(function (_)
    forceSubtitles = C.Game.i.basicLevelManager:getMaxReachedWave("3.8") >= BOSS_WAVE_NUMBER or S.gameState.gameIsContinued
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
                    st():schedule({
                        tut.ENSOR_TAG .. " [#F44336]&-Fh#fc-##vp&*vb-h#fNp%gv-iv%g%l#Qrg#rp$g$$rq-![]",
                        tut.ENSOR_TAG .. " [#F44336]0x91CF0FF: -F#gb$c**Vg$![]",
                        tut.ENSOR_TAG .. " [#F44336]P#baf*r&#dh#!ra-pr*fNer#P-ngnf&g&e#bcu-vp![]"
                    }, 9, 0.5)
                    st():schedule({
                        tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_3_8_010_you_will_meet"),
                        tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_3_8_020_i_think_you_also"),
                        tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_3_8_030_well_not_interesting"),
                        tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_3_8_040_we_need_to_defeat"),
                        tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_3_8_050_his_name_is")
                    }, 2, 5)
                end

                tut:condition(function() return S.wave.wave ~= nil and S.wave.wave.waveNumber >= BOSS_WAVE_NUMBER - 3 end, function()
                    if not S.CFG.headless then
                        st():add(tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_3_8_060_you_have_few_waves"))
                    end
                end)
            end)
        end,
        done = function()
            if not S.CFG.headless then
                local messages = {
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_3_8_070_i_have_to_admit"),
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_3_8_080_now_its_time"),
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_3_8_090_finish_your_work")
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
