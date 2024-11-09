if S.CFG.headless then return nil end

dofile("scripts/misc/subtitles-on-level-start.lua")(function(tutorial, i18n)
    S._gameUi.subtitles:schedule({
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_2_2_010_on_this_level"),
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_2_2_020_to_deal_with_them"),
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_2_2_030_flying_enemies"),
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_2_2_040_also_remember")
    }, 2, 5)
end)
