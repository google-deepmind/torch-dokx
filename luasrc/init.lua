--[[

Utilities for extracting and rendering documentation for Torch packages.

--]]

dokx = {}

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

-- Calling this puts dokx into debug mode.
function dokx.debugMode()
    dokx.logger:setLevel(logging.DEBUG)
end
