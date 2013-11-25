
--[[ Read the whole of the given file's contents, and return it as a string.

Args:
 * `inputPath` - path to a file

Returns: string containing the contents of the file

--]]
function dokx._readFile(inputPath)
    if not path.isfile(inputPath) then
        error("Not a file: " .. tostring(inputPath))
    end
    dokx.logger:debug("Opening " .. tostring(inputPath))
    local inputFile = io.open(inputPath, "rb")
    if not inputFile then
        error("Could not open: " .. tostring(inputPath))
    end
    local content = inputFile:read("*all")
    inputFile:close()
    return content
end

