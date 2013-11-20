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
--]]
function MarkdownWriter:_init(outputPath, packageName)
    self.outputFile = io.open(outputPath, 'w')
    self.packageName = packageName
    lapp.assert(self.outputFile, "could not open output file " .. outputPath)
    self:writeHeader()
end

--[[ Append a string to the output

Args:
 * `text` :: string; text to append

Returns: nil
--]]
function MarkdownWriter:write(text)
    self.outputFile:write(text)
end

--[[ Add the package header to the output ]]
function MarkdownWriter:writeHeader()
    self:heading("Module " .. self.packageName)
end

--[[ Add a heading to the output

Args:
 * `text` :: string; the heading text

Returns: nil
--]]
function MarkdownWriter:heading(text)
    self:write("### ".. text .. "\n\n")
end

--[[ Add markdown for a documented function

Args:
 * `entity` :: DocumentedFunction object

Returns: nil
--]]
function MarkdownWriter:documentEntity(entity)
    logger:debug("Outputting markdown for " .. entity:name())

    local valueTable = {
        name = entity:name() or "{missing name}",
        doc = entity:doc() or "{missing docs}",
    }

    local outputText = "#### " .. valueTable.name .. "\n" .. valueTable.doc

    self:write(outputText)
end

--[[ Add markdown for an undocumented function

Args:
 * `entity` :: Function object

Returns: nil
--]]
function MarkdownWriter:undocumentedFunction(entity)
    logger:debug("Outputting markdown for " .. entity.name)

    local valueTable = {
        name = entity.name or "{missing name}",
    }

    local outputText = " * " .. valueTable.name .. "\n"

    self:write(outputText)

end

--[[ Close the writer. _Must be called before exiting_. ]]
function MarkdownWriter:close()
    io.close(self.outputFile)
end
