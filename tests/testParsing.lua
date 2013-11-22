require 'dokx'

local tester = torch.Tester()
local myTests = {}

function myTests:testParseWhitespace()
    local parser = dokx.createParser("dummyPackageName", "dummySourceFile")
    local testInput = "  \n\t  "

    local result = parser(testInput)
    tester:asserteq(type(result), 'table', "should be a table")
    tester:asserteq(#result, 0, "should be empty")

end
function myTests:testParseDocumentedFunction()
    local parser = dokx.createParser("dummyPackageName", "dummySourceFile")
    local testInput = [[-- this is some dummy documentation
function foo()

end
    ]]

    local result = parser(testInput)
    tester:asserteq(type(result), 'table', "should be a table")
    tester:asserteq(#result, 2, "should be size two")

    local entity1 = result[1]
    tester:assert(entity1:is_a(dokx.Comment), "should be a comment")
    tester:asserteq(entity1:text(), "this is some dummy documentation\n", "should have expected text")
    tester:asserteq(entity1:package(), "dummyPackageName", "should have expected package name")
    tester:asserteq(entity1:file(), "dummySourceFile", "should have expected source file")
    tester:asserteq(entity1:lineNo(), 2, "should have expected line number")

    local entity2 = result[2]
    tester:assert(entity2:is_a(dokx.Function), "should be a function")
    tester:asserteq(entity2:name(), "foo", "should have expected name")
    tester:asserteq(entity2:class(), false, "should have no class")
    tester:asserteq(entity2:package(), "dummyPackageName", "should have expected package name")
    tester:asserteq(entity2:file(), "dummySourceFile", "should have expected source file")
    tester:asserteq(entity2:lineNo(), 5, "should have expected line number")

end

tester:add(myTests)
tester:run()
