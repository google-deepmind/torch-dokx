local dir = require 'pl.dir'
local func = require 'pl.func'
local path = require 'pl.path'
local stringx = require 'pl.stringx'

local function luaToMd(luaFile)
    if not stringx.endswith(luaFile, ".lua")  then
        error("Expected .lua file")
    end
    return path.basename(luaFile):sub(1, -4) .. "md"
end

local function makeSectionTOC(packageName, sectionPath)
    local sectionName = path.splitext(path.basename(sectionPath))
    local sectionHTML = dokx._readFile(sectionPath)
    local output = [[<li><a href="#]] .. packageName .. "." .. sectionName .. ".dok" .. [[">]] .. sectionName .. "</a>\n" .. sectionHTML .. "</li>\n"
    return output
end

local function makeAnchorName(packageName, sectionName)
    return packageName .. "." .. sectionName .. ".dok"
end

local function makeSectionHTML(packageName, sectionPath)
    local basename = path.basename(sectionPath)
    local sectionName = path.splitext(basename)
    local sectionHTML = dokx._readFile(sectionPath)
    local output = [[<div class='docSection'>]]
    output = output .. [[<a name="]] .. makeAnchorName(packageName, sectionName) .. [[">]]
    output = output .. sectionHTML
    output = output .. [[</div>]]
    return output
end

local function prependPath(prefix)
    return function(suffix)
        return path.join(prefix, suffix)
    end
end

local function indexEntry(package)
    return "<li><a href=\"" .. package .. "/index.html\">" .. package .. "</a></li>"
end

function dokx.combineHTML(tocPath, input)
    dokx.logger:info("Generating package documentation index for " .. input)

    local outputName = "index.html"
    local stylePath = "style.css"

    if not path.isdir(input) then
        error("Not a directory: " .. input)
    end

    local outputPath = path.join(input, outputName)

    local sectionPaths = dir.getfiles(input, "*.html")
    local packageName = dokx._getLastDirName(input)

    -- TODO sort sectionPaths, but with init.lua at the front

    local mainContent = ""
    sectionPaths:foreach(function(sectionPath)
        dokx.logger:info("Adding " .. sectionPath .. " to index")
        mainContent = mainContent .. makeSectionHTML(packageName, sectionPath)
    end)

    local toc

    -- Add the generated table of contents from the given file, if provided
    if tocPath and tocPath ~= "none" then
        toc = dokx._readFile(tocPath)
    end

    local output = [[
<html>
<head>
<link rel="stylesheet" type="text/css" href="]] .. stylePath .. [[">
<title>Documentation for ]] .. packageName .. [[</title>
</head>
<body>
<div class="content">
<h1>]] .. packageName .. [[</h1>]]

    if toc then
        output = output .. [[<div class="docToC"><h3>Overview</h3>TODO<h3>Contents</h3>]] .. toc .. [[</div>]]
    end
    output = output .. mainContent .. [[
</div>
</body>
</html>
]]

    dokx.logger:info("Writing to " .. outputPath)

    local outputFile = io.open(outputPath, 'w')
    outputFile:write(output)
    outputFile:close()
end

function dokx.generateHTML(output, inputs)
    if not path.isdir(output) then
        dokx.logger:info("Directory " .. output .. " not found; creating it.")
        path.mkdir(output)
    end

    local function handleFile(markdownFile, outputPath)
        local sundown = require 'sundown'
        local content = dokx._readFile(markdownFile)
        local rendered = sundown.render(content)
        local outputFile = io.open(outputPath, 'w')
        dokx.logger:debug("dokx.generateHTML: writing to " .. outputPath)
        lapp.assert(outputFile, "Could not open: " .. outputPath)
        outputFile:write(rendered)
        outputFile:close()
    end

    for i, input in ipairs(inputs) do
        input = path.abspath(path.normpath(input))
        dokx.logger:info("dokx.generateHTML: processing file " .. input)
        local basename = path.basename(input)
        local packageName, ext = path.splitext(basename)
        lapp.assert(ext == '.md', "Expected .md file for input")
        local outputPath = path.join(output, packageName .. ".html")

        handleFile(input, outputPath)
    end
end

function dokx.extractTOC(package, output, inputs)
    if not path.isdir(output) then
        dokx.logger:info("Directory " .. output .. " not found; creating it.")
        path.mkdir(output)
    end

    for i, input in ipairs(inputs) do
        input = path.normpath(input)
        dokx.logger:info("dokx.extractTOC: processing file " .. input)

        local basename = path.basename(input)
        local packageName, ext = path.splitext(basename)
        lapp.assert(ext == '.lua', "Expected .lua file for input")
        local outputPath = path.join(output, packageName .. ".html")

        local content = dokx._readFile(input)
        local classes, documentedFunctions, undocumentedFunctions = dokx.extractDocs(package, input, content)

        -- Output markdown
        local output = ""
        if documentedFunctions:len() ~= 0 then
            output = output .. "<ul>\n"
            local function handleFunction(entity)
                if not stringx.startswith(entity:name(), "_") then
                    anchorName = entity:fullname()
                    output = output .. [[<li><a href="#]] .. anchorName .. [[">]] .. entity:name() .. [[</a></li>]] .. "\n"
                end
            end
            documentedFunctions:foreach(handleFunction)
            undocumentedFunctions:foreach(handleFunction)

            output = output .. "</ul>\n"
        end

        local outputFile = io.open(outputPath, 'w')
        outputFile:write(output)
        outputFile:close()
    end

end

