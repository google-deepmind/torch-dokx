require 'dokx'

local tester = torch.Tester()
local myTests = {}

local package = "dummyPackageName"
local sourceFile = "dummySourceFile"

local checkTableSize = function(...) dokx._checkTableSize(tester, ...) end
local checkComment = function(...) dokx._checkComment(tester, package, sourceFile, ...) end
local checkWhitespace = function(...) dokx._checkWhitespace(tester, ...) end
local checkFunction = function(...) dokx._checkFunction(tester, package, sourceFile, ...) end
local checkClass = function(...) dokx._checkClass(tester, package, sourceFile, ...) end

-- Unit tests
function myTests:testParseWhitespace()
    local parser = dokx.createParser(package, sourceFile)
    local testInput = "  \n\t  "
    local result = parser(testInput)
    checkTableSize(result, 1)
    checkWhitespace(result[1])
end
function myTests:testParseDocumentedFunction()
    local parser = dokx.createParser(package, sourceFile)
    local testInput = [[-- this is some dummy documentation
function foo()

end
    ]]
    local result = parser(testInput)
    checkTableSize(result, 3)
    checkComment(result[1], "this is some dummy documentation\n", 2)
    checkFunction(result[2], "foo", false, 5)
    checkWhitespace(result[3])
end
function myTests:testParseGlobalFunction()
    local parser = dokx.createParser(package, sourceFile)
    local testInput = [[function foo(a) end]]
    local result = parser(testInput)
    checkTableSize(result, 1)
    checkFunction(result[1], "foo", false, 1, 'a')
end
function myTests:testParseLocalFunction()
    local parser = dokx.createParser(package, sourceFile)
    local testInput = [[local function foo(a, b) end]]
    local result = parser(testInput)
    checkTableSize(result, 1)
    checkFunction(result[1], "foo", false, 1, 'a, b')
end
function myTests:testParseInstanceMethod()
    local parser = dokx.createParser(package, sourceFile)
    local testInput = [[function myClass:foo() end]]
    local result = parser(testInput)
    checkTableSize(result, 1)
    checkFunction(result[1], "foo", "myClass", 1)
end
function myTests:testParseClassMethod()
    local parser = dokx.createParser(package, sourceFile)
    local testInput = [[function myClass.foo() end]]
    local result = parser(testInput)
    checkTableSize(result, 1)
    checkFunction(result[1], "foo", "myClass", 1)
end
function myTests:testParseSeparateComments()
    local parser = dokx.createParser(package, sourceFile)
    local testInput = [=[
    --[[ first comment
    lorem ipsum
    ]]

    --second comment
    ]=]

    local result = parser(testInput)
    checkTableSize(result, 5)
    checkWhitespace(result[1])
    checkComment(result[2], " first comment\n    lorem ipsum\n    \n", 4)
    checkWhitespace(result[3])
    checkComment(result[4], "second comment\n", 6)
    checkWhitespace(result[5])
end
function myTests:testParseAdjacentComments()
    local parser = dokx.createParser(package, sourceFile)
    local testInput = [[
    -- first comment
    -- second comment
    ]]

    local result = parser(testInput)
    checkTableSize(result, 5)
    checkWhitespace(result[1])
    checkComment(result[2], "first comment\n", 2)
    checkWhitespace(result[3])
    checkComment(result[4], "second comment\n", 3)
    checkWhitespace(result[5])
end
function myTests:testParseClass()
    local parser = dokx.createParser(package, sourceFile)
    local testInput = [=[--[[

This is a dummy class.

--]]
local MyClass, parent = torch.class('dummyPackageName.MyClass', 'otherPackage.Parent')
]=]

    local result = parser(testInput)
    checkTableSize(result, 4)
    checkComment(result[1], "\n\nThis is a dummy class.\n\n\n", 6)
    checkWhitespace(result[2])
    checkClass(result[3], "MyClass", "otherPackage.Parent", 7)
    checkWhitespace(result[4])
end

tester:add(myTests)
tester:run()
