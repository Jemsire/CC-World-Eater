-- ============================================
-- Task Management Module
-- Handles task queueing and sending
-- ============================================

function add_task(turtle, task)
    if not task.data then
        task.data = {}
    end
    table.insert(turtle.tasks, task)
end


function send_tasks(turtle)
    local task = turtle.tasks[1]
    if task then
        local turtle_data = turtle.data
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
            end
            turtle.task_id = turtle.task_id + 1
        elseif (not turtle_data.busy) and ((not task.epoch) or (task.epoch > os.clock()) or (task.epoch + config.task_timeout < os.clock())) then
            -- ONLY SEND INSTRUCTION AFTER <config.task_timeout> SECONDS HAVE PASSED
            task.epoch = os.clock()
            -- Suppress spam for 'pass' tasks that are just state transitions
            if task.action ~= 'pass' or not task.end_state then
                print(string.format('Sending %s directive to %d', task.action, turtle.id))
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

