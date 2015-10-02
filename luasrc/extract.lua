local List = require 'pl.List'
local func = require 'pl.func'
local tablex = require 'pl.tablex'

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

--[[ Given a list of items, remove all non-table elements

Args:
 - `entities :: pl.List` - items extracted from the source code

Returns: a new list of entities
--]]
local function removeNonTable(entities)
    return tablex.filter(entities, function(x) return type(x) == 'table' end)
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

local function removeSingleLineWhitespace(entities)
    return tablex.filter(entities, function(x) return not dokx._is_a(x, 'dokx.Whitespace') or x:numLines() > 1 end)
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

--[[ Given a list of entities, combine adjacent (Comment, Class) pairs

Args:
 - `entities :: pl.List` - AST objects extracted from the source code

Returns: a new list of entities
--]]
local function associateDocsWithClasses(entities)
    -- Find comments that immediately precede classes - we assume these are the corresponding docs
    local merged = List.new()
    tablex.foreachi(entities, function(x)
        if merged:len() ~= 0 and dokx._is_a(merged[merged:len()], 'dokx.Comment') and dokx._is_a(x, 'dokx.Class') then
            x:setDoc(merged[merged:len()]:text())
            merged[merged:len()] = x
        else
            merged:append(x)
        end
    end)
    return merged
end

-- Given a list of entities, if the first element is a Comment, mark it as a File comment
local function getFileString(entities)
    if entities:len() ~= 0 and dokx._is_a(entities[1], 'dokx.Comment') then
        local comment = entities[1]
        if comment:isFirst() then
            entities[1] = dokx.File(comment:text(), comment:package(), comment:file(), comment:lineNo())
        end
    end
    return entities
end

--[[ Extract functions and documentation from lua source code

Args:
 - `packageName` :: string - name of package from which we're extracting
 - `sourceName` :: string - name of source file with which to tag extracted elements
 - `input` :: string - lua source code

Returns:
- `classes` - a table of Class objects
- `documentedFunctions` - a table of DocumentedFunction objects
- `undocumentedFunctions` - a table of Function objects

--]]
function dokx.extractDocs(packageName, sourceName, input)

    -- Output data
    local classes = List.new()
    local documentedFunctions = List.new()
    local undocumentedFunctions = List.new()
    local fileString = false

    local parser = dokx.createParser(packageName, sourceName)

    -- Tokenize & extract relevant strings
    local matched = parser(input)

    if not matched then
        return classes, documentedFunctions, undocumentedFunctions, fileString
    end

    -- Manipulate our reduced AST to extract a list of functions, possibly with
    -- docs attached
    local extractor = tablex.reduce(func.compose, {
        -- note: order of application is bottom to top!
        getFileString,
        removeWhitespace,
        associateDocsWithClasses,
        associateDocsWithFunctions,
        removeSingleLineWhitespace,
        mergeAdjacentComments,
        removeNonTable,
    })

    local entities = extractor(matched)
    local files = {}
    for entity in entities:iter() do
        if dokx._is_a(entity, 'dokx.File') then
            files[1] = entity
        end
        if dokx._is_a(entity, 'dokx.Class') then
            classes:append(entity)
        end
        if dokx._is_a(entity, 'dokx.DocumentedFunction') then
            documentedFunctions:append(entity)
        end
        if dokx._is_a(entity, 'dokx.Function') then
            undocumentedFunctions:append(entity)
        end
    end
    if #files ~= 0 then
        fileString = files[1]:text()
    end

    return classes, documentedFunctions, undocumentedFunctions, fileString
end


