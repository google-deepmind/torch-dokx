local lapp = require 'pl.lapp'

require 'logging.console'
local logger = logging.console()
logger:setLevel(logging.DEBUG)

local lpeg = require 'lpeg'
local path = require 'pl.path'
local tablex = require 'pl.tablex'
local class = require 'pl.class'
local textx = require 'pl.text'

local function processArgs()
    return  lapp [[
    Extract inline documentation from Lua source
    -i,--input  (string)    input .lua file
    -o,--output (string)    output .markdown file
    ]]
end

function readFile(inputPath)
    lapp.assert(path.isfile(inputPath), "Not a file: " .. tostring(inputPath))
    logger:debug("Opening " .. tostring(inputPath))
    local inputFile = io.open(inputPath, "rb")
    lapp.assert(inputFile, "Could not open: " .. tostring(inputPath))
    local content = inputFile:read("*all")
    inputFile:close()
    return content
end

class.Entity()

function Entity:_init(args)
    self.name = args.name
    self.src = args.src
    self.doc = args.doc
end

local function parseSource(content)

    logger:debug("Parsing file contents")

    local commentBlockStart = lpeg.P"--[["
    local commentBlockEnd = lpeg.P"]]"

    local untilCommentStart = lpeg.C((1-commentBlockStart)^0)
    local untilCommentEnd = lpeg.C((1-commentBlockEnd)^0)

    local commentBlock = commentBlockStart * untilCommentEnd * commentBlockEnd
    local codeBlock = untilCommentStart -- TODO ?
    local whitespace = lpeg.P(" ")^0 -- TODO more flexible

    -- TODO get entity name

    local function makeEntity(doc, src)
        return Entity { name = "TODO", doc = doc, src = src }
    end

    local documentedEntity = (commentBlock * whitespace * codeBlock) / makeEntity

    local parser = untilCommentStart / 0 * documentedEntity ^ 0


    local matched = {lpeg.match(parser, content)}
    return matched
end

class.OutputWriter()

function OutputWriter:_init(outputPath, packageName)
    self.outputFile = io.open(outputPath, 'w')
    self.packageName = packageName
    lapp.assert(self.outputFile, "could not open output file " .. outputPath)
    self:writeHeader()
end

function OutputWriter:write(text)
    self.outputFile:write(text)
end

function OutputWriter:writeHeader()
    self:write("# Documentation for " .. self.packageName .. "\n")
end

function OutputWriter:documentEntity(entity)
    logger:debug("Outputting markdown for " .. entity.name)

    local template = textx.Template([[
## Documentation for ${name}
${doc}
## (source code  for ${name})
    ${src}

----
]])
    local outputText = template:substitute {
        name = entity.name,
        doc = entity.doc,
        src = textx.indent(entity.src, 4)
    }
    self:write(outputText)
end

function OutputWriter:close()
    io.close(self.outputFile)
end

local function main()
    local args = processArgs()
    local content = readFile(args.input)
    local matched = parseSource(content)

    local packageName = "nnd.KLSparsity" -- TODO

    local writer = OutputWriter(args.output, packageName)
    local function handleEntity(entity)
        writer:documentEntity(entity)
    end

    tablex.foreachi(matched, handleEntity)
end

main()
