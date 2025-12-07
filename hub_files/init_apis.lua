-- ============================================
-- Shared API Initialization
-- Load this file at the start of any thread that needs APIs
-- ============================================

-- Load config if not already loaded
if not config then
    loadfile('apis/config.lua')()
    -- Create config table to reference globals from config.lua
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
end

-- Load state if not already loaded
if not state then
    loadfile('apis/state.lua')()
end

-- Load utilities if not already loaded
if not utilities then
    utilities = loadfile('apis/utilities.lua')()
end

-- Create a global API registry for easy access
-- This allows code to access APIs through a single object
if not apis then
    apis = {}
    apis.utilities = utilities
    -- Other APIs can be added here as needed
end

