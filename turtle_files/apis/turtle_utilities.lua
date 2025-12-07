-- ============================================
-- Turtle Utilities Module
-- Initialization and calibration functions
-- ============================================

function calibrate_self()
    -- STANDALONE CALIBRATION - Gets location and orientation without requiring config
    -- Used during self-initialization before hub sends config
    local sx, sy, sz = gps.locate()
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
        back()
        return false
    end
    state.location = {x = nx, y = ny, z = nz}
    print('Self-calibrated to ' .. str_xyz(state.location, state.orientation))
    back()
    return true
end

function calibrate()
    -- GEOPOSITION BY MOVING TO ADJACENT BLOCK AND BACK
    -- This version includes home_area check (requires config.locations)
    -- For self-initialization, use calibrate_self() instead
    
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
    
    -- Only check home_area if config.locations has been set (from hub initialization)
    if config.locations and config.locations.home_area then
        if in_area(state.location, config.locations.home_area) then
            if config.locations.homes and config.locations.homes.increment then
                face(left_shift[left_shift[config.locations.homes.increment]])
            end
        end
    end
    
    return true
end

function initialize(session_id, config_values)
    -- INITIALIZE TURTLE (old simple method - no handshake)
    
    -- Safety check: ensure we have valid arguments
    if not session_id then
        print("ERROR: initialize called without session_id")
        return false
    end
    
    if not config_values or type(config_values) ~= "table" then
        print("ERROR: initialize called without valid config_values (got: " .. tostring(type(config_values)) .. ")")
        return false
    end
    
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
    
    -- Don't reset request_id if already set (preserve from previous initialization)
    if not state.request_id or state.request_id == 0 then
        state.request_id = 1
    end
    state.initialized = true
    print('[DEBUG] Initialize complete - session_id: ' .. tostring(session_id) .. ', type: ' .. tostring(state.type) .. ', request_id: ' .. tostring(state.request_id))
    return true
end

function getcwd()
    local running_program = shell.getRunningProgram()
    local program_name = fs.getName(running_program)
    return "/" .. running_program:sub(1, #running_program - #program_name)
end

-- Explicitly expose functions as globals (os.loadAPI wraps in table, but we want globals)
_G.calibrate_self = calibrate_self
_G.calibrate = calibrate
_G.initialize = initialize
_G.getcwd = getcwd

