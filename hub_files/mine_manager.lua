-- ============================================
-- Mine Manager - Main Coordinator
-- Loads modules and coordinates mining operations
-- ============================================

inf = basics.inf
str_xyz = basics.str_xyz

-- Load modules
os.loadAPI('/block_management')
os.loadAPI('/turtle_assignment')
os.loadAPI('/version_management')
os.loadAPI('/task_management')
os.loadAPI('/user_commands')
os.loadAPI('/state_machine')

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
    load_mine()
    
    -- Find the closest unmined block
    gen_next_block()
    
    -- DEV: Check if hub version has DEV suffix - if so, force update all turtles
    local hub_version = get_hub_version()
    if hub_version and is_dev_version(hub_version) then
        print('DEV: Hub version has -DEV suffix. Will force update all turtles...')
        -- Wait a bit for turtles to report, then queue them for force update
        state.dev_force_update_pending = true
        state.dev_force_update_wait = 0
    end
    
    while true do
        -- DEV: Handle force update after waiting for turtles to report
        if state.dev_force_update_pending then
            state.dev_force_update_wait = (state.dev_force_update_wait or 0) + 1
            -- Wait 5 seconds (50 cycles at 0.1s each) for turtles to report
            if state.dev_force_update_wait >= 50 then
                print('DEV: Force updating all turtles...')
                local turtle_list = {}
                for _, turtle in pairs(state.turtles) do
                    if turtle.data then
                        table.insert(turtle_list, turtle)
                    end
                end
                if #turtle_list > 0 then
                    queue_turtles_for_update(turtle_list, false, true)  -- force_update = true
                else
                    print('DEV: No turtles found. Will check again in 5 seconds...')
                    state.dev_force_update_wait = 0  -- Reset counter to check again
                end
                state.dev_force_update_pending = false
                state.dev_force_update_wait = nil
            end
        end
        
        user_input()         -- PROCESS USER INPUT
        command_turtles()    -- COMMAND TURTLES
        sleep(0.1)           -- DELAY 0.1 SECONDS
    end
end


main()
