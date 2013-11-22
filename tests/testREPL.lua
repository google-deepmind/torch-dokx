require 'dok'
require 'dokx'

local tester = torch.Tester()
local myTests = {}

function assertHaveDoc(name, symbol)
    local doc = dok.help(symbol, true)
    tester:assertne(nil, doc, "REPL couldn't get doc for " .. name)
end

function myTests:testREPL()

    assertHaveDoc('dokx', dokx)
    for name, func in pairs(dokx) do
        assertHaveDoc('dokx.' .. name, func)
    end
end

tester:add(myTests)
tester:run()
