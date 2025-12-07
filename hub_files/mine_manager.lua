-- ============================================
-- Mine Manager - Main Coordinator
-- Loads modules and coordinates mining operations
-- ============================================

-- Load all APIs through init_apis.lua (handles all API loading)
loadfile('/init_apis.lua')()

-- Verify command_turtles is loaded
if not command_turtles then
    error("command_turtles function not loaded! Check that state_machine.lua is loading correctly.")
end

-- Get references from API class
local state = API.getState()
local utilities = API.getUtilities()

-- Create convenience variables
inf = utilities.inf
str_xyz = utilities.str_xyz

function main()
    -- INCREASE SESSION ID BY ONE
    if fs.exists('/session_id') then
        session_id = tonumber(fs.open('/session_id', 'r').readAll()) + 1
    else
        session_id = 1
    end
    local file = fs.open('/session_id', 'w')
    file.write(session_id)
    file.close()
    
    -- LOAD MINE INTO MEMORY
    local success, err = pcall(load_mine)
    if not success then
        print("ERROR: Failed to load mine: " .. tostring(err))
        error("Failed to load mine: " .. tostring(err))
    end
    
    -- Verify mine was loaded
    local state_refresh = API.getState()
    if not state_refresh.mine and not state_refresh.mined_blocks then
        print("WARNING: load_mine() completed but state.mine and state.mined_blocks are not set!")
        -- Force set state.mine to allow monitor to proceed
        API.setStateValue('mine', true)
        API.setStateValue('mined_blocks', {})
    end
    
    -- Find the closest unmined block
    gen_next_block()
    
    -- REBOOT ALL TURTLES ON HUB RESTART
    -- When hub restarts, it gets a new session_id, so all turtles need to reboot to re-initialize
    -- Wait for turtles to report, then reboot all of them
    print('Hub restarted - will reboot all turtles to re-initialize with new session_id...')
    API.setStateValue('check_initialized_pending', true)
    API.setStateValue('check_initialized_wait', 0)
    
    -- DEV: Check if hub version has DEV suffix - if so, force update all turtles
    local hub_version = get_hub_version()
    if hub_version and is_dev_version(hub_version) then
        print('DEV: Hub version has -DEV suffix. Will force update all turtles...')
        -- Wait a bit for turtles to report, then queue them for force update
        API.setStateValue('dev_force_update_pending', true)
        API.setStateValue('dev_force_update_wait', 0)
    end
    
    while true do
        -- Reboot all turtles on hub restart (hub restart scenario)
        local state_refresh = API.getState()
        if state_refresh.check_initialized_pending then
            local wait_count = (state_refresh.check_initialized_wait or 0) + 1
            API.setStateValue('check_initialized_wait', wait_count)
            -- Wait 3 seconds (30 cycles at 0.1s each) for turtles to report
            if wait_count >= 30 then
                reboot_all_turtles()
                API.setStateValue('check_initialized_pending', false)
                API.setStateValue('check_initialized_wait', nil)
            end
        end
        
        -- DEV: Handle force update after waiting for turtles to report
        state_refresh = API.getState()
        if state_refresh.dev_force_update_pending then
            local wait_count = (state_refresh.dev_force_update_wait or 0) + 1
            API.setStateValue('dev_force_update_wait', wait_count)
            -- Wait 5 seconds (50 cycles at 0.1s each) for turtles to report
            if wait_count >= 50 then
                print('DEV: Force updating all turtles...')
                local turtle_list = {}
                for _, turtle in pairs(state_refresh.turtles) do
                    if turtle.data then
                        table.insert(turtle_list, turtle)
                    end
                end
                if #turtle_list > 0 then
                    queue_turtles_for_update(turtle_list, false, true)  -- force_update = true
                else
                    print('DEV: No turtles found. Will check again in 5 seconds...')
                    API.setStateValue('dev_force_update_wait', 0)  -- Reset counter to check again
                end
                API.setStateValue('dev_force_update_pending', false)
                API.setStateValue('dev_force_update_wait', nil)
            end
        end
        
        user_input()         -- PROCESS USER INPUT
        command_turtles()    -- COMMAND TURTLES
        sleep(0.1)           -- DELAY 0.1 SECONDS
    end
end


main()
