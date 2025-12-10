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
            print('[Update] Received update directive, force=' .. tostring(message.force or false))
            if message.force then
                local force_file = fs.open('/update_force', 'w')
                if force_file then
                    force_file.write('true')
                    force_file.close()
                    print('[Update] Created /update_force file')
                else
                    print('[Update] ERROR: Failed to create /update_force file!')
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
                
                -- Build enhanced log message with state and target info
                local log_parts = {'Directive: ' .. message.action .. data_str}
                
                -- Add current location and orientation
                if state.location then
                    local loc_str = string.format('@ (%d,%d,%d)', state.location.x, state.location.y, state.location.z)
                    if state.orientation then
                        loc_str = loc_str .. ' facing ' .. state.orientation
                    end
                    table.insert(log_parts, 'Current: ' .. loc_str)
                end
                
                -- Add target block/location info if available
                if message.data and #message.data > 0 then
                    local target_info = {}
                    for i, data_item in ipairs(message.data) do
                        if type(data_item) == 'table' then
                            if data_item.x and data_item.y and data_item.z then
                                local target_str = string.format('Target: (%d,%d,%d)', data_item.x, data_item.y, data_item.z)
                                if data_item.orientation then
                                    target_str = target_str .. ' facing ' .. data_item.orientation
                                end
                                table.insert(target_info, target_str)
                            elseif data_item.name then
                                table.insert(target_info, 'Target: ' .. tostring(data_item.name))
                            end
                        elseif type(data_item) == 'string' or type(data_item) == 'number' then
                            if message.action == 'prepare' and i == 1 then
                                table.insert(target_info, 'Min fuel: ' .. tostring(data_item))
                            elseif message.action == 'delay' and i == 1 then
                                table.insert(target_info, 'Duration: ' .. tostring(data_item) .. 's')
                            elseif message.action == 'face' and i == 1 then
                                table.insert(target_info, 'Face: ' .. tostring(data_item))
                            end
                        end
                    end
                    if #target_info > 0 then
                        table.insert(log_parts, table.concat(target_info, ', '))
                    end
                end
                
                -- Add fuel level if available
                local fuel_level = turtle.getFuelLevel()
                if fuel_level ~= 'unlimited' then
                    table.insert(log_parts, 'Fuel: ' .. tostring(fuel_level))
                else
                    table.insert(log_parts, 'Fuel: unlimited')
                end
                
                -- Add item count
                local item_count = 0
                for slot = 1, 16 do
                    item_count = item_count + turtle.getItemCount(slot)
                end
                if item_count > 0 then
                    table.insert(log_parts, 'Items: ' .. tostring(item_count))
                end
                
                print(table.concat(log_parts, ' | '))
                
                state.busy = true
                state.success = actions[message.action](unpack(message.data)) -- EXECUTE DESIRED FUNCTION WITH DESIRED ARGUMENTS
                state.busy = false
                
                -- Log result
                if state.success then
                    print('  -> Success')
                else
                    print('  -> Failed')
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