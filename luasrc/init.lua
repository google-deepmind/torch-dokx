--[[

Utilities for extracting and rendering documentation for Torch packages.

--]]

dokx = {}

require 'dok'
require 'logging.console'
dokx.logger = logging.console()
dokx.logger:setLevel(logging.WARN)

torch.include('dokx', 'markdown.lua')
torch.include('dokx', 'parse.lua')
torch.include('dokx', 'utils.lua')
torch.include('dokx', 'testUtils.lua')
torch.include('dokx', 'shell.lua')
torch.include('dokx', 'entities.lua')
torch.include('dokx', 'extract.lua')
torch.include('dokx', 'luarocks.lua')
torch.include('dokx', 'search.lua')

dokx._inDebugMode = false

