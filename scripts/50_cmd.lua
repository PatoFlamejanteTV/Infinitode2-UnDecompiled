--[[
    - cmd
--]]

local logger = C.TLog:forTag("cmd.lua")

_G.cmd = {
    help = function(a1)
        if (a1 == "?") then
            return {
                descr = "Show DeveloperConsole help"
            }
        end

        logger:i("Version %s (build %s) running %s on LibGDX %s", C.Config.VERSION, C.Config.BUILD, _VERSION, com.badlogic.gdx.Version.class.VERSION)
        logger:i("Use DeveloperConsole to run any Lua script. There are some predefined functions for easier usage of console:")

        local sorted = {}
        for k, v in pairs(_G.cmd) do
            local info = v("?")
            local cmdArgs = info and info.args or nil
            local cmdDescr = info and info.descr or nil
            if cmdArgs == nil then cmdArgs = "" end
            if cmdDescr == nil then cmdDescr = "description not provided" end
            sorted[k] = { args = cmdArgs,  descr = cmdDescr }
        end

        for c, info in utils.pairsByKeys(sorted) do
            logger:i("> cmd." .. c .. " [#64B5F6](" .. info.args .. ")[]\n  [#8BC34A]" .. info.descr .. "[]")
        end
    end,

    list_game_values = function(a1)
        if (a1 == "?") then
            return {
                descr = "Lists all game values"
            }
        end

        local snap -- gvp
        if S ~= nil then
            snap = S.gameValue:getSnapshot()
        else
            snap = C.Game.i.gameValueManager:getSnapshot()
        end
        ---@cast snap GameValuesSnapshot

        local currentEffectsByType = {} -- index shifted by 1
        for i = 1, #C.GameValueType.values do
            currentEffectsByType[i] = {}
        end

        for i = 0, snap.effects.size - 1 do
            local effect = snap.effects:get(i) --[[@as GameValueEffect]]
            local ebt = currentEffectsByType[effect.type:ordinal() + 1]
            table.insert(ebt, snap.effects:get(i))
        end

        for i = 1, #C.GameValueType.values do
            local gvt = C.GameValueType.values[i]
            local ebt = currentEffectsByType[gvt:ordinal() + 1]
            local value = snap:getValue(gvt)

            local parts = {}
            table.insert(parts, gvt:name())
            table.insert(parts, "[#455A64] = [][#FFFFFF]")
            table.insert(parts, tostring(value))
            table.insert(parts, "[]  [#455A64]( []")
            for j, v in ipairs(ebt) do
                local sourceName = v.source:name()
                if sourceName == "STOCK" then
                    table.insert(parts, "[#FFFFFF]")
                elseif sourceName == "LEVEL_STOCK" then
                    table.insert(parts, "[#455A64]LSTCK[] [#90A4AE]")
                elseif sourceName == "RESEARCH" then
                    table.insert(parts, "[#0097A7]RES[] [#4DD0E1]")
                elseif sourceName == "TROPHY" then
                    table.insert(parts, "[#7B1FA2]TRP[] [#BA68C8]")
                elseif sourceName == "LEVEL_QUEST" then
                    table.insert(parts, "[#1976D2]LQST[] [#64B5F6]")
                elseif sourceName == "LEVEL_WAVE_QUEST" then
                    table.insert(parts, "[#388E3C]LWQST[] [#81C784]")
                elseif sourceName == "BASE_TILE" then
                    table.insert(parts, "[#0097A7]BASE[] [#4DD0E1]")
                elseif sourceName == "CORE_TILE" then
                    table.insert(parts, "[#C2185B]CORE[] [#F06292]")
                else
                    table.insert(parts, "[#616161]" .. sourceName .. "[] [#E0E0E0]")
                end

                table.insert(parts, v.delta .. "[]")
                if j ~= #ebt then
                    table.insert(parts, "[#FFFFFF],[] ")
                end
            end

            -- TODO show final value if during the game

            table.insert(parts, "[#455A64] )[]")
            logger:i(table.concat(parts, ""))
        end
    end,

    researchgvs = function(multiplier)
        if (multiplier == "?") then
            return {
                args = "double multiplier",
                descr = "Lists all game values affected by researches as Json array for Base"
            }
        end

        if multiplier == nil then multiplier = 1 end

        local currentEffects = C.Game.i.gameValueManager:getCurrentEffects()
        local currentEffectsByType = {} -- index shifted by 1

        for i = 1, #C.GameValueType.values do
            currentEffectsByType[i] = {}
        end

        for i = 0, currentEffects.size - 1 do
            local effect = currentEffects:get(i) --[[@as GameValueEffect]]
            local ebt = currentEffectsByType[effect.type:ordinal() + 1]
            table.insert(ebt, currentEffects:get(i))
        end

        local parts = {}
        table.insert(parts, "[\n")
        for i = 1, #C.GameValueType.values do
            local gvt = C.GameValueType.values[i]
            local ebt = currentEffectsByType[gvt:ordinal() + 1]

            local delta = 0
            for j, v in ipairs(ebt) do
                if v.source:name() == "RESEARCH" then
                    delta = delta + v.delta
                end
            end
            if delta ~= 0 then
                delta = delta * multiplier
                table.insert(parts, " { \"t\":\"")
                table.insert(parts, gvt:name())
                table.insert(parts, "\", \"v\":")
                table.insert(parts, delta)
                table.insert(parts, ", \"o\":false, \"b\":false },\n")
            end
        end
        table.insert(parts, "]")
        logger:i(table.concat(parts, ""))
    end,

    dump_ui = function(actorName)
        if (actorName == "?") then
            return {
                args = "string actorName",
                descr = "Dumps UI hierarchy to console. Use nil as actorName to dump everything (will also print elements of this console)"
            }
        end

        local actor
        if actorName ~= nil then
            actor = C.Game.i.uiManager:findActor(actorName)
            if actor == nil then
                logger:i("No actors found with name '%s'", actorName)
                return
            end
        end
        ---@diagnostic disable-next-line: param-type-mismatch
        C.Game.i.uiManager:dumpActorsHierarchy(actor, 0)
    end,

    validate_ui = function(a1)
        if (a1 == "?") then
            return {
                descr = "Validates UI hierarchy"
            }
        end

        C.Game.i.uiManager:findDuplicateActorNames()
        logger:i("No actor name duplicates")
    end,

    list_ui_layers = function(a1)
        if (a1 == "?") then
            return {
                descr = "Prints current UI layers in order of drawing"
            }
        end

        for i = 1, #C.MainUiLayer.values do
            local mainUiLayer = C.MainUiLayer.values[i]
            logger:i(mainUiLayer:name())
            local layers = C.Game.i.uiManager.layers[i]
            for j = 1, layers.size do
                local layer = layers:get(j - 1) --[[@as UiLayer]]
                logger:i(layer.name .. " " .. layer.zIndex)
            end
        end
    end,

    hide_all_ui = function(a1)
        if (a1 == "?") then
            return {
                descr = "Hide all UI layers. Use back/console/camera controller button to recover"
            }
        end

        for i = 1, #C.Game.i.uiManager.layers do
            local uiLayerArray = C.Game.i.uiManager.layers[i]
            for j = 1, uiLayerArray.size do
                local uiLayer = uiLayerArray:get(j - 1) --[[@as UiLayer]]
                uiLayer:getTable():setVisible(false)
            end
        end
    end,

    run_lua_tests = function(a1)
        if (a1 == "?") then
            return {
                descr = "Run Lua VM tests"
            }
        end

        dofile("scripts/tests/run-all.lua")
    end
}
