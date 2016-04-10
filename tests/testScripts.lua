require 'dokx'
local stringx = require 'pl.stringx'
local dir = require 'pl.dir'
local tester = torch.Tester()
local myTests = {}

local optionalScripts = {
    ['dokx-combine-html'] = true,
    ['dokx-combine-toc'] = true,
    ['dokx-extract-toc'] = true,
    ['dokx-extract-markdown'] = true,
    ['dokx-generate-html'] = true,
    ['dokx-generate-html-index'] = true,
}

local function runScript(script, ...)
    if not dokx._which(script) and optionalScripts[script] then
        return
    end
    local returnCode = os.execute(script .. " " .. stringx.join(" ", { ... }) .. " &> /dev/null")
    tester:asserteq(returnCode, 0, "Non-zero return code: " .. script)
end

local withTmpDir = dokx._withTmpDir

function myTests:test_browse()
    runScript("env BROWSER=cat dokx-browse")
end
function myTests:test_build_package_docs()
    withTmpDir(function(tmpDir)
        runScript("dokx-build-package-docs", "--output", tmpDir, "--repl", tmpDir, tmpDir)
    end)
end
function myTests:test_build_search_index()
    withTmpDir(function(tmpDir)
        dir.makepath(dokx._markdownPath(tmpDir))
        runScript("dokx-build-search-index", tmpDir)
    end)
end
function myTests:test_combine_html()
    withTmpDir(function(tmpDir)
        runScript("dokx-combine-html", tmpDir)
    end)
end
function myTests:test_combine_toc()
    withTmpDir(function(tmpDir)
        local package = "myPackage"
        runScript("dokx-combine-toc", "--package", package, tmpDir)
    end)
end
function myTests:test_extract_markdown()
    withTmpDir(function(tmpDir)
        local package = "myPackage"
        local luaPath = path.join(tmpDir, "test.lua")
        file.write(luaPath, "--[[ Test file ]]")
        runScript("dokx-extract-markdown", "--output", tmpDir, "--package", package, luaPath)
    end)
end
function myTests:test_extract_toc()
    withTmpDir(function(tmpDir)
        local package = "myPackage"
        local luaPath = path.join(tmpDir, "test.lua")
        file.write(luaPath, "--[[ Test file ]]")
        runScript("dokx-extract-toc", "--output", tmpDir, "--package", package, "--packagePath", tmpDir, luaPath)
    end)
end
function myTests:test_generate_html()
    withTmpDir(function(tmpDir)
        local mdPath = path.join(tmpDir, "test.md")
        file.write(mdPath, "# Test heading")
        runScript("dokx-generate-html", "--output", tmpDir, mdPath)
    end)
end
function myTests:test_generate_html_index()
    withTmpDir(function(tmpDir)
        runScript("dokx-generate-html-index", tmpDir)
    end)
end
function myTests:test_init()
    withTmpDir(function(tmpDir)
        runScript("dokx-init", tmpDir)
    end)
end
function myTests:test_luarocks()
    withTmpDir(function(tmpDir)
        runScript("dokx-luarocks", tmpDir)
    end)
end
function myTests:test_search()
    withTmpDir(function(tmpDir)
        local query = "Function"
        runScript("dokx-search", query)
    end)
end
function myTests:test_update_from_git()
    withTmpDir(function(tmpDir)
        local git = "git@github.com:d11/torch-dokx.git"
        runScript("dokx-update-from-git", "--output", tmpDir, git)
    end)

end

tester:add(myTests):run()
