if S.CFG.headless then return nil end

dofile("scripts/misc/subtitles-on-level-start.lua")(function(tutorial, i18n)
    S._gameUi.subtitles:schedule({
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_1_2_010_great_you_got_to"),
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_1_2_020_at_this_level"),
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_1_2_030_it_is_very_effective"),
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_1_2_040_also_a_little_slow")
    }, 2, 5)
    S._gameUi.subtitles:schedule({
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_1_2_050_by_the_way")
    }, 2 + 5 * 3 + 8, 0)
end)
