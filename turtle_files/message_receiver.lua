-- Load all APIs through init_apis.lua (handles all API loading)
loadfile('/init_apis.lua')()

-- Get references from API class
local state = API.getState()

-- CONTINUOUSLY RECIEVE REDNET MESSAGES
while true do
    local success, err = pcall(function()
        signal = {rednet.receive('mastermine')}
        if signal and signal[2] and signal[2].action then
            print('=== MESSAGE RECEIVER: Got command ' .. tostring(signal[2].action) .. ' from ' .. tostring(signal[1]) .. ' ===')
            if signal[2].action == 'shutdown' then
                os.shutdown()
            elseif signal[2].action == 'reboot' then
                os.reboot()
            elseif signal[2].action == 'update' then
                os.run({}, '/update')
            else
                table.insert(state.requests, signal)
                print('=== MESSAGE RECEIVER: Added to queue: ' .. tostring(signal[2].action) .. ' ===')
            end
        else
            print('=== MESSAGE RECEIVER: Received malformed message ===')
        end
    end)
    if not success then
        print('ERROR in message_receiver: ' .. tostring(err))
        sleep(1)  -- Wait before retrying to avoid spam
    end
end