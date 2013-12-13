require 'dokx'
local tester = torch.Tester()
local myTests = {}

local path = require 'pl.path'
local filex = require 'pl.file'
local stringx = require 'pl.stringx'
local package = "testData"

function myTests.testExtractMarkdown()
    local tmpDir = dokx._mkTemp()
    local inputPath = "tests/data/testInput1.lua"
    local outputPath = path.join(tmpDir, "testInput1.md")
    local expectedPath = "tests/data/testOutput1.markdown"
    dokx.extractMarkdown(package, tmpDir, { inputPath })
    tester:assert(path.isfile(outputPath), "script did not produce the expected file")
    local got = dokx._readFile(outputPath)
    local expected = dokx._readFile(expectedPath)
    dokx._assertEqualWithDiff(tester, got, expected)

    filex.delete(outputPath)
    path.rmdir(tmpDir)
end

tester:add(myTests)
tester:run()
dokx._exitWithTester(tester)
