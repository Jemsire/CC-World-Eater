inf = basics.inf
str_xyz = basics.str_xyz


reverse_shift = {
    north = 'south',
    south = 'north',
    east  = 'west',
    west  = 'east',
}


function load_mine()
    -- LOAD MINE INTO state.mine FROM /mine/<x,z>/ DIRECTORY
    -- Loads mined blocks
    state.mine_dir_path = '/mine/' .. config.locations.mine_enter.x .. ',' .. config.locations.mine_enter.z .. '/'
    
    if not fs.exists(state.mine_dir_path) then
        fs.makeDir(state.mine_dir_path)
    end
    
    if fs.exists(state.mine_dir_path .. 'on') then
        state.on = true
    end
    
    -- Load mined blocks
    state.mined_blocks = {}
    local mined_blocks_dir = state.mine_dir_path .. 'mined_blocks/'
    
    if not fs.exists(mined_blocks_dir) then
        fs.makeDir(mined_blocks_dir)
    else
        -- Load all mined block files
        for _, file_name in pairs(fs.list(mined_blocks_dir)) do
            if file_name:sub(1, 1) ~= '.' then
                -- File name format: "x,z"
                local coords = {}
                for coord in string.gmatch(file_name, '[^,]+') do
                    table.insert(coords, tonumber(coord))
                end
                if #coords == 2 then
                    local x, z = coords[1], coords[2]
                    if not state.mined_blocks[x] then
                        state.mined_blocks[x] = {}
                    end
                    state.mined_blocks[x][z] = true
                end
            end
        end
    end
    
    -- Set state.mine flag for monitor compatibility
    state.mine = true
    
    state.turtles_dir_path = state.mine_dir_path .. 'turtles/'
    
    if not fs.exists(state.turtles_dir_path) then
        fs.makeDir(state.turtles_dir_path)
    end
    
    -- Load turtle assignments
    for _, turtle_id in pairs(fs.list(state.turtles_dir_path)) do
        if turtle_id:sub(1, 1) ~= '.' then
            turtle_id = tonumber(turtle_id)
            local turtle = {id = turtle_id}
            state.turtles[turtle_id] = turtle
            local turtle_dir_path = state.turtles_dir_path .. turtle_id .. '/'
            
            -- Load block assignment
            if fs.exists(turtle_dir_path .. 'block') then
                local file = fs.open(turtle_dir_path .. 'block', 'r')
                if file then
                    local block_args = string.gmatch(file.readAll(), '[^,]+')
                    local x = tonumber(block_args())
                    local z = tonumber(block_args())
                    if x and z then
                        turtle.block = {x = x, z = z}
                        -- Check if deployed (mining in progress)
                        if fs.exists(turtle_dir_path .. 'deployed') then
                            local dep_file = fs.open(turtle_dir_path .. 'deployed', 'r')
                            if dep_file then
                                local depth_reached = tonumber(dep_file.readAll())
                                turtle.depth_reached = depth_reached  -- Y coordinate reached
                                dep_file.close()
                            end
                        end
                    end
                    file.close()
                end
            end
            
            if fs.exists(turtle_dir_path .. 'halt') then
                turtle.state = 'halt'
            end
        end
    end
end




-- ============================================
-- Block-based functions
-- ============================================

function is_block_mined(x, z)
    -- Check if a block at (x, z) has been completely mined to bedrock
    if not state.mined_blocks then
        return false
    end
    if not state.mined_blocks[x] then
        return false
    end
    return state.mined_blocks[x][z] == true
end


function mark_block_mined(x, z)
    -- Mark a block as completely mined to bedrock
    if not state.mined_blocks then
        state.mined_blocks = {}
    end
    if not state.mined_blocks[x] then
        state.mined_blocks[x] = {}
    end
    state.mined_blocks[x][z] = true
    
    -- Write to disk
    local mined_blocks_dir = state.mine_dir_path .. 'mined_blocks/'
    if not fs.exists(mined_blocks_dir) then
        fs.makeDir(mined_blocks_dir)
    end
    local file = fs.open(mined_blocks_dir .. x .. ',' .. z, 'w')
    file.close()  -- Empty file, existence indicates mined
end


function write_turtle_block(turtle, block)
    -- Record turtle's assigned block
    local file = fs.open(state.turtles_dir_path .. turtle.id .. '/block', 'w')
    file.write(block.x .. ',' .. block.z)
    file.close()
end


function update_block(turtle)
    -- Mark block as mined when turtle completes mining to bedrock
    local block = turtle.block
    if block then
        -- Check if turtle reached bedrock level
        if turtle.data.location and turtle.data.location.y <= config.bedrock_level then
            mark_block_mined(block.x, block.z)
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




-- ============================================
-- Block assignment functions
-- ============================================

