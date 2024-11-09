if S.CFG.headless then return nil end

-- 2.1
if not S.gameState.gameIsContinued then
    local tutorial = require "scripts.misc.tutorial"

    local i18n = function() return C.Game.i.localeManager.i18n end
    local sm = function() return S._gameUi.storylineMessages end
    local st = function() return S._gameUi.subtitles end

    local forceSubtitles = false

    local tut

    S.events:getListeners(C.SystemsPostSetup):add(C.Listener(function (_)
        forceSubtitles = true
        tut:start()

        S.events:getListeners(C.GameStateTick):add(C.Listener(function(event)
            ---@cast event GameStateTick
            tut:update(event:getDeltaTime())
        end))
    end))

    tut = tutorial:new({
        {
            check = function()
                return S.wave:getCompletedWavesCount() >= 10
            end,
            start = function()
                local messages = {
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_2_1_010_stage_two_permissions"),
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_2_1_020_as_i_said_i_got_access"),
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_2_1_030_once_i_was_wandering"),
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_2_1_040_now_i_can_open_them"),
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_2_1_050_someone_switched_off"),
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_2_1_060_youll_find_button")
                }
                if forceSubtitles then
                    st():schedule(messages, 2, 6)
                else
                    tut:delay(2, function()
                        sm():queue(messages)
                    end)
                end
            end,
            done = function()
                local messages = {
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_2_1_070_did_you_notice"),
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_2_1_080_use_researches")
                }
                local postMessages = {
                    tut.ENSOR_TAG .. " ACCESS ERROR \\\\dc0f0009 INVALID PROTOCOL",
                    tut.ADVINAS_TAG .. " " .. i18n():get("lvlsub_2_1_090_never_mind")
                }

                if forceSubtitles then
                    st():schedule(messages, 0, 5)
                    st():schedule(postMessages, 15, 2)
                else
                    sm():queue(messages)
                    sm():runOnContinue(C.Runnable(function()
                        st():schedule(postMessages, 10, 2)
                    end))
                end
            end
        }
    })
end