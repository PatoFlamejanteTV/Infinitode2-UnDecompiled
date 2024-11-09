if S.CFG.headless then return nil end

dofile("scripts/misc/subtitles-on-level-start.lua")(function(tutorial, i18n)
    S._gameUi.subtitles:schedule({
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_2_5_010_meet_brand_new"),
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_2_5_020_probably_youll_not"),
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_2_5_030_splash_tower_shoots"),
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_2_5_040_it_can_attack")
    }, 2, 5)
end)
