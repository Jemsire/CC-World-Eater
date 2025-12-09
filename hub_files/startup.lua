-- SET LABEL
os.setComputerLabel('Hub')

-- INITIALIZE APIS
if fs.exists('/apis') then
    fs.delete('/apis')
end
fs.makeDir('/apis')
fs.copy('/globals.lua', '/apis/globals')
fs.copy('/lua_utils.lua', '/apis/lua_utils')
fs.copy('/config.lua', '/apis/config')
fs.copy('/state.lua', '/apis/state')
fs.copy('/github_api.lua', '/apis/github_api')
os.loadAPI('/apis/globals')
os.loadAPI('/apis/lua_utils')
os.loadAPI('/apis/config')
os.loadAPI('/apis/state')
os.loadAPI('/apis/github_api')



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
    state.updated = true
end


-- LAUNCH PROGRAMS AS SEPARATE THREADS
multishell.launch({}, '/user.lua')
multishell.launch({}, '/report.lua')
multishell.launch({}, '/monitor.lua')
multishell.launch({}, '/events.lua')
multishell.launch({}, '/worldeater.lua')
multishell.setTitle(2, 'user')
multishell.setTitle(3, 'report')
multishell.setTitle(4, 'monitor')
multishell.setTitle(5, 'events')
multishell.setTitle(6, 'worldeater')