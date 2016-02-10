local file = require 'pl.file'
local textx = require 'pl.text'
local stringx = require 'pl.stringx'
local tablex = require 'pl.tablex'
local path = require 'pl.path'
local dir = require 'pl.dir'

--[[ Return a table describing the .dokx config format

Table entries are themselves tables, with keys 'key', 'description' and 'default'

]]
function dokx.configSpecification()
    return {
        {
            key = "filter",
            description = "pattern or table of patterns; file paths to include",
            default = 'nil'
        },
        {
            key = "exclude",
            description = "pattern or table of patterns; file paths to exclude",
            default = "{ 'test', 'build' }"
        },
        {
            key = "tocLevel",
            description = "string; level of detail for table of contents for inline docs: 'class', 'function' or 'none'",
            default = "'function'"
        },
        {
            key = "tocLevelTopSection",
            description = "integer; max depth of table of contents for standalone .md docs",
            default = "nil"
        },
        {
            key = "sectionOrder",
            description = "table; paths of .md files in order of priority",
            default = "nil"
        },
        {
            key = "tocIncludeFilenames",
            description = "boolean; whether to include filenames as a top level in the table of contents",
            default = "false"
        },
        {
            key = "mathematics",
            description = "boolean; whether to process mathematics blocks",
            default = "true"
        },
        {
            key = "packageName",
            description = "string; override the inferred package namespace",
            default = "nil"
        },
        {
            key = "githubURL",
            description = "string; $githubUser/$githubProject - used for generating links, if present",
            default = "nil"
        },
        {
            key = "includeLocal",
            description = "boolean; whether to include local functions",
            default = "false"
        },
        {
            key = "includePrivate",
            description = "boolean; whether to include private functions (i.e. those that begin with an underscore)",
            default = "false"
        },
        {
            key = "section",
            description = "string; name of the section under which this package should be grouped in the main menu",
            default = "Miscellaneous"
        }
    }
end

-- Calling this puts dokx into debug mode.
function dokx.debugMode()
    dokx.logger.level = logroll.DEBUG
    dokx._inDebugMode = true
end

-- Return true if dokx is in debug mode.
function dokx.inDebugMode()
    return dokx._inDebugMode
end

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

function dokx._withTmpDir(func)
    local tmpDir = dokx._mkTemp()
    func(tmpDir)
    dir.rmtree(tmpDir)
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
    dokx.logger.debug("Opening " .. tostring(inputPath))
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
    return filePath:sub(1, -string.len(extension) - 1) .. newExtension
end

function dokx._searchDBPath(docRoot)
    return path.join(docRoot, "_search.sqlite3")
end

function dokx._markdownPath(docRoot)
    return path.join(docRoot, "_markdown")
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
    local lines = stringx.splitlines(text)
    tablex.transform(function(line)
        line = line:gsub("^%[=*%[", "")
        line = line:gsub("%]=*%]$", "")
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
        line = line:gsub("^%[=*%[", "")
        line = line:gsub("%]=*%]$", "")
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
    local configPath
    if packagePath then
        if path.isfile(packagePath) then
            configPath = packagePath
        else
            configPath = path.join(packagePath, ".dokx")
        end
    end
    local configTable = {}

    -- If config file exists, try to load it
    if configPath and path.isfile(configPath) then
        local configFunc, err = loadfile(configPath)
        if err then
            error("dokx._loadConfig: error loading dokx config " .. configPath .. ": " .. err)
        end
        configTable = configFunc()
        if not configTable or type(configTable) ~= 'table' then
            error("dokx._loadConfig: dokx config file must return a lua table! " .. configPath)
        end
    end

    local configSpec = dokx.configSpecification()
    local allowedKeys = {}
    local defaultValues = {}

    for _, configEntry in pairs(configSpec) do
        allowedKeys[configEntry.key] = true
        defaultValues[configEntry.key] = configEntry.default
    end

    -- Check for unknown keys
    for key, value in pairs(configTable) do
        if not allowedKeys[key] then
            error("dokx._loadConfig: unknown key '" .. key .. "' in dokx config file " .. configPath)
        end
    end

    -- Assign defaults, where value was not specified
    for key, _ in pairs(allowedKeys) do
        if configTable[key] == nil then
            local default = loadstring("return " .. defaultValues[key])()
            dokx.logger.info("dokx._loadConfig: no value specified for key '" .. key .. "' - using default: " .. tostring(default))
            configTable[key] = default
        end
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
                dokx.logger.info("dokx.buildPackageDocs: skipping file excluded by filter: " .. x)
            end
            return admit
        end)
    end

    return files
end

function dokx._getDokxDir()
    return path.dirname(debug.getinfo(1, 'S').source:gsub('^[@=]', ''))
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

function dokx._which(command)
    local cmd = io.popen("which " .. command)
    local result = stringx.strip(cmd:read("*all"))
    cmd:close()
    if result == '' then
        return nil
    end
    return result
end

--[[

Given a table of possible commands, return the path for the first one that exists, or nil if none do.

Example:

    dokx._chooseCommand { 'open', 'xdg-open' }

--]]
function dokx._chooseCommand(commands)

    for _, command in ipairs(commands) do
        local result = dokx._which(command)
        if result then
            return result
        end
    end
    return nil
end


function dokx._urlEncode(str)
  if (str) then
    str = string.gsub (str, "\n", "\r\n")
    str = string.gsub (str, "([^%w %-%_%.%~])",
        function (c) return string.format ("%%%02X", string.byte(c)) end)
    str = string.gsub (str, " ", "+")
  end
  return str
end

function dokx._openBrowser(url)
    local browser = dokx._chooseCommand { "open", "xdg-open", "firefox" }
    if not browser then
        dokx.logger.error("dokx.browse: could not find a browser")
        return
    end
    os.execute(browser .. " " .. url)
end

function dokx._copyFilesToDir(files, dirPath, copyFunc)
    local outputs = {}
    copyFunc = copyFunc or file.copy
    tablex.foreach(files, function(filePath)
        local dest = path.join(dirPath, path.basename(filePath))
        if path.isfile(dest) then
            dokx.logger.warn("*** Overwriting markdown file " .. dest .. " ***")
        end
        copyFunc(filePath, dest)
        table.insert(outputs, dest)
    end)
    return outputs
end

function dokx._pruneFunctions(config, documentedFunctions, undocumentedFunctions)
    if not config or not config.includeLocal then
        local function notLocal(x)
            if x:isLocal() then
                dokx.logger.info("Excluding local function " .. x:fullname())
                return false
            end
            return true
        end
        documentedFunctions = tablex.filter(documentedFunctions, notLocal)
        undocumentedFunctions = tablex.filter(undocumentedFunctions, notLocal)
    end
    if not config or not config.includePrivate then
        local function notPrivate(x)
            if x:isPrivate() then
                dokx.logger.info("Excluding private function " .. x:fullname())
                return false
            end
            return true
        end
        documentedFunctions = tablex.filter(documentedFunctions, notPrivate)
        undocumentedFunctions = tablex.filter(undocumentedFunctions, notPrivate)
    end
    return documentedFunctions, undocumentedFunctions
end

