--[[

Utilities for extracting and rendering documentation for Torch packages.

--]]

dokx = {}

require 'torch'
require 'dok'
require 'logroll'
dokx.logger = logroll.print_logger()
dokx.logger.level = logroll.WARN

torch.include('dokx', 'markdown.lua')
torch.include('dokx', 'parse.lua')
torch.include('dokx', 'utils.lua')
torch.include('dokx', 'testUtils.lua')
torch.include('dokx', 'shell.lua')
torch.include('dokx', 'entities.lua')
torch.include('dokx', 'extract.lua')
torch.include('dokx', 'luarocks.lua')
torch.include('dokx', 'search.lua')
torch.include('dokx', 'package.lua')

dokx._inDebugMode = false

