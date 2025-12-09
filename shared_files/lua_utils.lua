-- Lua Utilities API Module
-- Shared utility functions for Lua file operations, config management, and more
-- Used by install and update scripts to avoid code duplication
-- Uses os.loadAPI() style - sets globals

---==[ FILE LOADING ]==---

-- Load and execute a Lua file that returns a table
-- Returns: table on success, nil on failure
function load_file(path)
    if not fs.exists(path) then
        return nil
    end
    local file = fs.open(path, "r")
    if not file then
        return nil
    end
    local content = file.readAll()
    file.close()
    
    return load_string(content)
end

-- Load and execute a Lua string that returns a table
-- Returns: table on success, nil on failure
function load_string(content)
    if not content or content == "" then
        return nil
    end
    local func = load(content)
    if func then
        local success, result = pcall(func)
        if success and type(result) == "table" then
            return result
        end
    end
    return nil
end


---==[ CONFIG MANAGEMENT ]==---

-- Recursively merge tables, preserving old values while adding new keys
-- new_tbl: The new table structure (provides new keys with defaults)
-- old_tbl: The old table (provides existing user values to preserve)
-- replace_keys: Table of key names that should be replaced entirely, not merged
--               e.g., {dig_disallow = true, fuelnames = true}
-- Returns: Merged table
function merge_tables(new_tbl, old_tbl, replace_keys)
    replace_keys = replace_keys or {}
    
    if type(new_tbl) ~= "table" or type(old_tbl) ~= "table" then
        return new_tbl
    end
    
    local merged = {}
    
    -- Start with all keys from new table (ensures new options are included)
    for key, new_value in pairs(new_tbl) do
        local old_value = old_tbl[key]
        
        if old_value ~= nil then
            -- Key exists in both tables
            if type(new_value) == "table" and type(old_value) == "table" then
                -- Check if this key should be replaced entirely (not merged)
                if replace_keys[key] then
                    -- User's list/set replaces default entirely
                    merged[key] = old_value
                else
                    -- Recurse to merge nested tables
                    merged[key] = merge_tables(new_value, old_value, replace_keys)
                end
            else
                -- Use the old value (preserve user's setting)
                merged[key] = old_value
            end
        else
            -- New key that didn't exist in old table, use new default
            merged[key] = new_value
        end
    end
    
    return merged
end

-- Serialize a table to a valid Lua string
-- tbl: The table to serialize
-- indent: Current indentation (used internally for recursion)
-- Returns: Lua code string representing the table
function serialize_table(tbl, indent)
    indent = indent or ""
    local next_indent = indent .. "    "
    local lines = {}
    
    table.insert(lines, "{")
    
    -- Collect and sort keys for consistent output
    local keys = {}
    for k in pairs(tbl) do
        table.insert(keys, k)
    end
    table.sort(keys, function(a, b)
        -- Sort by type first (numbers before strings), then by value
        if type(a) ~= type(b) then
            return type(a) == "number"
        end
        return a < b
    end)
    
    for i, key in ipairs(keys) do
        local value = tbl[key]
        local key_str
        
        -- Format key
        if type(key) == "string" and key:match("^[%a_][%w_]*$") then
            key_str = key
        elseif type(key) == "string" then
            key_str = '["' .. key .. '"]'
        else
            key_str = "[" .. tostring(key) .. "]"
        end
        
        -- Format value
        local value_str
        if type(value) == "table" then
            value_str = serialize_table(value, next_indent)
        elseif type(value) == "string" then
            value_str = '"' .. value:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n') .. '"'
        elseif type(value) == "boolean" or type(value) == "number" then
            value_str = tostring(value)
        elseif value == nil then
            value_str = "nil"
        else
            value_str = '"' .. tostring(value) .. '"'
        end
        
        local comma = (i < #keys) and "," or ""
        table.insert(lines, next_indent .. key_str .. " = " .. value_str .. comma)
    end
    
    table.insert(lines, indent .. "}")
    return table.concat(lines, "\n")
end


---==[ VERSION UTILITIES ]==---

-- Format a version table as a string "MAJOR.MINOR.HOTFIX" or "MAJOR.MINOR.HOTFIX-DEV"
-- version: Table with major, minor, hotfix, and optional dev fields
-- Returns: Formatted string or nil if invalid
function format_version(version)
    if not version or type(version) ~= "table" then
        return nil
    end
    local version_str = string.format("%d.%d.%d", 
        version.major or 0, 
        version.minor or 0, 
        version.hotfix or 0
    )
    -- Add DEV suffix only if dev == true
    if version.dev == true then
        version_str = version_str .. "-DEV"
    end
    return version_str
end

-- Parse a version string into a table
-- str: Version string like "1.2.3" or "1.2.3-DEV"
-- Returns: Table with major, minor, hotfix, dev fields or nil if invalid
function parse_version(str)
    if not str or type(str) ~= "string" then
        return nil
    end
    
    -- Check for DEV suffix
    local is_dev = false
    local version_part = str
    if str:match("%-DEV$") then
        is_dev = true
        version_part = str:gsub("%-DEV$", "")
    end
    
    -- Parse major.minor.hotfix
    local major, minor, hotfix = version_part:match("^(%d+)%.(%d+)%.(%d+)$")
    if not major then
        -- Try major.minor format
        major, minor = version_part:match("^(%d+)%.(%d+)$")
        hotfix = "0"
    end
    if not major then
        -- Try just major format
        major = version_part:match("^(%d+)$")
        minor = "0"
        hotfix = "0"
    end
    
    if not major then
        return nil
    end
    
    return {
        major = tonumber(major),
        minor = tonumber(minor),
        hotfix = tonumber(hotfix),
        dev = is_dev,
        dev_suffix = is_dev and "-DEV" or nil
    }
end


---==[ FILE UTILITIES ]==---

-- Ensure parent directories exist for a given path
-- path: File path to ensure directories for
-- Returns: true on success, false on failure
function ensure_directory(path)
    local parent_dir = string.match(path, "^(.-)[^/\\]+$")
    if parent_dir and parent_dir ~= "" then
        if not fs.exists(parent_dir) then
            fs.makeDir(parent_dir)
        end
        return fs.exists(parent_dir)
    end
    return true
end

-- Copy a file from source to destination
-- src: Source file path
-- dest: Destination file path
-- Returns: true on success, false on failure
function copy_file(src, dest)
    if not fs.exists(src) then
        return false
    end
    
    -- Ensure destination directory exists
    if not ensure_directory(dest) then
        return false
    end
    
    local src_file = fs.open(src, "r")
    if not src_file then
        return false
    end
    
    local content = src_file.readAll()
    src_file.close()
    
    local dest_file = fs.open(dest, "w")
    if not dest_file then
        return false
    end
    
    dest_file.write(content)
    dest_file.close()
    
    return fs.exists(dest)
end

-- Check if a file exists
-- path: File path to check
-- Returns: true if exists, false otherwise
function file_exists(path)
    return fs.exists(path)
end

-- Read entire file contents
-- path: File path to read
-- Returns: File contents as string, or nil on failure
function read_file(path)
    if not fs.exists(path) then
        return nil
    end
    
    local file = fs.open(path, "r")
    if not file then
        return nil
    end
    
    local content = file.readAll()
    file.close()
    
    return content
end

-- Write content to a file (creates directories if needed)
-- path: File path to write
-- content: String content to write
-- Returns: true on success, false on failure
function write_file(path, content)
    -- Ensure parent directory exists
    if not ensure_directory(path) then
        return false
    end
    
    local file = fs.open(path, "w")
    if not file then
        return false
    end
    
    file.write(content)
    file.close()
    
    return fs.exists(path)
end

-- Delete a file
-- path: File path to delete
-- Returns: true on success, false on failure
function delete_file(path)
    if not fs.exists(path) then
        return true  -- Already doesn't exist
    end
    
    fs.delete(path)
    return not fs.exists(path)
end

-- Get file size
-- path: File path to check
-- Returns: Size in bytes, or nil if file doesn't exist
function file_size(path)
    if not fs.exists(path) then
        return nil
    end
    return fs.getSize(path)
end