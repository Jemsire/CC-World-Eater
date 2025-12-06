hub_id = ...

-- WORLD EATER: Check both disk and disk2 for turtle files
-- Try disk2 first (if dual-drive setup), then fall back to disk
local turtle_files_path = '/disk2/turtle_files'
if not fs.exists(turtle_files_path) then
    turtle_files_path = '/disk/turtle_files'
end

for _, filename in pairs(fs.list('/')) do
    if filename ~= 'rom' and filename ~= 'disk' and filename ~= 'disk2' and filename ~= 'openp' and filename ~= 'ppp' and filename ~= 'persistent' then
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

print("Linked")

sleep(1)
os.reboot()
