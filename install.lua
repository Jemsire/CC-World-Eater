-- Bootstrap Installer for World Eater
-- Small installer that downloads everything from GitHub
-- Place this in pastebin, users run: pastebin get <CODE> install.lua

-- Configuration
local GITHUB_REPO = "Jemsire/CC-World-Eater"
local GITHUB_BRANCH = "main"  -- or "master"
local GITHUB_BASE = "https://raw.githubusercontent.com/" .. GITHUB_REPO .. "/" .. GITHUB_BRANCH

-- Drive assignments
local DRIVE_HUB = "disk"      -- Hub files go here
local DRIVE_TURTLE = "disk2"  -- Turtle/Pocket files go here (falls back to disk if only one drive)

-- Colors for output
local function printHeader(text)
    print("========================================")
    print("  " .. text)
    print("========================================")
end

local function printStep(step, text)
    print(string.format("[%d] %s", step, text))
end

-- Detect system type
local function detect_system_type()
    -- Check if we have turtle API
    if turtle then
        -- Check for chunky peripheral
        local left = peripheral.getType("left")
        local right = peripheral.getType("right")
        if left == "chunkLoader" or right == "chunkLoader" or 
           left == "chunky" or right == "chunky" then
            return "chunky"
        else
            return "turtle"
        end
    end
    
    -- Check if we're a pocket computer
    if pocket then
        return "pocket"
    end
    
    -- Must be hub computer
    return "hub"
end

-- Detect available disk drives
local function detect_drives()
    local drives = {}
    
    -- Check for disk (always check this first)
    if peripheral.getType("top") == "drive" then
        drives.hub = "top"
    elseif peripheral.getType("bottom") == "drive" then
        drives.hub = "bottom"
    elseif peripheral.getType("left") == "drive" then
        drives.hub = "left"
    elseif peripheral.getType("right") == "drive" then
        drives.hub = "right"
    elseif peripheral.getType("back") == "drive" then
        drives.hub = "back"
    elseif peripheral.getType("front") == "drive" then
        drives.hub = "front"
    end
    
    -- Check for disk2 (second drive)
    -- Note: CC:Tweaked uses disk, disk2, etc. for multiple drives
    -- We'll check if we can access disk2
    if fs.exists("/disk2") then
        drives.turtle = "disk2"
    elseif drives.hub then
        -- Fallback to same drive if only one available
        drives.turtle = drives.hub
    end
    
    return drives
end

-- Download file from GitHub
local function download_file(url, filepath)
    print("  Downloading: " .. filepath)
    
    -- Try to use http API
    if http then
        local response = http.get(url)
        if not response then
            return false, "HTTP request failed"
        end
        
        local content = response.readAll()
        response.close()
        
        -- Create directory if needed
        local dir = string.match(filepath, "^(.-)[^/\\]*$")
        if dir and dir ~= "" then
            fs.makeDir(dir)
        end
        
        -- Write file
        local file = fs.open(filepath, "w")
        if not file then
            return false, "Failed to open file for writing"
        end
        file.write(content)
        file.close()
        
        return true
    else
        return false, "HTTP API not available"
    end
end

-- Download manifest from GitHub
local function download_manifest()
    printStep(1, "Downloading file manifest...")
    
    local manifest_url = GITHUB_BASE .. "/manifest.json"
    local manifest_path = "/manifest.json"
    
    local success, err = download_file(manifest_url, manifest_path)
    if not success then
        error("Failed to download manifest: " .. (err or "unknown error"))
    end
    
    -- Read and parse manifest
    local file = fs.open(manifest_path, "r")
    if not file then
        error("Failed to read manifest file")
    end
    
    local content = file.readAll()
    file.close()
    
    -- Parse JSON (simple parser for basic JSON)
    -- Note: This is a simplified parser, may need proper JSON library
    local manifest = {}
    -- TODO: Add JSON parsing or use textutils.unserializeJSON if available
    
    -- For now, we'll use a hardcoded file list
    -- In production, parse the manifest.json properly
    return manifest
end

