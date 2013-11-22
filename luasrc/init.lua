--[[

Utilities for extracting and rendering documentation for Torch packages.

--]]

dokx = {}

require 'logging.console'
dokx.logger = logging.console()
dokx.logger:setLevel(logging.DEBUG)

torch.include('dokx', 'markdown.lua')
torch.include('dokx', 'parse.lua')
