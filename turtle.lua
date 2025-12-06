hub_id = ...

-- WORLD EATER: Load turtle files from disk
local turtle_files_path = '/disk/turtle_files'

for _, filename in pairs(fs.list('/')) do
    if filename ~= 'rom' and filename ~= 'disk' and filename ~= 'openp' and filename ~= 'ppp' and filename ~= 'persistent' then
        fs.delete(filename)
    end
end

for _, filename in pairs(fs.list(turtle_files_path)) do
    fs.copy(turtle_files_path .. '/' .. filename, '/' .. filename)
end

if not tonumber(hub_id) then
    print("Enter ID of Hub computer to link to: ")
    hub_id = tonumber(read())
    if hub_id == nil then
        error("Invalid ID")
    end
end

file = fs.open('/hub_id', 'w')
file.write(hub_id)
file.close()

-- Create update wrapper script in root so "update" command works
local update_wrapper = fs.open('/update', 'w')
if update_wrapper then
    update_wrapper.write([[
-- Update wrapper - runs the update script from disk
if fs.exists('/disk/turtle_files/update') then
    shell.run('/disk/turtle_files/update', ...)
elseif fs.exists('/update') then
    shell.run('/update', ...)
else
    print('Update script not found!')
    print('Run: disk/turtle_files/update')
end
]])
    update_wrapper.close()
end

-- Create startup file to automatically run startup.lua on boot
-- (startup.lua is already copied from turtle_files by this script)
local startup_file = fs.open('/startup', 'w')
if startup_file then
    startup_file.write([[
-- Auto-generated startup file for World Eater Turtle
-- This file runs the turtle's main startup script

if fs.exists('/startup.lua') then
    shell.run('/startup.lua')
else
    print('startup.lua not found - run turtle.lua to initialize')
end
]])
    startup_file.close()
end

print("Linked")

sleep(1)
os.reboot()
