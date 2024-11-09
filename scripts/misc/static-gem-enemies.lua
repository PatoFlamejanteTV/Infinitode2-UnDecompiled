--[[
Static Gems

Replaces DUMMY tiles with gems that can be attacked by towers.
Gems use invisible generic enemies on their part.

StaticGemEnemies.createGems() can be called at any time to initialize gem visuals,
then StaticGemEnemies.spawnGemEnemies() will spawn actual enemies so that towers can attack them.
If spawnGemEnemies() not called manually, they'll spawn when the first wave starts. Can be disabled
by setting StaticGemEnemies.spawnOnFirstWave to false.

Gems will inherit DUMMY tile color.
DUMMY tile data:
  - sType = "staticGemEnemy", used to mark a DUMMY tile to be handled by this script.
  - iHp - gem HP.
  - sGemShape (optional) - shape of the gem ("triangle" by default), will use "gem-[shape]-base" and
    "gem-[shape]-overlay" textures to draw the gem.
  - iXp (optional) - xp given to towers for destroying the gem.
  - iScore (optional) - score given for destroying the gem.
  - iBounty (optional) - coins given for killing the enemy.
  - SAction (optional) - script that'll be called when the gem is destroyed, accepts vararg: lastDamage = ... (globals like S can also be used).
  - SEnemyModifiers (optional) - script that'll be called for each enemy that is being created,
    accepts varargs: enemy, gem, tile = ... (+ globals).
  - SonBreak (optional) - list of predefined actions that will happen right after the SAction.
    Each line is a separate action:
    - give_items|{ItemStack as json} - items will drop as a regular loot from the game, for example
      give_items|{"i":{"type":"GREEN_PAPER"},"c": 1500} will give 1500 Green Papers.
    - replace_with_tile|{Tile as json} - will be replaced with a tile, for example
      replace_with_tile|{"type":"TILE","tile":{"type":"PLATFORM"}} will replace it with a regular
      Platform.
    - place_tile|x|y|{Tile as json} - will place a tile at the specified coordinates, for example
      place_tile|5|10|{"type":"TILE","tile":{"type":"PLATFORM"}} will put a Platform at x5, y10.
--]]

local logger = C.TLog:forTag("static-gem-enemies.lua")

local SEGMENTS_PER_CURVE = 20
local GEM_RENDERING_Z_INDEX = C.GameRenderingOrder.MAP_DRAW_TILE_EXTRAS + 10
local GEM_MENU_EXTRAS_RENDERING_Z_INDEX = C.GameRenderingOrder.MAP_RENDERING_GAME_SELECTION + 10

--[[
Here we create a separate Table to store variables needed for the UI and other stuff which normally
is not saved / restored when a game continues (Textures / Sounds / UI elements etc).
The name of this table can be anything but I've preferred the "UIV" (UI-variables) because the game
basically works in one of two modes - "headless" (server-side, no UI / assets) and "full" (a regular
one with UI, assets and anything you normally find in a complete game) and I could not come up with
a better name for the second mode so I've called it a "UI mode".
Remember that not all objects are serializable (will be stored in a saved game / replay and restored
when player continues the game), for example Label and Image are UI-related classes, do not affect
the gameplay and there's no reason in storing them (also it is very hard to restore such objects).
Same goes for Texture / TextureRegion and other assets. For a complete list of classes that will be
properly serialized, look into kryo-registry.txt.
This table serves two purposes:
- We expect these variables to become nil when player continues the game, so this table serves as
  a neat list of a "nullable" variables for us - we store non-serializable stuff here and know that
  it becomes nil when the game is continued, and we are ready to restore it on StateRestore event
  or on demand.
- Tables serve as containers for variables and it is very handy in case of "desync checks". We can
  mark this whole table as ignored by sync checks (by specifying a "_noSyncCheck = true" field)
  which will make sync checker ignore all the fields of this table.
  It is important if we want to write a high-quality script and make sure there's no synchronization
  issues - normally we'll run sync-checker to do that, and it will report a desync if some var is
  absent.

  Serialization is better explained in the docs (or will be), but here's a short explanation:
  Game's state is completely deterministic, which means it does not depend on player's FPS or any
  kind of randomness. Each game can be re-simulated from the frame 0 and, if fed with player's
  actions on specific frames, the result of the game will be exactly and precisely the same. It
  allows to validate replays and restore a state of the game if it fails to deserialize, and any
  slightest desynchronization may cause an avalanche of incorrectly simulated game state, completely
  invalidating the outcome of the game.
  To make sure there are no synchronization issues, the game provides a "Synck check" debug setting.
  When enabled, the game runs a completely separate simulation of exactly the same run in a
  "headless" mode (no UI / assets etc) and feeds it exactly the same player actions on exactly the
  same frame numbers, and then it compares the state of this simulation with the real run. If it
  spots any difference in any state-related variable, it reports a desync. The difference may be
  very slight (like a slightly different rotation of some tower) but it can't be ignored because of
  that "avalanche" effect - this error will affect the game's state on the next frame and screw up
  the state even more (for example, the tower will be able to shoot 1 frame sooner etc).

  Game does not know what you are doing in Lua script and can't say if some variable is important
  for the game's state or not, that's why it will check every single variable of your script and
  will report a desync if it does not match with the same variable in a "headless" simulation.

  As an example, you can cause a desync simply by storing an Image in a regular variable - it will
  have a proper Image object in a "normal / UI" mode but will be absent (nil) in "headless",
  triggering the desync report. Or you can store a mouse cursor position (float) on one of your
  variables, which will produce the same result as there's no mouse in "headless" mode.

  So, yeah, you can give a sync-checker a hint to ignore some table and store anything you want
  there - any table with "_noSyncCheck = true" field won't be sync-checked.
--]]
local UIV = {
    _noSyncCheck = true, -- makes sync checker ignore this table as it contains data which can be changed outside of the game state (UI interactions / Render event etc)

    lastSelectedGem = nil, -- keeping track of the last selected gem. If selected gem has been changed, the gem menu will be updated

    container = nil, -- SideMenu container for the gem menu

    ---@type Label
    hpLabel = nil, -- Label for the gem's HP - we are storing it here because we'll need to access it at each rendering frame but it is only recreated when selected gem changes

    hpLine = nil, -- same as hpLabel

    --[[
        Each time we update the gem menu by inserting new actors, the UI hierarchy gets invalidated
        and needs to be properly laid out, which happens only on the next frame before UI gets drawn.
        By setting this flag to true when we update the UI and checking it in the Render listener,
        we basically skip one frame so that next time the listener is called, it knows the proper
        actor positions.
        It is a trick actually - you can try to layout the UI earlier with pack() / layout() methods
        but LibGDX's UI is a bit tricky and it may not work sometimes.
        In case of this script, Bezier curves from Gem menu with place_tile action may render
        incorrectly at the first frame the menu is being drawn
    --]]
    skipUiExtrasRenderingForFrame = true,
    hideRegularVulnerabilityCells = false,
    hideInvulnerableCells = true,
    gemMenuRenderListeners = {},
    curveHelperArray = java.lang.reflect.Array.class:newInstance_C_i(java.float, (SEGMENTS_PER_CURVE + 1) * 3),
    bezierPointArray = java.lang.reflect.Array.class:newInstance_C_i(java.float, SEGMENTS_PER_CURVE * 20)
}

