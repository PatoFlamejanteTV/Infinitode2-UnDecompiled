if S.CFG.headless then return nil end

dofile("scripts/misc/subtitles-on-level-start.lua")(function(tutorial, i18n)
    S._gameUi.subtitles:schedule({
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_3_4_010_here_comes_the"),
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_3_4_020_its_projectiles"),
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_3_4_030_extremely_effective")
    }, 2, 5)
end)
