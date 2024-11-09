local logger = C.TLog:forTag("global/controllers.lua")

if C.Gdx.app:getType():name() ~= "Desktop" then
    return logger:w("Controllers are only available on Desktop. Maybe Android too, but definitely not on iOS")
end

C.Controllers:addListener(C.ControllerListener({
    connected = function (c)
        logger:d("Controller connected: %s", c:getUniqueId())
    end,

    disconnected = function (c)
        logger:d("Controller disconnected: %s", c:getUniqueId())
    end,

    buttonDown = function (c, btnCode)
        logger:d("Controller buttonDown: %s, %s", c:getUniqueId(), btnCode)
        return true
    end,

    buttonUp = function (c, btnCode)
        logger:d("Controller buttonUp: %s, %s", c:getUniqueId(), btnCode)
        return true
    end,

    axisMoved = function (c, axisCode, value)
        if value < -0.1 or value > 0.1 then
            logger:d("Controller axisMoved: %s, %s, %s", c:getUniqueId(), axisCode, value)
        end
        return true
    end
}))

logger:d("List of connected controllers:")
local controllers = C.Controllers:getControllers()
for i = 0, controllers.size - 1 do
    local c = controllers:get(i) --[[@as Controller]]
    logger:d("- %s / %s", c:getName(), c:getUniqueId())
end