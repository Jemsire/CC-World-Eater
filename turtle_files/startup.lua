-- SET LABEL
os.setComputerLabel('Turtle ' .. os.getComputerID())

print("Starting turtle initialization...")

-- INITIALIZE APIS
-- Load all APIs through init_apis.lua (handles all API loading)
print("Loading APIs...")
local init_func = loadfile('/init_apis.lua')
if not init_func then
    error("Failed to load /init_apis.lua - file not found or cannot be read")
end

local success, err = pcall(init_func)
if not success then
    print("ERROR: Failed to initialize APIs: " .. tostring(err))
    error("API initialization failed: " .. tostring(err))
end

print("APIs loaded successfully")

-- Get references from API class (for compatibility, globals are also set)
local config = API.getConfig()
local state = API.getState()
local utilities = API.getUtilities()

if not config or not state or not utilities then
    error("Failed to get API references - config: " .. tostring(config) .. ", state: " .. tostring(state) .. ", utilities: " .. tostring(utilities))
end

print("API references obtained")


-- OPEN REDNET
print("Opening rednet...")
local rednet_opened = false
for _, side in pairs({'back', 'top', 'left', 'right'}) do
    if peripheral.getType(side) == 'modem' then
        rednet.open(side)
        rednet_opened = true
        print("Rednet opened on side: " .. side)
        break
    end
end
if not rednet_opened then
    print("WARNING: No modem found, rednet not opened")
end


-- IF UPDATED PRINT "UPDATED"
if fs.exists('/updated') then
    fs.delete('/updated')
    print('UPDATED')
    state.updated_not_home = true
end

-- FULL SELF-INITIALIZATION
-- Turtle gets its own location, orientation, and type, then reports to hub
print("Performing self-initialization...")
state.request_id = 1

-- DETERMINE TURTLE TYPE
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

-- CALIBRATE TO GET LOCATION AND ORIENTATION
print("Calibrating position...")
local sx, sy, sz = gps.locate()
if sx and sy and sz then
    -- Try to find empty adjacent block
    local found_empty = false
    local start_dir = 0
    for i = 1, 4 do
        if not turtle.detect() then
            found_empty = true
            start_dir = i - 1
            break
        end
        turtle.turnRight()
    end
    
    -- If no empty space, try digging
    if not found_empty then
        for i = 1, 4 do
            turtle.dig()
            if not turtle.detect() then
                found_empty = true
                start_dir = i - 1
                break
            end
            turtle.turnRight()
        end
    end
    
    -- Move forward to determine orientation
    if found_empty and turtle.forward() then
        local nx, ny, nz = gps.locate()
        if nx and ny and nz then
            -- Determine orientation based on position change
            if nx == sx + 1 then
                state.orientation = 'east'
            elseif nx == sx - 1 then
                state.orientation = 'west'
            elseif nz == sz + 1 then
                state.orientation = 'south'
            elseif nz == sz - 1 then
                state.orientation = 'north'
            end
            
            if state.orientation then
                state.location = {x = nx, y = ny, z = nz}
                print("Self-calibrated to " .. state.location.x .. "," .. state.location.y .. "," .. state.location.z .. ":" .. state.orientation)
                turtle.back()
                -- Return to original facing direction
                for i = 1, start_dir do
                    turtle.turnRight()
                end
            else
                turtle.back()
                print("WARNING: Could not determine orientation from GPS")
            end
        else
            turtle.back()
        end
    else
        print("WARNING: Could not find empty adjacent block for calibration")
    end
else
    print("WARNING: GPS not available for self-calibration")
end

-- Mark as initialized - turtle is ready to work
state.initialized = true
print("Self-initialization complete - type: " .. state.type)
if state.location then
    print("Location: " .. state.location.x .. "," .. state.location.y .. "," .. state.location.z .. ", orientation: " .. (state.orientation or "unknown"))
else
    print("WARNING: Could not determine location during self-initialization")
end

-- SEND INITIALIZATION REPORT TO HUB
-- Read hub_id and send initialization report
if rednet_opened then
    local hub_id_file = fs.open('/hub_id', 'r')
    if hub_id_file then
        local hub_id = tonumber(hub_id_file.readAll())
        hub_id_file.close()
        if hub_id then
            print("Sending initialization report to hub " .. hub_id .. "...")
            -- Load version for report
            local turtle_version = nil
            local version_paths = {"/version.lua", "/disk/turtle_files/version.lua"}
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
                                turtle_version = version
                                break
                            end
                        end
                    end
                end
            end
            
            -- Send initialization report
            -- Include session_id if turtle has one (from previous initialization)
            -- This helps hub detect turtles with old session_ids that need reboot
            local report_data = {
                action = 'initialization_report',
                turtle_type = state.type,
                peripheral_left = state.peripheral_left,
                peripheral_right = state.peripheral_right,
                location = state.location,
                orientation = state.orientation,
                request_id = state.request_id,
                version = turtle_version,
                updated_not_home = state.updated_not_home
            }
            -- Include session_id if it exists (turtle was previously initialized)
            if state.session_id then
                report_data.session_id = state.session_id
            end
            rednet.send(hub_id, report_data, 'turtle_report')  -- Use turtle_report protocol so hub receives it
            
            print("Initialization report sent to hub")
        else
            print("WARNING: Could not read hub_id")
        end
    else
        print("WARNING: Could not open /hub_id file")
    end
else
    print("WARNING: Rednet not opened, cannot send initialization report")
end


-- LAUNCH PROGRAMS AS SEPARATE THREADS
print("Launching threads...")
local report_id = multishell.launch({}, '/report.lua')
local receive_id = multishell.launch({}, '/message_receiver.lua')
local main_id = multishell.launch({}, '/turtle_main.lua')

if report_id then
    multishell.setTitle(report_id, 'report')
    print("Report thread launched: " .. report_id)
else
    print("ERROR: Failed to launch report.lua")
end

if receive_id then
    multishell.setTitle(receive_id, 'receive')
    print("Message receiver thread launched: " .. receive_id)
else
    print("ERROR: Failed to launch message_receiver.lua")
end

if main_id then
    multishell.setTitle(main_id, 'turtle_main')
    print("Turtle main thread launched: " .. main_id)
else
    print("ERROR: Failed to launch turtle_main.lua")
end

print("Turtle startup complete!")