require 'dokx'
local tester = torch.Tester()
local myTests = {}

local path = require 'pl.path'
local filex = require 'pl.file'
local stringx = require 'pl.stringx'
local package = "testData"

dokx.debugMode()

function myTests.testCombineTOC()
    local tmpDir = dokx._mkTemp()
    local inputPath = "tests/data/tocTest"
    local outputPath = path.join(inputPath, "toc.html")
    local expectedPath = "tests/data/expectedTOC.html"
    dokx.combineTOC(package, inputPath, dokx._loadConfig())
    tester:assert(path.isfile(outputPath), "script did not produce the expected file")
    local got = dokx._readFile(outputPath)
    local expected = dokx._readFile(expectedPath)
    print(got)
    dokx._assertEqualWithDiff(tester, got, expected, '-u -w')

    filex.delete(outputPath)
    path.rmdir(tmpDir)
end

tester:add(myTests):run()
