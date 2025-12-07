-- ============================================
-- Data Thread API
-- Provides interface for other threads to interact with data thread
-- ============================================

-- Initialize shared data if not exists
if not _G._DATA_THREAD then
    _G._DATA_THREAD = {
        send_queue = {},
        broadcast_queue = {},
        handlers = {},
        request_queue = {},
        response_queue = {},
        initialized = false,
        apis = {}
    }
end

local _data = _G._DATA_THREAD

-- Wait for data thread to initialize
local function wait_for_init()
    local timeout = 100  -- 10 seconds max wait
    local count = 0
    while not _data.initialized and count < timeout do
        sleep(0.1)
        count = count + 1
    end
    if not _data.initialized then
        error("Data thread not initialized after 10 seconds")
    end
end

-- DataThread API object
local DataThread = {}

-- Send a message to a specific target
-- @param target: Computer ID to send to
-- @param message: Message table/data to send
-- @param protocol: Protocol name (optional, defaults to nil)
function DataThread.send(target, message, protocol)
    wait_for_init()
    table.insert(_data.send_queue, {
        target = target,
        message = message,
        protocol = protocol
    })
end

-- Broadcast a message to all computers
-- @param message: Message table/data to broadcast
-- @param protocol: Protocol name (optional, defaults to nil)
function DataThread.broadcast(message, protocol)
    wait_for_init()
    table.insert(_data.broadcast_queue, {
        message = message,
        protocol = protocol
    })
end

-- Register a handler for incoming messages
-- @param protocol: Protocol name to listen for (nil for all protocols)
-- @param handler: Function(sender, message, protocol) to call when message received
function DataThread.registerHandler(protocol, handler)
    wait_for_init()
    if not _data.handlers[protocol] then
        _data.handlers[protocol] = {}
    end
    table.insert(_data.handlers[protocol], handler)
end

-- Request data from data thread
-- @param resource: Resource to get ('config', 'state', 'utilities', or nested like 'state.turtles.123')
-- @return: The requested data (or nil if error)
function DataThread.getData(resource)
    wait_for_init()
    local request_id = os.clock() .. '_' .. math.random(10000)
    table.insert(_data.request_queue, {
        type = 'get',
        resource = resource,
        request_id = request_id
    })
    
    -- Wait for response (with timeout)
    local timeout = 50  -- 5 seconds
    local count = 0
    while count < timeout do
        -- Check response queue
        for i, resp in ipairs(_data.response_queue) do
            if resp.request_id == request_id then
                table.remove(_data.response_queue, i)
                if resp.error then
                    error("Data thread error: " .. tostring(resp.error))
                end
                return resp.data
            end
        end
        sleep(0.1)
        count = count + 1
    end
    
    error("Data thread request timeout for: " .. tostring(resource))
end

-- Update data in data thread
-- @param resource: Resource to update (e.g., 'state.turtles.123.data')
-- @param value: Value to set
function DataThread.updateData(resource, value)
    wait_for_init()
    local request_id = os.clock() .. '_' .. math.random(10000)
    table.insert(_data.request_queue, {
        type = 'update',
        resource = resource,
        value = value,
        request_id = request_id
    })
    
    -- Wait for response (with timeout)
    local timeout = 50  -- 5 seconds
    local count = 0
    while count < timeout do
        -- Check response queue
        for i, resp in ipairs(_data.response_queue) do
            if resp.request_id == request_id then
                table.remove(_data.response_queue, i)
                if resp.error then
                    error("Data thread error: " .. tostring(resp.error))
                end
                return resp.success
            end
        end
        sleep(0.1)
        count = count + 1
    end
    
    error("Data thread update timeout for: " .. tostring(resource))
end

-- Check if data thread is initialized
function DataThread.isInitialized()
    return _data.initialized == true
end

-- Make DataThread globally accessible
_G.DataThread = DataThread

return DataThread
