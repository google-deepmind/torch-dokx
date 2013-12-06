local dir = require 'pl.dir'
local func = require 'pl.func'
local path = require 'pl.path'
local stringx = require 'pl.stringx'

local function pruneFunctions(config, documentedFunctions, undocumentedFunctions)
    if not config.includeLocal then
        local function notLocal(x)
            if x:isLocal() then
                dokx.logger:info("Excluding local function " .. x:fullname())
                return false
            end
            return true
        end
        documentedFunctions = tablex.filter(documentedFunctions, notLocal)
        undocumentedFunctions = tablex.filter(undocumentedFunctions, notLocal)
    end
    if not config.includePrivate then
        local function notPrivate(x)
            if x:isPrivate() then
                dokx.logger:info("Excluding private function " .. x:fullname())
                return false
            end
            return true
        end
        documentedFunctions = tablex.filter(documentedFunctions, notPrivate)
        undocumentedFunctions = tablex.filter(undocumentedFunctions, notPrivate)
    end
    return documentedFunctions, undocumentedFunctions
end

local function luaToMd(luaFile)
    return dokx._convertExtension("lua", "md", luaFile)
end

local function makeSectionTOC(namespace, sectionPath)
    local sectionName = path.splitext(path.basename(sectionPath))
    local sectionHTML = dokx._readFile(sectionPath)
    local output = [[<li><a href="#]] .. namespace .. "." .. sectionName .. ".dok" .. [[">]] .. sectionName .. "</a>\n" .. sectionHTML .. "</li>\n"
    return output
end

local function makeSectionHTML(namespace, sectionPath)
    local basename = path.basename(sectionPath)
    local sectionName = path.splitext(basename)
    local anchorName = namespace .. "." .. sectionName .. ".dok"
    local sectionHTML = dokx._readFile(sectionPath)
    local output = [[<div class='docSection'>]]
    output = output .. [[<a name="]] .. anchorName .. [["></a>]]
    output = output .. sectionHTML
    output = output .. [[</div>]]
    return output
end

--[[

Given a set of HTML sections for a package and an optional table of contents path, combine everything into a single index.html for the package.

Parameters:

- `tocPath` - path to an HTML file containing the table of contents for the package, or 'none'
- `input` - path to a directory containing HTML files to be combined
- `config` - a dokx config table

--]]
function dokx.combineHTML(tocPath, input, config)
    dokx.logger:info("Generating package documentation index for " .. input)

    local outputName = "index.html"

    if not path.isdir(input) then
        error("Not a directory: " .. input)
    end

    local extraDir = path.join(input, "extra")
    local extraSections = {}
    if path.isdir(extraDir) then
        extraSections = dir.getfiles(extraDir, "*.html")
    end

    local outputPath = path.join(input, outputName)
    local sectionPaths = dir.getfiles(input, "*.html")
    local packageName = dokx._getLastDirName(input)
    if config.packageName then
        packageName = config.packageName
    end

    sectionPaths = tablex.filter(sectionPaths, function(x)
        if stringx.endswith(x, 'init.html') then
            table.insert(extraSections, 1, path.join(input, 'init.html'))
            return false
        end
        return true
    end)

    local sortedExtra = tablex.sortv(extraSections)
    local sorted = tablex.sortv(sectionPaths)

    local content = ""

    for _, sectionPath in sortedExtra do
        dokx.logger:info("Adding " .. sectionPath .. " to index")
        content = content .. makeSectionHTML(packageName, sectionPath)
    end

    for _, sectionPath in sorted do
        dokx.logger:info("Adding " .. sectionPath .. " to index")
        content = content .. makeSectionHTML(packageName, sectionPath)
    end

    -- Add the generated table of contents from the given file, if provided
    local toc = ""
    if tocPath and tocPath ~= "none" then
        toc = dokx._readFile(tocPath)
    end

    local template = dokx._getTemplateContents("package.html")

    local mathjax = ""
    if not config or config.mathematics then
        mathjax = dokx._readFile(dokx._getTemplate("mathjax.html"))
    end

    local syntaxTemplate = dokx._getTemplateContents("syntax.html")
    local syntax = syntaxTemplate:safe_substitute {
        syntaxHighlighterURL = "../_highlight"
    }

    local output = template:safe_substitute {
        packageName = packageName,
        toc = toc,
        content = content,
        scripts = mathjax .. syntax,
        githubURL = "https://github.com/" .. (config.githubURL or "")
    }

    dokx.logger:info("Writing to " .. outputPath)

    local outputFile = io.open(outputPath, 'w')
    outputFile:write(output)
    outputFile:close()
