-- ============================================
-- API Proxy
-- Provides API interface that requests data from data thread
-- Data thread is the ONLY place APIs are actually loaded
-- ============================================

-- Load data thread API first
local function get_api_path(filename)
    if fs.exists('/apis/' .. filename) then
        return '/apis/' .. filename
    end
    if fs.exists('apis/' .. filename) then
        return 'apis/' .. filename
    end
    return '/apis/' .. filename
end

-- Load data thread API
if not DataThread then
    local func = loadfile(get_api_path('data_thread_api.lua'))
    if func then 
        func()
    else
        error("Failed to load data_thread_api.lua")
    end
end

-- Wait for data thread to initialize
while not DataThread.isInitialized() do
    sleep(0.1)
end

-- API Proxy Class - requests data from data thread instead of loading it
local API = {}
API.__index = API

-- Cache for frequently accessed data (threads can cache what they need)
local _cache = {
    config = nil,
    state = nil,
    utilities = nil,
    cache_time = {}
}

-- Cache timeout (refresh cache after this many seconds)
local CACHE_TIMEOUT = 0.1  -- Very short - data changes frequently

-- Helper to update state through data thread
function API.setStateValue(path, value)
    DataThread.updateData('state.' .. path, value)
    -- Clear cache to force refresh
    _cache.state = nil
    _cache.cache_time.state = nil
end

-- Helper to update config through data thread  
function API.setConfigValue(path, value)
    DataThread.updateData('config.' .. path, value)
    -- Clear cache to force refresh
    _cache.config = nil
    _cache.cache_time.config = nil
end

-- Helper to update turtle properties through data thread
function API.updateTurtle(turtle_id, property, value)
    DataThread.updateData('state.turtles.' .. turtle_id .. '.' .. property, value)
    -- Clear cache to force refresh
    _cache.state = nil
    _cache.cache_time.state = nil
end

-- Helper to get a turtle (with caching)
function API.getTurtle(turtle_id)
    local state_refresh = API.getState()
    return state_refresh.turtles[turtle_id]
end

-- Get config (with caching)
function API.getConfig()
    local now = os.clock()
    if not _cache.config or (now - (_cache.cache_time.config or 0)) > CACHE_TIMEOUT then
        _cache.config = DataThread.getData('config')
        _cache.cache_time.config = now
    end
    return _cache.config
end

-- Get state (with caching and proxy for auto-sync)
function API.getState()
    local now = os.clock()
    if not _cache.state or (now - (_cache.cache_time.state or 0)) > CACHE_TIMEOUT then
        local state_data = DataThread.getData('state')
        _cache.state = createStateProxy(state_data)
        _cache.cache_time.state = now
    end
    return _cache.state
end

-- Get utilities (with caching)
function API.getUtilities()
    local now = os.clock()
    if not _cache.utilities or (now - (_cache.cache_time.utilities or 0)) > CACHE_TIMEOUT then
        _cache.utilities = DataThread.getData('utilities')
        _cache.cache_time.utilities = now
    end
    return _cache.utilities
end

-- Update state (clears cache and updates data thread)
function API.updateState(path, value)
    _cache.state = nil  -- Clear cache
    _cache.cache_time.state = nil
    return DataThread.updateData('state.' .. path, value)
end

-- Update config (clears cache and updates data thread)
function API.updateConfig(path, value)
    _cache.config = nil  -- Clear cache
    _cache.cache_time.config = nil
    return DataThread.updateData('config.' .. path, value)
end

-- Check if APIs are loaded (always true since data thread handles it)
function API.isLoaded()
    return DataThread.isInitialized()
end

-- Make API globally accessible
_G.API = API

-- Note: We don't auto-load APIs here anymore - data thread does that
-- Other API modules (task_management, state_machine, etc.) will be loaded
-- by the data thread and their functions will be available globally
