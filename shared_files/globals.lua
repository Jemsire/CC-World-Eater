-- ==============================================
-- GLOBAL VARIABLES
-- Should be used for all global variables that are used in multiple files.
-- Gets duplicated to both hub_files and turtle_files.
-- ==============================================

 inf = 1e309

 menu_lines = {
    "##### ##### ##### ##### #####",
    "#     #   #   #   #     #   #",
    "###   #####   #   ###   #### ",
    "#     #   #   #   #     #  # ",
    "##### #   #   #   ##### #   #"
}

 decimals = {
    [0] = {
        "#####",
        "#   #",
        "#   #",
        "#   #",
        "#####"
    },
    [1] = {
        "###  ",
        "  #  ",
        "  #  ",
        "  #  ",
        "#####"
    },
    [2] = {
        "#####",
        "    #",
        "#####",
        "#    ",
        "#####"
    },
    [3] = {
        "#####",
        "    #",
        "#####",
        "    #",
        "#####"
    },
    [4] = {
        "#   #",
        "#   #",
        "#####",
        "    #",
        "    #"
    },
    [5] = {
        "#####",
        "#    ",
        "#####",
        "    #",
        "#####"
    },
    [6] = {
        "#####",
        "#    ",
        "#####",
        "#   #",
        "#####"
    },
    [7] = {
        "#####",
        "    #",
        "    #",
        "    #",
        "    #"
    },
    [8] = {
        "#####",
        "#   #",
        "#####",
        "#   #",
        "#####"
    },
    [9] = {
        "#####",
        "#   #",
        "#####",
        "    #",
        "    #"
    }
}

 color_codes = {
    ["0"] = colors.black,
    ["1"] = colors.blue,
    ["2"] = colors.green,
    ["3"] = colors.cyan,
    ["4"] = colors.red,
    ["5"] = colors.purple,
    ["6"] = colors.orange,
    ["7"] = colors.lightGray,
    ["8"] = colors.gray,
    ["9"] = colors.lightBlue,
    ["a"] = colors.lime,
    ["b"] = colors.brown,
    ["c"] = colors.pink,
    ["d"] = colors.magenta,
    ["e"] = colors.yellow,
    ["f"] = colors.white,
    ["r"] = default_text_color,
    ["t"] = nil
}

bumps = {
    north = { 0,  0, -1},
    south = { 0,  0,  1},
    east  = { 1,  0,  0},
    west  = {-1,  0,  0},
}

left_shift = {
    north = 'west',
    south = 'east',
    east  = 'north',
    west  = 'south',
}

right_shift = {
    north = 'east',
    south = 'west',
    east  = 'south',
    west  = 'north',
}

reverse_shift = {
    north = 'south',
    south = 'north',
    east  = 'west',
    west  = 'east',
}

function dprint(thing)
    -- PRINT; IF TABLE PRINT EACH ITEM
    if type(thing) == 'table' then
        for k, v in pairs(thing) do
            print(tostring(k) .. ': ' .. tostring(v))
        end
    else
        print(thing)
    end
    return true
end


function str_xyz(coords, facing)
    if facing then
        return coords.x .. ',' .. coords.y .. ',' .. coords.z .. ':' .. facing
    else
        return coords.x .. ',' .. coords.y .. ',' .. coords.z
    end
end


function distance(point_1, point_2)
    return math.abs(point_1.x - point_2.x)
         + math.abs(point_1.y - point_2.y)
         + math.abs(point_1.z - point_2.z)
end


function in_area(xyz, area)
    return xyz.x <= area.max_x and xyz.x >= area.min_x and xyz.y <= area.max_y and xyz.y >= area.min_y and xyz.z <= area.max_z and xyz.z >= area.min_z
end


function in_location(xyzo, location)
    for _, axis in pairs({'x', 'y', 'z'}) do
        if location[axis] then
            if location[axis] ~= xyzo[axis] then
                return false
            end
        end
    end
    return true
end


function format_directive_data(action, data)
    -- FORMAT DIRECTIVE DATA FOR DEBUG LOGGING
    if not data or #data == 0 then
        return ""
    end
    
    local data_str = ""
    
    if action == 'go_to' then
        -- Format coordinates for go_to
        local location = data[1]
        if location and type(location) == 'table' then
            if location.x and location.y and location.z then
                data_str = string.format(" -> (%d,%d,%d)", location.x, location.y, location.z)
                if location.orientation then
                    data_str = data_str .. " facing " .. location.orientation
                end
            end
        end
    elseif action == 'go_to_strip' then
        -- Format strip coordinates
        local strip = data[1]
        if strip and type(strip) == 'table' then
            if strip.x and strip.y and strip.z then
                data_str = string.format(" -> strip (%d,%d,%d)", strip.x, strip.y, strip.z)
                if strip.orientation then
                    data_str = data_str .. " facing " .. strip.orientation
                end
            end
        end
    elseif action == 'go_to_mine_exit' then
        -- Format mine exit with optional strip
        local strip = data[1]
        if strip and type(strip) == 'table' and strip.x and strip.y and strip.z then
            data_str = string.format(" from strip (%d,%d,%d)", strip.x, strip.y, strip.z)
        else
            data_str = " (to surface)"
        end
    elseif action == 'prepare' then
        -- Format fuel amount
        local fuel_amount = data[1]
        if fuel_amount then
            data_str = string.format(" (min_fuel: %d)", fuel_amount)
        end
    elseif action == 'go_to_home' then
        data_str = " (returning home)"
    elseif action == 'go_to_item_drop' then
        data_str = " (dropping items)"
    elseif action == 'go_to_refuel' then
        data_str = " (refueling)"
    elseif action == 'go_to_waiting_room' then
        data_str = " (to waiting room)"
    elseif action == 'go_to_mine_enter' then
        data_str = " (entering mine)"
    elseif action == 'mine_vein' then
        local orientation = data[1]
        if orientation then
            data_str = string.format(" (orientation: %s)", orientation)
        end
    elseif action == 'dump' then
        local direction = data[1]
        if direction then
            data_str = string.format(" (direction: %s)", direction)
        end
    elseif action == 'delay' then
        local duration = data[1]
        if duration then
            data_str = string.format(" (duration: %s)", duration)
        end
    elseif action == 'face' then
        local orientation = data[1]
        if orientation then
            data_str = string.format(" (facing: %s)", orientation)
        end
    elseif action == 'follow_route' then
        local route = data[1]
        if route then
            data_str = string.format(" (route: %s)", route)
        end
    elseif action == 'initialize' then
        data_str = " (initializing turtle)"
    elseif action == 'calibrate' then
        data_str = " (calibrating position)"
    elseif action == 'pass' then
        data_str = " (no-op)"
    else
        -- Generic formatting for other actions
        if #data > 0 then
            local parts = {}
            for i, v in ipairs(data) do
                if type(v) == 'table' then
                    if v.x and v.y and v.z then
                        table.insert(parts, string.format("(%d,%d,%d)", v.x, v.y, v.z))
                    else
                        table.insert(parts, tostring(v))
                    end
                else
                    table.insert(parts, tostring(v))
                end
            end
            if #parts > 0 then
                data_str = " (" .. table.concat(parts, ", ") .. ")"
            end
        end
    end
    
    return data_str
end