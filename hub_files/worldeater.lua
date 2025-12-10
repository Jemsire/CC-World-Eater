-- ==============================================
-- WORLDEATER - VERTICAL MINING SYSTEM
-- ==============================================
-- This system assigns each turtle an X,Z coordinate
-- and mines straight down from 2 blocks below the
-- starting area to bedrock.
-- ==============================================

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
                -- Parse x and z from filename (file_name is "x,z")
                local coords = string.gmatch(file_name, '[^,]+')
                local x = tonumber(coords())
                local z = tonumber(coords())
                
                -- Try to load as structured data (new format)
                local column_data = lua_utils.load_file(columns_dir_path .. file_name)
                
                if column_data then
                    -- New format: structured data
                    state.mine.columns[file_name] = {
                        x = x,
                        z = z,
                        current_y = column_data.current_y,
                        complete = column_data.complete or false,
                        disallow_found = column_data.disallow_found or false,
                        key = file_name,
                        turtle = nil  -- Will be assigned when turtle is mining this column
                    }
                else
                    -- Backward compatibility: old format (just a number)
                    local file = fs.open(columns_dir_path .. file_name, 'r')
                    if file then
                        local content = file.readAll()
                        file.close()
                        local current_y = tonumber(content)
                        
                        if current_y then
                            -- Migrate old format to new format
                            state.mine.columns[file_name] = {
                                x = x,
                                z = z,
                                current_y = current_y,
                                complete = false,
                                disallow_found = false,
                                key = file_name,
                                turtle = nil
                            }
                            -- Save in new format
                            write_column(state.mine.columns[file_name])
                        end
                    end
                end
            end
        end
    end

    -- Load or calculate total blocks mined (persisted across restarts)
    local total_blocks_file = state.mine_dir_path .. 'total_blocks_mined'
    if fs.exists(total_blocks_file) then
        local file = fs.open(total_blocks_file, 'r')
        if file then
            state.mine.total_blocks_mined = tonumber(file.readAll()) or 0
            file.close()
        end
    end
    
    -- If not loaded, calculate from columns (first run or migration)
    if not state.mine.total_blocks_mined then
        state.mine.total_blocks_mined = calculate_total_blocks_mined()
        save_total_blocks_mined()
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
            local version = lua_utils.load_file(turtle_dir_path .. 'version.lua')
            if version then
                -- Initialize data if not present
                if not turtle.data then
                    turtle.data = {}
                end
                turtle.data.version = version
            end
        end
    end
end


-- ==============================================
-- COLUMN ASSIGNMENT & PERSISTENCE
-- ==============================================

function write_column(column)
    -- SAVE COLUMN STATE TO DISK
    local columns_dir_path = state.mine_dir_path .. 'columns/'
    
    -- Prepare column data to save (only save relevant fields, not runtime data like turtle reference)
    local column_data = {
        complete = column.complete or false,
        disallow_found = column.disallow_found or false,
        current_y = column.current_y
    }
    
    -- Serialize and save as Lua table
    local serialized = lua_utils.serialize_table(column_data)
    local file = fs.open(columns_dir_path .. column.key, 'w')
    file.write("return " .. serialized)
    file.close()
end


function write_turtle_column(turtle, column)
    -- SAVE TURTLE'S ASSIGNED COLUMN TO DISK
    local file = fs.open(state.turtles_dir_path .. turtle.id .. '/column', 'w')
    file.write(column.key)
    file.close()
end


function save_total_blocks_mined()
    -- SAVE TOTAL BLOCKS MINED TO DISK (persists across restarts)
    if not state.mine then
        return
    end
    
    local total_blocks_file = state.mine_dir_path .. 'total_blocks_mined'
    local file = fs.open(total_blocks_file, 'w')
    if file then
        file.write(tostring(state.mine.total_blocks_mined or 0))
        file.close()
    end
end


