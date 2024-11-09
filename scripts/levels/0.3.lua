-- 0.3
local tutorial = require "scripts.misc.tutorial"

local logger = C.TLog:forTag("0.3.lua")

local i18n = function() return C.Game.i.localeManager.i18n end
local sm = function() return S._gameUi.storylineMessages end
local ql = function() return S._gameUi.questList end

local questListItem
local s3_drawModeQuest
local s3_tileWithBonus

local tut

S.events:getListeners(C.SystemsPostSetup):add(C.Listener(function (_)
    S._hotKey:setHotKeysEnabled(false)
    S._gameUi.mainUi:hideNextWaveButton()
    C.Game.i.uiManager:findActor("build_menu_modifiers_tab_button"):setVisible(false)
    C.Game.i.uiManager:findActor("tower_menu_upgrade"):setVisible(false)
    C.Game.i.uiManager:findActor("tower_menu_sell_button"):setVisible(false)
    S._gameUi.mainUi:showMessagesButton(false, nil)
    S._gameUi.mainUi:hideGameSpeedButton()
    S._gameUi.towerMenu:hideTowerExperience()
    S._gameUi.towerMenu:hideTowerAbilities()
    S.achievement:setEnabled(false)

    tut:start()

    S.events:getListeners(C.GameStateTick):add(C.Listener(function(event)
        ---@cast event GameStateTick
        tut:update(event:getDeltaTime())
    end))

    logger:d("Started")
end))

