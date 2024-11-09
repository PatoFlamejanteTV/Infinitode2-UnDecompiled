if S.CFG.headless then return nil end

dofile("scripts/misc/subtitles-on-level-start.lua")(function(tutorial, i18n)
    S._gameUi.subtitles:schedule({
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_5_4_010_i_decided_that"),
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_5_4_020_a_flamethrower_can"),
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_5_4_030_but_remember")
    }, 2, 5)
end)