--- @class GemEffect
--- @field type string
--- @field args string[]
local GemEffect = {}

--- @class Gem
--- @field textureBase TextureRegion
--- @field textureOverlay TextureRegion
--- @field x number
--- @field y number
--- @field tile DummyTile
--- @field active boolean
--- @field enemy GenericEnemy
--- @field color Color
--- @field enemySpawned boolean
--- @field effects GemEffect[]
--- @field effectsUiElements Table[]
local Gem = {

    --- @param tile DummyTile
    --- @param shape string|java.lang.String
    --- @return Gem
    new = function(self, tile, shape)
        local gem = {}
        setmetatable(gem, self)
        self.__index = self

        gem.active = true
        gem.color = tile.color
        gem.x = tile:getX()
        gem.y = tile:getY()
        gem.tile = tile
        gem.shape = shape
        gem.enemySpawned = false
        gem.effects = {}

        return gem
    end
}


--[[
Actual script starts here.
We create a "main" Table and store it in a local variable, it will store all data needed by this
script that may be useful outside of this script.
--]]
local StaticGemEnemies = {}
StaticGemEnemies.UDI_GEM = "static-gem-enemies-gem-id" -- userDataIndex used to store data in enemy

---@type Gem[]
StaticGemEnemies.gems = {} -- list of gems, used internally by the script
StaticGemEnemies.spawnOnFirstWave = true -- can be set to false if you want to make gems damageable later and not with the start of the first wave
StaticGemEnemies.lowAimPriority = true
StaticGemEnemies.menuRowBgColor = C.Color.new_i(0x252525FF)

