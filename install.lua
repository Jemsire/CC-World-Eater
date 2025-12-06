-- Bootstrap Installer for World Eater
-- Small installer that downloads everything from GitHub
-- Place this in pastebin, users run: pastebin get <CODE> install.lua

-- Configuration
local GITHUB_REPO = "Jemsire/CC-World-Eater"
local GITHUB_BRANCH = "main"  -- or "master"
local GITHUB_BASE = "https://raw.githubusercontent.com/" .. GITHUB_REPO .. "/" .. GITHUB_BRANCH

-- Drive assignment
local DRIVE_PATH = "/disk"  -- All files go on single drive

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

-- Check for disk drive
local function check_drive()
    if not fs.exists("/disk") then
        error("No disk drive found! Please attach a disk drive.")
    end
    return "/disk"
end

-- Download file from GitHub
local function download_file(url, filepath)
    print("  Downloading: " .. filepath)
    
    -- Yield to prevent "too long without yielding" error
    os.queueEvent("yield")
    os.pullEvent("yield")
    
    -- Try to use http API
    if http then
        local response = http.get(url)
        if not response then
            return false, "HTTP request failed"
        end
        
        -- Read content in chunks to avoid timeout
        local content = ""
        while true do
            local chunk = response.read(8192)  -- Read 8KB at a time
            if not chunk then break end
            content = content .. chunk
            -- Yield periodically during large downloads
            if #content % 32768 == 0 then
                os.queueEvent("yield")
                os.pullEvent("yield")
            end
        end
        response.close()
        
        -- Create directory if needed
        local dir = string.match(filepath, "^(.-)[^/\\]*$")
        if dir and dir ~= "" then
            fs.makeDir(dir)
        end
        
        -- Write file (overwrites existing)
        local file = fs.open(filepath, "w")
        if not file then
            return false, "Failed to open file for writing"
        end
        file.write(content)
        file.close()
        
        -- Yield after file operations
        os.queueEvent("yield")
        os.pullEvent("yield")
        
        -- Verify file was written
        if not fs.exists(filepath) then
            return false, "File write verification failed"
        end
        
        return true
    else
        return false, "HTTP API not available"
    end
end

-- Simple JSON parser for GitHub Trees API response
-- GitHub API returns: {"sha":"...","url":"...","tree":[{"path":"...","type":"file",...},...]}
local function parse_json_simple(json_str)
    -- Extract the tree array from the JSON response
    -- Look for "tree":[...] pattern
    local tree_array = string.match(json_str, '"tree"%s*:%s*%[%s*(.*)%s*%]')
    if not tree_array then
        return nil
    end
    
    local result = {}
    
    -- Parse objects in the array using regex to find path and type
    -- This is a simplified parser that extracts "path":"value" and "type":"value" pairs
    for path_match in string.gmatch(tree_array, '"path"%s*:%s*"([^"]+)"') do
        -- Find the type for this path (look backwards/forwards in the object)
        -- For simplicity, we'll extract all paths and assume files (not directories)
        -- We'll filter directories by checking if path ends with /
        if not string.match(path_match, "/$") then
            table.insert(result, path_match)
        end
    end
    
    -- Now filter to only include files (check type field)
    local filtered = {}
    local i = 1
    for obj_match in string.gmatch(tree_array, '{[^}]+}') do
        local path = string.match(obj_match, '"path"%s*:%s*"([^"]+)"')
        local obj_type = string.match(obj_match, '"type"%s*:%s*"([^"]+)"')
        -- GitHub API returns "blob" for files and "tree" for directories
        if path and obj_type == "blob" then
            table.insert(filtered, path)
        end
        i = i + 1
    end
    
    return filtered
end

-- Download file list from GitHub using API (dynamic discovery)
local function download_file_list()
    -- Use GitHub Trees API to get recursive file listing
    -- Format: https://api.github.com/repos/OWNER/REPO/git/trees/BRANCH?recursive=1
    local api_url = "https://api.github.com/repos/" .. GITHUB_REPO .. "/git/trees/" .. GITHUB_BRANCH .. "?recursive=1"
    
    local response = http.get(api_url, {
        ["Accept"] = "application/vnd.github.v3+json"
    })
    
    if not response then
        return nil
    end
    
    -- Parse JSON response
    local content = response.readAll()
    response.close()
    
    -- Try textutils.unserializeJSON first (if available in CC:Tweaked)
    local json_data = nil
    if textutils and textutils.unserializeJSON then
        json_data = textutils.unserializeJSON(content)
    else
        -- Fallback to simple parser
        local file_paths = parse_json_simple(content)
        if file_paths then
            json_data = {tree = {}}
            for _, path in ipairs(file_paths) do
                table.insert(json_data.tree, {path = path, type = "file"})
            end
        end
    end
    
    if not json_data or not json_data.tree then
        return nil
    end
    
    -- Group files by folder prefix
    -- GitHub API returns "blob" for files and "tree" for directories
    local file_lists = {}
    for _, item in ipairs(json_data.tree) do
        if item.type == "blob" and item.path then
            local path = item.path
            -- Skip certain files
            if not string.match(path, "^%.git/") and 
               not string.match(path, "^%.github/") and
               path ~= "README.md" and
               path ~= ".gitignore" and
               path ~= "install.lua" then
                
                local folder, filename = string.match(path, "^(.-)/([^/]+)$")
                if folder and filename then
                    if not file_lists[folder] then
                        file_lists[folder] = {}
                    end
                    table.insert(file_lists[folder], path)
                elseif not string.match(path, "/") then
                    -- Root level file
                    if not file_lists["root"] then
                        file_lists["root"] = {}
                    end
                    table.insert(file_lists["root"], path)
                end
            end
        end
    end
    
    return file_lists
