-- This file contains test input for the markdown extractor


function testFunction()
    print("This function is undocumented")
end

-- This is a dummy test class
local myClass, parent = torch.class("testData.MyClass")

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

