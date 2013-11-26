-- Check that the result is a table with the given size
function dokx._checkTableSize(tester, result, size)
    tester:asserteq(type(result), 'table', "should be a table")
    tester:asserteq(#result, size, "should be size " .. size)
end
function dokx._checkWhitespace(tester, entity)
    tester:assert(dokx._is_a(entity, 'dokx.Whitespace'), "should be whitespace")
end
-- Check that the result is a Function with the expected name, class and line number
function dokx._checkFunction(tester, package, sourceFile, entity, name, class, line, args)
    tester:assert(dokx._is_a(entity, 'dokx.Function'), "should be a function")
    tester:asserteq(entity:name(), name, "should have expected name")
    tester:asserteq(entity:class(), class, "should have expected class")
    tester:asserteq(entity:package(), package, "should have expected package name")
    tester:asserteq(entity:file(), sourceFile, "should have expected source file")
    tester:asserteq(entity:lineNo(), line, "should have expected line number")
    if args then
        tester:asserteq(entity:args(), args, 'arg name does not match expected')
    end
end
-- Check that the result is a Comment with the expected text and line number
function dokx._checkComment(tester, package, sourceFile, entity, text, line)
    tester:assert(dokx._is_a(entity, 'dokx.Comment'), "should be a comment")
    tester:asserteq(entity:text(), text, "should have expected text")
    tester:asserteq(entity:package(), package, "should have expected package name")
    tester:asserteq(entity:file(), sourceFile, "should have expected source file")
    tester:asserteq(entity:lineNo(), line, "should have expected line number")
end
-- Check that the result is a Class with the expected name, parent and line number
function dokx._checkClass(tester, package, sourceFile, entity, name, parent, line)
    tester:assert(dokx._is_a(entity, 'dokx.Class'), "should be a class")
    tester:asserteq(entity:name(), name, "should have expected name")
    tester:asserteq(entity:parent(), parent, "should have expected parent")
    tester:asserteq(entity:package(), package, "should have expected package name")
    tester:asserteq(entity:file(), sourceFile, "should have expected source file")
    tester:asserteq(entity:lineNo(), line, "should have expected line number")
end
