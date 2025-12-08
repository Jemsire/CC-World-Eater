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
            -- Handle update requests with file streaming to avoid 64KB rednet limit
            if fs.isDir(message) then
                print('[Update] Directory found. Pulling files for turtle ' .. sender .. '.')
                -- First, build a list of all files to send
                local file_list = {}
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
                            table.insert(file_list, sub_dir_name)
                        end
                    end
                end

                -- Store update info for this turtle
                state.pending_updates[sender] = {
                    file_list = file_list,
                    current_index = 0,  -- Will be incremented to 1 when ready
                    path = message,
                    file_count = #file_list,
                    ready = false
                }

                -- Send file list and count to turtle immediately (non-blocking)
                print('[Update] Sent ' .. sender .. ' ' .. #file_list .. ' files list. Waiting for ready signal...')
                rednet.send(sender, {
                    hub_id = os.getComputerID(),
                    file_count = #file_list,
                    file_list = file_list
                }, 'update_start')
            end
            
        elseif protocol == 'update_ready' then
            -- Turtle is ready to receive files, start streaming
            local update_info = state.pending_updates[sender]
            if update_info and not update_info.ready then
                update_info.ready = true
                update_info.current_index = 1
                print('[Update] Turtle ' .. sender .. ' is ready. Starting file transfer...')
                
                -- Send first file
                local file_name = update_info.file_list[1]
                local file_path = fs.combine(update_info.path, file_name)
                local file = fs.open(file_path, 'r')
                if file then
                    local content = file.readAll()
                    file.close()
                    
                    rednet.send(sender, {
                        index = 1,
                        total = update_info.file_count,
                        name = file_name,
                        content = content
                    }, 'update_file')
                    print('[Update] Sent file 1/' .. update_info.file_count .. ' to turtle ' .. sender)
                else
                    rednet.send(sender, {error = 'Could not open file: ' .. file_name}, 'update_error')
                    state.pending_updates[sender] = nil
                end
            end
            
        elseif protocol == 'update_file_ack' then
            -- Turtle acknowledged receiving a file, send next file
            local update_info = state.pending_updates[sender]
            if update_info and update_info.ready then
                -- Verify the ack matches expected index
                local expected_index = update_info.current_index
                if message == expected_index then
                    update_info.current_index = update_info.current_index + 1
                    
                    -- Check if more files to send
                    if update_info.current_index <= update_info.file_count then
                        -- Send next file
                        local file_name = update_info.file_list[update_info.current_index]
                        local file_path = fs.combine(update_info.path, file_name)
                        local file = fs.open(file_path, 'r')
                        if file then
                            local content = file.readAll()
                            file.close()
                            
                            rednet.send(sender, {
                                index = update_info.current_index,
                                total = update_info.file_count,
                                name = file_name,
                                content = content
                            }, 'update_file')
                            print('[Update] Sent file ' .. update_info.current_index .. '/' .. update_info.file_count .. ' to turtle ' .. sender)
                        else
                            rednet.send(sender, {error = 'Could not open file: ' .. file_name}, 'update_error')
                            state.pending_updates[sender] = nil
                        end
                    else
                        -- All files sent, send completion signal
                        rednet.send(sender, {complete = true}, 'update_complete')
                        print('[Update] Completed file transfer to turtle ' .. sender)
                        state.pending_updates[sender] = nil
                    end
                else
                    -- Index mismatch, send error
                    rednet.send(sender, {error = 'File index mismatch. Expected ' .. expected_index .. ', got ' .. message}, 'update_error')
                    state.pending_updates[sender] = nil
                end
            end
        end
        
    elseif event[1] == 'monitor_touch' then
        if state.monitor_touches then
            table.insert(state.monitor_touches, {x = event[3], y = event[4]})
        end
    end
end