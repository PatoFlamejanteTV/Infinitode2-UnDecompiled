-- 0.2
local tutorial = require "scripts.misc.tutorial"

local logger = C.TLog:forTag("0.2.lua")

local i18n = function() return C.Game.i.localeManager.i18n end
local sm = function() return S._gameUi.storylineMessages end
local ql = function() return S._gameUi.questList end

local questListItem
local s4_sideMenuWasOffscreen
local s5_sideMenuWasOffscreen
local s5_lastSelectedTower

local tut

logger:d("Level 0.2 script was successfully loaded")

----------------------------------------------------------------------------------------------------

S.events:getListeners(C.SystemsPostSetup):add(C.Listener(function (_)
    -- Setting initial state
    S._hotKey:setHotKeysEnabled(false)
    S._gameUi.mainUi:hideNextWaveButton()
    S._gameUi.mainUi:hideDrawModeButton()
    S.achievement:setEnabled(false)
    C.Game.i.uiManager:findActor("build_menu_modifiers_tab_button"):setVisible(false)
    C.Game.i.uiManager:findActor("build_menu_default_aim_strategy"):setVisible(false)
    C.Game.i.uiManager:findActor("tower_menu_abilities"):setVisible(false)
    C.Game.i.uiManager:findActor("tower_menu_upgrade"):setVisible(false)
    C.Game.i.uiManager:findActor("tower_menu_aim_strategy"):setVisible(false)
    C.Game.i.uiManager:findActor("tower_menu_sell_button"):setVisible(false)
    S._gameUi.mainUi:showMessagesButton(false, nil)
    S._gameUi.towerMenu:hideTowerExperience()

    tut:start()

    -- Listening to changes
    S.events:getListeners(C.GameStateTick):add(C.Listener(function(event)
        ---@cast event GameStateTick
        tut:update(event:getDeltaTime())
    end))

    logger:d("Started")
end))