end

--[[

Given a set of input Markdown files, render them to corresponding HTML files.

Parameters:
- `output` - path to a directory in which to write output HTML files
- `inputs` - table of paths to Lua files
- `config` - a dokx config table

--]]
function dokx.generateHTML(output, inputs, config)
    if not path.isdir(output) then
        dokx.logger:info("Directory " .. output .. " not found; creating it.")
        path.mkdir(output)
    end

    local function handleFile(markdownFile, outputPath)
        local sundown = require 'sundown'
        local content = dokx._readFile(markdownFile)
        if config and config.mathematics then
            content = content:gsub("$${", " ` $${"):gsub("[^$]${", " ` ${")
            content = content:gsub("}$%$", "}$$ ` "):gsub("}%$([^$])", "}$ ` ")
        end
        local rendered = sundown.render(content)
        if path.isfile(outputPath) then
            dokx.logger:warn("*** dokx.generateHTML: overwriting existing html file " .. outputPath .. " ***")
        end
        local outputFile = io.open(outputPath, 'w')
        dokx.logger:debug("dokx.generateHTML: writing to " .. outputPath)
        lapp.assert(outputFile, "Could not open: " .. outputPath)
        outputFile:write(rendered)
        outputFile:close()
    end

    for i, input in ipairs(inputs) do
        input = dokx._sanitizePath(input)
        dokx.logger:info("dokx.generateHTML: processing file " .. input)
        local basename = path.basename(input)
        local sectionName, ext = path.splitext(basename)
        lapp.assert(ext == '.md', "Expected .md file for input")
        local outputPath = path.join(output, sectionName .. ".html")

        handleFile(input, outputPath)
    end
end

--[[

Given a set of Lua files, parse them and output corresponding HTML files with table-of-contents sections

Parameters:
- `package` - name of the package
- `output` - path to directory in which to output HTML
- `inputs` - table of paths to input Lua files
- `config` - a dokx config table

--]]
function dokx.extractTOC(package, output, inputs, config)
    if not path.isdir(output) then
        dokx.logger:info("Directory " .. output .. " not found; creating it.")
        path.mkdir(output)
    end

    for i, input in ipairs(inputs) do
        input = dokx._sanitizePath(input)
        dokx.logger:info("dokx.extractTOC: processing file " .. input)

        local basename = path.basename(input)
        local sectionName, ext = path.splitext(basename)
        lapp.assert(ext == '.lua', "Expected .lua file for input")
        local outputPath = path.join(output, sectionName .. ".html")

        local content = dokx._readFile(input)
        local classes, documentedFunctions, undocumentedFunctions = dokx.extractDocs(package, input, content)

        documentedFunctions, undocumentedFunctions = pruneFunctions(config, documentedFunctions, undocumentedFunctions)

        -- Output markdown
        local output = ""

        if config.tocLevel == 'function' then
            if documentedFunctions:len() ~= 0 then
                output = output .. "<ul>\n"
                local function handleFunction(entity)
                    if not entity:isPrivate() then
                        anchorName = entity:fullname()
                        output = output .. [[<li><a href="#]] .. anchorName .. [[">]] .. entity:fullname() .. [[</a></li>]] .. "\n"
                    end
                end
                documentedFunctions:foreach(handleFunction)
                undocumentedFunctions:foreach(handleFunction)

                output = output .. "</ul>\n"
            end
        end

        local outputFile = io.open(outputPath, 'w')
        outputFile:write(output)
        outputFile:close()
    end

end