function calculate_total_blocks_mined()
    -- CALCULATE TOTAL BLOCKS MINED FROM ALL COLUMNS
    local start_y = config.locations.mine_enter.y - 2
    local total = 0
    
    if state.mine and state.mine.columns then
        for _, column in pairs(state.mine.columns) do
            if column and column.current_y then
                total = total + math.max(0, start_y - column.current_y)
            end
        end
    end
    
    return total
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
        complete = false,
        disallow_found = false,
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
    local spacing = 1  -- Mine every block

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
        x = center_x
        z = center_z
    else
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

    -- First check for unassigned columns
    for _, column in pairs(state.mine.columns) do
        if not column.turtle and column.current_y > 0 then
            return column
        end
    end

    -- Check if we should apply mining radius limit
    if config.mining_radius then
        local center_x = config.locations.mine_enter.x
        local center_z = config.locations.mine_enter.z

        -- Generate new column position
        local x, z = get_next_column_position()

        -- Check if new column would be within radius
        local dx = x - center_x
        local dz = z - center_z
        local distance = math.sqrt(dx * dx + dz * dz)

        if distance <= config.mining_radius then
            return create_column(x, z)
        else
            return nil
        end
    else
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
    if turtle.pair then
        -- If paired, free both turtles
        if turtle.column then
            turtle.column.turtle = nil
        end
        turtle.column = nil
        turtle.pair.column = nil
        turtle.pair.pair = nil
        turtle.pair = nil
        fs.delete(state.turtles_dir_path .. turtle.id .. '/column')
    elseif turtle.column then
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
    -- Called after both turtles are at mine entrance

    local column = get_available_column()

    if not column then
        -- No columns available
        add_task(turtle, {action = 'pass', end_state = 'idle'})
        if turtle.pair then
            add_task(turtle.pair, {action = 'pass', end_state = 'idle'})
        end
        return
    end

    print('Assigning column (' .. column.x .. ',' .. column.z .. ') to turtle ' .. turtle.id)
    if turtle.pair then
        print('  (paired with turtle ' .. turtle.pair.id .. ')')
    end

    -- Assign column to turtle (and pair if exists)
    turtle.column = column
    column.turtle = turtle
    write_turtle_column(turtle, column)
    
    if turtle.pair then
        turtle.pair.column = column
        write_turtle_column(turtle.pair, column)
    end

    -- Change state to trip
    add_task(turtle, {action = 'pass', end_state = 'trip'})
    if turtle.pair then
        add_task(turtle.pair, {action = 'pass', end_state = 'trip'})
    end

    -- Send mining turtle to column starting position (2 blocks below surface)
    local mining_target = {
        x = column.x,
        y = config.locations.mine_enter.y - 2,
        z = column.z
    }

    add_task(turtle, {
        action = 'go_to',
        data = {mining_target},
        end_state = 'mining'
    })
    
    if turtle.pair then
        -- Send chunky turtle to position ABOVE the mining turtle (same X,Z, at surface level)
        local chunky_target = {
            x = column.x,
            y = config.locations.mine_enter.y,
            z = column.z
        }
        add_task(turtle.pair, {
            action = 'go_to',
            data = {chunky_target},
            end_state = 'mining'
        })
    end
end


function good_on_fuel(mining_turtle, chunky_turtle)
    -- CHECK IF BOTH TURTLES HAVE ENOUGH FUEL
    local fuel_needed = math.ceil((mining_turtle.data.location.y - config.locations.mine_enter.y) * 1.5 + 50)
    return (mining_turtle.data.fuel_level == "unlimited" or mining_turtle.data.fuel_level > fuel_needed) and 
           ((not config.use_chunky_turtles) or (chunky_turtle.data.fuel_level == "unlimited" or chunky_turtle.data.fuel_level > fuel_needed))
end


function continue_mining(turtle)
    -- CONTINUE MINING DOWN THE COLUMN

    if not turtle.column then
        add_task(turtle, {action = 'pass', end_state = 'idle'})
        return
    end

    -- Update progress
    update_column_progress(turtle)

    -- Check if we've reached bedrock
    -- TODO: Check if we've reached bedrock using block detection
    if turtle.column.current_y <= 0 then
        print('Turtle ' .. turtle.id .. ' completed column (' .. turtle.column.x .. ',' .. turtle.column.z .. ')')
        turtle.column.complete = true
        write_column(turtle.column)
        free_turtle(turtle)
        add_task(turtle, {action = 'pass', end_state = 'idle'})
        return
    end

    -- Check inventory space
    if turtle.pair then
        if turtle.data.empty_slot_count == 0 and turtle.pair.data.empty_slot_count == 0 then
            add_task(turtle, {action = 'go_to_mine_exit', end_state = 'idle'})
            add_task(turtle.pair, {action = 'go_to_mine_exit', end_state = 'idle'})
            return
        end
    elseif turtle.data.empty_slot_count == 0 then
        add_task(turtle, {action = 'go_to_mine_exit', end_state = 'idle'})
        return
    end

    -- Check fuel level
    if turtle.pair then
        if not good_on_fuel(turtle, turtle.pair) then
            add_task(turtle, {action = 'go_to_mine_exit', end_state = 'idle'})
            add_task(turtle.pair, {action = 'go_to_mine_exit', end_state = 'idle'})
            return
        end
    else
        local fuel_needed = math.ceil((turtle.data.location.y - config.locations.mine_enter.y) * 1.5 + 50)
        if turtle.data.fuel_level ~= "unlimited" and turtle.data.fuel_level < fuel_needed then
            add_task(turtle, {action = 'go_to_mine_exit', end_state = 'idle'})
            return
        end
    end

    -- Continue mining down
    add_task(turtle, {action = 'mine_down_step', end_state = 'mining'})
    
    -- If paired, tell chunky turtle to move down too
    if turtle.pair then
        add_task(turtle.pair, {action = 'down', end_state = 'mining'})
    end
