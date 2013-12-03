INSTALL(FILES
    mathjax.html
    package.html
    packageIndex.html
    syntax.html
    style-index.css
    style-page.css
    DESTINATION ${Torch_INSTALL_LUA_PATH_SUBDIR}/dokx/templates)

INSTALL(DIRECTORY
    highlight
    DESTINATION ${Torch_INSTALL_LUA_PATH_SUBDIR}/dokx/templates)

