require 'dokx'
local tester = torch.Tester()
local myTests = {}

local path = require 'pl.path'
local filex = require 'pl.file'
local stringx = require 'pl.stringx'
local package = "testData"

local function mkTemp()
    local file = io.popen("mktemp -d -t dokxTest")
    local name = stringx.strip(file:read("*all"))
    file:close()
    return name
end

function myTests.testExtractMarkdown()
    local tmpDir = mkTemp()
    local inputPath = "tests/data/testInput1.lua"
    local outputPath = tmpDir .. "/testInput1.md"
    local expectedPath = "tests/data/testOutput1.md"
    local cmd = "dokx-extract-markdown -p " .. package .. " -o " .. tmpDir .. " " .. inputPath
    local exitCode = os.execute(cmd, "r")
    tester:asserteq(exitCode, 0, "script should return exit code 0")
    local got = dokx._readFile(outputPath)
    local expected = dokx._readFile(expectedPath)
    if got == expected then
        tester:assert(true, "output does not match expected")
    else
        -- TODO replace with diff ?
        os.execute("colordiff -u " .. outputPath .. " " .. expectedPath)
        tester:assert(false, "output does not match expected")
    end

    filex.delete(outputPath)
    path.rmdir(tmpDir)
end

tester:add(myTests)
tester:run()
