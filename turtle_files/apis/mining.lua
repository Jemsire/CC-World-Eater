-- ============================================
-- Mining Module
-- Mining operations and pathfinding
-- ============================================

function find_path_around_obstacle()
    -- Try to find a path around an obstacle by checking adjacent blocks
    -- Returns true if path found and turtle moved to new position, false if no path
    -- Checks blocks in cardinal directions (north, south, east, west) first
    
    local original_pos = {x = state.location.x, y = state.location.y, z = state.location.z, facing = state.orientation}
    local directions = {
        {dx = -1, dz = 0, face = 'west'},
        {dx = 1, dz = 0, face = 'east'},
        {dx = 0, dz = -1, face = 'north'},
        {dx = 0, dz = 1, face = 'south'},
    }
    
    -- Try each cardinal direction
    for _, dir in ipairs(directions) do
        -- Face the direction
        if face(dir.face) then
            local found_path = false
            
            -- Check if we can move forward
            if detect.forward() then
                -- Block in way, try to dig it
                if safedig('forward') then
                    -- Can dig, try to move
                    if go('forward') then
                        found_path = true
                    end
                end
            else
                -- No block in way, try to move
                if go('forward') then
                    found_path = true
                end
            end
            
            if found_path then
                -- Now check what's below at this new position
                if detect.down() then
                    local success, block_data = inspect.down()
                    if success and block_data then
                        local block_name = block_data.name or ""
                        local is_disallowed = false
                        local is_bedrock = false
                        
                        for _, word in pairs(config.dig_disallow) do
                            if string.find(string.lower(block_name), word) then
                                is_disallowed = true
                                if string.find(string.lower(block_name), "bedrock") then
                                    is_bedrock = true
                                end
                                break
                            end
                        end
                        
                        if not is_disallowed then
                            -- Found a path! This block below is minable
                            print("Found path around obstacle, continuing from new position")
                            return true
                        elseif is_bedrock then
                            -- Bedrock below, can't mine here either
                            -- Move back and try next direction
                            go('back')
                        else
                            -- Another disallowed block, move back and try next direction
                            go('back')
                        end
                    else
                        -- No block below, can mine here
                        print("Found path around obstacle, continuing from new position")
                        return true
                    end
                else
                    -- No block below, can mine here
                    print("Found path around obstacle, continuing from new position")
                    return true
                end
            end
        end
    end
    
    -- No path found, return to original position
    -- Try to get back to original position
    if state.location.x ~= original_pos.x or state.location.z ~= original_pos.z then
        -- We moved, try to get back
        go_to({x = original_pos.x, y = state.location.y, z = original_pos.z}, original_pos.facing, 'xz')
    end
    
    return false
end

