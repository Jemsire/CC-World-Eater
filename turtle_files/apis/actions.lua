-- ============================================
-- Actions - Main Coordinator
-- Loads modules and provides action interface
-- ============================================

-- Modules are loaded by startup.lua into /apis/
-- They are already available as global functions

-- Actions table for turtle_main.lua
-- Note: Functions should be available as globals after os.loadAPI
-- Check if initialize exists, if not try to get it from turtle_utilities table
local initialize_func = nil

-- Try to get initialize function from various sources
if type(initialize) == "function" then
    initialize_func = initialize
    print("[DEBUG] Found initialize as global function")
elseif turtle_utilities and type(turtle_utilities.initialize) == "function" then
    initialize_func = turtle_utilities.initialize
    print("[DEBUG] Found initialize in turtle_utilities table")
else
    print("ERROR: initialize function not found!")
    print("  - Global 'initialize': " .. tostring(initialize) .. " (type: " .. type(initialize) .. ")")
    print("  - turtle_utilities table exists: " .. tostring(turtle_utilities ~= nil))
    if turtle_utilities then
        print("  - turtle_utilities.initialize: " .. tostring(turtle_utilities.initialize) .. " (type: " .. type(turtle_utilities.initialize) .. ")")
    end
end

-- Create actions table directly in global scope to avoid os.loadAPI wrapper conflict
-- os.loadAPI wraps this file in a table called 'actions', so we need to use _G.actions directly
_G.actions = {
    -- Movement
    up = up,
    forward = forward,
    down = down,
    back = back,
    left = left,
    right = right,
    go = go,
    face = face,
    follow_route = follow_route,
    go_to = go_to,
    go_to_axis = go_to_axis,
    go_route = go_route,
    
    -- Navigation
    go_to_home = go_to_home,
    go_to_home_exit = go_to_home_exit,
    go_to_item_drop = go_to_item_drop,
    go_to_refuel = go_to_refuel,
    go_to_disk = go_to_disk,
    go_to_waiting_room = go_to_waiting_room,
    go_to_mine_enter = go_to_mine_enter,
    go_to_mine_exit = go_to_mine_exit,
    go_to_block = go_to_block,
    go_to_block_offset = go_to_block_offset,
    follow_mining_turtle = follow_mining_turtle,
    fastest_route = fastest_route,
    
    -- Detection
    detect_ore = detect_ore,
    scan = scan,
    detect_bedrock = detect_bedrock,
    safedig = safedig,
    clear_gravity_blocks = clear_gravity_blocks,
    
    -- Item Management
    dump_items = dump_items,
    dump = dump,
    prepare = prepare,
    
    -- Mining
    find_path_around_obstacle = find_path_around_obstacle,
    mine_column_down = mine_column_down,
    mine_column_up = mine_column_up,
    mine_to_bedrock = mine_to_bedrock,
    
    -- Utilities
    calibrate = calibrate,
    initialize = initialize_func,  -- Use the found function (will be nil if not found, which will cause error - that's intentional)
    getcwd = getcwd,
    pass = pass,
    digblock = digblock,
    delay = delay,
}

-- Also create local reference for convenience (but _G.actions is the real one)
actions = _G.actions

-- Debug: Verify initialize is in the table and show all keys
if _G.actions.initialize then
    print("[DEBUG] _G.actions.initialize is set: " .. tostring(type(_G.actions.initialize)) .. " - SUCCESS")
else
    print("[DEBUG] ERROR: _G.actions.initialize is NOT set in actions table!")
    print("[DEBUG] initialize_func was: " .. tostring(initialize_func) .. " (type: " .. type(initialize_func) .. ")")
end

-- Debug: Show all keys in _G.actions at startup
local action_keys = {}
for k, v in pairs(_G.actions) do
    table.insert(action_keys, k)
end
print("[DEBUG] _G.actions keys at startup: " .. table.concat(action_keys, ", "))
print("[DEBUG] Total actions: " .. tostring(#action_keys))