-- Get file list based on system type
local function get_file_list(system_type)
    local files = {}
    
    if system_type == "hub" then
        -- Hub files go to disk
        files = {
            "hub_files/startup.lua",
            "hub_files/config.lua",
            "hub_files/state.lua",
            "hub_files/utilities.lua",
            "hub_files/events.lua",
            "hub_files/monitor.lua",
            "hub_files/report.lua",
            "hub_files/user_input.lua",
            "hub_files/mine_manager.lua",
            "hub.lua",
        }
    elseif system_type == "turtle" or system_type == "chunky" then
        -- Turtle files go to disk2 (or disk if only one drive)
        files = {
            "turtle_files/startup.lua",
            "turtle_files/config.lua",
            "turtle_files/state.lua",
            "turtle_files/utilities.lua",
            "turtle_files/actions.lua",
            "turtle_files/message_receiver.lua",
            "turtle_files/report.lua",
            "turtle_files/turtle_main.lua",
            "turtle.lua",
        }
    elseif system_type == "pocket" then
        -- Pocket files
        files = {
            "pocket_files/startup.lua",
            "pocket_files/info.lua",
            "pocket_files/report.lua",
            "pocket_files/user.lua",
            "pocket.lua",
        }
    end
    
    return files
end

-- Install files
local function install_files(system_type, drives)
    printStep(2, "Installing files...")
    
    local base_url = GITHUB_BASE
    local has_dual_drive = drives.turtle and drives.turtle ~= drives.hub
    
    -- If hub computer with dual drives, install ALL files (hub + turtle + pocket)
    -- Otherwise, install only files for detected system type
    local file_sets = {}
    
    if system_type == "hub" and has_dual_drive then
        -- Hub with dual drives: install everything
        print("  Dual-drive detected: Installing hub, turtle, and pocket files...")
        file_sets = {
            {files = get_file_list("hub"), drive = "/disk"},
            {files = get_file_list("turtle"), drive = "/disk2"},
            {files = get_file_list("pocket"), drive = "/disk2"}
        }
    else
        -- Single drive or specific system: install only that system's files
        local files = get_file_list(system_type)
        local drive_path = "/disk"
        
        if system_type == "hub" then
            drive_path = "/disk"
        elseif drives.turtle and drives.turtle ~= drives.hub then
            drive_path = "/disk2"
        else
            drive_path = "/disk"
        end
        
        file_sets = {{files = files, drive = drive_path}}
    end
    
    -- Install all file sets
    for _, file_set in ipairs(file_sets) do
        for _, filepath in ipairs(file_set.files) do
            local url = base_url .. "/" .. filepath
            local dest_path = file_set.drive .. "/" .. filepath
            
            local success, err = download_file(url, dest_path)
            if not success then
                print("  ERROR: Failed to download " .. filepath .. ": " .. (err or "unknown"))
                -- Continue with other files
            end
        end
    end
    
    print("  Installation complete!")
end

-- Validate installation
local function validate_installation(system_type, drives)
    printStep(3, "Validating installation...")
    
    local has_dual_drive = drives.turtle and drives.turtle ~= drives.hub
    
    -- If hub computer with dual drives, validate ALL files
    -- Otherwise, validate only files for detected system type
    local file_sets = {}
    
    if system_type == "hub" and has_dual_drive then
        -- Hub with dual drives: validate everything
        file_sets = {
            {files = get_file_list("hub"), drive = "/disk"},
            {files = get_file_list("turtle"), drive = "/disk2"},
            {files = get_file_list("pocket"), drive = "/disk2"}
        }
    else
        -- Single drive or specific system: validate only that system's files
        local files = get_file_list(system_type)
        local drive_path = "/disk"
        
        if system_type == "hub" then
            drive_path = "/disk"
        elseif drives.turtle and drives.turtle ~= drives.hub then
            drive_path = "/disk2"
        else
            drive_path = "/disk"
        end
        
        file_sets = {{files = files, drive = drive_path}}
    end
    
    local missing = {}
    for _, file_set in ipairs(file_sets) do
        for _, filepath in ipairs(file_set.files) do
            local full_path = file_set.drive .. "/" .. filepath
            if not fs.exists(full_path) then
                table.insert(missing, filepath .. " (on " .. file_set.drive .. ")")
            end
        end
    end
    
    if #missing > 0 then
        print("  WARNING: Missing files:")
        for _, file in ipairs(missing) do
            print("    - " .. file)
        end
        return false
    end
    
    print("  All files present!")
    return true
end

