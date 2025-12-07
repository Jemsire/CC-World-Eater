-- ============================================
-- Version Management Module
-- Handles version checking and update coordination
-- ============================================

function get_hub_version()
    -- Load version from version.lua file
    local version_paths = {
        "/version.lua",
        "/disk/hub_files/version.lua"
    }
    
    for _, path in ipairs(version_paths) do
        if fs.exists(path) then
            local version_file = fs.open(path, "r")
            if version_file then
                local version_code = version_file.readAll()
                version_file.close()
                local version_func = load(version_code)
                if version_func then
                    local success, version = pcall(version_func)
                    if success and version and type(version) == "table" then
                        return version
                    end
                end
            end
        end
    end
    return nil
end


function is_dev_version(version)
    -- Check if version has DEV suffix/flag
    if not version or type(version) ~= "table" then
        return false
    end
    -- Check for dev field (boolean) or dev_suffix field (string)
    return version.dev == true or (version.dev_suffix and version.dev_suffix == "-DEV")
end


function compare_versions(v1, v2)
    -- Compare two semantic versions
    -- Returns: -1 if v1 < v2, 0 if v1 == v2, 1 if v1 > v2
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
    
    return 0  -- Equal
end


function check_turtle_versions()
    -- Check if any turtles are out of date and set them to updating state
    local hub_version = get_hub_version()
    if not hub_version then
        -- Can't check versions if hub version not available
        return
    end
    
    for _, turtle in pairs(state.turtles) do
        -- Skip turtles that are already updating, halted, or awaiting version verification
        if not turtle.data or turtle.state == 'updating' or turtle.state == 'halt' or turtle.update_complete then
            -- Skip this turtle
        else
            -- Check if turtle already has a task queued that will set it to updating state
            local has_update_task = false
            if turtle.tasks and #turtle.tasks > 0 then
                for _, task in ipairs(turtle.tasks) do
                    if task.end_state == 'updating' then
                        has_update_task = true
                        break
                    end
                end
            end
            
            -- Skip if already has an update task queued (set state to prevent future checks)
            if has_update_task then
                turtle.state = 'updating'
            else
                local needs_update = false
                
                -- Check if turtle has force_update flag set (from dev force update or manual command)
                if turtle.force_update then
                    needs_update = true
                -- If turtle has no version data, consider it out of date
                elseif not turtle.data.version then
                    needs_update = true
                elseif turtle.data.version then
                    local turtle_version = turtle.data.version
                    local comparison = compare_versions(turtle_version, hub_version)
                    
                    -- If turtle version is older than hub version, needs update
                    if comparison and comparison < 0 then
                        needs_update = true
                    end
                end
                        
                if needs_update then
                    if turtle.force_update then
                        print('Turtle ' .. turtle.id .. ' force update requested. Setting to updating state...')
                        turtle.force_update = nil  -- Clear flag after using it
                    else
                        print('Turtle ' .. turtle.id .. ' is out of date. Setting to updating state...')
                    end
                    -- Free turtle from any block assignment
                    free_turtle(turtle)
                    -- Clear tasks and set to updating state IMMEDIATELY to prevent duplicate checks
                    -- No need for 'pass' task - the update flow in command_turtles() will handle navigation
                    turtle.tasks = {}
                    turtle.state = 'updating'
                end
            end
        end
    end
end


function queue_turtles_for_update(turtle_list, update_hub_after, force_update)
    -- Set turtles to updating state for state-based update system
    -- force_update: If true, updates turtles even if versions match
    if #turtle_list == 0 then
        if update_hub_after then
            -- Check if all turtles are updated before updating hub
            local all_updated = true
            for _, turtle in pairs(state.turtles) do
                if turtle.data and turtle.state == 'updating' then
                    all_updated = false
                    break
                end
            end
            
            if all_updated then
            print('All turtles updated. Updating hub...')
            sleep(1)
            if force_update then
                os.run({}, '/update', 'force')
            else
                os.run({}, '/update')
                end
            end
        end
        return
    end
    
    -- Set turtles to updating state
    for _, turtle in pairs(turtle_list) do
        if turtle.data then
            -- Free turtle from any block assignment
            free_turtle(turtle)
            -- Clear tasks and set to updating state IMMEDIATELY to prevent duplicate checks
            -- No need for 'pass' task - the update flow in command_turtles() will handle navigation
            turtle.tasks = {}
            turtle.state = 'updating'
            turtle.force_update = force_update or false
            print('Set turtle ' .. turtle.id .. ' to updating state')
        end
    end
    
    state.update_hub_after = update_hub_after
    state.force_update = force_update or false
