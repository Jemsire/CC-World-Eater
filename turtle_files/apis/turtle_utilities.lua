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
        if utilities.in_area(state.location, config.locations.home_area) then
            if config.locations.homes and config.locations.homes.increment then
                face(left_shift[left_shift[config.locations.homes.increment]])
            end
        end
    end
    
    return true
end

function initialize(session_id, config_values)
    -- INITIALIZE TURTLE (full initialization from hub with config)
    -- Note: Turtle may have already done partial self-initialization in startup.lua
    
    -- Always process initialize command and send handshake, even if we've done it before
    -- This ensures handshake is sent if hub didn't receive it the first time
    local was_initialized = (state.session_id == session_id and state.config_received_sent)
    if was_initialized then
        print('=== INITIALIZE: Re-initializing with same session_id - will re-send handshake ===')
    end
    
    state.session_id = session_id
    
    -- COPY CONFIG DATA INTO MEMORY
    for k, v in pairs(config_values) do
        config[k] = v
    end
    
    -- DETERMINE TURTLE TYPE (if not already set by partial init)
    if not state.type then
        state.peripheral_left = peripheral.getType('left')
        state.peripheral_right = peripheral.getType('right')
        if state.peripheral_left == 'chunkLoader' or state.peripheral_right == 'chunkLoader' or state.peripheral_left == 'chunky' or state.peripheral_right == 'chunky' then
            state.type = 'chunky'
        else
            state.type = 'mining'
            if state.peripheral_left == 'modem' then
                state.peripheral_right = 'pick'
            else
                state.peripheral_left = 'pick'
            end
        end
    end
    
    -- SET LOCATIONS BASED ON TURTLE TYPE
    if state.type == 'chunky' then
        for k, v in pairs(config.chunky_turtle_locations) do
            config.locations[k] = v
        end
    else
        for k, v in pairs(config.mining_turtle_locations) do
            config.locations[k] = v
        end
    end
    
    -- Preserve request_id if already set (from partial init), otherwise set to 1
    if not state.request_id or state.request_id == 0 then
        state.request_id = 1
    end
    
    state.initialized = true
    print('Full initialization complete - session_id: ' .. tostring(session_id) .. ', type: ' .. state.type)
    
    -- SEND HANDSHAKE TO HUB CONFIRMING CONFIG RECEIVED
    print('=== INITIALIZE: Preparing to send config_received handshake ===')
    
    -- Verify rednet is open (should be opened in startup.lua, but check anyway)
    local rednet_open = false
    for _, side in pairs({'back', 'top', 'left', 'right'}) do
        if peripheral.getType(side) == 'modem' then
            rednet.open(side)
            rednet_open = true
            break
        end
    end
    
    if not rednet_open then
        print('=== INITIALIZE: ERROR: Rednet not available, cannot send handshake ===')
        return true  -- Still return success since initialization completed
    end
    
    local hub_id_file = fs.open('/hub_id', 'r')
    if hub_id_file then
        local hub_id = tonumber(hub_id_file.readAll())
        hub_id_file.close()
        if hub_id then
            print('=== INITIALIZE: Hub ID: ' .. hub_id .. ' ===')
            print('=== INITIALIZE: Session ID: ' .. tostring(session_id) .. ' ===')
            print('=== INITIALIZE: Sending config_received handshake to hub ' .. hub_id .. ' ===')
            
            local handshake_message = {
                action = 'config_received',
                session_id = session_id
            }
            
            -- Send handshake with error handling
            local success, err = pcall(function()
                rednet.send(hub_id, handshake_message, 'turtle_report')
            end)
            
            if success then
                print('=== INITIALIZE: Handshake SENT successfully ===')
                state.config_received_sent = true  -- Mark that we've sent the handshake
            else
                print('=== INITIALIZE: ERROR: Failed to send handshake: ' .. tostring(err) .. ' ===')
            end
        else
            print('=== INITIALIZE: ERROR: Could not read hub_id from file (nil) ===')
        end
    else
        print('=== INITIALIZE: ERROR: Could not open /hub_id file ===')
    end
    
    return true
end

function getcwd()
    local running_program = shell.getRunningProgram()
    local program_name = fs.getName(running_program)
    return "/" .. running_program:sub(1, #running_program - #program_name)
end