--[[

Given a directory containing table-of-contents sections, combine them into a single table-of-contents snippet.

The output is written to a file called 'toc.html' in the same directory.

Parameters:

 - `package` - name of the package
 - `input` - path to a directory containing ToC sections
 - `config` - a dokx config table

--]]
function dokx.combineTOC(package, input, config)
    dokx.logger:info("dokx.combineTOC: generating HTML ToC for " .. input)

    local outputName = "toc.html"

    if not path.isdir(input) then
        error("dokx.combineTOC: not a directory: " .. input)
    end

    local outputPath = path.join(input, outputName)

    -- Retrieve package name from path, by looking at the name of the last directory
    local sectionPaths = dir.getfiles(input, "*.html")
    local packageName = dokx._getLastDirName(input)
    if config.packageName then
        packageName = config.packageName
    end

    local sorted = tablex.sortv(sectionPaths)

    local toc = "<ul>\n"
    for _, sectionPath in sorted do
        dokx.logger:info("dokx.combineTOC: adding " .. sectionPath .. " to ToC")
        toc = toc .. makeSectionTOC(package, sectionPath)
    end
    toc = toc .. "</ul>\n"

    dokx.logger:info("dokx.combineTOC: writing to " .. outputPath)

    local outputFile = io.open(outputPath, 'w')
    outputFile:write(toc)
    outputFile:close()
end

--[[

Given information about a package and its source files, parse the lua and
generate Markdown for the extracted functions and classes.

Parameters:

 - `package` - name of the package
 - `output` - directory in which to write output Markdown files
 - `inputs` - table of input .lua files
 - `config` - a dokx config table
 - `packagePath`- path to the package
 - `mode` - either 'html' or 'repl', depending on the flavour of Markdown to extract

--]]
function dokx.extractMarkdown(package, output, inputs, config, packagePath, mode)

    mode = mode or 'html'

    if not path.isdir(output) then
        dokx.logger:info("dokx.extractMarkdown: directory " .. output .. " not found; creating it.")
        path.mkdir(output)
    end

    for i, input in ipairs(inputs) do
        input = dokx._sanitizePath(input)
        dokx.logger:info("dokx.extractMarkdown: processing file " .. input)

        local basename = path.basename(input)
        local sectionName, ext = path.splitext(basename)
        lapp.assert(ext == '.lua', "Expected .lua file for input")
        local outputPath = path.join(output, sectionName .. ".md")
        dokx.logger:info("dokx.extractMarkdown: writing to " .. outputPath)

        local content = dokx._readFile(input)
        local classes, documentedFunctions, undocumentedFunctions, fileString = dokx.extractDocs(
                package, input, content
            )

        documentedFunctions, undocumentedFunctions = pruneFunctions(config, documentedFunctions, undocumentedFunctions)

        -- Output markdown
        local writer = dokx.MarkdownWriter(outputPath, mode)
        if basename ~= 'init.lua' and fileString then
            writer:heading(3, basename)
        end
        if fileString then
            writer:write(fileString .. "\n")
        end

        classes:foreach(func.bind1(writer.class, writer))

        local gitCommit
        if mode == 'html' and config and config.githubURL then
            local gitProcess = io.popen("cd " .. path.dirname(input) .. " && git rev-parse HEAD", 'r')
            gitCommit = stringx.strip(gitProcess:read("*line"))
            gitProcess:close()
        end

        local function addGithubLink(entity)
            if gitCommit and packagePath then
                local filename = path.relpath(entity:file(), packagePath)
                local githubProjectRoot = "https://github.com/" .. config.githubURL
                local githubURL = githubProjectRoot .. "/blob/" .. gitCommit .. "/" .. filename
                githubURL = githubURL .. "#L" .. entity:lineNo()
                writer:write('\n<a class="entityLink" href="' .. githubURL .. '">' .. "[src]</a>\n")
            else
                dokx.logger:info("dokx.extractMarkdown: not adding source links")
            end
            return entity
        end

        documentedFunctions:foreach(func.compose(func.bind1(writer.documentedFunction, writer), addGithubLink))

        -- List undocumented functions, if there are any
        if undocumentedFunctions:len() ~= 0 then
            writer:heading(4, "Undocumented methods")
            undocumentedFunctions:foreach(func.bind1(writer.undocumentedFunction, writer))
        end

        writer:close()
    end
end