end


function count_turtles_at_disk()
    -- Count how many turtles are currently at the disk drive
    local count = 0
            for _, turtle in pairs(state.turtles) do
        if turtle.data and turtle.data.location and turtle.state == 'updating' then
            if utilities.in_location(turtle.data.location, config.locations.disk_drive) then
                count = count + 1
                end
            end
    end
    return count
end


function on_update_complete(turtle_id)
    -- Called when a turtle completes its update
    local turtle = state.turtles[turtle_id]
    if turtle then
        print('Turtle ' .. turtle_id .. ' update complete! Will verify version after initialization...')
        -- Mark that this turtle just completed an update and needs version verification
        -- The turtle will reboot and initialize, then we'll check its version
        turtle.update_complete = true
        turtle.update_sent_home = nil
        turtle.update_sent_to_disk = nil
        turtle.update_waiting_at_disk = nil
        -- Keep turtle in updating state - it will be verified after initialization
    end
end


function verify_turtle_version_after_update(turtle)
    -- Verify turtle version after it has updated and initialized
    -- Called when turtle reports version data after completing an update
    local hub_version = get_hub_version()
    if not hub_version then
        -- Can't verify without hub version
        return false
    end
    
    if not turtle.data or not turtle.data.version then
        -- Turtle hasn't reported version yet
        return false
    end
    
    local turtle_version = turtle.data.version
    local comparison = compare_versions(turtle_version, hub_version)
    
    if comparison and comparison >= 0 then
        -- Version is correct, update successful
        local turtle_version_str = turtle_version.major .. '.' .. turtle_version.minor .. '.' .. turtle_version.hotfix
        local hub_version_str = hub_version.major .. '.' .. hub_version.minor .. '.' .. hub_version.hotfix
        if is_dev_version(hub_version) then
            hub_version_str = hub_version_str .. '-DEV'
        end
        print('Turtle ' .. turtle.id .. ' version verified: ' .. turtle_version_str .. ' (hub: ' .. hub_version_str .. ')')
        turtle.update_complete = nil
        turtle.update_sent_home = nil
        turtle.update_sent_to_disk = nil
        turtle.update_waiting_at_disk = nil
        
        -- Transition out of updating state (turtle might be in 'lost' state after initialization)
        if turtle.state == 'updating' or turtle.state == 'lost' then
            if state.on then
                add_task(turtle, {
                    action = 'go_to_waiting_room',
                    end_state = 'idle',
                })
            else
                add_task(turtle, {
                    action = 'go_to_home',
                    end_state = 'park',
                })
            end
        end
        return true
    else
        -- Version is still wrong, needs another update
        local turtle_version_str = turtle_version and (turtle_version.major .. '.' .. turtle_version.minor .. '.' .. turtle_version.hotfix) or 'unknown'
        local hub_version_str = hub_version.major .. '.' .. hub_version.minor .. '.' .. hub_version.hotfix
        if is_dev_version(hub_version) then
            hub_version_str = hub_version_str .. '-DEV'
        end
        print('Turtle ' .. turtle.id .. ' version still incorrect after update: ' .. turtle_version_str .. ' (hub: ' .. hub_version_str .. ')')
        print('Turtle ' .. turtle.id .. ' will update again...')
        -- Reset update flags so it can update again
        turtle.update_complete = nil
        turtle.update_sent_home = nil
        turtle.update_sent_to_disk = nil
        turtle.update_waiting_at_disk = nil
        -- Keep in updating state to update again
        return false
    end
end

