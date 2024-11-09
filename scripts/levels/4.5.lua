if S.CFG.headless then return nil end

dofile("scripts/misc/subtitles-on-level-start.lua")(function(tutorial, i18n)
    S._gameUi.subtitles:schedule({
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_4_5_010_you_will_like"),
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_4_5_020_tesla_releases_lightning"),
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_4_5_030_tower_copes_well"),
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_4_5_040_it_is_worth_remembering")
    }, 2, 5)
end)