-- Update config file with hub reference coordinates
local function update_config_file(config_path, x, y, z)
    -- Read existing config file
    local config_file = fs.open(config_path, "r")
    if not config_file then
        return false, "Could not read config file"
    end
    
    local config_content = config_file.readAll()
    config_file.close()
    
    -- Replace hub_reference line
    -- Pattern: hub_reference = {x = NUMBER, y = NUMBER, z = NUMBER}
    local pattern = "hub_reference%s*=%s*{%s*x%s*=%s*[%d%.%-]+%s*,%s*y%s*=%s*[%d%.%-]+%s*,%s*z%s*=%s*[%d%.%-]+%s*}"
    local replacement = string.format("hub_reference = {x = %d, y = %d, z = %d}", x, y, z)
    
    local updated_content = string.gsub(config_content, pattern, replacement)
    
    -- If pattern didn't match, try to find and replace the line manually
    if updated_content == config_content then
        -- Try finding the line and replacing it
        local lines = {}
        for line in string.gmatch(config_content, "[^\r\n]+") do
            if string.match(line, "hub_reference%s*=") then
                table.insert(lines, replacement)
            else
                table.insert(lines, line)
            end
        end
        updated_content = table.concat(lines, "\n")
    end
    
    -- Write updated config back
    local write_file = fs.open(config_path, "w")
    if not write_file then
        return false, "Could not write config file"
    end
    
    write_file.write(updated_content)
    write_file.close()
    
    return true
end

-- Setup wizard for hub
local function setup_wizard(drive_path)
    printHeader("Setup Wizard")
    print("Please enter your hub reference coordinates:")
    print("(This is the central reference point for your setup)")
    print("(The hub computer must be within 8 blocks north/south of this point)")
    print("")
    
    print("X coordinate: ")
    local x = tonumber(read())
    if not x then
        print("Invalid X coordinate. Setup cancelled.")
        return false
    end
    
    print("Y coordinate (surface level): ")
    local y = tonumber(read())
    if not y then
        print("Invalid Y coordinate. Setup cancelled.")
        return false
    end
    
    print("Z coordinate: ")
    local z = tonumber(read())
    if not z then
        print("Invalid Z coordinate. Setup cancelled.")
        return false
    end
    
    -- Update config file
    local config_path = drive_path .. "/hub_files/config.lua"
    local success, err = update_config_file(config_path, x, y, z)
    
    if success then
        print("")
        print("✓ Configuration saved successfully!")
        print(string.format("  Hub reference set to: X=%d, Y=%d, Z=%d", x, y, z))
        return true
    else
        print("")
        print("✗ Error saving configuration: " .. (err or "unknown error"))
        print("  You may need to manually edit " .. config_path)
        return false
    end
end

-- Main installation function
local function main()
    printHeader("World Eater Installer")
    
    -- Detect system
    local system_type = detect_system_type()
    print("Detected system type: " .. system_type)
    
    -- Detect drives
    local drives = detect_drives()
    if not drives.hub then
        error("No disk drive found! Please attach a disk drive.")
    end
    
    print("Detected drives:")
    print("  Hub drive: " .. (drives.hub or "none"))
    print("  Turtle drive: " .. (drives.turtle or "none (using hub drive)"))
    
    -- Check if dual-drive setup
    local has_dual_drive = drives.turtle and drives.turtle ~= drives.hub
    if system_type == "hub" and has_dual_drive then
        print("")
        print("✓ Dual-drive setup detected!")
        print("  Will install hub files on disk1 and turtle/pocket files on disk2")
    elseif system_type == "hub" and not has_dual_drive then
        print("")
        print("⚠ Single-drive setup detected")
        print("  Only hub files will be installed (turtle/pocket files need disk2)")
    end
    
    -- Check for HTTP API
    if not http then
        error("HTTP API not available! This installer requires internet access.")
    end
    
    -- Download and install
    local manifest = download_manifest()
    install_files(system_type, drives)
    
    -- Validate
    if not validate_installation(system_type, drives) then
        print("WARNING: Some files may be missing. Installation may be incomplete.")
    end
    
    -- Setup wizard for hub
    if system_type == "hub" then
        print("")
        print("Run setup wizard? (y/n): ")
        local answer = read()
        if answer:lower() == "y" then
            local drive_path = "/disk"
            setup_wizard(drive_path)
        end
    end
    
    printHeader("Installation Complete!")
    print("Next steps:")
    if system_type == "hub" then
        print("  1. Run setup wizard to configure hub reference coordinates")
        print("     (Or manually edit disk/hub_files/config.lua)")
        print("  2. Run: disk/hub.lua")
    elseif system_type == "turtle" or system_type == "chunky" then
        print("  1. Run: disk/turtle.lua <hub_id>")
        print("  2. Enter hub computer ID when prompted")
    elseif system_type == "pocket" then
        print("  1. Run: disk/pocket.lua")
    end
end

-- Run installer
main()
