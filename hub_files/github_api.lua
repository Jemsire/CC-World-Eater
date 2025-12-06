-- GitHub API Helper Module
-- Shared functions for interacting with GitHub API
-- Used by update scripts to avoid code duplication

local github_api = {}

-- Simple JSON parser for GitHub Trees API response
function github_api.parse_json_simple(json_str)
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

-- Download file list from GitHub using API
function github_api.get_file_tree(github_repo, github_branch)
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
        local file_paths = github_api.parse_json_simple(content)
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

return github_api

