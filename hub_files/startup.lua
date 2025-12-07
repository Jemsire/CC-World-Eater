-- SET LABEL
os.setComputerLabel('Hub')

-- INITIALIZE APIS
-- Use loadfile() to load APIs
-- APIs are already in /apis/ folder (copied by hub.lua)
loadfile('config.lua')()
-- Create config table to reference globals from config.lua (for compatibility with code that uses config.*)
config = {
    locations = locations,
    use_chunky_turtles = use_chunky_turtles,
    fuel_padding = fuel_padding,
    fuel_per_unit = fuel_per_unit,
    turtle_timeout = turtle_timeout,
    pocket_timeout = pocket_timeout,
    task_timeout = task_timeout,
    dig_disallow = dig_disallow,
    paths = paths,
    mining_turtle_locations = mining_turtle_locations,
    chunky_turtle_locations = chunky_turtle_locations,
    gravitynames = gravitynames,
    orenames = orenames,
    blocktags = blocktags,
    fuelnames = fuelnames,
    monitor_max_zoom_level = monitor_max_zoom_level,
    default_monitor_zoom_level = default_monitor_zoom_level,
    default_monitor_location = default_monitor_location,
    hub_reference = hub_reference,
    mining_center = mining_center,
    bedrock_level = bedrock_level,
    mining_radius = mining_radius,
    mining_area = mining_area,
    mine_entrance = mine_entrance,
    c = c
}
loadfile('state.lua')()
utilities = loadfile('apis/utilities.lua')()
loadfile('block_management.lua')()
loadfile('turtle_assignment.lua')()
loadfile('version_management.lua')()
loadfile('task_management.lua')()
loadfile('user_commands.lua')()
loadfile('state_machine.lua')()

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