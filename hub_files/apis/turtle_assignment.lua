-- ============================================
-- Turtle Assignment Module
-- Handles block assignment and turtle pairing
-- ============================================

-- Get API references
local config = API.getConfig()
local state = API.getState()
local utilities = API.getUtilities()

function get_closest_unmined_block()
    -- Find the closest unmined block (x, z) starting from mining_center
    -- Spiral outward from mining_center to find closest unmined block
    local center = config.locations.mining_center
    local min_dist = utilities.inf
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
        min_x = config.mining_area and config.mining_area.min_x or -utilities.inf
        max_x = config.mining_area and config.mining_area.max_x or utilities.inf
        min_z = config.mining_area and config.mining_area.min_z or -utilities.inf
        max_z = config.mining_area and config.mining_area.max_z or utilities.inf
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
                                    local distance = utilities.distance(
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
    local next_block = get_closest_unmined_block()
    API.setStateValue('next_block', next_block)
    if next_block then
        -- Calculate fuel needed: distance to block + depth to bedrock * 2 (down and back) + padding
        local surface_y = config.locations.mining_center.y + 2  -- Surface level
        local distance_to_block = utilities.distance(
            {x = next_block.x, y = surface_y, z = next_block.z},
            config.locations.mine_enter
        )
        local depth = surface_y - config.bedrock_level  -- Depth from surface to bedrock
        API.setStateValue('min_fuel', (distance_to_block + depth * 2 + config.fuel_padding) * 3)
    else
        API.setStateValue('min_fuel', nil)
    end
end


function good_on_fuel(mining_turtle, chunky_turtle)
    -- Calculate fuel needed based on current location and mining depth
    local current_depth = mining_turtle.data.location.y
    local surface_y = config.locations.mining_center.y + 2
    local depth_to_surface = surface_y - current_depth
    local distance_to_exit = utilities.distance(mining_turtle.data.location, config.locations.mine_exit)
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
    API.setStateValue('pair_hold', nil)
end


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
    
    local state_refresh = API.getState()
    local block = state_refresh.next_block
    
    if not block then
        gen_next_block()
        state_refresh = API.getState()
        block = state_refresh.next_block
        if not block then
            add_task(mining_turtle, {action = 'pass', end_state = 'idle'})
            add_task(chunky_turtle, {action = 'pass', end_state = 'idle'})
            return
        end
    end
    
    print('Pairing ' .. mining_turtle.id .. ' and ' .. chunky_turtle.id .. ' to block (' .. block.x .. ',' .. block.z .. ')')
    
    mining_turtle.pair = chunky_turtle
    chunky_turtle.pair = mining_turtle
    
    API.setStateValue('pair_hold', {mining_turtle, chunky_turtle})
    
    -- Assign block to both turtles
    mining_turtle.block = block
    chunky_turtle.block = block
    
    -- Write block assignment
    write_turtle_block(mining_turtle, block)
    write_turtle_block(chunky_turtle, block)
    
    -- Mark as deployed (mining in progress)
    state_refresh = API.getState()
    fs.open(state_refresh.turtles_dir_path .. chunky_turtle.id .. '/deployed', 'w').close()
    local file = fs.open(state_refresh.turtles_dir_path .. mining_turtle.id .. '/deployed', 'w')
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
    local state_refresh = API.getState()
    local block = state_refresh.next_block
    
    if not block then
        gen_next_block()
        state_refresh = API.getState()
        block = state_refresh.next_block
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
    state_refresh = API.getState()
    local file = fs.open(state_refresh.turtles_dir_path .. turtle.id .. '/deployed', 'w')
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
    local state_refresh = API.getState()
    if state_refresh.min_fuel then
        if (turtle.data.fuel_level ~= "unlimited" and turtle.data.fuel_level <= state_refresh.min_fuel) then
            add_task(turtle, {action = 'prepare', data = {state_refresh.min_fuel}})
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