end

-- Get file list based on system type (with dynamic discovery fallback)
local function get_file_list(system_type)
    -- Try dynamic discovery first
    local file_lists = download_file_list()
    
    if file_lists then
        local files = {}
        
        if system_type == "hub" then
            -- Combine hub_files and root files
            if file_lists["hub_files"] then
                for _, file in ipairs(file_lists["hub_files"]) do
                    table.insert(files, file)
                end
            end
            if file_lists["root"] then
                for _, file in ipairs(file_lists["root"]) do
                    if string.match(file, "^hub%.lua$") then
                        table.insert(files, file)
                    end
                end
            end
        elseif system_type == "turtle" or system_type == "chunky" then
            if file_lists["turtle_files"] then
                for _, file in ipairs(file_lists["turtle_files"]) do
                    table.insert(files, file)
                end
            end
            if file_lists["root"] then
                for _, file in ipairs(file_lists["root"]) do
                    if string.match(file, "^turtle%.lua$") then
                        table.insert(files, file)
                    end
                end
            end
        elseif system_type == "pocket" then
            if file_lists["pocket_files"] then
                for _, file in ipairs(file_lists["pocket_files"]) do
                    table.insert(files, file)
                end
            end
            if file_lists["root"] then
                for _, file in ipairs(file_lists["root"]) do
                    if string.match(file, "^pocket%.lua$") then
                        table.insert(files, file)
                    end
                end
            end
        end
        
        if #files > 0 then
            print("  Using dynamic file list from GitHub")
            return files
        end
    end
    
    -- If we get here, GitHub API failed or returned no files
    error("Failed to retrieve file list from GitHub API. Please check your internet connection and try again.")
end

-- Install files
local function install_files(system_type, drive_path)
    printStep(2, "Installing files...")
    
    local base_url = GITHUB_BASE
    
    -- If hub computer, install ALL files (hub + turtle + pocket)
    -- Otherwise, install only files for detected system type
    local file_sets = {}
    
    if system_type == "hub" then
        -- Hub computer: install everything on single drive
        print("  Installing hub, turtle, and pocket files...")
        file_sets = {
            {files = get_file_list("hub"), drive = drive_path},
            {files = get_file_list("turtle"), drive = drive_path},
            {files = get_file_list("pocket"), drive = drive_path}
        }
    else
        -- Specific system: install only that system's files
        local files = get_file_list(system_type)
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
local function validate_installation(system_type, drive_path)
    printStep(3, "Validating installation...")
    
    -- If hub computer, validate ALL files
    -- Otherwise, validate only files for detected system type
    local file_sets = {}
    
    if system_type == "hub" then
        -- Hub computer: validate everything
        file_sets = {
            {files = get_file_list("hub"), drive = drive_path},
            {files = get_file_list("turtle"), drive = drive_path},
            {files = get_file_list("pocket"), drive = drive_path}
        }
    else
        -- Specific system: validate only that system's files
        local files = get_file_list(system_type)
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
    print("NOTE: hub_reference is the CENTER OF THE PREPARE AREA,")
    print("      not the hub computer location.")
    print("      The hub computer location will be detected via GPS at startup.")
    print("      The disk drive is always 1 block below the hub computer.")
    print("")
    
    local x, y, z
    
    -- Manual entry for hub_reference (center of prepare area)
    print("Please enter your hub reference coordinates:")
    print("(This is the CENTER OF THE PREPARE AREA - the central reference point)")
    print("(The hub computer must be within 8 blocks north/south of this point)")
    print("")
    
    print("X coordinate: ")
    x = tonumber(read())
    if not x then
        print("Invalid X coordinate. Setup cancelled.")
        return false
    end
    
    print("Y coordinate (surface level): ")
    y = tonumber(read())
    if not y then
        print("Invalid Y coordinate. Setup cancelled.")
        return false
    end
    
    print("Z coordinate: ")
    z = tonumber(read())
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
        print(string.format("  Hub reference (prepare area center): X=%d, Y=%d, Z=%d", x, y, z))
        print("")
        print("  Note: Disk drive location will be calculated automatically")
        print("        at startup using GPS (1 block below hub computer)")
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
    
    -- Check for disk drive
    local drive_path = check_drive()
    print("Disk drive: /disk")
    
    -- Check for HTTP API
    if not http then
        error("HTTP API not available! This installer requires internet access.")
    end
    
    -- Download and install
    install_files(system_type, drive_path)
    
    -- Validate
    if not validate_installation(system_type, drive_path) then
        print("WARNING: Some files may be missing. Installation may be incomplete.")
    end
    
    -- Setup wizard for hub
    if system_type == "hub" then
        print("")
        print("Run setup wizard? (y/n): ")
        local answer = read()
        if answer:lower() == "y" then
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
