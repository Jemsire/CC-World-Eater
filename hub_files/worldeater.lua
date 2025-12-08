-- ==============================================
-- WORLDEATER - VERTICAL MINING SYSTEM
-- ==============================================
-- This system assigns each turtle an X,Z coordinate
-- and mines straight down from 2 blocks below the
-- starting area to bedrock.
-- ==============================================

inf = basics.inf
str_xyz = basics.str_xyz


-- ==============================================
-- MINE GRID MANAGEMENT
-- ==============================================

function load_mine()
    -- LOAD MINE INTO state.mine FROM /mine/<x,z>/ DIRECTORY
    -- Each coordinate stores its current mining depth
    state.mine_dir_path = '/mine/' .. config.locations.mine_enter.x .. ',' .. config.locations.mine_enter.z .. '/'
    state.mine = {}
    state.mine.columns = {}  -- Stores all vertical mining columns by "x,z" key

    if not fs.exists(state.mine_dir_path) then
        fs.makeDir(state.mine_dir_path)
    end

    if fs.exists(state.mine_dir_path .. 'on') then
        state.on = true
    end

    -- Load existing columns from /mine/<x,z>/columns/ directory
    local columns_dir_path = state.mine_dir_path .. 'columns/'
    if not fs.exists(columns_dir_path) then
        fs.makeDir(columns_dir_path)
    else
        -- Load each column file
        for _, file_name in pairs(fs.list(columns_dir_path)) do
            if file_name:sub(1, 1) ~= '.' then
                local file = fs.open(columns_dir_path .. file_name, 'r')
                if file then
                    -- file_name is "x,z"
                    -- file contains current depth (y coordinate)
                    local current_y = tonumber(file.readAll())
                    file.close()

                    -- Parse x and z from filename
                    local coords = string.gmatch(file_name, '[^,]+')
                    local x = tonumber(coords())
                    local z = tonumber(coords())

                    -- Create column entry
                    state.mine.columns[file_name] = {
                        x = x,
                        z = z,
                        current_y = current_y,
                        key = file_name,
                        turtle = nil  -- Will be assigned when turtle is mining this column
                    }
                end
            end
        end
    end

    -- Setup turtles directory
    state.turtles_dir_path = state.mine_dir_path .. 'turtles/'
    if not fs.exists(state.turtles_dir_path) then
        fs.makeDir(state.turtles_dir_path)
    end

    -- Load existing turtles and their assigned columns
    for _, turtle_id in pairs(fs.list(state.turtles_dir_path)) do
        if turtle_id:sub(1, 1) ~= '.' then
            turtle_id = tonumber(turtle_id)
            local turtle = {id = turtle_id}
            state.turtles[turtle_id] = turtle
            local turtle_dir_path = state.turtles_dir_path .. turtle_id .. '/'

            -- Load assigned column
            if fs.exists(turtle_dir_path .. 'column') then
                local file = fs.open(turtle_dir_path .. 'column', 'r')
                if file then
                    local column_key = file.readAll()
                    file.close()

                    -- Assign column to turtle
                    if state.mine.columns[column_key] then
                        turtle.column = state.mine.columns[column_key]
                        turtle.column.turtle = turtle
                    end
                end
            end

            -- Check if turtle is halted
            if fs.exists(turtle_dir_path .. 'halt') then
                turtle.state = 'halt'
            end
            
            -- Load persisted version if available
            if fs.exists(turtle_dir_path .. 'version.lua') then
                local version_func = loadfile(turtle_dir_path .. 'version.lua')
                if version_func then
                    local success, version = pcall(version_func)
                    if success and version and type(version) == "table" then
                        -- Initialize data if not present
                        if not turtle.data then
                            turtle.data = {}
                        end
                        turtle.data.version = version
                    end
                end
            end
        end
    end
end


-- ==============================================
-- COLUMN ASSIGNMENT & PERSISTENCE
-- ==============================================

function write_column(column)
    -- SAVE COLUMN STATE TO DISK
    -- Format: /mine/<x,z>/columns/<x,z>
    local columns_dir_path = state.mine_dir_path .. 'columns/'
    local file = fs.open(columns_dir_path .. column.key, 'w')
    file.write(column.current_y)
    file.close()
end


function write_turtle_column(turtle, column)
    -- SAVE TURTLE'S ASSIGNED COLUMN TO DISK
    local file = fs.open(state.turtles_dir_path .. turtle.id .. '/column', 'w')
    file.write(column.key)
    file.close()
end


