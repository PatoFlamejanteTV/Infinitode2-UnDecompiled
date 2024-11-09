---@diagnostic disable: lowercase-global
-- This script can be run to check if my optimizations did not break the VM and to make sure Lua VM works in the same way on all platforms.
-- It also shows how to interact with Java's structures.

local ___tl = function(...)
    print("|", ...)
    -- log("|", ...)
end

local function set_quota(secs)
    local st=os.clock()
    function check()
        if os.clock()-st > secs then
            debug.sethook() -- disable hooks
            error("quota exceeded")
        end
    end
    debug.sethook(check,"",100000);
end
-- set_quota(5) -- limit execution time

___tl("== Tests started ==")
___tl("Warning: it may take a couple of minutes, do not close the game")

___tl("Check default log / warning functions work as expected")

local tst = com.prineside.tdi2.utils.luaTests

local logger = com.prineside.tdi2.utils.logging.Logger.class:forTag("Test")
logger:i("Calling log directly")
logger:d("Logger: debug")
logger:i("Logger: info")
logger:w("Logger: warning")
logger:e("Logger: error")

local dMethod = logger.d
dMethod(logger, "Logger: debug using method object %s", "successful")

local tdi = com.prineside.tdi2

___tl("Check inner class paths")
assert(tst.TestClassWithSubclass.class.TestSubclass == tst.TestClassWithSubclass_TestSubclass.class)

___tl("Check interface class is an interface")
local TestFunctionalInterface = tst.TestFunctionalInterface.class
assert(TestFunctionalInterface:_isInterface())

___tl("Check calling Class methods without a _ prefix fails")

---@diagnostic disable-next-line: undefined-field
assert(not pcall(function () TestFunctionalInterface:isInterface() end))

___tl("Check functional interface proxy creation")
local supplierFunction = function(val) return "Got " .. tostring(val) end
local supplier = TestFunctionalInterface(supplierFunction)
___tl(supplier)
assert(supplier ~= nil)

___tl("Check our new proxy has correct interface type")
___tl("-- Proxy class: " .. tostring(supplier:getClass()))
assert(TestFunctionalInterface:_isAssignableFrom(supplier:getClass())) -- supplier is Proxy and not an TestFunctionalInterface, because object can not have interface as a class

___tl("Check proxy instance works as expected")
assert(supplier:doStuff("something") == "Got something")

___tl("Check regular object tostring() works as expected")
___tl(tst.TestClass.class.SINGLETON)

___tl("Check class tostring() works as expected")
___tl(tst.TestClass.class)

___tl("Check class static fields are accessible")
___tl(tst.TestClass.class.SOME_STATIC_VAR)
assert(tst.TestClass.class.SOME_STATIC_FINAL_VAR == 42)

___tl("Check object method invokation")
local obj = tst.TestClass.class.SINGLETON
assert(obj:getSomeField() == 9001)

___tl("Check Class.class methods")
___tl(tst.TestClass.class:_getName())

___tl("Check Class.class methods for annotation discovery")
assert(tst.TestClass.class:_isAnnotationPresent(tst.TestAnnotationRuntimeRetention.class))
___tl("- Class time annotations: " .. tostring(tst.TestClass.class:_isAnnotationPresent(tst.TestAnnotationClassRetention.class)))

___tl("Check regular class is not an interface")
assert(not tst.TestClass.class:_isInterface())

___tl("Check calling instance method on a class directly fails (IDE will not bark on it)")
assert(not pcall(function () tst.TestClass:getSomeField() end))

___tl("Check proxying an interface with multiple methods and tricky method names")
local complexProxy = tst.TestComplexInterface.class({
    -- Note: a field called "this" will be added to the interface proxy, which contains a Java instance of this proxy
    --       this is needed because some methods may need the actual instance of proxy and not just "self" which is just a Lua table.
    dataField = "It's a me",

    _M_end = function(self, testTrickyName)
        ___tl("end called, " .. self.dataField .. ", " .. tostring(testTrickyName) .. ", this: " .. tostring(self.this))
    end,

    getSomeInt = function(self, someOtherInt)
        ___tl("getSomeInt called, " .. self.dataField .. ", " .. tostring(someOtherInt) .. ", this: " .. tostring(self.this))
        return 99 + someOtherInt
    end,

    getSomeString = function(self)
        ___tl("getSomeString called, " .. self.dataField)
        self.dataField = self.dataField .. ", Mario!"
        return "response from " .. self.dataField
    end,
})
___tl(complexProxy)
assert(complexProxy ~= nil)

