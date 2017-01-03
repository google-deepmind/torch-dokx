local search = require 'luarocks.search'
local cfg = require 'luarocks.cfg'
local site_config = require 'luarocks.site_config'
local deps = require 'luarocks.deps'
local path = require("luarocks.path")
local util = require 'luarocks.util'
local Set = require 'pl.Set'
local stringx = require 'pl.stringx'
local dir = require 'pl.dir'
local pathx = require 'pl.path'

-- Largely lifted from luarocks show
local function rockspec(name)

    local results = {}
    local query = search.make_query(name)
    query.exact_name = true
    local tree_map = {}
    local trees = cfg.rocks_trees
    for _,tree in ipairs(trees) do
        local rocks_dir = path.rocks_dir(tree)
        tree_map[rocks_dir] = tree
        search.manifest_search(results, rocks_dir, query)
    end

    if not next(results) then
        return nil,"cannot find package "..name.."\nUse 'list' to find installed rocks."
    end

    local version = nil
    local repo_url
    local package, versions = util.sortedpairs(results)()
    --question: what do we do about multiple versions? This should
    --give us the latest version on the last repo (which is usually the global one)
    for vs, repositories in util.sortedpairs(versions, deps.compare_versions) do
        if not version then version = vs end
        for _, rp in ipairs(repositories) do repo_url = rp.repo end
    end

    local repo = tree_map[repo_url]
	local rockspec_file = path.rockspec_file(name, version, repo)

	return rockspec_file
end

local function getRockspecVars(rockspecPath)
    local rockspecEnv = { }
    assert(rockspecPath)
    local getRockspec = assert(loadfile(rockspecPath))
    setfenv(getRockspec, rockspecEnv)
    getRockspec()
    assert(rockspecEnv.source, "Rockspec " .. rockspecPath .. " should contain 'source' definition")
    return rockspecEnv
end

local function repository(name)
    local rockspec, err = rockspec(name)
    if not rockspec then
        error("No rockspec for " .. name .. ": " .. err)
    end
    local rockspecEnv = getRockspecVars(rockspec)
    local source = rockspecEnv.source
	local url = stringx.replace(source.url, 'git+file://', '', 1)
	return url, source.branch or source.tag or 'master'
end


local function validDirectory(path)
	if not pathx.isdir(path) then
        dir.makepath(path)
	end
	return path
end


local function replDir(package)
	return validDirectory(site_config.LUAROCKS_ROCKS_TREE .. cfg.lua_modules_path .. '/' .. package .. '/doc')
end


function dokx._luarocksHtmlDir()
	return validDirectory(site_config.LUAROCKS_ROCKS_TREE .. 'share/doc/dokx')
end

function dokx._luarocksSearchDB()
    return dokx._searchDBPath(dokx._luarocksHtmlDir())
end

function dokx._luarocksMarkdownDir()
    return dokx._markdownPath(dokx._luarocksHtmlDir())
end

local function buildSearchIndex()
    local dbPath = dokx._luarocksSearchDB()
    local markdownPath = dokx._luarocksMarkdownDir()
    dokx.buildSearchIndex(markdownPath, dbPath)
end

local function getDescription(rockspecEnv)
    local description = ""
    if rockspecEnv.description and rockspecEnv.description.summary then
        description = rockspecEnv.description.summary
    end
    return description
end

local function getRockspecPathForInstalledRock(rock)
    local cmd = io.popen("luarocks show " .. rock .. " --rockspec")
    local result = stringx.strip(cmd:read("*all"))
    if result == "" then
        error("Could not get rockspec for installed rock " .. rock)
    end
    return result
end

--[[

Wrapper for the standard 'luarocks install' command, which builds documentation
and a search index in addition to building the package itself.

Parameters:
 * `args` - table; args for luarocks

Returns nil.

]]
function dokx.luarocksInstall(args)
    assert(os.execute('luarocks ' .. table.concat(arg, ' ')) == 0, 'Error executing luarocks')
	local package = args[#args]
    local rockspecPath = getRockspecPathForInstalledRock(package)
    local rockspecEnv = {}
    if rockspecPath then
        rockspecEnv = getRockspecVars(rockspecPath)
    end
	local url, branch = repository(package)
	local dir = dokx._luarocksHtmlDir()
    dokx.updateFromGit({url}, branch, nil, dokx._luarocksHtmlDir(), replDir(package), getDescription(rockspecEnv), nil)
    buildSearchIndex()
end

--[[

Wrapper for the standard 'luarocks make' command, which builds documentation
and a search index in addition to building the package itself.

Parameters:
 * `args` - table; args for luarocks

Returns nil.

]]
function dokx.luarocksMake(args)
    assert(os.execute('luarocks ' .. table.concat(arg, ' ')) == 0, 'Error executing luarocks')
    local rockspecPath = args[#args]
    if rockspecPath == 'make' then
        local rockspecs = dir.getfiles(pathx.currentdir(), "*.rockspec")
        if #rockspecs == 1 then
            rockspecPath = rockspecs[1]
        else
            error("Please specify a rockspec file to use")
        end
    end
    local rockspecEnv = getRockspecVars(rockspecPath)
	dokx.buildPackageDocs(
            dokx._luarocksHtmlDir(),
            pathx.currentdir(),
            replDir(rockspecEnv.package),
            getDescription(rockspecEnv)
        )
    buildSearchIndex()
end