function get_closest_unmined_block()
    -- Find the closest unmined block (x, z) starting from mining_center
    -- Spiral outward from mining_center to find closest unmined block
    local center = config.locations.mining_center
    local min_dist = inf
    local closest_block = nil
    
    -- Check mining radius if set (takes priority over mining_area)
    local radius = config.mining_radius
    
    -- Check mining area bounds (only used if radius is not set)
    local min_x, max_x, min_z, max_z
    if radius then
        -- Radius is set, ignore mining_area bounds
        -- Calculate bounds from radius
        min_x = center.x - radius
        max_x = center.x + radius
        min_z = center.z - radius
        max_z = center.z + radius
    else
        -- No radius, use mining_area bounds if set
        min_x = config.mining_area and config.mining_area.min_x or -inf
        max_x = config.mining_area and config.mining_area.max_x or inf
        min_z = config.mining_area and config.mining_area.min_z or -inf
        max_z = config.mining_area and config.mining_area.max_z or inf
    end
    
    -- Spiral outward from center
    local max_radius = radius or 1000  -- Default max search radius if no limit
    if radius then
        max_radius = radius
    end
    
    -- Start at center and spiral outward
    for r = 0, max_radius do
        -- Check all blocks at this radius
        for dx = -r, r do
            for dz = -r, r do
                -- Only check blocks at this radius (on the perimeter)
                if math.abs(dx) == r or math.abs(dz) == r then
                    local x = center.x + dx
                    local z = center.z + dz
                    
                    -- Check bounds (already calculated from radius if radius is set)
                    if x >= min_x and x <= max_x and z >= min_z and z <= max_z then
                        -- If radius is set, also verify circular distance
                        if not radius or (dx*dx + dz*dz <= radius*radius) then
                            -- Check if not mined
                            if not is_block_mined(x, z) then
                                -- Check if not assigned to another turtle
                                local assigned = false
                                for _, turtle in pairs(state.turtles) do
                                    if turtle.block and turtle.block.x == x and turtle.block.z == z then
                                        assigned = true
                                        break
                                    end
                                end
                                
                                if not assigned then
                                    -- Calculate distance from mine_enter
                                    local distance = basics.distance(
                                        {x = x, y = config.locations.mine_enter.y, z = z},
                                        config.locations.mine_enter
                                    )
                                    if distance < min_dist then
                                        min_dist = distance
                                        closest_block = {x = x, z = z}
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        -- If we found a block, return it (closest one found so far)
        if closest_block then
            return closest_block
        end
    end
    
    return closest_block
end


function gen_next_block()
    -- Generate next block assignment and calculate fuel requirements
    state.next_block = get_closest_unmined_block()
    if state.next_block then
        -- Calculate fuel needed: distance to block + depth to bedrock * 2 (down and back) + padding
        local surface_y = config.locations.mining_center.y + 2  -- Surface level
        local distance_to_block = basics.distance(
            {x = state.next_block.x, y = surface_y, z = state.next_block.z},
            config.locations.mine_enter
        )
        local depth = surface_y - config.bedrock_level  -- Depth from surface to bedrock
        state.min_fuel = (distance_to_block + depth * 2 + config.fuel_padding) * 3
    else
        state.min_fuel = nil
    end
end


function good_on_fuel(mining_turtle, chunky_turtle)
    -- Calculate fuel needed based on current location and mining depth
    local current_depth = mining_turtle.data.location.y
    local surface_y = config.locations.mining_center.y + 2
    local depth_to_surface = surface_y - current_depth
    local distance_to_exit = basics.distance(mining_turtle.data.location, config.locations.mine_exit)
    local fuel_needed = math.ceil((depth_to_surface + distance_to_exit) * 1.5)
    
    return (mining_turtle.data.fuel_level == "unlimited" or mining_turtle.data.fuel_level > fuel_needed) and ((not config.use_chunky_turtles) or (chunky_turtle.data.fuel_level == "unlimited" or chunky_turtle.data.fuel_level > fuel_needed))
end


function free_turtle(turtle)
    -- Free turtle from block assignment
    if turtle.block then
        -- Clear block assignment
        if fs.exists(state.turtles_dir_path .. turtle.id .. '/block') then
            fs.delete(state.turtles_dir_path .. turtle.id .. '/block')
        end
        if fs.exists(state.turtles_dir_path .. turtle.id .. '/deployed') then
            fs.delete(state.turtles_dir_path .. turtle.id .. '/deployed')
        end
        turtle.block = nil
        
        -- Handle pairing
        if turtle.pair then
            if fs.exists(state.turtles_dir_path .. turtle.pair.id .. '/block') then
                fs.delete(state.turtles_dir_path .. turtle.pair.id .. '/block')
            end
            if fs.exists(state.turtles_dir_path .. turtle.pair.id .. '/deployed') then
                fs.delete(state.turtles_dir_path .. turtle.pair.id .. '/deployed')
            end
            turtle.pair.pair = nil
            turtle.pair.block = nil
            turtle.pair = nil
        end
    end
