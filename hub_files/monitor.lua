-- APIs are loaded by startup.lua - this file uses globals from there

menu_lines = {
    '##### ##### ##### ##### #####',
    '#     #   #   #   #     #   #',
    '###   #####   #   ###   #### ',
    '#     #   #   #   #     #  # ',
    '##### #   #   #   ##### #   #',
}

decimals = {
    [0] = {
        '#####',
        '#   #',
        '#   #',
        '#   #',
        '#####',
    },
    [1] = {
        '###  ',
        '  #  ',
        '  #  ',
        '  #  ',
        '#####',
    },
    [2] = {
        '#####',
        '    #',
        '#####',
        '#    ',
        '#####',
    },
    [3] = {
        '#####',
        '    #',
        '#####',
        '    #',
        '#####',
    },
    [4] = {
        '#   #',
        '#   #',
        '#####',
        '    #',
        '    #',
    },
    [5] = {
        '#####',
        '#    ',
        '#####',
        '    #',
        '#####',
    },
    [6] = {
        '#####',
        '#    ',
        '#####',
        '#   #',
        '#####',
    },
    [7] = {
        '#####',
        '    #',
        '    #',
        '    #',
        '    #',
    },
    [8] = {
        '#####',
        '#   #',
        '#####',
        '#   #',
        '#####',
    },
    [9] = {
        '#####',
        '#   #',
        '#####',
        '    #',
        '    #',
    },
}

function debug_print(string)
    term.redirect(monitor.restore_to)
    print(string)
    term.redirect(monitor)
end