function create_column(x, z)
    -- CREATE A NEW VERTICAL MINING COLUMN AT X,Z
    local key = x .. ',' .. z

    -- Start 2 blocks below mine entrance
    local start_y = config.locations.mine_enter.y - 2

    local column = {
        x = x,
        z = z,
        current_y = start_y,
        key = key,
        turtle = nil
    }

    state.mine.columns[key] = column
    write_column(column)

    return column
end


function get_next_column_position()
    -- CALCULATE NEXT X,Z POSITION FOR A NEW COLUMN
    -- Uses a spiral pattern radiating outward from mine entrance

    local center_x = config.locations.mine_enter.x
    local center_z = config.locations.mine_enter.z
    local spacing = config.grid_width or 3  -- Distance between columns

    -- Count existing columns to determine spiral position
    local count = 0
    for _ in pairs(state.mine.columns) do
        count = count + 1
    end

    -- Generate spiral coordinates
    local layer = 0
    local positions_in_layer = 0
    local total_positions = 0

    -- Find which layer we're on
    while total_positions <= count do
        layer = layer + 1
        if layer == 1 then
            positions_in_layer = 1
        else
            positions_in_layer = (layer * 2 - 1) * 4
        end
        total_positions = total_positions + positions_in_layer
    end

    -- Position within current layer
    local position_in_layer = count - (total_positions - positions_in_layer)

    local x, z

    if layer == 1 then
        -- First column is at center
        x = center_x
        z = center_z
    else
        -- Calculate position on spiral
        local side_length = layer * 2 - 1
        local side = math.floor(position_in_layer / side_length)
        local offset = position_in_layer % side_length

        if side == 0 then  -- Moving east
            x = center_x + (layer - 1) * spacing
            z = center_z - (layer - 1) * spacing + offset * spacing
        elseif side == 1 then  -- Moving north
            x = center_x + (layer - 1) * spacing - offset * spacing
            z = center_z + (layer - 1) * spacing
        elseif side == 2 then  -- Moving west
            x = center_x - (layer - 1) * spacing
            z = center_z + (layer - 1) * spacing - offset * spacing
        else  -- Moving south
            x = center_x - (layer - 1) * spacing + offset * spacing
            z = center_z - (layer - 1) * spacing
        end
    end

    return x, z
end


