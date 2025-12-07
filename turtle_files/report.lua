-- APIs are loaded by startup.lua - this file uses globals from there

-- CONTINUOUSLY BROADCAST STATUS REPORTS
hub_id = tonumber(fs.open('/hub_id', 'r').readAll())

-- Load version
local function get_turtle_version()
    local version_paths = {
        "/version.lua",
        "/disk/turtle_files/version.lua"
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

local turtle_version = get_turtle_version()

-- Load statistics from file on startup
if fs.exists('/statistics') then
    local file = fs.open('/statistics', 'r')
    if file then
        local stats_data = file.readAll()
        file.close()
        if stats_data and stats_data ~= '' then
            state.statistics = textutils.unserialize(stats_data)
        end
    end
end

-- Initialize statistics if not loaded
if not state.statistics then
    state.statistics = {
        blocks_mined = 0,
        ores_mined = 0,
        ore_counts = {}
    }
end

local save_counter = 0
local save_interval = 20  -- Save every 20 reports (10 seconds)

while true do

    state.item_count = 0
    state.empty_slot_count = 16
    for slot = 1, 16 do
        slot_item_count = turtle.getItemCount(slot)
        if slot_item_count > 0 then
            state.empty_slot_count = state.empty_slot_count - 1
            state.item_count = state.item_count + slot_item_count
        end
    end
    
    -- Save statistics periodically
    save_counter = save_counter + 1
    if save_counter >= save_interval then
        save_counter = 0
        if state.statistics then
            local file = fs.open('/statistics', 'w')
            if file then
                file.write(textutils.serialize(state.statistics))
                file.close()
            end
        end
    end
    
    -- DEBUG: Show what we're reporting
    local location_str = 'nil'
    if state.location then
        location_str = state.location.x .. ',' .. state.location.y .. ',' .. state.location.z
    end
    print('[DEBUG] Sending report - session_id: ' .. tostring(state.session_id) .. 
          ', request_id: ' .. tostring(state.request_id) .. 
          ', location: ' .. location_str .. 
          ', orientation: ' .. tostring(state.orientation) ..
          ', initialized: ' .. tostring(state.initialized) ..
          ', success: ' .. tostring(state.success) ..
          ', busy: ' .. tostring(state.busy))
    
    rednet.send(hub_id, {
            session_id       = state.session_id,
            request_id       = state.request_id,
            turtle_type      = state.type,
            peripheral_left  = state.peripheral_left,
            peripheral_right = state.peripheral_right,
            updated_not_home = state.updated_not_home,
            location         = state.location,
            orientation      = state.orientation,
            fuel_level       = turtle.getFuelLevel(),
            item_count       = state.item_count,
            empty_slot_count = state.empty_slot_count,
            distance         = state.distance,
            strip            = state.strip,
            success          = state.success,
            busy             = state.busy,
            statistics       = state.statistics,
            version          = turtle_version,
        }, 'turtle_report')
    
    sleep(1)  -- Reduced from 0.5s to 1s - still frequent enough for timeout detection (5s timeout)
    
end