end


function pair_turtles_finish()
    state.pair_hold = nil
end


-- ============================================
-- Block-based assignment functions
-- ============================================

function pair_turtles_begin(turtle1, turtle2)
    -- Assigns blocks to turtle pairs for mining
    local mining_turtle
    local chunky_turtle
    if turtle1.data.turtle_type == 'mining' then
        if turtle2.data.turtle_type ~= 'chunky' then
            error('Incompatable turtles')
        end
        mining_turtle = turtle1
        chunky_turtle = turtle2
    elseif turtle1.data.turtle_type == 'chunky' then
        if turtle2.data.turtle_type ~= 'mining' then
            error('Incompatable turtles')
        end
        chunky_turtle = turtle1
        mining_turtle = turtle2
    end
    
    local block = state.next_block
    
    if not block then
        gen_next_block()
        block = state.next_block
        if not block then
            add_task(mining_turtle, {action = 'pass', end_state = 'idle'})
            add_task(chunky_turtle, {action = 'pass', end_state = 'idle'})
            return
        end
    end
    
    print('Pairing ' .. mining_turtle.id .. ' and ' .. chunky_turtle.id .. ' to block (' .. block.x .. ',' .. block.z .. ')')
    
    mining_turtle.pair = chunky_turtle
    chunky_turtle.pair = mining_turtle
    
    state.pair_hold = {mining_turtle, chunky_turtle}
    
    -- Assign block to both turtles
    mining_turtle.block = block
    chunky_turtle.block = block
    
    -- Write block assignment
    write_turtle_block(mining_turtle, block)
    write_turtle_block(chunky_turtle, block)
    
    -- Mark as deployed (mining in progress)
    fs.open(state.turtles_dir_path .. chunky_turtle.id .. '/deployed', 'w').close()
    local file = fs.open(state.turtles_dir_path .. mining_turtle.id .. '/deployed', 'w')
    file.write(config.locations.mining_center.y + 2)  -- Start depth (surface)
    file.close()
    
    -- Set up tasks
    for _, turtle in pairs({mining_turtle, chunky_turtle}) do
        add_task(turtle, {action = 'pass', end_state = 'trip'})
    end
    
    add_task(mining_turtle, {
        action = 'go_to_mine_enter',
        end_function = pair_turtles_send,
        end_function_args = {chunky_turtle}
    })
    
    add_task(mining_turtle, {
        action = 'go_to_block',
        data = {mining_turtle.block},
        end_state = 'wait',
    })
    
    gen_next_block()
end


function pair_turtles_send(chunky_turtle)
    add_task(chunky_turtle, {
        action = 'go_to_mine_enter',
        end_function = pair_turtles_finish
    })
    
    -- Chunky turtle should be one block south of mining turtle
    add_task(chunky_turtle, {
        action = 'go_to_block_offset',
        data = {chunky_turtle.block, 1},  -- 1 block south (positive Z)
        end_state = 'wait',
    })
end


function solo_turtle_begin(turtle)
    -- Assigns blocks to solo turtles for mining
    local block = state.next_block
    
    if not block then
        gen_next_block()
        block = state.next_block
        if not block then
            add_task(turtle, {action = 'pass', end_state = 'idle'})
            return
        end
    end
    
    print('Assigning ' .. turtle.id .. ' to block (' .. block.x .. ',' .. block.z .. ')')
    
    -- Assign block to turtle
    turtle.block = block
    write_turtle_block(turtle, block)
    
    -- Mark as deployed (mining in progress)
    local file = fs.open(state.turtles_dir_path .. turtle.id .. '/deployed', 'w')
    file.write(config.locations.mining_center.y + 2)  -- Start depth (surface)
    file.close()
    
    add_task(turtle, {action = 'pass', end_state = 'trip'})
    
    add_task(turtle, {
        action = 'go_to_mine_enter',
    })
    
    add_task(turtle, {
        action = 'go_to_block',
        data = {turtle.block},
        end_state = 'wait',
    })
    
    gen_next_block()
end


function go_mine(mining_turtle)
    -- Mines assigned block down to bedrock
    update_block(mining_turtle)
    
    if config.use_chunky_turtles then
        -- Set chunky turtle to follow state so it follows during mining
        add_task(mining_turtle.pair, {action = 'pass', end_state = 'following'})
    end
    
    add_task(mining_turtle, {
        action = 'mine_to_bedrock',
        data = {mining_turtle.block},
    })
    add_task(mining_turtle, {
        action = 'clear_gravity_blocks',
    })
    if config.use_chunky_turtles then
        add_task(mining_turtle, {
            action = 'go_to_block',
            data = {mining_turtle.block},
            end_state = 'wait',
            end_function = follow,
            end_function_args = {mining_turtle.pair},
        })
    else
        add_task(mining_turtle, {
            action = 'go_to_block',
            data = {mining_turtle.block},
            end_state = 'wait',
        })
    end
    
    -- Mark block as mined when complete
    mark_block_mined(mining_turtle.block.x, mining_turtle.block.z)
