inf = basics.inf
str_xyz = basics.str_xyz

--lua_print = print
--log_file = fs.open('log.txt', 'w')
--function print(thing)
--    lua_print(thing)
--    log_file.writeLine(thing)
--end
    

bumps = {
    north = { 0,  0, -1},
    south = { 0,  0,  1},
    east  = { 1,  0,  0},
    west  = {-1,  0,  0},
}


left_shift = {
    north = 'west',
    south = 'east',
    east  = 'north',
    west  = 'south',
}


right_shift = {
    north = 'east',
    south = 'west',
    east  = 'south',
    west  = 'north',
}


reverse_shift = {
    north = 'south',
    south = 'north',
    east  = 'west',
    west  = 'east',
}


move = {
    forward = turtle.forward,
    up      = turtle.up,
    down    = turtle.down,
    back    = turtle.back,
    left    = turtle.turnLeft,
    right   = turtle.turnRight
}


detect = {
    forward = turtle.detect,
    up      = turtle.detectUp,
    down    = turtle.detectDown
}


inspect = {
    forward = turtle.inspect,
    up      = turtle.inspectUp,
    down    = turtle.inspectDown
}


dig = {
    forward = turtle.dig,
    up      = turtle.digUp,
    down    = turtle.digDown
}

attack = {
    forward = turtle.attack,
    up      = turtle.attackUp,
    down    = turtle.attackDown
}


getblock = {
    
    up = function(pos, fac)
        if not pos then pos = state.location end
        if not fac then fac = state.orientation end
        return {x = pos.x, y = pos.y + 1, z = pos.z}
    end,

    down = function(pos, fac)
        if not pos then pos = state.location end
        if not fac then fac = state.orientation end
        return {x = pos.x, y = pos.y - 1, z = pos.z}
    end,

    forward = function(pos, fac)
        if not pos then pos = state.location end
        if not fac then fac = state.orientation end
        local bump = bumps[fac]
        return {x = pos.x + bump[1], y = pos.y + bump[2], z = pos.z + bump[3]}
    end,
    
    back = function(pos, fac)
        if not pos then pos = state.location end
        if not fac then fac = state.orientation end
        local bump = bumps[fac]
        return {x = pos.x - bump[1], y = pos.y - bump[2], z = pos.z - bump[3]}
    end,
    
    left = function(pos, fac)
        if not pos then pos = state.location end
        if not fac then fac = state.orientation end
        local bump = bumps[left_shift[fac]]
        return {x = pos.x + bump[1], y = pos.y + bump[2], z = pos.z + bump[3]}
    end,
    
    right = function(pos, fac)
        if not pos then pos = state.location end
        if not fac then fac = state.orientation end
        local bump = bumps[right_shift[fac]]
        return {x = pos.x + bump[1], y = pos.y + bump[2], z = pos.z + bump[3]}
    end,
}


function digblock(direction)
    dig[direction]()
    return true
end


function delay(duration)
    sleep(duration)
    return true
end


function up()
    return go('up')
end


function forward()
    return go('forward')
end


function down()
    return go('down')
end


function back()
    return go('back')
end


function left()
    return go('left')
end


function right()
    return go('right')
end


function follow_route(route)
    for step in route:gmatch'.' do
        if step == 'u' then
            if not go('up')      then return false end
        elseif step == 'f' then
            if not go('forward') then return false end
        elseif step == 'd' then
            if not go('down')    then return false end
        elseif step == 'b' then
            if not go('back')    then return false end
        elseif step == 'l' then
            if not go('left')    then return false end
        elseif step == 'r' then
            if not go('right')   then return false end
        end
    end
    return true
end
                    
                    
function face(orientation)
    if state.orientation == orientation then
        return true
    elseif right_shift[state.orientation] == orientation then
        if not go('right') then return false end
    elseif left_shift[state.orientation] == orientation then
        if not go('left') then return false end
    elseif right_shift[right_shift[state.orientation]] == orientation then
        if not go('right') then return false end
        if not go('right') then return false end
    else
        return false
    end
    return true
end