-- Used for SonBreak
StaticGemEnemies.gemActions = {
    -- give_items|{ItemStack json}
    give_items = {
        action = function(gem, args)
            local stack = C.ItemStack:fromJson(C.JsonReader.new():parse(args[2]))
            local v2 = C.Vector2.new_V2(gem.enemy:getPosition())
            if S._input ~= nil then S._input.cameraController:mapToStage(v2) end
            S.gameState:addLootIssuedPrizes(stack, v2.x, v2.y, 2)
        end,
        createMenuActor = function(table, gem, args)
            local stack = C.ItemStack:fromJson(C.JsonReader.new():parse(args[2]))
            local container = C.Table()
            table:add(container):growX()

            -- Note: Java's method I18NBundle.format() is a vararg function (which means it can receive a varying number of arguments)
            -- To call a Java's vararg method from Lua, pass those "varying" arguments in an array / table:
            local str = C.Game.i.localeManager.i18n:format("static_gem_action_drop_items", tostring(stack:getItem():getTitle()))
            local label = C.Label.new(str, C.Game.i.assetManager:getLabelStyle(CFG.FONT_SIZE_SMALL))
            container:add(label)
            container:add():height(1):growX()

            local icon = stack:getItem():generateIcon(32, false)
            container:add(icon):size(32)

            if stack:getCount() > 1 then
                local countLabel = C.Label.new(C.StringFormatter:compactNumber(stack:getCount(), false), C.Game.i.assetManager:getLabelStyle(CFG.FONT_SIZE_SMALL))
                container:add(countLabel):padLeft(8)
            end

            return container
        end
    },
    -- place_tile|x|y|{Tile json}
    place_tile = {
        action = function(gem, args)
            local x = tonumber(args[2]) --[[@as number]]
            local y = tonumber(args[3]) --[[@as number]]
            local newTile = C.Game.i.tileManager:createTileFromJsonString(args[4])
            S.map:setTile(x, y, newTile)
        end,
        createMenuActor = function(table, gem, args)
            local newTile = C.Game.i.tileManager:createTileFromJsonString(args[4])

            local container = C.Table.new()
            table:add(container):growX()

            local str = C.Game.i.localeManager.i18n:get("static_gem_action_place_tile")
            local label = C.Label.new(str, C.Game.i.assetManager:getLabelStyle(CFG.FONT_SIZE_SMALL))
            container:add(label)
            container:add():height(1):growX()

            local icon = newTile:generateUiIcon(40)
            container:add(icon):size(40)

            return container
        end,
        onMenuRender = function(batch, rowActor, gem, args)
            local x = tonumber(args[2])
            local y = tonumber(args[3])

            local tileCX = x * CFG.TILE_SIZE + CFG.TILE_HALF_SIZE
            local tileCY = y * CFG.TILE_SIZE + CFG.TILE_HALF_SIZE

            local cc = S._input:getCameraController()
            local actorPos = C.Vector2.new_2f(0, 52 * 0.5)
            rowActor:localToStageCoordinates(actorPos)
            cc:stageToMap(actorPos)

            local bezierPoints = {}
            bezierPoints[#bezierPoints + 1] = C.Vector2.new_2f(tileCX, tileCY)
            bezierPoints[#bezierPoints + 1] = C.Vector2.new_2f(tileCX, tileCY):add(100 * cc.zoom, 0)
            bezierPoints[#bezierPoints + 1] = C.Vector2.new_V2(actorPos):add(-100 * cc.zoom, 0)
            bezierPoints[#bezierPoints + 1] = actorPos

            -- Colored lines
            local blankTR = C.Game.i.assetManager:getBlankWhiteTextureRegion()
            C.DrawUtils:prepareBezierCurve(UIV.curveHelperArray, bezierPoints, SEGMENTS_PER_CURVE, C.MaterialColor.CYAN.P500, C.MaterialColor.CYAN.P800)
            C.DrawUtils:getTexturedMultiLineVertices(UIV.bezierPointArray, 2 * cc.zoom, blankTR, UIV.curveHelperArray, 0, #UIV.curveHelperArray)

            C.RenderingManager:prepareBatch(batch, true)
            batch:draw(blankTR:getTexture(), UIV.bezierPointArray, 0, #UIV.bezierPointArray)
            -- Batch batch, TextureRegion textureRegion, float startX, float startY, float endX, float endY, float width, float startColor, float endColor
            C.DrawUtils:texturedLineC(batch, blankTR, tileCX, tileCY, tileCX + 15 * cc.zoom, tileCY + 7 * cc.zoom, 2 * cc.zoom, C.MaterialColor.CYAN.P500:toFloatBits(), C.MaterialColor.CYAN.P500:toFloatBits())
            C.DrawUtils:texturedLineC(batch, blankTR, tileCX, tileCY, tileCX + 15 * cc.zoom, tileCY - 7 * cc.zoom, 2 * cc.zoom, C.MaterialColor.CYAN.P500:toFloatBits(), C.MaterialColor.CYAN.P500:toFloatBits())
            C.DrawUtils:texturedLineC(batch, blankTR, tileCX + 4 * cc.zoom, tileCY, tileCX + 15 * cc.zoom, tileCY + 7 * cc.zoom, 2 * cc.zoom, C.MaterialColor.CYAN.P500:toFloatBits(), C.MaterialColor.CYAN.P500:toFloatBits())
            C.DrawUtils:texturedLineC(batch, blankTR, tileCX + 4 * cc.zoom, tileCY, tileCX + 15 * cc.zoom, tileCY - 7 * cc.zoom, 2 * cc.zoom, C.MaterialColor.CYAN.P500:toFloatBits(), C.MaterialColor.CYAN.P500:toFloatBits())
        end
    },
    replace_with_tile = {
        -- replace_with_tile|{Tile json}
        action = function(gem, args)
            local newTile = C.Game.i.tileManager:createTileFromJsonString(args[2])
            S.map:setTile(gem.x, gem.y, newTile)
        end,
        createMenuActor = function(table, gem, args)
            local newTile = C.Game.i.tileManager:createTileFromJsonString(args[2])

            local container = C.Table.new()
            table:add(container):growX()

            local str = C.Game.i.localeManager.i18n:get("static_gem_action_replace_with_tile")
            local label = C.Label.new(str, C.Game.i.assetManager:getLabelStyle(CFG.FONT_SIZE_SMALL))
            container:add(label)
            container:add():height(1):growX()

            local icon = newTile:generateUiIcon(40)
            container:add(icon):size(40)

            return container
        end
    }
}

--[[
We can store some variables as a regular local ones and they won't be accessible outside of this
script.
--]]
local aimTargetResetCounter = 1 -- stores an index of the tower whose target will be reset on the next frame (to prevent towers from focusing on the gems if there are real enemies in range)

--[[
Here we create a Java's object of ObjectFilter class, which is an interface.
ObjectFilter argument can be passed to Tower.findTarget() which allows to ignore enemies in the process.
This particular implementation filters out any enemy used for gems, meaning that findTarget() will
ignore gems and will return only "normal" enemies.
--]]
local targetResetFilter = C.ObjectFilter(function(e)
    return e:getUserData(StaticGemEnemies.UDI_GEM) == nil
end)

--[[
Creates, registers but does not spawn a configured GENERIC enemy.
Returns an Enemy instance to be used later.
--]]
local createEnemy = function(speed, health, killScore, killBounty, killExp)
    local creep = C.Game.i.enemyManager.F.GENERIC:obtain() --[[@as GenericEnemy]]
    creep:setSpeed(speed)
    creep.maxHealth = health
    creep:setHealth(health)
    creep.killScore = killScore
    creep.bounty = killBounty
    creep:setKillExp(killExp)
    creep.ignoredOnGameOverNoEnemies = true

    creep.spawnTile = S.map:getMap():getTilesByType(C.SpawnTile):first() --[[@as SpawnTile]]
    S.enemy:registerWithPath(creep, nil, 5, 0)

    return creep
end

--[[
Fills gem.textureBase and gem.textureOverlay fields with TextureRegion objects to be used later for
gem rendering.
Remember: TextureRegion is an asset and it won't be restored when the game continues, we expect it
to be nil. We could restore it on StateRestore event or, just like in this case - on demand.
Call this function each time before you need to draw a gem.
Returns nothing.
--]]
local loadGemTextures = function(gem)
    if gem.textureBase == nil then
        gem.textureBase = C.Game.i.assetManager:getTextureRegion("gem-" .. gem.shape .. "-base")
        gem.textureOverlay = C.Game.i.assetManager:getTextureRegion("gem-" .. gem.shape .. "-overlay")
    end
end

--[[
Actually starts this script - creates gems and adds listeners.
--]]
StaticGemEnemies.start = function()
    StaticGemEnemies.createGems()

    -- Spawn actual DUMMY enemies on the first wave, if not disabled
    local waveSystemListener -- we define a variable separately to be able to access it from inside the function stored in it
    waveSystemListener = C.Listener(function(_)
        if StaticGemEnemies.spawnOnFirstWave then
            StaticGemEnemies.spawnGemEnemies()
        end
        S.events:getListeners(C.WaveStart):remove(waveSystemListener) -- we use "ourself" here, that's why waveSystemListener is defined on the separate line
    end)
    S.events:getListeners(C.WaveStart):addStateAffecting(waveSystemListener)

    -- Breaking a gem on DUMMY enemy death and triggering gem's actions
    S.events:getListeners(C.EnemyDie):addStateAffecting(C.Listener(function(event)
        ---@cast event EnemyDie
        local lastDamage = event:getLastDamage()
        local enemy = lastDamage:getEnemy()

        local gem = enemy:getUserData(StaticGemEnemies.UDI_GEM) --[[@as Gem]]
        if gem ~= nil then
            -- There's a gem associated with the dead enemy
            if not S.CFG.headless then -- this way we check whether we are in "headless" or "UI" mode
                loadGemTextures(gem) -- we are about to use gem.textureBase so we make sure it is properly initialized
                S._particle:addShatterParticle(gem.textureBase, gem.x * CFG.TILE_SIZE + CFG.TILE_HALF_SIZE, gem.y * CFG.TILE_SIZE + CFG.TILE_HALF_SIZE, CFG.TILE_SIZE, 0, 1, gem.color, nil, false)
            end

            -- Loading the "action" script defined by the gem
            local actionScript = gem.tile:getData("SAction") --[[@as string]]
            local chunk
            if actionScript ~= nil then
                chunk = load(actionScript)
            end

            -- Remove gem from map
            S.map:setTile(gem.tile:getX(), gem.tile:getY(), nil)

            -- Running the "action" script, if defined by the gem
            if chunk ~= nil then
                local status, err = pcall(function () chunk(lastDamage) end)
                if not status then
                    logger:w("Failed to execute SAction on tile " .. tostring(gem.tile), err)
                end
            end

            -- Running gem actions from SonBreak
            for _, v in ipairs(gem.effects) do
                local status, err = pcall(function () StaticGemEnemies.gemActions[v.type].action(gem, v.args) end)
                if not status then
                    logger:w("Failed to execute SonBreak on tile " .. tostring(gem.tile) .. " (" .. tostring(v.type) .. ")", err)
                end
            end

            gem.active = false
        end
    end))

    -- Gem tile menu
    S.events:getListeners(C.MapElementSelect):addStateAffecting(C.Listener(StaticGemEnemies._updateGemMenu)):setDescription("static-gem-enemies - updates gem menu")

    -- Updating the gem menu on every frame rendered
    S.events:getListeners(com.prineside.tdi2.events.game.Render.class):addStateAffecting(C.Listener(function(_)
        StaticGemEnemies._updateGemMenu()
    end))

    -- Resetting tower targets, one tower per game tick, if they are focused on gems while there are
    -- more important enemies in range
    if StaticGemEnemies.lowAimPriority then
        S.events:getListeners(C.GameStateTick):addStateAffecting(C.Listener(function(_)
            if S.tower.towers.size < aimTargetResetCounter then
                aimTargetResetCounter = 1
            end

            if S.tower.towers.size ~= 0 then
                local tower = S.tower.towers.items[aimTargetResetCounter] --[[@as Tower]]
                if tower:getTarget() ~= nil then
                    local cfg = tower:getTarget():getUserData(StaticGemEnemies.UDI_GEM)
                    if cfg ~= nil then
                        local newTarget = tower:findTargetFiltered(targetResetFilter)
                        if newTarget ~= nil then
                            tower:setTarget(newTarget)
                        end
                    end
                end
            end

            aimTargetResetCounter = aimTargetResetCounter + 1
        end))
    end

    StaticGemEnemies.initNonStateAffectingStuff()
    S.events:getListeners(C.SystemsStateRestore):addStateAffecting(C.Listener(StaticGemEnemies.initNonStateAffectingStuff))
end

StaticGemEnemies.initNonStateAffectingStuff = function()
    if S.CFG.headless then return nil end

    --[[
        Render the gems each frame.
        Note the listener's priority - it affects the order of rendering.
        In this case, it will be triggered after tile extras are already drawn.
        For more info, refer to GameRenderingOrder javadoc - AFTER_PERCENT and draw order are better
        explained there.
        --]]
    S._render:addLayer(C.RenderSystem.Layer.new(
        GEM_RENDERING_Z_INDEX, -- zIndex
        false, -- additive
        C.LayerRenderer(function(batch, realDeltaTime, inGameDeltaTime, interpolatedDeltaTime)
            for _, v in ipairs(StaticGemEnemies.gems) do
                if v.active then
                    loadGemTextures(v)
                    batch:setColor(v.color)
                    batch:draw(v.textureBase, v.x * CFG.TILE_SIZE, v.y * CFG.TILE_SIZE, CFG.TILE_SIZE, CFG.TILE_SIZE)
                    batch:setColor(CFG.WHITE_COLOR_CACHED_FLOAT_BITS)
                    batch:draw(v.textureOverlay, v.x * CFG.TILE_SIZE, v.y * CFG.TILE_SIZE, CFG.TILE_SIZE, CFG.TILE_SIZE)
                end
            end
        end)
    ))

    S._render:addLayer(C.RenderSystem.Layer.new(
        GEM_MENU_EXTRAS_RENDERING_Z_INDEX,
        false,
        C.LayerRenderer(function(batch, realDeltaTime, inGameDeltaTime, interpolatedDeltaTime)
            if UIV.skipUiExtrasRenderingForFrame then
                UIV.skipUiExtrasRenderingForFrame = false
                return nil
            end

            local selectedTile = S._gameMapSelection:getSelectedTile() --[[@as DummyTile]]
            if selectedTile ~= nil and selectedTile.type == C.TileType.DUMMY and selectedTile:getData("sType") == "staticGemEnemy" then
                -- Gem tile is selected
                local gem = selectedTile:getUserData(StaticGemEnemies.UDI_GEM) --[[@as Gem]]
                for idx, v in ipairs(gem.effects) do
                    local onRender = StaticGemEnemies.gemActions[v.type].onMenuRender
                    if onRender then
                        -- batch, rowActor, gem, args
                        onRender(batch, gem.effectsUiElements[idx], gem, v.args)
                    end
                end
            end
        end)
    ))
end

--[[
Called each frame to update the menu of the selected game.
Recreates the menu on demand and updates info in real time.
--]]
StaticGemEnemies._updateGemMenu = function()
    local selectedTile = S._gameMapSelection:getSelectedTile()

    if selectedTile ~= nil and selectedTile.type == C.TileType.DUMMY then
        ---@cast selectedTile DummyTile
        if selectedTile:getData("sType") == "staticGemEnemy" then
            -- Gem tile is selected
            local gem = selectedTile:getUserData(StaticGemEnemies.UDI_GEM) --[[@as Gem]]
            local extraHeight = C.Game.i.settingsManager:getScaledViewportHeight() - CFG.VIEWPORT_HEIGHT

            if UIV.container == nil then
                -- Recreate / initialize Gem tile menu
                UIV.container = S._gameUi.sideMenu:createContainer("StaticGemMenuContainer")
                UIV.lastSelectedGem = nil
            end

            if UIV.lastSelectedGem ~= gem then
                -- Player has selected some other gem / this is the first time any gem is selected
                -- Heavy code can be run here as it gets triggered once each time a selected gem
                -- tile has been changed
                UIV.container:clear()

                local titleLabel = C.Label.new(C.Game.i.localeManager.i18n:get("static_gem_menu_title"), C.Game.i.assetManager:getLabelStyle(CFG.FONT_SIZE_LARGE))
                titleLabel:setPosition(40, 249 + 745 + extraHeight)
                titleLabel:setSize(520, 26)
                UIV.container:addActor(titleLabel)

                local hpBarGroup = C.Group.new()
                hpBarGroup:setName("gem_menu_hp_bar")
                hpBarGroup:setTransform(false)
                hpBarGroup:setPosition(40, 209 + 745 + extraHeight)
                hpBarGroup:setSize(520, 66)
                UIV.container:addActor(hpBarGroup)

                UIV.hpLine = C.ExpLine.new()
                hpBarGroup:addActor(UIV.hpLine)

                UIV.hpLabel = C.Label.new("", C.Game.i.assetManager:getLabelStyle(CFG.FONT_SIZE_SMALL))
                UIV.hpLabel:setSize(520, 24)
                UIV.hpLabel:setAlignment(C.Align.right)
                hpBarGroup:addActor(UIV.hpLabel)

                local content = C.Table.new()

                local contentScroll = C.ScrollPane.new_A(content)
                C.UiUtils:enableMouseMoveScrollFocus(contentScroll)
                contentScroll:setSize(600, 209 + 725 + extraHeight)
                UIV.container:addActor(contentScroll)

                -- Coins
                local coinsLayout = C.Table.new()
                coinsLayout:setBackground(C.Game.i.assetManager:getDrawable("blank"):tint(StaticGemEnemies.menuRowBgColor))
                content:add(coinsLayout):size(600, 52):row()

                local coinsRowTitle = C.Label.new(C.Game.i.localeManager.i18n:get("coins"), C.Game.i.assetManager:getLabelStyle(CFG.FONT_SIZE_SMALL))
                coinsLayout:add(coinsRowTitle):expandX():fillX():height(52):padLeft(40)

                coinsLayout:add(C.Image.new_D(C.Game.i.assetManager:getDrawable("coin-small"))):size(32):padTop(10):padBottom(10):padRight(8)

                local coinsLabel = C.Label.new(C.StringFormatter:compactNumber(gem.enemy.bounty, false), C.Game.i.assetManager:getLabelStyle(CFG.FONT_SIZE_SMALL))
                coinsLabel:setColor(C.MaterialColor.YELLOW.P500)
                coinsLayout:add( coinsLabel):height(52):padRight(40)

                -- Score
                local scoreLayout = C.Table.new()
                scoreLayout:setBackground(C.Game.i.assetManager:getDrawable("blank"):tint(StaticGemEnemies.menuRowBgColor))
                content:add(scoreLayout):size(600, 52):padTop(4):row()

                local scoreRowTitle = C.Label.new(C.Game.i.localeManager.i18n:get("score"), C.Game.i.assetManager:getLabelStyle(CFG.FONT_SIZE_SMALL))
                scoreLayout:add(scoreRowTitle):expandX():fillX():height(52):padLeft(40)

                scoreLayout:add(C.Image.new_D(C.Game.i.assetManager:getDrawable("icon-star"))):size(32):padTop(10):padBottom(10):padRight(8)

                local scoreLabel = C.Label.new(C.StringFormatter:compactNumber(gem.enemy.killScore, false), C.Game.i.assetManager:getLabelStyle(CFG.FONT_SIZE_SMALL))
                scoreLayout:add(scoreLabel):height(52):padRight(40)

                -- XP
                local xpLayout = C.Table.new()
                xpLayout:setBackground(C.Game.i.assetManager:getDrawable("blank"):tint(StaticGemEnemies.menuRowBgColor))
                content:add(xpLayout):size(600, 52):padTop(4):row()

                local xpRowTitle = C.Label.new(C.Game.i.localeManager.i18n:get("experience"), C.Game.i.assetManager:getLabelStyle(CFG.FONT_SIZE_SMALL))
                xpLayout:add(xpRowTitle):expandX():fillX():height(52):padLeft(40)

                local xpIcon = C.Image.new_D(C.Game.i.assetManager:getDrawable("icon-experience"))
                xpIcon:setColor(C.MaterialColor.CYAN.P500)
                xpLayout:add(xpIcon):size(32):padTop(10):padBottom(10):padRight(8)

                local xpLabel = C.Label.new(C.StringFormatter:compactNumber(gem.enemy:getKillExp(), false), C.Game.i.assetManager:getLabelStyle(CFG.FONT_SIZE_SMALL))
                xpLabel:setColor(C.MaterialColor.CYAN.P500)
                xpLayout:add(xpLabel):height(52):padRight(40)

                if #gem.effects ~= 0 then
                    -- Effects on break
                    local effectsHeaderLabel = C.Label.new(C.Game.i.localeManager.i18n:get("effects"), C.Game.i.assetManager:getLabelStyle(CFG.FONT_SIZE_X_SMALL))
                    effectsHeaderLabel:setColor(1, 1, 1, 0.56)
                    content:add(effectsHeaderLabel):padLeft(40):padRight(40):size(520, 52):padTop(4):row()

                    local effectsTable = C.Table.new()
                    content:add(effectsTable):width(600):row()
                    gem.effectsUiElements = {}

                    for idx, v in ipairs(gem.effects) do
                        local rowLayout = C.Table.new()
                        rowLayout:setBackground(C.Game.i.assetManager:getDrawable("blank"):tint(StaticGemEnemies.menuRowBgColor))
                        effectsTable:add(rowLayout):width(600):minHeight(52):padBottom(4):row()
                        gem.effectsUiElements[idx] = rowLayout

                        local status, err = pcall(function ()
                            StaticGemEnemies.gemActions[v.type].createMenuActor(rowLayout, gem, v.args):padTop(8):padBottom(8):padLeft(40):padRight(40)
                        end)
                        if not status then
                            logger:w("Failed to execute createMenuActor for SonBreak action " .. tostring(v.type) .. " on tile " .. tostring(gem.tile) .. " (" .. tostring(v.type) .. ")", err)
                        end
                    end
                end

                -- Vulnerabilities to towers / buffs / damage types / special damage types / abilities
                local togglesTable = C.Table.new()
                content:add(togglesTable):padLeft(40):padRight(40):growX():padTop(16):row()

                local hideRegularToggle = C.LabelToggleButton.new()
                hideRegularToggle:setup(
                        C.Game.i.localeManager.i18n:get("static_gem_menu_hide_100_percent"),
                        UIV.hideRegularVulnerabilityCells,
                        CFG.FONT_SIZE_X_SMALL,
                        32,
                        false,
                        C.ObjectConsumer(function(v)
                            UIV.hideRegularVulnerabilityCells = v
                            UIV.lastSelectedGem = nil
                            StaticGemEnemies._updateGemMenu()
                        end)
                )
                togglesTable:add(hideRegularToggle):growX():padRight(20)

                local hideInvulnerableToggle = C.LabelToggleButton.new()
                hideInvulnerableToggle:setup(
                        C.Game.i.localeManager.i18n:get("static_gem_menu_hide_invulnerable"),
                        UIV.hideInvulnerableCells,
                        CFG.FONT_SIZE_X_SMALL,
                        32,
                        false,
                        C.ObjectConsumer(function(v)
                            UIV.hideInvulnerableCells = v
                            UIV.lastSelectedGem = nil
                            StaticGemEnemies._updateGemMenu()
                        end)
                )
                togglesTable:add(hideInvulnerableToggle):growX():padLeft(20)

                local vulnerabilitiesTable = C.Table.new()
                content:add(vulnerabilitiesTable):width(600):row()

                local colorFromEfficiency = function (efficiency)
                    local efficiencyPercentage = efficiency * 100
                    if efficiencyPercentage <= 25.1 then
                        return C.MaterialColor.RED.P500
                    elseif efficiencyPercentage <= 50.1 then
                        return C.MaterialColor.ORANGE.P500
                    elseif efficiencyPercentage <= 75.1 then
                        return C.MaterialColor.AMBER.P500
                    elseif efficiencyPercentage <= 100.1 then
                        return C.Color.WHITE
                    elseif efficiencyPercentage <= 125.1 then
                        return C.MaterialColor.LIGHT_GREEN.P500
                    else
                        return C.MaterialColor.GREEN.P500
                    end
                end

                --[[
                    Returns true if cell has been added
                --]]
                local efficiencyCell = function(cellIdx, drawable, drawableColor, drawableSize, damageMult)
                    if UIV.hideRegularVulnerabilityCells and damageMult == 1 then
                        return false
                    end
                    if UIV.hideInvulnerableCells and damageMult == 0 then
                        return false
                    end

                    local rowLayout = C.Table.new()
                    rowLayout:setBackground(C.Game.i.assetManager:getDrawable("blank"):tint(StaticGemEnemies.menuRowBgColor))
                    local cell = vulnerabilitiesTable:add(rowLayout):minHeight(52):padBottom(4)

                    local icon = C.Image.new_D(drawable)
                    icon:setColor(drawableColor)
                    local iconCell = rowLayout:add(icon):size(drawableSize)
                    rowLayout:add():height(1):growX()
                    local multLabel = C.Label.new(tostring(C.StringFormatter:compactNumber(damageMult * 100, false)) .. "[#808080]%[]", C.Game.i.assetManager:getLabelStyle(CFG.FONT_SIZE_X_SMALL))
                    multLabel:setColor(colorFromEfficiency(damageMult))
                    local labelCell = rowLayout:add(multLabel):padRight(40)

                    local colIdx = (cellIdx - 1) % 4
                    if colIdx == 0 then
                        cell:padRight(4):width(160)
                        iconCell:padLeft(32 + (52 - drawableSize) * 0.5)
                        labelCell:padRight(16)
                    elseif colIdx == 1 or colIdx == 2 then
                        cell:padRight(4):width((600 - 320 - 12) / 2)
                        iconCell:padLeft(16)
                        labelCell:padRight(16)
                    else
                        iconCell:padLeft(16)
                        labelCell:padRight(40)
                        cell:width(160):row()
                    end

                    return true
                end

                local noSpecialVulnerabilities = function()
                    local rowLayout = C.Table.new()
                    rowLayout:setBackground(C.Game.i.assetManager:getDrawable("blank"):tint(StaticGemEnemies.menuRowBgColor))
                    vulnerabilitiesTable:row()
                    vulnerabilitiesTable:add(rowLayout):colspan(4):growX():minHeight(52):padBottom(4):row()

                    local label = C.Label.new(C.Game.i.localeManager.i18n:get("has_no_special_vulnerabilities"), C.Game.i.assetManager:getLabelStyle(CFG.FONT_SIZE_X_SMALL))
                    label:setColor(1,1,1,0.56)
                    rowLayout:add(label):padLeft(40):padRight(40):growX()
                end

                -- -- Towers
                local headerLabel = C.Label.new(C.Game.i.localeManager.i18n:get("tower_efficiency"), C.Game.i.assetManager:getLabelStyle(CFG.FONT_SIZE_X_SMALL))
                headerLabel:setColor(1, 1, 1, 0.56)
                vulnerabilitiesTable:add(headerLabel):colspan(4):padLeft(40):padRight(40):size(520, 52):padTop(4):row()

                local idx = 1
                for i = 1, #C.TowerType.values do
                    local towerType = C.TowerType.values[i]
                    local towerFactory = C.Game.i.towerManager:getFactory(towerType)
                    if towerFactory:isAvailable(S.gameValue --[[@as GameValueProvider]]) then
                        if efficiencyCell(idx, towerFactory:getIconDrawable(), C.Color.WHITE, 52, gem.enemy:getTowerDamageMultiplier(towerType)) then
                            idx = idx + 1
                        end
                    end
                end
                if idx == 1 then
                    noSpecialVulnerabilities()
                end
                vulnerabilitiesTable:row()

                -- -- Abilities
                headerLabel = C.Label.new(C.Game.i.localeManager.i18n:get("ability_efficiency"), C.Game.i.assetManager:getLabelStyle(CFG.FONT_SIZE_X_SMALL))
                headerLabel:setColor(1, 1, 1, 0.56)
                vulnerabilitiesTable:add(headerLabel):colspan(4):padLeft(40):padRight(40):size(520, 52):padTop(4):row()
                idx = 1
                for i = 1, #C.AbilityType.values do
                    local abilityType = C.AbilityType.values[i]
                    local factory = C.Game.i.abilityManager:getFactory(abilityType)
                    if S.gameValue:getIntValue(C.Game.i.abilityManager:getMaxPerGameGameValueType(abilityType)) > 0 then
                        if efficiencyCell(idx, factory:getIconDrawable(), factory:getColor(), 32, gem.enemy:getAbilityVulnerability(abilityType)) then
                            idx = idx + 1
                        end
                    end
                end
                if idx == 1 then
                    noSpecialVulnerabilities()
                end
                vulnerabilitiesTable:row()

                -- -- Buffs
                headerLabel = C.Label.new(C.Game.i.localeManager.i18n:get("buff_efficiency"), C.Game.i.assetManager:getLabelStyle(CFG.FONT_SIZE_X_SMALL))
                headerLabel:setColor(1, 1, 1, 0.56)
                vulnerabilitiesTable:add(headerLabel):colspan(4):padLeft(40):padRight(40):size(520, 52):padTop(4):row()
                idx = 1
                for i = 1, #C.BuffType.values do
                    local buffType = C.BuffType.values[i]
                    local factory = C.Game.i.buffManager:getFactory(buffType)

                    if efficiencyCell(idx, C.TextureRegionDrawable.new_TR(factory:getHealthBarIcon()), C.Color.WHITE, 32, gem.enemy:getBuffVulnerability(buffType)) then
                        idx = idx + 1
                    end
                end
                if idx == 1 then
                    noSpecialVulnerabilities()
                end
                vulnerabilitiesTable:row()

                -- TODO damageType / specialDamageType - can't add yet - no i18n nor assigned textures but GenericEnemy allows modifying that

                content:row()
                content:add():width(1):growY():row()
                content:add():width(1):height(40):row()

                UIV.lastSelectedGem = gem
                UIV.skipUiExtrasRenderingForFrame = true
            end

            -- Remaining code gets run on each frame, be careful not to rebuild the UI / allocate
            -- lots of objects as it may harm the performance

            -- HP
            local currHp = C.StringFormatter:compactNumber(gem.enemy:getHealth(), false):toString()
            local maxHp = C.StringFormatter:compactNumber(gem.enemy.maxHealth, false):toString()
            UIV.hpLabel:setText(currHp .. " / " .. maxHp)

            UIV.hpLine:setColor(gem.color)
            UIV.hpLine:setCoeff(gem.enemy:getHealth() / gem.enemy.maxHealth)

            UIV.container:show()
        else
            UIV.container:hide()
        end
    elseif UIV.container ~= nil then
        UIV.container:hide()
    end
end

--[[
Scans the map for DUMMY tiles marked as gems, loads gem config from them and configures the gem
enemies. Does not spawn enemies yet though, only allows to draw the gems.
--]]
StaticGemEnemies.createGems = function()
    local tiles = S.map:getMap():getTilesByType(C.DummyTile)
    for i = 1, tiles.size do
        local tile = tiles.items[i] --[[@as DummyTile]]
        if tile:getData("sType") == "staticGemEnemy" then
            local hp = tile:getData("iHp") --[[@as number]]
            local score = tile:getData("iScore") --[[@as number]]
            local bounty = tile:getData("iBounty") --[[@as number]]
            local xp = tile:getData("iXp") --[[@as number]]
            local shape = tile:getData("sGemShape") --[[@as string]]

            if xp == nil then xp = 0 end
            if bounty == nil then bounty = 0 end
            if score == nil then score = 0 end
            if shape == nil then shape = "triangle" end

            local gem = Gem:new(tile, shape)
            StaticGemEnemies.gems[#StaticGemEnemies.gems + 1] = gem

            tile:setUserData(StaticGemEnemies.UDI_GEM, gem)

            local effectsStr = tile:getData("SonBreak") --[[@as java.lang.String]]
            if effectsStr ~= nil then
                local effectStrArr = effectsStr:split("\n")
                for j = 1, #effectStrArr do
                    local str = effectStrArr[j]:trim()
                    if str:len() ~= 0 then
                        local actionArr = str:split("\\|")
                        --local actionArr = {}
                        --for k = 1, #actionArrJava do
                        --    actionArr[k] = actionArrJava[k]
                        --end
                        local actionType = actionArr[1]
                        if StaticGemEnemies.gemActions[actionType] ~= nil then
                            table.insert(gem.effects, {
                                type = actionType,
                                args = actionArr
                            })
                        else
                            logger:w("gem action not recognized: " .. effectStrArr[j])
                        end
                    end
                end
            end

            local enemy = createEnemy(0, hp, score, bounty, xp)
            enemy.invisible:addReason("StaticGemEnemy")
            enemy.healthBarScale = 1.8
            enemy.ignorePathfinding = true
            if StaticGemEnemies.lowAimPriority then
                enemy.lowAimPriority:addReason("StaticGemEnemy")
            end
            enemy:setUserData(StaticGemEnemies.UDI_GEM, gem)

            enemy.color = tile.color
            enemy.size = CFG.TILE_SIZE * 0.35
            enemy.baseDamage = 0
            enemy:setPosition(gem.x * CFG.TILE_SIZE + CFG.TILE_HALF_SIZE, gem.y * CFG.TILE_SIZE + CFG.TILE_HALF_SIZE)

            --
            enemy:setTowerDamageMultiplier(C.TowerType.AIR, 0)
            enemy:setTowerDamageMultiplier(C.TowerType.CRUSHER, 0)
            enemy:setBuffVulnerability(C.BuffType.REGENERATION, 0)
            enemy:setBuffVulnerability(C.BuffType.FREEZING, 0)
            enemy:setBuffVulnerability(C.BuffType.SNOWBALL, 0)
            enemy:setBuffVulnerability(C.BuffType.THROW_BACK, 0)
            enemy:setBuffVulnerability(C.BuffType.STUN, 0)
            --enemy:setDamageVulnerability(enums.DamageType.LASER, false)
            --enemy:setSpecialDamageVulnerability(enums.SpecialDamageType.KILLSHOT, false)
            --enemy:setAbilityVulnerability(enums.AbilityType.BALL_LIGHTNING, false)
            --

            gem.enemy = enemy

            local enemyModScript = tile:getData("SEnemyModifiers") --[[@as string]]
            if enemyModScript ~= nil then
                local chunk = load(enemyModScript) --[[@as function]]
                local status, err = pcall(function () chunk(enemy, gem, tile) end)
                if not status then
                    logger:w("Failed to execute SEnemyModifiers on tile " .. tostring(tile), err)
                end
            end
        end
    end
end

--[[
Actually spawns the gem enemies, allowing to damage them and shows gem HP bars
--]]
StaticGemEnemies.spawnGemEnemies = function()
    for _, gem in ipairs(StaticGemEnemies.gems) do
        if not gem.enemySpawned then
            S.map:spawnEnemy(gem.enemy)
            gem.enemy:setPosition(gem.x * CFG.TILE_SIZE + CFG.TILE_HALF_SIZE, gem.y * CFG.TILE_SIZE + CFG.TILE_HALF_SIZE)
            gem.enemySpawned = true
        end
    end
end

--[[
Convenience method which allows to instantly destroy all gems at once.
Can be used to test the SonBreak / SAction gem configs.
--]]
--StaticGemEnemies.killAllGemEnemies = function()
--    for _, gem in ipairs(StaticGemEnemies.gems) do
--        if gem.enemySpawned then
--            TODO: use new method (queue)
--            S.enemy:killEnemy(gem.enemy, nil, DamageType.BULLET, nil, nil)
--        end
--    end
--end

--[[
Return the table which contains this script's configuration and "public" functions.
This allows to store the script's data in a single variable if imported by some other script.

For example, some of the regular maps use this script like that:
local StaticGemEnemies = dofile("scripts/misc/static-gem-enemies.lua")

This way their variable namespace is not polluted by the functions that are only needed inside of
this script and they can interact with it through the StaticGemEnemies local variable (or rename it
for convenience)

Pro tip: including files in this way (local a = dofile('a.lua')) basically stores whatever this
         script returns as a variable, and you can return anything you like this way, not only table.
         For example, you can return a function:
           a.lua:
           return function(foo, bar) ... end
         and use this script file in a cool way, immediately calling that function / configuring
         multiple instances of the same script:
           local a = dofile("a.lua")(1, 42)
           local b = dofile("a.lua")(9001, 1337)
--]]
return StaticGemEnemies