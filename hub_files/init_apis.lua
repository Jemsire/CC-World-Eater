-- ============================================
-- Shared API Initialization
-- Load this file at the start of any thread that needs APIs
-- ============================================

-- Determine the base path for loading files
-- If this file is loaded from root (/), use absolute paths
-- If loaded relatively, try to detect the correct path
local function get_api_path(filename)
    -- Try absolute path first (most reliable)
    if fs.exists('/apis/' .. filename) then
        return '/apis/' .. filename
    end
    -- Fallback to relative path
    return 'apis/' .. filename
end

-- Load config if not already loaded (config.lua creates the config table itself)
if not config then
    local config_path = get_api_path('config.lua')
    loadfile(config_path)()
end

-- Load state if not already loaded (state.lua creates the state table itself)
if not state then
    local state_path = get_api_path('state.lua')
    loadfile(state_path)()
end

-- Load utilities if not already loaded (utilities.lua returns a table)
if not utilities then
    local utilities_path = get_api_path('utilities.lua')
    utilities = loadfile(utilities_path)()
    if not utilities then
        error("Failed to load utilities.lua")
    end
end

-- Create a global API registry for easy access
-- This allows code to access APIs through a single object
if not apis then
    apis = {}
    apis.config = config
    apis.state = state
    apis.utilities = utilities
end

