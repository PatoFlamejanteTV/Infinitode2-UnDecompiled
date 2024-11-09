--[[
    TODO: this script is from 2.0+ and won't run

    Can be included into a map with no side effects.
    Does nothing during a regular gameplay.
    Only comes to action when some replay is started (statistics -> by game -> view replay)

    At the start of the replay:
    - Disables most of the visual effects
    - Sets maximum game speed

    At the end of the replay prints (to the console) time it took to play the replay from start to the end.
    Feel free to create your own versions of this script if you want to add some extra info to the benchmark.
--]]
local logger = C.TLog:forTag("replay-benchmark.lua")

S.events:getListeners(C.SystemsPostSetup):add(C.Listener(function()
    if S.gameState.replayMode then
        local settingsManager = C.Game.i.settingsManager

        logger:d("Replay detected")

        settingsManager:setCustomValue(C.CustomValueType.DRAW_TOWER_TARGET, 0)
        settingsManager:setCustomValue(C.CustomValueType.LOOT_ICONS_ENABLED, 0)
        settingsManager:setCustomValue(C.CustomValueType.GRAPHICS_INTERPOLATION_ENABLED, 1)
        settingsManager:setCustomValue(C.CustomValueType.UI_QUEST_LIST_VISIBLE, 0)
        settingsManager:setCustomValue(C.CustomValueType.UI_LIVE_LEADERBOARDS_VISIBLE, 0)
        settingsManager:setCustomValue(C.CustomValueType.UI_DETAILED_MODE_ENABLED, 0)
        settingsManager:setCustomValue(C.CustomValueType.UI_STATISTICS_CHART_VISIBLE, 0)
        settingsManager:setCustomValue(C.CustomValueType.UI_HOT_KEY_HINTS, 0)
        settingsManager:setCustomValue(C.CustomValueType.DBG_CONSOLE_DISABLED, 1)
        settingsManager:setCustomValue(C.CustomValueType.DBG_SYNC_VALIDATION, 0)
        settingsManager:setCustomValue(C.CustomValueType.DBG_SHOW_FPS, 1)
        settingsManager:setExplosionsDrawing(false)
        settingsManager:setFlyingCoinsEnabled(false)
        settingsManager:setParticlesDrawing(false)
        settingsManager:setProjectilesDrawing(false)
        settingsManager:setProjectileTrailsDrawing(false)
        settingsManager:setStainsEnabled(false)
        S.gameState:setGameSpeed(65536)

        local startTs = C.Game:getTimestampMillis()
        logger:d("Start ts %s", startTs)

        S.events:getListeners(C.GameOver):add(C.Listener(function()
            local elapsed = C.Game:getTimestampMillis() - startTs
            logger:i("Replay finished in %sms", elapsed)
        end)):setName("Replay benchmark script")
    else
        logger:d("Not in replay mode")
    end
end)):setName("Replay benchmark script")
