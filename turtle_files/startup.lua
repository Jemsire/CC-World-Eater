-- SET LABEL
os.setComputerLabel('Turtle ' .. os.getComputerID())

-- Load APIs in dependency order
os.loadAPI('/apis/utilities.lua')        -- Base utilities (inf, str_xyz, distance, in_area, etc.)
os.loadAPI('/apis/config.lua')          -- Configuration
os.loadAPI('/apis/state.lua')           -- State management
os.loadAPI('/apis/movement.lua')        -- Basic movement functions (up, down, forward, back, go, face, etc.)
os.loadAPI('/apis/detection.lua')       -- Detection functions (detect_ore, scan, safedig, etc.)
os.loadAPI('/apis/navigation.lua')      -- Navigation functions (go_to_home, go_to_block, etc.)
os.loadAPI('/apis/item_management.lua') -- Item management (dump, prepare, etc.)
os.loadAPI('/apis/mining.lua')          -- Mining functions (mine_to_bedrock, etc.)
os.loadAPI('/apis/turtle_utilities.lua') -- Turtle utilities (calibrate, initialize, etc.)
-- Load actions.lua directly (not via os.loadAPI) to avoid wrapper table conflicts
dofile('/apis/actions.lua')


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
    state.updated_not_home = true
end


-- LAUNCH PROGRAMS AS SEPARATE THREADS
multishell.launch({}, '/report.lua')
multishell.launch({}, '/message_receiver.lua')
multishell.launch({}, '/turtle_main.lua')
multishell.setTitle(2, 'report')
multishell.setTitle(3, 'receive')
multishell.setTitle(4, 'turtle_main')