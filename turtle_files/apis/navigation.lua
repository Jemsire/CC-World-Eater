-- ============================================
-- Navigation Module
-- Location-specific navigation functions
-- ============================================

function go_to_home()
    -- Check if config.locations is available (turtle needs to be fully initialized by hub first)
    if not config.locations then
        print('ERROR: Cannot go_to_home - config.locations not set. Waiting for hub initialization...')
        return false
    end
    
    state.updated_not_home = nil
    if utilities.in_area(state.location, config.locations.home_area) then
        return true
    elseif utilities.in_area(state.location, config.locations.greater_home_area) then
        if not go_to_home_exit() then return false end
    elseif utilities.in_area(state.location, config.locations.waiting_room_area) then
        if not go_to(config.locations.mine_exit, nil, config.paths.waiting_room_to_mine_exit, true) then return false end
    elseif state.location.y < config.locations.mine_enter.y then
        return false
    end
    if config.locations.main_loop_route[utilities.str_xyz(state.location)] then
        if not go_route(config.locations.main_loop_route, config.locations.home_enter) then return false end
    elseif utilities.in_area(state.location, config.locations.control_room_area) then
        if not go_to(config.locations.home_enter, nil, config.paths.control_room_to_home_enter, true) then return false end
    else
        return false
    end
    if not forward() then return false end
    while detect.down() do
        if not forward() then return false end
    end
    if not down() then return false end
    if not right() then return false end
    if not right() then return false end
    return true
end

function go_to_home_exit()
    if utilities.in_area(state.location, config.locations.greater_home_area) then
        if not go_to(config.locations.home_exit, nil, config.paths.home_to_home_exit) then return false end
    elseif config.locations.main_loop_route[utilities.str_xyz(state.location)] then
        if not go_route(config.locations.main_loop_route, config.locations.home_exit) then return false end
    else
        return false
    end
    return true
end

function go_to_item_drop()
    if not config.locations.main_loop_route[utilities.str_xyz(state.location)] then
        if not go_to_home() then return false end
        if not go_to_home_exit() then return false end
    end
    if not go_route(config.locations.main_loop_route, config.locations.item_drop) then return false end
    return true
end

function go_to_refuel()
    if not config.locations.main_loop_route[utilities.str_xyz(state.location)] then
        if not go_to_home() then return false end
        if not go_to_home_exit() then return false end
    end
    if not go_route(config.locations.main_loop_route, config.locations.refuel) then return false end
    return true
end

function go_to_disk()
    if not config.locations.main_loop_route[utilities.str_xyz(state.location)] then
        if not go_to_home() then return false end
        if not go_to_home_exit() then return false end
    end
    if not go_route(config.locations.main_loop_route, config.locations.disk_drive) then return false end
    return true
end

function go_to_waiting_room()
    if not utilities.in_area(state.location, config.locations.waiting_room_line_area) then
        if not go_to_home() then return false end
    end
    if not go_to(config.locations.waiting_room, nil, config.paths.home_to_waiting_room) then return false end
    return true
end

function go_to_mine_enter()
    -- Navigate to mine_enter from current location
    -- First check if we're already at mine_enter
    if utilities.in_location({x = state.location.x, y = state.location.y, z = state.location.z}, config.locations.mine_enter) then
        return true
    end
    
    -- If in waiting room area, use the route
    if utilities.in_area(state.location, config.locations.waiting_room_area) then
        if not go_route(config.locations.waiting_room_to_mine_enter_route) then return false end
        return true
    end
    
    -- Otherwise, navigate to waiting room first, then to mine_enter
    if not utilities.in_area(state.location, config.locations.waiting_room_line_area) then
        if not go_to_home() then return false end
    end
    if not go_to_waiting_room() then return false end
    
    -- Now use the route from waiting room to mine_enter
    if not go_route(config.locations.waiting_room_to_mine_enter_route) then return false end
    return true
end

function go_to_mine_exit(block)
    -- Navigate to mine exit from current location
    local target_y = config.locations.mining_center.y + 2
    
    if state.location.y < config.locations.mine_enter.y or (state.location.x == config.locations.mine_exit.x and state.location.z == config.locations.mine_exit.z) then
        if state.location.x == config.locations.mine_enter.x and state.location.z == config.locations.mine_enter.z then
            -- If directly under mine_enter, shift over to exit
            if not go_to_axis('z', config.locations.mine_exit.z) then return false end
        elseif state.location.x ~= config.locations.mine_exit.x or state.location.z ~= config.locations.mine_exit.z then
            -- If NOT directly under mine_exit go to proper y
            if not go_to_axis('y', target_y) then return false end
            
            -- Navigate to exit
            if state.location.x ~= config.locations.mine_exit.x then
                if not go_to_axis('x', config.locations.mine_exit.x) then return false end
            end
            if state.location.z ~= config.locations.mine_exit.z then
                if not go_to_axis('z', config.locations.mine_exit.z) then return false end
            end
        end
        if not go_to(config.locations.mine_exit, nil, 'xzy') then return false end
        return true
    end
