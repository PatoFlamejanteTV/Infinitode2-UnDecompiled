local tst = com.prineside.tdi2.utils.luaTests

assert(tst.TestClass.class.SINGLETON:sameNameMethod(10) == "int|10")
assert(tst.TestClass.class.SINGLETON:sameNameMethod(10.5) == "float|10.5")
assert(tst.TestClass.class.SINGLETON:sameNameMethod("abc") == "string|abc")
assert(tst.TestClass.class.SINGLETON:sameNameMethod(5, 7) == "ints|5|7")

local sameNameMethodInt = tst.TestClass.class:_findMethod("sameNameMethod", java.int)
assert(sameNameMethodInt(tst.TestClass.class.SINGLETON, 10.5) == "int|10")

local sameNameMethodIntInt = tst.TestClass.class:_findMethod("sameNameMethod", java.int, java.int)
assert(sameNameMethodIntInt(tst.TestClass.class.SINGLETON, 99, 1) == "ints|99|1")
assert(sameNameMethodIntInt(tst.TestClass.class.SINGLETON, "99", 1) == "ints|99|1")

-- Interface methods
local methodFromInterface = com.prineside.tdi2.utils.luaTests.TestInterfaceWithBlacklistedMethod.class:_findMethod("thisMethodIsWhitelisted")
print(methodFromInterface)
assert(methodFromInterface(tst.TestClass.class.SINGLETON) == 777)