function log_movement(direction)
    if direction == 'up' then
        state.location.y = state.location.y +1
    elseif direction == 'down' then
        state.location.y = state.location.y -1
    elseif direction == 'forward' then
        bump = bumps[state.orientation]
        state.location = {x = state.location.x + bump[1], y = state.location.y + bump[2], z = state.location.z + bump[3]}
    elseif direction == 'back' then
        bump = bumps[state.orientation]
        state.location = {x = state.location.x - bump[1], y = state.location.y - bump[2], z = state.location.z - bump[3]}
    elseif direction == 'left' then
        state.orientation = left_shift[state.orientation]
    elseif direction == 'right' then
        state.orientation = right_shift[state.orientation]
    end
    return true
end


function go(direction, nodig)
    if not nodig then
        if detect[direction] then
            if detect[direction]() then
                -- Try to dig, but check if block is disallowed
                local dig_success = safedig(direction)
                -- If safedig returned false, it might be a disallowed block
                -- We still try to move - if movement fails, we'll return false
            end
        end
    end
    if not move[direction] then
        return false
    end
    if not move[direction]() then
        -- Movement failed - might be disallowed block or other obstacle
        if attack[direction] then
            attack[direction]()
        end
        return false
    end
    log_movement(direction)
    return true
end


function go_to_axis(axis, coordinate, nodig)
    local delta = coordinate - state.location[axis]
    if delta == 0 then
        return true
    end
    
    if axis == 'x' then
        if delta > 0 then
            if not face('east') then return false end
        else
            if not face('west') then return false end
        end
    elseif axis == 'z' then
        if delta > 0 then
            if not face('south') then return false end
        else
            if not face('north') then return false end
        end
    end
    
    for i = 1, math.abs(delta) do
        if axis == 'y' then
            if delta > 0 then
                if not go('up', nodig) then return false end
            else
                if not go('down', nodig) then return false end
            end
        else
            if not go('forward', nodig) then return false end
        end
    end
    return true
end


function go_to(end_location, end_orientation, path, nodig)
    if path then
        for axis in path:gmatch'.' do
            if not go_to_axis(axis, end_location[axis], nodig) then return false end
        end
    elseif end_location.path then
        for axis in end_location.path:gmatch'.' do
            if not go_to_axis(axis, end_location[axis], nodig) then return false end
        end
    else
        return false
    end
    if end_orientation then
        if not face(end_orientation) then return false end
    elseif end_location.orientation then
        if not face(end_location.orientation) then return false end
    end
    return true
end


function go_route(route, xyzo)
    local xyz_string
    if xyzo then
        xyz_string = str_xyz(xyzo)
    end
    local location_str = basics.str_xyz(state.location)
    while route[location_str] and location_str ~= xyz_string do
        if not go_to(route[location_str], nil, 'xyz') then return false end
        location_str = basics.str_xyz(state.location)
    end
    if xyzo then
        if location_str ~= xyz_string then
            return false
        end
        if xyzo.orientation then
            if not face(xyzo.orientation) then return false end
        end
    end
    return true
end


function go_to_home()
    state.updated_not_home = nil
    if basics.in_area(state.location, config.locations.home_area) then
        return true
    elseif basics.in_area(state.location, config.locations.greater_home_area) then
        if not go_to_home_exit() then return false end
    elseif basics.in_area(state.location, config.locations.waiting_room_area) then
        if not go_to(config.locations.mine_exit, nil, config.paths.waiting_room_to_mine_exit, true) then return false end
    elseif state.location.y < config.locations.mine_enter.y then
        return false
    end
    if config.locations.main_loop_route[basics.str_xyz(state.location)] then
        if not go_route(config.locations.main_loop_route, config.locations.home_enter) then return false end
    elseif basics.in_area(state.location, config.locations.control_room_area) then
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
    if basics.in_area(state.location, config.locations.greater_home_area) then
        if not go_to(config.locations.home_exit, nil, config.paths.home_to_home_exit) then return false end
    elseif config.locations.main_loop_route[basics.str_xyz(state.location)] then
        if not go_route(config.locations.main_loop_route, config.locations.home_exit) then return false end
    else
        return false
    end
    return true
end


function go_to_item_drop()
    if not config.locations.main_loop_route[basics.str_xyz(state.location)] then
        if not go_to_home() then return false end
        if not go_to_home_exit() then return false end
    end
    if not go_route(config.locations.main_loop_route, config.locations.item_drop) then return false end
    return true
end


