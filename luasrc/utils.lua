local textx = require 'pl.text'
local stringx = require 'pl.stringx'
local path = require 'pl.path'

--[[ Return true if x is an instance of the given class ]]
function dokx._is_a(x, className)
    return torch.typename(x) == className
end

--[[ Create a temporary directory and return its path ]]
function dokx._mkTemp()
    local file = io.popen("mktemp -d -t dokx_XXXXXX")
    local name = stringx.strip(file:read("*all"))
    file:close()
    return name
end

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


--[[ Given the path to a directory, return the name of the last component ]]
function dokx._getLastDirName(dirPath)
    local split = tablex.filter(stringx.split(path.normpath(path.abspath(dirPath)), "/"), function(x) return x ~= '' end)
    local packageName = split[#split]
    if stringx.strip(packageName) == '' then
        error("malformed package name for " .. dirPath)
    end
    return packageName
end

--[[ Given a path to a file, an expected extension, and a new extension, return
the path to a file with the same name but the new extension.

Throws an error if the file does not have the expected extension.
--]]
function dokx._convertExtension(extension, newExtension, filePath)
    if not stringx.endswith(filePath, "." .. extension)  then
        error("Expected ." .. extension .. " file")
    end
    return path.basename(filePath):sub(1, -string.len(extension) - 1) .. newExtension
end

--[[ Create a function that will prepend the given path prefix onto its argument.

Example:

    > f = dokx._prependPath("/usr/local")
    > print(f("bin"))
    "/usr/local/bin"

--]]
function dokx._prependPath(prefix)
    return function(suffix)
        return path.join(prefix, suffix)
    end
end

--[[ Given a comment string, remove extraneous symbols and spacing ]]
function dokx._normalizeComment(text)
    text = stringx.strip(tostring(text))
    if stringx.startswith(text, "[[") then
        text = stringx.strip(text:sub(3))
    end
    if stringx.endswith(text, "]]") then
        text = stringx.strip(text:sub(1, -3))
    end
    local lines = stringx.splitlines(text)
    tablex.transform(function(line)
        if stringx.startswith(line, "--") then
            local chopIndex = 3
            if stringx.startswith(line, "-- ") then
                chopIndex = 4
            end
            line = line:sub(chopIndex)
        end
        if stringx.endswith(line, "--") then
            line = line:sub(1, -3)
        end
        return line
    end, lines)
    text = stringx.join("\n", lines)

    -- Ensure we end with a new line
    if text[#text] ~= '\n' then
        text = text .. "\n"
    end
    return text
end

function dokx._loadConfig(packagePath)
    local configPath = path.join(packagePath, ".dokx")
    if not path.isfile(configPath) then
        return {}
    end
    local configFunc, err = loadfile(configPath)
    if err then
        error("dokx._loadConfig: error loading dokx config " .. configPath .. ": " .. err)
    end
    local configTable = configFunc()
    if not configTable or type(configTable) ~= 'table' then
        error("dokx._loadConfig: dokx config file must return a lua table! " .. configPath)
    end
    local allowedKeys = {
        filter = true,
        exclude = true,
        tocLevel = true,
        mathematics = true,
        packageName = true,
        githubURL = true
    }
    for key, value in pairs(configTable) do
        if not allowedKeys[key] then
            error("dokx._loadConfig: unknown key '" .. key .. "' in dokx config file " .. configPath)
        end
    end
    if configTable.mathematics == nil then
        configTable.mathematics = true
    end

    return configTable
end

function dokx._filterFiles(files, pattern, invert)
    if not pattern then
        return files
    end
    if type(pattern) == 'string' then
        pattern = { pattern }
    end

    for _, patternString in ipairs(pattern) do
        files =  tablex.filter(files, function(x)
            local admit = string.find(x, patternString)
            if invert then
                admit = not admit
            end
            if not admit then
                dokx.logger:info("dokx.buildPackageDocs: skipping file excluded by filter: " .. x)
            end
            return admit
        end)
    end

    return files
end

function dokx._getDokxDir()
    return path.dirname(debug.getinfo(1, 'S').source):sub(2)
end

function dokx._getTemplate(templateFile)
    local dokxDir = dokx._getDokxDir()
    local templateDir = path.join(dokxDir, "templates")
    return path.join(templateDir, templateFile)
end

function dokx._getTemplateContents(templateFile)
    return textx.Template(dokx._readFile(dokx._getTemplate(templateFile)))
end

function dokx._sanitizePath(pathString)
    local sanitized = path.normpath(path.abspath(pathString))
    if stringx.endswith(sanitized, "/.") then
        sanitized = sanitized:sub(1, -3)
    end
    return sanitized
end
