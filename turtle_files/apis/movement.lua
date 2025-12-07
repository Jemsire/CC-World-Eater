-- ============================================
-- Movement Module
-- Basic movement and direction functions
-- ============================================
-- Uses globals: inf, str_xyz (from utilities, loaded via os.loadAPI)

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
        return {x = pos.x - bump[1], y = pos.y - bump[2], z = pos.z + bump[3]}
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
    -- Safety check: ensure state.location exists before updating it
    if not state.location then
        return true  -- Can't log movement without a starting location
    end
    
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
    local location_str = str_xyz(state.location)
    while route[location_str] and location_str ~= xyz_string do
        if not go_to(route[location_str], nil, 'xyz') then return false end
        location_str = str_xyz(state.location)
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

function pass()
    return true
end