--[[

Given the root of a documentation tree, generate an index page listing all of the packages in the tree.

An entry is added for each directory in the top level of the tree whose name doesn't begin with an underscore.

The output is written to index.html in the root of the documentation tree, overwriting any existing file there.

--]]
function dokx.generateHTMLIndex(input)
    dokx.logger:info("dokx.generateHTMLIndex: generating global documentation index for " .. input)

    if not path.isdir(input) then
        error("dokx.generateHTMLIndex: not a directory: " .. input)
    end

    local outputName = "index.html"
    local outputPath = path.join(input, outputName)
    local packageDirs = dir.getdirectories(input)
    local template = dokx._getTemplateContents("packageIndex.html")

    local function indexEntry(package)
        return "<li><a href=\"" .. package .. "/index.html\">" .. package .. "</a></li>"
    end

    local sorted = tablex.sortv(packageDirs)

    -- Construct package list HTML
    local packageList = "<ul>"
    for _, packageDir in sorted do
        local packageName = path.basename(packageDir)
        if stringx.startswith(packageName, "_") then
            dokx.logger:info("dokx.generateHTMLIndex: skipping " .. packageName)
        else
            dokx.logger:info("dokx.generateHTMLIndex: adding " .. packageName .. " to index")
            packageList = packageList .. indexEntry(packageName)
        end
    end
    packageList = packageList .. "</ul>"

    local output = template:safe_substitute { packageList = packageList }
    dokx.logger:info("dokx.generateHTMLIndex: writing to " .. outputPath)

    local outputFile = io.open(outputPath, 'w')
    outputFile:write(output)
    outputFile:close()
end

function dokx._getPackageLuaFiles(packagePath, config)
    local luaFiles = dir.getallfiles(packagePath, "*.lua")
    luaFiles = dokx._filterFiles(luaFiles, config.filter, false)
    luaFiles = dokx._filterFiles(luaFiles, config.exclude, true)
    return luaFiles
end

function dokx._getPackageMdFiles(packagePath, config)
    local luaFiles = dir.getallfiles(packagePath, "*.md")
    luaFiles = dokx._filterFiles(luaFiles, config.exclude, true)
    return luaFiles
end

