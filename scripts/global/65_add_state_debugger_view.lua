if C.Config:isHeadless() then return nil end

-- Minimal view implementation
local view = C.StateDebugger.View({
    getId = function (self)
        return "MY_SIMPLE_VIEW"
    end,

    getName = function (self)
        return "Simple view"
    end,

    -- rebuildWindow = function(self)
    -- end,

    -- init = function (self)
    -- end,

    -- postInit = function (self)
    -- end,

    -- onShow = function(self)
    -- end,

    -- onHide = function (self)
    -- end,

    onRender = function (self)
        -- Retrieving GameSystemProvider
        local S = nil --[[@as GameSystemProvider?]]
        if C.GameScreen:_isInstance(C.Game.i.screenManager:getCurrentScreen()) then
            -- On GameScreen
            local gameScreen = C.Game.i.screenManager:getCurrentScreen() --[[@as GameScreen]]
            if not gameScreen.S:isDisposed() then
                S = gameScreen.S
            end
        else
            -- On any other screen
            self.S = nil
        end

        -- Rebuilding the UI layout - each frame in this example
        local contentTable = C.StateDebugger:i().contentTable
        contentTable:clear()

        -- Updating the UI
        if S then
            local label = C.Label.new("State found, tick number: " .. tostring(S.state.updateNumber), C.Game.i.assetManager:getLabelStyle(C.Config.FONT_SIZE_X_SMALL))
            contentTable:add(label):grow()
        else
            local label = C.Label.new("Game not running", C.Game.i.assetManager:getLabelStyle(C.Config.FONT_SIZE_X_SMALL))
            contentTable:add(label):grow()
        end

        -- Make the window fit its contents (when needed)
        -- C.StateDebugger:i().window:fitToContent(C.Align.bottomLeft, true, false, true)
    end
})
-- C.StateDebugger:i():registerView(view)











-- Slightly more complex implementation

---@param table Table
---@param title CharSequence|string
local addTableRowSeparator = function(table, title)
    local label = C.Label.new(title, C.Game.i.assetManager:getLabelStyle(C.Config.FONT_SIZE_X_SMALL))
    table:add(label):colspan(2):growX():row()
end

---@param table Table
---@param fieldName CharSequence|string
---@return Label
local addTableRow = function(table, fieldName)
    local nameLabel = C.Label.new(fieldName, C.Game.i.assetManager:getLabelStyle(C.Config.FONT_SIZE_X_SMALL))
    nameLabel:setColor(1,1,1,0.56)
    table:add(nameLabel):fillX():padRight(8)

    local valueLabel = C.Label.new("", C.Game.i.assetManager:getLabelStyle(C.Config.FONT_SIZE_X_SMALL))
    table:add(valueLabel):growX():row()

    return valueLabel
end

C.StateDebugger:i():registerView(C.StateDebugger.View({
    lastFrameHash = -1,

    labels = {
        gameState = {
            playRealTime = nil,
            updateNumber = nil,
            pxpLastActionFrame = nil,
            gameRealTimePasses = nil,
        },
        _input = {
            zoom = nil,
        }
    },

    --

    getId = function (self)
        return "GENERAL_INFO_VIEW"
    end,

    getName = function (self)
        return "General info"
    end,

    rebuildWindow = function(self)
        self.lastFrameHash = -1
    end,

    onRender = function (self)
        -- Retrieving GameSystemProvider
        local S = nil --[[@as GameSystemProvider?]]
        if C.GameScreen:_isInstance(C.Game.i.screenManager:getCurrentScreen()) then
            -- On GameScreen
            local gameScreen = C.Game.i.screenManager:getCurrentScreen() --[[@as GameScreen]]
            if not gameScreen.S:isDisposed() then
                S = gameScreen.S
            end
        else
            -- On any other screen
            self.S = nil
        end

        -- Calculating UI state hash
        -- It is just a number which corresponds to some specific UI layout. If hash differs from the previous frame, the
        -- UI layout has to be rebuilt
        local hash = 1
        if S then
            hash = hash * 31 + 1
            if S.CFG.headless then
                hash = hash * 31 + 1
            end
        end

        if self.lastFrameHash ~= hash then
            -- Rebuilding UI layout
            self.lastFrameHash = hash

            local contentTable = C.StateDebugger:i().contentTable
            contentTable:clear()

            if S then
                -- Fully-fledged UI
                local table = C.Table.new()
                contentTable:add(table):grow()

                addTableRowSeparator(table, "GameState") ------------------------------
                -- Some static fields
                addTableRow(table, "averageDifficulty"):setText(tostring(S.gameState.averageDifficulty))
                addTableRow(table, "basicLevelName"):setText(tostring(S.gameState.basicLevelName))
                addTableRow(table, "difficultyMode"):setText(tostring(S.gameState.difficultyMode))

                -- Dynamic fields
                self.labels.gameState.playRealTime = addTableRow(table, "playRealTime")
                self.labels.gameState.gameRealTimePasses = addTableRow(table, "isGameRealTimePasses")
                self.labels.gameState.updateNumber = addTableRow(table, "updateNumber")
                self.labels.gameState.pxpLastActionFrame = addTableRow(table, "getPxpLastActionFrame")

                if not S.CFG.headless then
                    -- Not in headless mode = more systems
                    addTableRowSeparator(table, "Input") ------------------------------
                    self.labels._input.zoom = addTableRow(table, "zoom")
                end

                table:row()
                table:add():width(1):growY():row()
            else
                -- Just a label telling that S not found
                local label = C.Label.new("Game not running", C.Game.i.assetManager:getLabelStyle(C.Config.FONT_SIZE_X_SMALL))
                contentTable:add(label):grow()
            end

            C.StateDebugger:i().window:fitToContent(C.Align.bottomLeft, true, false, true)
        end

        -- Updating the UI without layout changes
        if S then
            self.labels.gameState.playRealTime:setText(C.StringFormatter:compactNumberWithPrecision(S.gameState.playRealTime, 3))
            self.labels.gameState.updateNumber:setText(tostring(S.gameState.updateNumber))
            self.labels.gameState.pxpLastActionFrame:setText(tostring(S.gameState:getPxpLastActionFrame()))
            if S.gameState:isGameRealTimePasses() then
                self.labels.gameState.gameRealTimePasses:setColor(C.MaterialColor.LIGHT_GREEN.P500)
                self.labels.gameState.gameRealTimePasses:setText("Yes")
            else
                self.labels.gameState.gameRealTimePasses:setColor(C.MaterialColor.AMBER.P500)
                self.labels.gameState.gameRealTimePasses:setText("No")
            end
            

            if not S.CFG.headless then
                self.labels._input.zoom:setText(C.StringFormatter:compactNumberWithPrecision(S._input:getCameraController().zoom, 2))
            end
        end
    end
}))