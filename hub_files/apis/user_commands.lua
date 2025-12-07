-- ============================================
-- User Commands Module
-- Handles user input processing
-- ============================================
-- Uses globals: config, state (loaded via os.loadAPI)

function user_input(input)
    -- PROCESS USER INPUT FROM USER_INPUT TABLE
    while #state.user_input > 0 do
        local input = table.remove(state.user_input, 1)
        local next_word = string.gmatch(input, '%S+')
        local command = next_word()
        local turtle_id_string = next_word()
        local turtle_id
        local turtles = {}
        if turtle_id_string and turtle_id_string ~= '*' then
            turtle_id = tonumber(turtle_id_string)
            if state.turtles[turtle_id] then
                turtles = {state.turtles[turtle_id]}
            end
        else
            turtles = state.turtles
        end
        if command == 'turtle' then
            -- SEND COMMAND DIRECTLY TO TURTLE
            local action = next_word()
            local data = {}
            for user_arg in next_word do
                table.insert(data, user_arg)
            end
            for _, turtle in pairs(turtles) do
                halt(turtle)
                add_task(turtle, {
                    action = action,
                    data = data,
                })
            end
        elseif command == 'clear' then
            for _, turtle in pairs(turtles) do
                turtle.tasks = {}
                add_task(turtle, {action = 'pass'})
            end
        elseif command == 'shutdown' then
            -- SHUTDOWN TURTLE(S) OR HUB
            if turtle_id_string then
                -- Shutdown specific turtle(s)
                for _, turtle in pairs(turtles) do
                    turtle.tasks = {}
                    add_task(turtle, {action = 'pass'})
                    rednet.send(turtle.id, {
                        action = 'shutdown',
                    }, 'mastermine')
                end
            else
                -- Shutdown hub
                os.shutdown()
            end
        elseif command == 'reboot' then
            -- REBOOT TURTLE(S) OR HUB
            if turtle_id_string then
                -- Reboot specific turtle(s)
                for _, turtle in pairs(turtles) do
                    turtle.tasks = {}
                    add_task(turtle, {action = 'pass'})
                    rednet.send(turtle.id, {
                        action = 'reboot',
                    }, 'mastermine')
                end
            else
                -- Reboot all turtles, then hub
                print('Rebooting all turtles, then hub...')
                local rebooted_count = 0
                for _, turtle in pairs(state.turtles) do
                    if turtle.data then
                        -- Free turtle from assignments
                        free_turtle(turtle)
                        -- Clear tasks
                        turtle.tasks = {}
                        -- Send reboot command
                        rednet.send(turtle.id, {
                            action = 'reboot',
                        }, 'mastermine')
                        rebooted_count = rebooted_count + 1
                    end
                end
                print('Reboot command sent to ' .. rebooted_count .. ' turtle(s)')
                sleep(1)  -- Brief delay to let reboot commands send
                -- Reboot hub
                os.reboot()
            end
        elseif command == 'update' then
            -- UPDATE TURTLES AND/OR HUB
            -- Check for "force" argument
            local next_arg = next_word()
            local force_update = (next_arg == 'force')
            local update_hub_after = not turtle_id_string
            
            if turtle_id_string then
                -- Update specific turtle(s) - queue them one at a time
                local turtle_list = {}
                for _, turtle in pairs(turtles) do
                    table.insert(turtle_list, turtle)
                end
                queue_turtles_for_update(turtle_list, false, force_update)
            else
                -- Update hub and all turtles
                if force_update then
                    print('Force updating hub and all turtles (ignoring version checks)...')
                else
                    print('Updating hub and all turtles...')
                end
                -- Queue all turtles for update (even if they don't have version data)
                local turtle_list = {}
                for _, turtle in pairs(state.turtles) do
                    table.insert(turtle_list, turtle)
                end
                
                if #turtle_list == 0 then
                    print('No turtles found. Waiting 2 seconds for turtles to report...')
                    sleep(2)
                    -- Try again after waiting
                    turtle_list = {}
                    for _, turtle in pairs(state.turtles) do
                        table.insert(turtle_list, turtle)
                    end
                    if #turtle_list == 0 then
                        print('No turtles found. Updating hub only...')
                        -- Update hub only if no turtles found
                        queue_turtles_for_update({}, true, force_update)
                    else
                        print('Found ' .. #turtle_list .. ' turtle(s). Queuing for update...')
                        queue_turtles_for_update(turtle_list, true, force_update)
                    end
                else
                    print('Found ' .. #turtle_list .. ' turtle(s). Queuing for update...')
                    queue_turtles_for_update(turtle_list, true, force_update)
                end
            end
        elseif command == 'return' then
            -- BRING TURTLE HOME
            for _, turtle in pairs(turtles) do
                -- Check if turtle is initialized (has session_id and config)
                if not turtle.data or turtle.data.session_id ~= session_id then
                    print('Turtle ' .. turtle.id .. ' is not initialized yet. Cannot return home.')
                else
                    turtle.tasks = {}
                    -- Clear any halt state so turtle can move
                    if fs.exists(state.turtles_dir_path .. turtle.id .. '/halt') then
                        fs.delete(state.turtles_dir_path .. turtle.id .. '/halt')
                    end
                    -- Free turtle from block assignment
                    free_turtle(turtle)
                    -- Send turtle up from mine if underground, then go home
                    send_turtle_up(turtle)
                    add_task(turtle, {action = 'go_to_home', end_state = 'park'})
                end
            end
        elseif command == 'halt' then
            -- HALT TURTLE(S)
            for _, turtle in pairs(turtles) do
                turtle.tasks = {}
                add_task(turtle, {action = 'pass'})
                halt(turtle)
            end
        elseif command == 'reset' then
            -- HALT TURTLE(S)
            for _, turtle in pairs(turtles) do
                turtle.tasks = {}
                add_task(turtle, {action = 'pass'})
                add_task(turtle, {action = 'pass', end_state = 'lost'})
            end
        elseif command == 'on' or command == 'go' then
            -- ACTIVATE MINING NETWORK
            if not turtle_id_string then
                for _, turtle in pairs(state.turtles) do
                    turtle.tasks = {}
                    add_task(turtle, {action = 'pass'})
                end
                state.on = true
                fs.open(state.mine_dir_path .. 'on', 'w').close()
            end
        elseif command == 'off' or command == 'stop' then
            -- STANDBY MINING NETWORK
            if not turtle_id_string then
                for _, turtle in pairs(state.turtles) do
                    turtle.tasks = {}
                    add_task(turtle, {action = 'pass'})
                    free_turtle(turtle)
                end
                state.on = nil
                fs.delete(state.mine_dir_path .. 'on')
            end
        elseif command == 'check_init' or command == 'confirm_init' then
            -- CHECK INITIALIZATION STATUS AND REBOOT TURTLES WITH OLD SESSION_ID
            print('Checking turtle initialization status...')
            check_and_reboot_initialized_turtles()
        elseif command == 'debug' then
            -- DEBUG
        end
    end
end

-- Expose functions as globals (os.loadAPI wraps them into API table)
-- Assign to global environment explicitly
_G.user_input = user_input

