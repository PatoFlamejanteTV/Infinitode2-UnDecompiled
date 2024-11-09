S.events:getListeners(C.SystemsStateRestore):addStateAffecting(C.Listener(function (event)
    C.TLog:forTag("serialization_test.lua"):d("SystemsStateRestore listener called", event)
end))

local multiProxy = luajava.createProxy(C.Listener, C.ObjectSupplier, {
    get = function(self)
        return "Supplied string"
    end,

    handleEvent = function(self, event)
        C.TLog:forTag("serialization_test.lua"):d("SystemsStateRestore multy proxy listener called", event)
        assert(self:get() == "Supplied string")

        assert(C.Listener:_isInstance(self.this))
        assert(C.ObjectSupplier:_isInstance(self.this))
    end
})

assert(C.Listener:_isInstance(multiProxy))
assert(C.ObjectSupplier:_isInstance(multiProxy))

---@cast multiProxy ObjectSupplier
assert(multiProxy:get() == "Supplied string")

---@cast multiProxy Listener
S.events:getListeners(C.SystemsStateRestore):addStateAffecting(multiProxy)