-- WORLD EATER: Hub startup script
-- Handles loading hub files from disk (drive 1)
-- Turtle/pocket files are on disk2 (if dual-drive setup)

if fs.exists('/disk/hub_files/session_id') then
    fs.delete('/disk/hub_files/session_id')
end
if fs.exists('/session_id') then
    fs.copy('/session_id', '/disk/hub_files/session_id')
end
if fs.exists('/disk/hub_files/mine') then
    fs.delete('/disk/hub_files/mine')
end
if fs.exists('/mine') then
    fs.copy('/mine', '/disk/hub_files/mine')
end

for _, filename in pairs(fs.list('/')) do
    if filename ~= 'rom' and filename ~= 'disk' and filename ~= 'disk2' and filename ~= 'openp' and filename ~= 'ppp' and filename ~= 'persistent' then
        fs.delete(filename)
    end
end
for _, filename in pairs(fs.list('/disk/hub_files')) do
    fs.copy('/disk/hub_files/' .. filename, '/' .. filename)
end
os.reboot()
