-- APIs are loaded by startup.lua - this file uses globals from there

-- CONTINUOUSLY RECIEVE REDNET MESSAGES
while true do
    local success, err = pcall(function()
        signal = {rednet.receive('mastermine')}
        if signal and signal[2] and signal[2].action then
            local sender = signal[1]
            local message = signal[2]
            local action = message.action
            local request_id = message.request_id or 'nil'
            
            -- DEBUG: Show received commands
            local data_info = 'nil'
            if message.data then
                if type(message.data) == 'table' then
                    data_info = 'table with ' .. tostring(#message.data) .. ' elements'
                    if action == 'initialize' then
                        data_info = data_info .. ' [1]=' .. tostring(message.data[1]) .. ' [2]=' .. tostring(type(message.data[2]))
                    end
                else
                    data_info = tostring(type(message.data))
                end
            end
            print('[DEBUG] Received command: ' .. tostring(action) .. ' from ' .. tostring(sender) .. 
                  ' (request_id: ' .. tostring(request_id) .. ', current_request_id: ' .. tostring(state.request_id) .. 
                  ', initialized: ' .. tostring(state.initialized) .. ', data: ' .. data_info .. ')')
            
            if action == 'shutdown' then
                os.shutdown()
            elseif action == 'reboot' then
                os.reboot()
            elseif action == 'update' then
                os.run({}, '/update')
            else
                table.insert(state.requests, signal)
                print('[DEBUG] Queued action: ' .. tostring(action))
            end
        end
    end)
    if not success then
        print('ERROR in message_receiver: ' .. tostring(err))
        sleep(1)  -- Wait before retrying to avoid spam
    end
end