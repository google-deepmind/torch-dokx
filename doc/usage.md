# Using torch-dokx

Dokx is intended to be simple to use. There are no special tags needed when you
write your documentation.  Just write Markdown comments in your code, and dokx
will extract them as appropriate.

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

    Args:
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
render it for you (using MathJax) if you surround the mathematics with `$$`
pairs. You can use either LaTeX or MathML.

### Example

    --[[ This function computes the PDF for a Binomial distribution.
    
    The density is given by the formula
    
        $$ P(E) = {n \choose k} p^k (1-p)^{n-k} $$

    Args:
    * `n` - number of independent trials
    * `k` - number of successes
    * `p` - probability of success
    
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

#### filter

A [Lua pattern](http://www.lua.org/pil/20.2.html) against which potential input
files will be tested. Only Lua files which match the pattern will be included
in the generated documentation. By default, all Lua files in the project will
be included.

#### tocLevel

A string indicating how detailed the table of contents in the generated HTML
should be. The default is to generate an entry for every documented function,
but in large projects, this might be excessive. Valid values are 'function' and
'class'.

# Building documentation

## Command-line interface

The following commands provide full control over the various parts of the documentation-generation process. For more detailed information, pass `--help` to the command you're interested in.

High-level commands:

* **dokx-update-from-github** - fetch a package from GitHub and build its documentation
* **dokx-build-package-docs** - build documentation for a package already on disk

Low-level commands:

* **dokx-extract-toc** - extract table-of-contents components from Lua sources
* **dokx-extract-markdown** - extract Markdown components from Lua sources
* **dokx-generate-html** - convert Markdown components to HTML components
* **dokx-combine-toc** - combine table-of-contents components into one table for a package
* **dokx-combine-html** - combine HTML components and a table-of-contents into one page for a package
* **dokx-combine-markdown** - combine Markdown components into one markdown page for a package
* **dokx-generate-html-index** - generate an index page for a set of packages in a documentation tree
