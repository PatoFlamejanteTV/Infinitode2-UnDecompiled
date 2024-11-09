assert(not pcall(function() C.SFileHandle.new("foo.txt") end))
assert(pcall(function() C.SFileHandle.new("res/foo.txt") end))
assert(not pcall(function() C.SFileHandle.new("res/luaj/foo.txt") end))