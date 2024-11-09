-- 0.4
local tutorial = require "scripts.misc.tutorial"

local logger = C.TLog:forTag("0.4.lua")

local i18n = function() return C.Game.i.localeManager.i18n end
local sm = function() return S._gameUi.storylineMessages end
local ql = function() return S._gameUi.questList end

local questListItem
local s6_sideMenuWasOffscreen
local s5_ready = false

local tut

logger:d("Level 0.4 script was successfully loaded")

S.events:getListeners(C.SystemsPostSetup):add(C.Listener(function (_)
    S._hotKey:setHotKeysEnabled(false)
    S._gameUi.mainUi:showMessagesButton(false, nil)
    S._gameUi.mainUi:hideGameSpeedButton()
    S.achievement:setEnabled(false)
    C.Game.i.uiManager:findActor("build_menu_miner_build_buttons"):setVisible(false)

    tut:start()

    S.events:getListeners(C.GameStateTick):add(C.Listener(function(event)
        ---@cast event GameStateTick
        tut:update(event:getDeltaTime())
    end))

    local towerX, towerY

    S.events:getListeners(C.TowerPreSell):add(C.Listener(function(event)
        ---@cast event TowerPreSell
        local tower = event:getTower()
        towerX = tower:getTile():getX()
        towerY = tower:getTile():getY()
    end))
    S.events:getListeners(C.TowerSell):add(C.Listener(function(event)
        local newTower = S.tower:buildTowerIgnorePrice(C.TowerType.CANNON, nil, towerX, towerY, true)
        newTower:addExperience(90001)
        newTower:upgradeToLevel(10)
        for i = 0, 5 do
            S.tower:setAbilityInstalled(newTower, i, true)
        end
        newTower.moneySpentOn = 0
    end))

    logger:d("Started")
end))

