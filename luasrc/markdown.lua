--- Handle Markdown generation

require 'logging.console'
local logger = logging.console()
logger:setLevel(logging.DEBUG)

local textx = require 'pl.text'

class.MarkdownWriter()

function MarkdownWriter:_init(outputPath, packageName)
    self.outputFile = io.open(outputPath, 'w')
    self.packageName = packageName
    lapp.assert(self.outputFile, "could not open output file " .. outputPath)
    self:writeHeader()
end

function MarkdownWriter:write(text)
    self.outputFile:write(text)
end

function MarkdownWriter:writeHeader()
    self:write("# Module " .. self.packageName .. "\n\n")
end

function MarkdownWriter:documentEntity(entity)
    logger:debug("Outputting markdown for " .. entity:name())

    local template = textx.Template([[
## Function ${name}
${doc}

]])
    local outputText = template:substitute {
        name = entity:name(),
        doc = entity:doc(),
    }
    self:write(outputText)
end

function MarkdownWriter:close()
    io.close(self.outputFile)
end