tut = tutorial:new({
    {-- Построить снайпер
        check = function()
            for i = 0, S.tower.towers.size - 1 do
                local tower = S.tower.towers:get(i) --[[@as Tower]]
                if tower.type == C.TowerType.SNIPER then
                    return true
                end
            end

            return false
        end,
        start = function()
            logger:d("Stage 1 start")
            tut:delay(1, function()
                sm():queue({
                    tut.ADVINAS_TAG .. " " .. i18n():get("tut_03_010_010_this_next_level"),
                    tut.ADVINAS_TAG .. " " .. i18n():get("tut_03_010_020_sniper_tower_well"),
                })
                sm():runOnContinue(C.Runnable(function()
                    logger:d("Stage 1 sm continue")

                    -- Добавляем квест
                    questListItem = ql():addQuestListItem()
                    questListItem:setText(i18n():get("tut_03_010_030_build_sniper_tower"))

                    -- Подсвечиваем
                    C.Game.i.uiManager:addHighlight(C.Game.i.uiManager:findActor("build_menu_tower_build_button_SNIPER"))
                end))
            end)
        end,
        done = function()
            logger:d("Stage 1 done")

            C.Game.i.uiManager:removeAllHighlights()
            S.gameState:addCompletedQuest("Q:0.3:1")

            questListItem:setCompleted(true)
            tut:delay(2, function()
                ql():removeQuestListItem(questListItem)

                sm():queue({
                    tut.ADVINAS_TAG .. " " .. i18n():get("tut_03_010_040_sniper_tower_deals"),
                    tut.ADVINAS_TAG .. " " .. i18n():get("tut_03_010_050_when_changing_target"),
                })
                sm():runOnContinue(C.Runnable(function()
                    tut:startNextStage()
                end))
            end)
        end
    },
    {-- Победить первую волну
        check = function()
            return S.wave:getCompletedWavesCount() >= 1
        end,
        start = function()
            logger:d("Stage 2 start")

            -- Добавляем квест
            questListItem = ql():addQuestListItem()
            questListItem:setText(i18n():get("tut_03_020_010_defeat_first_wave"))

            -- Показываем кнопку вызова волны
            S._gameUi.mainUi:showNextWaveButton(false, nil)

            -- После вызова волны скрываем кнопку
            tut:condition(function()
                return S.wave.wave ~= nil
            end,
                    function()
                        S._gameUi.mainUi:hideNextWaveButton()
                    end)
        end,
        done = function()
            logger:d("Stage 2 done")

            questListItem:setCompleted(true)
            tut:delay(1, function()
                ql():removeQuestListItem(questListItem)

                -- Показываем уровень башни и уникальную характеристику
                sm():queue({
                    tut.ADVINAS_TAG .. " " .. i18n():get("tut_03_020_020_towers_gain_experience"),
                })
                sm():runOnContinue(C.Runnable(function()
                    -- Показываем опыт и уровень башни
                    S._gameUi.towerMenu:showTowerExperience(true, C.Runnable(function()
                        tut:startNextStage()
                    end))
                end))
            end)
        end
    },
    {-- (Появится новый тайл с бонусом опыта) Выбрать тайл и посмотреть информацию о нем
        check = function()
            return S._gameMapSelection:getSelectedTile() == s3_tileWithBonus and s3_tileWithBonus ~= nil
        end,
        start = function()
            logger:d("Stage 3 start")

            -- Останавливаем игру
            S._gameUi.mainUi:hideNextWaveButton()
            -- S.gameState:setGameSpeed(0)
            S.wave:freezeTimeToNextWave(9001)

            sm():queue({
                tut.ADVINAS_TAG .. " " .. i18n():get("tut_03_030_010_some_platforms_give"),
                tut.ADVINAS_TAG .. " " .. i18n():get("tut_03_030_020_check_out_this"),
            })
            sm():runOnContinue(C.Runnable(function()
                logger:d("Stage 3 sm continue")

                -- Добавляем тайл
                s3_tileWithBonus = C.Game.i.tileManager:getFactory(C.TileType.PLATFORM):create() --[[@as PlatformTile]]
                s3_tileWithBonus.bonusType = C.SpaceTileBonusType.BONUS_EXPERIENCE
                s3_tileWithBonus.bonusLevel = 5
                S.map:setTile(4, 3, s3_tileWithBonus)
                S.map:showTileWarningParticle(4, 3)

                -- Подсвечиваем его
                S.map:removeHighlights()
                S.map:highlightTile(s3_tileWithBonus)

                -- Добавляем квест выбора тайла
                questListItem = ql():addQuestListItem()
                questListItem:setText(i18n():get("tut_03_030_030_select_platform_with_bonus"))

                -- Добавляем опциональный квест смены режима отрисовки
                s3_drawModeQuest = ql():addQuestListItem()
                s3_drawModeQuest:setText(i18n():get("tut_03_030_040_turn_on_detailed_mode"))
                tut:condition(function()
                    return S._mapRendering:getDrawMode() == C.DrawMode.DETAILED
                end,
                        function()
                            s3_drawModeQuest:setCompleted(true)
                        end)
            end))
        end,
        done = function()
            logger:d("Stage 3 done")

            S.map:removeHighlights()
            questListItem:setCompleted(true)
            tut:delay(2, function()
                ql():removeQuestListItem(questListItem)
                ql():removeQuestListItem(s3_drawModeQuest)
                tut:startNextStage()
            end)
        end
    },
    {-- Продать первый снайпер
        check = function()
            return S.tower.towers.size == 0
        end,
        start = function()
            logger:d("Stage 4 start")

            sm():queue({
                tut.ADVINAS_TAG .. " " .. i18n():get("tut_03_040_010_this_platform_will_increase"),
                tut.ADVINAS_TAG .. " " .. i18n():get("tut_03_040_020_theres_not_enough")
            })
            sm():runOnContinue(C.Runnable(function()
                logger:d("Stage 4 sm continue")

                -- Выбираем башню
                local tower = S.tower.towers:get(0) --[[@as Tower]]
                if tower ~= nil then
                    S._gameMapSelection:setSelectedTile(tower:getTile())
                end

                -- Открываем меню башни
                S._gameUi.sideMenu:setOffscreen(false)

                -- Подсвечиваем кнопку продажи
                C.Game.i.uiManager:findActor("tower_menu_sell_button"):setVisible(true)
                C.Game.i.uiManager:addHighlight(C.Game.i.uiManager:findActor("tower_menu_sell_button"))

                -- Добавляем квест
                questListItem = ql():addQuestListItem()
                questListItem:setText(i18n():get("tut_03_040_030_sell_existing_tower"))
            end))
        end,
        done = function()
            logger:d("Stage 4 done")

            C.Game.i.uiManager:removeAllHighlights()
            questListItem:setCompleted(true)
            tut:delay(1, function()
                ql():removeQuestListItem(questListItem)
                tut:startNextStage()
            end)
        end
    },
    {-- Построить снайпер на новом тайле
        check = function()
            return s3_tileWithBonus.building ~= nil
        end,
        update = function(_)
            if S.gameState:getMoney() < C.Game.i.towerManager:getFactory(C.TowerType.SNIPER):getBuildPrice(S) then
                -- Не хватает денег на постройку новой башни
                S.gameState:triggerGameOver(C.GameOverReason.QUEST_FAILED)
            end
        end,
        start = function()
            logger:d("Stage 5 start")

            -- Выбираем тайл
            S._gameMapSelection:setSelectedTile(s3_tileWithBonus)

            -- Подсвечиваем тайл
            S.map:removeHighlights()
            S.map:highlightTile(s3_tileWithBonus)

            -- Подсвечиваем кнопку постройки
            C.Game.i.uiManager:addHighlight(C.Game.i.uiManager:findActor("build_menu_tower_build_button_SNIPER"))

            -- Добавляем квест
            questListItem = ql():addQuestListItem()
            questListItem:setText(i18n():get("tut_03_050_010_build_sniper"))
        end,
        done = function()
            logger:d("Stage 5 done")

            S.map:removeHighlights()
            questListItem:setCompleted(true)
            tut:delay(1, function()
                ql():removeQuestListItem(questListItem)
                tut:startNextStage()
            end)
        end
    },
    {-- Победить вторую волну
        check = function()
            return S.wave:getCompletedWavesCount() >= 2
        end,
        update = function(_)
            if s3_tileWithBonus.building == nil then
                -- Продали башню на тайле с бонусом
                S.gameState:triggerGameOver(C.GameOverReason.QUEST_FAILED)
            end
        end,
        start = function()
            logger:d("Stage 6 start")

            -- Добавляем квест
            questListItem = ql():addQuestListItem()
            questListItem:setText(i18n():get("tut_03_060_010_defeat_second_wave"))

            -- Показываем кнопку вызова волны
            S._gameUi.mainUi:showNextWaveButton(false, nil)
            S.wave:freezeTimeToNextWave(-1)
        end,
        done = function()
            logger:d("Stage 6 done")

            questListItem:setCompleted(true)
            tut:delay(1, function()
                ql():removeQuestListItem(questListItem)
                tut:startNextStage()
            end)
        end
    },
    {-- Выбрать навык
        check = function()
            if S.tower.towers.size == 0 then return false end

            local tower = S.tower.towers:get(0) --[[@as Tower]]
            if tower ~= nil then
                for i = 1, C.Tower.ABILITIES_COUNT do
                    if tower.installedAbilities[i] then
                        return true
                    end
                end
            end

            return false
        end,
        update = function(_)
            if s3_tileWithBonus.building == nil then
                -- Продали башню на тайле с бонусом
                S.gameState:triggerGameOver(C.GameOverReason.QUEST_FAILED)
            end
        end,
        start = function()
            logger:d("Stage 7 start")
            sm():queue({
                tut.ADVINAS_TAG .. " " .. i18n():get("tut_03_070_010_tower_gains_abilities"),
                tut.ADVINAS_TAG .. " " .. i18n():get("tut_03_070_020_your_tower_reached")
            })
            sm():runOnContinue(C.Runnable(function()
                logger:d("Stage 7 sm continue")

                -- Останавливаем волны
                S._gameUi.mainUi:hideNextWaveButton()
                S.wave:freezeTimeToNextWave(9001)

                if S.tower.towers.size == 0 then return end -- Нет башен

                -- Открываем меню башни
                local tower = S.tower.towers:get(0) --[[@as Tower]]
                if tower ~= nil then
                    S._gameMapSelection:setSelectedTile(tower:getTile())

                    -- Если уровень башни меньше 4, подгоняем
                    if tower:getLevel() < 4 then
                        S.gameState.inUpdateStage = true
                        S.tower:addExperienceToMatchLevel(tower, 4)
                    end
                end
                S._gameUi.sideMenu:setOffscreen(false)

                -- Показываем кнопки навыков башни
                S._gameUi.towerMenu:showTowerAbilities(true, C.Runnable(function()
                    -- Добавляем квест
                    questListItem = ql():addQuestListItem()
                    questListItem:setText(i18n():get("tut_03_070_030_select_ability"))

                    -- Подсвечиваем кнопки навыков
                    C.Game.i.uiManager:addHighlight(C.Game.i.uiManager:findActor("tower_menu_abilities"))
                end))
            end))
        end,
        done = function()
            logger:d("Stage 7 done")

            C.Game.i.uiManager:removeAllHighlights()
            S.gameState:addCompletedQuest("Q:0.3:2")

            questListItem:setCompleted(true)
            tut:delay(2, function()
                ql():removeQuestListItem(questListItem)
                tut:startNextStage()
            end)
        end
    },
    {-- Победить третью волну
        check = function()
            return false
        end,
        update = function(_)
            if s3_tileWithBonus.building == nil then
                -- Продали башню на тайле с бонусом
                S.gameState:triggerGameOver(C.GameOverReason.QUEST_FAILED)
            end
        end,
        start = function()
            logger:d("Stage 8 start")

            -- Запускаем волны
            S._gameUi.mainUi:showNextWaveButton(false, nil)
            S.wave:freezeTimeToNextWave(-1)

            -- Добавляем квест
            questListItem = ql():addQuestListItem()
            questListItem:setText(i18n():get("tut_03_080_010_defeat_remaining_waves"))
            S.gameState:addCompletedQuest("Q:0.3:3")

            -- Если заспавнились все враги 3-й волны, показываем кнопку скорости игры
            tut:condition(function()
                return (S.wave.status ~= C.WaveSystem.Status.SPAWNING) and S.wave.wave.waveNumber >= 3
            end, function()
                logger:d("Showing game speed button")
                S._gameUi.mainUi:showGameSpeedButton(true, C.Runnable(function()
                    -- Добавляем квест
                    local quest
                    quest = C.Quest({
                        getTitle = function()
                            return i18n():get("tut_03_080_020_switch_game_speed")
                        end,

                        update = function() end,

                        isCompleted = function()
                            return S.gameState:getGameSpeed() > 1
                        end,

                        onCompletion = function()
                            S._quest:getListItem(quest):setCompleted(true)
                        end
                    })
                    S._quest:addQuest(quest)
                end))
            end)
        end,
        done = function()
            logger:d("Stage 8 done")
        end
    }
})