-- APIs are loaded by startup.lua - this file uses globals from there

-- CONTINUOUSLY RECIEVE REDNET MESSAGES
while true do
    local success, err = pcall(function()
        signal = {rednet.receive('mastermine')}
        if signal and signal[2] and signal[2].action then
            if signal[2].action == 'shutdown' then
                os.shutdown()
            elseif signal[2].action == 'reboot' then
                os.reboot()
            elseif signal[2].action == 'update' then
                os.run({}, '/update')
            else
                table.insert(state.requests, signal)
            end
        end
    end)
    if not success then
        print('ERROR in message_receiver: ' .. tostring(err))
        sleep(1)  -- Wait before retrying to avoid spam
    end
end