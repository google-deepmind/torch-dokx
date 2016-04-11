require 'dokx'
local tester = torch.Tester()
local myTests = {}

local sampleMarkdown1 = [[
# A

Here's some text

## B

## C ##

### D

```
# fake heading
```

    ## other fake heading

```lua
one more fake heading
==
```

Some writing

##### E
##### F ####

##G

####  H

Junk writing
I
=

J
============

<a name="link"/>
K
--
]]

function myTests:testHierarchy()

    local package = "myPackage"
    local filePath = "README.md"
    local packagePath = ""
    local sourceName = ""
    local headings = dokx._extractMarkdownHeadings(dokx.Package(package, packagePath), filePath, sourceName, sampleMarkdown1)
    tester:asserteq(#headings, 11)
    tester:assertTableEq(headings[1], { text = "A", level = 1 })
    tester:assertTableEq(headings[2], { text = "B", level = 2 })
    tester:assertTableEq(headings[3], { text = "C", level = 2 })
    tester:assertTableEq(headings[4], { text = "D", level = 3 })
    tester:assertTableEq(headings[5], { text = "E", level = 5 })
    tester:assertTableEq(headings[6], { text = "F", level = 5 })
    tester:assertTableEq(headings[7], { text = "G", level = 2 })
    tester:assertTableEq(headings[8], { text = "H", level = 4 })
    tester:assertTableEq(headings[9], { text = "I", level = 1 })
    tester:assertTableEq(headings[10], { text = "J", level = 1 })
    tester:assertTableEq(headings[11], { text = "K", level = 2 })

    local hierarchy = dokx._computeHeadingHierarchy(headings)

    tester:asserteq(#hierarchy.children, 3)

    tester:asserteq(#hierarchy.children[1].children, 3)
    tester:asserteq(#hierarchy.children[1].children[1].children, 0)
    tester:asserteq(#hierarchy.children[1].children[2].children, 1)
    tester:asserteq(#hierarchy.children[1].children[2].children[1].children, 1)
    tester:asserteq(#hierarchy.children[1].children[2].children[1].children[1].children, 2)
    tester:asserteq(#hierarchy.children[1].children[3].children, 1)
    tester:asserteq(#hierarchy.children[1].children[3].children[1].children, 1)
    tester:asserteq(#hierarchy.children[1].children[3].children[1].children[1].children, 0)

    tester:asserteq(#hierarchy.children[2].children, 0)

    tester:asserteq(#hierarchy.children[3].children, 1)
    tester:asserteq(#hierarchy.children[3].children[1].children, 0)
end

function myTests:testExtractTOCMarkdown()
    local package = dokx.Package("myPackage", "")
    local filePath = "README.md"
    local output = dokx._extractTOCMarkdown(package, filePath, sampleMarkdown1)

    local expected = [[

<ul>
<li><a href="#myPackage.README.A">A</a>
    <ul>
    <li><a href="#myPackage.README.B">B</a></li>
    <li><a href="#myPackage.README.C">C</a>
        <ul>
        <li><a href="#myPackage.README.D">D</a>
            <ul>
            <li>
                <ul>
                <li><a href="#myPackage.README.E">E</a></li>
                <li><a href="#myPackage.README.F">F</a></li>
                </ul>
            </li>
            </ul>
        </li>
        </ul>
    </li>
    <li><a href="#myPackage.README.G">G</a>
        <ul>
        <li>
            <ul>
            <li><a href="#myPackage.README.H">H</a></li>
            </ul>
        </li>
        </ul>
    </li>
    </ul>
</li>
<li><a href="#myPackage.README.I">I</a></li>
<li><a href="#myPackage.README.J">J</a>
    <ul>
    <li><a href="#myPackage.README.K">K</a></li>
    </ul>
</li>
</ul>
]]
    dokx._assertEqualWithDiff(tester, output, expected, "-u")
end

tester:add(myTests):run()