end


-- ==============================================
-- TURTLE PAIRING (SEQUENTIAL - ONE PAIR AT A TIME)
-- ==============================================

function start_pair_sequence(mining_turtle, chunky_turtle)
    -- PAIR TURTLES AND SEND THEM TO MINE ONE AT A TIME
    
    print('=== Starting pair sequence ===')
    print('Mining turtle: ' .. mining_turtle.id)
    print('Chunky turtle: ' .. chunky_turtle.id)
    
    -- Create pair relationship immediately
    mining_turtle.pair = chunky_turtle
    chunky_turtle.pair = mining_turtle
    
    -- Lock this pair
    state.pair_hold = {mining_turtle, chunky_turtle}
    
    -- Set states to 'pairing'
    mining_turtle.state = 'pairing'
    chunky_turtle.state = 'pairing'
    
    -- Mining turtle: prepare FIRST (while still at parking spot near chests)
    -- then move up and go to mine
    add_task(mining_turtle, {
        action = 'prepare',
        data = {config.fuel_per_unit}
    })
    
    -- Then move UP to clear the parking row
    add_task(mining_turtle, {action = 'up'})
    add_task(mining_turtle, {action = 'up'})
    
    -- Then go to mine entrance
    add_task(mining_turtle, {
        action = 'go_to_mine_enter',
        end_function = send_chunky_turtle,
        end_function_args = {chunky_turtle}
    })
end


function send_chunky_turtle(chunky_turtle)
    print('Mining turtle arrived at mine entrance, sending chunky turtle ' .. chunky_turtle.id)
    
    -- Chunky turtle: prepare FIRST (while still at parking spot)
    add_task(chunky_turtle, {
        action = 'prepare',
        data = {config.fuel_per_unit}
    })
    
    -- Then move UP to clear the parking row
    add_task(chunky_turtle, {action = 'up'})
    add_task(chunky_turtle, {action = 'up'})
    
    -- Then go to mine entrance (1 block above miner)
    add_task(chunky_turtle, {
        action = 'go_to',
        data = {{
            x = config.locations.mine_enter.x,
            y = config.locations.mine_enter.y + 1,
            z = config.locations.mine_enter.z
        }},
        end_function = pair_ready_to_mine
    })
end


function pair_ready_to_mine()
    -- BOTH TURTLES ARE AT MINE ENTRANCE, ASSIGN COLUMN AND START MINING
    print('=== Pair ready to mine! ===')
    
    if state.pair_hold and #state.pair_hold == 2 then
        local mining_turtle = state.pair_hold[1].data.turtle_type == 'mining' 
            and state.pair_hold[1] or state.pair_hold[2]
        local chunky_turtle = mining_turtle.pair
        
        print('Assigning column to mining turtle ' .. mining_turtle.id .. ' and chunky turtle ' .. chunky_turtle.id)
        
        -- Clear the hold BEFORE assigning column (so next pair can start preparing)
        state.pair_hold = nil
        
        -- Assign column - this will send them to the column to start mining
        assign_column_to_turtle(mining_turtle)
    else
        print('ERROR: pair_hold invalid in pair_ready_to_mine')
        state.pair_hold = nil
    end
end