tut = tutorial:new({
    {-- Победить первую волну
        check = function()
            return S.wave:getCompletedWavesCount() >= 1
        end,
        start = function()
            logger:d("Stage 1 start")

            -- При вызове волны скрываем кнопку и останавливаем таймер волны
            tut:condition(function() return S.wave.wave ~= nil end, function()
                S._gameUi.mainUi:hideNextWaveButton()
                S.wave:freezeTimeToNextWave(9001)
            end)

            tut:delay(1, function()
                sm():queue({
                    tut.ADVINAS_TAG .. " " .. i18n():get("tut_04_010_010_in_this_tutorial"),
                    tut.ADVINAS_TAG .. " " .. i18n():get("tut_04_010_020_lets_make_coins")
                })
                sm():runOnContinue(C.Runnable(function()
                    logger:d("Stage 1 sm continue")

                    -- Показываем счетчик MDPS
                    S._gameUi.mainUi:showMdps(true, nil)

                    -- Добавляем квест
                    questListItem = ql():addQuestListItem()
                    questListItem:setText(i18n():get("tut_04_010_030_defeat_first_wave"))
                end))
            end)
        end,
        done = function()
            logger:d("Stage 1 done")

            questListItem:setCompleted(true)
            tut:delay(1, function()
                ql():removeQuestListItem(questListItem)

                tut:startNextStage()
            end)
        end
    },
    {-- Выделить телепорт
        check = function()
            return S._gameMapSelection:getSelectedGate() ~= nil and S._gameMapSelection:getSelectedGate():getType() == C.GateType.TELEPORT
        end,
        start = function()
            logger:d("Stage 2 start")

            S.map:removeHighlights()
            local map = S.map:getMap()
            for y = 0, map:getHeight() do
                for x = 0, map:getWidth() do
                    for i = 1, 2 do
                        local gate = map:getGate(x, y, i == 1)
                        if gate ~= nil and gate:getType() == C.GateType.TELEPORT then
                            S.map:highlightGate(gate)
                        end
                    end
                end
            end

            sm():queue({
                tut.ADVINAS_TAG .. " " .. i18n():get("tut_04_020_010_enemies_can_pass"),
                tut.ADVINAS_TAG .. " " .. i18n():get("tut_04_020_020_select_any_teleport")
            })
            sm():runOnContinue(C.Runnable(function()
                logger:d("Stage 2 sm continue")
                questListItem = ql():addQuestListItem()
                questListItem:setText(i18n():get("tut_04_020_030_select_teleport"))
            end))
        end,
        done = function()
            logger:d("Stage 2 done")

            S.gameState:addCompletedQuest("Q:0.4:1")

            S.map:removeHighlights()

            questListItem:setCompleted(true)
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
            logger:d("Stage 3 start")

            -- Показываем кнопку вызова волны
            S._gameUi.mainUi:showNextWaveButton(false, nil)
            S.wave:freezeTimeToNextWave(-1)

            -- При вызове волны скрываем кнопку и останавливаем таймер волны
            tut:condition(function() return S.wave.wave.waveNumber == 2 end, function()
                S._gameUi.mainUi:hideNextWaveButton()
                S.wave:freezeTimeToNextWave(9001)
            end)

            sm():queue({
                tut.ADVINAS_TAG .. " " .. i18n():get("tut_04_030_010_deal_with_second_wave")
            })
            sm():runOnContinue(C.Runnable(function()
                logger:d("Stage 3 sm continue")

                -- Добавляем квест
                questListItem = ql():addQuestListItem()
                questListItem:setText(i18n():get("tut_04_030_020_defeat_one_more_wave"))
            end))
        end,
        done = function()
            logger:d("Stage 3 done")

            questListItem:setCompleted(true)
            tut:delay(1, function()
                ql():removeQuestListItem(questListItem)
                tut:startNextStage()
            end)
        end
    },
    {-- Выделить барьер
        check = function()
            return S._gameMapSelection:getSelectedGate() ~= nil and S._gameMapSelection:getSelectedGate():getType() == C.GateType.BARRIER_TYPE
        end,
        start = function()
            logger:d("Stage 4 start")

            S.map:removeHighlights()
            local map = S.map:getMap()
            for y = 0, map:getHeight() do
                for x = 0, map:getWidth() do
                    for i = 1, 2 do
                        local gate = map:getGate(x, y, i == 1)
                        if gate ~= nil and gate:getType() == C.GateType.BARRIER_TYPE then
                            S.map:highlightGate(gate)
                        end
                    end
                end
            end

            sm():queue({
                tut.ADVINAS_TAG .. " " .. i18n():get("tut_04_040_010_as_you_could_see"),
                tut.ADVINAS_TAG .. " " .. i18n():get("tut_04_040_020_barriers_can_block")
            })
            sm():runOnContinue(C.Runnable(function()
                logger:d("Stage 4 sm continue")
                questListItem = ql():addQuestListItem()
                questListItem:setText(i18n():get("tut_04_040_030_select_barrier"))
            end))
        end,
        done = function()
            logger:d("Stage 4 done")

            S.map:removeHighlights()

            questListItem:setCompleted(true)

            tut:delay(2, function()
                ql():removeQuestListItem(questListItem)

                -- Добавляем STRONG в список заблокированных врагов
                local map = S.map:getMap()
                for y = 0, map:getHeight() do
                    for x = 0, map:getWidth() do
                        for i = 1, 2 do
                            local gate = map:getGate(x, y, i == 1)
                            if gate ~= nil and gate:getType() == C.GateType.BARRIER_TYPE then
                                ---@cast gate BarrierTypeGate
                                gate = gate:cloneGate()
                                gate:setEnemyBlocked(C.EnemyType.STRONG, true)
                                S.map:setGate(gate:getX(), gate:getY(), gate:isLeftSide(), gate)
                            end
                        end
                    end
                end

                sm():queue({
                    tut.ADVINAS_TAG .. " " .. i18n():get("tut_04_040_040_barriers_can_also")
                })
                sm():runOnContinue(C.Runnable(function()
                    logger:d("Stage 4 sm continue")
                    tut:startNextStage()
                end))
            end)
        end
    },
    {-- Выделить тайл с ресурсом
        check = function()
            return s5_ready and S._gameMapSelection:getSelectedTile() ~= nil and S._gameMapSelection:getSelectedTile().type == C.TileType.SOURCE
        end,
        start = function()
            logger:d("Stage 5 start")

            S.map:removeHighlights()
            S._gameMapSelection:setSelectedTile(nil)

            local map = S.map:getMap()
            for y = 0, map:getHeight() - 1 do
                for x = 0, map:getWidth() - 1 do
                    local tile = map:getTile(x, y)
                    if tile ~= nil and tile.type == C.TileType.SOURCE then
                        S.map:highlightTile(tile)
                    end
                end
            end

            tut:delay(1, function()
                sm():queue({
                    tut.ADVINAS_TAG .. " " .. i18n():get("tut_04_050_010_lets_talk_about_resources"),
                    tut.ADVINAS_TAG .. " " .. i18n():get("tut_04_050_020_resources_are_useful"),
                    tut.ADVINAS_TAG .. " " .. i18n():get("tut_04_050_030_resources_can_be_obtained")
                })
                sm():runOnContinue(C.Runnable(function()
                    logger:d("Stage 5 sm continue")
                    questListItem = ql():addQuestListItem()
                    questListItem:setText(i18n():get("tut_04_050_040_select_source_tile"))

                    s5_ready = true
                end))
            end)
        end,
        done = function()
            logger:d("Stage 5 done")

            --            S.map:removeHighlights()

            S.gameState:addCompletedQuest("Q:0.4:2")

            questListItem:setCompleted(true)
            tut:delay(2, function()
                logger:d("Stage 5 done continue")
                ql():removeQuestListItem(questListItem)

                tut:startNextStage()
            end)
        end
    },
    {-- Построить майнер
        check = function()
            return S.miner.miners.size ~= 0
        end,
        update = function()
            local sideMenuOffscreen = S._gameUi.sideMenu:isOffscreen()
            if s6_sideMenuWasOffscreen ~= sideMenuOffscreen then
                -- Меняем подсветку элементов UI
                C.Game.i.uiManager:removeAllHighlights()

                if sideMenuOffscreen then
                    -- Меню скрыто - подсвечиваем кнопку открытия меню
                    C.Game.i.uiManager:addHighlight(C.Game.i.uiManager:findActor("side_menu_toggle_button"))
                else
                    -- Меню открыто, подсвечиваем кнопку постройки
                    C.Game.i.uiManager:addHighlight(C.Game.i.uiManager:findActor("build_menu_miner_build_button_SCALAR"))
                end
                s6_sideMenuWasOffscreen = sideMenuOffscreen
            end
        end,
        start = function()
            logger:d("Stage 6 start")

            tut:delay(1, function()
                C.Game.i.uiManager:findActor("build_menu_miner_build_buttons"):setVisible(true)

                -- Подсвечиваем кнопку постройки майнера
                s6_sideMenuWasOffscreen = not S._gameUi.sideMenu:isOffscreen()

                local missingCoins = S.miner:getBuildPrice(C.MinerType.SCALAR) - S.gameState:getMoney()
                if (missingCoins > 0) then
                    -- ...
                    S.gameState:addMoney(missingCoins, false)
                    sm():queue({
                        tut.ADVINAS_TAG .. " " .. i18n():get("tut_04_060_011_dont_do_that_again")
                    })
                end

                sm():queue({
                    tut.ADVINAS_TAG .. " " .. i18n():get("tut_04_060_010_youll_use_miners"),
                    tut.ADVINAS_TAG .. " " .. i18n():get("tut_04_060_020_we_have_enough_coins")
                })
                sm():runOnContinue(C.Runnable(function()
                    logger:d("Stage 6 sm continue")
                    questListItem = ql():addQuestListItem()
                    questListItem:setText(i18n():get("tut_04_060_030_build_a_miner"))
                end))
            end)
        end,
        done = function()
            logger:d("Stage 6 done")

            S.gameState:addCompletedQuest("Q:0.4:3")

            S.map:removeHighlights()
            C.Game.i.uiManager:removeAllHighlights()

            questListItem:setCompleted(true)
            tut:delay(2, function()
                ql():removeQuestListItem(questListItem)

                sm():queue({
                    tut.ADVINAS_TAG .. " " .. i18n():get("tut_04_060_040_you_have_limited")
                })
                sm():runOnContinue(C.Runnable(function()
                    tut:startNextStage()
                end))
            end)
        end
    },
    {-- Дождаться установки майнера
        check = function()
            return S.miner.miners.size ~= 0 and (S.miner.miners:get(0)--[[@as Miner]]):isPrepared()
        end,
        start = function()
            logger:d("Stage 7 start")

            tut:delay(1, function()
                S._gameUi.mainUi:showNextWaveButton(false, nil)
                S.wave:freezeTimeToNextWave(-1)
                S._gameUi.mainUi:showGameSpeedButton(false, nil)

                sm():queue({
                    tut.ADVINAS_TAG .. " " .. i18n():get("tut_04_070_010_miners_take_time"),
                    tut.ADVINAS_TAG .. " " .. i18n():get("tut_04_070_020_installation_progress")
                })
                sm():runOnContinue(C.Runnable(function()
                    logger:d("Stage 7 sm continue")
                    questListItem = ql():addQuestListItem()
                    questListItem:setText(i18n():get("tut_04_070_030_wait_for_miner"))
                end))
            end)
        end,
        done = function()
            logger:d("Stage 7 done")

            questListItem:setCompleted(true)
            tut:delay(1, function()
                ql():removeQuestListItem(questListItem)

                sm():queue({
                    tut.ADVINAS_TAG .. " " .. i18n():get("tut_04_070_040_each_next_miner"),
                    tut.ADVINAS_TAG .. " " .. i18n():get("tut_04_070_050_now_just_watch")
                })
                sm():runOnContinue(C.Runnable(function()
                    logger:d("Stage 7 sm continue")
                    questListItem = ql():addQuestListItem()
                    questListItem:setText(i18n():get("tut_04_070_060_defeat_remaining_waves"))
                end))
                tut:startNextStage()
            end)
        end
    }
})