-- SET LABEL
os.setComputerLabel('Turtle ' .. os.getComputerID())

-- INITIALIZE APIS
-- Use loadfile() to load APIs
-- APIs are already in /apis/ folder (copied by turtle.lua)
loadfile('apis/config')()
-- Create config table to reference globals from config.lua (for compatibility with code that uses config.*)
-- Note: Most config is loaded from hub during initialization, this is just for turtle-specific defaults
config = {
    bedrock_level = bedrock_level
    -- Other config properties (locations, use_chunky_turtles, etc.) will be set by hub during initialization
}
loadfile('apis/state')()
utilities = loadfile('apis/utilities')()
loadfile('apis/movement')()
loadfile('apis/navigation')()
loadfile('apis/detection')()
loadfile('apis/item_management')()
loadfile('apis/mining')()
loadfile('apis/turtle_utilities')()
loadfile('apis/actions')()


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