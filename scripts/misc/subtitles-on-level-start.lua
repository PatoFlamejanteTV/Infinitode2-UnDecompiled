--[[
Shows subtitles on level start
Usage:

dofile("scripts/misc/subtitles-on-level-start.lua")(function(tutorial, i18n)
    S._graphics.subtitles:schedule({
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_2_5_010_meet_brand_new")
    }, 2, 5)
end)
--]]

return function(cb)
    if not S.CFG.headless and not S.gameState.gameIsContinued then
        S.events:getListeners(C.SystemsPostSetup):add(com.prineside.tdi2.events.Listener.class(function (_)
            local tutorial = dofile("scripts/misc/tutorial.lua")
            local i18n = function() return C.Game.i.localeManager.i18n end

            cb(tutorial, i18n)
            --S._graphics.subtitles:schedule({
            --    tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_2_5_010_meet_brand_new"),
            --    tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_2_5_020_probably_youll_not"),
            --    tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_2_5_030_splash_tower_shoots"),
            --    tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_2_5_040_it_can_attack")
            --}, 2, 5)
        end))
    end
end