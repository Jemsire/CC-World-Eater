-- ============================================
-- Task Management Module
-- Handles task queueing and sending
-- ============================================
-- Uses globals: config, state (loaded via os.loadAPI)

function add_task(turtle, task)
    if not task.data then
        task.data = {}
    end
    table.insert(turtle.tasks, task)
end


function send_tasks(turtle)
    local task = turtle.tasks[1]
    if task then
        local turtle_data = turtle.data or {}
        -- Use _G.session_id to ensure we get the global value
        local current_session_id = _G.session_id or session_id
        
        -- Skip initialize tasks if turtle is already initialized
        if task.action == 'initialize' and turtle_data.session_id == current_session_id then
            print('[HUB DEBUG] Skipping initialize task for turtle ' .. turtle.id .. ' (already initialized, session_id: ' .. tostring(turtle_data.session_id) .. ')')
            table.remove(turtle.tasks, 1)
            -- Don't modify task_id here - it will be set when we send the next task
            return
        end
        
        -- Skip calibrate tasks if turtle already has a location
        if task.action == 'calibrate' and turtle_data.location and turtle_data.location.x and turtle_data.location.y and turtle_data.location.z then
            print('[HUB DEBUG] Skipping calibrate task for turtle ' .. turtle.id .. ' (already has location: ' .. 
                  turtle_data.location.x .. ',' .. turtle_data.location.y .. ',' .. turtle_data.location.z .. ')')
            table.remove(turtle.tasks, 1)
            -- Don't modify task_id here - it will be set when we send the next task
            return
        end
        
        -- Check if task was completed (success reported and request_id matches)
        -- Note: turtle increments request_id after completing a task, so we check if reported request_id is one higher than what we sent
        -- turtle.task_id is set to the request_id we sent, so we check if turtle_data.request_id == turtle.task_id + 1
        -- OR if turtle_data.request_id == turtle.task_id (in case the turtle hasn't incremented yet)
        -- IMPORTANT: Only match if the action matches what we sent (prevents matching wrong task)
        local request_id_matches = false
        if turtle.task_id then
            request_id_matches = (turtle_data.request_id == turtle.task_id or turtle_data.request_id == turtle.task_id + 1)
        end
        local action_matches = (turtle.task_action == task.action)
        if request_id_matches and action_matches and turtle.data.session_id == current_session_id then
            print('[HUB DEBUG] Task completion check: action=' .. task.action .. ', request_id=' .. tostring(turtle_data.request_id) .. ', task_id=' .. tostring(turtle.task_id) .. ', task_action=' .. tostring(turtle.task_action) .. ', success=' .. tostring(turtle_data.success))
            if turtle_data.success then
                if task.end_state then
                    if turtle.state == 'halt' and task.end_state ~= 'halt' then
                        unhalt(turtle)
                    end
                    -- Protect 'updating' state - don't allow tasks to overwrite it
                    -- The update flow manages state transitions for updating turtles
                    if turtle.state ~= 'updating' or task.end_state == 'updating' then
                        print('[HUB DEBUG] Task ' .. task.action .. ' completed, transitioning turtle ' .. turtle.id .. ' from ' .. turtle.state .. ' to ' .. task.end_state)
                        turtle.state = task.end_state
                    end
                end
                if task.end_function then
                    if task.end_function_args then
                        task.end_function(unpack(task.end_function_args))
                    else
                        task.end_function()
                    end
                end
                table.remove(turtle.tasks, 1)
                -- Clear task_id and task_action so we don't match old tasks
                turtle.task_id = nil
                turtle.task_action = nil
            end
        -- Send task if turtle is not busy and timeout has passed
        elseif (not turtle_data.busy) and ((not task.epoch) or (task.epoch > os.clock()) or (task.epoch + config.task_timeout < os.clock())) then
            -- ONLY SEND INSTRUCTION AFTER <config.task_timeout> SECONDS HAVE PASSED
            task.epoch = os.clock()
            -- Suppress spam for 'pass' tasks that are just state transitions
            if task.action ~= 'pass' or not task.end_state then
                if task.action ~= 'pass' then
                    print(string.format('Sending %s directive to %d', task.action, turtle.id))
                end
            end
            -- For initialize action, use -1 (always accept) if turtle not initialized, otherwise use turtle's request_id
            -- For other actions, use turtle's current request_id, or default to 1 if not set
            local send_request_id
            if task.action == 'initialize' and (not turtle_data.session_id or turtle_data.session_id ~= current_session_id) then
                -- Initialize action for uninitialized turtle - use -1 so it's always accepted
                send_request_id = -1
            else
                send_request_id = turtle_data.request_id or 1
            end
            -- Set task_id to match the request_id we're sending, so we can match it when the turtle reports back
            -- Also store the action name to verify we're matching the right task
            turtle.task_id = send_request_id
            turtle.task_action = task.action  -- Store which action we sent with this task_id
            print('[HUB DEBUG] Sending ' .. task.action .. ' to turtle ' .. turtle.id .. ' with request_id: ' .. tostring(send_request_id) .. ' (turtle has: ' .. tostring(turtle_data.request_id) .. ', session_id: ' .. tostring(turtle_data.session_id) .. ', task_id set to: ' .. tostring(turtle.task_id) .. ')')
            rednet.send(turtle.id, {
                action = task.action,
                data = task.data,
                request_id = send_request_id
            }, 'mastermine')
        end
    end
end


function halt(turtle)
    add_task(turtle, {action = 'pass', end_state = 'halt'})
    fs.open(state.turtles_dir_path .. turtle.id .. '/halt', 'w').close()
end


function unhalt(turtle)
    if fs.exists(state.turtles_dir_path .. turtle.id .. '/halt') then
        fs.delete(state.turtles_dir_path .. turtle.id .. '/halt')
    end
end


function initialize_turtle(turtle)
    -- Use _G.session_id to ensure we get the global value, not a local shadow
    local current_session_id = _G.session_id or session_id
    local current_config = _G.config or config
    
    -- Debug: Check if session_id and config are available
    if not current_session_id then
        print('[HUB ERROR] session_id is nil when initializing turtle ' .. turtle.id)
        print('[HUB ERROR] _G.session_id=' .. tostring(_G.session_id) .. ', session_id=' .. tostring(session_id))
    end
    if not current_config then
        print('[HUB ERROR] config is nil when initializing turtle ' .. turtle.id)
    end
    
    local data = {current_session_id, current_config}
    print('[HUB DEBUG] initialize_turtle data: session_id=' .. tostring(data[1]) .. ', config type=' .. tostring(type(data[2])))
    
    if turtle.state ~= 'halt' then
        -- If turtle just completed an update, keep it in updating state until version is verified
        if turtle.update_complete then
            turtle.state = 'updating'
        else
            turtle.state = 'lost'
        end
    end
    turtle.task_id = 2
    turtle.tasks = {}
    add_task(turtle, {action = 'initialize', data = data})
end


function reboot_all_turtles()
    -- Reboot all turtles (even if not initialized yet)
    -- Called when hub restarts to ensure all turtles re-initialize with new session_id
    local rebooted_count = 0
    
    -- Get current session_id (read from file if global not available)
    local current_session_id = session_id
    if not current_session_id and fs.exists('/session_id') then
        local session_file = fs.open('/session_id', 'r')
        if session_file then
            current_session_id = tonumber(session_file.readAll())
            session_file.close()
        end
    end
    
    for _, turtle in pairs(state.turtles) do
        -- Try to reboot turtle even if it hasn't reported yet (no turtle.data)
        local session_str = current_session_id and tostring(current_session_id) or 'unknown'
        print('Rebooting turtle ' .. turtle.id .. ' (hub restarted, new session_id: ' .. session_str .. ')')
        
        -- Free turtle from assignments if it has data
        if turtle.data then
            free_turtle(turtle)
        end
        
        -- Clear tasks
        if not turtle.tasks then
            turtle.tasks = {}
        else
            turtle.tasks = {}
        end
        
        -- Send reboot command (try even if turtle hasn't reported)
        rednet.send(turtle.id, {
            action = 'reboot',
        }, 'mastermine')
        rebooted_count = rebooted_count + 1
    end
    
    if rebooted_count == 0 then
        print('No turtles found in state. They will reboot and initialize when they report.')
    else
        print('Sent reboot command to ' .. rebooted_count .. ' turtle(s). They will re-initialize with new session_id after reboot.')
    end
end

-- Keep old function name for backwards compatibility (if called elsewhere)
function check_and_reboot_initialized_turtles()
    reboot_all_turtles()
end

-- Expose functions as globals (os.loadAPI wraps them into API table)
-- Assign to global environment explicitly
_G.add_task = add_task
_G.send_tasks = send_tasks
_G.halt = halt
_G.unhalt = unhalt
_G.initialize_turtle = initialize_turtle
_G.reboot_all_turtles = reboot_all_turtles
_G.check_and_reboot_initialized_turtles = check_and_reboot_initialized_turtles

