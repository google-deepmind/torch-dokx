local path = require 'pl.path'
local file = require 'pl.file'
local http = require 'socket.http'

function dokx._getVirtualEnvPath()
    return path.join(dokx._getDokxDir(), "dokx-search", "virtualenv")
end

local function inVirtualEnv(...)
    local virtualEnvPath = dokx._getVirtualEnvPath()
    if not path.isdir(virtualEnvPath) then
        dokx._installSearchDependencies()
    end
    local virtualenv = path.join(virtualEnvPath, "bin/activate")
    return stringx.join(" ", { 'source', virtualenv, '&&', ... })
end

function dokx._installSearchDependencies()
    dokx.logger:info("Installing dependencies for dokx-search")
    if not dokx._which("virtualenv") then
        dokx.logger:error("Cannot find virtualenv command - unable to install dokx-search dependencies")
        return
    end
    if not dokx._which("pip") then
        dokx.logger:error("Cannot find pip command - unable to install dokx-search dependencies")
        return
    end
    local python = dokx._which("python2.7")
    if not python then
        dokx.logger:error("Cannot find python2.7 - unable to install dokx-search dependencies")
        return
    end
    local virtualEnvPath = dokx._getVirtualEnvPath()
    os.execute("virtualenv --python=" .. python .. " " .. virtualEnvPath)
    local requirements = path.join(dokx._getDokxDir(), "dokx-search", "requirements.txt")
    os.execute(inVirtualEnv("pip install -r " .. requirements))
    local dokxDaemon = path.join(dokx._getDokxDir(), "dokx-search", "dokxDaemon.py")
    local virtualEnvLib = path.join(virtualEnvPath, "lib/python2.7")
    local dest = path.join(virtualEnvLib, "dokxDaemon.py")
    dokx.logger:info("Copying " .. dokxDaemon .. " -> " .. dest)
    file.copy(dokxDaemon, dest)
end

function dokx._runPythonScript(script, ...)
    local scriptPath = path.join(dokx._getDokxDir(), "dokx-search", script)
    local command = inVirtualEnv('python', scriptPath, ...)
    dokx.logger:info("Executing: " .. command)
    os.execute(command)
end

function dokx.buildSearchIndex(input, output)
    if not path.isdir(input) then
        dokx.logger:error("dokx.buildSearchIndex: input is not a directory - " .. tostring(input))
        return
    end
    local python = dokx._which("python")
    if not python then
        dokx.logger:warn("Python not installed: dokx-search will not be available!")
        return
    end
    local script = path.join(dokx._getDokxDir(), "dokx-search", "dokx-build-search-index.py")

    if not path.isfile(script) then
        dokx.logger:warn("dokx-build-search-index.py not available: dokx-search will not be available!")
        return
    end

    dokx._runPythonScript(script, "--output", output, input)
end

function dokx._daemonIsRunning()
    local resultRest = http.request("http://localhost:8130/search/")
    local resultWeb = http.request("http://localhost:5000/")
    return resultRest ~= nil and resultWeb ~= nil
end

function dokx.runSearchServices()
    if dokx._daemonIsRunning() then
        return
    end
    dokx._runPythonScript("rest/dokx-service-rest.py", " --database ", dokx._luarocksSearchDB())
    dokx._runPythonScript("web/dokx-service-web.py", "--docs", dokx._luarocksHtmlDir())
end

function dokx._searchHTTP(query)
    return http.request("http://localhost:8130/search/" .. dokx._urlEncode(query) .. "/")
end

function dokx._searchGrep(query)
    local grep = dokx._chooseCommand {"ag", "ack", "ack-grep", "grep"}
    if not grep then
        dokx.logger:error("doxk.search: can't find grep either - giving up, sorry!")
        return
    end
    local searchDir = path.join(dokx._luarocksHtmlDir(), "_markdown")
    os.execute(grep .. " --color -r '" .. query .. "' " .. searchDir)
end

function dokx._browserSearch(query)
    dokx._openBrowser("http://localhost:5000/search?query=" .. dokx._urlEncode(query))
end

function dokx.search(query, browse)
    local result = dokx._searchHTTP(query)
    if not result then
        -- If no response, try to run server first
        dokx.logger:info("dokx.search: no response; trying to launch search service")
        dokx.runSearchServices()
        -- Wait for process to start... (ick!)
        os.execute("sleep 1")
        result = dokx._searchHTTP(query)
    end

    -- If still no result, fall back to grep
    if not result then
        dokx.logger:warn("dokx.search: no result from search process - falling back to grep.")
        dokx._searchGrep(query)
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
        print(string.rep("-", 80))
        print(" #" .. id .. " " .. resultInfo.tag)
        local snip = resultInfo.snippets[1]
        local yellow = '\27[1;33m'
        local clear = '\27[0m'
        snip = snip:gsub('<b>(.-)</b>', yellow .. '%1' .. clear)
        print(" ... " .. snip .. " ... \n")
    end

end
