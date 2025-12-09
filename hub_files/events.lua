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
            
            -- Track blocks mined increment
            local old_blocks_mined = state.turtles[sender].data and state.turtles[sender].data.blocks_mined or 0
            local new_blocks_mined = message.blocks_mined or 0
            local blocks_delta = new_blocks_mined - old_blocks_mined
            
            state.turtles[sender].data = message
            state.turtles[sender].last_update = os.clock()
            
            -- Update total blocks mined if turtle reported new blocks
            -- Only process if mine is initialized and delta is positive (ignore negative deltas from turtle restarts)
            if blocks_delta > 0 and state.mine then
                -- Ensure mine_dir_path is available (may not be set if load_mine hasn't run yet)
                local mine_dir_path = state.mine_dir_path
                if not mine_dir_path and config and config.locations and config.locations.mine_enter then
                    mine_dir_path = '/mine/' .. config.locations.mine_enter.x .. ',' .. config.locations.mine_enter.z .. '/'
                end
                
                if mine_dir_path then
                    if not state.mine.total_blocks_mined then
                        state.mine.total_blocks_mined = 0
                    end
                    state.mine.total_blocks_mined = state.mine.total_blocks_mined + blocks_delta
                    
                    -- Save to disk
                    local total_blocks_file = mine_dir_path .. 'total_blocks_mined'
                    local file = fs.open(total_blocks_file, 'w')
                    if file then
                        file.write(tostring(state.mine.total_blocks_mined))
                        file.close()
                    end
                end
            end
            
            -- Persist version to disk if present
            if message.version then
                -- Construct turtles directory path (state.turtles_dir_path may not be set yet if load_mine() hasn't run)
                local turtles_dir_path = state.turtles_dir_path
                if not turtles_dir_path and config and config.locations and config.locations.mine_enter then
                    -- Fallback: construct from config if state not initialized yet
                    turtles_dir_path = '/mine/' .. config.locations.mine_enter.x .. ',' .. config.locations.mine_enter.z .. '/turtles/'
                end
                
                if turtles_dir_path then
                    local turtle_dir_path = turtles_dir_path .. sender .. '/'
                    if not fs.exists(turtle_dir_path) then
                        fs.makeDir(turtle_dir_path)
                    end
                    local version_file = fs.open(turtle_dir_path .. 'version.lua', 'w')
                    if version_file then
                        version_file.write('-- Turtle Version\n')
                        version_file.write('-- Persisted from turtle report\n')
                        version_file.write('return {\n')
                        version_file.write('    major = ' .. tostring(message.version.major or 0) .. ',\n')
                        version_file.write('    minor = ' .. tostring(message.version.minor or 0) .. ',\n')
                        version_file.write('    hotfix = ' .. tostring(message.version.hotfix or 0) .. ',\n')
                        if message.version.dev_suffix then
                            version_file.write('    dev_suffix = "' .. tostring(message.version.dev_suffix) .. '",\n')
                        end
                        if message.version.dev ~= nil then
                            version_file.write('    dev = ' .. tostring(message.version.dev) .. '\n')
                        end
                        version_file.write('}\n')
                        version_file.close()
                    end
                end
            end
        
        elseif protocol == 'pocket_report' then
            if not state.pockets[sender] then
                state.pockets[sender] = {id = sender}
            end
            state.pockets[sender].data = message
            state.pockets[sender].last_update = os.clock()
            
        elseif protocol == 'update_request' then
            -- Handle update requests with file streaming to avoid 64KB rednet limit
            if fs.isDir(message) then
                -- Check if turtle version matches hub version before updating
                local turtle = state.turtles[sender]
                local turtle_version = turtle and turtle.data and turtle.data.version
                
                -- Get hub version
                local hub_version = nil
                hub_version = lua_utils.load_file("/version.lua")
                
                -- Check if versions match (only update if different)
                -- Note: compare_versions only checks dev=true/false, not dev_suffix (which is for display only)
                if turtle_version and hub_version and github_api then
                    -- Compare versions (compares dev=true/false, ignores dev_suffix)
                    local comparison = github_api.compare_versions(turtle_version, hub_version)
                    
                    if comparison == 0 then
                        -- Versions match - turtle is up to date
                        local turtle_str = lua_utils.format_version(turtle_version) or "unknown"
                        local hub_str = lua_utils.format_version(hub_version) or "unknown"
                        print('[Update] Turtle ' .. sender .. ' is already up to date (turtle: ' .. turtle_str .. ', hub: ' .. hub_str .. '). Skipping update.')
                        rednet.send(sender, {error = 'Already up to date'}, 'update_error')
                        return
                    end
                elseif not turtle_version then
                    print('[Update] Warning: Turtle ' .. sender .. ' version not available. Proceeding with update.')
                elseif not hub_version then
                    print('[Update] Warning: Hub version not available. Proceeding with update.')
                end
                
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