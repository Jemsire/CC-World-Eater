-- ============================================
-- Data Thread
-- Centralized data and API handler
-- ALL APIs and data are loaded and held here
-- Other threads request data as needed
-- ============================================

-- Determine the base path for loading files
local function get_api_path(filename)
    if fs.exists('/apis/' .. filename) then
        return '/apis/' .. filename
    end
    if fs.exists('apis/' .. filename) then
        return 'apis/' .. filename
    end
    return '/apis/' .. filename
end

-- Shared data storage for communication between threads
if not _G._DATA_THREAD then
    _G._DATA_THREAD = {
        -- Outgoing message queue
        send_queue = {},
        
        -- Broadcast queue
        broadcast_queue = {},
        
        -- Message handlers registered by other threads
        handlers = {},
        
        -- Data request queue (from other threads)
        request_queue = {},
        
        -- Data response queue (to other threads)
        response_queue = {},
        
        -- Initialization flag
        initialized = false,
        
        -- All API data stored here
        apis = {
            config = nil,
            state = nil,
            utilities = nil,
            -- Other API modules will be stored here as they're loaded
        }
    }
end

local _data = _G._DATA_THREAD

-- Load all APIs and data
print('Data thread: Loading all APIs...')

-- Load config
local config_path = get_api_path('config.lua')
local config_func = loadfile(config_path)
if not config_func then
    error("Data thread: Failed to load config.lua from: " .. config_path)
end
_data.apis.config = config_func()
if not _data.apis.config then
    error("Data thread: Failed to load config.lua - file returned nil")
end
print('Data thread: Config loaded')

-- Load state
local state_path = get_api_path('state.lua')
local state_func = loadfile(state_path)
if not state_func then
    error("Data thread: Failed to load state.lua from: " .. state_path)
end
_data.apis.state = state_func()
if not _data.apis.state then
    error("Data thread: Failed to load state.lua - file returned nil")
end
print('Data thread: State loaded')

-- Load utilities
local utilities_path = get_api_path('utilities.lua')
local utilities_func = loadfile(utilities_path)
if not utilities_func then
    error("Data thread: Failed to load utilities.lua from: " .. utilities_path)
end
local utilities_result = utilities_func()
if utilities_result then
    _data.apis.utilities = utilities_result
else
    error("Data thread: Failed to load utilities.lua - file returned nil")
end
print('Data thread: Utilities loaded')

-- Load all other API modules (these create global functions)
-- Block management
local block_mgmt_func = loadfile(get_api_path('block_management.lua'))
if block_mgmt_func then 
    block_mgmt_func()
    _data.apis.block_management = true
end

-- Turtle assignment
local turtle_assign_func = loadfile(get_api_path('turtle_assignment.lua'))
if turtle_assign_func then 
    turtle_assign_func()
    _data.apis.turtle_assignment = true
end

-- Version management
local version_mgmt_func = loadfile(get_api_path('version_management.lua'))
if version_mgmt_func then 
    version_mgmt_func()
    _data.apis.version_management = true
end

-- Task management
local task_mgmt_func = loadfile(get_api_path('task_management.lua'))
if task_mgmt_func then 
    task_mgmt_func()
    _data.apis.task_management = true
end

-- User commands
local user_cmds_func = loadfile(get_api_path('user_commands.lua'))
if user_cmds_func then 
    user_cmds_func()
    _data.apis.user_commands = true
end

-- State machine
local state_machine_func = loadfile(get_api_path('state_machine.lua'))
if state_machine_func then 
    state_machine_func()
    _data.apis.state_machine = true
end

print('Data thread: All APIs loaded')

-- Helper function to get nested value from path string (e.g., "state.turtles.123.data")
local function get_nested_value(data, path)
    local parts = {}
    for part in string.gmatch(path, "[^.]+") do
        table.insert(parts, part)
    end
    
    local current = data
    for _, part in ipairs(parts) do
        if type(current) == 'table' then
            current = current[part]
        else
            return nil
        end
    end
    return current
