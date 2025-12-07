-- ============================================
-- Turtle API Initialization
-- Load this file at the start of any thread that needs APIs
-- ============================================

-- ============================================
-- API Manager Class
-- Centralized data store with getters/setters
-- ============================================
local API = {}
API.__index = API

-- Shared data storage (global so all threads share the same state)
-- Use a global table so all threads/modules share the same data
-- In ComputerCraft, multishell threads are coroutines that share _G, so this works across threads
if not _G._API_DATA then
    _G._API_DATA = {
        config = nil,
        state = nil,
        utilities = nil,
        loaded = false
    }
end
-- All threads reference the same global table
local _data = _G._API_DATA

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
    
    -- Load config (sets global bedrock_level, then we create config table)
    if not _data.config then
        local config_path = get_api_path('config.lua')
        local func = loadfile(config_path)
        if not func then
            error("Failed to load config.lua from: " .. config_path)
        end
        func() -- Execute to set bedrock_level global
        
        -- Create config table to reference globals from config.lua
        -- Note: Most config is loaded from hub during initialization, this is just for turtle-specific defaults
        _data.config = {
            bedrock_level = bedrock_level
            -- Other config properties (locations, use_chunky_turtles, etc.) will be set by hub during initialization
        }
        
        -- Also set global config for compatibility
        config = _data.config
    end
    
    -- Load state (sets global variables, then we create state table)
    if not _data.state then
        local state_path = get_api_path('state.lua')
        local func = loadfile(state_path)
        if not func then
            error("Failed to load state.lua from: " .. state_path)
        end
        func() -- Execute to set global state variables
        
        -- Create state table from globals (state is used as a table throughout the codebase)
        -- Properties can be added dynamically (like session_id, location, orientation, etc.)
        _data.state = {
            initialized = initialized,
            busy = busy,
            success = success,
            request_id = request_id,
            requests = requests,
            last_ping = last_ping
        }
        
        -- Also set global state for compatibility (used throughout turtle code)
        state = _data.state
    end
    
    -- Load utilities (returns a table)
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
        
        -- Also set global utilities for compatibility
        utilities = _data.utilities
    end
    
    -- Load all other API modules (these create global functions)
    -- Only load if not already loaded (check for a function from each module)
    if not forward then
        local func = loadfile(get_api_path('movement.lua'))
        if func then func() end
    end
    
    if not go_to_home then
        local func = loadfile(get_api_path('navigation.lua'))
        if func then func() end
    end
    
    if not detect_ore then
        local func = loadfile(get_api_path('detection.lua'))
        if func then func() end
    end
    
    if not dump_items then
        local func = loadfile(get_api_path('item_management.lua'))
        if func then func() end
    end
    
    if not mine_column_down then
        local func = loadfile(get_api_path('mining.lua'))
        if func then func() end
    end
    
    if not calibrate then
        local func = loadfile(get_api_path('turtle_utilities.lua'))
        if func then func() end
    end
    
    if not actions then
        local func = loadfile(get_api_path('actions.lua'))
        if func then func() end
    end
    
    _data.loaded = true
end

-- Make API globally accessible
_G.API = API

-- Auto-initialize when this file is loaded
API.init()

