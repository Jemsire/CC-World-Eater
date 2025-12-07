-- ============================================
-- Actions - Main Coordinator
-- Loads modules and provides action interface
-- ============================================

-- Modules are loaded by startup.lua into /apis/
-- They are already available as global functions

-- Actions table for turtle_main.lua
actions = {
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
    initialize = initialize,
    getcwd = getcwd,
    pass = pass,
    digblock = digblock,
    delay = delay,
}
