local inputPath = arg[1]

local tmpFile = "/tmp/extractedBytecode"
os.execute("luac -p -l " .. inputPath .. " > " .. tmpFile)
--local content = io.open(inputPath, "rb"):read("*all")
--

local lpeg = require 'lpeg'

local digit = lpeg.S("1234567890")
local colon = lpeg.P(":")
local comma = lpeg.P(",")
local captureNumber = lpeg.C(digit^1)
local rbracket = lpeg.P(")")

local functionPattern = lpeg.P("function <") * lpeg.C((1-colon)^1) * colon * 
    captureNumber * comma * captureNumber *
    (1-lpeg.P("bytes at "))^0 * lpeg.P("bytes at ") * lpeg.C((1-rbracket)^1)

local stringx = require 'pl.stringx'
local bytecodeFile = io.open(tmpFile, 'r')
for line in bytecodeFile:lines() do

    if stringx.startswith(line, "function") then
        print(line)
    end
    local matched = {lpeg.match(functionPattern, line)}
    if #matched ~= 0 then
        print(matched)
    end

end
