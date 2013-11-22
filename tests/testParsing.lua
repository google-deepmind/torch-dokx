require 'dokx'

local tester = torch.Tester()
local myTests = {}

-- Check that the result is a table with the given size
local function _checkTableSize(result, size)
    tester:asserteq(type(result), 'table', "should be a table")
    tester:asserteq(#result, size, "should be size " .. size)
end
-- Check that the result is a Function with the expected name, class and line number
local function _checkFunction(entity, name, class, line)
    tester:assert(entity:is_a(dokx.Function), "should be a function")
    tester:asserteq(entity:name(), name, "should have expected name")
    tester:asserteq(entity:class(), class, "should have expected class")
    tester:asserteq(entity:package(), "dummyPackageName", "should have expected package name")
    tester:asserteq(entity:file(), "dummySourceFile", "should have expected source file")
    tester:asserteq(entity:lineNo(), line, "should have expected line number")
end
-- Check that the result is a Comment with the expected text and line number
local function _checkComment(entity, text, line)
    tester:assert(entity:is_a(dokx.Comment), "should be a comment")
    tester:asserteq(entity:text(), text, "should have expected text")
    tester:asserteq(entity:package(), "dummyPackageName", "should have expected package name")
    tester:asserteq(entity:file(), "dummySourceFile", "should have expected source file")
    tester:asserteq(entity:lineNo(), line, "should have expected line number")
end
-- Check that the result is a Class with the expected name, parent and line number
local function _checkClass(entity, name, parent, line)
    tester:assert(entity:is_a(dokx.Class), "should be a class")
    tester:asserteq(entity:name(), name, "should have expected name")
    tester:asserteq(entity:parent(), parent, "should have expected parent")
    tester:asserteq(entity:package(), "dummyPackageName", "should have expected package name")
    tester:asserteq(entity:file(), "dummySourceFile", "should have expected source file")
    tester:asserteq(entity:lineNo(), line, "should have expected line number")
end

-- Unit tests
function myTests:testParseWhitespace()
    local parser = dokx.createParser("dummyPackageName", "dummySourceFile")
    local testInput = "  \n\t  "
    local result = parser(testInput)
    _checkTableSize(result, 0)
end
function myTests:testParseDocumentedFunction()
    local parser = dokx.createParser("dummyPackageName", "dummySourceFile")
    local testInput = [[-- this is some dummy documentation
function foo()

end
    ]]
    local result = parser(testInput)
    _checkTableSize(result, 2)
    _checkComment(result[1], "this is some dummy documentation\n", 2)
    _checkFunction(result[2], "foo", false, 5)
end
function myTests:testParseGlobalFunction()
    local parser = dokx.createParser("dummyPackageName", "dummySourceFile")
    local testInput = [[function foo() end]]
    local result = parser(testInput)
    _checkTableSize(result, 1)
    _checkFunction(result[1], "foo", false, 1)
end
function myTests:testParseLocalFunction()
    local parser = dokx.createParser("dummyPackageName", "dummySourceFile")
    local testInput = [[local function foo() end]]
    local result = parser(testInput)
    _checkTableSize(result, 1)
    _checkFunction(result[1], "foo", false, 1)
end
function myTests:testParseInstanceMethod()
    local parser = dokx.createParser("dummyPackageName", "dummySourceFile")
    local testInput = [[function myClass:foo() end]]
    local result = parser(testInput)
    _checkTableSize(result, 1)
    _checkFunction(result[1], "foo", "myClass", 1)
end
function myTests:testParseClassMethod()
    local parser = dokx.createParser("dummyPackageName", "dummySourceFile")
    local testInput = [[function myClass.foo() end]]
    local result = parser(testInput)
    _checkTableSize(result, 1)
    _checkFunction(result[1], "foo", "myClass", 1)
end
function myTests:testParseSeparateComments()
    local parser = dokx.createParser("dummyPackageName", "dummySourceFile")
    local testInput = [=[
    --[[ first comment
    lorem ipsum
    ]]

    --second comment
    ]=]

    local result = parser(testInput)
    _checkTableSize(result, 2)
    _checkComment(result[1], "first comment\n    lorem ipsum\n", 4)
    _checkComment(result[2], "second comment\n", 6)
end
function myTests:testParseClass()
    local parser = dokx.createParser("dummyPackageName", "dummySourceFile")
    local testInput = [=[
--[[

This is a dummy class.

--]]
local MyClass, parent = torch.class('dummyPackageName.MyClass', 'otherPackage.Parent')
]=]

    local result = parser(testInput)
    _checkTableSize(result, 2)
    _checkComment(result[1], "This is a dummy class.\n\n\n", 6)
    _checkClass(result[2], "MyClass", "otherPackage.Parent", 7)
end

tester:add(myTests)
tester:run()
