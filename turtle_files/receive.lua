-- CONTINUOUSLY RECIEVE REDNET MESSAGES
while true do
    signal = {rednet.receive('mastermine')}
    if signal[2].action == 'shutdown' then
        os.shutdown()
    elseif signal[2].action == 'reboot' then
        os.reboot()
    else
        -- Pass all messages (including update) to mastermine.lua for proper handling
        -- mastermine.lua needs to handle update to create force file before running update script
        table.insert(state.requests, signal)
    end
end