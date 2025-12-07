-- SET LABEL
os.setComputerLabel('Turtle ' .. os.getComputerID())

-- INITIALIZE APIS
-- Use require() instead of deprecated os.loadAPI()
-- APIs are already in /apis/ folder (copied by turtle.lua)
require('/apis/config')
require('/apis/state')
utilities = require('/apis/utilities')
require('/apis/movement')
require('/apis/navigation')
require('/apis/detection')
require('/apis/item_management')
require('/apis/mining')
require('/apis/turtle_utilities')
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