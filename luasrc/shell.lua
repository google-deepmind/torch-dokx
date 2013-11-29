local dir = require 'pl.dir'
local func = require 'pl.func'
local path = require 'pl.path'
local stringx = require 'pl.stringx'

local function luaToMd(luaFile)
    return dokx._convertExtension("lua", "md", luaFile)
end

local function makeSectionTOC(packageName, sectionPath)
    local sectionName = path.splitext(path.basename(sectionPath))
    local sectionHTML = dokx._readFile(sectionPath)
    local output = [[<li><a href="#]] .. packageName .. "." .. sectionName .. ".dok" .. [[">]] .. sectionName .. "</a>\n" .. sectionHTML .. "</li>\n"
    return output
end

local function makeSectionHTML(packageName, sectionPath)
    local basename = path.basename(sectionPath)
    local sectionName = path.splitext(basename)
    local anchorName = packageName .. "." .. sectionName .. ".dok"
    local sectionHTML = dokx._readFile(sectionPath)
    local output = [[<div class='docSection'>]]
    output = output .. [[<a name="]] .. anchorName .. [["></a>]]
    output = output .. sectionHTML
    output = output .. [[</div>]]
    return output
end

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

function dokx.generateHTML(output, inputs)
    if not path.isdir(output) then
        dokx.logger:info("Directory " .. output .. " not found; creating it.")
        path.mkdir(output)
    end

    local function handleFile(markdownFile, outputPath)
        local sundown = require 'sundown'
        local content = dokx._readFile(markdownFile)
        content = content:gsub("$${", " ` $${"):gsub("[^$]${", " ` ${")
        content = content:gsub("}$%$", "}$$ ` "):gsub("}%$([^$])", "}$ ` ")
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
        input = path.abspath(path.normpath(input))
        dokx.logger:info("dokx.generateHTML: processing file " .. input)
        local basename = path.basename(input)
        local packageName, ext = path.splitext(basename)
        lapp.assert(ext == '.md', "Expected .md file for input")
        local outputPath = path.join(output, packageName .. ".html")

        handleFile(input, outputPath)
    end
end

function dokx.extractTOC(package, output, inputs, config)
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

        if config.tocLevel == 'function' then
            if documentedFunctions:len() ~= 0 then
                output = output .. "<ul>\n"
                local function handleFunction(entity)
                    if not stringx.startswith(entity:name(), "_") then
                        anchorName = entity:fullname()
                        output = output .. [[<li><a href="#]] .. anchorName .. [[">]] .. entity:nameWithClass() .. [[</a></li>]] .. "\n"
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

function dokx.extractMarkdown(package, output, inputs, config, packagePath)

    local mode = 'html' -- TODO

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
        local writer = dokx.MarkdownWriter(outputPath, mode)
        local haveNonClassFunctions = false -- TODO

        if basename ~= 'init.lua' and fileString or haveNonClassFunctions then
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
                print(entity:file())
                local filename = path.relpath(entity:file(), packagePath)
                local githubProjectRoot = "https://github.com/" .. config.githubURL
                local githubURL = githubProjectRoot .. "/blob/" .. gitCommit .. "/" .. filename
                githubURL = githubURL .. "#L" .. entity:lineNo()
                writer:write('\n<a class="entityLink" href="' .. githubURL .. '">' .. path.basename(filename) .. "</a>\n")
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

    -- Construct package list HTML
    local packageList = "<ul>"
    packageDirs:foreach(function(packageDir)
        local packageName = path.basename(packageDir)
        if stringx.startswith(packageName, "_") then
            dokx.logger:info("dokx.generateHTMLIndex: skipping " .. packageName)
        else
            dokx.logger:info("dokx.generateHTMLIndex: adding " .. packageName .. " to index")
            packageList = packageList .. indexEntry(packageName)
        end
    end)
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

function dokx.buildPackageDocs(outputRoot, packagePath)
    packagePath = path.abspath(path.normpath(packagePath))
    outputRoot = path.abspath(path.normpath(outputRoot))
    local config = dokx._loadConfig(packagePath)
    if not path.isdir(outputRoot) then
        error("dokx.buildPackageDocs: invalid documentation tree " .. outputRoot)
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

    path.mkdir(outputPackageDir)

    dokx.extractMarkdown(packageName, docTmp, luaFiles, config, packagePath)
    dokx.extractTOC(packageName, tocTmp, luaFiles, config)
    dokx.combineTOC(packageName, tocTmp, config)
    dokx.generateHTML(outputPackageDir, markdownFiles)
    dokx.generateHTML(path.join(outputPackageDir, "extra"), extraMarkdownFiles)
    dokx.combineHTML(path.join(tocTmp, "toc.html"), outputPackageDir, config)

    -- Find the path to the templates - it's relative to our installed location
    local dokxDir = dokx._getDokxDir()
    local pageStyle = dokx._getTemplate("style-page.css")
    file.copy(pageStyle, path.join(outputPackageDir, "style.css"))

    -- Update the main index
    dokx.generateHTMLIndex(outputRoot)
    file.copy(dokx._getTemplate("style-index.css"), path.join(outputRoot, "style.css"))

    if not path.isdir(path.join(outputRoot, "_highlight")) then
        dokx.logger:warn("highlight.js not found - syntax highlighting will be unavailable")
    end

    dir.rmtree(docTmp)
    dir.rmtree(tocTmp)

    dokx.logger:info("Installed docs for " .. packagePath)
end
