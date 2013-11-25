--- Handle Markdown generation

local textx = require 'pl.text'

-- This class opens and writes to a markdown file
local MarkdownWriter = torch.class("dokx.MarkdownWriter")

--[[ Constructor for MarkdownWriter

Args:
 * `outputPath` - string; path to write to

Returns: new MarkdownWriter object
--]]
function MarkdownWriter:__init(outputPath)
    self.outputFile = io.open(outputPath, 'w')
    lapp.assert(self.outputFile, "could not open output file " .. outputPath)
end

--[[ Append a string to the output

Args:
 * `text` :: string; text to append

Returns: nil
--]]
function MarkdownWriter:write(text)
    self.outputFile:write(text)
end

--[[ Add an anchor to the output

Args:
 * `name` :: string; name for the anchor

Returns: nil
--]]
function MarkdownWriter:anchor(name)
    self:write([[<a name="]] .. name .. [["/>]] .. "\n")
end

--[[ Add a heading to the output

Args:
 * `text` :: string; the heading text
 * `level` :: int; level of the heading (lower means bigger)

Returns: nil
--]]
function MarkdownWriter:heading(level, text, rhs)
    self:write(string.rep("#", level) .. " ".. text .. " " .. string.rep("#", level) .. "\n\n")
end

--[[ Add markdown for a documented class

Args:
 * `entity` :: dokx.Class object

Returns: nil
--]]
function MarkdownWriter:class(entity)
    dokx.logger:debug("Outputting markdown for " .. entity:name())
    self:anchor(entity:fullname() .. ".dok")
    self:heading(3, entity:name())
    self:write(entity:doc())
end

--[[ Add markdown for a documented function

Args:
 * `entity` :: DocumentedFunction object

Returns: nil
--]]
function MarkdownWriter:documentedFunction(entity)
    dokx.logger:debug("Outputting markdown for " .. entity:name())
    self:anchor(entity:fullname())
    self:heading(4, entity:name())
    self:write(entity:doc())
end

--[[ Add markdown for an undocumented function

Args:
 * `entity` :: Function object

Returns: nil
--]]
function MarkdownWriter:undocumentedFunction(entity)
    dokx.logger:debug("Outputting markdown for " .. entity:name())
    self:anchor(entity:fullname())
    self:write(" * `" .. entity:name() .. "`\n")
end

--[[ Close the writer. _Must be called before exiting_. ]]
function MarkdownWriter:close()
    io.close(self.outputFile)
end
