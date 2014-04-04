do
    --[[ Information about a package ]]
    local Package, parent = torch.class("dokx.Package")
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
end
