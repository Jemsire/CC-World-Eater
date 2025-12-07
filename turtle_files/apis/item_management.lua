-- ============================================
-- Item Management Module
-- Item handling and preparation functions
-- ============================================

function dump_items(omit)
    for slot = 1, 16 do
        if turtle.getItemCount(slot) > 0 and ((not omit) or (not omit[turtle.getItemDetail(slot).name])) then
            turtle.select(slot)
            if not turtle.drop() then return false end
        end
    end
    return true
end

function dump(direction)
    if not face(direction) then return false end
    if ({inspect.forward()})[2].name ~= 'computercraft:turtle_advanced' then
        return false
    end
    for slot = 1, 16 do
        if turtle.getItemCount(slot) > 0 then
            turtle.select(slot)
            turtle.drop()
        end
    end
    return true
end

function prepare(min_fuel_amount)
    if state.item_count > 0 then
        if not go_to_item_drop() then return false end
        if not dump_items(config.fuelnames) then return false end
    end
    local min_fuel_amount = min_fuel_amount + config.fuel_padding
    if not go_to_refuel() then return false end
    if not dump_items() then return false end
    turtle.select(1)
    if turtle.getFuelLevel() ~= 'unlimited' then
        while turtle.getFuelLevel() < min_fuel_amount do
            if not turtle.suck(math.min(64, math.ceil(min_fuel_amount / config.fuel_per_unit))) then return false end
            turtle.refuel()
        end
    end
    return true
end