--[[

Given the path to a package repository, read the source files, markdown files, and any .dokx config file that may be present, and generate full HTML and Markdown documentation for the package.

Parameters:

 - `outputRoot` - path to a documentation tree in which to write the HTML output
 - `packagePath` - path to the package repository
 - `outputREPL` - optional path to write Markdown for consumption by the Torch REPL

--]]
function dokx.buildPackageDocs(outputRoot, packagePath, outputREPL)
    packagePath = dokx._sanitizePath(packagePath)
    outputRoot = dokx._sanitizePath(outputRoot)
    local config = dokx._loadConfig(packagePath)
    if not path.isdir(outputRoot) then
        error("dokx.buildPackageDocs: invalid documentation tree " .. outputRoot)
    end
    if outputREPL and not path.isdir(outputREPL) then
        error("dokx.buildPackageDocs: invalid path for REPL markdown output " .. outputREPL)
    end
    local docTmp = dokx._mkTemp()
    local tocTmp = dokx._mkTemp()

    local packageName = dokx._getLastDirName(packagePath)
    if config.packageName then
        packageName = config.packageName
    end
    local luaFiles = dokx._getPackageLuaFiles(packagePath, config)
    local extraMarkdownFiles = dokx._getPackageMdFiles(packagePath, config)
    local markdownFiles = tablex.map(func.compose(dokx._prependPath(docTmp), luaToMd), luaFiles)
    local outputPackageDir = path.join(outputRoot, packageName)

    if path.isdir(outputPackageDir) then
        dokx.logger:warn("Output directory " .. outputPackageDir .. " exists - removing!")
        dir.rmtree(outputPackageDir)
    end

    dokx.logger:info("dokx.buildPackageDocs: examining package " .. packagePath)
    dokx.logger:info("dokx.buildPackageDocs: package name = " .. packageName)
    dokx.logger:info("dokx.buildPackageDocs: output root = " .. outputRoot)
    dokx.logger:info("dokx.buildPackageDocs: output dir = " .. outputPackageDir)
    if outputREPL then
        dokx.logger:info("dokx.buildPackageDocs: output REPL markdown = " .. outputPackageDir)
    end

    path.mkdir(outputPackageDir)

    if outputREPL then
        dokx.extractMarkdown(packageName, outputREPL, luaFiles, config, packagePath, 'repl')
    end

    dokx.extractMarkdown(packageName, docTmp, luaFiles, config, packagePath, 'html')
    dokx.extractTOC(packageName, tocTmp, luaFiles, config)
    dokx.combineTOC(packageName, tocTmp, config)
    dokx.generateHTML(outputPackageDir, markdownFiles, config)
    dokx.generateHTML(path.join(outputPackageDir, "extra"), extraMarkdownFiles, config)
    dokx.combineHTML(path.join(tocTmp, "toc.html"), outputPackageDir, config)

    local markdownDir = path.join(outputRoot, "_markdown", packageName)
    if not path.isdir(markdownDir) then
        dir.makepath(markdownDir)
    end
    tablex.foreach(markdownFiles, function(mdFile)
        file.copy(mdFile, path.join(markdownDir, path.basename(mdFile)))
    end)

    -- Find the path to the templates - it's relative to our installed location
    local dokxDir = dokx._getDokxDir()
    local pageStyle = dokx._getTemplate("style-page.css")
    file.copy(pageStyle, path.join(outputPackageDir, "style.css"))

    -- Update the main index
    dokx.generateHTMLIndex(outputRoot)
    file.copy(dokx._getTemplate("style-index.css"), path.join(outputRoot, "style.css"))

    if not path.isdir(path.join(outputRoot, "_highlight")) then
        dokx.logger:warn("highlight.js not found - installing it...")
        local highlightDir = dokx._getTemplate("highlight")
        local installDir = path.join(outputRoot, "_highlight")
        dir.makepath(installDir)
        dir.makepath(path.join(installDir, "styles"))
        local highlightFiles = dir.getallfiles(highlightDir)
        for _, fileName in ipairs(highlightFiles) do
            local relPath = path.relpath(fileName, highlightDir)
            local destPath = path.join(installDir, relPath)
            dokx.logger:debug(destPath)
            dir.copyfile(path.join(highlightDir, fileName), destPath)
        end
    end

    file.copy(dokx._getTemplate("search.js"), path.join(outputRoot, "search.js"))

    dir.rmtree(docTmp)
    dir.rmtree(tocTmp)

    dokx.logger:info("Installed docs for " .. packagePath)
end

--[[

Given the path to a project repository, create an example .dokx config file in the root of the repository.

The .dokx file just contains the default values (commented out), along with explanations of what the various keys do.

--]]
function dokx.initPackage(packagePath)
    packagePath = dokx._sanitizePath(packagePath)

    local dokxPath = path.join(packagePath, ".dokx")
    if path.isfile(dokxPath) then
        dokx.logger:error("dokx.initPackage: .dokx file already exists for package " .. tostring(packagePath))
        os.exit(1)
    end

    local configSpec = dokx.configSpecification()

    local output = "return {\n"

    for _, configEntry in pairs(configSpec) do
        output = output .. "    -- " .. configEntry.key .. ": " .. configEntry.description .. "\n"
        output = output .. "    --" .. configEntry.key .. " = " .. configEntry.default .. ",\n\n"
    end

    output = output .. "}"

    dokx.logger:info("dokx.initPackage: creating default .dokx config file for package " .. tostring(packagePath))
    local dokxFile = io.open(dokxPath, 'w')
    dokxFile:write(output)
    dokxFile:close()
end

--[[

Open a web browser pointing to the documentation

--]]
function dokx.browse(docLocation)

    docLocation = docLocation or ""

    -- If going to a directory rather than a file, append index page to url
    if not string.find(docLocation, "%.") then
        docLocation = path.join(docLocation, "index.html")
    end

    dokx.runSearchServices()
    -- Wait for process to start... (ick!)
    os.execute("sleep 1")

    local docRoot
    if dokx._daemonIsRunning() then
        docRoot = "http://localhost:5000"
    else
        docRoot = dokx._luarocksHtmlDir()
        if not path.isdir(docRoot) then
            dokx.logger:error("dokx.browse: could not find local docs.")
            return
        end
    end
    local docPath = docRoot
    if docLocation then
        docPath = path.join(docRoot, docLocation)
    end

    dokx._openBrowser(docPath)
end