function mine_column_down(block)
    -- Mine straight down from current position to bedrock
    -- Returns true if completed, false if interrupted
    local start_y = state.location.y
    local target_y = config.bedrock_level
    local original_x = block and block.x or state.location.x
    local original_z = block and block.z or state.location.z
    
    -- Check if we're already at or below bedrock
    if start_y <= target_y then
        return true
    end
    
    -- Mine down block by block
    while state.location.y > target_y do
        -- Check for bedrock before digging
        if detect_bedrock('down') then
            -- Reached bedrock, stop mining
            break
        end
        
        -- Check inventory space
        if state.empty_slot_count == 0 then
            -- Inventory full, need to return
            return false
        end
        
        -- Check fuel (rough estimate)
        local fuel_needed = (state.location.y - target_y) * 2  -- Down and back up
        if turtle.getFuelLevel() ~= "unlimited" and turtle.getFuelLevel() < fuel_needed + 50 then
            -- Low on fuel, return early
            return false
        end
        
        -- Check if block below exists
        if detect.down() then
            -- Inspect block to check if it's disallowed
            local success, block_data = inspect.down()
            if success and block_data then
                local block_name = block_data.name or ""
                local is_disallowed = false
                local is_bedrock = false
                
                for _, word in pairs(config.dig_disallow) do
                    if string.find(string.lower(block_name), word) then
                        is_disallowed = true
                        if string.find(string.lower(block_name), "bedrock") then
                            is_bedrock = true
                        end
                        break
                    end
                end
                
                if is_disallowed then
                    if is_bedrock then
                        -- Bedrock reached - stop mining and return
                        print("Reached bedrock at Y=" .. state.location.y)
                        break
                    else
                        -- Other disallowed block (chest, computer, etc.) - try to go around
                        print("Encountered disallowed block: " .. block_name .. " - attempting to navigate around...")
                        
                        -- Try to find a path around the obstacle
                        if find_path_around_obstacle() then
                            -- Found a path, continue mining from new position
                            -- Continue loop to mine down from new position
                        else
                            -- No path found, return to surface
                            print("Could not navigate around obstacle, returning to surface...")
                            return false
                        end
                    end
                else
                    -- Block is minable, try to dig it
                    safedig('down')
                end
            else
                -- No block data, try to dig anyway
                safedig('down')
            end
        end
        
        -- Move down
        if not go('down') then
            -- Can't move down, might be bedrock or unbreakable obstacle
            -- Check if it's bedrock
            if detect.down() then
                local success, block_data = inspect.down()
                if success and block_data then
                    local block_name = block_data.name or ""
                    if string.find(string.lower(block_name), "bedrock") then
                        -- Bedrock, stop mining
                        break
                    else
                        -- Not bedrock, try to navigate around
                        if find_path_around_obstacle() then
                            -- Found path, continue mining
                            -- Continue loop to mine from new position
                        else
                            -- No path, give up
                            return false
                        end
                    end
                end
            end
            break
        end
        
        -- Clear any gravity blocks that may have fallen above
        if detect.up() then
            local up_success, up_data = inspect.up()
            if up_success and up_data and config.gravitynames[up_data.name] then
                safedig('up')
                sleep(0.5)  -- Wait for block to fall
            end
        end
    end
    
    return true
end

function mine_column_up(target_y)
    -- Return to surface (or target Y level)
    -- Mines up if needed (blocks may have fallen)
    if not target_y then
        target_y = config.locations.mining_center.y + 2  -- Surface level
    end
    
    while state.location.y < target_y do
        -- Check if block above exists
        if detect.up() then
            -- Block above, dig it
            safedig('up')
        end
        
        -- Move up
        if not go('up') then
            -- Can't move up, might be obstacle
            return false
        end
    end
    
    return true
end

function mine_to_bedrock(block)
    -- Main world eater mining function
    -- Mines entire column from surface to bedrock
    -- block = {x = x, z = z}
    
    if not block or not block.x or not block.z then
        return false
    end
    
    -- Ensure we're at the correct block position
    local surface_y = config.locations.mining_center.y + 2
    if state.location.x ~= block.x or state.location.z ~= block.z or state.location.y ~= surface_y then
        -- Not at correct position, navigate there first
        if not go_to_block(block) then
            return false
        end
    end
    
    -- Mine down to bedrock
    local completed = mine_column_down(block)
    
    -- Clear gravity blocks before returning
    clear_gravity_blocks()
    
    -- Return to surface
    if not mine_column_up(surface_y) then
        -- Failed to return to surface, but mining is done
        -- Try to get back to surface level at least
        while state.location.y < surface_y do
            if detect.up() then
                safedig('up')
            end
            if not go('up') then
                break
            end
        end
    end
    
    -- Return to exact block position at surface
    if state.location.x ~= block.x or state.location.z ~= block.z then
        go_to({x = block.x, y = state.location.y, z = block.z}, nil, 'xz')
    end
    
    return completed
end

-- Explicitly expose functions as globals (os.loadAPI wraps them in a table)
_G.find_path_around_obstacle = find_path_around_obstacle
_G.mine_column_down = mine_column_down
_G.mine_column_up = mine_column_up
_G.mine_to_bedrock = mine_to_bedrock

