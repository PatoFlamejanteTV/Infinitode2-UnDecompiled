if S.CFG.headless then return nil end

dofile("scripts/misc/subtitles-on-level-start.lua")(function(tutorial, i18n)
    S._gameUi.subtitles:schedule({
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_3_2_010_you_will_love"),
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_3_2_020_it_was_specially"),
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_3_2_030_not_so_good"),
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_3_2_040_by_the_way_beware"),
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_3_2_050_armored_enemies")
    }, 2, 5)
end)
