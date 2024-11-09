if S.CFG.headless then return nil end

dofile("scripts/misc/subtitles-on-level-start.lua")(function(tutorial, i18n)
    S._gameUi.subtitles:schedule({
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_4_2_010_the_time_has_come"),
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_4_2_020_each_projectile"),
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_4_2_030_enemy_can_be_poisoned"),
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_4_2_040_it_has_small_radius")
    }, 2, 5)
end)