tut = tutorial:new({
    {-- Просмотр волн врагов
        check = function()
            return S._gameMapSelection:getSelectedTile() ~= nil and S._gameMapSelection:getSelectedTile().type == C.TileType.SPAWN
        end,
        start = function()
            logger:d("Stage 1 start")
            sm():queue({
                tut.ADVINAS_TAG .. " " .. i18n():get("tut_02_010_010_you_can_view")
            })
            sm():runOnContinue(C.Runnable(function()
                logger:d("Stage 1 sm continue")

                -- Добавляем квест
                questListItem = ql():addQuestListItem()
                questListItem:setText(i18n():get("tut_02_010_020_tap_on_portal"))

                -- Подсвечиваем спавн
                S.map:removeHighlights()
                S.map:highlightTile(S.map:getMap():getTilesByType(C.SpawnTile):first() --[[@as SpawnTile]])
            end))
        end,
        done = function() -- Выбрали портал
            logger:d("Stage 1 done")

            S.map:removeHighlights()
            S.gameState:addCompletedQuest("Q:0.2:1")

            questListItem:setCompleted(true)
            tut:delay(2, function()
                ql():removeQuestListItem(questListItem)

                tut:startNextStage()
            end)
        end
    },
    {-- Полоски путей врагов, строим 3 башни
        check = function()
            return false
        end,
        start = function()
            logger:d("Stage 2 start")
            sm():queue({
                tut.ADVINAS_TAG .. " " .. i18n():get("tut_02_020_010_small_enemy_icons"),
            })
            sm():runOnContinue(C.Runnable(function()
                logger:d("Stage 2 sm continue")

                -- Через время говорим построить 3 башни
                tut:delay(1, function()
                    sm():queue({
                        tut.ADVINAS_TAG .. " " .. i18n():get("tut_02_020_020_looks_like_a_large"),
                        tut.ADVINAS_TAG .. " " .. i18n():get("tut_02_020_030_build_maximum")
                    })
                    sm():runOnContinue(C.Runnable(function()
                        -- Добавляем квест
                        local lastTowersCount = -1
                        local quest
                        quest = C.Quest({
                            getTitle = function()
                                return ""
                            end,

                            update = function()
                                local towersCount = S.tower.towers.size
                                if towersCount ~= lastTowersCount then
                                    S._quest:getListItem(quest):setText(i18n():get("tut_02_020_040_build_towers") .. " " .. towersCount .. " / 3")
                                    lastTowersCount = towersCount
                                end
                            end,

                            isCompleted = function()
                                return S.tower.towers.size >= 3
                            end,

                            onCompletion = function()
                                local qli = S._quest:getListItem(quest)
                                qli:setCompleted(true)

                                tut:delay(1, function()
                                    ql():removeQuestListItem(qli)

                                    tut:startNextStage()
                                end)
                            end
                        })
                        S._quest:addQuest(quest)
                    end))
                end)
            end))
        end,
        done = function() end
    },
    {-- Вызов волн врагов
        check = function()
            if S.wave.wave ~= nil and not (S.wave.status == C.WaveSystem.Status.SPAWNING and S.wave.wave.waveNumber == 1) then
                -- Волны начались и первая волна заспавнилась, проверяем, сколько врагов из текущей волны осталось
                return S.map:getSpawnedEnemiesCountByWave(S.wave.wave) == 0
            end

            return false
        end,
        start = function()
            logger:d("Stage 3 start")
            sm():queue({
                tut.ADVINAS_TAG .. " " .. i18n():get("tut_02_030_010_that_should_do")
            })
            sm():runOnContinue(C.Runnable(function()
                logger:d("Stage 3 sm continue")

                -- Добавляем квест
                questListItem = ql():addQuestListItem()
                questListItem:setText(i18n():get("tut_02_030_020_protect_from"))

                -- Показываем кнопку начала волны
                S._gameUi.mainUi:showNextWaveButton(false, nil)

                -- Если волна началась, скрываем кнопку
                tut:condition(function() return S.wave.wave ~= nil end, function()
                    S._gameUi.mainUi:hideNextWaveButton()
                end)
            end))
        end,
        done = function() -- Выбрали портал
            logger:d("Stage 3 done")

            questListItem:setCompleted(true)
            tut:delay(1, function()
                ql():removeQuestListItem(questListItem)

                tut:startNextStage()
            end)
        end
    },
    {-- Улучшить башню
        check = function()
            local anythindUpgraded = false
            for i = 1, S.tower.towers.size do
                local tower = S.tower.towers:get(i - 1) --[[@as Tower]]
                if tower:getUpgradeLevel() > 0 then
                    anythindUpgraded = true
                    break
                end
            end

            return anythindUpgraded
        end,
        update = function()
            local sideMenuOffscreen = S._gameUi.sideMenu:isOffscreen()
            if s4_sideMenuWasOffscreen ~= sideMenuOffscreen then
                -- Меняем подсветку элементов UI
                C.Game.i.uiManager:removeAllHighlights()

                if sideMenuOffscreen then
                    -- Меню скрыто - подсвечиваем кнопку открытия меню
                    C.Game.i.uiManager:addHighlight(C.Game.i.uiManager:findActor("side_menu_toggle_button"))
                else
                    -- Меню открыто, подсвечиваем кнопку улучшения
                    C.Game.i.uiManager:addHighlight(C.Game.i.uiManager:findActor("tower_menu_upgrade_button"))
                end
                s4_sideMenuWasOffscreen = sideMenuOffscreen
            end
        end,
        start = function()
            logger:d("Stage 4 start")

            -- Скрываем кнопку начала волны
            S._gameUi.mainUi:hideNextWaveButton()
            -- systems.GameStateSystem:setGameSpeed(0)
            S.wave:freezeTimeToNextWave(9001)

            -- Добавляем монеты, если не хватает
            if S.gameState:getMoney() < 25 then
                S.gameState:setMoney(25)
            end

            sm():queue({
                tut.ADVINAS_TAG .. " " .. i18n():get("tut_02_040_010_well_done"),
                tut.ADVINAS_TAG .. " " .. i18n():get("tut_02_040_020_you_coped_with"),
                tut.ADVINAS_TAG .. " " .. i18n():get("tut_02_040_030_currently_theres")
            })
            sm():runOnContinue(C.Runnable(function()
                logger:d("Stage 4 sm continue")

                -- Добавляем квест
                questListItem = ql():addQuestListItem()
                questListItem:setText(i18n():get("tut_02_040_040_upgrade_any_tower"))

                -- Показываем улучшения
                C.Game.i.uiManager:findActor("tower_menu_upgrade"):setVisible(true)

                -- Подсвечиваем кнопку улучшения
                s4_sideMenuWasOffscreen = not S._gameUi.sideMenu:isOffscreen()
            end))
        end,
        done = function() -- Улучшили башню
            logger:d("Stage 4 done")

            questListItem:setCompleted(true)
            C.Game.i.uiManager:removeAllHighlights()
            S.gameState:addCompletedQuest("Q:0.2:2")

            tut:delay(2, function()
                ql():removeQuestListItem(questListItem)

                tut:startNextStage()
            end)
        end
    },
    {-- Выставить режим прицеливания улучшенной башне на самых сильных
        check = function()
            --            local upgradesCount = 0
            --            for i = 1, systems.TowerSystem.towers.size do
            --                local tower = systems.TowerSystem.towers:get(i - 1)
            --                upgradesCount = upgradesCount + tower:getUpgradeLevel()
            --            end
            --
            --            return upgradesCount >= 3
            for i = 1, S.tower.towers.size do
                local tower = S.tower.towers:get(i - 1) --[[@as Tower]]
                if tower:getUpgradeLevel() > 0 and tower.aimStrategy == C.AimStrategy.STRONGEST then
                    return true
                end
            end

            return false
        end,
        update = function()
            local sideMenuOffscreen = S._gameUi.sideMenu:isOffscreen()
            local selectedTile = S._gameMapSelection:getSelectedTile() --[[@as Tile?]]
            if s5_sideMenuWasOffscreen ~= sideMenuOffscreen or s5_lastSelectedTower ~= selectedTile then
                -- Меняем подсветку элементов UI
                C.Game.i.uiManager:removeAllHighlights()

                if C.PlatformTile:_isInstance(selectedTile) then
                    --- @cast selectedTile PlatformTile
                    if C.Tower:_isInstance(selectedTile.building) then
                        local tower = selectedTile.building --[[@as Tower]]
                        if tower:getUpgradeLevel() > 0 then
                            -- Выбрана улучшенная башня
                            if sideMenuOffscreen then
                                -- Меню скрыто - подсвечиваем кнопку открытия меню
                                C.Game.i.uiManager:addHighlight(C.Game.i.uiManager:findActor("side_menu_toggle_button"))
                            else
                                -- Меню открыто, подсвечиваем кнопку улучшения
                                C.Game.i.uiManager:addHighlight(C.Game.i.uiManager:findActor("tower_menu_aim_strategy"))
                            end
                        end
                    end
                end
                s5_sideMenuWasOffscreen = sideMenuOffscreen
                s5_lastSelectedTower = selectedTile
            end
        end,
        start = function()
            logger:d("Stage 5 start")
            sm():queue({
                tut.ADVINAS_TAG .. " " .. i18n():get("tut_02_050_010_now_this_tower"),
                tut.ADVINAS_TAG .. " " .. i18n():get("tut_02_050_020_there_are_two"),
                tut.ADVINAS_TAG .. " " .. i18n():get("tut_02_050_030_lets_make_it")
            })
            sm():runOnContinue(C.Runnable(function()
                logger:d("Stage 5 sm continue")

                -- Показываем переключатель прицеливания и подсвечиваем у улучшенной башни
                C.Game.i.uiManager:findActor("build_menu_default_aim_strategy"):setVisible(true)
                C.Game.i.uiManager:findActor("tower_menu_aim_strategy"):setVisible(true)

                s5_sideMenuWasOffscreen = not S._gameUi.sideMenu:isOffscreen()
                s5_lastSelectedTower = nil

                -- Подсвечиваем улучшенную башню
                for i = 1, S.tower.towers.size do
                    local tower = S.tower.towers:get(i - 1) --[[@as Tower]]
                    if tower:getUpgradeLevel() > 0 then
                        S.map:removeHighlights()
                        S.map:highlightTile(tower:getTile())
                        logger:d("Highlighting")
                        logger:d(tostring(tower:getTile()))
                        break
                    end
                end

                -- Добавляем квест
                questListItem = ql():addQuestListItem()
                questListItem:setText(i18n():get("tut_02_050_040_set_strongest"))
            end))
        end,
        done = function()
            logger:d("Stage 5 done")

            S.map:removeHighlights()
            questListItem:setCompleted(true)
            C.Game.i.uiManager:removeAllHighlights()
            tut:delay(2, function()
                ql():removeQuestListItem(questListItem)

                tut:startNextStage()
            end)
        end
    },
    {-- Победить вторую волну
        check = function()
            return S.wave:getCompletedWavesCount() >= 2
        end,
        start = function()
            logger:d("Stage 6 start")

            -- Убираем паузу
            -- systems.GameStateSystem:setGameSpeed(1)
            S.wave:freezeTimeToNextWave(-1)

            -- Показываем кнопку вызова волны
            S._gameUi.mainUi:showNextWaveButton(false, nil)

            -- Добавляем квест
            questListItem = ql():addQuestListItem()
            questListItem:setText(i18n():get("tut_02_060_010_protect_from"))

            S.map:removeHighlights()
        end,
        done = function()
            logger:d("Stage 6 done")

            questListItem:setCompleted(true)
            tut:delay(1, function()
                ql():removeQuestListItem(questListItem)

                S._mapRendering:setDrawMode(C.DrawMode.DEFAULT)
                tut:startNextStage()
            end)
        end
    },
    {-- Включить детальный режим отображения
        check = function()
            return S._mapRendering:getDrawMode() == C.DrawMode.DETAILED
        end,
        start = function()
            logger:d("Stage 7 start")

            -- Скрываем кнопку начала волны и останавливаем игру
            S._gameUi.mainUi:hideNextWaveButton()
            -- systems.GameStateSystem:setGameSpeed(0)
            S.wave:freezeTimeToNextWave(9001)

            sm():queue({
                tut.ADVINAS_TAG .. " " .. i18n():get("tut_02_070_010_you_can_see")
            })
            sm():runOnContinue(C.Runnable(function()
                logger:d("Stage 7 sm continue")

                -- Показываем кнопку режима отрисовки
                S._gameUi.mainUi:showDrawModeButton(true, C.Runnable(function()
                    -- Добавляем квест
                    questListItem = ql():addQuestListItem()
                    questListItem:setText(i18n():get("tut_02_070_020_turn_on_detailed"))
                end))
            end))
        end,
        done = function()
            logger:d("Stage 6 done")

            questListItem:setCompleted(true)
            S.gameState:addCompletedQuest("Q:0.2:3")

            tut:delay(1, function()
                ql():removeQuestListItem(questListItem)

                tut:startNextStage()
            end)
        end
    },
    {-- Победить остальные волны
        check = function()
            return false
        end,
        start = function()
            logger:d("Stage 8 start")

            sm():queue({
                tut.ADVINAS_TAG .. " " .. i18n():get("tut_02_080_010_you_can_turn_off"),
                tut.ADVINAS_TAG .. " " .. i18n():get("tut_02_080_020_now_upgrade")
            })
            sm():runOnContinue(C.Runnable(function()
                logger:d("Stage 7 sm continue")

                -- Уберем паузу
                S._gameUi.mainUi:showNextWaveButton(false, nil)
                -- systems.GameStateSystem:setGameSpeed(1)
                S.wave:freezeTimeToNextWave(-1)

                -- Добавляем квесты (победить 3 волну, улучшить остальные базы)
                local questA
                questA = C.Quest({
                    getTitle = function()
                        return i18n():get("tut_02_080_030_defeat_third")
                    end,

                    update = function() end,

                    isCompleted = function()
                        return S.wave.wave ~= nil and S.wave.wave.waveNumber > 3
                    end,

                    onCompletion = function()
                        S._quest:getListItem(questA):setCompleted(true)
                    end
                })
                S._quest:addQuest(questA)

                local getUpgradedTowersCount = function()
                    local cnt = 0
                    for i = 1, S.tower.towers.size do
                        local tower = S.tower.towers:get(i - 1) --[[@as Tower]]
                        if tower:getUpgradeLevel() > 0 then
                            cnt = cnt + 1
                        end
                    end

                    return cnt
                end

                local questBlastTowersCount
                local questB
                questB = C.Quest({
                    getTitle = function()
                        return ""
                    end,

                    update = function()
                        local towersCount = getUpgradedTowersCount()
                        if towersCount ~= questBlastTowersCount then
                            S._quest:getListItem(questB):setText(i18n():get("tut_02_080_040_upgrade_towers") .. " " .. towersCount .. " / 3")
                            questBlastTowersCount = towersCount
                        end
                    end,

                    isCompleted = function()
                        return getUpgradedTowersCount() >= 3
                    end,

                    onCompletion = function()
                        S._quest:getListItem(questB):setCompleted(true)
                    end
                })
                S._quest:addQuest(questB)
            end))
        end,
        done = function() end
    }
})