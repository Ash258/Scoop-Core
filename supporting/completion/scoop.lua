-- https://github.com/vladimir-kotikov/clink-completions/blob/f639287526d3599188a6639171837dc4bbc77923/vagrant.lua
local parser = clink.arg.new_parser

local scoopEnvironment = os.getenv('SCOOP')
local scoopGlobalEnvironment = os.getenv('SCOOP_GLOBAL')
if not scoopEnvironment then
    scoopEnvironment = os.getenv('userprofile')..'\\scoop'
end
if not scoopGlobalEnvironment then
    scoopGlobalEnvironment = os.getenv('programdata')..'\\Scoop'
end

-- region Functions
-- endregion Function

-- TODO: Implement
local scoopParser = parser({
    'search',
    'status',
    'which'
})
local scoopHelpParser = parser({
    'help' ..parser(scoopParser:flatten_argument(1))
})

clink.arg.register_parser('scoop', scoopParser)
clink.arg.register_parser('scoop', scoopHelpParser)
clink.arg.register_parser('shovel', scoopParser)
clink.arg.register_parser('shovel', scoopHelpParser)
