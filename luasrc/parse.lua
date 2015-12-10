--[[ Facilities for parsing lua 5.1 code, in order to extract documentation and function names ]]

-- Penlight libraries
local class = require 'pl.class'
local stringx = require 'pl.stringx'
local tablex = require 'pl.tablex'
local func = require 'pl.func'
local path = require 'pl.path'

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
        local textBefore = content:sub(1, pos - #text):gsub('\n', '')
        textBefore = stringx.strip(textBefore)
        local isFirst = textBefore == "" or textBefore == '--' or textBefore == '--['
        return true, dokx.Comment(text, isFirst, packageName, file, lineNo)
    end
    local function makeFunction(content, pos, name, funcArgs)
        local lineNo = _calcLineNo(content, pos)
        local argString = ""
        if funcArgs and type(funcArgs) == 'string' then
            argString = funcArgs
        end
        return true, dokx.Function(name, argString or "", packageName, file, lineNo)
    end
    local function makeLocalFunction(...)
        local _, func = makeFunction(...)
        func:setLocal(true)
        return true, func
    end
    local function makeFunctionAsAssignment(content, pos, ...)
        local lineNo = _calcLineNo(content, pos)
        local args = {...}
        if not #args == 2 then
            return true
        end
        if torch.typename(args[1]) ~= nil then
            return true, args[1]
        end
        local funcName, funcBody = unpack(args)
        local pattern = "^function%(([^)]*)%)"
        local func
        if not funcName or not funcBody or type(funcName) ~= 'string' or type(funcBody) ~= 'string' then
            return true
        end
        if string.find(funcBody, pattern) then
            local funcArgs = funcBody:match(pattern)
            func = dokx.Function(funcName, funcArgs, packageName, file, lineNo)
        end

        return true, func
    end
    local function makePenlightClass(content, pos, ...)
        local lineNo = _calcLineNo(content, pos)
        local args = {...}
        if #args > 0 and torch.typename(args[#args]) == "dokx.Class" then
            return true, args[#args]
        end
        if not #args == 2 then
            return true
        end
        local className, classCall = unpack(args)
        local pattern = "^class%(([^)]*)%)"
        local class
        if not className or not classCall or type(className) ~= 'string' or type(classCall) ~= 'string' then
            return true
        end
        if string.find(classCall, pattern) then
            local funcArgsString = classCall:match(pattern)
            local classArgs = funcArgsString:gsub('"', '')
            if classArgs == "" then
                classArgs = nil
            end

            if classArgs and string.find(classArgs, '[, ]') then
                dokx.logger.debug("Too many arguments to class() - ignoring")
                return true
            end
            class = dokx.Class(className, classArgs or false, packageName, file, lineNo)
            return true, class
        end
        return true

    end
    local function inferClassName(fileName)
        local dir, name = path.splitpath(fileName)
        local base, ext = path.splitext(name)
        return base
    end
    local function parseStringOrIdentifier(str)
        if not str then
            return
        end
        str = stringx.strip(str)
        if str:sub(1,1) == '"' or str:sub(1,1) == "'" then
            local func = loadstring("return " .. str)
            if not func then 
                return
            end
            return func()
        end
        return str
    end
    local function makeClass(content, pos, funcname, classArgsString, ...)
        if funcname == 'torch.class' or funcname == 'classic.class' then
            local name, parent = stringx.splitv(classArgsString:sub(2, -2), ',')
            name = parseStringOrIdentifier(name)
            parent = parseStringOrIdentifier(parent)
            if name then
                if name == '...' then
                    name = inferClassName(file)
                end
                local lineNo = _calcLineNo(content, pos)
                return true, dokx.Class(name, parent or false, packageName, file, lineNo)
            end
        end
        if type(classArgsString) == "string" then
            local _, _, name1 = classArgsString:find(':mustHave%("([%w_]*)"%)')
            local _, _, name2 = classArgsString:find(":mustHave%('([%w_]*)'%)")
            if name1 or name2 then
                local lineNo = _calcLineNo(content, pos)
                local className = parseStringOrIdentifier(funcname)
                local funcName = className .. "." .. (name1 or name2)
                func = dokx.Function(funcName, "", packageName, file, lineNo)
                return true, func
            end
        end
        return true
    end
    local function makeWhitespace(content, pos, text)
        local lineNo = _calcLineNo(content, pos)
        local numLines = #stringx.splitlines(text)
        return true, dokx.Whitespace(numLines, packageName, file, lineNo)
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
        (shebang)^-1 * V "capturespace" * V "chunk" * V "capturespace" * -P(1);

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
        capturespace = (Cmt(C(locale.space^1), makeWhitespace) + V "comment")^0;

        -- Types and Comments

        Name = (locale.alpha + P "_") * (locale.alnum + P "_")^0 - V "keywords";
        Number = (P "-")^-1 * V "space" * P "0x" * locale.xdigit^1 *
        -(locale.alnum + P "_") +
        (P "-")^-1 * V "space" * locale.digit^1 *
        (P "." * locale.digit^0)^-1 * (S "eE" * (P "-")^-1 *
        locale.digit^1)^-1 * -(locale.alnum + P "_") +
        (P "-")^-1 * V "space" * P "." * locale.digit^1 *
        (S "eE" * (P "-")^-1 * locale.digit^1)^-1 *
        -(locale.alnum + P "_");
        String = P "\"" * (P "\\" * P(1) + (1 - P "\""))^0 * P "\"" +
        P "'" * (P "\\" * P(1) + (1 - P "'"))^0 * P "'" +
        V "longstring";

        -- Lua Complete Syntax

        chunk = (V "capturespace" * V "stat" * (V "space" * P ";")^-1)^0 *
        (V "capturespace" * V "laststat" * (V "space" * P ";")^-1)^-1;

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
        Cmt(K "function" * V "space" * C(V "funcname") * V "space" *  V "funcbody", makeFunction) +
        Cmt(K "local" * V "space" * K "function" * V "space" * C(V "Name") *
        V "space" * V "funcbody", makeLocalFunction) +

        -- Assign to local vars
        K "local" * V "space" * Cmt(C(V "namelist") *
        (V "space" * P "=" * V "space" * C(V "explist"))^-1, makePenlightClass) +

        -- Assign to global vars
        Cmt(C(V "varlist") * V "space" * P "=" * V "space" * C(V "explist") +
        V "functioncall", makeFunctionAsAssignment);

        laststat = K "return" * (V "space" * V "explist")^-1 + K "break";

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

        ["function"] = K "function" * V "space" * (V "funcbody")/0;

        funcbody = P "(" * V "space" * (C(V "parlist") / "%0" * V "space")^-1 * P ")" *
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


