-- Utilities module (os.loadAPI style - sets globals)

inf = 1e309

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
    if not area or not xyz then
        return false
    end
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


-- Expose functions and variables as globals (os.loadAPI wraps them into API table)
-- Assign to global environment explicitly
_G.inf = inf
_G.dprint = dprint
_G.str_xyz = str_xyz
_G.distance = distance
_G.in_area = in_area
_G.in_location = in_location