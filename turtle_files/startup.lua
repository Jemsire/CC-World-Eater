-- SET LABEL
os.setComputerLabel('Turtle ' .. os.getComputerID())

-- INITIALIZE APIS
-- Use require() instead of deprecated os.loadAPI()
if fs.exists('/apis') then
    fs.delete('/apis')
end
fs.makeDir('/apis')
fs.copy('/config.lua', '/apis/config')
fs.copy('/state.lua', '/apis/state')
fs.copy('/utilities.lua', '/apis/basics')
require('/apis/config')
require('/apis/state')
require('/apis/basics')

-- Copy and load turtle action modules
fs.copy('/movement.lua', '/apis/movement')
fs.copy('/navigation.lua', '/apis/navigation')
fs.copy('/detection.lua', '/apis/detection')
fs.copy('/item_management.lua', '/apis/item_management')
fs.copy('/mining.lua', '/apis/mining')
fs.copy('/turtle_utilities.lua', '/apis/turtle_utilities')
require('/apis/movement')
require('/apis/navigation')
require('/apis/detection')
require('/apis/item_management')
require('/apis/mining')
require('/apis/turtle_utilities')

-- Load actions.lua (which provides the actions table)
fs.copy('/actions.lua', '/apis/actions')
require('/apis/actions')


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