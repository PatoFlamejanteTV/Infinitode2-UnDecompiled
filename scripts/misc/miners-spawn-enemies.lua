local MinersSpawnEnemies = {}
MinersSpawnEnemies.enabled = true
MinersSpawnEnemies.sharedWaveNumber = false
MinersSpawnEnemies.difficultyFormula = function(waveNumber) return S.gameState.averageDifficulty end
MinersSpawnEnemies.shouldEnemyBeSpawned = function(enemyGroup, enemyIdxInGroup) return true end -- if returns false, enemy won't be spawned but will be accounted as spawned (still increases wave difficulty)
MinersSpawnEnemies.shouldMinedResourceBeHandled = function(miner, resourceType, delta, mined) return true end -- if returns false, the mined resource event will be completely ignored (does not affect difficulty)
MinersSpawnEnemies.waveTemplatesPerResource = {
    [C.ResourceType.SCALAR:ordinal() + 1] = {  	"REGULAR_MEDIUM", 		"REGULAR_LOW", 	"TOXIC_MEDIUM", "TOXIC_ARMORED" }, -- "REGULAR_HIGH" "TOXIC_HIGH"
    [C.ResourceType.VECTOR:ordinal() + 1] = {  	"STRONG_MEDIUM", 		"STRONG_LOW",	"FAST_MEDIUM", 	"FAST_LOW", 	"HEALER_STRONG" }, -- "FAST_HIGH"
    [C.ResourceType.MATRIX:ordinal() + 1] = {  	"HELI_MEDIUM", 			"JET_MEDIUM",		"HEALER_JET", 		"ICY_HIGH", 			"ICY_TOXIC", 		"HEALER_ICY" },
    [C.ResourceType.TENSOR:ordinal() + 1] = {  	"ARMORED_LOW", 			"ARMORED_REGULAR",	"ARMORED_STRONG", 	"HEALER_REGULAR", 		"HEALER_SLOW", 		"FIGHTER_ARMORED" },
    [C.ResourceType.INFIAR:ordinal() + 1] = {  	"FIGHTER_LOW", 			"FIGHTER_MEDIUM",	"LIGHT_MEDIUM", 	"LIGHT_HIGH", 			"LIGHT_FAST" }
}

----

local templateIndices = {}
local enemyQueueWaves = {}
local sharedEnemyQueueWave = 1
local enemyQueue = {}

---@param resourceType ResourceType
---@return Enemy?
local getNextEnemyToSpawn = function(resourceType)
	local resTypeIdx = resourceType:ordinal() + 1
	if enemyQueue[resTypeIdx] == nil or #enemyQueue[resTypeIdx] == 0 then
		local queue = {}
		local waveNumber
		if MinersSpawnEnemies.sharedWaveNumber then
			waveNumber = sharedEnemyQueueWave
		else
			waveNumber = enemyQueueWaves[resTypeIdx]
		end
		if waveNumber == nil then
			waveNumber = 1
		end
		local templateIndex = templateIndices[resTypeIdx]
		if templateIndex == nil then templateIndex = 1 end
		--log(utils.print(MinersSpawnEnemies.waveTemplatesPerResource))
		local templates = MinersSpawnEnemies.waveTemplatesPerResource[resTypeIdx]
		local templateName = templates[templateIndex]
		templateIndex = templateIndex + 1
		if templateIndex == #templates + 1 then
			templateIndex = 1
		end
		templateIndices[resTypeIdx] = templateIndex
		local template = C.WaveTemplates[templateName]
		local wave = S.wave:generateWave(template, waveNumber, MinersSpawnEnemies.difficultyFormula(waveNumber))
		for i = 1, wave.enemyGroups.size do
			local group = wave.enemyGroups.items[i] --[[@as EnemyGroup]]
			for j = 1, group.count do
			    if MinersSpawnEnemies.shouldEnemyBeSpawned(group, j) then
                    local creep = C.Game.i.enemyManager:getFactory(group:getEnemyType()):obtain()
                    creep:setSpeed(group.speed)
                    creep.maxHealth = group.health
                    creep:setHealth(group.health)
                    creep.killScore = group.killScore
                    creep.bounty = group.bounty
                    creep:setKillExp(group.killExp)
                    table.insert(queue, #queue + 1, creep)
				end
			end
		end
		local randomSeed = 37
		for i = 1, #queue do
			local idx = S.gameState:randomIntIndependent(#queue, randomSeed) + 1
			randomSeed = (randomSeed * 31 + idx) % 65536
			local tmp = queue[idx]
			queue[idx] = queue[i]
			queue[i] = tmp
		end

		if MinersSpawnEnemies.sharedWaveNumber then
			sharedEnemyQueueWave = waveNumber + 1
		else
			enemyQueueWaves[resTypeIdx] = waveNumber + 1
		end
		enemyQueue[resTypeIdx] = queue

		-- log("Filled enemy queue for " .. resourceType:name() .. " with " .. templateName .. " (" .. #queue .. " enemies, wave " .. waveNumber .. ")")
	end

	return table.remove(enemyQueue[resTypeIdx], #enemyQueue[resTypeIdx])
end

MinersSpawnEnemies.start = function()
    S.events:getListeners(C.MinerResourceChange):addStateAffecting(C.Listener(function (e)
		---@cast e MinerResourceChange
        local miner = e:getMiner()
        local delta = e:getDelta()
        local resourceType = e:getResourceType()
        local mined = e:isMined()
        if MinersSpawnEnemies.shouldMinedResourceBeHandled(miner, resourceType, delta, mined) then
            if mined and MinersSpawnEnemies.enabled then
                for i = 1, delta do
                    local enemy = getNextEnemyToSpawn(resourceType)
                    if enemy ~= nil then
                        S.enemy:addEnemyWithFirstSpawn(enemy, miner:getTile(), S.gameState:randomInt(11))
                    end
                end
            end
        end
    end))
end

return MinersSpawnEnemies