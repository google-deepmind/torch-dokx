local stringx = require 'pl.stringx'

do
    local Entity, parent = torch.class('dokx.Entity')

    --[[ Abstract Base Class for items extracted from lua source.

    Fields `_package`, `_file` and `_lineNo` keep track of where the item was extracted from.

    --]]
    function Entity:__init(package, file, lineNo)
        assert(package)
        assert(file)
        assert(lineNo)
        self._package = package
        self._file = file
        self._lineNo = lineNo
    end

    -- Return the name of the package from which this documentation entity was extracted
    function Entity:package()
        return self._package
    end

    -- Return the name of the source file from which this documentation entity was extracted
    function Entity:file()
        return self._file
    end

    -- Return the (last) line number of this documentation entity in the source file
    function Entity:lineNo()
        return self._lineNo
    end
end

--[[ Information about a comment string, as extracted from lua source ]]
do
    local Comment, parent = torch.class("dokx.Comment", "dokx.Entity")
    function Comment:__init(text, isFirst, ...)
        parent.__init(self, ...)
        self._isFirst = isFirst
        self._text = dokx._normalizeComment(text)
    end
    -- Return a new dokx.Comment by concatenating this with another comment
    function Comment:combine(other)
        return dokx.Comment(self._text .. other._text, self._isFirst, self._package, self._file, self._lineNo)
    end
    -- Return a string representation of this Comment entity
    function Comment:str()
        return "{Comment: " .. self._text .. "}"
    end
    -- Return this comment's text
    function Comment:text()
        return self._text
    end
    -- Returns true if this comment is the first in the file
    function Comment:isFirst()
        return self._isFirst
    end
end

do
    local File, parent = torch.class("dokx.File", "dokx.Entity")
    function File:__init(text, ...)
        parent.__init(self, ...)
        self._text = dokx._normalizeComment(text)
    end
    -- Return a string representation of this File entity
    function File:str()
        return "{File: " .. self._text .. "}"
    end
    -- Return this file's docString
    function File:text()
        return self._text
    end
end

do
    --[[ Information about a Function, as extracted from lua source ]]
    local Function, parent = torch.class("dokx.Function", "dokx.Entity")

    -- We keep a whitelist of methods that begin with an underscore but which
    -- nevertheless should be included in generated documentation
    local _metamethods = {
            _init = true,
            __init = true,
            __index = true,
            __newindex = true,
            __mode = true,
            __call = true,
            __metatable = true,
            __tostring = true,
            __len = true,
            __gc = true,
            __unm = true,
            __add = true,
            __sub = true,
            __mul = true,
            __div = true,
            __mod = true,
            __div = true,
            __pow = true,
            __concat = true,
            __eq = true,
            __lt = true,
            __le = true
        }

    function Function:__init(name, args, ...)
        parent.__init(self, ...)
        assert(name)
        self._method = false
        self._local = false
        local hasClass = false
        local pos = name:find(":")
        if pos then
            hasClass = true
            self._method = true
        else
            pos = name:find("%.")
            if pos and name:sub(1, pos-1) ~= self:package() then
                hasClass = true
            end
        end
        if hasClass then
            self._className = name:sub(1, pos-1)
            self._name = name:sub(pos+1, -1)
        else
            self._className = false

            pos = name:find("%.")
            if pos and name:sub(1, pos-1) == self:package() then
                self._name = name:sub(pos+1, -1)
            else
                self._name = name
            end
        end
        self._args = args
    end
    -- Set whether this is a local function
    function Function:setLocal(localVal) self._local = localVal end
    -- Return whether this is a local function
    function Function:isLocal() return self._local end
    -- Return whether this is a private function
    function Function:isPrivate()
        return stringx.startswith(self._name, "_") and not _metamethods[self._name]
    end
    -- Return a string describing the args consumed by this function
    function Function:args() return self._args end
    -- Return the name of this function
    function Function:name() return self._name end
    -- Return the name of the class to which this function belongs, or false if it's not a method at all
    function Function:class() return self._className end
    function Function:nameWithClass()
        local name = self._name
        if self._className then
            if name == '__init' or name == '_init' then
                name = self._className
            else
                if self._method then
                    name = self._className .. ":" .. name
                else
                    name = self._className .. "." .. name
                end
            end
        end
        return name
    end
    -- Return the full (package[.class].function) name of this function
    function Function:fullname()
        local name = self:nameWithClass()
        name = self._package .. "." .. name
        return name
    end
    -- Return a string representation of this Function entity
    function Function:str() return "{Function: " .. self._name .. "}" end
end

do
    --[[ Information about a torch Class, as extracted from lua source ]]
    local Class, parent = torch.class("dokx.Class", "dokx.Entity")
    --[[ Constructor for a Class entity

    Args:
    - `name` - the name of the class
    - `class` - the name of the parent class, or false if there is none

    --]]
    function Class:__init(name, parentName, ...)
        parent.__init(self, ...)
        self._parent = parentName
        local pos = name:find("%.")
        if pos then
            local package = name:sub(1, pos-1)
            self._name = name:sub(pos+1, -1)
            if package ~= self._package then
                dokx.logger.warn("Class " .. name ..
                " is defined in the wrong module!? Expected " .. self._package .. "." .. self._name
                )
            end
        else
            dokx.logger.info("Class " .. name ..
            " should be defined in the " .. self._package .. " namespace! Expected " .. self._package .. "." .. name
            )
            self._name = name
        end
        self._doc = false
    end
    -- Return the name of this class
    function Class:name() return self._name end
    -- Return the name of the parent class to this one, or false if there is none
    function Class:parent() return self._parent end
    -- Return the full (package.class) name of this class
    function Class:fullname() return self._package .. "." .. self._name end
    -- Set the doc string for the class to the given text
    function Class:setDoc(text) self._doc = text end
    -- Return the docstring associated with this class, or false if there is none
    function Class:doc() return self._doc end
end

do
    --[[ Information about a region of whitespace, as extracted from lua source ]]
    local Whitespace, parent = torch.class("dokx.Whitespace", "dokx.Entity")
    function Whitespace:__init(numLines, ...)
        parent.__init(self, ...)
        self._numLines = numLines
    end
    -- String representation of this Whitespace entity
    function Whitespace:str() return "{Whitespace}" end
    function Whitespace:numLines() return self._numLines end
end

do
    --[[ Information about a function together with a comment, as extracted from lua source

TODO: get rid of this

    --]]
    local DocumentedFunction, parent = torch.class("dokx.DocumentedFunction", "dokx.Entity")
    function DocumentedFunction:__init(func, doc)
        local package = doc:package()
        local file = doc:file()
        local lineNo = doc:lineNo()

        parent.__init(self, package, file, lineNo)
        self._func = func
        self._doc = doc
    end

    function DocumentedFunction:name() return self._func:name() end
    function DocumentedFunction:nameWithClass() return self._func:nameWithClass() end
    function DocumentedFunction:fullname() return self._func:fullname() end
    function DocumentedFunction:doc() return self._doc._text end
    function DocumentedFunction:args() return self._func:args() end
    function DocumentedFunction:isLocal() return self._func:isLocal() end
    function DocumentedFunction:isPrivate() return self._func:isPrivate() end

    function DocumentedFunction:str()
        return "{Documented function: \n   " .. self._func:str() .. "\n   " .. self._doc:str() .. "\n}"
    end
end
