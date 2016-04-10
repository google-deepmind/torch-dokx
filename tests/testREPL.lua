require 'dok'
require 'dokx'

--[[

This test checks whether it's possible to access the docs for torch-dokx from the torch REPL (using the torch 'dok' system).

This relies on the Markdown docs having been installed in the correct place in the torch rocks tree - for example `~/usr/local/share/lua/5.1/dokx/doc`.

These could be installed by, for example:

    dokx-build-package-docs -o /tmp/testDocs/ /path/to/dokx/repository --repl ~/usr/local/share/lua/5.1/dokx/doc

--]]

local tester = torch.Tester()
local myTests = {}

function myTests:testREPL()

    local succeeded = {}
    local failed = {}

    if dok.help(dokx, true) == nil then
        table.insert(failed, 'dokx')
    else
        table.insert(succeeded, 'dokx')
    end

    for name, func in pairs(dokx) do

        -- We'll check docs for everything in the global dokx table, except for private functions and the logger object.
        if name:sub(1,1) ~= "_" and name ~= 'logger' then

            -- This is equivalent to calling the help() function from the REPL, except that it returns a string.
            local doc = dok.help(func, true)

            -- For reporting the results, we keep track of which item had or did not have docs
            local symbol = 'dokx.' .. name
            if doc == nil then
                table.insert(failed, symbol)
            else
                table.insert(succeeded, symbol)
            end
        end
    end

    -- Fail if any items were missing docs
    tester:asserteq(#failed, 0, "REPL couldn't get doc for some functions")
    if #failed ~= 0 then
        print("Suceeded: ", succeeded)
        print("Failed: ", failed)
    end
end

tester:add(myTests):run()
