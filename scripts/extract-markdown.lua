
local lapp = require 'pl.lapp'

local path = require 'pl.path'
require 'logging.console'
local logger = logging.console()
logger:setLevel(logging.DEBUG)

local function processArgs()
    return  lapp [[
    Extract inline documentation from Lua source
    -o,--output (string)    output directory
    <inputs...>  (string)    input .lua files
    ]]
end


local function main()
    local args = processArgs()

    for i, input in ipairs(args.inputs) do
        logger:info("Processing file " .. input)

        local basename = path.basename(input)
        local name, ext = path.splitext(basename)
        lapp.assert(ext == '.lua', "Expected .lua file for input")
        local outputPath = path.join(args.output, name .. ".md")

        local packageName = name

        dofile("luasrc/parse.lua") -- TODO require

        local documentedFunctions = dokx.extractDocs(input)

        -- Output markdown
        dofile("luasrc/markdown.lua")-- TODO require
        local writer = MarkdownWriter(outputPath, packageName)
        local function handleEntity(entity)
            writer:documentEntity(entity)
        end
        documentedFunctions:foreach(handleEntity)
        writer:close()
    end
end

main()

