-- ============================================
-- Detection Module
-- Block detection and ore detection functions
-- ============================================

function checkTags(data)
    if type(data.tags) ~= 'table' then
        return false
    end
    if not config.blocktags then
        return false
    end
    for k,v in pairs(data.tags) do
        if config.blocktags[k] then
            return true
        end
    end
    return false
end

function detect_ore(direction)
    local block = ({inspect[direction]()})[2]
    if block == nil or block.name == nil then
        return false
    end
    -- Check config.orenames first (user-defined ore list takes priority)
    if config.orenames and config.orenames[block.name] then
        return true
    end
    -- Check if block name contains "_ore" (case-insensitive) - catches modded ores
    if block.name:lower():find("_ore") then
        return true
    end
    -- Check for forge ore tags (useful for modded ores that use tags)
    if checkTags(block) then
        return true
    end
    return false
end

function scan(valid, ores)
    local checked_left  = false
    local checked_right = false
    
    local f = str_xyz(getblock.forward())
    local u = str_xyz(getblock.up())
    local d = str_xyz(getblock.down())
    local l = str_xyz(getblock.left())
    local r = str_xyz(getblock.right())
    local b = str_xyz(getblock.back())
    
    if not valid[f] and valid[f] ~= false then
        valid[f] = detect_ore('forward')
        ores[f] = valid[f]
    end
    if not valid[u] and valid[u] ~= false then
        valid[u] = detect_ore('up')
        ores[u] = valid[u]
    end
    if not valid[d] and valid[d] ~= false then
        valid[d] = detect_ore('down')
        ores[d] = valid[d]
    end
    if not valid[l] and valid[l] ~= false then
        left()
        checked_left = true
        valid[l] = detect_ore('forward')
        ores[l] = valid[l]
    end
    if not valid[r] and valid[r] ~= false then
        right()
        if checked_left then
            right()
        end
        checked_right = true
        valid[r] = detect_ore('forward')
        ores[r] = valid[r]
    end
    if not valid[b] and valid[b] ~= false then
        if checked_right then
            right()
        elseif checked_left then
            left()
        else
            right(2)
        end
        valid[b] = detect_ore('forward')
        ores[b] = valid[b]
    end
end

function detect_bedrock(direction)
    -- Check if block below is bedrock
    -- direction should be 'down' for world eater
    if not direction then
        direction = 'down'
    end
    
    local success, data = inspect[direction]()
    if not success or not data then
        return false
    end
    
    local block_name = data.name or ""
    -- Check if block name contains "bedrock" (case insensitive)
    if string.find(string.lower(block_name), "bedrock") then
        return true
    end
    
    -- Also check if we've reached bedrock level
    if direction == 'down' and state.location.y <= config.bedrock_level then
        return true
    end
    
    return false
end

function safedig(direction)
    -- DIG IF BLOCK NOT ON BLACKLIST
    if not direction then
        direction = 'forward'
    end
    
    local block_data = ({inspect[direction]()})[2]
    local block_name = block_data and block_data.name
    if block_name then
        for _, word in pairs(config.dig_disallow) do
            if string.find(string.lower(block_name), word) then
                return false
            end
        end

        -- Check if it's an ore BEFORE digging (since block will be gone after)
        local is_ore = detect_ore(direction)
        
        local result = dig[direction]()
        
        -- Track statistics if block was successfully dug
        if result then
            -- Initialize statistics if not already done
            if not state.statistics then
                state.statistics = {
                    blocks_mined = 0,
                    ores_mined = 0,
                    ore_counts = {}
                }
            end
            
            -- Increment total blocks mined
            state.statistics.blocks_mined = state.statistics.blocks_mined + 1
            
            -- Track ore if it was detected as an ore
            if is_ore then
                state.statistics.ores_mined = state.statistics.ores_mined + 1
                state.statistics.ore_counts[block_name] = (state.statistics.ore_counts[block_name] or 0) + 1
            end
        end
        
        return result
    end
    return true
end

function clear_gravity_blocks()
    for _, direction in pairs({'forward', 'up'}) do
        while config.gravitynames[ ({inspect[direction]()})[2].name ] do
            safedig(direction)
            sleep(1)
        end
    end
    return true
end

-- Explicitly expose functions as globals (os.loadAPI wraps them in a table)
_G.checkTags = checkTags
_G.detect_ore = detect_ore
_G.scan = scan
_G.detect_bedrock = detect_bedrock
_G.safedig = safedig
_G.clear_gravity_blocks = clear_gravity_blocks