function go_to_refuel()
    if not config.locations.main_loop_route[basics.str_xyz(state.location)] then
        if not go_to_home() then return false end
        if not go_to_home_exit() then return false end
    end
    if not go_route(config.locations.main_loop_route, config.locations.refuel) then return false end
    return true
end


function go_to_disk()
    if not config.locations.main_loop_route[basics.str_xyz(state.location)] then
        if not go_to_home() then return false end
        if not go_to_home_exit() then return false end
    end
    if not go_route(config.locations.main_loop_route, config.locations.disk_drive) then return false end
    return true
end


function go_to_waiting_room()
    if not basics.in_area(state.location, config.locations.waiting_room_line_area) then
        if not go_to_home() then return false end
    end
    if not go_to(config.locations.waiting_room, nil, config.paths.home_to_waiting_room) then return false end
    return true
end


function go_to_mine_enter()
    -- Navigate to mine_enter from current location
    -- First check if we're already at mine_enter
    if basics.in_location({x = state.location.x, y = state.location.y, z = state.location.z}, config.locations.mine_enter) then
        return true
    end
    
    -- If in waiting room area, use the route
    if basics.in_area(state.location, config.locations.waiting_room_area) then
        if not go_route(config.locations.waiting_room_to_mine_enter_route) then return false end
        return true
    end
    
    -- Otherwise, navigate to waiting room first, then to mine_enter
    if not basics.in_area(state.location, config.locations.waiting_room_line_area) then
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


function safedig(direction)
    -- DIG IF BLOCK NOT ON BLACKLIST
    if not direction then
        direction = 'forward'
    end
    
    local block_data = ({inspect[direction]()})[2]
    local block_name = block_data and block_data.name
    if block_name then
        for _, word in pairs(config.dig_disallow) do
            if string.find(string.lower(block_name), word) then
                return false
            end
        end

        -- Check if it's an ore BEFORE digging (since block will be gone after)
        local is_ore = detect_ore(direction)
        
        local result = dig[direction]()
        
        -- Track statistics if block was successfully dug
        if result then
            -- Initialize statistics if not already done
            if not state.statistics then
                state.statistics = {
                    blocks_mined = 0,
                    ores_mined = 0,
                    ore_counts = {}
                }
            end
            
            -- Increment total blocks mined
            state.statistics.blocks_mined = state.statistics.blocks_mined + 1
            
            -- Track ore if it was detected as an ore
            if is_ore then
                state.statistics.ores_mined = state.statistics.ores_mined + 1
                state.statistics.ore_counts[block_name] = (state.statistics.ore_counts[block_name] or 0) + 1
            end
        end
        
        return result
    end
    return true
end


function dump_items(omit)
    for slot = 1, 16 do
        if turtle.getItemCount(slot) > 0 and ((not omit) or (not omit[turtle.getItemDetail(slot).name])) then
            turtle.select(slot)
            if not turtle.drop() then return false end
        end
    end
    return true
end
    


function prepare(min_fuel_amount)
    if state.item_count > 0 then
        if not go_to_item_drop() then return false end
        if not dump_items(config.fuelnames) then return false end
    end
    local min_fuel_amount = min_fuel_amount + config.fuel_padding
    if not go_to_refuel() then return false end
    if not dump_items() then return false end
    turtle.select(1)
    if turtle.getFuelLevel() ~= 'unlimited' then
        while turtle.getFuelLevel() < min_fuel_amount do
            if not turtle.suck(math.min(64, math.ceil(min_fuel_amount / config.fuel_per_unit))) then return false end
            turtle.refuel()
        end
    end
    return true
end


function calibrate()
    -- GEOPOSITION BY MOVING TO ADJACENT BLOCK AND BACK
    local sx, sy, sz = gps.locate()
--    if sx == config.interface.x and sy == config.interface.y and sz == config.interface.z then
--        refuel()
--    end
    if not sx or not sy or not sz then
        return false
    end
    for i = 1, 4 do
        -- TRY TO FIND EMPTY ADJACENT BLOCK
        if not turtle.detect() then
            break
        end
        if not turtle.turnRight() then return false end
    end
    if turtle.detect() then
        -- TRY TO DIG ADJACENT BLOCK
        for i = 1, 4 do
            safedig('forward')
            if not turtle.detect() then
                break
            end
            if not turtle.turnRight() then return false end
        end
        if turtle.detect() then
            return false
        end
    end
    if not turtle.forward() then return false end
    local nx, ny, nz = gps.locate()
    if nx == sx + 1 then
        state.orientation = 'east'
    elseif nx == sx - 1 then
        state.orientation = 'west'
    elseif nz == sz + 1 then
        state.orientation = 'south'
    elseif nz == sz - 1 then
        state.orientation = 'north'
    else
        return false
    end
    state.location = {x = nx, y = ny, z = nz}
    print('Calibrated to ' .. str_xyz(state.location, state.orientation))
    
    back()
    
    if basics.in_area(state.location, config.locations.home_area) then
        face(left_shift[left_shift[config.locations.homes.increment]])
    end
    
    return true
