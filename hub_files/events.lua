-- Load shared APIs (config, state, utilities)
loadfile('/init_apis.lua')()

-- Load modules needed by events.lua
loadfile('/apis/version_management')()

while true do
    event = {os.pullEvent()}
    if event[1] == 'rednet_message' then
        local sender = event[2]
        local message = event[3]
        local protocol = event[4]
        
        if protocol == 'user_input' then
            table.insert(state.user_input, message)
        
        elseif protocol == 'turtle_report' then
            if not state.turtles[sender] then
                state.turtles[sender] = {id = sender}
            end
            state.turtles[sender].data = message
            state.turtles[sender].last_update = os.clock()
        
        elseif protocol == 'pocket_report' then
            if not state.pockets[sender] then
                state.pockets[sender] = {id = sender}
            end
            state.pockets[sender].data = message
            state.pockets[sender].last_update = os.clock()
            
        elseif protocol == 'update_request' then
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
                rednet.send(sender, update_package, 'update_package')
            end
        
        elseif protocol == 'update_complete' then
            -- Turtle has completed its update
            if on_update_complete then
                on_update_complete(sender)
            end
        end
        
    elseif event[1] == 'monitor_touch' then
        if state.monitor_touches then
            table.insert(state.monitor_touches, {x = event[3], y = event[4]})
        end
    end
end