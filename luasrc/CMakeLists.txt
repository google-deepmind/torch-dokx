# install the lua code for the dokx package
FILE(GLOB luasrc "*.lua")
ADD_TORCH_PACKAGE(dokx "" "${luasrc}")

