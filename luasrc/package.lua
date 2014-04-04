local dir = require 'pl.dir'
do
    --[[ Information about a package ]]
    local Package, parent = torch.class("dokx.Package")
    --[[ Create a package object
    Parameters:
    * `name` - name of the package
    * `path` - path of the package
    ]]
    function Package:__init(name, path)
        self._name = name
        self._path = path
    end
    function Package:name()
        return self._name
    end
    function Package:path()
        return self._path
    end
    --[[ Return a table of lua files in the package (except those excluded by the config) ]]
    function Package:luaFiles(config)
        local luaFiles = dir.getallfiles(self._path, "*.lua")
        luaFiles = dokx._filterFiles(luaFiles, config.filter, false)
        luaFiles = dokx._filterFiles(luaFiles, config.exclude, true)
        return luaFiles
    end
    --[[ Return a table of markdown files in the package (except those excluded by the config) ]]
    function Package:mdFiles(config)
        local luaFiles = dir.getallfiles(self._path, "*.md")
        luaFiles = dokx._filterFiles(luaFiles, config.exclude, true)
        return luaFiles
    end
    --[[ Return a table of image files in the package ]]
    function Package:imageFiles(config)
        local imageFiles = dir.getallfiles(self._path, "*.png")
        return imageFiles
    end
end
