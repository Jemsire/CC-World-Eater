function parse_requests()
    -- PROCESS ALL REDNET REQUESTS
    while #state.requests > 0 do
        local request = table.remove(state.requests, 1)
        sender, message, protocol = request[1], request[2], request[3]
        if message.action == 'shutdown' then
            os.shutdown()
        elseif message.action == 'reboot' then
            os.reboot()
        elseif message.action == 'update' then
            -- Write force flag to file if present, so update script can read it
            if message.force then
                local force_file = fs.open('/update_force', 'w')
                if force_file then
                    force_file.write('true')
                    force_file.close()
                end
            else
                -- Remove force file if it exists (in case of previous force update)
                if fs.exists('/update_force') then
                    fs.delete('/update_force')
                end
            end
            os.run({}, '/update')
        elseif message.request_id == -1 or message.request_id == state.request_id then -- MAKE SURE REQUEST IS CURRENT
            if state.initialized or message.action == 'initialize' then
                local data_str = globals.format_directive_data(message.action, message.data or {})
                print('Directive: ' .. message.action .. data_str)
                state.busy = true
                state.success = actions[message.action](unpack(message.data)) -- EXECUTE DESIRED FUNCTION WITH DESIRED ARGUMENTS
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