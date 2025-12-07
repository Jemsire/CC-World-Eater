-- ============================================
-- Shared API Initialization
-- Load this file at the start of any thread that needs APIs
-- ============================================

-- ============================================
-- API Manager Class
-- Centralized data store with getters/setters
-- ============================================
local API = {}
API.__index = API

-- Private data storage
local _data = {
    config = nil,
    state = nil,
    utilities = nil,
    loaded = false
}

-- Determine the base path for loading files
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

-- Getters
function API.getConfig()
    return _data.config
end

function API.getState()
    return _data.state
end

function API.getUtilities()
    return _data.utilities
end

function API.isLoaded()
    return _data.loaded
end

-- Setters
function API.setConfig(newConfig)
    _data.config = newConfig
end

function API.setState(newState)
    _data.state = newState
end

function API.setUtilities(newUtilities)
    _data.utilities = newUtilities
end

-- Initialize function - loads all APIs
function API.init()
    if _data.loaded then
        return -- Already initialized
    end
    
    -- Load config
    if not _data.config then
        local config_path = get_api_path('config.lua')
        local func = loadfile(config_path)
        if not func then
            error("Failed to load config.lua from: " .. config_path)
        end
        _data.config = func()
        if not _data.config then
            error("Failed to load config.lua - file returned nil")
        end
    end
    
    -- Load state
    if not _data.state then
        local state_path = get_api_path('state.lua')
        local func = loadfile(state_path)
        if not func then
            error("Failed to load state.lua from: " .. state_path)
        end
        _data.state = func()
        if not _data.state then
            error("Failed to load state.lua - file returned nil")
        end
    end
    
    -- Load utilities
    if not _data.utilities then
        local utilities_path = get_api_path('utilities.lua')
        local func = loadfile(utilities_path)
        if not func then
            error("Failed to load utilities.lua from: " .. utilities_path)
        end
        local result = func()
        
        if result then
            -- File returned a table, use it
            _data.utilities = result
        else
            -- File didn't return anything, error (utilities.lua should return a table)
            error("Failed to load utilities.lua - file returned nil. utilities.lua must return a table.")
        end
        
        if not _data.utilities then
            error("Failed to load utilities.lua - could not create utilities table")
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
    
    _data.loaded = true
end

-- Make API globally accessible
_G.API = API

-- Auto-initialize when this file is loaded
API.init()