end

function go_to_block(block)
    -- Navigate to assigned block (x, z) at surface level
    -- block = {x = x, z = z}
    if not block or not block.x or not block.z then
        return false
    end
    
    -- Get surface level (mining_center.y + 2)
    local surface_y = config.locations.mining_center.y + 2
    local target_location = {x = block.x, y = surface_y, z = block.z}
    
    -- Check if already at target
    if state.location.x == target_location.x and 
       state.location.y == target_location.y and 
       state.location.z == target_location.z then
        return true
    end
    
    -- If not at mine_enter, navigate there first
    if not utilities.in_location({x = state.location.x, y = state.location.y, z = state.location.z}, config.locations.mine_enter) then
        if not go_to_mine_enter() then return false end
    end
    
    -- Navigate to block position at surface level
    -- Use 'yxz' path: Y first (vertical), then X, then Z
    if not go_to(target_location, nil, 'yxz') then
        return false
    end
    
    return true
end

function go_to_block_offset(block, z_offset)
    -- Navigate to assigned block (x, z) at surface level with a Z offset
    -- block = {x = x, z = z}
    -- z_offset: positive = south, negative = north
    if not block or not block.x or not block.z then
        return false
    end
    
    if not z_offset then
        z_offset = 0
    end
    
    -- Get surface level (mining_center.y + 2)
    local surface_y = config.locations.mining_center.y + 2
    local target_location = {x = block.x, y = surface_y, z = block.z + z_offset}
    
    -- Check if already at target
    if state.location.x == target_location.x and 
       state.location.y == target_location.y and 
       state.location.z == target_location.z then
        return true
    end
    
    -- If not at mine_enter, navigate there first
    if not utilities.in_location({x = state.location.x, y = state.location.y, z = state.location.z}, config.locations.mine_enter) then
        if not go_to_mine_enter() then return false end
    end
    
    -- Navigate to block position at surface level with offset
    -- Use 'yxz' path: Y first (vertical), then X, then Z
    if not go_to(target_location, nil, 'yxz') then
        return false
    end
    
    return true
end

function follow_mining_turtle(target_location)
    -- Follow the mining turtle, staying 2 blocks above it
    -- target_location = {x = x, y = y, z = z} where chunky turtle should be (2 blocks above mining turtle)
    if not target_location or not target_location.x or not target_location.y or not target_location.z then
        return false
    end
    
    -- Navigate to target location (same X, Z as mining turtle, but Y+2)
    -- Use 'yxz' path to prioritize vertical movement
    if not go_to(target_location, nil, 'yxz') then
        return false
    end
    
    return true
end

function fastest_route(area, pos, fac, end_locations)
    local queue = {}
    local explored = {}
    table.insert(queue,
        {
            coords = {x = pos.x, y = pos.y, z = pos.z},
            facing = fac,
            path = '',
        }
    )
    explored[str_xyz(pos, fac)] = true

    while #queue > 0 do
        local node = table.remove(queue, 1)
        if end_locations[str_xyz(node.coords)] or end_locations[str_xyz(node.coords, node.facing)] then
            return node.path
        end
        for _, step in pairs({
                {coords = node.coords,                                facing = left_shift[node.facing],  path = node.path .. 'l'},
                {coords = node.coords,                                facing = right_shift[node.facing], path = node.path .. 'r'},
                {coords = getblock.forward(node.coords, node.facing), facing = node.facing,              path = node.path .. 'f'},
                {coords = getblock.up(node.coords, node.facing),      facing = node.facing,              path = node.path .. 'u'},
                {coords = getblock.down(node.coords, node.facing),    facing = node.facing,              path = node.path .. 'd'},
                }) do
            explore_string = str_xyz(step.coords, step.facing)
            if not explored[explore_string] and (not area or area[str_xyz(step.coords)]) then
                explored[explore_string] = true
                table.insert(queue, step)
            end
        end
    end
end

