if S.CFG.headless then return nil end

dofile("scripts/misc/subtitles-on-level-start.lua")(function(tutorial, i18n)
    S._gameUi.subtitles:schedule({
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_1_5_010_theres_something_new"),
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_1_5_020_freezing_tower_has"),
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_1_5_030_it_cant_damage")
    }, 2, 5)
end)
