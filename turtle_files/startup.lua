-- SET LABEL
os.setComputerLabel('Turtle ' .. os.getComputerID())

-- INITIALIZE APIS
-- Load all APIs through init_apis.lua (handles all API loading)
loadfile('/init_apis.lua')()

-- Get references from API class (for compatibility, globals are also set)
local config = API.getConfig()
local state = API.getState()
local utilities = API.getUtilities()


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