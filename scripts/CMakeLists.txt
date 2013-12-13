INSTALL(PROGRAMS
    dokx-build-package-docs
    dokx-build-search-index
    dokx-init
    dokx-browse
    dokx-update-from-git
    dokx-luarocks
    dokx-search
    DESTINATION bin)

IF(CMAKE_BUILD_TYPE STREQUAL "Debug")
    message("Debug build: installing low-level commands")

    INSTALL(PROGRAMS
        dokx-combine-html
        dokx-combine-toc
        dokx-extract-toc
        dokx-extract-markdown
        dokx-generate-html
        dokx-generate-html-index
    DESTINATION bin)

ENDIF()
