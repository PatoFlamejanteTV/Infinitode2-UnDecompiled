if S.CFG.headless then return nil end

dofile("scripts/misc/subtitles-on-level-start.lua")(function(tutorial, i18n)
    S._gameUi.subtitles:schedule({
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_3_7_010_meet_the_new"),
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_3_7_020_its_attack_speed"),
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_3_7_030_it_also_has")
    }, 2, 5)
end)
