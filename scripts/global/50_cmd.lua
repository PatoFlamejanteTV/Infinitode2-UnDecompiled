local logger = C.TLog:forTag("global/cmd.lua")

cmd.level_config_editor = function(a1)
    if (a1 == "?") then
        return {
            descr = "Open levels configuration editor"
        }
    end

    C.LevelConfigurationEditor:i():show()
end

cmd.lua_whitelist_editor = function(a1)
    if (a1 == "?") then
        return {
            descr = "Shows Lua whitelist editor"
        }
    end
    C.LuajavaWhitelistEditor:i():show()
end

cmd.show_cases_queue = function(a1)
    if (a1 == "?") then
        return {
            descr = "Show cases queue."
        }
    end

    local str = ""

    for i = 1, #C.ItemManager.ENCRYPTED_CASES_QUEUE do
        local c = C.ItemManager.ENCRYPTED_CASES_QUEUE[i]
        if c == C.CaseType.GREEN then
            str = str .. "<@chest-green>"
        elseif c == C.CaseType.BLUE then
            str = str .. "<@chest-blue>"
        elseif c == C.CaseType.PURPLE then
            str = str .. "<@chest-purple>"
        elseif c == C.CaseType.ORANGE then
            str = str .. "<@chest-orange>"
        elseif c == C.CaseType.CYAN then
            str = str .. "<@chest-cyan>"
        else
            str = str .. "<@chest-question>"
        end
    end

    logger:i(tostring(C.Game.i.assetManager:replaceRegionAliasesWithChars(str)))
end

cmd.complete_all_quests = function(a1)
    if (a1 == "?") then
        return {
            descr = "Completes all quests on regular levels"
        }
    end

    local m = C.Game.i.basicLevelManager
    for i = 1, m.levelsOrdered.size do
        local level = m.levelsOrdered.items[i] --[[@as BasicLevel]]
        for j = 1, level.quests.size do
            local quest = level.quests.items[j] --[[@as BasicLevelQuestConfig]]
            if not quest:isCompleted() then
                quest:setCompleted(true)
            end
        end

        for j = 1, level.waveQuests.size do
            local quest = level.waveQuests.items[j] --[[@as WaveQuest]]
            if not quest:isCompleted() then
                quest:setCompleted(true)
            end
        end
    end
end

cmd.get_all_level_prizes = function(questType)
    if (questType == "?") then
        return {
            args = "string questType - quest type ('all' / 'wave' / 'quest')",
            descr = "Gives all prizes from all quests of all levels"
        }
    end

    local m = C.Game.i.basicLevelManager
    for i = 0, m.levelsOrdered.size - 1 do
        local lvl = m.levelsOrdered:get(i) --[[@as BasicLevel]]
        if questType == "all" or questType == "quest" then
            for j = 0, lvl.quests.size - 1 do
                local quest = lvl.quests:get(j) --[[@as BasicLevelQuestConfig]]
                for k = 0, quest.prizes.size - 1 do
                    local stack = quest.prizes:get(j) --[[@as ItemStack]]
                    C.Game.i.progressManager:addItemStack(stack, "console")
                end
            end
        end
        if questType == "all" or questType == "wave" then
            for j = 0, lvl.waveQuests.size - 1 do
                local quest = lvl.waveQuests:get(j) --[[@as WaveQuest]]
                for k = 0, quest.prizes.size - 1 do
                    local stack = quest.prizes:get(j) --[[@as ItemStack]]
                    C.Game.i.progressManager:addItemStack(stack, "console")
                end
            end
        end
    end

    logger:d("Done")
end

cmd.get_cases_for_playtime = function(cnt)
    if (cnt == "?") then
        return {
            args = "int count",
            descr = "Gives cases in order for playing time"
        }
    end

    if not cnt then
        return logger:w("Count not specified")
    end

    for i = 0, cnt - 1 do
        local caseType = C.Game.i.itemManager:getQueuedEncryptedCaseType(i)
        local caseItem = C.Item.D.F_CASE:create(caseType, true)
        C.Game.i.progressManager:addItems(caseItem, 1, "console")
    end
end

cmd.clear_inventory = function(a1)
    if (a1 == "?") then
        return {
            descr = "Remove all items from inventory"
        }
    end

    C.Game.i.progressManager:removeAllItems()
end

cmd.show_global_statistics = function(a1)
    if (a1 == "?") then
        return {
            descr = "Show global statistics"
        }
    end

    for i = 1, #C.StatisticsType.values do
        local statType = C.StatisticsType.values[i]
        logger:i(statType:name() .. " " .. C.Game.i.statisticsManager:getAllTime(statType) .. " " .. C.Game.i.statisticsManager:getMaxOneGame(statType))
    end
end

cmd.make_item = function(a1)
    if (a1 == "?") then
        return {
            descr = "Show overlay which allows to create any items (Developer mode research required)"
        }
    end

    C.ItemCreationOverlay:i():show()
end

cmd.full_research = function(a1)
    if (a1 == "?") then
        return {
            descr = "Install max level for all research nodes"
        }
    end
    C.Game.i.researchManager:installAllResearches()
end

cmd.full_endless_research = function(a1)
    if (a1 == "?") then
        return {
            descr = "Install max endless level for all research nodes"
        }
    end
    C.Game.i.researchManager:installAllEndlessResearches()
end

cmd.list_missing_gv_quads = function(a1)
    if (a1 == "?") then
        return {
            descr = "Print all GV aliases with no icons"
        }
    end
    logger:i("GVs with missing icons:")
    local gvs = C.GameValueType.values
    for i = 1, #gvs do
        local gv = gvs[i]
        local quadName = "gv." .. gv:name()
        local icon = C.Game.i.assetManager:getQuad(quadName)
        if icon == C.Quad:getNoQuad() then
            logger:i(quadName)
        end
    end
    logger:i("Done")
end