function turtle_viewer(turtle_ids)
    term.redirect(monitor)
    
    local selected = 1
    
    while true do
        local turtle_id = turtle_ids[selected]
        local turtle = state.turtles[turtle_id]
        
        -- RESOLVE MONITOR TOUCHES, EITHER BY AFFECTING THE DISPLAY OR INSERTING INTO USER_INPUT TABLE
        while #state.monitor_touches > 0 do
            local monitor_touch = table.remove(state.monitor_touches)
            if monitor_touch.x == elements.left.x and monitor_touch.y == elements.left.y then
                selected = math.max(selected - 1, 1)
            elseif monitor_touch.x == elements.right.x and monitor_touch.y == elements.right.y then
                selected = math.min(selected + 1, #turtle_ids)
            elseif monitor_touch.x == elements.viewer_exit.x and monitor_touch.y == elements.viewer_exit.y then
                term.redirect(monitor.restore_to)
                return
            elseif monitor_touch.x == elements.turtle_return.x and monitor_touch.y == elements.turtle_return.y then
                table.insert(state.user_input, 'return ' .. turtle_id)
            elseif monitor_touch.x == elements.turtle_reboot.x and monitor_touch.y == elements.turtle_reboot.y then
                table.insert(state.user_input, 'reboot ' .. turtle_id)
            elseif monitor_touch.x == elements.turtle_halt.x and monitor_touch.y == elements.turtle_halt.y then
                table.insert(state.user_input, 'halt ' .. turtle_id)
            elseif monitor_touch.x == elements.turtle_clear.x and monitor_touch.y == elements.turtle_clear.y then
                table.insert(state.user_input, 'clear ' .. turtle_id)
            elseif monitor_touch.x == elements.turtle_reset.x and monitor_touch.y == elements.turtle_reset.y then
                table.insert(state.user_input, 'reset ' .. turtle_id)
            elseif monitor_touch.x == elements.turtle_find.x and monitor_touch.y == elements.turtle_find.y then
                monitor_location.x = turtle.data.location.x
                monitor_location.z = turtle.data.location.z
                monitor_zoom_level = 0
                if turtle.block then
                    monitor_location.x = turtle.block.x
                    monitor_location.z = turtle.block.z
                end
                term.redirect(monitor.restore_to)
                return
            elseif monitor_touch.x == elements.turtle_forward.x and monitor_touch.y == elements.turtle_forward.y then
                table.insert(state.user_input, 'turtle ' .. turtle_id .. ' go forward')
            elseif monitor_touch.x == elements.turtle_back.x and monitor_touch.y == elements.turtle_back.y then
                table.insert(state.user_input, 'turtle ' .. turtle_id .. ' go back')
            elseif monitor_touch.x == elements.turtle_up.x and monitor_touch.y == elements.turtle_up.y then
                table.insert(state.user_input, 'turtle ' .. turtle_id .. ' go up')
            elseif monitor_touch.x == elements.turtle_down.x and monitor_touch.y == elements.turtle_down.y then
                table.insert(state.user_input, 'turtle ' .. turtle_id .. ' go down')
            elseif monitor_touch.x == elements.turtle_left.x and monitor_touch.y == elements.turtle_left.y then
                table.insert(state.user_input, 'turtle ' .. turtle_id .. ' go left')
            elseif monitor_touch.x == elements.turtle_right.x and monitor_touch.y == elements.turtle_right.y then
                table.insert(state.user_input, 'turtle ' .. turtle_id .. ' go right')
            elseif turtle.data.turtle_type == 'mining' then
                if monitor_touch.x == elements.turtle_dig_up.x and monitor_touch.y == elements.turtle_dig_up.y then
                    table.insert(state.user_input, 'turtle ' .. turtle_id .. ' digblock up')
                elseif monitor_touch.x == elements.turtle_dig.x and monitor_touch.y == elements.turtle_dig.y then
                    table.insert(state.user_input, 'turtle ' .. turtle_id .. ' digblock forward')
                elseif monitor_touch.x == elements.turtle_dig_down.x and monitor_touch.y == elements.turtle_dig_down.y then
                    table.insert(state.user_input, 'turtle ' .. turtle_id .. ' digblock down')
                end
            end
        end
        
        turtle_id = turtle_ids[selected]
        turtle = state.turtles[turtle_id]
        
        background_color = colors.black
        term.setBackgroundColor(background_color)
        monitor.clear()
        
        if turtle.last_update + config.turtle_timeout < os.clock() then
            term.setCursorPos(elements.turtle_lost.x, elements.turtle_lost.y)
            term.setTextColor(colors.red)
            term.write('CONNECTION LOST')
        end
        
        local x_position = elements.turtle_id.x
        for decimal_string in string.format('%04d', turtle_id):gmatch"." do
            for y_offset, line in pairs(decimals[tonumber(decimal_string)]) do
                term.setCursorPos(x_position, elements.turtle_id.y + y_offset - 1)
                for char in line:gmatch"." do
                    if char == '#' then
                        term.setBackgroundColor(colors.green)
                    else
                        term.setBackgroundColor(colors.black)
                    end
                    term.write(' ')
                end
            end
            x_position = x_position + 6
        end
        
        -- Display turtle version below turtle ID
        term.setCursorPos(elements.turtle_id.x, elements.turtle_id.y + 5)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.write('Version: ')
        if turtle.data.version then
            local turtle_version_str = format_version(turtle.data.version)
            if turtle_version_str then
                -- Check if turtle version is out of date compared to hub
                local hub_version = get_version()
                local is_out_of_date = false
                if hub_version and turtle.data.version then
                    -- Compare versions (simple comparison)
                    if turtle.data.version.major < hub_version.major or
                       (turtle.data.version.major == hub_version.major and turtle.data.version.minor < hub_version.minor) or
                       (turtle.data.version.major == hub_version.major and turtle.data.version.minor == hub_version.minor and turtle.data.version.hotfix < hub_version.hotfix) then
                        is_out_of_date = true
                    end
                end
                
                if is_out_of_date then
                    term.setTextColor(colors.red)
                else
                    term.setTextColor(colors.yellow)
                end
                term.write('v' .. turtle_version_str)
            else
                term.setTextColor(colors.gray)
                term.write('unknown')
            end
        else
            term.setTextColor(colors.gray)
            term.write('unknown')
        end
        
        term.setCursorPos(elements.turtle_face.x + 1, elements.turtle_face.y)
        term.setBackgroundColor(colors.yellow)
        term.write('       ')
        term.setCursorPos(elements.turtle_face.x + 1, elements.turtle_face.y + 1)
        term.setBackgroundColor(colors.yellow)
        term.write(' ')
        term.setBackgroundColor(colors.gray)
        term.write('     ')
        term.setBackgroundColor(colors.yellow)
        term.write(' ')
        term.setCursorPos(elements.turtle_face.x + 1, elements.turtle_face.y + 2)
        term.setBackgroundColor(colors.yellow)
        term.write('       ')
        term.setCursorPos(elements.turtle_face.x + 1, elements.turtle_face.y + 3)
        term.setBackgroundColor(colors.yellow)
        term.write('       ')
        term.setCursorPos(elements.turtle_face.x + 1, elements.turtle_face.y + 4)
        term.setBackgroundColor(colors.yellow)
        term.write('       ')
        
        if turtle.data.peripheral_right == 'modem' then
            term.setBackgroundColor(colors.lightGray)
            term.setCursorPos(elements.turtle_face.x, elements.turtle_face.y + 1)
            term.write(' ')
            term.setCursorPos(elements.turtle_face.x, elements.turtle_face.y + 2)
            term.write(' ')
            term.setCursorPos(elements.turtle_face.x, elements.turtle_face.y + 3)
            term.write(' ')
        elseif turtle.data.peripheral_right == 'pick' then
            term.setBackgroundColor(colors.cyan)
            term.setCursorPos(elements.turtle_face.x, elements.turtle_face.y + 1)
            term.write(' ')
            term.setCursorPos(elements.turtle_face.x, elements.turtle_face.y + 2)
            term.write(' ')
            term.setBackgroundColor(colors.brown)
            term.setCursorPos(elements.turtle_face.x, elements.turtle_face.y + 3)
            term.write(' ')
        elseif turtle.data.peripheral_right == 'chunkLoader' then
            term.setBackgroundColor(colors.gray)
            term.setCursorPos(elements.turtle_face.x, elements.turtle_face.y + 1)
            term.write(' ')
            term.setCursorPos(elements.turtle_face.x, elements.turtle_face.y + 3)
            term.write(' ')
            term.setBackgroundColor(colors.blue)
            term.setCursorPos(elements.turtle_face.x, elements.turtle_face.y + 2)
            term.write(' ')
        elseif turtle.data.peripheral_right == 'chunky' then
            term.setBackgroundColor(colors.white)
            term.setCursorPos(elements.turtle_face.x, elements.turtle_face.y + 1)
            term.write(' ')
            term.setCursorPos(elements.turtle_face.x, elements.turtle_face.y + 3)
            term.write(' ')
            term.setBackgroundColor(colors.red)
            term.setCursorPos(elements.turtle_face.x, elements.turtle_face.y + 2)
            term.write(' ')
        end
        
        if turtle.data.peripheral_left == 'modem' then
            term.setBackgroundColor(colors.lightGray)
            term.setCursorPos(elements.turtle_face.x + 8, elements.turtle_face.y + 1)
            term.write(' ')
            term.setCursorPos(elements.turtle_face.x + 8, elements.turtle_face.y + 2)
            term.write(' ')
            term.setCursorPos(elements.turtle_face.x + 8, elements.turtle_face.y + 3)
            term.write(' ')
        elseif turtle.data.peripheral_left == 'pick' then
            term.setBackgroundColor(colors.cyan)
            term.setCursorPos(elements.turtle_face.x + 8, elements.turtle_face.y + 1)
            term.write(' ')
            term.setCursorPos(elements.turtle_face.x + 8, elements.turtle_face.y + 2)
            term.write(' ')
            term.setBackgroundColor(colors.brown)
            term.setCursorPos(elements.turtle_face.x + 8, elements.turtle_face.y + 3)
            term.write(' ')
        elseif turtle.data.peripheral_left == 'chunkLoader' then
            term.setBackgroundColor(colors.gray)
            term.setCursorPos(elements.turtle_face.x + 8, elements.turtle_face.y + 1)
            term.write(' ')
            term.setCursorPos(elements.turtle_face.x + 8, elements.turtle_face.y + 3)
            term.write(' ')
            term.setBackgroundColor(colors.blue)
            term.setCursorPos(elements.turtle_face.x + 8, elements.turtle_face.y + 2)
            term.write(' ')
        elseif turtle.data.peripheral_left == 'chunky' then
            term.setBackgroundColor(colors.white)
            term.setCursorPos(elements.turtle_face.x + 8, elements.turtle_face.y + 1)
            term.write(' ')
            term.setCursorPos(elements.turtle_face.x + 8, elements.turtle_face.y + 3)
            term.write(' ')
            term.setBackgroundColor(colors.red)
            term.setCursorPos(elements.turtle_face.x + 8, elements.turtle_face.y + 2)
            term.write(' ')
        end
        
        term.setBackgroundColor(background_color)
        
        term.setCursorPos(elements.turtle_data.x, elements.turtle_data.y)
        term.setTextColor(colors.white)
        term.write('State: ')
        term.setTextColor(colors.green)
        term.write(turtle.state)
        
        term.setCursorPos(elements.turtle_data.x, elements.turtle_data.y + 1)
        term.setTextColor(colors.white)
        term.write('X: ')
        term.setTextColor(colors.green)
        if turtle.data.location then
            term.write(turtle.data.location.x)
        end
        
        term.setCursorPos(elements.turtle_data.x, elements.turtle_data.y + 2)
        term.setTextColor(colors.white)
        term.write('Y: ')
        term.setTextColor(colors.green)
        if turtle.data.location then
            term.write(turtle.data.location.y)
        end
        
        term.setCursorPos(elements.turtle_data.x, elements.turtle_data.y + 3)
        term.setTextColor(colors.white)
        term.write('Z: ')
        term.setTextColor(colors.green)
        if turtle.data.location then
            term.write(turtle.data.location.z)
        end
        
        term.setCursorPos(elements.turtle_data.x, elements.turtle_data.y + 4)
        term.setTextColor(colors.white)
        term.write('Facing: ')
        term.setTextColor(colors.green)
        term.write(turtle.data.orientation)
        
        term.setCursorPos(elements.turtle_data.x, elements.turtle_data.y + 5)
        term.setTextColor(colors.white)
        term.write('Fuel: ')
        term.setTextColor(colors.green)
        term.write(turtle.data.fuel_level)
        
        term.setTextColor(colors.white)
        
        term.setCursorPos(elements.turtle_return.x, elements.turtle_return.y)
        term.setBackgroundColor(colors.green)
        term.write('*')
        term.setBackgroundColor(colors.brown)
        term.write('-RETURN')
        
        term.setCursorPos(elements.turtle_reboot.x, elements.turtle_reboot.y)
        term.setBackgroundColor(colors.green)
        term.write('*')
        term.setBackgroundColor(colors.brown)
        term.write('-REBOOT')
        
        term.setCursorPos(elements.turtle_halt.x, elements.turtle_halt.y)
        term.setBackgroundColor(colors.green)
        term.write('*')
        term.setBackgroundColor(colors.brown)
        term.write('-HALT')
        
        term.setCursorPos(elements.turtle_clear.x, elements.turtle_clear.y)
        term.setBackgroundColor(colors.green)
        term.write('*')
        term.setBackgroundColor(colors.brown)
        term.write('-CLEAR')
        
        term.setCursorPos(elements.turtle_reset.x, elements.turtle_reset.y)
        term.setBackgroundColor(colors.green)
        term.write('*')
        term.setBackgroundColor(colors.brown)
        term.write('-RESET')
        
        term.setCursorPos(elements.turtle_find.x, elements.turtle_find.y)
        term.setBackgroundColor(colors.green)
        term.write('*')
        term.setBackgroundColor(colors.brown)
        term.write('-FIND')
        
        term.setCursorPos(elements.turtle_forward.x, elements.turtle_forward.y)
        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.green)
        term.write('^')
        term.setTextColor(colors.gray)
        term.setBackgroundColor(background_color)
        term.write('-FORWARD')
        
        term.setCursorPos(elements.turtle_back.x, elements.turtle_back.y)
        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.green)
        term.write('V')
        term.setTextColor(colors.gray)
        term.setBackgroundColor(background_color)
        term.write('-BACK')
        
        term.setCursorPos(elements.turtle_up.x, elements.turtle_up.y)
        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.green)
        term.write('^')
        term.setTextColor(colors.gray)
        term.setBackgroundColor(background_color)
        term.write('-UP')
        
        term.setCursorPos(elements.turtle_down.x, elements.turtle_down.y)
        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.green)
        term.write('V')
        term.setTextColor(colors.gray)
        term.setBackgroundColor(background_color)
        term.write('-DOWN')
        
        term.setCursorPos(elements.turtle_left.x, elements.turtle_left.y)
        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.green)
        term.write('<')
        term.setTextColor(colors.gray)
        term.setBackgroundColor(background_color)
        term.write('-LEFT')
        
        term.setCursorPos(elements.turtle_right.x, elements.turtle_right.y)
        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.green)
        term.write('>')
        term.setTextColor(colors.gray)
        term.setBackgroundColor(background_color)
        term.write('-RIGHT')
        
        term.setCursorPos(elements.turtle_dig_up.x, elements.turtle_dig_up.y)
        term.setTextColor(colors.white)
        if turtle.data.turtle_type == 'mining' then
            term.setBackgroundColor(colors.green)
        else
            term.setBackgroundColor(colors.gray)
        end
        term.write('^')
        
        term.setCursorPos(elements.turtle_dig.x, elements.turtle_dig.y)
        term.setTextColor(colors.white)
        if turtle.data.turtle_type == 'mining' then
            term.setBackgroundColor(colors.green)
        else
            term.setBackgroundColor(colors.gray)
        end
        term.write('*')
        term.setTextColor(colors.gray)
        term.setBackgroundColor(background_color)
        term.write('-DIG')
        
        term.setCursorPos(elements.turtle_dig_down.x, elements.turtle_dig_down.y)
        term.setTextColor(colors.white)
        if turtle.data.turtle_type == 'mining' then
            term.setBackgroundColor(colors.green)
        else
            term.setBackgroundColor(colors.gray)
        end
        term.write('v')
        
        term.setTextColor(colors.white)
        if selected == 1 then
            term.setBackgroundColor(colors.gray)
        else
            term.setBackgroundColor(colors.green)
        end
        term.setCursorPos(elements.left.x, elements.left.y)
        term.write('<')
        if selected == #turtle_ids then
            term.setBackgroundColor(colors.gray)
        else
            term.setBackgroundColor(colors.green)
        end
        term.setCursorPos(elements.right.x, elements.right.y)
        term.write('>')
        term.setBackgroundColor(colors.red)
        term.setCursorPos(elements.viewer_exit.x, elements.viewer_exit.y)
        term.write('x')
        
        monitor.setVisible(true)
        monitor.setVisible(false)
        
        sleep(sleep_len)
    end
