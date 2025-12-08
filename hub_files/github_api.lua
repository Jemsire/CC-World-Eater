-- GitHub API Helper Module
-- Shared functions for interacting with GitHub API
-- Used by update scripts to avoid code duplication
-- Uses os.loadAPI() style - sets globals

-- Function to compare two semantic versions
-- Returns: -1 if v1 < v2, 0 if v1 == v2, 1 if v1 > v2, nil if invalid
-- DEV versions are considered "greater than" their release counterparts
-- because DEV = that version PLUS additional commits
-- e.g., 0.3.1-DEV > 0.3.1, but 0.3.2 > 0.3.1-DEV
function compare_versions(v1, v2)
    if not v1 or not v2 or type(v1) ~= "table" or type(v2) ~= "table" then
        return nil
    end
    
    -- Compare major
    if v1.major > v2.major then return 1 end
    if v1.major < v2.major then return -1 end
    
    -- Compare minor
    if v1.minor > v2.minor then return 1 end
    if v1.minor < v2.minor then return -1 end
    
    -- Compare hotfix
    if v1.hotfix > v2.hotfix then return 1 end
    if v1.hotfix < v2.hotfix then return -1 end
    
    -- If numeric versions are equal, compare dev status
    -- DEV versions are considered "greater than" release versions
    -- because DEV = that version + additional commits
    local v1_is_dev = v1.dev == true
    local v2_is_dev = v2.dev == true
    
    if v1_is_dev and not v2_is_dev then
        return 1   -- v1 is dev, v2 is release: v1 > v2 (dev has more commits)
    elseif not v1_is_dev and v2_is_dev then
        return -1  -- v1 is release, v2 is dev: v1 < v2 (dev has more commits)
    end
    
    return 0  -- Equal (both dev or both release)
end

-- Simple JSON parser for GitHub Trees API response
function parse_json_simple(json_str)
    -- Extract the tree array from the JSON response
    local tree_array = string.match(json_str, '"tree"%s*:%s*%[%s*(.*)%s*%]')
    if not tree_array then
        return nil
    end
    
    -- Parse objects in the array using regex to find path and type
    -- GitHub API returns "blob" for files and "tree" for directories
    local filtered = {}
    for obj_match in string.gmatch(tree_array, '{[^}]+}') do
        local path = string.match(obj_match, '"path"%s*:%s*"([^"]+)"')
        local obj_type = string.match(obj_match, '"type"%s*:%s*"([^"]+)"')
        if path and obj_type == "blob" then
            table.insert(filtered, path)
        end
    end
    
    return filtered
end

-- Get the latest release tag from GitHub releases API
function get_latest_release_tag(github_repo)
    -- Get the latest release tag from GitHub releases API
    local api_url = "https://api.github.com/repos/" .. github_repo .. "/releases/latest"
    local response = http.get(api_url, {
        ["Accept"] = "application/vnd.github.v3+json"
    })
    
    if not response then
        return nil
    end
    
    local content = response.readAll()
    response.close()
    
    -- Try to parse JSON
    local tag_name = nil
    if textutils and textutils.unserializeJSON then
        local json_data = textutils.unserializeJSON(content)
        if json_data and json_data.tag_name then
            tag_name = json_data.tag_name
        end
    else
        -- Simple regex fallback
        tag_name = string.match(content, '"tag_name"%s*:%s*"([^"]+)"')
    end
    
    return tag_name
end

-- Download file list from GitHub using API
function get_file_tree(github_repo, github_branch)
    -- Use GitHub Trees API to get recursive file listing
    local api_url = "https://api.github.com/repos/" .. github_repo .. "/git/trees/" .. github_branch .. "?recursive=1"
    
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
    
    return json_data.tree
end

-- Get the version from the latest GitHub release
function get_latest_release_version(github_repo)
    -- Get latest release tag
    local latest_tag = get_latest_release_tag(github_repo)
    if not latest_tag then
        return nil
    end
    
    -- Get version from the release tag's version.lua file
    local url = "https://raw.githubusercontent.com/" .. github_repo .. "/" .. latest_tag .. "/shared_files/version.lua"
    local response = http.get(url)
    if response then
        local content = response.readAll()
        response.close()
        local version_func = load(content)
        if version_func then
            local success, version = pcall(version_func)
            if success and version and type(version) == "table" then
                return version
            end
        end
    end
    return nil
end

