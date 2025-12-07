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
        -- Check if task was completed (success reported and request_id matches)
        if turtle_data.request_id == turtle.task_id and turtle.data.session_id == session_id then
            if turtle_data.success then
                if task.end_state then
                    if turtle.state == 'halt' and task.end_state ~= 'halt' then
                        unhalt(turtle)
                    end
                    -- Protect 'updating' state - don't allow tasks to overwrite it
                    -- The update flow manages state transitions for updating turtles
                    if turtle.state ~= 'updating' or task.end_state == 'updating' then
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
                turtle.task_id = turtle.task_id + 1
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
            rednet.send(turtle.id, {
                action = task.action,
                data = task.data,
                request_id = turtle_data.request_id
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
    local data = {session_id, config}
    
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

