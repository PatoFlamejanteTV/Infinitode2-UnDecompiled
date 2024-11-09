local logger = C.TLog:forTag("enemy_path_test")

local Path = com.prineside.tdi2.pathfinding.Path.class

local path = {
    { 5, 3 },
    { 4, 3 },
    { 3, 3 },
    { 2, 3 },
    { 2, 2 }, -- loop
    { 1, 2 }, --
    { 1, 3 }, --
    { 2, 3 }, --
    { 2, 4 },
    { 2, 5 },
    { 2, 6 },
    { 2, 7 },
    { 2, 8 },
    { 2, 9 },
    { 3, 9 },
    { 4, 9 },
    { 5, 9 },
    { 6, 9 },
    { 6, 10 }, -- loop
    { 5, 10 }, --
    { 4, 10 }, --
    { 4, 9 }, --
    { 5, 9 }, --
    { 6, 9 }, --
    { 7, 9 },
    { 8, 9 },
    { 8, 8 },
    { 8, 7 },
    { 8, 6 }, -- loop outside of map
    { 9, 6 }, --
    { 10, 6 }, --
    { 11, 6 }, --
    { 12, 6 }, --
    { 13, 6 }, --
    { 14, 6 }, --
    { 15, 6 }, --
    { 16, 6 }, --
    { 16, 5 }, --
    { 15, 5 }, --
    { 14, 5 }, --
    { 13, 5 }, --
    { 12, 5 }, --
    { 11, 5 }, --
    { 10, 5 }, --
    { 9, 5 }, --
    { 8, 5 },
    { 8, 4 },
    { 8, 3 },
    { 7, 3 },
    { 6, 3 },
    { 5, 3 }
}
local pathConnectionMoveSide = C.MoveSide.RIGHT_LEFT

-- Create path object
local nodes = {}
local nodeIdx = 0
for _, n in pairs(path) do
    local node = C.HeavyPathNode.new()
    node:setup(nodeIdx, n[1], n[2], 1)
    table.insert(nodes, node)
    nodeIdx = nodeIdx + 1
end

local defaultPath = Path.new_HPNArr(nodes)
defaultPath = defaultPath:copyWithCustomMoveSides({0, pathConnectionMoveSide, defaultPath:getCount() - 1, pathConnectionMoveSide})

-- Listen for enemyReachedTarget
S.events:getListeners(C.EnemyReachTarget):addStateAffecting(C.Listener(function (event)
    ---@cast event EnemyReachTarget
    local e = event:getEnemy()
    if e:getUserData("testsCustomPath") then
        e.passedTiles = e.passedTiles - defaultPath:getCount() + 1
        event:setCancelled(true)
    end
end))

S.events:getListeners(C.SystemsPostSetup):addStateAffecting(C.Listener(function (_)
    local waveStartListener
    waveStartListener = C.Listener(function(_)
        local enemyTypes = {
            C.EnemyType.REGULAR,
            C.EnemyType.FAST,
            C.EnemyType.STRONG,
            C.EnemyType.HELI,
            C.EnemyType.ARMORED,
            C.EnemyType.FIGHTER,
            C.EnemyType.HEALER,
            C.EnemyType.ICY,
            C.EnemyType.JET,
            C.EnemyType.LIGHT,
            C.EnemyType.TOXIC,
            C.EnemyType.REGULAR,
            C.EnemyType.FAST,
            C.EnemyType.STRONG,
            C.EnemyType.HELI,
            C.EnemyType.ARMORED,
            C.EnemyType.FIGHTER,
            C.EnemyType.HEALER,
            C.EnemyType.ICY,
            C.EnemyType.JET,
            C.EnemyType.LIGHT,
            C.EnemyType.TOXIC
        }

        local interval = defaultPath:getCount() / #enemyTypes
        for sideIdx = 0, 10, 1 do
            for groupIdx, enemyType in pairs(enemyTypes) do
                local enemy = C.Game.i.enemyManager:getFactory(enemyType):obtain()
                enemy:setSpeed(2)
                enemy.maxHealth = 10000
                enemy:setHealth(10000)
                enemy.killScore = 1000
                enemy.bounty = 1000
                enemy:setKillExp(1000)
                enemy.ignorePathfinding = true
                enemy.ignoredByAutoWaveCall = true
                enemy:setUserData("testsCustomPath", true)
                S.enemy:addEnemyWithPath(
                    enemy,
                    S.map:getMap():getTilesByType(C.SpawnTile):first() --[[@as SpawnTile]],
                    defaultPath,
                    sideIdx,
                    nil,
                    (groupIdx -1) * interval
                )

                S.events:getListeners(C.WaveStart):remove(waveStartListener)
            end
        end
    end)
    S.events:getListeners(C.WaveStart):addStateAffecting(waveStartListener)
end))
