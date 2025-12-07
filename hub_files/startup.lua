-- SET LABEL
os.setComputerLabel('Hub')

-- INITIALIZE APIS
-- Load all APIs through init_apis.lua (handles all API loading)
loadfile('/init_apis.lua')()

-- Get references from API class
local config = API.getConfig()
local state = API.getState()

-- Calculate disk drive location dynamically (1 block below hub computer)
-- Disk drive is always 1 block below the hub computer, not relative to hub_reference
if gps then
    local hub_x, hub_y, hub_z = gps.locate()
    if hub_x and hub_y and hub_z then
        -- Disk drive is 1 block below hub computer (only y coordinate changes)
        config.locations.disk_drive = {
            x = hub_x,
            y = hub_y - 1,
            z = hub_z,
            orientation = 'east'
        }
        print("Disk drive location set to: X=" .. hub_x .. ", Y=" .. (hub_y - 1) .. ", Z=" .. hub_z)
    else
        print("WARNING: Could not get GPS location. Disk drive location may be incorrect.")
    end
else
    print("WARNING: GPS not available. Disk drive location may be incorrect.")
end


-- IF UPDATED PRINT "UPDATED"
if fs.exists('/updated') then
    fs.delete('/updated')
    print('UPDATED')
    state.updated = true
end


-- LAUNCH PROGRAMS AS SEPARATE THREADS
-- Data thread must be launched first (handles all rednet communication)
multishell.launch({}, '/data_thread.lua')
multishell.launch({}, '/user_input.lua')
multishell.launch({}, '/report.lua')
multishell.launch({}, '/monitor.lua')
multishell.launch({}, '/events.lua')
multishell.launch({}, '/mine_manager.lua')
multishell.setTitle(2, 'data_thread')
multishell.setTitle(3, 'user')
multishell.setTitle(4, 'report')
multishell.setTitle(5, 'monitor')
multishell.setTitle(6, 'events')
multishell.setTitle(7, 'mine_manager')