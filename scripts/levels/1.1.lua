if S.CFG.headless then return nil end

dofile("scripts/misc/subtitles-on-level-start.lua")(function(tutorial, i18n)
    S._gameUi.subtitles:schedule({
        tutorial.ENSOR_TAG .. " " .. i18n():get("lvlsub_1_1_010_congratulations"),
        tutorial.ENSOR_TAG .. " " .. i18n():get("lvlsub_1_1_020_from_now_on"),
        tutorial.ENSOR_TAG .. " " .. i18n():get("lvlsub_1_1_030_your_task_is_simple"),
        tutorial.ENSOR_TAG .. " " .. i18n():get("lvlsub_1_1_040_dont_forget_about_quests")
    }, 2, 5)
end)