end


function follow(chunky_turtle)
    -- After mining completes, chunky turtle returns to surface and positions at block
    -- (one block south for next mining operation)
    -- First transition out of following state and return to surface
    add_task(chunky_turtle, {action = 'pass', end_state = 'trip'})
    
    -- Return to surface if deep underground
    local surface_y = config.locations.mining_center.y + 2
    if chunky_turtle.data and chunky_turtle.data.location and chunky_turtle.data.location.y < surface_y then
        -- Need to return to surface first
        add_task(chunky_turtle, {
            action = 'mine_column_up',
            data = {surface_y},
        })
    end
    
    -- Then position one block south of mining turtle at surface
    add_task(chunky_turtle, {
        action = 'go_to_block_offset',
        data = {chunky_turtle.block, 1},  -- 1 block south (positive Z)
        end_state = 'wait',
    })
end


function check_pair_fuel(turtle)
    if state.min_fuel then
        if (turtle.data.fuel_level ~= "unlimited" and turtle.data.fuel_level <= state.min_fuel) then
            add_task(turtle, {action = 'prepare', data = {state.min_fuel}})
        else
            add_task(turtle, {action = 'pass', end_state = 'pair'})
        end
    else
        gen_next_block()
    end
end


function send_turtle_up(turtle)
    if turtle.data.location.y < config.locations.mine_enter.y then
        if turtle.block then
            -- Turtle is mining a block, return to surface
            add_task(turtle, {action = 'go_to_mine_exit', data = {turtle.block}})
        end
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


function get_hub_version()
    -- Load version from version.lua file
    local version_paths = {
        "/version.lua",
        "/disk/hub_files/version.lua"
    }
    
    for _, path in ipairs(version_paths) do
        if fs.exists(path) then
            local version_file = fs.open(path, "r")
            if version_file then
                local version_code = version_file.readAll()
                version_file.close()
                local version_func = load(version_code)
                if version_func then
                    local success, version = pcall(version_func)
                    if success and version and type(version) == "table" then
                        return version
                    end
                end
            end
        end
    end
    return nil
end


function is_dev_version(version)
    -- Check if version has DEV suffix/flag
    if not version or type(version) ~= "table" then
        return false
    end
    -- Check for dev field (boolean) or dev_suffix field (string)
    return version.dev == true or (version.dev_suffix and version.dev_suffix == "-DEV")
end


function compare_versions(v1, v2)
    -- Compare two semantic versions
    -- Returns: -1 if v1 < v2, 0 if v1 == v2, 1 if v1 > v2
    if not v1 or not v2 or type(v1) ~= "table" or type(v2) ~= "table" then
        return nil
    end
    
    -- Compare major
    if v1.major > v2.major then return 1 end
    if v1.major < v2.major then return -1 end
    
    -- Compare minor
    if v1.minor > v2.minor then return 1 end
    if v1.minor < v2.minor then return -1 end
    
    -- Compare hotfix
    if v1.hotfix > v2.hotfix then return 1 end
    if v1.hotfix < v2.hotfix then return -1 end
    
    return 0  -- Equal
end


function check_turtle_versions()
    -- Check if any turtles are out of date and set them to updating state
    local hub_version = get_hub_version()
    if not hub_version then
        -- Can't check versions if hub version not available
        return
    end
    
    for _, turtle in pairs(state.turtles) do
        -- Skip turtles that are already updating, halted, or awaiting version verification
        if not turtle.data or turtle.state == 'updating' or turtle.state == 'halt' or turtle.update_complete then
            -- Skip this turtle
        else
            -- Check if turtle already has a task queued that will set it to updating state
            local has_update_task = false
            if turtle.tasks and #turtle.tasks > 0 then
                for _, task in ipairs(turtle.tasks) do
                    if task.end_state == 'updating' then
                        has_update_task = true
                        break
                    end
                end
            end
            
            -- Skip if already has an update task queued (set state to prevent future checks)
            if has_update_task then
                turtle.state = 'updating'
            else
                local needs_update = false
                
                -- Check if turtle has force_update flag set (from dev force update or manual command)
                if turtle.force_update then
                    needs_update = true
                -- If turtle has no version data, consider it out of date
                elseif not turtle.data.version then
                    needs_update = true
                elseif turtle.data.version then
                    local turtle_version = turtle.data.version
                    local comparison = compare_versions(turtle_version, hub_version)
                    
                    -- If turtle version is older than hub version, needs update
                    if comparison and comparison < 0 then
                        needs_update = true
                    end
                end
                        
                if needs_update then
                    if turtle.force_update then
                        print('Turtle ' .. turtle.id .. ' force update requested. Setting to updating state...')
                        turtle.force_update = nil  -- Clear flag after using it
                    else
                        print('Turtle ' .. turtle.id .. ' is out of date. Setting to updating state...')
                    end
                    -- Free turtle from any block assignment
                    free_turtle(turtle)
                    -- Clear tasks and set to updating state IMMEDIATELY to prevent duplicate checks
                    -- No need for 'pass' task - the update flow in command_turtles() will handle navigation
                    turtle.tasks = {}
                    turtle.state = 'updating'
                end
            end
        end
    end