function get_available_column()
    -- FIND AN AVAILABLE COLUMN FOR MINING
    -- Returns column that either:
    -- 1. Has no turtle assigned, OR
    -- 2. Is not yet complete (hasn't reached bedrock)

    -- First check for unassigned columns
    for _, column in pairs(state.mine.columns) do
        if not column.turtle and column.current_y > 0 then
            return column
        end
    end

    -- Check if we should apply mining radius limit
    if config.mining_radius then
        -- Count columns within radius
        local center_x = config.locations.mine_enter.x
        local center_z = config.locations.mine_enter.z
        local columns_in_radius = 0

        for _, column in pairs(state.mine.columns) do
            local dx = column.x - center_x
            local dz = column.z - center_z
            local distance = math.sqrt(dx * dx + dz * dz)
            if distance <= config.mining_radius then
                columns_in_radius = columns_in_radius + 1
            end
        end

        -- Generate new column position
        local x, z = get_next_column_position()

        -- Check if new column would be within radius
        local dx = x - center_x
        local dz = z - center_z
        local distance = math.sqrt(dx * dx + dz * dz)

        if distance <= config.mining_radius then
            return create_column(x, z)
        else
            -- Exceeded mining radius, no more columns available
            return nil
        end
    else
        -- No radius limit, create new column
        local x, z = get_next_column_position()
        return create_column(x, z)
    end
end


-- ==============================================
-- TURTLE MANAGEMENT
-- ==============================================

function halt(turtle)
    add_task(turtle, {action = 'pass', end_state = 'halt'})
    fs.open(state.turtles_dir_path .. turtle.id .. '/halt', 'w').close()
end


function unhalt(turtle)
    fs.delete(state.turtles_dir_path .. turtle.id .. '/halt')
end


function free_turtle(turtle)
    -- RELEASE TURTLE FROM ITS COLUMN ASSIGNMENT
    if turtle.column then
        turtle.column.turtle = nil
        turtle.column = nil
        fs.delete(state.turtles_dir_path .. turtle.id .. '/column')
    end
end


function update_column_progress(turtle)
    -- UPDATE COLUMN DEPTH BASED ON TURTLE'S CURRENT POSITION
    if turtle.column and turtle.data and turtle.data.location then
        local current_y = turtle.data.location.y
        if current_y < turtle.column.current_y then
            turtle.column.current_y = current_y
            write_column(turtle.column)
        end
    end
end


function assign_column_to_turtle(turtle)
    -- ASSIGN A COLUMN TO A TURTLE AND SEND IT TO MINE

    local column = get_available_column()

    if not column then
        -- No columns available (might have hit mining radius limit)
        add_task(turtle, {action = 'pass', end_state = 'idle'})
        return
    end

    print('Assigning column (' .. column.x .. ',' .. column.z .. ') to turtle ' .. turtle.id)

    -- Assign column to turtle
    turtle.column = column
    column.turtle = turtle
    write_turtle_column(turtle, column)

    -- Change state to on mission
    add_task(turtle, {action = 'pass', end_state = 'trip'})

    -- Send turtle to column starting position
    local target = {
        x = column.x,
        y = config.locations.mine_enter.y - 2,  -- Start 2 below surface
        z = column.z
    }

    add_task(turtle, {
        action = 'go_to',
        data = {target},
        end_state = 'mining'
    })
end


function continue_mining(turtle)
    -- CONTINUE MINING DOWN THE COLUMN

    if not turtle.column then
        -- No column assigned, go idle
        add_task(turtle, {action = 'pass', end_state = 'idle'})
        return
    end

    -- Update progress
    update_column_progress(turtle)

    -- Check if we've reached bedrock (y <= 0) or hit disallowed block
    if turtle.column.current_y <= 0 then
        print('Turtle ' .. turtle.id .. ' completed column (' .. turtle.column.x .. ',' .. turtle.column.z .. ')')
        free_turtle(turtle)
        add_task(turtle, {action = 'pass', end_state = 'idle'})
        return
    end

    -- Check inventory space
    if turtle.data.empty_slot_count == 0 then
        -- Inventory full, return to surface
        add_task(turtle, {
            action = 'go_to_mine_exit',
            end_state = 'idle'
        })
        return
    end

    -- Check fuel level
    local fuel_needed = math.ceil((turtle.data.location.y - config.locations.mine_enter.y) * 1.5 + 50)
    if turtle.data.fuel_level ~= "unlimited" and turtle.data.fuel_level < fuel_needed then
        -- Low on fuel, return to surface
        add_task(turtle, {
            action = 'go_to_mine_exit',
            end_state = 'idle'
        })
        return
    end

    -- Continue mining down
    add_task(turtle, {
        action = 'mine_down_step',
        end_state = 'mining'
    })
end


-- ==============================================
-- TASK MANAGEMENT
-- ==============================================

function initialize_turtle(turtle)
    local data = {session_id, config}

    if turtle.state ~= 'halt' then
        turtle.state = 'lost'
    end
    turtle.task_id = 2
    turtle.tasks = {}
    add_task(turtle, {action = 'initialize', data = data})
end


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
                    turtle.state = task.end_state
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
            print(string.format('Sending %s directive to %d', task.action, turtle.id))
            rednet.send(turtle.id, {
                action = task.action,
                data = task.data,
                request_id = turtle_data.request_id
            }, 'mastermine')
        end
    end
end


-- ==============================================
-- USER INPUT COMMANDS
-- ==============================================

function user_input()
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
            for _, turtle in pairs(turtles) do
                turtle.tasks = {}
                add_task(turtle, {action = 'pass'})
                rednet.send(turtle.id, {action = 'shutdown'}, 'mastermine')
            end

        elseif command == 'reboot' then
            for _, turtle in pairs(turtles) do
                turtle.tasks = {}
                add_task(turtle, {action = 'pass'})
                rednet.send(turtle.id, {action = 'reboot'}, 'mastermine')
            end

        elseif command == 'update' then
            for _, turtle in pairs(turtles) do
                turtle.tasks = {}
                add_task(turtle, {action = 'pass'})
                rednet.send(turtle.id, {action = 'update'}, 'mastermine')
            end

        elseif command == 'return' then
            -- BRING TURTLE HOME
            for _, turtle in pairs(turtles) do
                turtle.tasks = {}
                add_task(turtle, {action = 'pass'})
                halt(turtle)
                add_task(turtle, {action = 'go_to_mine_exit'})
                add_task(turtle, {action = 'go_to_home'})
            end

        elseif command == 'halt' then
            for _, turtle in pairs(turtles) do
                turtle.tasks = {}
                add_task(turtle, {action = 'pass'})
                halt(turtle)
            end

        elseif command == 'reset' then
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

        elseif command == 'hubshutdown' then
            if not turtle_id_string then
                os.shutdown()
            end

        elseif command == 'hubreboot' then
            if not turtle_id_string then
                os.reboot()
            end

        elseif command == 'hubupdate' then
            if not turtle_id_string then
                os.run({}, '/update')
            end

        elseif command == 'debug' then
            -- DEBUG COMMAND
            print('=== DEBUG INFO ===')
            print('Total columns: ' .. table.getn(state.mine.columns))
            print('Active turtles: ' .. table.getn(state.turtles))
            for _, column in pairs(state.mine.columns) do
                local status = column.turtle and ('turtle ' .. column.turtle.id) or 'available'
                print('Column (' .. column.x .. ',' .. column.z .. ') depth: ' .. column.current_y .. ' - ' .. status)
            end
        end
    end
end


-- ==============================================
-- MAIN COMMAND LOOP
-- ==============================================

function command_turtles()
    for _, turtle in pairs(state.turtles) do

        if turtle.data then

            -- Check if turtle needs initialization
            if turtle.data.session_id ~= session_id then
                if (not turtle.tasks) or (not turtle.tasks[1]) or (not (turtle.tasks[1].action == 'initialize')) then
                    initialize_turtle(turtle)
                end
            end

            -- Send pending tasks
            if #turtle.tasks > 0 then
                send_tasks(turtle)

            elseif not turtle.data.location then
                -- TURTLE NEEDS CALIBRATION
                add_task(turtle, {action = 'calibrate'})

            elseif turtle.state ~= 'halt' then

                if turtle.state == 'park' then
                    -- TURTLE IS PARKED, ACTIVATE IF SYSTEM IS ON
                    if state.on then
                        add_task(turtle, {action = 'pass', end_state = 'idle'})
                    end

                elseif not state.on and turtle.state ~= 'idle' then
                    -- SYSTEM TURNED OFF, GO IDLE
                    add_task(turtle, {action = 'pass', end_state = 'idle'})

                elseif turtle.state == 'lost' then
                    -- TURTLE IS LOST, SEND HOME
                    add_task(turtle, {action = 'pass', end_state = 'idle'})

                elseif turtle.state == 'idle' then
                    -- TURTLE IS IDLE
                    free_turtle(turtle)

                    if turtle.data.location.y < config.locations.mine_enter.y then
                        -- Turtle is underground, send it up
                        add_task(turtle, {action = 'go_to_mine_exit'})

                    elseif not basics.in_area(turtle.data.location, config.locations.control_room_area) then
                        -- Turtle is outside control room, halt it
                        halt(turtle)

                    elseif turtle.data.item_count > 0 or (turtle.data.fuel_level ~= "unlimited" and turtle.data.fuel_level < config.fuel_per_unit) then
                        -- Turtle needs to drop items or refuel
                        add_task(turtle, {action = 'prepare', data = {config.fuel_per_unit}})

                    elseif state.on then
                        -- System is on, assign a column and start mining
                        assign_column_to_turtle(turtle)

                    else
                        -- System is off, go park
                        add_task(turtle, {action = 'go_to_home', end_state = 'park'})
                    end

                elseif turtle.state == 'mining' then
                    -- TURTLE IS ACTIVELY MINING
                    continue_mining(turtle)

                elseif turtle.state == 'trip' then
                    -- TURTLE IS TRAVELING TO COLUMN
                    -- Wait for it to arrive
                end
            end
        end
    end
end


-- ==============================================
-- MAIN ENTRY POINT
-- ==============================================

function main()
    -- INCREASE SESSION ID BY ONE
    if fs.exists('/session_id') then
        session_id = tonumber(fs.open('/session_id', 'r').readAll()) + 1
    else
        session_id = 1
    end
    local file = fs.open('/session_id', 'w')
    file.write(session_id)
    file.close()

    -- LOAD MINE INTO MEMORY
    load_mine()

    print('=== WORLDEATER VERTICAL MINING SYSTEM ===')
    print('Mining from: Y=' .. (config.locations.mine_enter.y - 2))
    if config.mining_radius then
        print('Mining radius: ' .. config.mining_radius .. ' blocks')
    else
        print('Mining radius: UNLIMITED')
    end
    print('Column spacing: ' .. (config.grid_width or 3) .. ' blocks')
    print('==========================================')

    while true do
        user_input()         -- PROCESS USER INPUT
        command_turtles()    -- COMMAND TURTLES
        sleep(0.1)           -- DELAY 0.1 SECONDS
    end
end


main()