___tl("Check complex proxy has a proper interface type")
assert(tst.TestComplexInterface.class:_isAssignableFrom(complexProxy:getClass()))

___tl("Check complex proxy method calls")
assert(complexProxy:_M_end("someArg") == nil)
assert(complexProxy:getSomeInt(5) == 99 + 5)
assert(complexProxy:getSomeString() == "response from It's a me, Mario!")
assert(complexProxy:getSomeString() == "response from It's a me, Mario!, Mario!")

___tl("Check proxy creation for a multiple interfaces")
-- Functions documentation directly copied from the interface docs
local multiProxy = luajava.createProxy(tst.TestComplexInterface.class, tst.TestFunctionalInterface.class, {
    proxyField = 51,

    -- TestComplexInterface

    --- @param testTrickyName java.lang.String|string
    --- @return nil
    _M_end = function(self, testTrickyName)
        ___tl("end called, " .. self.proxyField .. ", " .. tostring(testTrickyName))
    end,

    --- @param someOtherInt number (int)
    --- @return number (int)
    getSomeInt = function(self, someOtherInt)
        ___tl("getSomeInt called, " .. self.proxyField .. ", " .. tostring(someOtherInt))
        return self.proxyField - someOtherInt
    end,

    --- @return java.lang.String
    getSomeString = function(self)
        ___tl("getSomeString called, " .. self.proxyField)
        return "banana " .. self:getSomeInt(-5)
    end,

    -- TestFunctionalInterface

    --- @param value? java.lang.String|string
    --- @return java.lang.String|string
    doStuff = function(self, value)
        ___tl("doStuff called, " .. self.proxyField .. " " .. tostring(value))
        return "the stuff " .. tostring(value)
    end,
})
___tl(multiProxy)
assert(multiProxy ~= nil)

___tl("Check proxy has correct interfaces")
assert(tst.TestComplexInterface.class:_isAssignableFrom(multiProxy:getClass()))
assert(tst.TestFunctionalInterface.class:_isAssignableFrom(multiProxy:getClass()))

-- Can't cast to both interfaces at once
--- @cast multiProxy TestComplexInterface
multiProxy:_M_end("I1 works")
assert(multiProxy:getSomeString() == "banana 56")

--- @cast multiProxy TestFunctionalInterface
assert(multiProxy:doStuff("is done") == "the stuff is done")

___tl("Check constructors and object methods of the freshly created objects")
obj = tst.TestClass.class.new_i(1000)
assert(obj ~= nil)
assert(obj:getSomeField() == 1000)
assert(obj.someField == 1000)
obj.someField = obj.someField * 2
assert(obj.someField == 2000)
assert(obj:getSomeField() == 2000)

___tl("Check accessing fields and methods with _F_ and _M_ prefixes")
---@diagnostic disable-next-line: undefined-field
assert(obj._F_someField == 2000)
---@diagnostic disable-next-line: undefined-field
assert(obj:_M_getSomeField() == 2000)

___tl("Check accessing static fields of classes")
tst.TestClass.class.SOME_STATIC_VAR = 55
assert(tst.TestClass.class.SOME_STATIC_VAR == 55)

___tl("Check setting final fields fails")
assert(not pcall(function () tst.TestClass.class.SOME_STATIC_FINAL_VAR = 999 end))

___tl("Check primitive classes")
local intClass = luajava.bindClass("int")
assert(java.int == intClass)
___tl(intClass)
assert(intClass:_isPrimitive())

