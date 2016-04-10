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
function myTests:testParseMustHave()
    local parser = dokx.createParser(package, sourceFile)
    local testInput = [[myClass:mustHave("step")]]
    local result = parser(testInput)
    checkTableSize(result, 1)
    checkFunction(result[1], "step", "myClass", 1)
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

function myTests:testParseClassicClass()
    local parser = dokx.createParser(package, sourceFile)
    local testInput = [=[--[[

This is a dummy class.

--]]
local MyClass, parent = classic.class('dummyPackageName.MyClass', 'otherPackage.Parent')
]=]

    local result = parser(testInput)
    checkTableSize(result, 4)
    checkComment(result[1], "\n\nThis is a dummy class.\n\n\n", 6)
    checkWhitespace(result[2])
    checkClass(result[3], "MyClass", "otherPackage.Parent", 7)
    checkWhitespace(result[4])
end

function myTests:testParseClassicClassWithEllipsis()
    local parser = dokx.createParser(package, sourceFile)
    local testInput = [=[--[[

This is a dummy class.

--]]
local MyClass, parent = classic.class(..., otherPackage.Parent)
]=]

    local result = parser(testInput)
    checkTableSize(result, 4)
    checkComment(result[1], "\n\nThis is a dummy class.\n\n\n", 6)
    checkWhitespace(result[2])
    checkClass(result[3], "dummySourceFile", "otherPackage.Parent", 7)
    checkWhitespace(result[4])
end

function myTests:testParsePenlightClass()
    local parser = dokx.createParser(package, sourceFile)
    local testInput = [=[--[[

This is a dummy class.

--]]
local MyClass = class()
]=]

    local result = parser(testInput)
    checkTableSize(result, 4)
    checkComment(result[1], "\n\nThis is a dummy class.\n\n\n", 6)
    checkWhitespace(result[2])
    checkClass(result[3], "MyClass", false, 7)
    checkWhitespace(result[4])
end

function myTests:testParsePenlightClassWithParent()
    local parser = dokx.createParser(package, sourceFile)
    local testInput = [=[--[[

This is a dummy class.

--]]
local MyClass = class(MyParent)
]=]

    local result = parser(testInput)
    checkTableSize(result, 4)
    checkComment(result[1], "\n\nThis is a dummy class.\n\n\n", 6)
    checkWhitespace(result[2])
    checkClass(result[3], "MyClass", "MyParent", 7)
    checkWhitespace(result[4])
end

function myTests:testFunctionAsAssignment()
    local parser = dokx.createParser(package, sourceFile)
    local testInput = [[myFunction = function(a, b) end]]
    local result = parser(testInput)
    checkTableSize(result, 1)
    checkFunction(result[1], "myFunction", false, 1)
    tester:asserteq(result[1]:args(), "a, b", "function should have expected args")
end
function myTests:testFunctionAsAssignmentWithClass()
    local parser = dokx.createParser(package, sourceFile)
    local testInput = [[myClass.myFunction = function(a, b) end]]
    local result = parser(testInput)
    checkTableSize(result, 1)
    checkFunction(result[1], "myFunction", "myClass", 1)
    tester:asserteq(result[1]:args(), "a, b", "function should have expected args")
end

function myTests:testIgnoreAssignment()
    local parser = dokx.createParser(package, sourceFile)
    local testInput = [[myFunction = 3]]
    local result = parser(testInput)
    checkTableSize(result, 0)
end

function myTests:testIgnoreAssignmentString()
    local parser = dokx.createParser(package, sourceFile)
    local testInput = [[a="function(a, b) return 1 end"]]
    local result = parser(testInput)
    checkTableSize(result, 0)
end

function myTests:testBadParse()
    local parser = dokx.createParser(package, sourceFile)
    local testInput = [[a=function)"]]
    local result = parser(testInput)
    tester:asserteq(result, nil, "result of bad parse should be nil")
end

function myTests:testFunctionAsAssigmentWithDocs()
    local parser = dokx.createParser(package, sourceFile)
    local testInput = [[
-- a function
module.aFunction = function(x, y)
    x = y
    z = function() end
    local p = function(a)
        return 2
    end
    return z
end
local f = function(z)

end]]
    local result = parser(testInput)
    checkTableSize(result, 3)
    checkComment(result[1], "a function\n", 2)
    checkFunction(result[2], "aFunction", "module", 10)
    tester:asserteq(result[2]:args(), "x, y", "function should have expected args")
    checkWhitespace(result[3])
end

function myTests:testNumberParsing()
    local parser = dokx.createParser(package, sourceFile)
    local testInput = "return 1.0"
    tester:assertne(parser(testInput), nil, "float should parse")
    testInput = "return 1."
    tester:assertne(parser(testInput), nil, "float with no fractional part should parse")
    testInput = "return 1"
    tester:assertne(parser(testInput), nil, "integer should parse")
end

function myTests:testInterposingComment()
  local parser = dokx.createParser(package, sourceFile)
  local testInput = [[

local foo =
    -- my very special number
    3

bar =
    -- another number
    4

  ]]
  tester:assertne(parser(testInput), nil, "interposing comment should parse")
end

tester:add(myTests):run()
