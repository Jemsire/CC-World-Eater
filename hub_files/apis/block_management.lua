-- ============================================
-- Block Management Module
-- Handles tracking of mined blocks
-- ============================================

-- Get API references
local config = API.getConfig()
local state = API.getState()

function load_mine()
    -- LOAD MINE INTO state.mine FROM /mine/<x,z>/ DIRECTORY
    -- Loads mined blocks
    
    -- Ensure config.locations.mine_enter exists
    if not config or not config.locations or not config.locations.mine_enter then
        error("load_mine() failed: config.locations.mine_enter is not defined. Check config.lua")
    end
    
    local mine_dir_path = '/mine/' .. config.locations.mine_enter.x .. ',' .. config.locations.mine_enter.z .. '/'
    API.setStateValue('mine_dir_path', mine_dir_path)
    
    if not fs.exists(mine_dir_path) then
        fs.makeDir(mine_dir_path)
    end
    
    if fs.exists(mine_dir_path .. 'on') then
        API.setStateValue('on', true)
    end
    
    -- Load mined blocks
    API.setStateValue('mined_blocks', {})
    local state_refresh = API.getState()
    local mined_blocks_dir = state_refresh.mine_dir_path .. 'mined_blocks/'
    
    if not fs.exists(mined_blocks_dir) then
        fs.makeDir(mined_blocks_dir)
    else
        -- Load all mined block files
        local mined_blocks = {}
        for _, file_name in pairs(fs.list(mined_blocks_dir)) do
            if file_name:sub(1, 1) ~= '.' then
                -- File name format: "x,z"
                local coords = {}
                for coord in string.gmatch(file_name, '[^,]+') do
                    table.insert(coords, tonumber(coord))
                end
                if #coords == 2 then
                    local x, z = coords[1], coords[2]
                    if not mined_blocks[x] then
                        mined_blocks[x] = {}
                    end
                    mined_blocks[x][z] = true
                end
            end
        end
        API.setStateValue('mined_blocks', mined_blocks)
        state_refresh = API.getState()
    end
    
    -- Set state.mine flag for monitor compatibility (ALWAYS set this, even if no blocks loaded)
    API.setStateValue('mine', true)
    
    local turtles_dir_path = state_refresh.mine_dir_path .. 'turtles/'
    API.setStateValue('turtles_dir_path', turtles_dir_path)
    
    if not fs.exists(turtles_dir_path) then
        fs.makeDir(turtles_dir_path)
    end
    
    -- Load turtle assignments
    for _, turtle_id in pairs(fs.list(turtles_dir_path)) do
        if turtle_id:sub(1, 1) ~= '.' then
            turtle_id = tonumber(turtle_id)
            local turtle = {
                id = turtle_id,
                tasks = {}  -- Initialize tasks array to prevent nil errors
            }
            DataThread.updateData('state.turtles.' .. turtle_id, turtle)
            local turtle_dir_path = turtles_dir_path .. turtle_id .. '/'
            
            -- Load block assignment
            if fs.exists(turtle_dir_path .. 'block') then
                local file = fs.open(turtle_dir_path .. 'block', 'r')
                if file then
                    local block_args = string.gmatch(file.readAll(), '[^,]+')
                    local x = tonumber(block_args())
                    local z = tonumber(block_args())
                    if x and z then
                        turtle.block = {x = x, z = z}
                        -- Check if deployed (mining in progress)
                        if fs.exists(turtle_dir_path .. 'deployed') then
                            local dep_file = fs.open(turtle_dir_path .. 'deployed', 'r')
                            if dep_file then
                                local depth_reached = tonumber(dep_file.readAll())
                                turtle.depth_reached = depth_reached  -- Y coordinate reached
                                dep_file.close()
                            end
                        end
                    end
                    file.close()
                end
            end
            
            if fs.exists(turtle_dir_path .. 'halt') then
                turtle.state = 'halt'
            end
        end
    end
end


function is_block_mined(x, z)
    -- Check if a block at (x, z) has been completely mined to bedrock
    if not state.mined_blocks then
        return false
    end
    if not state.mined_blocks[x] then
        return false
    end
    return state.mined_blocks[x][z] == true
end


function mark_block_mined(x, z)
    -- Mark a block as completely mined to bedrock
    local state_refresh = API.getState()
    local mined_blocks = state_refresh.mined_blocks or {}
    if not mined_blocks[x] then
        mined_blocks[x] = {}
    end
    mined_blocks[x][z] = true
    API.setStateValue('mined_blocks', mined_blocks)
    
    -- Write to disk
    state_refresh = API.getState()
    local mined_blocks_dir = state_refresh.mine_dir_path .. 'mined_blocks/'
    if not fs.exists(mined_blocks_dir) then
        fs.makeDir(mined_blocks_dir)
    end
    local file = fs.open(mined_blocks_dir .. x .. ',' .. z, 'w')
    file.close()  -- Empty file, existence indicates mined
end


function write_turtle_block(turtle, block)
    -- Record turtle's assigned block
    local state_refresh = API.getState()
    local file = fs.open(state_refresh.turtles_dir_path .. turtle.id .. '/block', 'w')
    file.write(block.x .. ',' .. block.z)
    file.close()
end


function update_block(turtle)
    -- Mark block as mined when turtle completes mining to bedrock
    local block = turtle.block
    if block then
        -- Check if turtle reached bedrock level
        local config = API.getConfig()
        if turtle.data.location and turtle.data.location.y <= config.bedrock_level then
            mark_block_mined(block.x, block.z)
        end
    end
end

