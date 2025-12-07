-- Load all APIs through init_apis.lua (handles all API loading)
loadfile('/init_apis.lua')()

-- Get references from API class
local state = API.getState()

-- Register handlers with data thread
DataThread.registerHandler('user_input', function(sender, message, protocol)
    -- Get current user_input array
    local state = API.getState()
    table.insert(state.user_input, message)
    -- Update through data thread (append to array)
    -- Note: We need to get the full array, modify, and set it back
    -- For efficiency, we'll update the whole user_input array
    local updated_input = state.user_input
    DataThread.updateData('state.user_input', updated_input)
end)

DataThread.registerHandler('turtle_report', function(sender, message, protocol)
    -- Get current state
    local state = API.getState()
    
    if not state.turtles[sender] then
        -- Initialize new turtle entry
        DataThread.updateData('state.turtles.' .. sender, {
            id = sender,
            tasks = {},
            ready = false
        })
        state = API.getState()  -- Refresh state
    end
    
    -- Handle config_received handshake
    if message and message.action == 'config_received' then
        local turtle = state.turtles[sender]
        if not turtle.ready then
            -- Get hub's current session_id to verify handshake
            local hub_session_id = nil
            if fs.exists('/session_id') then
                local session_file = fs.open('/session_id', 'r')
                if session_file then
                    hub_session_id = tonumber(session_file.readAll())
                    session_file.close()
                end
            end
            
            -- Verify handshake: message must have session_id matching hub's current session_id
            if message.session_id and hub_session_id and message.session_id == hub_session_id then
                -- Mark turtle as ready and flag that it just became ready
                local was_ready = turtle.ready or false
                DataThread.updateData('state.turtles.' .. sender .. '.ready', true)
                DataThread.updateData('state.turtles.' .. sender .. '.just_became_ready', not was_ready)
                print('Turtle ' .. sender .. ' ready')
            end
        end
    end
    
    -- Update turtle data
    DataThread.updateData('state.turtles.' .. sender .. '.data', message)
    DataThread.updateData('state.turtles.' .. sender .. '.last_update', os.clock())
end)

DataThread.registerHandler('pocket_report', function(sender, message, protocol)
    local state = API.getState()
    if not state.pockets[sender] then
        DataThread.updateData('state.pockets.' .. sender, {id = sender})
        state = API.getState()  -- Refresh state
    end
    DataThread.updateData('state.pockets.' .. sender .. '.data', message)
    DataThread.updateData('state.pockets.' .. sender .. '.last_update', os.clock())
end)

DataThread.registerHandler('update_request', function(sender, message, protocol)
    if fs.isDir(message) then
        local update_package = {}
        local queue = {''}
        while #queue > 0 do
            dir_name = table.remove(queue)
            path_name = fs.combine(message, dir_name)
            for _, object_name in pairs(fs.list(path_name)) do
                sub_dir_name = fs.combine(dir_name, object_name)
                sub_path_name = fs.combine(message, sub_dir_name)
                if fs.isDir(sub_path_name) then
                    table.insert(queue, sub_dir_name)
                else
                    local file = fs.open(sub_path_name, 'r')
                    update_package[sub_dir_name] = file.readAll()
                    file.close()
                end
            end
        end
        update_package.hub_id = os.getComputerID()
        DataThread.send(sender, update_package, 'update_package')
    end
end)

DataThread.registerHandler('update_complete', function(sender, message, protocol)
    -- Turtle has completed its update
    if on_update_complete then
        on_update_complete(sender)
    end
end)

-- Handle monitor touches
while true do
    event = {os.pullEvent()}
    if event[1] == 'monitor_touch' then
        if state.monitor_touches then
            table.insert(state.monitor_touches, {x = event[3], y = event[4]})
        end
    end
end