end


function statistics_viewer()
    term.redirect(monitor)
    
    local selected_turtle = 1
    local turtle_ids = {}
    local scroll_offset = 0
    local max_display = 15  -- Increased from 10
    
    -- Collect only mining turtle IDs (exclude chunk turtles)
    for _, turtle in pairs(state.turtles) do
        if turtle.data and turtle.data.turtle_type == 'mining' then
            table.insert(turtle_ids, turtle.id)
        end
    end
    
    table.sort(turtle_ids)
    
    while true do
        -- Handle monitor touches
        while #state.monitor_touches > 0 do
            local monitor_touch = table.remove(state.monitor_touches)
            local nav_y = monitor_height
            
            -- Exit button (top-left or bottom-right)
            if (monitor_touch.x == elements.viewer_exit.x and monitor_touch.y == elements.viewer_exit.y) or
               (monitor_touch.x >= monitor_width - 3 and monitor_touch.x <= monitor_width and monitor_touch.y == nav_y) then
                return
            -- Previous turtle button (<)
            elseif monitor_touch.x == 1 and monitor_touch.y == nav_y then
                selected_turtle = math.max(selected_turtle - 1, 1)
                if selected_turtle <= scroll_offset then
                    scroll_offset = math.max(selected_turtle - 1, 0)
                end
            -- Next turtle button (>)
            elseif monitor_touch.x == 8 and monitor_touch.y == nav_y then
                selected_turtle = math.min(selected_turtle + 1, #turtle_ids)
                if selected_turtle > scroll_offset + max_display then
                    scroll_offset = selected_turtle - max_display
                end
            -- Scroll up button (^)
            elseif monitor_touch.x == 16 and monitor_touch.y == nav_y then
                scroll_offset = math.max(scroll_offset - 1, 0)
                if selected_turtle > scroll_offset + max_display then
                    selected_turtle = math.min(selected_turtle, scroll_offset + max_display)
                end
            -- Scroll down button (v)
            elseif monitor_touch.x == 22 and monitor_touch.y == nav_y then
                scroll_offset = math.min(scroll_offset + 1, math.max(0, #turtle_ids - max_display))
                if selected_turtle <= scroll_offset then
                    selected_turtle = math.min(selected_turtle, scroll_offset + 1)
                end
            end
        end
        
        background_color = colors.black
        term.setBackgroundColor(background_color)
        monitor.clear()
        
        -- Title (offset to avoid exit button)
        term.setCursorPos(2, 1)
        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.green)
        term.write('STATISTICS')
        term.setBackgroundColor(background_color)
        
        -- Exit button (top-left)
        term.setBackgroundColor(colors.red)
        term.setCursorPos(elements.viewer_exit.x, elements.viewer_exit.y)
        term.write('x')
        term.setBackgroundColor(background_color)
        
        -- Calculate aggregate statistics (only mining turtles)
        local total_blocks = 0
        local total_ores = 0
        local aggregate_ore_counts = {}
        local mining_turtle_count = 0
        
        for _, turtle_id in pairs(turtle_ids) do
            local turtle = state.turtles[turtle_id]
            if turtle.data and turtle.data.turtle_type == 'mining' then
                mining_turtle_count = mining_turtle_count + 1
                if turtle.data.statistics then
                    total_blocks = total_blocks + (turtle.data.statistics.blocks_mined or 0)
                    total_ores = total_ores + (turtle.data.statistics.ores_mined or 0)
                    if turtle.data.statistics.ore_counts then
                        for ore_name, count in pairs(turtle.data.statistics.ore_counts) do
                            aggregate_ore_counts[ore_name] = (aggregate_ore_counts[ore_name] or 0) + count
                        end
                    end
                end
            end
        end
        
        -- Display aggregate stats with better formatting
        term.setCursorPos(1, 2)
        term.setTextColor(colors.yellow)
        term.write('Mining Turtles: ')
        term.setTextColor(colors.green)
        term.write(mining_turtle_count)
        
        term.setCursorPos(25, 2)
        term.setTextColor(colors.yellow)
        term.write('Total Blocks: ')
        term.setTextColor(colors.green)
        term.write(string.format("%8d", total_blocks))
        
        term.setCursorPos(1, 3)
        term.setTextColor(colors.yellow)
        term.write('Total Ores Mined: ')
        term.setTextColor(colors.green)
        term.write(string.format("%8d", total_ores))
        
        -- Display top ores with better formatting
        local top_ores = {}
        for ore_name, count in pairs(aggregate_ore_counts) do
            table.insert(top_ores, {name = ore_name, count = count})
        end
        table.sort(top_ores, function(a, b) return a.count > b.count end)
        
        term.setCursorPos(1, 4)
        term.setTextColor(colors.yellow)
        term.write('Top Ores:')
        
        local ore_y = 5
        for i = 1, math.min(6, #top_ores) do
            term.setCursorPos(3, ore_y)
            term.setTextColor(colors.gray)
            local short_name = top_ores[i].name:match("([^:]+)$") or top_ores[i].name
            -- Remove common prefixes for readability
            short_name = short_name:gsub("^minecraft:", "")
            short_name = short_name:gsub("_", " ")
            if #short_name > 20 then
                short_name = short_name:sub(1, 17) .. "..."
            end
            term.write(string.format("%-20s", short_name))
            term.setTextColor(colors.green)
            term.write(string.format("%6d", top_ores[i].count))
            ore_y = ore_y + 1
        end
        
        -- Turtle list header with better spacing
        local header_y = ore_y + 1
        term.setCursorPos(1, header_y)
        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.brown)
        term.write(string.format("%-10s %10s %10s", "Turtle ID", "Blocks", "Ores"))
        term.setBackgroundColor(background_color)
        
        -- Display turtle list with better formatting
        local display_y = header_y + 1
        for i = scroll_offset + 1, math.min(scroll_offset + max_display, #turtle_ids) do
            local turtle_id = turtle_ids[i]
            local turtle = state.turtles[turtle_id]
            
            if display_y <= monitor_height - 2 then
                -- Highlight selected turtle
                if i == selected_turtle then
                    term.setBackgroundColor(colors.gray)
                else
                    term.setBackgroundColor(background_color)
                end
                
                term.setCursorPos(1, display_y)
                term.setTextColor(colors.white)
                term.write(string.format("%04d", turtle_id))
                
                term.setCursorPos(11, display_y)
                if turtle.data and turtle.data.statistics then
                    term.setTextColor(colors.green)
                    term.write(string.format("%10d", turtle.data.statistics.blocks_mined or 0))
                    term.setCursorPos(21, display_y)
                    term.write(string.format("%10d", turtle.data.statistics.ores_mined or 0))
                else
                    term.setTextColor(colors.gray)
                    term.write(string.format("%10d", 0))
                    term.setCursorPos(21, display_y)
                    term.write(string.format("%10d", 0))
                end
                
                display_y = display_y + 1
            end
        end
        
        -- Navigation buttons
        local nav_y = monitor_height
        term.setCursorPos(1, nav_y)
        term.setBackgroundColor(colors.green)
        term.setTextColor(colors.white)
        term.write('<')
        term.setBackgroundColor(background_color)
        term.setTextColor(colors.gray)
        term.write(' Prev')
        
        term.setCursorPos(8, nav_y)
        term.setBackgroundColor(colors.green)
        term.setTextColor(colors.white)
        term.write('>')
        term.setBackgroundColor(background_color)
        term.setTextColor(colors.gray)
        term.write(' Next')
        
        term.setCursorPos(16, nav_y)
        term.setBackgroundColor(colors.green)
        term.setTextColor(colors.white)
        term.write('^')
        term.setBackgroundColor(background_color)
        term.setTextColor(colors.gray)
        term.write(' Up')
        
        term.setCursorPos(22, nav_y)
        term.setBackgroundColor(colors.green)
        term.setTextColor(colors.white)
        term.write('v')
        term.setBackgroundColor(background_color)
        term.setTextColor(colors.gray)
        term.write(' Down')
        
        -- Exit button already at top-left, no need for duplicate
        
        -- Show selected turtle details with better formatting
        if #turtle_ids > 0 and selected_turtle <= #turtle_ids then
            local turtle_id = turtle_ids[selected_turtle]
            local turtle = state.turtles[turtle_id]
            
            if turtle.data and turtle.data.statistics then
                local detail_x = 35
                local detail_y = 2
                
                if detail_x < monitor_width - 15 then
                    term.setCursorPos(detail_x, detail_y)
                    term.setTextColor(colors.yellow)
                    term.write('Turtle ' .. string.format("%04d", turtle_id))
                    
                    detail_y = detail_y + 1
                    term.setCursorPos(detail_x, detail_y)
                    term.setTextColor(colors.white)
                    term.write('Blocks: ')
                    term.setTextColor(colors.green)
                    term.write(string.format("%8d", turtle.data.statistics.blocks_mined or 0))
                    
                    detail_y = detail_y + 1
                    term.setCursorPos(detail_x, detail_y)
                    term.setTextColor(colors.white)
                    term.write('Ores: ')
                    term.setTextColor(colors.green)
                    term.write(string.format("%8d", turtle.data.statistics.ores_mined or 0))
                    
                    if turtle.data.statistics.ore_counts then
                        detail_y = detail_y + 2
                        term.setCursorPos(detail_x, detail_y)
                        term.setTextColor(colors.yellow)
                        term.write('Ore Breakdown:')
                        
                        local turtle_ores = {}
                        for ore_name, count in pairs(turtle.data.statistics.ore_counts) do
                            table.insert(turtle_ores, {name = ore_name, count = count})
                        end
                        table.sort(turtle_ores, function(a, b) return a.count > b.count end)
                        
                        detail_y = detail_y + 1
                        for i = 1, math.min(10, #turtle_ores) do
                            if detail_y <= monitor_height - 1 then
                                term.setCursorPos(detail_x, detail_y)
                                term.setTextColor(colors.gray)
                                local short_name = turtle_ores[i].name:match("([^:]+)$") or turtle_ores[i].name
                                short_name = short_name:gsub("^minecraft:", "")
                                short_name = short_name:gsub("_", " ")
                                if #short_name > 22 then
                                    short_name = short_name:sub(1, 19) .. "..."
                                end
                                term.write(string.format("%-22s", short_name))
                                term.setTextColor(colors.green)
                                term.write(string.format("%6d", turtle_ores[i].count))
                                detail_y = detail_y + 1
                            end
                        end
                    end
                end
            end
        end
        
        monitor.setVisible(true)
        monitor.setVisible(false)
        
        sleep(sleep_len)
    end
end


function get_version()
    -- Load version from version.lua file
    local version_file_path = "/version.lua"
    if not fs.exists(version_file_path) then
        version_file_path = "/disk/hub_files/version.lua"
    end
    if not fs.exists(version_file_path) then
        return nil
    end
    
    local version_file = fs.open(version_file_path, "r")
    if not version_file then
        return nil
    end
    
    local version_code = version_file.readAll()
    version_file.close()
    
    -- Execute version code in a safe environment
    local version_func = load(version_code)
    if version_func then
        local success, version = pcall(version_func)
        if success and version and type(version) == "table" then
            return version
        end
    end
    return nil
end

function format_version(version)
    -- Format version table as "MAJOR.MINOR.HOTFIX" or "MAJOR.MINOR.HOTFIX-DEV"
    if version and type(version) == "table" then
        local version_str = string.format("%d.%d.%d", version.major or 0, version.minor or 0, version.hotfix or 0)
        -- Add DEV suffix if present
        if version.dev_suffix == "-DEV" or version.dev == true then
            version_str = version_str .. "-DEV"
        end
        return version_str
    end
    return nil
end

function menu()
    term.redirect(monitor)
    
    while true do
        while #state.monitor_touches > 0 do
            local monitor_touch = table.remove(state.monitor_touches)
            if monitor_touch.x == elements.viewer_exit.x and monitor_touch.y == elements.viewer_exit.y then
                term.redirect(monitor.restore_to)
                return
            elseif monitor_touch.x == elements.menu_toggle.x and monitor_touch.y == elements.menu_toggle.y then
                if state.on then
                    table.insert(state.user_input, 'off')
                else
                    table.insert(state.user_input, 'on')
                end
            elseif monitor_touch.x == elements.menu_update.x and monitor_touch.y == elements.menu_update.y then
                table.insert(state.user_input, 'update')
            elseif monitor_touch.x == elements.menu_return.x and monitor_touch.y == elements.menu_return.y then
                table.insert(state.user_input, 'return')
            elseif monitor_touch.x == elements.menu_reboot.x and monitor_touch.y == elements.menu_reboot.y then
                table.insert(state.user_input, 'reboot')
            elseif monitor_touch.x == elements.menu_halt.x and monitor_touch.y == elements.menu_halt.y then
                table.insert(state.user_input, 'halt')
            elseif monitor_touch.x == elements.menu_clear.x and monitor_touch.y == elements.menu_clear.y then
                table.insert(state.user_input, 'clear')
            elseif monitor_touch.x == elements.menu_reset.x and monitor_touch.y == elements.menu_reset.y then
                table.insert(state.user_input, 'reset')
            elseif monitor_touch.x == elements.menu_statistics.x and monitor_touch.y == elements.menu_statistics.y then
                statistics_viewer()
                -- Ensure term is redirected back to monitor after statistics_viewer returns
                term.redirect(monitor)
            end
        end
        
        term.setBackgroundColor(colors.black)
        monitor.clear()
        
        term.setTextColor(colors.white)
        term.setCursorPos(elements.menu_title.x, elements.menu_title.y)
        term.write('WORLD')
        
        -- Display version number
        local version = get_version()
        if version then
            local version_str = format_version(version)
            if version_str then
                term.setCursorPos(elements.version.x, elements.version.y)
                term.setTextColor(colors.gray)
                term.write("v" .. version_str)
                term.setTextColor(colors.white)
            end
        end
        
        for y_offset, line in pairs(menu_lines) do
            term.setCursorPos(elements.menu_title.x, elements.menu_title.y + y_offset)
            for char in line:gmatch"." do
                if char == '#' then
                    if state.on then
                        term.setBackgroundColor(colors.lime)
                    else
                        term.setBackgroundColor(colors.red)
                    end
                else
                    term.setBackgroundColor(colors.black)
                end
                term.write(' ')
            end
        end
        
        term.setBackgroundColor(colors.red)
        term.setCursorPos(elements.viewer_exit.x, elements.viewer_exit.y)
        term.write('x')
        term.setBackgroundColor(colors.green)
        term.setCursorPos(elements.menu_toggle.x, elements.menu_toggle.y)
        term.write('*')
        term.setCursorPos(elements.menu_return.x, elements.menu_return.y)
        term.write('*')
        term.setCursorPos(elements.menu_update.x, elements.menu_update.y)
        term.write('*')
        term.setCursorPos(elements.menu_reboot.x, elements.menu_reboot.y)
        term.write('*')
        term.setCursorPos(elements.menu_halt.x, elements.menu_halt.y)
        term.write('*')
        term.setCursorPos(elements.menu_clear.x, elements.menu_clear.y)
        term.write('*')
        term.setCursorPos(elements.menu_reset.x, elements.menu_reset.y)
        term.write('*')
        term.setCursorPos(elements.menu_statistics.x, elements.menu_statistics.y)
        term.write('*')
        term.setBackgroundColor(colors.brown)
        term.setCursorPos(elements.menu_toggle.x + 1, elements.menu_toggle.y)
        term.write('-TOGGLE POWER')
        term.setCursorPos(elements.menu_update.x + 1, elements.menu_update.y)
        term.write('-UPDATE')
        term.setCursorPos(elements.menu_return.x + 1, elements.menu_return.y)
        term.write('-RETURN')
        term.setCursorPos(elements.menu_reboot.x + 1, elements.menu_reboot.y)
        term.write('-REBOOT')
        term.setCursorPos(elements.menu_halt.x + 1, elements.menu_halt.y)
        term.write('-HALT')
        term.setCursorPos(elements.menu_clear.x + 1, elements.menu_clear.y)
        term.write('-CLEAR')
        term.setCursorPos(elements.menu_reset.x + 1, elements.menu_reset.y)
        term.write('-RESET')
        term.setCursorPos(elements.menu_statistics.x + 1, elements.menu_statistics.y)
        term.write('-STATISTICS')
        
        monitor.setVisible(true)
        monitor.setVisible(false)
        
        sleep(sleep_len)
    end
end


function draw_location(location, color)
    if location then
        local pixel = {
            -- x = monitor_width  - math.floor((location.x - min_location.x) / zoom_factor),
            -- y = monitor_height - math.floor((location.z - min_location.z) / zoom_factor),
            x = math.floor((location.x - min_location.x) / zoom_factor),
            y = math.floor((location.z - min_location.z) / zoom_factor),
        }
        if pixel.x >= 1 and pixel.x <= monitor_width and pixel.y >= 1 and pixel.y <= monitor_height then
            if color then
                paintutils.drawPixel(pixel.x, pixel.y, color)
            end
            return pixel
        end
    end
end
    

function draw_monitor()
    
    term.redirect(monitor)
    term.setBackgroundColor(colors.black)
    monitor.clear()
    
    zoom_factor = math.pow(2, monitor_zoom_level)
    min_location = {
        x = monitor_location.x - math.floor(monitor_width  * zoom_factor / 2) - 1,
        z = monitor_location.z - math.floor(monitor_height * zoom_factor / 2) - 1,
    }
    
    local mined = {}
    local xz
    for x = min_location.x, min_location.x + (monitor_width * zoom_factor), zoom_factor do
        for z = min_location.z, min_location.z + (monitor_height * zoom_factor), zoom_factor do
            xz = x .. ',' .. z
            if not mined[xz] then
                -- Check if this block is mined
                if state.mined_blocks and state.mined_blocks[x] and state.mined_blocks[x][z] then
                    mined[xz] = true
                    draw_location({x = x, z = z}, colors.lightGray)
                else
                    draw_location({x = x, z = z}, colors.gray)
                end
            end
        end
    end
    
    local pixel
    local special = {}
    
    local mine_enter = config.locations and config.locations.mine_enter or config.mine_entrance
    if mine_enter then
        pixel = draw_location(mine_enter, colors.blue)
        if pixel then
            special[pixel.x .. ',' .. pixel.y] = colors.blue
        end
    end
    
    -- Draw mining center (2 blocks below hub_reference)
    if config.mining_center then
        pixel = draw_location({x = config.mining_center.x, y = config.mining_center.y, z = config.mining_center.z}, colors.cyan)
        if pixel then
            special[pixel.x .. ',' .. pixel.y] = colors.cyan
        end
    end
    
    -- Draw turtle assigned blocks (if they have blocks assigned)
    for _, turtle in pairs(state.turtles) do
        if turtle.block then
            local mine_enter_y = (config.locations and config.locations.mine_enter and config.locations.mine_enter.y) or (config.mine_entrance and config.mine_entrance.y) or config.hub_reference.y
            pixel = draw_location({x = turtle.block.x, y = mine_enter_y, z = turtle.block.z}, colors.green)
            if pixel then
                special[pixel.x .. ',' .. pixel.y] = colors.green
            end
        end
    end
    
    term.setTextColor(colors.black)
    turtles = {}
    local str_pixel
    for _, turtle in pairs(state.turtles) do
        if turtle.data then
            local location = turtle.data.location
            if location and location.x and location.y then
                pixel = draw_location(location)
                if pixel then
                    term.setCursorPos(pixel.x, pixel.y)
                    str_pixel = pixel.x .. ',' .. pixel.y
                    if special[str_pixel] then
                        term.setBackgroundColor(special[str_pixel])
                    elseif turtle.last_update + config.turtle_timeout < os.clock() then
                        term.setBackgroundColor(colors.red)
                    else
                        term.setBackgroundColor(colors.yellow)
                    end
                    if not turtles[str_pixel] then
                        turtles[str_pixel] = {turtle.id}
                        term.write('-')
                    else
                        table.insert(turtles[str_pixel], turtle.id)
                        if #turtles[str_pixel] <= 9 then
                            term.write(#turtles[str_pixel])
                        else
                            term.write('+')
                        end
                    end
                end
            end
        end
    end
    
    for _, pocket in pairs(state.pockets) do
        local location = pocket.data.location
        if location and location.x and location.y then
            pixel = draw_location(location)
            if pixel then
                term.setCursorPos(pixel.x, pixel.y)
                str_pixel = pixel.x .. ',' .. pixel.y
                if pocket.last_update + config.pocket_timeout < os.clock() then
                    term.setBackgroundColor(colors.red)
                else
                    term.setBackgroundColor(colors.green)
                end
                term.write('M')
            end
        end
    end
    
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.green)
    term.setCursorPos(elements.menu.x, elements.menu.y)
    term.write('*')
    term.setCursorPos(elements.all_turtles.x, elements.all_turtles.y)
    term.write('*')
    term.setCursorPos(elements.mining_turtles.x, elements.mining_turtles.y)
    term.write('*')
    term.setCursorPos(elements.center.x, elements.center.y)
    term.write('*')
    term.setCursorPos(elements.up.x, elements.up.y)
    term.write('N')
    term.setCursorPos(elements.down.x, elements.down.y)
    term.write('S')
    term.setCursorPos(elements.left.x, elements.left.y)
    term.write('W')
    term.setCursorPos(elements.right.x, elements.right.y)
    term.write('E')
    term.setCursorPos(elements.zoom_in.x, elements.zoom_in.y)
    term.write('+')
    term.setCursorPos(elements.zoom_out.x, elements.zoom_out.y)
    term.write('-')
    term.setBackgroundColor(colors.brown)
    local mined_count = 0
    if state.mined_blocks then
        for x, z_table in pairs(state.mined_blocks) do
            for z, _ in pairs(z_table) do
                mined_count = mined_count + 1
            end
        end
    end
    term.setCursorPos(elements.level_indicator.x, elements.level_indicator.y)
    term.write(string.format('MINED: %4d', mined_count))
    term.setCursorPos(elements.zoom_indicator.x, elements.zoom_indicator.y)
    term.write('ZOOM: ' .. monitor_zoom_level)
    term.setCursorPos(elements.x_indicator.x, elements.x_indicator.y)
    term.write('X: ' .. monitor_location.x)
    term.setCursorPos(elements.z_indicator.x, elements.z_indicator.y)
    term.write('Z: ' .. monitor_location.z)
    term.setCursorPos(elements.center_indicator.x, elements.center_indicator.y)
    term.write('-CENTER')
    term.setCursorPos(elements.menu_indicator.x, elements.menu_indicator.y)
    term.write('-MENU')
    term.setCursorPos(elements.all_indicator.x, elements.all_indicator.y)
    term.write('ALL-')
    term.setCursorPos(elements.mining_indicator.x, elements.mining_indicator.y)
    term.write('MINING-')
    
    term.redirect(monitor.restore_to)
end


function touch_monitor(monitor_touch)
    if monitor_touch.x == elements.up.x and monitor_touch.y == elements.up.y then
        monitor_location.z = monitor_location.z - zoom_factor
    elseif monitor_touch.x == elements.down.x and monitor_touch.y == elements.down.y then
        monitor_location.z = monitor_location.z + zoom_factor
    elseif monitor_touch.x == elements.left.x and monitor_touch.y == elements.left.y then
        monitor_location.x = monitor_location.x - zoom_factor
    elseif monitor_touch.x == elements.right.x and monitor_touch.y == elements.right.y then
        monitor_location.x = monitor_location.x + zoom_factor
    elseif monitor_touch.x == elements.zoom_in.x and monitor_touch.y == elements.zoom_in.y then
        monitor_zoom_level = math.max(monitor_zoom_level - 1, 0)
    elseif monitor_touch.x == elements.zoom_out.x and monitor_touch.y == elements.zoom_out.y then
        monitor_zoom_level = math.min(monitor_zoom_level + 1, config.monitor_max_zoom_level)
    elseif monitor_touch.x == elements.menu.x and monitor_touch.y == elements.menu.y then
        menu()
    elseif monitor_touch.x == elements.center.x and monitor_touch.y == elements.center.y then
        if config.mining_center then
            monitor_location = {x = config.mining_center.x, z = config.mining_center.z}
        elseif config.locations and config.locations.mine_enter then
            monitor_location = {x = config.locations.mine_enter.x, z = config.locations.mine_enter.z}
        else
            monitor_location = {x = config.mine_entrance.x, z = config.mine_entrance.z}
        end
    elseif monitor_touch.x == elements.all_turtles.x and monitor_touch.y == elements.all_turtles.y then
        local turtle_ids = {}
        for _, turtle in pairs(state.turtles) do
            if turtle.data then
                table.insert(turtle_ids, turtle.id)
            end
        end
        if #turtle_ids then
            turtle_viewer(turtle_ids)
        end
    elseif monitor_touch.x == elements.mining_turtles.x and monitor_touch.y == elements.mining_turtles.y then
        local turtle_ids = {}
        for _, turtle in pairs(state.turtles) do
            if turtle.data and turtle.data.turtle_type == 'mining' then
                table.insert(turtle_ids, turtle.id)
            end
        end
        if #turtle_ids then
            turtle_viewer(turtle_ids)
        end
    else
        local str_pos = monitor_touch.x .. ',' .. monitor_touch.y
        if turtles[str_pos] then
            turtle_viewer(turtles[str_pos])
        end
    end
end


function init_elements()
    elements = {
        up               = {x = math.ceil(monitor_width / 2), y = 1                            },
        down             = {x = math.ceil(monitor_width / 2), y = monitor_height               },
        left             = {x = 1,                            y = math.ceil(monitor_height / 2)},
        right            = {x = monitor_width,                y = math.ceil(monitor_height / 2)},
        level_up         = {x = monitor_width, y =  1},
        level_down       = {x = monitor_width - 11, y =  1},
        level_indicator  = {x = monitor_width - 10, y =  1},
        zoom_in          = {x = monitor_width, y =  2},
        zoom_out         = {x = monitor_width - 8, y = 2},
        zoom_indicator   = {x = monitor_width - 7, y = 2},
        all_turtles      = {x = monitor_width, y = monitor_height-1},
        all_indicator    = {x = monitor_width - 4, y = monitor_height-1},
        mining_turtles   = {x = monitor_width, y = monitor_height},
        mining_indicator = {x = monitor_width - 7, y = monitor_height},
        menu             = {x =  1, y = monitor_height},
        menu_indicator   = {x =  2, y = monitor_height},
        center           = {x =  1, y =  1},
        center_indicator = {x =  2, y =  1},
        x_indicator      = {x =  1, y =  2},
        z_indicator      = {x =  1, y =  3},
        viewer_exit      = {x =  1, y =  1},
        version          = {x =  2, y =  1},
        turtle_face      = {x =  5, y =  2},
        turtle_id        = {x = 16, y =  2},
        turtle_lost      = {x = 13, y =  1},
        turtle_data      = {x =  4, y =  8},
        turtle_return    = {x = 26, y =  8},
        turtle_reboot    = {x = 26, y =  9},
        turtle_halt      = {x = 26, y = 10},
        turtle_clear     = {x = 26, y = 11},
        turtle_reset     = {x = 26, y = 12},
        turtle_find      = {x = 26, y = 13},
        turtle_forward   = {x = 10, y = 16},
        turtle_back      = {x = 10, y = 18},
        turtle_up        = {x = 23, y = 16},
        turtle_down      = {x = 23, y = 18},
        turtle_left      = {x =  6, y = 17},
        turtle_right     = {x = 14, y = 17},
        turtle_dig_up    = {x = 31, y = 16},
        turtle_dig       = {x = 31, y = 17},
        turtle_dig_down  = {x = 31, y = 18},
        menu_title       = {x =  7, y =  3},
        menu_toggle      = {x = 10, y = 11},
        menu_update      = {x = 10, y = 13},
        menu_return      = {x = 10, y = 14},
        menu_reboot      = {x = 10, y = 15},
        menu_halt        = {x = 10, y = 16},
        menu_clear       = {x = 10, y = 17},
        menu_reset       = {x = 10, y = 18},
        menu_statistics  = {x = 10, y = 19},
    }
end




function step()
    while #state.monitor_touches > 0 do
        touch_monitor(table.remove(state.monitor_touches))
    end
    draw_monitor()
    monitor.setVisible(true)
    sleep(sleep_len)
end


function main()
    sleep_len = 0.3
    
    local attached = peripheral.find('monitor')
    
    if not attached then
        error('No monitor connected.')
    end
    
    monitor_size = {attached.getSize()}
    monitor_width = monitor_size[1]
    monitor_height = monitor_size[2]
    
    if monitor_width < 29 or monitor_height < 12 then -- Must be at least that big
        return
    end
    
    monitor = window.create(attached, 1, 1, monitor_width, monitor_height)
    monitor.restore_to = term.current()
    monitor.clear()
    monitor.setVisible(true)
    monitor.setCursorPos(1, 1)
    
    -- Show loading message while waiting for state.mine
    term.redirect(monitor)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    monitor.clear()
    term.setCursorPos(1, 1)
    print("World Eater Hub")
    print("Initializing...")
    print("")
    print("Waiting for mine state...")
    term.redirect(monitor.restore_to)
    
    monitor_location = {x = config.locations.mine_enter.x, z = config.locations.mine_enter.z}
    monitor_zoom_level = config.default_monitor_zoom_level or 0
    
    init_elements()
    
    -- Wait for mine state to be initialized (state.mine or state.mined_blocks)
    local wait_count = 0
    while not state.mine and not state.mined_blocks do
        wait_count = wait_count + 1
        if wait_count % 4 == 0 then
            -- Update loading message every 2 seconds
            term.redirect(monitor)
            term.setCursorPos(1, 4)
            local dots = string.rep(".", (wait_count / 4) % 4)
            print("Waiting for mine state" .. dots .. "   ")
            term.redirect(monitor.restore_to)
        end
        sleep(0.5)
    end
    
    state.monitor_touches = {}
    while true do
        local status, caught_error = pcall(step)
        if not status then
            term.redirect(monitor.restore_to)
            error(caught_error)
        end
    end
end


main()