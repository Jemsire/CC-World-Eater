-- SET LABEL
os.setComputerLabel('Turtle ' .. os.getComputerID())

print("Starting turtle initialization...")

-- INITIALIZE APIS
-- Load all APIs through init_apis.lua (handles all API loading)
print("Loading APIs...")
local init_func = loadfile('/init_apis.lua')
if not init_func then
    error("Failed to load /init_apis.lua - file not found or cannot be read")
end

local success, err = pcall(init_func)
if not success then
    print("ERROR: Failed to initialize APIs: " .. tostring(err))
    error("API initialization failed: " .. tostring(err))
end

print("APIs loaded successfully")

-- Get references from API class (for compatibility, globals are also set)
local config = API.getConfig()
local state = API.getState()
local utilities = API.getUtilities()

if not config or not state or not utilities then
    error("Failed to get API references - config: " .. tostring(config) .. ", state: " .. tostring(state) .. ", utilities: " .. tostring(utilities))
end

print("API references obtained")


-- OPEN REDNET
print("Opening rednet...")
local rednet_opened = false
for _, side in pairs({'back', 'top', 'left', 'right'}) do
    if peripheral.getType(side) == 'modem' then
        rednet.open(side)
        rednet_opened = true
        print("Rednet opened on side: " .. side)
        break
    end
end
if not rednet_opened then
    print("WARNING: No modem found, rednet not opened")
end


-- IF UPDATED PRINT "UPDATED"
if fs.exists('/updated') then
    fs.delete('/updated')
    print('UPDATED')
    state.updated_not_home = true
end


-- LAUNCH PROGRAMS AS SEPARATE THREADS
print("Launching threads...")
local report_id = multishell.launch({}, '/report.lua')
local receive_id = multishell.launch({}, '/message_receiver.lua')
local main_id = multishell.launch({}, '/turtle_main.lua')

if report_id then
    multishell.setTitle(report_id, 'report')
    print("Report thread launched: " .. report_id)
else
    print("ERROR: Failed to launch report.lua")
end

if receive_id then
    multishell.setTitle(receive_id, 'receive')
    print("Message receiver thread launched: " .. receive_id)
else
    print("ERROR: Failed to launch message_receiver.lua")
end

if main_id then
    multishell.setTitle(main_id, 'turtle_main')
    print("Turtle main thread launched: " .. main_id)
else
    print("ERROR: Failed to launch turtle_main.lua")
end

print("Turtle startup complete!")