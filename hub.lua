-- WORLD EATER: Hub startup script
-- Handles loading hub files from disk

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
    if filename ~= 'rom' and filename ~= 'disk' and filename ~= 'openp' and filename ~= 'ppp' and filename ~= 'persistent' then
        -- Skip all disk mount points (defensive - we only use /disk, but skip others if present)
        if not string.match(filename, '^disk%d*$') then
            local full_path = '/' .. filename
            -- Use pcall to handle errors gracefully (e.g., protected mount points)
            local success, err = pcall(fs.delete, full_path)
            if not success then
                -- Silently skip files that can't be deleted (mount points, etc.)
            end
        end
    end
end
for _, filename in pairs(fs.list('/disk/hub_files')) do
    fs.copy('/disk/hub_files/' .. filename, '/' .. filename)
end

-- Create update wrapper script in root so "update" command works
local update_wrapper = fs.open('/update', 'w')
if update_wrapper then
    update_wrapper.write([[
-- Update wrapper - runs the update script from disk
if fs.exists('/disk/hub_files/update') then
    shell.run('/disk/hub_files/update', ...)
elseif fs.exists('/update') then
    shell.run('/update', ...)
else
    print('Update script not found!')
    print('Run: disk/hub_files/update')
end
]])
    update_wrapper.close()
end

-- Create startup file to automatically run startup.lua on boot
-- (startup.lua is already copied from hub_files by this script)
local startup_file = fs.open('/startup', 'w')
if startup_file then
    startup_file.write([[
-- Auto-generated startup file for World Eater Hub
-- This file runs the hub's main startup script

if fs.exists('/startup.lua') then
    shell.run('/startup.lua')
else
    print('startup.lua not found - run hub.lua to initialize')
end
]])
    startup_file.close()
end

os.reboot()
