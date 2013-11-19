require 'lxsh'
local inputPath = arg[1]

local content = io.open(inputPath, "rb"):read("*all")

for kind, text, lnum, cnum in lxsh.lexers.lua.gmatch(content) do
    print(string.format('%s: %q (%i:%i)', kind, text, lnum, cnum))
end