function has_enough_fuel_for_mining(turtle)
    -- CHECK IF TURTLE HAS ENOUGH FUEL FOR A MINING TRIP
    local fuel_needed = math.abs(config.locations.mine_enter.y + 64) + config.fuel_padding
    return turtle.data.fuel_level == "unlimited" or turtle.data.fuel_level >= fuel_needed
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
            task.epoch = os.clock()
            local data_str = globals.format_directive_data(task.action, task.data or {})
            print(string.format('Sending %s directive to %d%s', task.action, turtle.id, data_str))
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
        
        -- For 'update' command, we need special parsing to distinguish turtle vs hub updates
        -- For all other commands, parse normally
        local turtle_id_string, turtle_id, turtles
        if command ~= 'update' then
            turtle_id_string = next_word()
            turtle_id = nil
            turtles = {}
            
            if turtle_id_string and turtle_id_string ~= '*' then
                turtle_id = tonumber(turtle_id_string)
                if state.turtles[turtle_id] then
                    turtles = {state.turtles[turtle_id]}
                end
            else
                turtles = state.turtles
            end
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
                add_task(turtle, {action = action, data = data})
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
            -- UPDATE COMMAND - TURTLES ONLY
            -- Format: update [turtle_id|*] [force]
            local arg2 = next_word()
            local force_update = false
            local turtles = {}
            local turtle_id_string = nil
            local turtle_id = nil
            
            -- Parse turtle ID or * (default to all turtles if no arg)
            if arg2 then
                local arg2_num = tonumber(arg2)
                if arg2 == '*' then
                    turtle_id_string = '*'
                    turtles = state.turtles
                    local arg3 = next_word()
                    force_update = (arg3 == 'force')
                elseif arg2_num and state.turtles[arg2_num] then
                    turtle_id_string = arg2
                    turtle_id = arg2_num
                    turtles = {state.turtles[turtle_id]}
                    local arg3 = next_word()
                    force_update = (arg3 == 'force')
                elseif arg2 == 'force' then
                    turtle_id_string = '*'
                    turtles = state.turtles
                    force_update = true
                else
                    print('[Update] Invalid turtle ID: ' .. arg2)
                end
            else
                -- No args - default to all turtles
                turtle_id_string = '*'
                turtles = state.turtles
            end
            
            -- Get hub version for comparison
            local hub_version = lua_utils.load_file("/version.lua")
            
            for _, turtle in pairs(turtles) do
                local turtle_version = turtle.data and turtle.data.version
                local needs_update = true
                
                if not force_update and turtle_version and hub_version and github_api then
                    local comparison = github_api.compare_versions(turtle_version, hub_version)
                    if comparison == 0 then
                        print('[Update] Turtle ' .. turtle.id .. ' is already up to date.')
                        needs_update = false
                    end
                end
                
                if needs_update then
                    print('[Update] Sending update request to turtle ' .. turtle.id)
                    turtle.tasks = {}
                    add_task(turtle, {action = 'pass'})
                    rednet.send(turtle.id, {action = 'update', force = force_update}, 'mastermine')
                end
            end

        elseif command == 'return' then
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
            if not turtle_id_string then
                for _, turtle in pairs(state.turtles) do
                    turtle.tasks = {}
                    add_task(turtle, {action = 'pass'})
                end
                state.on = true
                fs.open(state.mine_dir_path .. 'on', 'w').close()
            end

        elseif command == 'off' or command == 'stop' then
            if not turtle_id_string then
                for _, turtle in pairs(state.turtles) do
                    turtle.tasks = {}
                    add_task(turtle, {action = 'pass'})
                    free_turtle(turtle)
                end
                state.on = nil
                state.pair_hold = nil  -- Clear any pending pairing
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
            print('=== DEBUG INFO ===')
            print('System on: ' .. tostring(state.on))
            print('Pair hold: ' .. tostring(state.pair_hold ~= nil))
            if state.pair_hold then
                print('  Turtle 1: ' .. state.pair_hold[1].id .. ' (' .. state.pair_hold[1].data.turtle_type .. ')')
                print('  Turtle 2: ' .. state.pair_hold[2].id .. ' (' .. state.pair_hold[2].data.turtle_type .. ')')
            end
            local column_count = 0
            for _ in pairs(state.mine.columns) do
                column_count = column_count + 1
            end
            print('Total columns: ' .. column_count)
            local turtle_count = 0
            for _ in pairs(state.turtles) do
                turtle_count = turtle_count + 1
            end
            print('Total turtles: ' .. turtle_count)
            for _, turtle in pairs(state.turtles) do
                local pair_info = turtle.pair and (' paired with ' .. turtle.pair.id) or ''
                print('Turtle ' .. turtle.id .. ': ' .. (turtle.state or 'nil') .. pair_info)
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
                    -- TURTLE IS PARKED
                    -- Don't do anything - pairing logic below will select pairs from parked turtles
                    -- This prevents all turtles from rushing to the waiting room at once

                elseif turtle.state == 'pairing' then
                    -- TURTLE IS IN PAIRING SEQUENCE
                    -- Just wait for tasks to complete - don't interfere

                elseif not state.on and turtle.state ~= 'idle' then
                    -- SYSTEM TURNED OFF, GO IDLE
                    add_task(turtle, {action = 'pass', end_state = 'idle'})

                elseif turtle.state == 'lost' then
                    -- TURTLE IS LOST, SEND HOME
                    if turtle.data.location.y < config.locations.mine_enter.y and (turtle.pair or not config.use_chunky_turtles) then
                        add_task(turtle, {action = 'pass', end_state = 'mining'})
                    else
                        add_task(turtle, {action = 'pass', end_state = 'idle'})
                    end

                elseif turtle.state == 'idle' then
                    -- TURTLE IS IDLE
                    free_turtle(turtle)

                    if turtle.data.location.y < config.locations.mine_enter.y then
                        -- Turtle is underground, send it up
                        add_task(turtle, {action = 'go_to_mine_exit'})

                    elseif not globals.in_area(turtle.data.location, config.locations.control_room_area) then
                        -- Turtle is outside control room, halt it
                        halt(turtle)

                    elseif turtle.data.item_count > 0 or (turtle.data.fuel_level ~= "unlimited" and turtle.data.fuel_level < config.fuel_per_unit) then
                        -- Turtle needs to drop items or refuel
                        add_task(turtle, {action = 'prepare', data = {config.fuel_per_unit}, end_state = 'idle'})

                    elseif state.on then
                        -- System is on
                        if config.use_chunky_turtles then
                            if turtle.pair then
                                -- Already paired, assign column to start mining
                                assign_column_to_turtle(turtle)
                            else
                                -- Not paired, go back to park and wait to be selected
                                add_task(turtle, {action = 'go_to_home', end_state = 'park'})
                            end
                        else
                            -- Not using chunky turtles, assign column directly
                            assign_column_to_turtle(turtle)
                        end

                    else
                        -- System is off, go park
                        add_task(turtle, {action = 'go_to_home', end_state = 'park'})
                    end

                elseif turtle.state == 'mining' then
                    -- TURTLE IS ACTIVELY MINING
                    if config.use_chunky_turtles and turtle.pair and turtle.data.turtle_type == 'mining' then
                        if turtle.pair.state == 'mining' then
                            continue_mining(turtle)
                        end
                    elseif config.use_chunky_turtles and turtle.pair and turtle.data.turtle_type == 'chunky' then
                        -- Chunky turtle: wait for mining turtle
                    elseif not config.use_chunky_turtles or not turtle.pair then
                        continue_mining(turtle)
                    end

                elseif turtle.state == 'trip' then
                    -- TURTLE IS TRAVELING TO COLUMN
                    -- Wait for it to arrive
                end
            end
        end
    end

    -- ==============================================
    -- PAIRING LOGIC - Select ONE pair at a time from PARKED turtles
    -- ==============================================
    if state.on and config.use_chunky_turtles and not state.pair_hold then
        local parked_mining = nil
        local parked_chunky = nil
        
        -- Find one parked mining turtle and one parked chunky turtle
        -- Only consider turtles that are parked and have enough fuel
        for _, turtle in pairs(state.turtles) do
            if turtle.state == 'park' and turtle.data and not turtle.pair then
                if turtle.data.turtle_type == 'mining' and not parked_mining then
                    if has_enough_fuel_for_mining(turtle) then
                        parked_mining = turtle
                    end
                elseif turtle.data.turtle_type == 'chunky' and not parked_chunky then
                    if has_enough_fuel_for_mining(turtle) then
                        parked_chunky = turtle
                    end
                end
            end
            
            -- Stop searching once we have one of each
            if parked_mining and parked_chunky then
                break
            end
        end
        
        -- If we found a valid pair, start the pairing sequence
        if parked_mining and parked_chunky then
            start_pair_sequence(parked_mining, parked_chunky)
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
    print('Mining pattern: Every block (spacing = 1)')
    if config.use_chunky_turtles then
        print('Chunky turtle pairing: ENABLED (sequential)')
    else
        print('Chunky turtle pairing: DISABLED')
    end
    print('==========================================')

    while true do
        user_input()         -- PROCESS USER INPUT
        command_turtles()    -- COMMAND TURTLES
        sleep(0.1)           -- DELAY 0.1 SECONDS
    end
end


main()