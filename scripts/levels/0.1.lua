-- 0.1
local tutorial = require "scripts.misc.tutorial" -- loads "tutorial" thing to use later

local logger = C.TLog:forTag("0.1.lua")

-- Creating some getters for convenience:
-- Note: do not store these values directly into variables as they'll become nil after deserialization ("S" and "managers" are always here)
local i18n = function() return C.Game.i.localeManager.i18n end
local sm = function() return S._gameUi.storylineMessages end
local ql = function() return S._gameUi.questList end

-- Some variables needed for the tutorial lifecycle
local questListItem
local s3_sideMenuWasOffscreen -- Stage 3

logger:d("Level 0.1 script was successfully loaded")

local tut
tut = tutorial:new({
    {-- Spawn tile info
        check = function()
            -- Returns true / false notifying about the completion of this stage
            return questListItem ~= nil and S._gameMapSelection:getSelectedTile() ~= nil and S._gameMapSelection:getSelectedTile().type == C.TileType.SPAWN
        end,
        start = function()
            -- Called at the start of the stage
            logger:d("Stage 1 start")
            sm():queue({
                tut.ENSOR_TAG .. " " .. i18n():get("tut_01_010_010_welcome_to_the_infinitode"),
                tut.ENSOR_TAG .. " " .. i18n():get("tut_01_010_020_this_is_an_experimental"),
                tut.ENSOR_TAG .. " " .. i18n():get("tut_01_010_030_anyone_can_take_part"),
                tut.ENSOR_TAG .. " " .. i18n():get("tut_01_010_040_please_follow_instructions")
            })
            sm():runOnContinue(C.Runnable(function()
                tut:delay(1, function()
                    sm():queue({
                        tut.ADVINAS_TAG .. " " .. i18n():get("tut_01_010_050_hi_let_me_show_basics"),
                        tut.ADVINAS_TAG .. " " .. i18n():get("tut_01_010_060_lets_start_with_the_game")
                    })
                    sm():runOnContinue(C.Runnable(function()
                        logger:d("Stage 1 sm continue")

                        -- Добавляем квест
                        questListItem = ql():addQuestListItem()
                        questListItem:setText(i18n():get("tut_01_010_070_tap_on_portal"))

                        -- Подсвечиваем спавн
                        local spawnTile = S.map:getMap():getTilesByType(C.SpawnTile):first() --[[@as SpawnTile]]
                        S.map:removeHighlights()
                        S.map:highlightTile(spawnTile)

                        -- Показываем кнопку включения StorylineMessages
                        S._gameUi.mainUi:showMessagesButton(true, C.Runnable(function()
                            -- Показываем подсказку про pan & zoom
                            S._gameUi.panZoomTooltip:show();

                            local animation = C.BasicAnimation.new(spawnTile.center.x, spawnTile.center.y, 2, 1, C.Interpolation.pow2);
                            S._input.cameraController:animate(animation)
                        end))
                    end))
                end)
            end))
        end,
        done = function() -- Выбрали портал
            -- Вызывается при выполненни условия (здесь нужно убрать за собой)
            logger:d("Stage 1 done")

            -- Убираем подсветку и квест
            S.map:removeHighlights()
            questListItem:setCompleted(true)

            tut:delay(2, function()
                ql():removeQuestListItem(questListItem)
                sm():queue({
                    tut.ADVINAS_TAG .. " " .. i18n():get("tut_01_010_080_this_is_a_portal")
                })
                sm():runOnContinue(C.Runnable(function()
                    logger:d("Stage 1 done sm continued, starting next stage")
                    tut:startNextStage()
                end))
            end)
        end
    },
    {-- Информация о базе и цели игры
        check = function()
            return S._gameMapSelection:getSelectedTile() ~= nil and S._gameMapSelection:getSelectedTile().type == C.TileType.TARGET
        end,
        start = function()
            logger:d("Stage 2 start")
            sm():queue({
                tut.ADVINAS_TAG .. " " .. i18n():get("tut_01_020_010_ive_highlighted_the_other")
            })
            sm():runOnContinue(C.Runnable(function()
                logger:d("Stage 2 sm continue")

                -- Подсвечиваем базу
                local baseTile = S.map:getMap():getTargetTileOrThrow()
                S.map:removeHighlights()
                S.map:highlightTile(baseTile)

                -- Добавляем квест
                questListItem = ql():addQuestListItem()
                questListItem:setText(i18n():get("tut_01_020_020_tap_on_base"))

                local animation = C.BasicAnimation.new(baseTile.center.x, baseTile.center.y, 2, 1, C.Interpolation.pow2 );
                S._input.cameraController:animate(animation)
            end))
        end,
        done = function() -- Выбрали базу
            logger:d("Stage 2 done")

            S.map:removeHighlights()
            questListItem:setCompleted(true)

            -- Отмечаем квест выполненным для уровня
            -- managers.BasicLevelManager:setQuestCompleted("QTUT1S1")
            S.gameState:addCompletedQuest("Q:0.1:1")

            tut:delay(2, function()
                ql():removeQuestListItem(questListItem)

                sm():queue({
                    tut.ADVINAS_TAG .. " " .. i18n():get("tut_01_020_030_you_are_doing_well"),
                    tut.ADVINAS_TAG .. " " .. i18n():get("tut_01_020_040_so_this_is_your_base")
                })
                sm():runOnContinue(C.Runnable(function()
                    logger:d("Stage 2 done sm continue")

                    -- Показываем здоровье
                    S._gameUi.mainUi:showHealth(true, C.Runnable(function()
                        sm():queue({
                            tut.ADVINAS_TAG .. " " .. i18n():get("tut_01_020_050_your_task_is_simple")
                        })
                        sm():runOnContinue(C.Runnable(function()
                            logger:d("Stage 1 done sm continued, starting next stage")
                            tut:startNextStage()
                        end))
                    end))
                end))
            end)
        end
    },
    {-- Платформа, открыть меню постройки башен
        check = function()
            local tile = S._gameMapSelection:getSelectedTile()
            if tile == nil then return false end

            return tile:getX() == 2 and tile:getY() == 1
        end,
        start = function()
            logger:d("Stage 3 start")
            sm():queue({
                tut.ADVINAS_TAG .. " " .. i18n():get("tut_01_030_010_youll_use_towers"),
                tut.ADVINAS_TAG .. " " .. i18n():get("tut_01_030_020_towers_can_be_built")
            })
            sm():runOnContinue(C.Runnable(function()
                -- Подсвечиваем платформу
                S.map:removeHighlights()
                S.map:highlightTile(S.map:getMap():getTile(2, 1))

                -- Показываем кнопки постройки
                C.Game.i.uiManager:findActor("build_menu_tower_build_buttons"):setVisible(true)

                -- Добавляем квест
                questListItem = ql():addQuestListItem()
                questListItem:setText(i18n():get("tut_01_030_030_tap_on_platform"))
            end))
        end,
        done = function() -- Выбрали платформу
            logger:d("Stage 3 done")

            S.map:removeHighlights()
            questListItem:setCompleted(true)

            tut:delay(2, function()
                ql():removeQuestListItem(questListItem)

                sm():queue({
                    tut.ADVINAS_TAG .. " " .. i18n():get("tut_01_030_040_you_can_choose_the_type"),
                    tut.ADVINAS_TAG .. " " .. i18n():get("tut_01_030_050_each_type_of_tower")
                })
                sm():runOnContinue(C.Runnable(function()
                    logger:d("Stage 3 done sm continue")

                    -- Показываем монеты
                    S._gameUi.mainUi:showCoins(true, C.Runnable(function() tut:startNextStage() end))
                end))
            end)
        end
    },
    {-- Построить башню
        check = function()
            return S.tower.towers.size ~= 0
        end,
        update = function()
            local sideMenuOffscreen = S._gameUi.sideMenu:isOffscreen()
            if s3_sideMenuWasOffscreen ~= sideMenuOffscreen then
                -- Меняем подсветку элементов UI
                C.Game.i.uiManager:removeAllHighlights()

                if sideMenuOffscreen then
                    -- Меню скрыто - подсвечиваем кнопку открытия меню
                    C.Game.i.uiManager:addHighlight(C.Game.i.uiManager:findActor("side_menu_toggle_button"))
                else
                    -- Меню открыто, подсвечиваем кнопку постройки
                    C.Game.i.uiManager:addHighlight(C.Game.i.uiManager:findActor("build_menu_tower_build_button_BASIC"))
                end
                s3_sideMenuWasOffscreen = sideMenuOffscreen
            end
        end,
        start = function()
            logger:d("Stage 4 start")
            sm():queue({
                tut.ADVINAS_TAG .. " " .. i18n():get("tut_01_040_010_you_have_enough_coins")
            })
            sm():runOnContinue(C.Runnable(function()
                -- Подсвечиваем платформу
                S.map:removeHighlights()
                S.map:highlightTile(S.map:getMap():getTile(2, 1))

                -- Делаем так, чтобы в следующем update() обновилась подсветка UI
                s3_sideMenuWasOffscreen = not S._gameUi.sideMenu:isOffscreen()

                -- Добавляем квест
                questListItem = ql():addQuestListItem()
                questListItem:setText(i18n():get("tut_01_040_020_build_basic_tower"))
            end))
        end,
        done = function() -- Построили башню
            logger:d("Stage 4 done")

            S.map:removeHighlights()
            questListItem:setCompleted(true)
            S.gameState:addCompletedQuest("Q:0.1:2")

            tut:delay(2, function()
                ql():removeQuestListItem(questListItem)
                C.Game.i.uiManager:removeAllHighlights()
                S.map:removeHighlights()
                sm():queue({
                    tut.ADVINAS_TAG .. " " .. i18n():get("tut_01_040_030_great"),
                    tut.ADVINAS_TAG .. " " .. i18n():get("tut_01_040_040_basic_towers_are_the_most"),
                })
                sm():runOnContinue(C.Runnable(function() tut:startNextStage() end))
            end)
        end
    },
    {-- Вызвать волну и дождаться, когда заспавнятся все враги первой волны
        check = function()
            return S.wave.wave ~= nil
                    and not (S.wave.status == C.WaveSystem.Status.SPAWNING and S.wave.wave.waveNumber == 1)
        end,
        update = function(_)
            if S.tower.towers.size == 0 then
                -- Башни не построены
                S.gameState:triggerGameOver(C.GameOverReason.QUEST_FAILED)
            end
        end,
        start = function()
            logger:d("Stage 5 start")
            sm():queue({
                tut.ADVINAS_TAG .. " " .. i18n():get("tut_01_050_010_you_are_prepared_to_call")
            })
            sm():runOnContinue(C.Runnable(function()
                -- Показываем кнопку вызова волны
                S._gameUi.mainUi:showNextWaveButton(true, nil)
            end))
        end,
        done = function() -- Вызвали волну
            logger:d("Stage 5 done")
            sm():queue({
                tut.ADVINAS_TAG .. " " .. i18n():get("tut_01_050_020_youll_gain_score_points")
            })
            sm():runOnContinue(C.Runnable(function()
                -- Показываем очки
                S._gameUi.mainUi:showScore(true, C.Runnable(function()
                    sm():queue({
                        tut.ADVINAS_TAG .. " " .. i18n():get("tut_01_050_030_next_enemy_wave_will_start"),
                        tut.ADVINAS_TAG .. " " .. i18n():get("tut_01_050_040_you_can_also_tap")
                    })
                    sm():runOnContinue(C.Runnable(function() tut:startNextStage() end))
                end))
            end))
        end
    },
    {-- Дождаться, когда начнется вторая волна
        check = function()
            return S.wave.wave ~= nil and S.wave.wave.waveNumber >= 2
        end,
        update = function(_)
            if S.tower.towers.size == 0 then
                -- Башни не построены
                S.gameState:triggerGameOver(C.GameOverReason.QUEST_FAILED)
            end
        end,
        start = function()
            logger:d("Stage 6 start")
        end,
        done = function() -- Вызвали волну
            logger:d("Stage 6 done")
            sm():queue({
                tut.ADVINAS_TAG .. " " .. i18n():get("tut_01_060_010_build_new_towers_and_try")
            })
            sm():runOnContinue(C.Runnable(function()
                -- Добавляем квесты
                --                    local quest = ql():addQuestListItem()
                --                    quest:setText("Fight off 3 waves of enemies")
                --
                --                    quest = ql():addQuestListItem()
                --                    quest:setText("Build one more tower")

                S.gameState:addCompletedQuest("Q:0.1:3")

                local questA
                questA = C.Quest({
                    getTitle = function()
                        return i18n():get("tut_01_060_020_fight_off_3_waves")
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

                local questB
                questB = C.Quest({
                    getTitle = function()
                        return i18n():get("tut_01_060_030_build_one_more_tower")
                    end,

                    update = function() end,

                    isCompleted = function()
                        return S.tower.towers.size >= 2
                    end,

                    onCompletion = function()
                        S._quest:getListItem(questB):setCompleted(true)
                    end
                })
                S._quest:addQuest(questB)

                -- Показываем номер волны
                S._gameUi.mainUi:showWaveNumber(true, nil)
            end))
        end
    }
})

S.events:getListeners(C.SystemsPostSetup):add(C.Listener(function (_)
    S._hotKey:setHotKeysEnabled(false)
    S._gameUi.mainUi:hideNextWaveButton()
    S._gameUi.mainUi:hideDrawModeButton()
    S._gameUi.mainUi:hideCoins()
    S._gameUi.mainUi:hideHealth()
    S._gameUi.mainUi:hideScore()
    S._gameUi.mainUi:hideWaveNumber()
    S._gameUi.towerMenu:hideTowerExperience()
    S.map:setPathTracesDrawing(false)
    S.achievement:setEnabled(false)
    C.Game.i.uiManager:findActor("spawn_menu_details"):setVisible(false)
    C.Game.i.uiManager:findActor("build_menu_modifiers_tab_button"):setVisible(false)
    C.Game.i.uiManager:findActor("build_menu_default_aim_strategy"):setVisible(false)
    C.Game.i.uiManager:findActor("build_menu_tower_build_buttons"):setVisible(false)
    C.Game.i.uiManager:findActor("tower_menu_abilities"):setVisible(false)
    C.Game.i.uiManager:findActor("tower_menu_upgrade"):setVisible(false)
    C.Game.i.uiManager:findActor("tower_menu_aim_strategy"):setVisible(false)
    C.Game.i.uiManager:findActor("tower_menu_sell_button"):setVisible(false)

    tut:start()

    -- Слушаем изменения
    S.events:getListeners(C.GameStateTick):add(C.Listener(function(event)
        ---@cast event GameStateTick
        tut:update(event:getDeltaTime())
    end))

    --
    logger:d("Started")
end))