function dokx.combineTOC(package, input)
    dokx.logger:info("dokx.combineTOC: generating HTML ToC for " .. input)

    local outputName = "toc.html"

    if not path.isdir(input) then
        error("dokx.combineTOC: not a directory: " .. input)
    end

    local outputPath = path.join(input, outputName)

    -- Retrieve package name from path, by looking at the name of the last directory
    local sectionPaths = dir.getfiles(input, "*.html")
    local packageName = dokx._getLastDirName(input)

    local toc = "<ul>\n"
    sectionPaths:foreach(function(sectionPath)
        dokx.logger:info("dokx.combineTOC: adding " .. sectionPath .. " to ToC")
        toc = toc .. makeSectionTOC(package, sectionPath)
    end)
    toc = toc .. "</ul>\n"

    dokx.logger:info("dokx.combineTOC: writing to " .. outputPath)

    local outputFile = io.open(outputPath, 'w')
    outputFile:write(toc)
    outputFile:close()
end

function dokx.extractMarkdown(package, output, inputs)
    if not path.isdir(output) then
        dokx.logger:info("dokx.extractMarkdown: directory " .. output .. " not found; creating it.")
        path.mkdir(output)
    end

    for i, input in ipairs(inputs) do
        input = path.normpath(input)
        dokx.logger:info("dokx.extractMarkdown: processing file " .. input)

        local basename = path.basename(input)
        local packageName, ext = path.splitext(basename)
        lapp.assert(ext == '.lua', "Expected .lua file for input")
        local outputPath = path.join(output, packageName .. ".md")
        dokx.logger:info("dokx.extractMarkdown: writing to " .. outputPath)

        local content = dokx._readFile(input)
        local classes, documentedFunctions, undocumentedFunctions, fileString = dokx.extractDocs(
                package, input, content
            )

        -- Output markdown
        local writer = dokx.MarkdownWriter(outputPath)
        if basename ~= 'init.lua' then
            writer:heading(3, basename)
        end
        if fileString then
            writer:write(fileString)
        end

        classes:foreach(func.bind1(writer.class, writer))

        local function handleDocumentedFunction(entity)
            writer:documentedFunction(entity)
        end
        documentedFunctions:foreach(handleDocumentedFunction)

        -- List undocumented functions, if there are any
        if undocumentedFunctions:len() ~= 0 then
            writer:heading(4, "Undocumented methods")
            local function handleUndocumentedFunction(entity)
                writer:undocumentedFunction(entity)
            end
            undocumentedFunctions:foreach(handleUndocumentedFunction)
        end

        writer:close()
    end
end

function dokx.generateHTMLIndex(input)
    dokx.logger:info("dokx.generateHTMLIndex: generating global documentation index for " .. input)

    if not path.isdir(input) then
        error("dokx.generateHTMLIndex: not a directory: " .. input)
    end

    local outputName = "index.html"
    local outputPath = path.join(input, outputName)

    local packageDirs = dir.getdirectories(input)

    local output = [[
<html>
<head>
<title>Documentation Index</title>
<link rel="stylesheet" type="text/css" href="style.css">
</head>
<body>
<h1>Deepmind Documentation</h1>
<ul>
    ]]

    packageDirs:foreach(function(packageDir)
        local packageName = path.basename(packageDir)
        dokx.logger:info("dokx.generateHTMLIndex: adding " .. packageName .. " to index")
        output = output .. indexEntry(packageName)
    end)

    output = output .. [[
</ul>
</body>
</html>
]]

    dokx.logger:info("dokx.generateHTMLIndex: writing to " .. outputPath)

    local outputFile = io.open(outputPath, 'w')
    outputFile:write(output)
    outputFile:close()
end

function dokx.buildPackageDocs(outputRoot, packagePath)
    packagePath = path.abspath(path.normpath(packagePath))
    outputRoot = path.abspath(path.normpath(outputRoot))
    if not path.isdir(outputRoot) then
        error("dokx.buildPackageDocs: invalid documentation tree " .. outputRoot)
    end
    local docTmp = dokx._mkTemp()
    local tocTmp = dokx._mkTemp()

    local packageName = dokx._getLastDirName(packagePath)
    local luaFiles = dir.getallfiles(packagePath, "*.lua")
    local markdownFiles = tablex.map(func.compose(prependPath(docTmp), luaToMd), luaFiles)
    local outputPackageDir = path.join(outputRoot, packageName)

    dokx.logger:info("dokx.buildPackageDocs: examining package " .. packagePath)
    dokx.logger:info("dokx.buildPackageDocs: package name = " .. packageName)
    dokx.logger:info("dokx.buildPackageDocs: output root = " .. outputRoot)
    dokx.logger:info("dokx.buildPackageDocs: output dir = " .. outputPackageDir)
    path.mkdir(outputPackageDir)

    dokx.extractMarkdown(packageName, docTmp, luaFiles)
    dokx.extractTOC(packageName, tocTmp, luaFiles)
    dokx.combineTOC(packageName, tocTmp)
    dokx.generateHTML(outputPackageDir, markdownFiles)
    dokx.combineHTML(path.join(tocTmp, "toc.html"), outputPackageDir)

    -- Find the path to the templates - it's relative to our installed location
    local dokxDir = path.dirname(debug.getinfo(1, 'S').source):sub(2)
    local pageStyle = path.join(dokxDir, "templates/style-page.css")
    file.copy(pageStyle, path.join(outputPackageDir, "style.css"))

    -- Update the main index
    dokx.generateHTMLIndex(outputRoot)
    file.copy(path.join(dokxDir, "templates/style-index.css"), path.join(outputRoot, "style.css"))

    dir.rmtree(docTmp)
    dir.rmtree(tocTmp)

    dokx.logger:info("Installed docs for " .. packagePath)
end

