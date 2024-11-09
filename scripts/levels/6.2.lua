S.events:getListeners(C.SystemsPostSetup):add(C.Listener(function (_)
    _G.StaticGemEnemies = require "scripts.misc.static-gem-enemies"
    _G.StaticGemEnemies.start()
end))

_G.configureGemEnemy = function(enemy)
    for i = 1, #C.TowerType.values do
        enemy:setTowerDamageMultiplier(C.TowerType.values[i], 0)
    end

    for i = 1, #C.AbilityType.values do
        enemy:setAbilityVulnerability(C.AbilityType.values[i], false)
    end

    enemy:setTowerDamageMultiplier(C.TowerType.GAUSS, 1)
    enemy:setSpecialDamageVulnerability(C.SpecialDamageType.NANOPARTICLES, false)
end