---@meta

--- LuaJava library is provided by LuaJ, this is its default (and obsolete in terms of this game) way of interaction with Java.
--- Left here for backwards compatibility.
--- @class luajava
luajava = {}


--- Works just like importGlobal().
--- Preferred alternative: access classes directly through the global tables. For example:
---
--- local someClass = luajava.bindClass("com.prineside.tdi2.Config") --[[@as com.prineside.tdi2.Config.class]]
---   does the same as
--- local someClass = com.prineside.tdi2.Config.class
---
--- Can be used to import Java class for a primitive type:
---     "float" => float.class
---		"int" => int.class
---		"double" => double.class
---		"long" => long.class
---		"byte" => byte.class
---		"short" => short.class
---		"boolean" => boolean.class
---		"char" => char.class
---
--- For example:
--- local intClass = luajava.bindClass("int") --[[@as java.lang.Class]]
--- local arr = java.lang.reflect.Array.class.newInstance(intClass, 10) -- same as new int[10]; in Java
---
--- @param className string full name of the class
--- @return java.lang.Class
luajava.bindClass = function(className) end


--- Creates new instance of the class by its full name.
--- Preferred alternative: use class constructors, the do the same but also provide an IDE hints:
---
--- local obj = luajava.newInstance("java.lang.ArrayList") --[[@as java.lang.ArrayList]]
---   does the same as
--- local obj = java.lang.ArrayList.class.new()
---
--- @param className string full class name
--- @return java.lang.Object
luajava.newInstance = function(className) end


--- Creates new instance of the class.
--- Preferred alternative: use class constructors, the do the same but also provide an IDE hints:
---
--- local obj = luajava.newInstance(java.lang.ArrayList.class) --[[@as java.lang.ArrayList]]
---   does the same as
--- local obj = java.lang.ArrayList.class.new()
---
--- @param className java.lang.Class class to create new instance of
--- @return java.lang.Object
luajava.newInstance = function(className) end


--- Creates new object which implements the specified interfaces.
--- Only use this function if you need multiple interfaces to be implemented at once.
--- If you want to implement a single interface, it is better to use the interface class directly:
---
--- local listener = luajava.createProxy("com.prineside.tdi2.events.Listener", { handle = function(event) ... end }) --[[@as com.prineside.tdi2.events.Listener]]
---   does the same as
--- local listener = com.prineside.tdi2.events.Listener({ handle = function(event) ... end })
---
--- To implement multiple interfaces:
---
--- local listener = luajava.createProxy(
---     com.prineside.tdi2.events.Listener.class,
---     java.lang.Iterable.class,
---     { ... }
--- )
---
--- Last parameter is a table implementing interface methods. Everything else is a string or java.lang.Class representing interfaces or their names.
--- @return java.lang.Object which implements all of the listed interfaces
luajava.createProxy = function(...) end


--- Check if object is instance of the class.
--- Works the same as Java's ```obj instanceof Class```.
--- @param object java.lang.Object object to be checked
--- @param class java.lang.Class|string class or class name to be checked for
--- @return boolean true if object is instance of class
luajava.ofClass = function(object, class) end


--- Get a hashCode of the object
--- @param object any
--- @return number (int)
luajava.hashCode = function(object) end
