INSTALL(FILES
    mathjax.html
    package.html
    packageIndex.html
    syntax.html
    syntaxNoMathJax.html
    style-index.css
    style-page.css
    search.js
    DESTINATION ${Torch_INSTALL_LUA_PATH_SUBDIR}/dokx/templates)

INSTALL(DIRECTORY
    highlight
    DESTINATION ${Torch_INSTALL_LUA_PATH_SUBDIR}/dokx/templates)

