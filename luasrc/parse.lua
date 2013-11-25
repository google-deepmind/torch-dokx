--[[ Facilities for parsing lua 5.1 code, in order to extract documentation and function names ]]

-- AST setup. We don't capture a full AST - only the parts we need.

-- Penlight libraries
local class = require 'pl.class'
local stringx = require 'pl.stringx'
local tablex = require 'pl.tablex'
local func = require 'pl.func'

function dokx._is_a(x, className)
    return torch.typename(x) == className
end

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
    function Comment:__init(text, ...)
        parent.__init(self, ...)
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
                return line:sub(chopIndex)
            end
            return line
        end, lines)
        text = stringx.join("\n", lines)

        -- Ensure we end with a new line
        if text[#text] ~= '\n' then
            text = text .. "\n"
        end
        self._text = text
    end
    -- Return a new dokx.Comment by concatenating this with another comment
    function Comment:combine(other)
        return dokx.Comment(self._text .. other._text, self._package, self._file, self._lineNo)
    end
    -- Return a string representation of this Comment entity
    function Comment:str()
        return "{Comment: " .. self._text .. "}"
    end
    -- Return this comment's text
    function Comment:text()
        return self._text
    end
end

do
    --[[ Information about a Function, as extracted from lua source ]]
    local Function, parent = torch.class("dokx.Function", "dokx.Entity")
    function Function:__init(name, ...)
        parent.__init(self, ...)
        assert(name)
        local pos = name:find(":") or name:find("%.")
        if pos then
            self._className = name:sub(1, pos-1)
            self._name = name:sub(pos+1, -1)
        else
            self._className = false
            self._name = name
        end
    end
    -- Return the name of this function
    function Function:name() return self._name end
    -- Return the name of the class to which this function belongs, or false if it's not a method at all
    function Function:class() return self._className end
    -- Return the full (package[.class].function) name of this function
    function Function:fullname()
        local name = self._name
        if self._className then
            name = self._className .. "." .. name
        end
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
                dokx.logger:error("Class " .. name ..
                " is defined in the wrong module!? Expected " .. self._package .. "." .. self._name
                )
            end
        else
            dokx.logger:error("Class " .. name ..
            " should be defined in the " .. self._package .. " namespace! Expected " .. self._package .. "." .. name
            )
            self._name = name
        end
    end
    -- Return the name of this class
    function Class:name() return self._name end
    -- Return the name of the parent class to this one, or false if there is none
    function Class:parent() return self._parent end
    -- Return the full (package.class) name of this class
    function Class:fullname() return self._package .. "." .. self._name end
end

do
    --[[ Information about a region of whitespace, as extracted from lua source ]]
    local Whitespace, parent = torch.class("dokx.Whitespace", "dokx.Entity")
    -- String representation of this Whitespace entity
    function Whitespace:str() return "{Whitespace}" end
end

do
    --[[ Information about a function together with a comment, as extracted from lua source ]]
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
    function DocumentedFunction:fullname() return self._func:fullname() end
    function DocumentedFunction:doc() return self._doc._text end

    function DocumentedFunction:str()
        return "{Documented function: \n   " .. self._func:str() .. "\n   " .. self._doc:str() .. "\n}"
    end
end

local function _calcLineNo(text, pos)
	local line = 1
	for _ in text:sub(1, pos):gmatch("\n") do
		line = line+1
	end
    return line
end

-- Lua 5.1 parser - based on one from http://lua-users.org/wiki/LpegRecipes
function dokx.createParser(packageName, file)
    assert(packageName)
    assert(file)
    local function makeComment(content, pos, text)
        local lineNo = _calcLineNo(content, pos)
        return true, dokx.Comment(text, packageName, file, lineNo)
    end
    local function makeFunction(content, pos, name)
        local lineNo = _calcLineNo(content, pos)
        return true, dokx.Function(name, packageName, file, lineNo)
    end
    local function makeClass(content, pos, funcname, classArgsString, ...)
        if funcname == 'torch.class' then
            local classArgs = loadstring("return " .. classArgsString:sub(2, -2))
            local valid = true
            if not classArgs then
                valid = false
            end
            if valid then
                local name, parent = classArgs()
                if not name or not parent then
                    valid = false
                else
                    local lineNo = _calcLineNo(content, pos)
                    return true, dokx.Class(name, parent, packageName, file, lineNo)
                end
                if valid then
                    logger:error("Could not understand class declaration " .. funcname .. classArgsString)
                    return true
                end
            end
        end
        return true
    end
    local function makeWhitespace()
        local lineNo = 0
        return dokx.Whitespace()
    end

    local lpeg = require "lpeg";

    -- Increase the max stack depth, since it can legitimately get quite deep, for
    -- syntactically complex programs.
    lpeg.setmaxstack(100000)

    local locale = lpeg.locale();
    local P, S, V = lpeg.P, lpeg.S, lpeg.V;
    local C, Cb, Cc, Cg, Cs, Cmt, Ct = lpeg.C, lpeg.Cb, lpeg.Cc, lpeg.Cg, lpeg.Cs, lpeg.Cmt, lpeg.Ct;

    local shebang = P "#" * (P(1) - P "\n")^0 * P "\n";

    -- keyword
    local function K (k) return P(k) * -(locale.alnum + P "_"); end

    local lua = Ct(P {
        (shebang)^-1 * V "space" * V "chunk" * V "space" * -P(1);

        -- keywords

        keywords = K "and" + K "break" + K "do" + K "else" + K "elseif" +
        K "end" + K "false" + K "for" + K "function" + K "if" +
        K "in" + K "local" + K "nil" + K "not" + K "or" + K "repeat" +
        K "return" + K "then" + K "true" + K "until" + K "while";

        -- longstrings

        longstring = P { -- from Roberto Ierusalimschy's lpeg examples
            V "open" * C((P(1) - V "closeeq")^0) *
            V "close" / function (o, s) return s end;

            open = "[" * Cg((P "=")^0, "init") * P "[" * (P "\n")^-1;
            close = "]" * C((P "=")^0) * "]";
            closeeq = Cmt(V "close" * Cb "init", function (s, i, a, b) return a == b end)
        };

        -- comments & whitespace

        comment = Cmt(P "--" * C(V "longstring") +
        P "--" * C((P(1) - P "\n")^0 * (P "\n" + -P(1))), makeComment);

        space = (locale.space + V "comment")^0;
        --  space = (C(locale.space) / makeWhitespace + V "comment")^0;

        -- Types and Comments

        Name = (locale.alpha + P "_") * (locale.alnum + P "_")^0 - V "keywords";
        Number = (P "-")^-1 * V "space" * P "0x" * locale.xdigit^1 *
        -(locale.alnum + P "_") +
        (P "-")^-1 * V "space" * locale.digit^1 *
        (P "." * locale.digit^1)^-1 * (S "eE" * (P "-")^-1 *
        locale.digit^1)^-1 * -(locale.alnum + P "_") +
        (P "-")^-1 * V "space" * P "." * locale.digit^1 *
        (S "eE" * (P "-")^-1 * locale.digit^1)^-1 *
        -(locale.alnum + P "_");
        String = P "\"" * (P "\\" * P(1) + (1 - P "\""))^0 * P "\"" +
        P "'" * (P "\\" * P(1) + (1 - P "'"))^0 * P "'" +
        V "longstring";

        -- Lua Complete Syntax

        chunk = (V "space" * V "stat" * (V "space" * P ";")^-1)^0 *
        (V "space" * V "laststat" * (V "space" * P ";")^-1)^-1;

        block = V "chunk";

        stat = K "do" * V "space" * V "block" * V "space" * K "end" +
        K "while" * V "space" * V "exp" * V "space" * K "do" * V "space" *
        V "block" * V "space" * K "end" +
        K "repeat" * V "space" * V "block" * V "space" * K "until" *
        V "space" * V "exp" +
        K "if" * V "space" * V "exp" * V "space" * K "then" *
        V "space" * V "block" * V "space" *
        (K "elseif" * V "space" * V "exp" * V "space" * K "then" *
        V "space" * V "block" * V "space"
        )^0 *
        (K "else" * V "space" * V "block" * V "space")^-1 * K "end" +
        K "for" * V "space" * V "Name" * V "space" * P "=" * V "space" *
        V "exp" * V "space" * P "," * V "space" * V "exp" *
        (V "space" * P "," * V "space" * V "exp")^-1 * V "space" *
        K "do" * V "space" * V "block" * V "space" * K "end" +
        K "for" * V "space" * V "namelist" * V "space" * K "in" * V "space" *
        V "explist" * V "space" * K "do" * V "space" * V "block" *
        V "space" * K "end" +

        -- Define a function - we'll create a Function entity!
        Cmt(K "function" * V "space" * C(V "funcname") * V "space" *  V "funcbody" +
        K "local" * V "space" * K "function" * V "space" * C(V "Name") *
        V "space" * V "funcbody", makeFunction) +

        -- Assign to local vars
        K "local" * V "space" * V "namelist" *
        (V "space" * P "=" * V "space" * V "explist")^-1 +

        V "varlist" * V "space" * P "=" * V "space" * V "explist" +
        V "functioncall";

        laststat = K "return" * (V "space" * V "explist")^-1 + K "break";

        --  funcname = C(V "Name" * (V "space" * P "." * V "space" * V "Name")^0 *
        --      (V "space" * P ":" * V "space" * V "Name")^-1) / makeFunction;
        funcname = V "Name" * (V "space" * P "." * V "space" * V "Name")^0 *
        (V "space" * P ":" * V "space" * V "Name")^-1;

        namelist = V "Name" * (V "space" * P "," * V "space" * V "Name")^0;

        varlist = V "var" * (V "space" * P "," * V "space" * V "var")^0;

        -- Let's come up with a syntax that does not use left recursion
        -- (only listing changes to Lua 5.1 extended BNF syntax)
        -- value ::= nil | false | true | Number | String | '...' | function |
        --           tableconstructor | functioncall | var | '(' exp ')'
        -- exp ::= unop exp | value [binop exp]
        -- prefix ::= '(' exp ')' | Name
        -- index ::= '[' exp ']' | '.' Name
        -- call ::= args | ':' Name args
        -- suffix ::= call | index
        -- var ::= prefix {suffix} index | Name
        -- functioncall ::= prefix {suffix} call

        -- Something that represents a value (or many values)
        value = K "nil" +
        K "false" +
        K "true" +
        V "Number" +
        V "String" +
        P "..." +
        V "function" +
        V "tableconstructor" +
        V "functioncall" +
        V "var" +
        P "(" * V "space" * V "exp" * V "space" * P ")";

        -- An expression operates on values to produce a new value or is a value
        exp = V "unop" * V "space" * V "exp" +
        V "value" * (V "space" * V "binop" * V "space" * V "exp")^-1;

        -- Index and Call
        index = P "[" * V "space" * V "exp" * V "space" * P "]" +
        P "." * V "space" * V "Name";
        call = V "args" +
        P ":" * V "space" * V "Name" * V "space" * V "args";

        -- A Prefix is a the leftmost side of a var(iable) or functioncall
        prefix = P "(" * V "space" * V "exp" * V "space" * P ")" +
        V "Name";
        -- A Suffix is a Call or Index
        suffix = V "call" +
        V "index";

        var = V "prefix" * (V "space" * V "suffix" * #(V "space" * V "suffix"))^0 *
        V "space" * V "index" +
        V "Name";

        -- Function call - check for torch.class definitions!
        functioncall = Cmt(C(V "prefix" *
        (V "space" * V "suffix" * #(V "space" * V "suffix"))^0) *
        V "space" * C(V "call"), makeClass);

        explist = V "exp" * (V "space" * P "," * V "space" * V "exp")^0;

        args = P "(" * V "space" * (V "explist" * V "space")^-1 * P ")" +
        V "tableconstructor" +
        V "String";

        ["function"] = K "function" * V "space" * V "funcbody";

        funcbody = P "(" * V "space" * (V "parlist" * V "space")^-1 * P ")" *
        V "space" *  V "block" * V "space" * K "end";

        parlist = V "namelist" * (V "space" * P "," * V "space" * P "...")^-1 +
        P "...";

        tableconstructor = P "{" * V "space" * (V "fieldlist" * V "space")^-1 * P "}";

        fieldlist = V "field" * (V "space" * V "fieldsep" * V "space" * V "field")^0
        * (V "space" * V "fieldsep")^-1;

        field = P "[" * V "space" * V "exp" * V "space" * P "]" * V "space" * P "=" *
        V "space" * V "exp" +
        V "Name" * V "space" * P "=" * V "space" * V "exp" +
        V "exp";

        fieldsep = P "," +
        P ";";

        binop = K "and" + -- match longest token sequences first
        K "or" +
        P ".." +
        P "<=" +
        P ">=" +
        P "==" +
        P "~=" +
        P "+" +
        P "-" +
        P "*" +
        P "/" +
        P "^" +
        P "%" +
        P "<" +
        P ">";

        unop = P "-" +
        P "#" +
        K "not";
    });

    return function(content)
        return lpeg.match(lua, content)
    end
end

local List = require 'pl.List'
local tablex = require 'pl.tablex'

--[[ Given a list, filter out any items that are not tables.

Args:
 - `entities :: pl.List` - AST objects extracted from the source code

Returns: a new list of entities
--]]
local function removeNonTable(entities)
    return tablex.filter(entities, function(x) return type(x) == 'table' end)
end

--[[ Given a list of entities, combine runs of adjacent Comment objects

Args:
 - `entities :: pl.List` - AST objects extracted from the source code

Returns: a new list of entities
--]]
local function mergeAdjacentComments(entities)

    local merged = List.new()

    -- Merge adjacent comments
    tablex.foreachi(entities, function(x)
        if type(x) ~= 'table' then
            error("Unexpected type for captured data: [" .. tostring(x) .. " :: " .. type(x) .. "]")
        end
        if merged:len() ~= 0 and dokx._is_a(merged[merged:len()], 'dokx.Comment') and dokx._is_a(x, 'dokx.Comment') then
            merged[merged:len()] = merged[merged:len()]:combine(x)
        else
            merged:append(x)
        end
    end)
    return merged
end

--[[ Given a list of entities, remove all whitespace elements

Args:
 - `entities :: pl.List` - AST objects extracted from the source code

Returns: a new list of entities
--]]
local function removeWhitespace(entities)
    -- Remove whitespace
    return tablex.filter(entities, function(x) return not dokx._is_a(x, 'dokx.Whitespace') end)
end

--[[ Given a list of entities, combine adjacent (Comment, Function) pairs into DocumentedFunction objects

Args:
 - `entities :: pl.List` - AST objects extracted from the source code

Returns: a new list of entities
--]]
local function associateDocsWithFunctions(entities)
    -- Find comments that immediately precede functions - we assume these are the corresponding docs
    local merged = List.new()
    tablex.foreachi(entities, function(x)
        if merged:len() ~= 0 and dokx._is_a(merged[merged:len()], 'dokx.Comment') and dokx._is_a(x, 'dokx.Function') then
            merged[merged:len()] = dokx.DocumentedFunction(x, merged[merged:len()])
        else
            merged:append(x)
        end
    end)
    return merged
end


--[[ Extract functions and documentation from lua source code

Args:
 - `packageName` :: string - name of package from which we're extracting
 - `sourceName` :: string - name of source file with which to tag extracted elements
 - `input` :: string - lua source code

Returns:
- `documentedFunctions` - a table of DocumentedFunction objects
- `undocumentedFunctions` - a table of Function objects

--]]
function dokx.extractDocs(packageName, sourceName, input)

    -- Output data
    local documentedFunctions = List.new()
    local undocumentedFunctions = List.new()

    local parser = dokx.createParser(packageName, sourceName)

    -- Tokenize & extract relevant strings
    local matched = parser(input)

    -- TODO handle bad parse
    if not matched then
        return documentedFunctions, undocumentedFunctions
    end

    -- Manipulate our reduced AST to extract a list of functions, possibly with
    -- docs attached
    local extractor = tablex.reduce(func.compose, {
        associateDocsWithFunctions,
--        removeWhitespace,
        mergeAdjacentComments,
        removeNonTable,
    })

    local entities = extractor(matched)


    for entity in entities:iter() do
        if dokx._is_a(entity, 'dokx.DocumentedFunction') then
            documentedFunctions:append(entity)
        end
        if dokx._is_a(entity, 'dokx.Function') then
            undocumentedFunctions:append(entity)
        end
    end

    return documentedFunctions, undocumentedFunctions
end



