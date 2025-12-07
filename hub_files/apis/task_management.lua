-- ============================================
-- Task Management Module
-- Handles task queueing and sending
-- ============================================

-- Get API references
local config = API.getConfig()
local state = API.getState()

function add_task(turtle, task)
    if not task.data then
        task.data = {}
    end
    table.insert(turtle.tasks, task)
    -- Sync tasks array to data thread
    API.updateTurtle(turtle.id, 'tasks', turtle.tasks)
end


function send_tasks(turtle)
    local task = turtle.tasks[1]
    if task then
        local turtle_data = turtle.data or {}
        local is_initialize = (task.action == 'initialize')
        -- For initialize tasks, don't check request_id or session_id (turtle might not have reported yet)
        local request_id_matches = turtle_data.request_id and (turtle_data.request_id == turtle.task_id)
        local session_matches = turtle.data and turtle.data.session_id and (turtle.data.session_id == session_id)
        
        -- Check if task was completed (success reported and request_id matches)
        if request_id_matches and session_matches and turtle_data.success then
            if task.end_state then
                if turtle.state == 'halt' and task.end_state ~= 'halt' then
                    unhalt(turtle)
                end
                -- Protect 'updating' state - don't allow tasks to overwrite it
                -- The update flow manages state transitions for updating turtles
                if turtle.state ~= 'updating' or task.end_state == 'updating' then
                    API.updateTurtle(turtle.id, 'state', task.end_state)
                    turtle.state = task.end_state  -- Update local reference
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
            -- Update tasks array in data thread
            API.updateTurtle(turtle.id, 'tasks', turtle.tasks)
            if turtle.task_id then
                API.updateTurtle(turtle.id, 'task_id', turtle.task_id + 1)
                turtle.task_id = turtle.task_id + 1
            end
        -- Send task if turtle is not busy and timeout has passed
        -- For initialize, always send immediately (bypass request_id check and busy check)
        -- Initialize commands must be sent even if turtle appears busy (turtle might be busy from startup)
        elseif (is_initialize or not turtle_data.busy) and (is_initialize or (not task.epoch) or (task.epoch > os.clock()) or (task.epoch + config.task_timeout < os.clock())) then
            -- ONLY SEND INSTRUCTION AFTER <config.task_timeout> SECONDS HAVE PASSED (or immediately for initialize)
            task.epoch = os.clock()
            -- Suppress spam for 'pass' tasks that are just state transitions
            if task.action ~= 'pass' or not task.end_state then
                if is_initialize then
                    print('Sending initialize to turtle ' .. turtle.id)
                elseif task.action ~= 'pass' then
                    print('Sending ' .. task.action .. ' to turtle ' .. turtle.id)
                end
            end
            -- Use -1 for request_id to ensure commands are processed
            DataThread.send(turtle.id, {
                action = task.action,
                data = task.data,
                request_id = -1
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
    -- Get session_id (read from file if global not available)
    local current_session_id = session_id
    if not current_session_id and fs.exists('/session_id') then
        local session_file = fs.open('/session_id', 'r')
        if session_file then
            current_session_id = tonumber(session_file.readAll())
            session_file.close()
        end
    end
    
    if not current_session_id then
        print('ERROR: session_id is nil! Cannot initialize turtle ' .. turtle.id)
        return
    end
    
    local data = {current_session_id, config}
    
    -- Mark turtle as not ready until handshake is received
    API.updateTurtle(turtle.id, 'ready', false)
    API.updateTurtle(turtle.id, 'just_became_ready', false)
    turtle.ready = false
    turtle.just_became_ready = false
    
    if turtle.state ~= 'halt' then
        -- If turtle just completed an update, keep it in updating state until version is verified
        if turtle.update_complete then
            API.updateTurtle(turtle.id, 'state', 'updating')
            turtle.state = 'updating'
        else
            API.updateTurtle(turtle.id, 'state', 'lost')
            turtle.state = 'lost'
        end
    end
    API.updateTurtle(turtle.id, 'task_id', 2)
    turtle.task_id = 2
    turtle.tasks = {}
    API.updateTurtle(turtle.id, 'tasks', {})
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
        DataThread.send(turtle.id, {
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

