S.events:getListeners(C.SystemsPostSetup):add(C.Listener(function (_)
    _G.StaticGemEnemies = require "scripts.misc.static-gem-enemies"
    _G.StaticGemEnemies.start()
end))