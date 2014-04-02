local path = require 'pl.path'
local file = require 'pl.file'
local stringx = require 'pl.stringx'
local http = require 'socket.http'
require 'dok'

function dokx._getVirtualEnvPath()
    return path.join(dokx._getDokxDir(), "dokx-search", "virtualenv")
end

local function inVirtualEnv(bin, ...)
    local virtualEnvPath = dokx._getVirtualEnvPath()
    if not path.isdir(virtualEnvPath) then
        local result = dokx._installSearchDependencies()
        if not result then
            return
        end
    end
    local virtualenv = path.join(virtualEnvPath, "bin", bin)
    return stringx.join(" ", { virtualenv, ... })
end

local function explainSearch()
    dokx.logger.warn([[

********************************************************************************
*                                                                              *
*   Hi! In order for documentation search to work, please install the          *
*   dependencies 'pip' and 'virtualenv'. This is optional, but recommended.    *
*                                                                              *
*   On OS X:                                                                   *
*                                                                              *
*   $ sudo easy_install pip                                                    *
*   $ sudo pip install virtualenv                                              *
*                                                                              *
*   On Ubuntu:                                                                 *
*                                                                              *
*   $ sudo apt-get install pip                                                 *
*   $ sudo pip install virtualenv                                              *
*                                                                              *
*   Then search will work and you won't get this message. Thanks!              *
*                                                                              *
*   In the event of further problems, please file an issue:                    *
*                                                                              *
*   https://github.com/d11/torch-dokx/issues                                   *
*                                                                              *
********************************************************************************

]])
end

function dokx._installSearchDependencies()
    dokx.logger.info("Installing dependencies for dokx-search")
    if not dokx._which("virtualenv") then
        dokx.logger.warn("Cannot find virtualenv command - unable to install dokx-search dependencies")
        explainSearch()
        return
    end
    if not dokx._which("pip") then
        dokx.logger.warn("Cannot find pip command - unable to install dokx-search dependencies")
        explainSearch()
        return
    end
    local python = dokx._which("python2.7")
    if not python then
        dokx.logger.warn("Cannot find python2.7 - unable to install dokx-search dependencies")
        explainSearch()
        return
    end
    local virtualEnvPath = dokx._getVirtualEnvPath()
    local result = os.execute("virtualenv --python=" .. python .. " " .. virtualEnvPath)
    if result ~= 0 then
        dokx.logger.warn("Virtualenv creation failed!")
        explainSearch()
        return
    end
    local requirements = path.join(dokx._getDokxDir(), "dokx-search", "requirements.txt")
    result = os.execute(inVirtualEnv("pip", "install -r " .. requirements))
    if result ~= 0 then
        dokx.logger.warn("Installing search dependencies failed!")
        explainSearch()
        return
    end
    local dokxDaemon = path.join(dokx._getDokxDir(), "dokx-search", "dokxDaemon.py")
    local virtualEnvLib = path.join(virtualEnvPath, "lib/python2.7")
    local dest = path.join(virtualEnvLib, "dokxDaemon.py")
    dokx.logger.info("Copying " .. dokxDaemon .. " -> " .. dest)
    file.copy(dokxDaemon, dest)
    return true
end

function dokx._runPythonScript(script, ...)
    local scriptPath = path.join(dokx._getDokxDir(), "dokx-search", script)
    local command = inVirtualEnv('python', scriptPath, ...)
    if not command then
        return
    end
    if dokx.inDebugMode() then
        command = command .. " --debug True"
    end
    dokx.logger.info("Executing: " .. command)
    os.execute(command)
end

--[[

Build an SQLite3 search index from a directory of Markdown files (which must contain section anchors)

Parameters:
 * `input` - string; path to directory of Markdown files
 * `output` - string; path to SQLite3 file to create / overwrite

Returns nil.

]]
function dokx.buildSearchIndex(input, output)
    if not path.isdir(input) then
        dokx.logger.error("dokx.buildSearchIndex: input is not a directory - " .. tostring(input))
        return
    end
    local python = dokx._which("python")
    if not python then
        dokx.logger.warn("Python not installed: dokx-search will not be available!")
        return
    end
    local script = path.join(dokx._getDokxDir(), "dokx-search", "dokx-build-search-index.py")

    if not path.isfile(script) then
        dokx.logger.warn("dokx-build-search-index.py not available: dokx-search will not be available!")
        return
    end

    dokx._runPythonScript(script, "--output", output, input)
