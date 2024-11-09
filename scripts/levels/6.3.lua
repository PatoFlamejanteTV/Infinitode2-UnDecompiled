local MinersSpawnEnemies = require "scripts.misc.miners-spawn-enemies"

local bossHpMultiplier = 2500
local bossMinSpeed = 0.025
local bossMaxSpeed = 0.08

local aimTargetResetCounter = 1

MinersSpawnEnemies.sharedWaveNumber = true

S.events:getListeners(C.SystemsPostSetup):add(C.Listener(function (_)
	---@diagnostic disable-next-line: duplicate-set-field
	MinersSpawnEnemies.shouldMinedResourceBeHandled = function(miner, resourceType, delta, mined)
		if S.gameState.difficultyMode == C.DifficultyMode.NORMAL then
			-- do not affect enemy spawn rate for regular mode to keep leaderboards fair
			return true
		else
			-- endless / easy mode - limit the amount of enemies to reduce lag
			-- do not worry about the loot - there will be enough enemies to put the loot into, amount of enemies do not affect the actual loot drop rate
			if S.map.spawnedEnemies.size < 1000 then
				return true
			else
				-- limit to ~4,000 enemies - should only happen with lots of overloads
				return S.gameState:randomFloat() > ((S.map.spawnedEnemies.size - 1000) ^ 0.75) * 0.00232
			end
		end
	end
	MinersSpawnEnemies.start()

	-- Reset tower targets
	local lastDamagePerTower = {} -- tower.id -> damage
	local perTowerUpdateNum = {}

	S.events:getListeners(C.GameStateTick):addStateAffecting(C.Listener(function(_)
		if S.tower.towers.size < aimTargetResetCounter then
			aimTargetResetCounter = 1
		end

		if S.tower.towers.size ~= 0 then
			local tower = S.tower.towers.items[aimTargetResetCounter] --[[@as Tower]]
			local towerTarget = tower:getTarget()
			local lastDamage = lastDamagePerTower[tower.id]
			local towerUpdateNum = perTowerUpdateNum[tower.id]
			if lastDamage == nil then lastDamage = 0 end
			if towerUpdateNum == nil then towerUpdateNum = 0 end

			if towerTarget ~= nil and (towerTarget.type == C.EnemyType.SNAKE_BOSS_HEAD or towerTarget.type == C.EnemyType.SNAKE_BOSS_BODY or towerTarget.type == C.EnemyType.SNAKE_BOSS_TAIL) then
				if lastDamage ~= tower.damageGiven or S.gameState.updateNumber - towerUpdateNum > 30 then
					-- Has dealt some damage since the last search or 30 frames passed
					lastDamagePerTower[tower.id] = tower.damageGiven
					perTowerUpdateNum[tower.id] = S.gameState.updateNumber
					local newTarget = tower:findTarget()
					if towerTarget ~= newTarget then
						tower:setTarget(newTarget)
					end
				end
			end
		end
		aimTargetResetCounter = aimTargetResetCounter + 1
	end))

	S.events:getListeners(C.EnemyDie):addStateAffecting(C.Listener(function(event)
		---@cast event EnemyDie
		local record = event:getLastDamage()
		local enemy = record:getEnemy()
		if enemy.type == C.EnemyType.SNAKE_BOSS_HEAD then
			MinersSpawnEnemies.enabled = false

			local bonusScore = math.floor(S.gameState:getScore() * 0.2)
			S.gameState:addScore(bonusScore, C.StatisticsType.SG_EK)
		end
	end))

	S.events:getListeners(C.EnemyReachTarget):addStateAffecting(C.Listener(function(event)
		---@cast event EnemyReachTarget
		if event:getEnemy().type == C.EnemyType.SNAKE_BOSS_HEAD then
			MinersSpawnEnemies.enabled = false
		end
	end))

	S.events:getListeners(C.EnemySpawn):addStateAffecting(C.Listener(function(event)
		---@cast event EnemySpawn
		local enemy = event:getEnemy()
		if C.SnakeBossHeadEnemy:_isInstance(enemy) or C.SnakeBossBodyEnemy:_isInstance(enemy) or C.SnakeBossTailEnemy:_isInstance(enemy) then
			enemy:setMaxHealth(enemy.maxHealth * bossHpMultiplier)
			enemy:setHealth(enemy:getHealth() * bossHpMultiplier)

			if C.SnakeBossHeadEnemy:_isInstance(enemy) then
				---@cast enemy SnakeBossHeadEnemy
				enemy.defaultMinSpeed = bossMinSpeed
				enemy.defaultMaxSpeed = bossMaxSpeed
			end
		end
	end))
end))
