-- ============================================
-- Mine Manager - Main Coordinator
-- Loads modules and coordinates mining operations
-- ============================================
-- Core APIs are loaded by startup.lua - this file loads additional modules it needs

-- Load API modules needed by mine_manager
os.loadAPI('/apis/block_management.lua')
os.loadAPI('/apis/turtle_assignment.lua')
os.loadAPI('/apis/task_management.lua')
os.loadAPI('/apis/user_commands.lua')
os.loadAPI('/apis/version_management.lua')
os.loadAPI('/apis/state_machine.lua')
os.loadAPI('/apis/utilities.lua')

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
    if not state.mine and not state.mined_blocks then
        print("WARNING: load_mine() completed but state.mine and state.mined_blocks are not set!")
        -- Force set state.mine to allow monitor to proceed
        state.mine = true
        state.mined_blocks = {}
    end
    
    -- Find the closest unmined block
    gen_next_block()
    
    -- Old simple method - no reboot on restart, just let turtles report and initialize naturally
    while true do
        user_input()         -- PROCESS USER INPUT
        command_turtles()    -- COMMAND TURTLES
        sleep(0.1)           -- DELAY 0.1 SECONDS
    end
end


main()