end

function dokx._daemonIsRunning()
    local resultRest = http.request("http://localhost:8130/search/")
    local resultWeb = http.request("http://localhost:5000/")
    return resultRest ~= nil and resultWeb ~= nil
end

function dokx._restService(...)
    dokx._runPythonScript("rest/dokx-service-rest.py", ...)
end

function dokx._webService(...)
    dokx._runPythonScript("web/dokx-service-web.py", ...)
end

--[[

Stop the background processes that provide SQLite-backed full text search.

]]
function dokx.stopSearchServices()
  dokx._restService("stop")
  dokx._webService("stop")
end

--[[

Start or restart the background processes that provide SQLite-backed full text search.

Parameters:
 * `docRoot` - string; path to the root of the documentation tree in which the search DB is located.

]]
function dokx.runSearchServices(docRoot)
    docRoot = docRoot or dokx._luarocksHtmlDir()
    if dokx._daemonIsRunning() then
        return
    end
    dokx._restService("restart", " --database ", dokx._searchDBPath(docRoot))
    dokx._webService("restart", "--docs", docRoot)
end

function dokx._searchHTTP(query)
    return http.request("http://localhost:8130/search/" .. dokx._urlEncode(query) .. "/")
end

function dokx._searchGrep(query, docRoot)
    local grep = dokx._chooseCommand {"ag", "ack", "ack-grep", "grep"}
    if not grep then
        dokx.logger.error("doxk.search: can't find grep either - giving up, sorry!")
        return
    end
    os.execute(grep .. " --color -r '" .. query .. "' " .. dokx._markdownPath(docRoot))
end

function dokx._browserSearch(query)
    dokx._openBrowser("http://localhost:5000/search?query=" .. dokx._urlEncode(query))
end

--[[ Search all installed documentation using the given query.

Results are printed on stdout.

See the [SQLite documentation](http://www.sqlite.org/fts3.html#section_3) for details of permitted query forms.

Parameters:

* `query` - string; the text to search for
* `browse` - optional boolean (default: false); if true, open a browser with the results
* `docRoot` - optional string (default: luarocks tree); documentation tree to use

Examples:

    dokx.search("needle")
    dokx.search("nee*")
    dokx.search("lovely penguin")
    dokx.search("dishonourable NEAR/4 giraffe")

]]
function dokx.search(query, browse, docRoot)
    if not query or type(query) ~= 'string' then
        dokx.logger.error("dokx.search: expected a query string!")
        dok.help(dokx.search)
        return
    end
    docRoot = docRoot or dokx._luarocksHtmlDir()
    local result = dokx._searchHTTP(query)
    if not result then
        -- If no response, try to run server first
        dokx.logger.info("dokx.search: no response; trying to launch search service")
        dokx.runSearchServices(docRoot)
        -- Wait for process to start... (ick!)
        os.execute("sleep 1")
        result = dokx._searchHTTP(query)
    end

    -- If still no result, fall back to grep
    if not result then
        dokx.logger.warn("dokx.search: no result from search process - falling back to grep.")
        dokx._searchGrep(query, docRoot)
        return
    end

    if browse then
        dokx._browserSearch(query)
        return
    end

    -- Decode JSON
    local json = require 'json'
    local decoded = json.decode(result)

    -- Format results
    local n = decoded.meta.results
    if n == 0 then
        print("No results for '"  .. decoded.query .. "'.")
        return
    end

    print(n .. " results for '"  .. decoded.query .. "':")

    for id, resultInfo in ipairs(decoded.results) do
        local snip = resultInfo.snippets[1]
        local black = '\27[0;30m'
        local cyan = '\27[1;36m'
        local _yellow = '\27[43m'
        local clear = '\27[0m'
        print(cyan .. "#" .. id .. " " .. resultInfo.tag .. clear)
        snip = snip:gsub('<b>(.-)</b>', black .. _yellow .. '%1' .. clear)
        snip = stringx.strip(snip)
        print(snip .. " \n")
    end

end