end


function add_task(turtle, task)
    if not task.data then
        task.data = {}
    end
    table.insert(turtle.tasks, task)
end


function queue_turtles_for_update(turtle_list, update_hub_after, force_update)
    -- Set turtles to updating state for state-based update system
    -- force_update: If true, updates turtles even if versions match
    if #turtle_list == 0 then
        if update_hub_after then
            -- Check if all turtles are updated before updating hub
            local all_updated = true
            for _, turtle in pairs(state.turtles) do
                if turtle.data and turtle.state == 'updating' then
                    all_updated = false
                    break
                end
            end
            
            if all_updated then
            print('All turtles updated. Updating hub...')
            sleep(1)
            if force_update then
                os.run({}, '/update', 'force')
            else
                os.run({}, '/update')
                end
            end
        end
        return
    end
    
    -- Set turtles to updating state
    for _, turtle in pairs(turtle_list) do
        if turtle.data then
            -- Free turtle from any block assignment
            free_turtle(turtle)
            -- Clear tasks and set to updating state IMMEDIATELY to prevent duplicate checks
            -- No need for 'pass' task - the update flow in command_turtles() will handle navigation
            turtle.tasks = {}
            turtle.state = 'updating'
            turtle.force_update = force_update or false
            print('Set turtle ' .. turtle.id .. ' to updating state')
        end
    end
    
    state.update_hub_after = update_hub_after
    state.force_update = force_update or false
end


function count_turtles_at_disk()
    -- Count how many turtles are currently at the disk drive
    local count = 0
            for _, turtle in pairs(state.turtles) do
        if turtle.data and turtle.data.location and turtle.state == 'updating' then
            if basics.in_location(turtle.data.location, config.locations.disk_drive) then
                count = count + 1
                end
            end
    end
    return count
end


function on_update_complete(turtle_id)
    -- Called when a turtle completes its update
    local turtle = state.turtles[turtle_id]
    if turtle then
        print('Turtle ' .. turtle_id .. ' update complete! Will verify version after initialization...')
        -- Mark that this turtle just completed an update and needs version verification
        -- The turtle will reboot and initialize, then we'll check its version
        turtle.update_complete = true
        turtle.update_sent_home = nil
        turtle.update_sent_to_disk = nil
        turtle.update_waiting_at_disk = nil
        -- Keep turtle in updating state - it will be verified after initialization
    end
end


function verify_turtle_version_after_update(turtle)
    -- Verify turtle version after it has updated and initialized
    -- Called when turtle reports version data after completing an update
    local hub_version = get_hub_version()
    if not hub_version then
        -- Can't verify without hub version
        return false
    end
    
    if not turtle.data or not turtle.data.version then
        -- Turtle hasn't reported version yet
        return false
    end
    
    local turtle_version = turtle.data.version
    local comparison = compare_versions(turtle_version, hub_version)
    
    if comparison and comparison >= 0 then
        -- Version is correct, update successful
        local turtle_version_str = turtle_version.major .. '.' .. turtle_version.minor .. '.' .. turtle_version.hotfix
        local hub_version_str = hub_version.major .. '.' .. hub_version.minor .. '.' .. hub_version.hotfix
        if is_dev_version(hub_version) then
            hub_version_str = hub_version_str .. '-DEV'
        end
        print('Turtle ' .. turtle.id .. ' version verified: ' .. turtle_version_str .. ' (hub: ' .. hub_version_str .. ')')
        turtle.update_complete = nil
        turtle.update_sent_home = nil
        turtle.update_sent_to_disk = nil
        turtle.update_waiting_at_disk = nil
        
        -- Transition out of updating state (turtle might be in 'lost' state after initialization)
        if turtle.state == 'updating' or turtle.state == 'lost' then
            if state.on then
                add_task(turtle, {
                    action = 'go_to_waiting_room',
                    end_state = 'idle',
                })
            else
                add_task(turtle, {
                    action = 'go_to_home',
                    end_state = 'park',
                })
            end
        end
        return true
    else
        -- Version is still wrong, needs another update
        local turtle_version_str = turtle_version and (turtle_version.major .. '.' .. turtle_version.minor .. '.' .. turtle_version.hotfix) or 'unknown'
        local hub_version_str = hub_version.major .. '.' .. hub_version.minor .. '.' .. hub_version.hotfix
        if is_dev_version(hub_version) then
            hub_version_str = hub_version_str .. '-DEV'
        end
        print('Turtle ' .. turtle.id .. ' version still incorrect after update: ' .. turtle_version_str .. ' (hub: ' .. hub_version_str .. ')')
        print('Turtle ' .. turtle.id .. ' will update again...')
        -- Reset update flags so it can update again
        turtle.update_complete = nil
        turtle.update_sent_home = nil
        turtle.update_sent_to_disk = nil
        turtle.update_waiting_at_disk = nil
        -- Keep in updating state to update again
        return false
    end
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
                turtle.tasks = {}
                add_task(turtle, {action = 'pass'})
                halt(turtle)
                send_turtle_up(turtle)
                add_task(turtle, {action = 'go_to_home'})
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
        elseif command == 'debug' then
            -- DEBUG
        end
    end
