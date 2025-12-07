-- APIs are loaded by startup.lua - this file uses globals from there

function parse_requests()
    -- PROCESS ALL REDNET REQUESTS
    while #state.requests > 0 do
        local request = table.remove(state.requests, 1)
        sender, message, protocol = request[1], request[2], request[3]
        
        -- Safety check: ensure message exists and has action
        if not message or not message.action then
            print('ERROR: Invalid request format - missing message or action')
            return
        end
        
        if message.action == 'shutdown' then
            os.shutdown()
        elseif message.action == 'reboot' then
            os.reboot()
        elseif message.action == 'update' then
            os.run({}, '/update')
        elseif message.request_id == -1 or message.request_id == state.request_id then -- MAKE SURE REQUEST IS CURRENT
            if state.initialized or message.action == 'initialize' then
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
                    else
                        print('ERROR executing action "' .. tostring(message.action) .. '": ' .. tostring(result))
                        state.success = false
                    end
                end
                state.busy = false
                if not state.success then
                    sleep(1)
                end
                state.request_id = state.request_id + 1
            end
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