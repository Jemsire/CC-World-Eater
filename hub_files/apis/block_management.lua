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
    state.mine_dir_path = '/mine/' .. config.locations.mine_enter.x .. ',' .. config.locations.mine_enter.z .. '/'
    
    if not fs.exists(state.mine_dir_path) then
        fs.makeDir(state.mine_dir_path)
    end
    
    if fs.exists(state.mine_dir_path .. 'on') then
        state.on = true
    end
    
    -- Load mined blocks
    state.mined_blocks = {}
    local mined_blocks_dir = state.mine_dir_path .. 'mined_blocks/'
    
    if not fs.exists(mined_blocks_dir) then
        fs.makeDir(mined_blocks_dir)
    else
        -- Load all mined block files
        for _, file_name in pairs(fs.list(mined_blocks_dir)) do
            if file_name:sub(1, 1) ~= '.' then
                -- File name format: "x,z"
                local coords = {}
                for coord in string.gmatch(file_name, '[^,]+') do
                    table.insert(coords, tonumber(coord))
                end
                if #coords == 2 then
                    local x, z = coords[1], coords[2]
                    if not state.mined_blocks[x] then
                        state.mined_blocks[x] = {}
                    end
                    state.mined_blocks[x][z] = true
                end
            end
        end
    end
    
    -- Set state.mine flag for monitor compatibility
    state.mine = true
    
    state.turtles_dir_path = state.mine_dir_path .. 'turtles/'
    
    if not fs.exists(state.turtles_dir_path) then
        fs.makeDir(state.turtles_dir_path)
    end
    
    -- Load turtle assignments
    for _, turtle_id in pairs(fs.list(state.turtles_dir_path)) do
        if turtle_id:sub(1, 1) ~= '.' then
            turtle_id = tonumber(turtle_id)
            local turtle = {id = turtle_id}
            state.turtles[turtle_id] = turtle
            local turtle_dir_path = state.turtles_dir_path .. turtle_id .. '/'
            
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
    if not state.mined_blocks then
        state.mined_blocks = {}
    end
    if not state.mined_blocks[x] then
        state.mined_blocks[x] = {}
    end
    state.mined_blocks[x][z] = true
    
    -- Write to disk
    local mined_blocks_dir = state.mine_dir_path .. 'mined_blocks/'
    if not fs.exists(mined_blocks_dir) then
        fs.makeDir(mined_blocks_dir)
    end
    local file = fs.open(mined_blocks_dir .. x .. ',' .. z, 'w')
    file.close()  -- Empty file, existence indicates mined
end


function write_turtle_block(turtle, block)
    -- Record turtle's assigned block
    local file = fs.open(state.turtles_dir_path .. turtle.id .. '/block', 'w')
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

