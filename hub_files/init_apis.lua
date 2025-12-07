-- ============================================
-- Shared API Initialization
-- Load this file at the start of any thread that needs APIs
-- ============================================

-- Determine the base path for loading files
-- Tries absolute path first, then relative path
local function get_api_path(filename)
    -- Try absolute path first (most reliable)
    if fs.exists('/apis/' .. filename) then
        return '/apis/' .. filename
    end
    -- Fallback to relative path
    if fs.exists('apis/' .. filename) then
        return 'apis/' .. filename
    end
    -- If neither exists, return absolute path anyway (will error with helpful message)
    return '/apis/' .. filename
end

-- Load config if not already loaded (config.lua creates the config table itself)
if not config then
    local config_path = get_api_path('config.lua')
    local func = loadfile(config_path)
    if not func then
        error("Failed to load config.lua from: " .. config_path)
    end
    func()
end

-- Load state if not already loaded (state.lua creates the state table itself)
if not state then
    local state_path = get_api_path('state.lua')
    local func = loadfile(state_path)
    if not func then
        error("Failed to load state.lua from: " .. state_path)
    end
    func()
end

-- Load utilities if not already loaded (utilities.lua returns a table)
if not utilities then
    local utilities_path = get_api_path('utilities.lua')
    local func = loadfile(utilities_path)
    if not func then
        error("Failed to load utilities.lua from: " .. utilities_path)
    end
    utilities = func()
    if not utilities then
        error("Failed to load utilities.lua - file returned nil")
    end
end

-- Load all other API modules (these create global functions)
-- Only load if not already loaded (check for a function from each module)
if not load_mine then
    local func = loadfile(get_api_path('block_management.lua'))
    if func then func() end
end

if not get_closest_unmined_block then
    local func = loadfile(get_api_path('turtle_assignment.lua'))
    if func then func() end
end

if not get_hub_version then
    local func = loadfile(get_api_path('version_management.lua'))
    if func then func() end
end

if not add_task then
    local func = loadfile(get_api_path('task_management.lua'))
    if func then func() end
end

if type(user_input) ~= "function" then
    local func = loadfile(get_api_path('user_commands.lua'))
    if func then func() end
end

if not command_turtles then
    local func = loadfile(get_api_path('state_machine.lua'))
    if func then func() end
end

-- Create a global API registry for easy access
-- This allows code to access APIs through a single object
if not apis then
    apis = {}
    apis.config = config
    apis.state = state
    apis.utilities = utilities
end

