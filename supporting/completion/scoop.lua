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

-- region Helpers
local booleanParser = parser({'true', 'false'})
local architectureParser = parser({'32bit', '64bit'})
local utilityParser = parser({'native', 'aria2'})
-- region Functions

local function getChildItemDirectory(path)
    dir = clink.find_dirs(path)
    -- Remove .. and . from table of directories
    table.remove(dir, 1)
    table.remove(dir, 1)

    return dir
end

local function getLocallyAddedBucket()
    return getChildItemDirectory(scoopEnvironment..'\\buckets\\*')
end

local function selectBaseName(path)
    local names = {}

    for k, v in pairs(path) do
        names[k] = string.match(v, '(.+)%.')
    end

    return names
end

local function getLocallyAvailableApplicationsByScoop()
    local apps = {}
    local i = 0
    local buckets = scoopEnvironment .. '\\buckets\\'

    for _, bucket in pairs(getLocallyAddedBucket()) do
        local bucketFolder = buckets .. bucket
        local nestedFolder = bucketFolder .. '\\bucket'

        if clink.is_dir(nestedFolder) then
            bucketFolder = nestedFolder
        end

        for u, app in pairs(selectBaseName(clink.find_files(bucketFolder .. '\\*.*'))) do
            apps[i] = app
            i = i + 1
        end
    end

    return apps
end

local function getLocallyInstalledApplicationsByScoop()
    local installed = getChildItemDirectory(scoopEnvironment .. '\\apps\\*')
    local i = #installed

    if scoopGlobalEnvironment then
        for _, dir in pairs(getChildItemDirectory(scoopGlobalEnvironment .. '\\apps\\*')) do
            installed[i] = dir
            i = i + 1
        end
    end

    return installed
end
-- endregion Functions
-- endregion Helpers

local scoopParser = parser({
    'alias' .. parser({
        'add',
        'list' .. parser({'-v', '--verbose'}),
        'rm'
    }),
    'cat' .. parser({getLocallyAvailableApplicationsByScoop}),
    'checkup',
    'cleanup' .. parser({getLocallyInstalledApplicationsByScoop},
        '-g', '--global',
        '-k', '--cache'
    ):loop(1),
    'depends' .. parser({getLocallyAvailableApplicationsByScoop}),
    'download' .. parser({getLocallyAvailableApplicationsByScoop},
        '-a' .. architectureParser, '--arch' .. architectureParser,
        '-b', '--all-architectures',
        '-s', '--skip',
        '-u' .. utilityParser, '--utility' .. utilityParser
    ):loop(1),
    'export',
    'hold' .. parser({getLocallyInstalledApplicationsByScoop},
        '-g', '--global'
    ):loop(1),
    'home' .. parser({getLocallyAvailableApplicationsByScoop}),
    'info' .. parser({getLocallyAvailableApplicationsByScoop}),
    'install' .. parser({getLocallyAvailableApplicationsByScoop},
        '-a' .. architectureParser, '--arch' .. architectureParser,
        '-g', '--global',
        '-i', '--independent',
        '-k', '--no-cache',
        '-s', '--skip'
    ):loop(1),
    'list',
    'prefix' .. parser({getLocallyInstalledApplicationsByScoop}),
    'reset' .. parser({getLocallyInstalledApplicationsByScoop}):loop(1),
    'search',
    'status',
    'unhold' .. parser({getLocallyInstalledApplicationsByScoop},
        '-g', '--global'
    ):loop(1),
    'uninstall' .. parser({getLocallyInstalledApplicationsByScoop},
        '-g', '--global',
        '-p', '--purge'
    ):loop(1),
    'update' .. parser({getLocallyInstalledApplicationsByScoop},
        '-f', '--force',
        '-g', '--global',
        '-i', '--independent',
        '-k', '--no-cache',
        '-s', '--skip',
        '-q', '--quiet'
    ):loop(1),
    'virustotal' .. parser({getLocallyAvailableApplicationsByScoop},
        '-a' .. architectureParser, '--arch' .. architectureParser,
        '-s', '--scan',
        '-n', '--no-depends'
    ):loop(1),
    'which',









    'bucket' ..parser({
        'rm' ..parser({getLocallyAddedBucket})
    }),
    'cache',
    'config'
})
local scoopHelpParser = parser({
    '/?',
    '-h', '--help',
    '--version',
    'help' ..parser(scoopParser:flatten_argument(1))
})

clink.arg.register_parser('scoop', scoopParser)
clink.arg.register_parser('scoop', scoopHelpParser)
clink.arg.register_parser('shovel', scoopParser)
clink.arg.register_parser('shovel', scoopHelpParser)