end


function command_turtles()
    -- Check for out-of-date turtles and set them to updating state
    check_turtle_versions()
    
    -- Check if all updating turtles are done and update hub if needed
    if state.update_hub_after then
        local any_updating = false
        for _, turtle in pairs(state.turtles) do
            if turtle.data and turtle.state == 'updating' then
                any_updating = true
                break
            end
        end
        
        if not any_updating then
            print('All turtles updated. Updating hub...')
            sleep(1)
            if state.force_update then
                os.run({}, '/update', 'force')
            else
                os.run({}, '/update')
            end
            state.update_hub_after = false
            state.force_update = false
        end
    end
    
    local turtles_for_pair = {}
    
    for _, turtle in pairs(state.turtles) do
        
        if turtle.data then
        
            if turtle.data.session_id ~= session_id then
                -- BABY TURTLE NEEDS TO LEARN
                if (not turtle.tasks) or (not turtle.tasks[1]) or (not (turtle.tasks[1].action == 'initialize')) then
                    -- Check if this turtle just completed an update and needs version verification
                    if turtle.update_complete then
                        -- Turtle just updated and is initializing - verify version after initialization completes
                        initialize_turtle(turtle)
                    else
                        initialize_turtle(turtle)
                    end
                end
            end
            
            -- Check if turtle that completed update now has version data to verify
            if turtle.update_complete and turtle.data and turtle.data.version then
                verify_turtle_version_after_update(turtle)
            end

            if #turtle.tasks > 0 then
                -- TURTLE IS BUSY
                send_tasks(turtle)

            elseif not turtle.data.location then
                -- TURTLE NEEDS A MAP
                add_task(turtle, {action = 'calibrate'})

            elseif turtle.state ~= 'halt' then

                if turtle.state == 'park' then
                    -- TURTLE FOUND PARKING
                    if state.on and (config.use_chunky_turtles or turtle.data.turtle_type == 'mining') then
                        add_task(turtle, {action = 'pass', end_state = 'idle'})
                    end

                elseif not state.on and turtle.state ~= 'idle' then
                    -- TURTLE HAS TO STOP
                    add_task(turtle, {action = 'pass', end_state = 'idle'})

                elseif turtle.state == 'lost' then
                    -- TURTLE IS CONFUSED
                    if turtle.data.location.y < config.locations.mine_enter.y and (turtle.pair or not config.use_chunky_turtles) then
                        add_task(turtle, {action = 'pass', end_state = 'trip'})
                        if turtle.block then
                            add_task(turtle, {
                                action = 'go_to_block',
                                data = {turtle.block},
                                end_state = 'wait'
                            })
                        else
                            add_task(turtle, {action = 'pass', end_state = 'idle'})
                        end
                    else
                        add_task(turtle, {action = 'pass', end_state = 'idle'})
                    end

                elseif turtle.state == 'idle' then
                    -- TURTLE IS BORED
                    free_turtle(turtle)
                    if turtle.data.location.y < config.locations.mine_enter.y then
                        send_turtle_up(turtle)
                    elseif not basics.in_area(turtle.data.location, config.locations.control_room_area) then
                        halt(turtle)
                    elseif turtle.data.item_count > 0 or (turtle.data.fuel_level ~= "unlimited" and turtle.data.fuel_level < config.fuel_per_unit) then
                        add_task(turtle, {action = 'prepare', data = {config.fuel_per_unit}})
                    elseif state.on then
                        add_task(turtle, {
                            action = 'go_to_waiting_room',
                            end_function = check_pair_fuel,
                            end_function_args = {turtle},
                        })
                    else
                        add_task(turtle, {action = 'go_to_home', end_state = 'park'})
                    end

                elseif turtle.state == 'pair' then
                    -- TURTLE NEEDS A FRIEND
                    if config.use_chunky_turtles then
                        if not state.pair_hold then
                            if not turtle.pair then
                                table.insert(turtles_for_pair, turtle)
                            end
                        else
                            if not (state.pair_hold[1].pair and state.pair_hold[2].pair) then
                                state.pair_hold = nil
                            end
                        end
                    else
                        solo_turtle_begin(turtle)
                    end

                elseif turtle.state == 'trip' then
                    -- TURTLE IS TRAVELING TO BLOCK
                    -- If turtle has no tasks but has a block assignment, ensure it continues navigation
                    if turtle.block and (#turtle.tasks == 0) then
                        -- Check if this is a chunky turtle that should wait for pair_turtles_send callback
                        -- But if mining turtle is already at wait state, the callback may have been missed
                        if turtle.pair and turtle.data.turtle_type == 'chunky' and turtle.pair.state == 'wait' then
                            -- Mining turtle is already at block, add tasks for chunky turtle to catch up
                            add_task(turtle, {
                                action = 'go_to_mine_enter',
                                end_function = pair_turtles_finish
                            })
                            -- Chunky turtle should be one block south of mining turtle
                            add_task(turtle, {
                                action = 'go_to_block_offset',
                                data = {turtle.block, 1},  -- 1 block south (positive Z)
                                end_state = 'wait',
                            })
                        elseif not turtle.pair or turtle.data.turtle_type == 'mining' then
                            -- Mining turtle or solo turtle - continue to block
                            if not basics.in_area(turtle.data.location, config.locations.waiting_room_area) then
                                add_task(turtle, {action = 'go_to_mine_enter'})
                            end
                            add_task(turtle, {
                                action = 'go_to_block',
                                data = {turtle.block},
                                end_state = 'wait',
                            })
                        end
                        -- If chunky turtle and mining turtle not at wait yet, wait for pair_turtles_send callback
                    elseif not turtle.block then
                        -- No block assignment, go idle
                        add_task(turtle, {action = 'pass', end_state = 'idle'})
                    end

                elseif turtle.state == 'wait' then
                    -- TURTLE GO DO SOME WORK
                    if turtle.block then
                        if turtle.pair then
                            if turtle.data.turtle_type == 'mining' and turtle.pair.state == 'wait' then
                                -- Check if inventory full or fuel low
                                if (turtle.data.empty_slot_count == 0 and turtle.pair.data.empty_slot_count == 0) or not good_on_fuel(turtle, turtle.pair) then
                                    add_task(turtle, {action = 'pass', end_state = 'idle'})
                                    add_task(turtle.pair, {action = 'pass', end_state = 'idle'})
                                elseif turtle.data.empty_slot_count == 0 then
                                    -- Dump items
                                    add_task(turtle, {action = 'dump', data = {'north'}})
                                else
                                    add_task(turtle, {action = 'pass', end_state = 'mine'})
                                    add_task(turtle.pair, {action = 'pass', end_state = 'mine'})
                                    go_mine(turtle)
                                end
                            end
                        elseif not config.use_chunky_turtles then
                            -- Solo turtle mining block
                            if turtle.data.empty_slot_count == 0 or not good_on_fuel(turtle) then
                                add_task(turtle, {action = 'pass', end_state = 'idle'})
                            else
                                add_task(turtle, {action = 'pass', end_state = 'mine'})
                                go_mine(turtle)
                            end
                        else
                            add_task(turtle, {action = 'pass', end_state = 'idle'})
                        end
                    else
                        -- No assignment, go idle
                        add_task(turtle, {action = 'pass', end_state = 'idle'})
                    end
                elseif turtle.state == 'mine' then
                    if config.use_chunky_turtles and not turtle.pair then
                        add_task(turtle, {action = 'pass', end_state = 'idle'})
                    end
                    
                elseif turtle.state == 'updating' then
                    -- TURTLE IS UPDATING
                    -- First, ensure turtle is not halted (clear halt if it exists)
                    if fs.exists(state.turtles_dir_path .. turtle.id .. '/halt') then
                        unhalt(turtle)
                    end
                    
                    -- Check if turtle needs to return home first
                    local is_home = false
                    local is_at_disk = false
                    local is_near_home = false
                    
                    if turtle.data and turtle.data.location then
                        is_home = (config.locations.home_area and basics.in_area(turtle.data.location, config.locations.home_area)) or
                                  basics.in_area(turtle.data.location, config.locations.greater_home_area)
                        is_at_disk = basics.in_location(turtle.data.location, config.locations.disk_drive)
                        is_near_home = is_home or basics.in_area(turtle.data.location, config.locations.greater_home_area)
                    end
                    
                    if is_at_disk then
                        -- Turtle is at disk drive
                        -- Mark that turtle has reached disk
                        turtle.update_sent_to_disk = true
                        
                        -- Check if other turtles are updating (wait if so)
                        local turtles_at_disk = count_turtles_at_disk()
                        if turtles_at_disk > 1 then
                            -- Another turtle is updating, wait
                            if not turtle.update_waiting_at_disk then
                                print('Turtle ' .. turtle.id .. ' waiting at disk drive (other turtle updating)...')
                                turtle.update_waiting_at_disk = true
                            end
                            -- Just wait, don't send update command yet
                        else
                            -- No other turtles updating, proceed with update
                            if not turtle.update_waiting_at_disk or turtle.update_waiting_at_disk then
                                -- Clear waiting flag and send update command
                                turtle.update_waiting_at_disk = nil
                                print('Turtle ' .. turtle.id .. ' at disk drive. Starting update...')
                                -- Clear any existing tasks before sending update command
                                turtle.tasks = {}
                                rednet.send(turtle.id, {
                                    action = 'update',
                                }, 'mastermine')
                            end
                        end
                    elseif is_near_home then
                        -- Turtle is near home, navigate to disk drive
                        if not turtle.update_sent_to_disk and not turtle.update_waiting_at_disk then
                            add_task(turtle, {
                                action = 'go_to_disk',
                                end_state = 'updating',  -- Stay in updating state
                            })
                            -- Don't set update_sent_to_disk yet - wait until turtle reaches disk
                        end
                    elseif turtle.data and turtle.data.location then
                        -- Turtle needs to return home first (only if we have location data)
                        if not turtle.update_sent_home then
                            send_turtle_up(turtle)
                            add_task(turtle, {
                                action = 'go_to_home',
                                end_state = 'updating',  -- Stay in updating state
                            })
                            turtle.update_sent_home = true
                        end
                    else
                        -- Turtle doesn't have location data - need to calibrate first
                        if not turtle.update_sent_home then
                            add_task(turtle, {
                                action = 'calibrate',
                                end_state = 'updating',  -- Stay in updating state after calibration
                            })
                            turtle.update_sent_home = true  -- Mark that we've started the update process
                        end
                    end
                    
                    -- Version verification happens after update completes and turtle initializes
                    -- See verify_turtle_version_after_update() which is called when turtle reports version
                    
                elseif turtle.state == 'following' then
                    -- CHUNKY TURTLE FOLLOWING MINING TURTLE
                    -- Keep chunky turtle 2 blocks above mining turtle during mining
                    if turtle.pair and turtle.pair.data and turtle.pair.data.location then
                        local mining_location = turtle.pair.data.location
                        local target_location = {
                            x = mining_location.x,
                            y = mining_location.y + 2,  -- 2 blocks above
                            z = mining_location.z
                        }
                        
                        -- Check if chunky turtle needs to move
                        if turtle.data and turtle.data.location then
                            local current = turtle.data.location
                            -- If not at target position, move there
                            if current.x ~= target_location.x or 
                               current.y ~= target_location.y or 
                               current.z ~= target_location.z then
                                add_task(turtle, {
                                    action = 'follow_mining_turtle',
                                    data = {target_location},
                                    end_state = 'following',  -- Stay in following state
                                })
                            end
                        else
                            -- No location data, try to get there anyway
                            add_task(turtle, {
                                action = 'follow_mining_turtle',
                                data = {target_location},
                                end_state = 'following',
                            })
                        end
                    else
                        -- No pair or no location data, go idle
                        add_task(turtle, {action = 'pass', end_state = 'idle'})
                    end
                end
            end
        end
    end
    if #turtles_for_pair == 2 then
        pair_turtles_begin(turtles_for_pair[1], turtles_for_pair[2])
    end
end


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
    
    -- Find the closest unmined block
    gen_next_block()
    
    -- DEV: Check if hub version has DEV suffix - if so, force update all turtles
    local hub_version = get_hub_version()
    if hub_version and is_dev_version(hub_version) then
        print('DEV: Hub version has -DEV suffix. Will force update all turtles...')
        -- Wait a bit for turtles to report, then queue them for force update
        state.dev_force_update_pending = true
        state.dev_force_update_wait = 0
    end
    
    while true do
        -- DEV: Handle force update after waiting for turtles to report
        if state.dev_force_update_pending then
            state.dev_force_update_wait = (state.dev_force_update_wait or 0) + 1
            -- Wait 5 seconds (50 cycles at 0.1s each) for turtles to report
            if state.dev_force_update_wait >= 50 then
                print('DEV: Force updating all turtles...')
                local turtle_list = {}
                for _, turtle in pairs(state.turtles) do
                    if turtle.data then
                        table.insert(turtle_list, turtle)
                    end
                end
                if #turtle_list > 0 then
                    queue_turtles_for_update(turtle_list, false, true)  -- force_update = true
                else
                    print('DEV: No turtles found. Will check again in 5 seconds...')
                    state.dev_force_update_wait = 0  -- Reset counter to check again
                end
                state.dev_force_update_pending = false
                state.dev_force_update_wait = nil
            end
        end
        
        user_input()         -- PROCESS USER INPUT
        command_turtles()    -- COMMAND TURTLES
        sleep(0.1)           -- DELAY 0.1 SECONDS
    end
end


main()