end

-- Helper function to set nested value
local function set_nested_value(data, path, value)
    local parts = {}
    for part in string.gmatch(path, "[^.]+") do
        table.insert(parts, part)
    end
    
    local current = data
    for i = 1, #parts - 1 do
        local part = parts[i]
        if not current[part] then
            current[part] = {}
        end
        current = current[part]
    end
    current[parts[#parts]] = value
end

-- Process data requests from other threads
local function process_data_requests()
    while #_data.request_queue > 0 do
        local req = table.remove(_data.request_queue, 1)
        local response = {request_id = req.request_id}
        
        if req.type == 'get' then
            -- Get data request
            if req.resource == 'config' then
                response.data = _data.apis.config
            elseif req.resource == 'state' then
                response.data = _data.apis.state
            elseif req.resource == 'utilities' then
                response.data = _data.apis.utilities
            elseif string.match(req.resource, "^config%.") then
                -- Nested config path
                local path = string.sub(req.resource, 8)  -- Remove "config." prefix
                response.data = get_nested_value(_data.apis.config, path)
            elseif string.match(req.resource, "^state%.") then
                -- Nested state path
                local path = string.sub(req.resource, 7)  -- Remove "state." prefix
                response.data = get_nested_value(_data.apis.state, path)
            else
                response.error = "Unknown resource: " .. tostring(req.resource)
            end
        elseif req.type == 'update' then
            -- Update data request
            if string.match(req.resource, "^state%.") then
                local path = string.sub(req.resource, 7)  -- Remove "state." prefix
                set_nested_value(_data.apis.state, path, req.value)
                response.success = true
            elseif string.match(req.resource, "^config%.") then
                local path = string.sub(req.resource, 8)  -- Remove "config." prefix
                set_nested_value(_data.apis.config, path, req.value)
                response.success = true
            else
                response.error = "Can only update state or config, got: " .. tostring(req.resource)
            end
        else
            response.error = "Unknown request type: " .. tostring(req.type)
        end
        
        table.insert(_data.response_queue, response)
    end
end

-- Initialize rednet
local function init_rednet()
    for _, side in pairs({'back', 'top', 'left', 'right'}) do
        if peripheral.getType(side) == 'modem' then
            rednet.open(side)
            print('Data thread: Rednet opened on side: ' .. side)
            return true
        end
    end
    print('Data thread: WARNING: No modem found, rednet not opened')
    return false
end

-- Initialize rednet on startup
local rednet_available = init_rednet()
_data.initialized = true
print('Data thread: Initialized and ready')

-- Main loop: handle sending, receiving, and data requests
while true do
    -- Process data requests first (high priority)
    process_data_requests()
    
    -- Process outgoing messages (send queue)
    while #_data.send_queue > 0 do
        local msg = table.remove(_data.send_queue, 1)
        if rednet_available then
            pcall(function()
                rednet.send(msg.target, msg.message, msg.protocol)
            end)
        end
    end
    
    -- Process broadcast messages
    while #_data.broadcast_queue > 0 do
        local msg = table.remove(_data.broadcast_queue, 1)
        if rednet_available then
            pcall(function()
                rednet.broadcast(msg.message, msg.protocol)
            end)
        end
    end
    
    -- Receive messages (non-blocking with short timeout to allow queue processing)
    if rednet_available then
        local sender, message, protocol = rednet.receive(0.05)
        if sender and message and protocol then
            -- Check if there's a handler for this protocol
            if protocol and _data.handlers[protocol] then
                -- Call all registered handlers for this protocol
                for _, handler in ipairs(_data.handlers[protocol]) do
                    pcall(handler, sender, message, protocol)
                end
            end
        end
    else
        -- If rednet not available, try to reinitialize periodically
        sleep(1)
        rednet_available = init_rednet()
    end
end
