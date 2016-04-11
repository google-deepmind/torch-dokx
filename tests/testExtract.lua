require 'dokx'

local myTests = {}
local tester = torch.Tester()

local package = "dummyPackageName"
local sourceFile = "dummySourceFile"

local checkTableSize = function(...) dokx._checkTableSize(tester, ...) end
local checkComment = function(...) dokx._checkComment(tester, package, sourceFile, ...) end
local checkWhitespace = function(...) dokx._checkWhitespace(tester, ...) end
local checkFunction = function(...) dokx._checkFunction(tester, package, sourceFile, ...) end
local checkClass = function(...) dokx._checkClass(tester, package, sourceFile, ...) end

function myTests:testExtractNone()
    local testInput = [[

    ]]
    local classes, documentedFunctions, undocumentedFunctions = dokx.extractDocs(package, sourceFile, testInput)
    checkTableSize(classes, 0)
    checkTableSize(documentedFunctions, 0)
    checkTableSize(undocumentedFunctions, 0)
end

function myTests:testExtractFunction()
    local testInput = [[

function dummyPackageName.activate()
end

    ]]
    local classes, documentedFunctions, undocumentedFunctions = dokx.extractDocs(package, sourceFile, testInput)
    checkTableSize(classes, 0)
    checkTableSize(documentedFunctions, 0)
    checkTableSize(undocumentedFunctions, 1)
end

function myTests:testExtractDocumentedFunction()
    local testInput = [[

-- this is a function
function dummyPackageName.activate()
end

    ]]
    local classes, documentedFunctions, undocumentedFunctions = dokx.extractDocs(package, sourceFile, testInput)
    checkTableSize(classes, 0)
    checkTableSize(documentedFunctions, 1)
    checkTableSize(undocumentedFunctions, 0)
end

function myTests:testExtractClassWithParent()
    local testInput = [[

-- this is a function
function dummyPackageName.activate()
end

-- this is a class
local MyClass, parent = torch.class("dummyPackageName.MyClass", "SomeParentClass")

function MyClass:frobnicate(gamma)

end

    ]]
    local classes, documentedFunctions, undocumentedFunctions = dokx.extractDocs(package, sourceFile, testInput)
    checkTableSize(classes, 1)
    checkTableSize(documentedFunctions, 1)
    checkTableSize(undocumentedFunctions, 1)
end

function myTests:testExtractClassNoParent()
    local testInput = [[

-- this is a function
function dummyPackageName.activate()
end

-- this is a class
local MyClass, parent = torch.class("dummyPackageName.MyClass")

function MyClass:frobnicate(gamma)

end

    ]]
    local classes, documentedFunctions, undocumentedFunctions = dokx.extractDocs(package, sourceFile, testInput)
    checkTableSize(classes, 1)
    checkTableSize(documentedFunctions, 1)
    checkTableSize(undocumentedFunctions, 1)
end


function myTests:testExtractModule()
    local testInput = [=[
--[[ This is a module ]]

-- this is a function
function dummyPackageName.activate()
end
]=]
    local classes, documentedFunctions, undocumentedFunctions, fileString = dokx.extractDocs(
            package, sourceFile, testInput
        )
    checkTableSize(classes, 0)
    checkTableSize(documentedFunctions, 1)
    checkTableSize(undocumentedFunctions, 0)
    tester:asserteq(fileString, "This is a module\n", "file string does not match expected")

end

function myTests:testExtractFullModule()
    local testInput = [=[
-- This is a module


function testFunction()
    print("This function is undocumented")
end

-- This is a dummy test class
local myClass, parent = torch.class("dummyPackageName.MyClass")

--[[ This is a dummy test function

Args:

 * `gamma` - a test parameter

Returns: nil
]]
function myClass:frobnicate(gamma)
    print("Undergoing frobnication")
end

-- This is another dummy test function
function myClass:foobar()
end
]=]
    local classes, documentedFunctions, undocumentedFunctions, fileString = dokx.extractDocs(
            package, sourceFile, testInput
        )
    local parser = dokx.createParser(package, sourceFile)
    local result = parser(testInput)
    checkTableSize(classes, 1)
    checkTableSize(documentedFunctions, 2)
    checkTableSize(undocumentedFunctions, 1)
    tester:asserteq(fileString, "This is a module\n", "file string does not match expected")
end

function myTests:testExtractNoFileComment()
    local testInput = [=[
require 'module'

-- This is some random comment
]=]
    local classes, documentedFunctions, undocumentedFunctions, fileString = dokx.extractDocs(
            package, sourceFile, testInput
        )
    local parser = dokx.createParser(package, sourceFile)
    local result = parser(testInput)
    checkTableSize(classes, 0)
    checkTableSize(documentedFunctions, 0)
    checkTableSize(undocumentedFunctions, 0)
    tester:asserteq(fileString, false, "no file string expected")
end

tester:add(myTests):run()
