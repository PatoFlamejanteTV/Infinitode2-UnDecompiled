if S.CFG.headless then return nil end

dofile("scripts/misc/subtitles-on-level-start.lua")(function(tutorial, i18n)
    S._gameUi.subtitles:schedule({
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_4_1_010_well_i_think"),
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_4_1_020_levels_become"),
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_4_1_030_this_is_all"),
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_4_1_040_we_both_understand"),
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_4_1_050_you_went_too_far"),
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_4_1_060_in_the_end"),
        tutorial.ADVINAS_TAG .. " " .. i18n():get("lvlsub_4_1_070_and_yes_forget")
    }, 2, 5)
end)
