--- -------------------------- /!\ -------------------------
--- This script makes some of the previously available features backwards compatible with version 1.9.0.
--- Do not use anything from this script as it is obsolete. Please read the comments to find a way to refactor your old
--- scripts. This file may be removed in the later versions of the game (probably 1.10)
--- -------------------------- /!\ -------------------------

------------------------------------------------------------
--- Class namespaces
------------------------------------------------------------
--- These constants are usually only used for the import* functions or LuaJava stuff.
--- Since Lua now has full access to the class tree directly through the "com" and "java" global
--- tables, use them instead as they will also provide VSCode suggestions out of the box.
--- You can find all namespaces in scripts/.definitions/classes folder and they should be
--- automatically discovered by VSCode.
--- Examples:
---     Old version: luajava.createProxy(GNS .. "systems.WaveSystem$WaveSystemListener", {...
---     New version: luajava.createProxy(com.prineside.tdi2.systems.WaveSystem_WaveSystemListener.class, {...
---
---     Old version: local ItemStack = import("ItemStack")
---     New version: local ItemStack = com.prineside.tdi2.ItemStack.class
---
--- Note: you don't have to write the whole path to the class each time. Parts of the class tree
--- can be stored in a separate veriable (which is preserved when player continues the game), for
--- example:
---     local ItemStack = com.prineside.tdi2.ItemStack.class
---         is equal to
---     local tdi = com.prineside.tdi2
---     local ItemStack = tdi2.ItemStack.class
--- 
--- Remember that `ClassName.class` is a real Java object of a class and it exists on the class tree
--- while a simple `ClassName` is just a type hint for your text editor.
--- If you want to store a Java class in a variable, use `.class` suffix on it. If you want to give
--- your text editor a hint on some variable (--[[@as ...]] or ---@cast ...), use its name without a `.class`

--- Game's package namespace
--- @type string
--- @deprecated
GNS = "com.prineside.tdi2."


--- LibGDX package namespace
--- @type string
--- @deprecated
GDXNS = "com.badlogic.gdx."

------------------------------------------------------------
--- Global variables
------------------------------------------------------------

--- Game configuration (things like font sizes and stuff)
--- Access this class directly, just like it is shown below
--- @deprecated
CFG = com.prineside.tdi2.Config.class

--- Enums (com.prineside.tdi2.enums.*)
--- Access enums directly from the class tree, for example:
---     Old version: enums.EnemyType.FAST
---     New version: com.prineside.tdi2.enums.EnemyType.class.FAST
---                     or
---                  local EnemyType = com.prineside.tdi2.enums.EnemyType.class
---                  EnemyType.FAST ...
local enumNames = {
    "AbilityType",
    "BossTileType",
    "BuffType",
    "BuildingType",
    "DamageType",
    "DifficultyMode",
    "EnemyType",
    "ExplosionType",
    "GameValueType",
    "GateType",
    "ItemType",
    "MinerType",
    "ModifierType",
    "ProjectileType",
    "ResourceType",
    "PredefinedCoreTileType",
    "SpaceTileBonusType",
    "SpecialDamageType",
    "StaticSoundType",
    "StatisticsType",
    "TileType",
    "TowerStatType",
    "TowerType"
};
--- @deprecated
_G.enums = {}
for _, v in pairs(enumNames) do
---@diagnostic disable-next-line: deprecated
    _G.enums[v] = com.prineside.tdi2.enums[v].class
end

--- Global "reflection" table has been removed - use java.reflect.* classes and java.Class methods directly on the class
--- objects.

--- Global "reg" variable has also been removed as the game no longer uses that implementation of registry.
--- I'm still going to replace those constant enums with something more flexible and moddable...

------------------------------------------------------------
--- Global "managers" table
------------------------------------------------------------
-- Use com.prineside.tdi2.Game.i.[asset]Manager fields instead
-- If you want to access different managers frequently, you can simply do something like this:
-- Example:
--    local Game = com.prineside.tdi2.Game.class
--    Game.i.assetManager:getQuad("abc")
--    Game.i.towerManager:getFactory(com.prineside.tdi2.enums.TowerType.BASIC)
--    (Note: I've used Game class instead of Game.i object, because classes are serializable and Game object is not)

---@deprecated
_G.managers = {}
local managerArray = com.prineside.tdi2.Game.class.i.managers
for i = 1, managerArray.size do
    local manager = managerArray.items[i] --[[@as com.prineside.tdi2.Manager]]
    ---@diagnostic disable-next-line: deprecated
    _G.managers[manager:getClass():_getSimpleName()] = manager
end
---@diagnostic disable-next-line: deprecated
_G.managers._noSyncCheck = true

------------------------------------------------------------
--- Logging
------------------------------------------------------------
--- These functions were used to log messages (to the console and the log file).
--- They do not allow to set a custom tag or log level, thus are deprecated.
--- A new way of logging stuff is to create an individual logger per script:
---     local logger = com.prineside.tdi2.utils.logging.TLog.class:forTag("My script")
---     logger:i("Some info")
---     logger:d("Value of deltaTime: %s", 127)

--- Writes to the console and the file log
--- @param ... any
--- @deprecated
--- @return nil
function _G.log(...)
    local msg = ""
    for k, v in ipairs({...}) do
        if k ~= 1 then msg = msg .. " " end
        msg = msg .. tostring(v)
    end
    C.TLog:forTag("Script"):i(msg)
end

--- Writes a warning to the console and the file log
--- @param ... any
--- @deprecated
--- @return nil
function _G.warning(...)
    local msg = ""
    for k, v in ipairs({...}) do
        if k ~= 1 then msg = msg .. " " end
        msg = msg .. tostring(v)
    end
    C.TLog:forTag("Script"):w(msg)
end

------------------------------------------------------------
--- Event handling
------------------------------------------------------------
--- I don't really remember how it has been implemented in 1.8.10 so there may be errors in this section.
--- Previously Lua scripts had some kind of a "special" events which you could listen with 
--- `addEventHandler` and `removeEventHandler`
--- Since 1.9.0, almost all events go through Game.class.EVENTS or S.events, see docs and default scripts
--- for usage example.
--- @deprecated
_G.addEventHandler = function() error("deprecated, use Game.class.EVENTS and S.events instead") end

--- @deprecated
_G.removeEventHandler = function() error("deprecated, use Game.class.EVENTS and S.events instead") end

------------------------------------------------------------
--- Fields available only during the game - not available for global scripts
------------------------------------------------------------

--- Current instance of system provider, renamed from SP (I use S in Java all the time)
---@type com.prineside.tdi2.GameSystemProvider
_G.S = nil