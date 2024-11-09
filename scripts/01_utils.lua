--[[
    Utilities for Lua
--]]
_G.utils = {
    --- Returns string representation of the variable with extra info:
    --- - if it is a `table`, prints all of its key - value pairs and table's total size
    --- - if it is a `userdata` (Java object), prints its field and method names with signatures
    --- Hint: you can use `log(utils.print(someUnknownVar))` in script / console to quickly find out how you can interact with it (or press the eye icon)
    --- @param var any any variable you want to print
    --- @return string - string representation of what is in the variable
    print = function(var)
        if type(var) == "table" then
            local out = {}
            local cnt = 0
            for k, v in pairs(var) do
                local lineParts = {}
                table.insert(lineParts, "  " .. tostring(k))
                table.insert(lineParts, " = ")
                table.insert(lineParts, type(v))
                table.insert(out, table.concat(lineParts, ""))
                cnt = cnt + 1
            end

            if cnt == 0 then
                return tostring(var) .. " (size: 0) {}"
            else
                return tostring(var) .. " (size: " .. cnt .. " / " .. #var .. " indices) {\n" .. table.concat(out, "\n") .. "\n}"
            end
        elseif type(var) == "userdata" then
            -- todo: use var:getClass() / java.lang.reflection to get more info
            return tostring(var)
        else
            return tostring(var)
        end
    end,

    --- Print `var` recursively if it is a table or as usual string if not
    --- @param tabSize integer number of spaces for pretty print (may be nil)
    --- @param visitedTables table? visited tables as keys to not print them again (may be nil)
    --- @return string - string representation of what is in the variable
    printr = function(var, tabSize, visitedTables)
        if tabSize == nil then tabSize = 0 end
        if visitedTables == nil then visitedTables = {} end

        if type(var) == "table" then
            if visitedTables[var] ~= nil then
                return "..."
            end
            visitedTables[var] = true

            local currentTab = string.rep("  ", tabSize)
            local nextTab = string.rep("  ", tabSize + 1)
            local out = {}
            local cnt = 0
            for k, v in pairs(var) do
                local lineParts = {}
                table.insert(lineParts, nextTab)
                table.insert(lineParts, tostring(k))
                table.insert(lineParts, " = ")
                table.insert(lineParts, _G.utils.printr(v, tabSize + 1, visitedTables))
                table.insert(out, table.concat(lineParts, ""))
                cnt = cnt + 1
            end

            if cnt == 0 then
                return currentTab .. tostring(var) .. " (size: 0) {}"
            else
                return currentTab .. tostring(var) .. " (size: " .. cnt .. " / " .. #var .. " indices) {\n" .. table.concat(out, "\n") .. "\n" .. currentTab .. "}"
            end
        elseif type(var) == "userdata" then
            -- todo: use var:getClass() / java.lang.reflection to get more info
            return tostring(var)
        else
            return tostring(var)
        end
    end,

    --- Split `inputstr` into an array of strings, separated by `sep`
    --- @param inputstr string string to split
    --- @param sep? string separator (part of the string to cut on), use nil to split by whitespace (space / tab etc)
    --- @return table - an array which contains parts of the string
    stringsplit = function (inputstr, sep)
        if sep == nil then
            sep = "%s"
        end
        local t = {}
        local i = 1
        for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
            t[i] = str
            i = i + 1
        end
        return t
    end,

    --- Removes all of the nil values from table `t` and shifts all of the indices to fill in the gaps.
    --- May be useful if you want to remove some values from the table while iterating through it
    --- (iterate -> set some index to nil while iterating -> call compactnil() on the table at the end)
    --- Order of elements is preserved
    --- @param t table a table from which you want to remove the nils. Can be a regular array or a map
    --- @return nil
    compactnil = function (t)
        local idx = 1
        for k, v in pairs(t) do
            if v ~= nil then
                if k ~= idx then
                    t[idx] = v
                    t[k] = nil
                end
                idx = idx + 1
            end
        end
    end,

    --- Remove all of the values from table `t` that are equal to `val`
    --- Element order will be preserved and there will be no gaps (nil values) in the table
    --- @param t table a table you want to remove `val` from
    --- @param val any any value that you want to be removed from the table `t`
    --- @return nil
    tableRemoveVal = function(t, val)
        for i = #t, 1, -1 do
            if t[i] == val then
                t[i] = nil
            end
        end
        utils.compactnil(t)
    end,

    --- Just like pairs() but iterates in a sorted manner (sorts by keys)
    --- Does not alter the original table
    --- @param t table a table you want to iterate through
    --- @param f? fun(a: any, b: any):boolean an optional sorting function, see table.sort(list, comp) for more info
    --- @return fun():any, any - an iterator which can be used in `for` directly
    pairsByKeys = function(t, f)
      local a = {}
      for n in pairs(t) do table.insert(a, n) end
      table.sort(a, f)
      local i = 0
      local iter = function ()
        i = i + 1
        if a[i] == nil then return nil
        else return a[i], t[a[i]]
        end
      end
      return iter
    end,

    --- Try to run some code and catch an error if it occurs.
    --- You may prefer to use `pcall()` directly - I've made this utility function because I always forget 
    --- how this function is called (don't blame me, I don't even remember how many languages I write in)
    --- @param action function a function you want to run
    --- @param errorHandler? fun(e:any) a function which will be called in case of error, optional 
    tryCatch = function(action, errorHandler)
        local status, err = pcall(action)
        if not status and errorHandler then
            errorHandler(err)
        end

        return status
    end,

    --- Deprecated, use `S.gameState:randomFloat()` instead.
    --- This function will be removed later.
    ---@deprecated
    syncRandFloat = function()
        error("use S.gameState:randomFloat() instead")
    end,

    --- Deprecated, use `S.gameState:randomInt(maxExcl)` instead.
    --- This function will be removed later.
    ---@deprecated
    syncRandInt = function(maxExcl)
        error("use S.gameState:randomInt(maxExcl) instead")
    end
}