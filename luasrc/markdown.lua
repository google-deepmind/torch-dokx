--- Handle Markdown generation

require 'logging.console'
local logger = logging.console()
logger:setLevel(logging.DEBUG)

local textx = require 'pl.text'

class.MarkdownWriter()

--[[ Constructor for MarkdownWriter

Args:
 * `outputPath` - string; path to write to
 * `packageName` - string; name of package being documented

Returns: new MarkdownWriter object
]]
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
    print(entity:str())
    logger:debug("Outputting markdown for " .. entity:name())

    local valueTable = {
        name = entity:name() or "{missing name}",
        doc = entity:doc() or "{missing docs}",
    }

    local outputText = "## " .. valueTable.name .. "\n" .. valueTable.doc

--    local outputText = template:substitute(valueTable)
    self:write(outputText)
end

function MarkdownWriter:close()
    io.close(self.outputFile)
end
