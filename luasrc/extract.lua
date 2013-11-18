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

    local untilCommentStart = (1-commentBlockStart)^0
    local untilCommentEnd = lpeg.C((1-commentBlockEnd)^0)

    local whitespace = lpeg.S(" \t\n")^0
    local commentBlock = commentBlockStart * untilCommentEnd * commentBlockEnd
    local functionSignature = lpeg.C((1-lpeg.P("("))^1)
--    local functionSignature = (lpeg.C(1-lpeg.S(":."))^1 * lpeg.S(":."))^-1 * lpeg.C(1-lpeg.P("("))^1
    local functionDefinition = lpeg.P("function") * whitespace * functionSignature
    local entityDefinition = functionDefinition
    local codeBlock = lpeg.C(entityDefinition * untilCommentStart) -- TODO ?
--    local codeBlock = untilCommentStart -- TODO ?

    -- TODO get entity name

    local function makeEntity(doc, src, name)
        return Entity { name = name, doc = doc, src = src }
    end

    local documentedEntity = (commentBlock * whitespace * codeBlock) / makeEntity

    local function err(_, i)
        local contextSize = 20
        local surrounding = content:sub(i - contextSize, i + contextSize)
        local lines = stringx.splitlines(surrounding)
        local lineIndex = 1
        local charIndex = -contextSize
        local context = lines[1]
        while charIndex < 0 do
            local line = lines[lineIndex]
            charIndex = charIndex + string.len(line) + 1
            lineIndex = lineIndex + 1
            context = context .. lines[lineIndex] .. "\n"
        end
        context = context .. string.rep(" ", charIndex) .. "^^^\n"
        while lineIndex < #lines do
            context = context .. lines[lineIndex] .. "\n"
            lineIndex = lineIndex + 1
        end

        -- TODO: this is not accurate, due to line breaks
--        local context = content:sub(i - contextSize, i + contextSize) .. "\n" .. string.rep(" ", contextSize-2) .. "^^^\n"

        local errMsg = "failed to parse source at position " .. i .. ":\n " .. context
        error(errMsg)
    end
    local parser = untilCommentStart / 0 * documentedEntity ^ 0 * (-1 + lpeg.P(err))

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
## (source code for ${name})
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
