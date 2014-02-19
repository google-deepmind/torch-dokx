# Using torch-dokx

Dokx is intended to be simple to use. There are no special tags needed when you
write your documentation.  Just write Markdown comments in your code, and dokx
will extract them as appropriate.

# Example

The following is a general example of how to you might write documentation for dokx.

    --[[ This file defines an example class, for demonstrating usage of dokx.

    This comment could contain some general documentation for the whole file.

    [Example of a hyperlink.](http://example.com)

    ]]

    require 'somelibrary'

    --[[ This is some class documentation ]]--
    local MyClass, parent = torch.class('myPackage.MyClass', 'myPackage.Base')

    --[[ This method is the constructor.

    Parameters:
     * `a` - a string
     * `b` - an integer

    Returns:
     1. `c` - a computed value
     2. `d` - another computed value

    Example:
        
        local myClass = myPackage.MyClass("hello", 3)

    --]]
    function MyClass:__init(a, b)
        ...
    end

    --[[ This method does some calculation.

    The value returned is equal to ${ n }$, where

    $${ n = x^3 + y ^ 3 }$$

    Parameters:
     * `x` - integer
     * `y` - integer

    Returns:
     * `n` - integer; see above
    
    Example:
        
        local myClass = MyClass("hello", 3)
        print(myClass:calculate(1, 12) == myClass:calculate(9, 10))

    --]]
    function MyClass:calculate(x, y)
        ...
    end

    -- This is private - by default, dokx will ignore it
    function MyClass:_secret()
        ...
    end

    -- This is local - by default, dokx will ignore it
    local function helper()
        ...
    end


## What's Markdown?

Markdown is a standard way of specifying text formatting. It is precise enough
for computers to understand, but also easily readable by humans. It's very easy
to learn, and if you don't need any special formatting then you can simply
write text as normal. Markdown is used for the Torch core documentation.

Markdown resources:

* [DaringFireball](http://daringfireball.net/projects/markdown/syntax) - syntax guide
* [vim-instant-markdown](https://github.com/suan/vim-instant-markdown) - preview plugin for Vim

## Where should I put documentation?

Only comments in certain places are treated as documentation.

### Before functions and methods

For example:

    ...

    --[[ This is a function

    Parameters:
    - `zeta` - a most interesting parameter

    --]]
    function myPackage.doSomething(zeta)
        ...
    end

    ...

Ensure there are _no extra lines_ between your documentation and the function's
start - if there's a gap, dokx assumes the comment is not related to the
function.

### Before classes

For example:

    ...

    --[[ This class does something nice.

    Example:
        local myInstance = myPackage.NiceClass()
        myInstance:activate()

    --]]
    local NiceClass, parent = torch.class("myPackage.NiceClass")

    ...

Again - ensure there are _no extra lines_ between your documentation and the
function's start. If there's a gap, dokx assumes the comment is not related to
the class.

### At the top of files

For example:

    --[[ This file contains some wonderful functions.

    You can use them, if you like.

    --]]

    ...

Note: `init.lua` is treated as a special case. If you put a comment at the top
of `init.lua`, it is treated as documentation about the package as a whole.

### In separate Markdown files

Any additional Markdown files in your project (e.g. `README.md`) will be
detected and added to the generated documentation, at the top.

## Code blocks

To insert a code block, simply use the standard Markdown syntax for that -
indent the code by four spaces.

## Mathematics

Markdown itself doesn't provide a way to format mathematics, but dokx will
render it for you if you surround it with the appropriate tokens.  Inside the
tokens you can write your mathematics using LaTeX.

For inline mathematics, surround it with `${` and `}$`.

For display mathematics (shown centered, on a separate line), surround it with `$${` and `}$$`.

### Example

    --[[ This function computes the PDF for a Binomial distribution.
    
    The density is given by the formula $${ P(E) = {n \choose k} p^k (1-p)^{n-k} }$$

    Parameters:
    * ${n \geq 0}$ - number of independent trials
    * ${0 \leq k \leq n}$ - number of successes
    * ${0 \leq p \leq 1$} - probability of success
    
    --]]
    function binpdf(n, k, p)
       ...
    end

## Per-package configuration

If you want to tweak how dokx generates documentation for your project, you can
add a `.dokx` configuration file in the root of the repository. This file
should be a lua snippet which returns a table of configuration values.

### Example

    return {
        filter = "luasrc/.*%.lua$",
        tocLevel = 'function'
    }

### Configuration options

The available configuration keys are as follows:

#### packageName

If the detected package name does not match the namespace that should appear in
the documentation, you can override it by setting `packageName` in the config
file. For example, the repository for this project is called `'torch-dokx'`, but
the namespace is `'dokx'`.

#### section

A string - the name of the section under which this package should be grouped
in the main menu. If not given, the package will go into 'Miscellaneous' by
default.

#### githubURL

If this is provided, then the generated documentation will include links to the
main project page and to the source locations on GitHub. This should be a string of
the form `'$user/$project'` - for example, `'d11/torch-dokx'`.

#### filter

A [Lua pattern](http://www.lua.org/pil/20.2.html) or table of lua patterns,
against which potential input files will be tested. Only Lua files which match
(one of) the pattern(s) will be included in the generated documentation. By
default, all Lua files in the project will be included.

#### exclude

A [Lua pattern](http://www.lua.org/pil/20.2.html) or table of lua patterns,
against which potential input files will be tested. Any file (lua or md)
matching an exclusion pattern will be removed from the documentation. By
default, no files are excluded.

#### tocLevel

A string indicating how detailed the table of contents in the generated HTML
should be. The default is to generate an entry for every documented function,
but in large projects, this might be excessive. Valid values are 'function',
'class' and 'none'.

#### tocLevelTopSection

An integer indicating the maximum depth of the top section of the generated
table of contents (the part containing links for the standalone .md docs)

#### sectionOrder

A table containing the names of files in order of priority. The top section of
the table of contents will list these markdown files first, followed by any
others in alphabetical order, followed by extracted inline documentation.

The filenames are case-sensitive and should *not* include the extension.

For example:

    sectionOrder = { 'README', 'tensor', 'maths' }

#### tocIncludeFilenames

A boolean; if true, include filenames as a top level in the table of contents
(applies to the top, non-inline section only.)

#### mathematics

A boolean indicating whether MathJax should be included in the generated HTML.
If present MathJax will render any mathematics detected in the page. By
default, this is **on**. If your documentation contains no mathematics and MathJax
is therefore not needed, or if it is causing problems, then you may wish to set
this to `false`.

#### includeLocal

A boolean indicating whether local functions should be included in the
generated documentation. The default is `false`.

#### includePrivate

A boolean indicating whether 'private' functions - those whose names begin
with an underscore - should be included in the generated documentation. The
default is `false`.

# Viewing documentation

If you use `dokx-luarocks`, you'll have a documentation tree automatically built in your rock tree. (In `$root/share/doc/dokx`). While you can browse the HTML files here directly if you wish, it can be more convenient to use the `dokx-browse` command. This opens your browser at the correct location, and also runs a service that allows you to search the documentation. The search box only appears when using this method.

You can pass the name of a package to `dokx-browse` to jump straight to it.

# Searching documentation

**Note: in order for search to work, you'll need to have `python`, `pip`, and `virtualenv` installed!**

OS/X installation:

    sudo easy_install pip
    sudo pip install virtualenv

Ubuntu installation:

    sudo apt-get install python-pip
    sudo pip install virtualenv

As well as searching via the web interface, you can search on the command-line:

    dokx-search 'myLovelyModule'

Or in the REPL:

    > dokx.search('myLovelyModule')

# Building documentation

## Command-line interface

The following commands provide full control over the various parts of the documentation-generation process. For more detailed information, pass `--help` to the command you're interested in.

High-level commands:

* **dokx-init** - create a default .dokx config file for a package
* **dokx-luarocks** - install or make a package along with its documentation
* **dokx-browse** - open web browser to view documentation
* **dokx-search** - search documentation for a given pattern

Low-level commands:

* **dokx-update-from-git** - fetch a package from git and build its documentation
* **dokx-build-search-index** - update the search index for a documentation tree
* **dokx-build-package-docs** - build documentation for a package already on disk
* **dokx-extract-toc** - extract table-of-contents components from Lua sources
* **dokx-extract-markdown** - extract Markdown components from Lua sources
* **dokx-generate-html** - convert Markdown components to HTML components
* **dokx-combine-toc** - combine table-of-contents components into one table for a package
* **dokx-combine-html** - combine HTML components and a table-of-contents into one page for a package
* **dokx-combine-markdown** - combine Markdown components into one markdown page for a package
* **dokx-generate-html-index** - generate an index page for a set of packages in a documentation tree

## Normal usage

Install dokx:

    luarocks install dokx

Install packages with documentation:

    dokx-luarocks install myPackage

    OR

    dokx-luarocks make myPackage-0-0.rockspec

View documentation:

    dokx-browse

## Manually building a local documentation tree

If you want more control, you can manually build a local documentation tree as follows.

    # Install documentation system
    luarocks install dokx

    # Create a directory for the documentation tree
    mkdir -p ~/myDocs
    
    # For each project you want docs for:
    dokx-build-package-docs -o ~/myDocs /path/to/project/repository
    
    # Optionally you can also install docs for use from the Torch REPL - just specify the location:
    dokx-build-package-docs -o ~/myDocs --repl ~/usr/local/shate/lua/5.1/myPackage/doc/ /path/to/project/repository
    
    # OR, for projects in git, if you don't have them checked out:
    dokx-update-from-git -o ~/myDocs -b master git@github.com:githubUser/githubProject.git
    
    # Browse the created documentation
    open ~/myDocs/index.html

In case of error, append `--debug`, or raise an issue.

You can update the documentation at any time by re-running the same `dokx-...` command.
