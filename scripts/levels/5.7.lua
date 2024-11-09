if S.CFG.headless then return nil end

dofile("scripts/misc/subtitles-on-level-start.lua")(function(tutorial, i18n)
    S._gameUi.subtitles:schedule({
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_5_7_010_the_final_is_near"),
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_5_7_020_the_main_great"),
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_5_7_030_it_can_cause_really"),
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_5_7_040_this_tower_has_a_small")
    }, 2, 5)
end)