___tl("Check creation of primitive arrays and passing Classes as method parameters")
local intArray = java.lang.reflect.Array.class:newInstance_C_i(intClass, 10)
___tl(intArray)
assert(#intArray == 10)
assert(intArray[1] == 0)
intArray[1] = 5
assert(intArray[1] == 5)
intArray[2] = 7
local sum = 0
for i = 1, 10 do
    sum = sum + intArray[i]
end
assert(sum == 12)
___tl(intArray:getClass())
assert(intArray:getClass():_isArray())

___tl("Check creation of multidimensional arrays")
local twoDimArr = java.lang.reflect.Array.class:newInstance_C_iArr(intClass, 2, 3)
___tl(twoDimArr)
___tl(#twoDimArr)
___tl(#twoDimArr[1])
assert(#twoDimArr == 2)
assert(#twoDimArr[1] == 3)
twoDimArr[1][2] = 5
assert(twoDimArr[1][2] == 5)
assert(intArray:getClass():_isArray())

___tl("Check array class types")
local intArrayClassName = intArray:getClass():_getName()
___tl("  int array class name: " .. intArrayClassName) -- [I

local intArrayClass = luajava.bindClass("[I") -- int[]
assert(intArray:getClass() == intArrayClass)

local intMdArrayClass = luajava.bindClass("[[I") -- int[][]
assert(twoDimArr:getClass() == intMdArrayClass)

assert(intMdArrayClass:_getComponentType() == intArrayClass)

___tl("Check interfaces with default methods")
local TIWD = tdi.utils.luaTests.TestInterfaceWithDefaults.class
local proxyA = TIWD({
    mult = 3,

    getIntMultipliedByTwo = function (self, value)
        ___tl("getIntMultipliedByTwo called, " .. self.mult .. ", " .. value .. " " .. tostring(self.this))
        return value * self.mult
    end,

    -- This method is "default" in Java, which is properly supported only on PC. Android and iOS (probably) "desugar" it into some utility
    -- class with a static method which we can't easily access. To keep things simple, default methods must be defined in proxes always and they
    -- will not run that default code.
    -- If some of the default methods has a complex implementation and you don't want to rewrite it in Lua, look for the "Defaults" sub-class
    -- of an interface you want to implement - maybe it has a static method which contains the actual implementation of this default method.
    getAsStringDefaultMethod = function (self, intValue)
        return TIWD.Defaults:getAsStringDefaultMethod(self.this, intValue) -- return "value as string: " + obj.getIntMultipliedByTwo(intValue);
        -- Of course you can write your own implementation here too
    end
})
assert(proxyA ~= nil)
assert(proxyA:getIntMultipliedByTwo(5) == 15)
assert(proxyA:getAsStringDefaultMethod(3) == "value as string: 9")

___tl("Check whitelist works")
---@diagnostic disable-next-line: undefined-field
assert(not pcall(function () tst.TestClass.class.SINGLETON:thisMethodIsBlacklisted() end)) -- Interface method, blacklisted
---@diagnostic disable-next-line: undefined-field
assert(pcall(function () tst.TestClass.class.SINGLETON:thisMethodIsWhitelisted() end)) -- Interface method, whitelisted in the interface but not in the TestClass itself
---@diagnostic disable-next-line: inject-field
assert(not pcall(function () tst.TestClass.class.SOME_BLACKLISTED_STATIC_FIELD = 1 end)) -- Static field, blacklisted
assert(pcall(function () tst.TestClass.class.SOME_STATIC_VAR = 1337 end))
---@diagnostic disable-next-line: inject-field
assert(not pcall(function () tst.TestClass.class.SINGLETON.someBlacklistedField = "test" end)) -- Field, blacklisted
assert(pcall(function () tst.TestClass.class.SINGLETON.someField = 9001 end))
-- assert(not pcall(function () tst.TestClass.class.new("abc") end)) -- Constructor, blacklisted (not works because Lua guesses to use (int) constructor as it is the only constructor abailable to it)
assert(pcall(function () tst.TestClass.class.new_i(98) end))

-- ___tl("Check overloaded method calls") - run overloads.lua
-- assert(tst.TestClass.class.SINGLETON:sameNameMethod_i(10) == "int|10")
-- assert(tst.TestClass.class.SINGLETON:sameNameMethod_f(10.5) == "float|10.5")
-- assert(tst.TestClass.class.SINGLETON:sameNameMethod_S("abc") == "string|abc")
-- assert(tst.TestClass.class.SINGLETON:sameNameMethod_2i(5, 7) == "ints|5|7")

___tl("Check metatables")
local t = {}
local t1 = {}
setmetatable(t, t1)
assert(getmetatable(t) == t1)


___tl("Check varargs")

-- Lua
local vaFooA = function(msg, ...)
    local args = {...}
    local s = msg
    for _, v in ipairs(args) do
        s = s .. "/" .. tostring(v)
    end
    return s
end

local vaFooB = function(...)
    local args = {...}
    local s = ""
    for _, v in ipairs(args) do
        s = s .. "/" .. tostring(v)
    end
    return s
end

assert(vaFooA("ma") == "ma")
assert(vaFooA("ma", 1) == "ma/1")
assert(vaFooA("ma", 1, 2) == "ma/1/2")
assert(vaFooB() == "")
assert(vaFooB("ma") == "/ma")
assert(vaFooB("ma", 1) == "/ma/1")
assert(vaFooB("ma", 1, 2) == "/ma/1/2")

-- Java
local TestClass = com.prineside.tdi2.utils.luaTests.TestClass.class
local o1 = TestClass.new_i(1)

print(o1)
assert(tostring(o1) == "Secret1")
assert(o1:varArgMethodA(123) == "[123]")
assert(o1:varArgMethodA(123, 321) == "[123, 321]")
assert(o1:varArgMethodA() == "[]")
assert(o1:varArgMethodA("abc") == "[abc]")
assert(o1:varArgMethodB("def") == "def[]")
assert(o1:varArgMethodB("def", 123) == "def[123]")
assert(o1:varArgMethodB("def", 123.5) == "def[123.5]")
assert(o1:varArgMethodC("def", "ghi") == "def[ghi]")
assert(o1:varArgMethodC("def") == "def[]")

local o2 = TestClass.new_iArr(5, 10)
local o3 = TestClass.new_i_OArr(7, "abc", 15)
assert(tostring(o3) == "[abc, 15]7")
assert(o3:varArgMethodD("zxc", o1, o2) == "zxc[Secret1, Secret5]")

assert(TestClass:staticVarArgMethodA("abc", 123, o1) == "[abc, 123, Secret1]")
assert(TestClass:staticVarArgMethodB("def") == "def[]")
assert(TestClass:staticVarArgMethodB("def", "def", "def", 1) == "def[def, def, 1]")
---@diagnostic disable-next-line: param-type-mismatch
assert(TestClass:staticVarArgMethodC("abc", 900, false) == "abc[900, false]")
assert(TestClass:staticVarArgMethodD("xsq", o2) == "xsq[Secret5]")
assert(TestClass:staticVarArgMethodC("abc", nil, false) == "abc[null, false]")
TestClass:staticVarArgMethodE("arrs", {5, 10})

assert(tostring(5) == "5")
assert(tostring(5.5) == "5.5")
logger:i("num: %s", 5)
logger:i("num: %s", 5.5)
logger:i("test: %s, %s", nil, 5.5)

assert(TestClass:staticVarArgMethodF("foo", {o2, o3}) == "foo1[Secret5, [abc, 15]7]")
assert(TestClass:staticVarArgMethodF("foo", nil, {o2, o3}) == "foo2null")
assert(TestClass:staticVarArgMethodF("foo", {o2, o3}, nil, {o2}) == "foo3[Secret5, [abc, 15]7]")

___tl("Check string can be used as java.lang.String")
local s = "a string"
assert(type(s) == "string")

local js = C.String.new_String("a java string")
assert(type(js) == "string")
assert(js:getClass() == C.String)

local split = js:split("java") -- should be String[]
assert(split[1] == "a ")
assert(split[2] == " string")
split = js:split("\\s")
assert(split[1] == "a")
assert(split[2] == "java")
assert(split[3] == "string")


-- Getting Class array type (turning Class into Class[])
-- Java 12+ does exactly this: https://github.com/openjdk/jdk/blob/fd8a3dcc52dc5d6b62edd83eacef5934f6294e80/src/java.base/share/classes/java/lang/Class.java#L4482-L4484
local StringArrClass = java.lang.reflect.Array.class:newInstance_C_i(C.String, 0):getClass()
assert(StringArrClass:_isInstance(split))

assert(js:charAt(0) == 97) -- ascii a

local cStr = js:concat("!!!")
assert(cStr == "a java string!!!")

assert(js:contains("java"))
assert(not js:contains("kotlin"))

assert(cStr:endsWith("!!!"))

assert(js:len() == js:length())

print("All done")