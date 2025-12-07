-- SET LABEL
os.setComputerLabel('Hub')

-- INITIALIZE APIS
-- Use require() instead of deprecated os.loadAPI()
-- APIs are already in /apis/ folder (copied by hub.lua)
require('/apis/config')
require('/apis/state')
utilities = require('/apis/utilities')
require('/apis/block_management')
require('/apis/turtle_assignment')
require('/apis/version_management')
require('/apis/task_management')
require('/apis/user_commands')
require('/apis/state_machine')

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


-- OPEN REDNET
for _, side in pairs({'back', 'top', 'left', 'right'}) do
    if peripheral.getType(side) == 'modem' then
        rednet.open(side)
        break
    end
end


-- IF UPDATED PRINT "UPDATED"
if fs.exists('/updated') then
    fs.delete('/updated')
    print('UPDATED')
    state.updated = true
end


-- LAUNCH PROGRAMS AS SEPARATE THREADS
multishell.launch({}, '/user_input.lua')
multishell.launch({}, '/report.lua')
multishell.launch({}, '/monitor.lua')
multishell.launch({}, '/events.lua')
multishell.launch({}, '/mine_manager.lua')
multishell.setTitle(2, 'user')
multishell.setTitle(3, 'report')
multishell.setTitle(4, 'monitor')
multishell.setTitle(5, 'events')
multishell.setTitle(6, 'mine_manager')