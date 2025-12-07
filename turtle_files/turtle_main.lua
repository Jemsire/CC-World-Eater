-- Load all APIs through init_apis.lua (handles all API loading)
loadfile('/init_apis.lua')()

-- Get references from API class
local state = API.getState()

function parse_requests()
    -- PROCESS ALL REDNET REQUESTS
    while #state.requests > 0 do
        local request = table.remove(state.requests, 1)
        sender, message, protocol = request[1], request[2], request[3]
        print('=== TURTLE_MAIN: Processing request - action=' .. tostring(message.action) .. ' ===')
        if message.action == 'shutdown' then
            os.shutdown()
        elseif message.action == 'reboot' then
            os.reboot()
        elseif message.action == 'update' then
            os.run({}, '/update')
        elseif message.request_id == -1 or message.request_id == state.request_id then -- MAKE SURE REQUEST IS CURRENT
            if state.initialized or message.action == 'initialize' then
                print('=== TURTLE_MAIN: Directive: ' .. message.action .. ' ===')
                if message.action == 'initialize' then
                    print('=== TURTLE_MAIN: Processing initialize command ===')
                    print('=== TURTLE_MAIN: message.data=' .. tostring(message.data) .. ' ===')
                    if message.data and type(message.data) == 'table' then
                        print('=== TURTLE_MAIN: message.data[1] (session_id)=' .. tostring(message.data[1]) .. ' ===')
                        print('=== TURTLE_MAIN: message.data[2] (config)=' .. tostring(message.data[2]) .. ' ===')
                    end
                end
                state.busy = true
                -- Check if action exists
                if not actions[message.action] then
                    print('ERROR: Action "' .. tostring(message.action) .. '" not found in actions table')
                    state.success = false
                else
                    -- Safely unpack message.data (handle nil case)
                    local data = message.data or {}
                    local success, result = pcall(function()
                        return actions[message.action](unpack(data))
                    end)
                    if success then
                        state.success = result
                        if message.action == 'initialize' then
                            print('=== TURTLE_MAIN: initialize() returned: ' .. tostring(result) .. ' ===')
                        end
                    else
                        print('=== TURTLE_MAIN: ERROR executing action "' .. tostring(message.action) .. '": ' .. tostring(result) .. ' ===')
                        state.success = false
                    end
                end
                state.busy = false
                if not state.success then
                    sleep(1)
                end
                state.request_id = state.request_id + 1
            else
                -- Debug: why command was ignored
                print('DEBUG: Ignoring command "' .. tostring(message.action) .. '" - initialized=' .. tostring(state.initialized))
            end
        else
            -- Debug: request_id mismatch
            print('DEBUG: Request ID mismatch - received ' .. tostring(message.request_id) .. ', expected ' .. tostring(state.request_id))
        end
    end
end


function main()
    state.last_ping = os.clock()
    while true do
        parse_requests()
        sleep(0.3)
    end
end


main()