end


function initialize(session_id, config_values)
    -- INITIALIZE TURTLE
    
    state.session_id = session_id
    
    -- COPY CONFIG DATA INTO MEMORY
    for k, v in pairs(config_values) do
        config[k] = v
    end
    
    -- DETERMINE TURTLE TYPE
    state.peripheral_left = peripheral.getType('left')
    state.peripheral_right = peripheral.getType('right')
    if state.peripheral_left == 'chunkLoader' or state.peripheral_right == 'chunkLoader' or state.peripheral_left == 'chunky' or state.peripheral_right == 'chunky' then
        state.type = 'chunky'
        for k, v in pairs(config.chunky_turtle_locations) do
            config.locations[k] = v
        end
    else
        state.type = 'mining'
        for k, v in pairs(config.mining_turtle_locations) do
            config.locations[k] = v
        end
        if state.peripheral_left == 'modem' then
            state.peripheral_right = 'pick'
        else
            state.peripheral_left = 'pick'
        end
    end
    
    state.request_id = 1
    state.initialized = true
    return true
end


function getcwd()
    local running_program = shell.getRunningProgram()
    local program_name = fs.getName(running_program)
    return "/" .. running_program:sub(1, #running_program - #program_name)
end


function pass()
    return true
end


function dump(direction)
    if not face(direction) then return false end
    if ({inspect.forward()})[2].name ~= 'computercraft:turtle_advanced' then
        return false
    end
    for slot = 1, 16 do
        if turtle.getItemCount(slot) > 0 then
            turtle.select(slot)
            turtle.drop()
        end
    end
    return true
end


function checkTags(data)
    if type(data.tags) ~= 'table' then
        return false
    end
    if not config.blocktags then
        return false
    end
    for k,v in pairs(data.tags) do
        if config.blocktags[k] then
            return true
        end
    end
    return false
end


function detect_ore(direction)
    local block = ({inspect[direction]()})[2]
    if block == nil or block.name == nil then
        return false
    end
    -- Check config.orenames first (user-defined ore list takes priority)
    if config.orenames and config.orenames[block.name] then
        return true
    end
    -- Check if block name contains "_ore" (case-insensitive) - catches modded ores
    if block.name:lower():find("_ore") then
        return true
    end
    -- Check for forge ore tags (useful for modded ores that use tags)
    if checkTags(block) then
        return true
    end
    return false
end


function scan(valid, ores)
    local checked_left  = false
    local checked_right = false
    
    local f = str_xyz(getblock.forward())
    local u = str_xyz(getblock.up())
    local d = str_xyz(getblock.down())
    local l = str_xyz(getblock.left())
    local r = str_xyz(getblock.right())
    local b = str_xyz(getblock.back())
    
    if not valid[f] and valid[f] ~= false then
        valid[f] = detect_ore('forward')
        ores[f] = valid[f]
    end
    if not valid[u] and valid[u] ~= false then
        valid[u] = detect_ore('up')
        ores[u] = valid[u]
    end
    if not valid[d] and valid[d] ~= false then
        valid[d] = detect_ore('down')
        ores[d] = valid[d]
    end
    if not valid[l] and valid[l] ~= false then
        left()
        checked_left = true
        valid[l] = detect_ore('forward')
        ores[l] = valid[l]
    end
    if not valid[r] and valid[r] ~= false then
        right()
        if checked_left then
            right()
        end
        checked_right = true
        valid[r] = detect_ore('forward')
        ores[r] = valid[r]
    end
    if not valid[b] and valid[b] ~= false then
        if checked_right then
            right()
        elseif checked_left then
            left()
        else
            right(2)
        end
        valid[b] = detect_ore('forward')
        ores[b] = valid[b]
    end
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


function clear_gravity_blocks()
    for _, direction in pairs({'forward', 'up'}) do
        while config.gravitynames[ ({inspect[direction]()})[2].name ] do
            safedig(direction)
            sleep(1)
        end
    end
    return true
end


-- ============================================
-- Block-based mining functions
-- ============================================

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
    if not basics.in_location({x = state.location.x, y = state.location.y, z = state.location.z}, config.locations.mine_enter) then
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
    if not basics.in_location({x = state.location.x, y = state.location.y, z = state.location.z}, config.locations.mine_enter) then
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


function detect_bedrock(direction)
    -- Check if block below is bedrock
    -- direction should be 'down' for world eater
    if not direction then
        direction = 'down'
    end
    
    local success, data = inspect[direction]()
    if not success or not data then
        return false
    end
    
    local block_name = data.name or ""
    -- Check if block name contains "bedrock" (case insensitive)
    if string.find(string.lower(block_name), "bedrock") then
        return true
    end
    
    -- Also check if we've reached bedrock level
    if direction == 'down' and state.location.y <= config.bedrock_level then
        return true
    end
    
    return false
end


function find_path_around_obstacle()
    -- Try to find a path around an obstacle by checking adjacent blocks
    -- Returns true if path found and turtle moved to new position, false if no path
    -- Checks blocks in cardinal directions (north, south, east, west) first
    
    local original_pos = {x = state.location.x, y = state.location.y, z = state.location.z, facing = state.orientation}
    local directions = {
        {dx = -1, dz = 0, face = 'west'},
        {dx = 1, dz = 0, face = 'east'},
        {dx = 0, dz = -1, face = 'north'},
        {dx = 0, dz = 1, face = 'south'},
    }
    
    -- Try each cardinal direction
    for _, dir in ipairs(directions) do
        -- Face the direction
        if face(dir.face) then
            local found_path = false
            
            -- Check if we can move forward
            if detect.forward() then
                -- Block in way, try to dig it
                if safedig('forward') then
                    -- Can dig, try to move
                    if go('forward') then
                        found_path = true
                    end
                end
            else
                -- No block in way, try to move
                if go('forward') then
                    found_path = true
                end
            end
            
            if found_path then
                -- Now check what's below at this new position
                if detect.down() then
                    local success, block_data = inspect.down()
                    if success and block_data then
                        local block_name = block_data.name or ""
                        local is_disallowed = false
                        local is_bedrock = false
                        
                        for _, word in pairs(config.dig_disallow) do
                            if string.find(string.lower(block_name), word) then
                                is_disallowed = true
                                if string.find(string.lower(block_name), "bedrock") then
                                    is_bedrock = true
                                end
                                break
                            end
                        end
                        
                        if not is_disallowed then
                            -- Found a path! This block below is minable
                            print("Found path around obstacle, continuing from new position")
                            return true
                        elseif is_bedrock then
                            -- Bedrock below, can't mine here either
                            -- Move back and try next direction
                            go('back')
                        else
                            -- Another disallowed block, move back and try next direction
                            go('back')
                        end
                    else
                        -- No block below, can mine here
                        print("Found path around obstacle, continuing from new position")
                        return true
                    end
                else
                    -- No block below, can mine here
                    print("Found path around obstacle, continuing from new position")
                    return true
                end
            end
        end
    end
    
    -- No path found, return to original position
    -- Try to get back to original position
    if state.location.x ~= original_pos.x or state.location.z ~= original_pos.z then
        -- We moved, try to get back
        go_to({x = original_pos.x, y = state.location.y, z = original_pos.z}, original_pos.facing, 'xz')
    end
    
    return false
end


function mine_column_down(block)
    -- Mine straight down from current position to bedrock
    -- Returns true if completed, false if interrupted
    local start_y = state.location.y
    local target_y = config.bedrock_level
    local original_x = block and block.x or state.location.x
    local original_z = block and block.z or state.location.z
    
    -- Check if we're already at or below bedrock
    if start_y <= target_y then
        return true
    end
    
    -- Mine down block by block
    while state.location.y > target_y do
        -- Check for bedrock before digging
        if detect_bedrock('down') then
            -- Reached bedrock, stop mining
            break
        end
        
        -- Check inventory space
        if state.empty_slot_count == 0 then
            -- Inventory full, need to return
            return false
        end
        
        -- Check fuel (rough estimate)
        local fuel_needed = (state.location.y - target_y) * 2  -- Down and back up
        if turtle.getFuelLevel() ~= "unlimited" and turtle.getFuelLevel() < fuel_needed + 50 then
            -- Low on fuel, return early
            return false
        end
        
        -- Check if block below exists
        if detect.down() then
            -- Inspect block to check if it's disallowed
            local success, block_data = inspect.down()
            if success and block_data then
                local block_name = block_data.name or ""
                local is_disallowed = false
                local is_bedrock = false
                
                for _, word in pairs(config.dig_disallow) do
                    if string.find(string.lower(block_name), word) then
                        is_disallowed = true
                        if string.find(string.lower(block_name), "bedrock") then
                            is_bedrock = true
                        end
                        break
                    end
                end
                
                if is_disallowed then
                    if is_bedrock then
                        -- Bedrock reached - stop mining and return
                        print("Reached bedrock at Y=" .. state.location.y)
                        break
                    else
                        -- Other disallowed block (chest, computer, etc.) - try to go around
                        print("Encountered disallowed block: " .. block_name .. " - attempting to navigate around...")
                        
                        -- Try to find a path around the obstacle
                        if find_path_around_obstacle() then
                            -- Found a path, continue mining from new position
                            -- Continue loop to mine down from new position
                        else
                            -- No path found, return to surface
                            print("Could not navigate around obstacle, returning to surface...")
                            return false
                        end
                    end
                else
                    -- Block is minable, try to dig it
                    safedig('down')
                end
            else
                -- No block data, try to dig anyway
                safedig('down')
            end
        end
        
        -- Move down
        if not go('down') then
            -- Can't move down, might be bedrock or unbreakable obstacle
            -- Check if it's bedrock
            if detect.down() then
                local success, block_data = inspect.down()
                if success and block_data then
                    local block_name = block_data.name or ""
                    if string.find(string.lower(block_name), "bedrock") then
                        -- Bedrock, stop mining
                        break
                    else
                        -- Not bedrock, try to navigate around
                        if find_path_around_obstacle() then
                            -- Found path, continue mining
                            -- Continue loop to mine from new position
                        else
                            -- No path, give up
                            return false
                        end
                    end
                end
            end
            break
        end
        
        -- Clear any gravity blocks that may have fallen above
        if detect.up() then
            local up_success, up_data = inspect.up()
            if up_success and up_data and config.gravitynames[up_data.name] then
                safedig('up')
                sleep(0.5)  -- Wait for block to fall
            end
        end
    end
    
    return true
end


function mine_column_up(target_y)
    -- Return to surface (or target Y level)
    -- Mines up if needed (blocks may have fallen)
    if not target_y then
        target_y = config.locations.mining_center.y + 2  -- Surface level
    end
    
    while state.location.y < target_y do
        -- Check if block above exists
        if detect.up() then
            -- Block above, dig it
            safedig('up')
        end
        
        -- Move up
        if not go('up') then
            -- Can't move up, might be obstacle
            return false
        end
    end
    
    return true
end


function mine_to_bedrock(block)
    -- Main world eater mining function
    -- Mines entire column from surface to bedrock
    -- block = {x = x, z = z}
    
    if not block or not block.x or not block.z then
        return false
    end
    
    -- Ensure we're at the correct block position
    local surface_y = config.locations.mining_center.y + 2
    if state.location.x ~= block.x or state.location.z ~= block.z or state.location.y ~= surface_y then
        -- Not at correct position, navigate there first
        if not go_to_block(block) then
            return false
        end
    end
    
    -- Mine down to bedrock
    local completed = mine_column_down(block)
    
    -- Clear gravity blocks before returning
    clear_gravity_blocks()
    
    -- Return to surface
    if not mine_column_up(surface_y) then
        -- Failed to return to surface, but mining is done
        -- Try to get back to surface level at least
        while state.location.y < surface_y do
            if detect.up() then
                safedig('up')
            end
            if not go('up') then
                break
            end
        end
    end
    
    -- Return to exact block position at surface
    if state.location.x ~= block.x or state.location.z ~= block.z then
        go_to({x = block.x, y = state.location.y, z = block.z}, nil, 'xz')
    end
    
    return completed
end