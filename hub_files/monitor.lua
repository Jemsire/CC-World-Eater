-- Current active tab
local current_tab = "menu" -- 'menu', 'map', 'turtles', 'stats'

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

function debug_print(string)
    term.redirect(monitor.restore_to)
    print(string)
    term.redirect(monitor)
end

function format_version(version)
    if not version or type(version) ~= "table" then
        return "unknown"
    end
    local version_str = string.format("%d.%d.%d", version.major or 0, version.minor or 0, version.hotfix or 0)
    if version.dev_suffix or version.dev then
        version_str = version_str .. "-DEV"
    end
    return version_str
end

function get_hub_version()
    if fs.exists("/version.lua") then
        local version_func = loadfile("/version.lua")
        if version_func then
            local success, version = pcall(version_func)
            if success and version and type(version) == "table" then
                return version
            end
        end
    end
    return nil
end

-- Cache for GitHub version check (only checked once on startup)
local github_version_cache = nil

function is_hub_up_to_date()
    local hub_version = get_hub_version()
    if not hub_version then
        return false
    end

    -- Use cached version (only checked once on startup)
    if not github_version_cache then
        return nil -- Unknown (not checked yet or can't check)
    end

    local comparison = github_api.compare_versions(hub_version, github_version_cache)
    -- Hub is up to date if versions are equal (comparison == 0)
    -- Or if hub is newer (comparison > 0)
    return comparison >= 0
end

function turtle_matches_hub(turtle_version)
    local hub_version = get_hub_version()
    if not hub_version or not turtle_version then
        return false
    end

    local comparison = github_api.compare_versions(turtle_version, hub_version)
    return comparison == 0
end

function is_turtle_up_to_date(turtle)
    -- Check if turtle version matches hub version
    if not turtle or not turtle.data or not turtle.data.version then
        return nil -- Unknown (no version data)
    end

    return turtle_matches_hub(turtle.data.version)
end

function turtle_viewer(turtle_ids)
    term.redirect(monitor)

    local selected = 1

    while true do
        -- Draw tab bar at top (preserve it)
        draw_tab_bar()
        
        local turtle_id = turtle_ids[selected]
        local turtle = state.turtles[turtle_id]

        -- RESOLVE MONITOR TOUCHES, EITHER BY AFFECTING THE DISPLAY OR INSERTING INTO USER_INPUT TABLE
        while #state.monitor_touches > 0 do
            local monitor_touch = table.remove(state.monitor_touches)
            -- Handle tab bar clicks (y = 1)
            if monitor_touch.y == 1 then
                if monitor_touch.x >= 2 and monitor_touch.x <= 7 then
                    current_tab = "menu"
                elseif monitor_touch.x >= 9 and monitor_touch.x <= 12 then
                    current_tab = "map"
                elseif monitor_touch.x >= 14 and monitor_touch.x <= 21 then
                    current_tab = "turtles"
                elseif monitor_touch.x >= 23 and monitor_touch.x <= 28 then
                    current_tab = "stats"
                end
                term.redirect(monitor.restore_to)
                return
            elseif monitor_touch.x == elements.left.x and monitor_touch.y == elements.left.y then
                selected = math.max(selected - 1, 1)
            elseif monitor_touch.x == elements.right.x and monitor_touch.y == elements.right.y then
                selected = math.min(selected + 1, #turtle_ids)
            elseif monitor_touch.x == elements.viewer_exit.x and monitor_touch.y == elements.viewer_exit.y then
                term.redirect(monitor.restore_to)
                return
            elseif monitor_touch.x == elements.turtle_return.x and monitor_touch.y == elements.turtle_return.y then
                table.insert(state.user_input, "return " .. turtle_id)
            elseif monitor_touch.x == elements.turtle_reboot.x and monitor_touch.y == elements.turtle_reboot.y then
                table.insert(state.user_input, "reboot " .. turtle_id)
            elseif monitor_touch.x == elements.turtle_halt.x and monitor_touch.y == elements.turtle_halt.y then
                table.insert(state.user_input, "halt " .. turtle_id)
            elseif monitor_touch.x == elements.turtle_clear.x and monitor_touch.y == elements.turtle_clear.y then
                table.insert(state.user_input, "clear " .. turtle_id)
            elseif monitor_touch.x == elements.turtle_reset.x and monitor_touch.y == elements.turtle_reset.y then
                table.insert(state.user_input, "reset " .. turtle_id)
            elseif monitor_touch.x == elements.turtle_update.x and monitor_touch.y == elements.turtle_update.y then
                table.insert(state.user_input, "update " .. turtle_id)
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
                table.insert(state.user_input, "turtle " .. turtle_id .. " go forward")
            elseif monitor_touch.x == elements.turtle_back.x and monitor_touch.y == elements.turtle_back.y then
                table.insert(state.user_input, "turtle " .. turtle_id .. " go back")
            elseif monitor_touch.x == elements.turtle_up.x and monitor_touch.y == elements.turtle_up.y then
                table.insert(state.user_input, "turtle " .. turtle_id .. " go up")
            elseif monitor_touch.x == elements.turtle_down.x and monitor_touch.y == elements.turtle_down.y then
                table.insert(state.user_input, "turtle " .. turtle_id .. " go down")
            elseif monitor_touch.x == elements.turtle_left.x and monitor_touch.y == elements.turtle_left.y then
                table.insert(state.user_input, "turtle " .. turtle_id .. " go left")
            elseif monitor_touch.x == elements.turtle_right.x and monitor_touch.y == elements.turtle_right.y then
                table.insert(state.user_input, "turtle " .. turtle_id .. " go right")
            elseif turtle.data.turtle_type == "mining" then
                if monitor_touch.x == elements.turtle_dig_up.x and monitor_touch.y == elements.turtle_dig_up.y then
                    table.insert(state.user_input, "turtle " .. turtle_id .. " digblock up")
                elseif monitor_touch.x == elements.turtle_dig.x and monitor_touch.y == elements.turtle_dig.y then
                    table.insert(state.user_input, "turtle " .. turtle_id .. " digblock forward")
                elseif monitor_touch.x == elements.turtle_dig_down.x and monitor_touch.y == elements.turtle_dig_down.y then
                    table.insert(state.user_input, "turtle " .. turtle_id .. " digblock down")
                end
            end
        end

        turtle_id = turtle_ids[selected]
        turtle = state.turtles[turtle_id]

        background_color = colors.black
        term.setBackgroundColor(background_color)
        -- Don't clear - tab bar is already drawn, just clear from line 2 onwards
        for y = 2, monitor_height do
            term.setCursorPos(1, y)
            term.clearLine()
        end

        if turtle.last_update + config.turtle_timeout < os.clock() then
            term.setCursorPos(elements.turtle_lost.x, elements.turtle_lost.y)
            term.setTextColor(colors.red)
            term.write("CONNECTION LOST")
        end

        local x_position = elements.turtle_id.x
        for decimal_string in string.format("%04d", turtle_id):gmatch "." do
            for y_offset, line in pairs(decimals[tonumber(decimal_string)]) do
                term.setCursorPos(x_position, elements.turtle_id.y + y_offset - 1)
                for char in line:gmatch "." do
                    if char == "#" then
                        term.setBackgroundColor(colors.green)
                    else
                        term.setBackgroundColor(colors.black)
                    end
                    term.write(" ")
                end
            end
            x_position = x_position + 6
        end

        term.setCursorPos(elements.turtle_face.x + 1, elements.turtle_face.y)
        term.setBackgroundColor(colors.yellow)
        term.write("       ")
        term.setCursorPos(elements.turtle_face.x + 1, elements.turtle_face.y + 1)
        term.setBackgroundColor(colors.yellow)
        term.write(" ")
        term.setBackgroundColor(colors.gray)
        term.write("     ")
        term.setBackgroundColor(colors.yellow)
        term.write(" ")
        term.setCursorPos(elements.turtle_face.x + 1, elements.turtle_face.y + 2)
        term.setBackgroundColor(colors.yellow)
        term.write("       ")
        term.setCursorPos(elements.turtle_face.x + 1, elements.turtle_face.y + 3)
        term.setBackgroundColor(colors.yellow)
        term.write("       ")
        term.setCursorPos(elements.turtle_face.x + 1, elements.turtle_face.y + 4)
        term.setBackgroundColor(colors.yellow)
        term.write("       ")

        if turtle.data.peripheral_right == "modem" then
            term.setBackgroundColor(colors.lightGray)
            term.setCursorPos(elements.turtle_face.x, elements.turtle_face.y + 1)
            term.write(" ")
            term.setCursorPos(elements.turtle_face.x, elements.turtle_face.y + 2)
            term.write(" ")
            term.setCursorPos(elements.turtle_face.x, elements.turtle_face.y + 3)
            term.write(" ")
        elseif turtle.data.peripheral_right == "pick" then
            term.setBackgroundColor(colors.cyan)
            term.setCursorPos(elements.turtle_face.x, elements.turtle_face.y + 1)
            term.write(" ")
            term.setCursorPos(elements.turtle_face.x, elements.turtle_face.y + 2)
            term.write(" ")
            term.setBackgroundColor(colors.brown)
            term.setCursorPos(elements.turtle_face.x, elements.turtle_face.y + 3)
            term.write(" ")
        elseif turtle.data.peripheral_right == "chunkLoader" then
            term.setBackgroundColor(colors.gray)
            term.setCursorPos(elements.turtle_face.x, elements.turtle_face.y + 1)
            term.write(" ")
            term.setCursorPos(elements.turtle_face.x, elements.turtle_face.y + 3)
            term.write(" ")
            term.setBackgroundColor(colors.blue)
            term.setCursorPos(elements.turtle_face.x, elements.turtle_face.y + 2)
            term.write(" ")
        elseif turtle.data.peripheral_right == "chunky" then
            term.setBackgroundColor(colors.white)
            term.setCursorPos(elements.turtle_face.x, elements.turtle_face.y + 1)
            term.write(" ")
            term.setCursorPos(elements.turtle_face.x, elements.turtle_face.y + 3)
            term.write(" ")
            term.setBackgroundColor(colors.red)
            term.setCursorPos(elements.turtle_face.x, elements.turtle_face.y + 2)
            term.write(" ")
        end

        if turtle.data.peripheral_left == "modem" then
            term.setBackgroundColor(colors.lightGray)
            term.setCursorPos(elements.turtle_face.x + 8, elements.turtle_face.y + 1)
            term.write(" ")
            term.setCursorPos(elements.turtle_face.x + 8, elements.turtle_face.y + 2)
            term.write(" ")
            term.setCursorPos(elements.turtle_face.x + 8, elements.turtle_face.y + 3)
            term.write(" ")
        elseif turtle.data.peripheral_left == "pick" then
            term.setBackgroundColor(colors.cyan)
            term.setCursorPos(elements.turtle_face.x + 8, elements.turtle_face.y + 1)
            term.write(" ")
            term.setCursorPos(elements.turtle_face.x + 8, elements.turtle_face.y + 2)
            term.write(" ")
            term.setBackgroundColor(colors.brown)
            term.setCursorPos(elements.turtle_face.x + 8, elements.turtle_face.y + 3)
            term.write(" ")
        elseif turtle.data.peripheral_left == "chunkLoader" then
            term.setBackgroundColor(colors.gray)
            term.setCursorPos(elements.turtle_face.x + 8, elements.turtle_face.y + 1)
            term.write(" ")
            term.setCursorPos(elements.turtle_face.x + 8, elements.turtle_face.y + 3)
            term.write(" ")
            term.setBackgroundColor(colors.blue)
            term.setCursorPos(elements.turtle_face.x + 8, elements.turtle_face.y + 2)
            term.write(" ")
        elseif turtle.data.peripheral_left == "chunky" then
            term.setBackgroundColor(colors.white)
            term.setCursorPos(elements.turtle_face.x + 8, elements.turtle_face.y + 1)
            term.write(" ")
            term.setCursorPos(elements.turtle_face.x + 8, elements.turtle_face.y + 3)
            term.write(" ")
            term.setBackgroundColor(colors.red)
            term.setCursorPos(elements.turtle_face.x + 8, elements.turtle_face.y + 2)
            term.write(" ")
        end

        term.setBackgroundColor(background_color)

        term.setCursorPos(elements.turtle_data.x, elements.turtle_data.y)
        term.setTextColor(colors.white)
        term.write("State: ")
        term.setTextColor(colors.green)
        term.write(turtle.state)

        term.setCursorPos(elements.turtle_data.x, elements.turtle_data.y + 1)
        term.setTextColor(colors.white)
        term.write("X: ")
        term.setTextColor(colors.green)
        if turtle.data.location then
            term.write(turtle.data.location.x)
        end

        term.setCursorPos(elements.turtle_data.x, elements.turtle_data.y + 2)
        term.setTextColor(colors.white)
        term.write("Y: ")
        term.setTextColor(colors.green)
        if turtle.data.location then
            term.write(turtle.data.location.y)
        end

        term.setCursorPos(elements.turtle_data.x, elements.turtle_data.y + 3)
        term.setTextColor(colors.white)
        term.write("Z: ")
        term.setTextColor(colors.green)
        if turtle.data.location then
            term.write(turtle.data.location.z)
        end

        term.setCursorPos(elements.turtle_data.x, elements.turtle_data.y + 4)
        term.setTextColor(colors.white)
        term.write("Facing: ")
        term.setTextColor(colors.green)
        term.write(turtle.data.orientation)

        term.setCursorPos(elements.turtle_data.x, elements.turtle_data.y + 5)
        term.setTextColor(colors.white)
        term.write("Fuel: ")
        term.setTextColor(colors.green)
        term.write(turtle.data.fuel_level)

        term.setCursorPos(elements.turtle_data.x, elements.turtle_data.y + 6)
        term.setTextColor(colors.white)
        term.write("Items: ")
        term.setTextColor(colors.green)
        term.write(turtle.data.item_count)

        -- Display turtle version with status indicator
        local turtle_version = turtle.data.version
        local is_up_to_date = is_turtle_up_to_date(turtle)
        term.setCursorPos(elements.turtle_version.x, elements.turtle_version.y)

        -- Status indicator (colored block)
        if is_up_to_date == true then
            term.setBackgroundColor(colors.green)
            term.setTextColor(colors.white)
            term.write("UP")
        elseif is_up_to_date == false then
            term.setBackgroundColor(colors.red)
            term.setTextColor(colors.white)
            term.write("OUT")
        else
            term.setBackgroundColor(colors.gray)
            term.setTextColor(colors.white)
            term.write("UNK")
        end

        -- Version text
        term.setBackgroundColor(colors.black)
        if is_up_to_date == true then
            term.setTextColor(colors.green)
        elseif is_up_to_date == false then
            term.setTextColor(colors.red)
        else
            term.setTextColor(colors.gray)
        end
        if turtle_version then
            term.write(" v" .. format_version(turtle_version))
        else
            term.write(" unknown")
        end

        term.setTextColor(colors.white)

        term.setCursorPos(elements.turtle_return.x, elements.turtle_return.y)
        term.setBackgroundColor(colors.green)
        term.write("*")
        term.setBackgroundColor(colors.brown)
        term.write("-RETURN")

        term.setCursorPos(elements.turtle_update.x, elements.turtle_update.y)
        term.setBackgroundColor(colors.green)
        term.write("*")
        term.setBackgroundColor(colors.brown)
        term.write("-UPDATE")

        term.setCursorPos(elements.turtle_reboot.x, elements.turtle_reboot.y)
        term.setBackgroundColor(colors.green)
        term.write("*")
        term.setBackgroundColor(colors.brown)
        term.write("-REBOOT")

        term.setCursorPos(elements.turtle_halt.x, elements.turtle_halt.y)
        term.setBackgroundColor(colors.green)
        term.write("*")
        term.setBackgroundColor(colors.brown)
        term.write("-HALT")

        term.setCursorPos(elements.turtle_clear.x, elements.turtle_clear.y)
        term.setBackgroundColor(colors.green)
        term.write("*")
        term.setBackgroundColor(colors.brown)
        term.write("-CLEAR")

        term.setCursorPos(elements.turtle_reset.x, elements.turtle_reset.y)
        term.setBackgroundColor(colors.green)
        term.write("*")
        term.setBackgroundColor(colors.brown)
        term.write("-RESET")

        term.setCursorPos(elements.turtle_find.x, elements.turtle_find.y)
        term.setBackgroundColor(colors.green)
        term.write("*")
        term.setBackgroundColor(colors.brown)
        term.write("-FIND")

        term.setCursorPos(elements.turtle_forward.x, elements.turtle_forward.y)
        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.green)
        term.write("^")
        term.setTextColor(colors.gray)
        term.setBackgroundColor(background_color)
        term.write("-FORWARD")

        term.setCursorPos(elements.turtle_back.x, elements.turtle_back.y)
        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.green)
        term.write("V")
        term.setTextColor(colors.gray)
        term.setBackgroundColor(background_color)
        term.write("-BACK")

        term.setCursorPos(elements.turtle_up.x, elements.turtle_up.y)
        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.green)
        term.write("^")
        term.setTextColor(colors.gray)
        term.setBackgroundColor(background_color)
        term.write("-UP")

        term.setCursorPos(elements.turtle_down.x, elements.turtle_down.y)
        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.green)
        term.write("V")
        term.setTextColor(colors.gray)
        term.setBackgroundColor(background_color)
        term.write("-DOWN")

        term.setCursorPos(elements.turtle_left.x, elements.turtle_left.y)
        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.green)
        term.write("<")
        term.setTextColor(colors.gray)
        term.setBackgroundColor(background_color)
        term.write("-LEFT")

        term.setCursorPos(elements.turtle_right.x, elements.turtle_right.y)
        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.green)
        term.write(">")
        term.setTextColor(colors.gray)
        term.setBackgroundColor(background_color)
        term.write("-RIGHT")

        term.setCursorPos(elements.turtle_dig_up.x, elements.turtle_dig_up.y)
        term.setTextColor(colors.white)
        if turtle.data.turtle_type == "mining" then
            term.setBackgroundColor(colors.green)
        else
            term.setBackgroundColor(colors.gray)
        end
        term.write("^")

        term.setCursorPos(elements.turtle_dig.x, elements.turtle_dig.y)
        term.setTextColor(colors.white)
        if turtle.data.turtle_type == "mining" then
            term.setBackgroundColor(colors.green)
        else
            term.setBackgroundColor(colors.gray)
        end
        term.write("*")
        term.setTextColor(colors.gray)
        term.setBackgroundColor(background_color)
        term.write("-DIG")

        term.setCursorPos(elements.turtle_dig_down.x, elements.turtle_dig_down.y)
        term.setTextColor(colors.white)
        if turtle.data.turtle_type == "mining" then
            term.setBackgroundColor(colors.green)
        else
            term.setBackgroundColor(colors.gray)
        end
        term.write("v")

        term.setTextColor(colors.white)
        if selected == 1 then
            term.setBackgroundColor(colors.gray)
        else
            term.setBackgroundColor(colors.green)
        end
        term.setCursorPos(elements.left.x, elements.left.y)
        term.write("<")
        if selected == #turtle_ids then
            term.setBackgroundColor(colors.gray)
        else
            term.setBackgroundColor(colors.green)
        end
        term.setCursorPos(elements.right.x, elements.right.y)
        term.write(">")
        term.setBackgroundColor(colors.red)
        term.setCursorPos(elements.viewer_exit.x, elements.viewer_exit.y)
        term.write("x")

        monitor.setVisible(true)
        monitor.setVisible(false)

        sleep(sleep_len)
    end
end

function draw_menu_content()
    term.redirect(monitor)
    term.setBackgroundColor(colors.black)
    -- Don't clear - tab bar is already drawn, just clear from line 2 onwards
    for y = 2, monitor_height do
        term.setCursorPos(1, y)
        term.clearLine()
    end

    term.setTextColor(colors.white)
    term.setCursorPos(elements.menu_title.x, elements.menu_title.y)
    term.write("WORLD")

    for y_offset, line in pairs(menu_lines) do
        term.setCursorPos(elements.menu_title.x, elements.menu_title.y + y_offset)
        for char in line:gmatch "." do
            if char == "#" then
                if state.on then
                    term.setBackgroundColor(colors.lime)
                else
                    term.setBackgroundColor(colors.red)
                end
            else
                term.setBackgroundColor(colors.black)
            end
            term.write(" ")
        end
    end

    term.setCursorPos(elements.menu_title.x, elements.menu_title.y + 1)
    term.setTextColor(colors.gray)
    if state.on then
        term.write("ON")
    else
        term.write("OFF")
    end

    term.setBackgroundColor(colors.black)
    term.setCursorPos(elements.menu_suffix.x, elements.menu_suffix.y)
    term.write(".lua")

    -- Display hub version with status indicator
    local hub_version = get_hub_version()
    local is_up_to_date = is_hub_up_to_date()
    term.setCursorPos(elements.menu_version.x, elements.menu_version.y)

    -- Status indicator (colored block)
    if is_up_to_date == true then
        term.setBackgroundColor(colors.green)
        term.setTextColor(colors.white)
        term.write("UP")
    elseif is_up_to_date == false then
        term.setBackgroundColor(colors.red)
        term.setTextColor(colors.white)
        term.write("OUT")
    else
        term.setBackgroundColor(colors.gray)
        term.setTextColor(colors.white)
        term.write("UNK")
    end

    -- Version text
    term.setBackgroundColor(colors.black)
    if is_up_to_date == true then
        term.setTextColor(colors.green)
    elseif is_up_to_date == false then
        term.setTextColor(colors.red)
    else
        term.setTextColor(colors.gray)
    end
    term.write(" v" .. format_version(hub_version))

    -- Hub Controls Section (Left Side)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.setCursorPos(elements.menu_hub_section.x, elements.menu_hub_section.y)
    term.write("HUB:")

    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.green)
    term.setCursorPos(elements.menu_toggle.x, elements.menu_toggle.y)
    term.write("*")
    term.setCursorPos(elements.menu_hub_update.x, elements.menu_hub_update.y)
    term.write("*")
    term.setBackgroundColor(colors.brown)
    term.setCursorPos(elements.menu_toggle.x + 1, elements.menu_toggle.y)
    term.write("-TOGGLE POWER")
    term.setCursorPos(elements.menu_hub_update.x + 1, elements.menu_hub_update.y)
    term.write("-UPDATE HUB")

    -- Turtle Commands Section (Right Side) - Right-aligned with text on left
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.setCursorPos(elements.menu_turtle_section.x, elements.menu_turtle_section.y)
    term.write("TURTLES:")

    term.setBackgroundColor(colors.brown)
    term.setTextColor(colors.white)
    -- Text on left, button on right (flipped from hub controls)
    term.setCursorPos(elements.menu_return_text.x, elements.menu_return.y)
    term.write("RETURN-")
    term.setCursorPos(elements.menu_update_text.x, elements.menu_update.y)
    term.write("UPDATE-")
    term.setCursorPos(elements.menu_reboot_text.x, elements.menu_reboot.y)
    term.write("REBOOT-")
    term.setCursorPos(elements.menu_halt_text.x, elements.menu_halt.y)
    term.write("HALT-")
    term.setCursorPos(elements.menu_clear_text.x, elements.menu_clear.y)
    term.write("CLEAR-")
    term.setCursorPos(elements.menu_reset_text.x, elements.menu_reset.y)
    term.write("RESET-")

    term.setBackgroundColor(colors.green)
    term.setCursorPos(elements.menu_return.x, elements.menu_return.y)
    term.write("*")
    term.setCursorPos(elements.menu_update.x, elements.menu_update.y)
    term.write("*")
    term.setCursorPos(elements.menu_reboot.x, elements.menu_reboot.y)
    term.write("*")
    term.setCursorPos(elements.menu_halt.x, elements.menu_halt.y)
    term.write("*")
    term.setCursorPos(elements.menu_clear.x, elements.menu_clear.y)
    term.write("*")
    term.setCursorPos(elements.menu_reset.x, elements.menu_reset.y)
    term.write("*")

    term.redirect(monitor.restore_to)
end

-- Store selected turtle for turtles tab
local turtles_tab_selected = 1
local turtles_tab_ids = {}

function draw_turtles_view()
    term.redirect(monitor)
    term.setBackgroundColor(colors.black)
    -- Don't clear - tab bar is already drawn, just clear from line 2 onwards
    for y = 2, monitor_height do
        term.setCursorPos(1, y)
        term.clearLine()
    end
    
    -- Collect all turtle IDs
    turtles_tab_ids = {}
    for _, turtle in pairs(state.turtles) do
        if turtle.data then
            table.insert(turtles_tab_ids, turtle.id)
        end
    end
    
    if #turtles_tab_ids == 0 then
        term.setTextColor(colors.white)
        term.setCursorPos(2, 2)
        term.write("No turtles found")
        term.redirect(monitor.restore_to)
        return
    end
    
    -- Ensure selected is valid
    if turtles_tab_selected > #turtles_tab_ids then
        turtles_tab_selected = 1
    end
    
    local turtle_id = turtles_tab_ids[turtles_tab_selected]
    local turtle = state.turtles[turtle_id]
    
    if not turtle or not turtle.data then
        term.setTextColor(colors.white)
        term.setCursorPos(2, 2)
        term.write("Turtle data not available")
        term.redirect(monitor.restore_to)
        return
    end
    
    -- Draw turtle viewer content (non-blocking version)
    local background_color = colors.black
    term.setBackgroundColor(background_color)
    
    if turtle.last_update + config.turtle_timeout < os.clock() then
        term.setCursorPos(elements.turtle_lost.x, elements.turtle_lost.y)
        term.setTextColor(colors.red)
        term.write("CONNECTION LOST")
    end
    
    local x_position = elements.turtle_id.x
    for decimal_string in string.format("%04d", turtle_id):gmatch "." do
        for y_offset, line in pairs(decimals[tonumber(decimal_string)]) do
            term.setCursorPos(x_position, elements.turtle_id.y + y_offset - 1)
            for char in line:gmatch "." do
                if char == "#" then
                    term.setBackgroundColor(colors.green)
                else
                    term.setBackgroundColor(colors.black)
                end
                term.write(" ")
            end
        end
        x_position = x_position + 6
    end
    
    term.setCursorPos(elements.turtle_face.x + 1, elements.turtle_face.y)
    term.setBackgroundColor(colors.yellow)
    term.write("       ")
    term.setCursorPos(elements.turtle_face.x + 1, elements.turtle_face.y + 1)
    term.setBackgroundColor(colors.yellow)
    term.write(" ")
    term.setBackgroundColor(colors.gray)
    term.write("     ")
    term.setBackgroundColor(colors.yellow)
    term.write(" ")
    term.setCursorPos(elements.turtle_face.x + 1, elements.turtle_face.y + 2)
    term.setBackgroundColor(colors.yellow)
    term.write("       ")
    term.setCursorPos(elements.turtle_face.x + 1, elements.turtle_face.y + 3)
    term.setBackgroundColor(colors.yellow)
    term.write("       ")
    term.setCursorPos(elements.turtle_face.x + 1, elements.turtle_face.y + 4)
    term.setBackgroundColor(colors.yellow)
    term.write("       ")
    
    if turtle.data.peripheral_right == "modem" then
        term.setBackgroundColor(colors.lightGray)
        term.setCursorPos(elements.turtle_face.x, elements.turtle_face.y + 1)
        term.write(" ")
        term.setCursorPos(elements.turtle_face.x, elements.turtle_face.y + 2)
        term.write(" ")
        term.setCursorPos(elements.turtle_face.x, elements.turtle_face.y + 3)
        term.write(" ")
    elseif turtle.data.peripheral_right == "pick" then
        term.setBackgroundColor(colors.cyan)
        term.setCursorPos(elements.turtle_face.x, elements.turtle_face.y + 1)
        term.write(" ")
        term.setCursorPos(elements.turtle_face.x, elements.turtle_face.y + 2)
        term.write(" ")
        term.setBackgroundColor(colors.brown)
        term.setCursorPos(elements.turtle_face.x, elements.turtle_face.y + 3)
        term.write(" ")
    elseif turtle.data.peripheral_right == "chunkLoader" then
        term.setBackgroundColor(colors.gray)
        term.setCursorPos(elements.turtle_face.x, elements.turtle_face.y + 1)
        term.write(" ")
        term.setCursorPos(elements.turtle_face.x, elements.turtle_face.y + 3)
        term.write(" ")
        term.setBackgroundColor(colors.blue)
        term.setCursorPos(elements.turtle_face.x, elements.turtle_face.y + 2)
        term.write(" ")
    elseif turtle.data.peripheral_right == "chunky" then
        term.setBackgroundColor(colors.white)
        term.setCursorPos(elements.turtle_face.x, elements.turtle_face.y + 1)
        term.write(" ")
        term.setCursorPos(elements.turtle_face.x, elements.turtle_face.y + 3)
        term.write(" ")
        term.setBackgroundColor(colors.red)
        term.setCursorPos(elements.turtle_face.x, elements.turtle_face.y + 2)
        term.write(" ")
    end
    
    if turtle.data.peripheral_left == "modem" then
        term.setBackgroundColor(colors.lightGray)
        term.setCursorPos(elements.turtle_face.x + 8, elements.turtle_face.y + 1)
        term.write(" ")
        term.setCursorPos(elements.turtle_face.x + 8, elements.turtle_face.y + 2)
        term.write(" ")
        term.setCursorPos(elements.turtle_face.x + 8, elements.turtle_face.y + 3)
        term.write(" ")
    elseif turtle.data.peripheral_left == "pick" then
        term.setBackgroundColor(colors.cyan)
        term.setCursorPos(elements.turtle_face.x + 8, elements.turtle_face.y + 1)
        term.write(" ")
        term.setCursorPos(elements.turtle_face.x + 8, elements.turtle_face.y + 2)
        term.write(" ")
        term.setBackgroundColor(colors.brown)
        term.setCursorPos(elements.turtle_face.x + 8, elements.turtle_face.y + 3)
        term.write(" ")
    elseif turtle.data.peripheral_left == "chunkLoader" then
        term.setBackgroundColor(colors.gray)
        term.setCursorPos(elements.turtle_face.x + 8, elements.turtle_face.y + 1)
        term.write(" ")
        term.setCursorPos(elements.turtle_face.x + 8, elements.turtle_face.y + 3)
        term.write(" ")
        term.setBackgroundColor(colors.blue)
        term.setCursorPos(elements.turtle_face.x + 8, elements.turtle_face.y + 2)
        term.write(" ")
    elseif turtle.data.peripheral_left == "chunky" then
        term.setBackgroundColor(colors.white)
        term.setCursorPos(elements.turtle_face.x + 8, elements.turtle_face.y + 1)
        term.write(" ")
        term.setCursorPos(elements.turtle_face.x + 8, elements.turtle_face.y + 3)
        term.write(" ")
        term.setBackgroundColor(colors.red)
        term.setCursorPos(elements.turtle_face.x + 8, elements.turtle_face.y + 2)
        term.write(" ")
    end
    
    term.setBackgroundColor(background_color)
    
    term.setCursorPos(elements.turtle_data.x, elements.turtle_data.y)
    term.setTextColor(colors.white)
    term.write("State: ")
    term.setTextColor(colors.green)
    term.write(turtle.state)
    
    term.setCursorPos(elements.turtle_data.x, elements.turtle_data.y + 1)
    term.setTextColor(colors.white)
    term.write("X: ")
    term.setTextColor(colors.green)
    if turtle.data.location then
        term.write(turtle.data.location.x)
    end
    
    term.setCursorPos(elements.turtle_data.x, elements.turtle_data.y + 2)
    term.setTextColor(colors.white)
    term.write("Y: ")
    term.setTextColor(colors.green)
    if turtle.data.location then
        term.write(turtle.data.location.y)
    end
    
    term.setCursorPos(elements.turtle_data.x, elements.turtle_data.y + 3)
    term.setTextColor(colors.white)
    term.write("Z: ")
    term.setTextColor(colors.green)
    if turtle.data.location then
        term.write(turtle.data.location.z)
    end
    
    term.setCursorPos(elements.turtle_data.x, elements.turtle_data.y + 4)
    term.setTextColor(colors.white)
    term.write("Facing: ")
    term.setTextColor(colors.green)
    term.write(turtle.data.orientation)
    
    term.setCursorPos(elements.turtle_data.x, elements.turtle_data.y + 5)
    term.setTextColor(colors.white)
    term.write("Fuel: ")
    term.setTextColor(colors.green)
    term.write(turtle.data.fuel_level)
    
    term.setCursorPos(elements.turtle_data.x, elements.turtle_data.y + 6)
    term.setTextColor(colors.white)
    term.write("Items: ")
    term.setTextColor(colors.green)
    term.write(turtle.data.item_count)
    
    -- Display turtle version with status indicator
    local turtle_version = turtle.data.version
    local is_up_to_date = is_turtle_up_to_date(turtle)
    term.setCursorPos(elements.turtle_version.x, elements.turtle_version.y)
    
    -- Status indicator (colored block)
    if is_up_to_date == true then
        term.setBackgroundColor(colors.green)
        term.setTextColor(colors.white)
        term.write("UP")
    elseif is_up_to_date == false then
        term.setBackgroundColor(colors.red)
        term.setTextColor(colors.white)
        term.write("OUT")
    else
        term.setBackgroundColor(colors.gray)
        term.setTextColor(colors.white)
        term.write("UNK")
    end
    
    -- Version text
    term.setBackgroundColor(colors.black)
    if is_up_to_date == true then
        term.setTextColor(colors.green)
    elseif is_up_to_date == false then
        term.setTextColor(colors.red)
    else
        term.setTextColor(colors.gray)
    end
    if turtle_version then
        term.write(" v" .. format_version(turtle_version))
    else
        term.write(" unknown")
    end
    
    term.setTextColor(colors.white)
    
    term.setCursorPos(elements.turtle_return.x, elements.turtle_return.y)
    term.setBackgroundColor(colors.green)
    term.write("*")
    term.setBackgroundColor(colors.brown)
    term.write("-RETURN")
    
    term.setCursorPos(elements.turtle_update.x, elements.turtle_update.y)
    term.setBackgroundColor(colors.green)
    term.write("*")
    term.setBackgroundColor(colors.brown)
    term.write("-UPDATE")
    
    term.setCursorPos(elements.turtle_reboot.x, elements.turtle_reboot.y)
    term.setBackgroundColor(colors.green)
    term.write("*")
    term.setBackgroundColor(colors.brown)
    term.write("-REBOOT")
    
    term.setCursorPos(elements.turtle_halt.x, elements.turtle_halt.y)
    term.setBackgroundColor(colors.green)
    term.write("*")
    term.setBackgroundColor(colors.brown)
    term.write("-HALT")
    
    term.setCursorPos(elements.turtle_clear.x, elements.turtle_clear.y)
    term.setBackgroundColor(colors.green)
    term.write("*")
    term.setBackgroundColor(colors.brown)
    term.write("-CLEAR")
    
    term.setCursorPos(elements.turtle_reset.x, elements.turtle_reset.y)
    term.setBackgroundColor(colors.green)
    term.write("*")
    term.setBackgroundColor(colors.brown)
    term.write("-RESET")
    
    term.setCursorPos(elements.turtle_find.x, elements.turtle_find.y)
    term.setBackgroundColor(colors.green)
    term.write("*")
    term.setBackgroundColor(colors.brown)
    term.write("-FIND")
    
    term.setCursorPos(elements.turtle_forward.x, elements.turtle_forward.y)
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.green)
    term.write("^")
    term.setTextColor(colors.gray)
    term.setBackgroundColor(background_color)
    term.write("-FORWARD")
    
    term.setCursorPos(elements.turtle_back.x, elements.turtle_back.y)
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.green)
    term.write("V")
    term.setTextColor(colors.gray)
    term.setBackgroundColor(background_color)
    term.write("-BACK")
    
    term.setCursorPos(elements.turtle_up.x, elements.turtle_up.y)
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.green)
    term.write("^")
    term.setTextColor(colors.gray)
    term.setBackgroundColor(background_color)
    term.write("-UP")
    
    term.setCursorPos(elements.turtle_down.x, elements.turtle_down.y)
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.green)
    term.write("V")
    term.setTextColor(colors.gray)
    term.setBackgroundColor(background_color)
    term.write("-DOWN")
    
    term.setCursorPos(elements.turtle_left.x, elements.turtle_left.y)
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.green)
    term.write("<")
    term.setTextColor(colors.gray)
    term.setBackgroundColor(background_color)
    term.write("-LEFT")
    
    term.setCursorPos(elements.turtle_right.x, elements.turtle_right.y)
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.green)
    term.write(">")
    term.setTextColor(colors.gray)
    term.setBackgroundColor(background_color)
    term.write("-RIGHT")
    
    term.setCursorPos(elements.turtle_dig_up.x, elements.turtle_dig_up.y)
    term.setTextColor(colors.white)
    if turtle.data.turtle_type == "mining" then
        term.setBackgroundColor(colors.green)
    else
        term.setBackgroundColor(colors.gray)
    end
    term.write("^")
    
    term.setCursorPos(elements.turtle_dig.x, elements.turtle_dig.y)
    term.setTextColor(colors.white)
    if turtle.data.turtle_type == "mining" then
        term.setBackgroundColor(colors.green)
    else
        term.setBackgroundColor(colors.gray)
    end
    term.write("*")
    term.setTextColor(colors.gray)
    term.setBackgroundColor(background_color)
    term.write("-DIG")
    
    term.setCursorPos(elements.turtle_dig_down.x, elements.turtle_dig_down.y)
    term.setTextColor(colors.white)
    if turtle.data.turtle_type == "mining" then
        term.setBackgroundColor(colors.green)
    else
        term.setBackgroundColor(colors.gray)
    end
    term.write("v")
    
    term.setTextColor(colors.white)
    if turtles_tab_selected == 1 then
        term.setBackgroundColor(colors.gray)
    else
        term.setBackgroundColor(colors.green)
    end
    term.setCursorPos(elements.left.x, elements.left.y)
    term.write("<")
    if turtles_tab_selected == #turtles_tab_ids then
        term.setBackgroundColor(colors.gray)
    else
        term.setBackgroundColor(colors.green)
    end
    term.setCursorPos(elements.right.x, elements.right.y)
    term.write(">")
    
    -- Show turtle selector info
    term.setCursorPos(2, monitor_height)
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.black)
    term.write("Turtle " .. turtles_tab_selected .. "/" .. #turtles_tab_ids)
    
    term.redirect(monitor.restore_to)
end

function draw_stats_view()
    term.redirect(monitor)
    term.setBackgroundColor(colors.black)
    -- Don't clear - tab bar is already drawn, just clear from line 2 onwards
    for y = 2, monitor_height do
        term.setCursorPos(1, y)
        term.clearLine()
    end

    term.setTextColor(colors.white)
    term.setCursorPos(2, 2)
    term.write("STATISTICS")
    term.setCursorPos(2, 3)
    term.write("==========")

    local y = 4
    local turtle_count = 0
    local active_count = 0
    local mining_count = 0
    local idle_count = 0
    local halt_count = 0
    
    for _, turtle in pairs(state.turtles) do
        if turtle.data then
            turtle_count = turtle_count + 1
            if turtle.state == "halt" then
                halt_count = halt_count + 1
            elseif turtle.state == "idle" then
                idle_count = idle_count + 1
            else
                active_count = active_count + 1
            end
            if turtle.data.turtle_type == "mining" then
                mining_count = mining_count + 1
            end
        end
    end
    
    -- Calculate mined blocks
    local mined_count = 0
    if state.mined_blocks then
        for x, z_table in pairs(state.mined_blocks) do
            for z, _ in pairs(z_table) do
                mined_count = mined_count + 1
            end
        end
    end

    term.setCursorPos(2, y)
    term.write("Total Turtles: " .. turtle_count)
    y = y + 1
    term.setCursorPos(2, y)
    term.write("Active Turtles: " .. active_count)
    y = y + 1
    term.setCursorPos(2, y)
    term.write("Idle Turtles: " .. idle_count)
    y = y + 1
    term.setCursorPos(2, y)
    term.write("Halted Turtles: " .. halt_count)
    y = y + 1
    term.setCursorPos(2, y)
    term.write("Mining Turtles: " .. mining_count)
    y = y + 1
    term.setCursorPos(2, y)
    term.write("Blocks Mined: " .. mined_count)
    y = y + 1
    term.setCursorPos(2, y)
    term.write("System Status: ")
    if state.on then
        term.setTextColor(colors.green)
        term.write("ON")
    else
        term.setTextColor(colors.red)
        term.write("OFF")
    end
    term.setTextColor(colors.white)
    
    -- Display hub version
    y = y + 2
    term.setCursorPos(2, y)
    term.write("Hub Version: ")
    local hub_version = get_hub_version()
    if hub_version then
        local is_up_to_date = is_hub_up_to_date()
        if is_up_to_date == true then
            term.setTextColor(colors.green)
        elseif is_up_to_date == false then
            term.setTextColor(colors.red)
        else
            term.setTextColor(colors.gray)
        end
        term.write(format_version(hub_version))
    else
        term.setTextColor(colors.gray)
        term.write("unknown")
    end

    term.redirect(monitor.restore_to)
end

function menu()
    -- Legacy function - now just switches to menu tab
    current_tab = "menu"
end

function draw_location(location, color)
    if location then
        local pixel = {
            -- x = monitor_width  - math.floor((location.x - min_location.x) / zoom_factor),
            -- y = monitor_height - math.floor((location.z - min_location.z) / zoom_factor),
            x = math.floor((location.x - min_location.x) / zoom_factor),
            y = math.floor((location.z - min_location.z) / zoom_factor) + 1  -- Offset by 1 to account for tab bar
        }
        -- Exclude y=1 (tab bar) from drawing
        if pixel.x >= 1 and pixel.x <= monitor_width and pixel.y >= 2 and pixel.y <= monitor_height then
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
    -- Don't clear - tab bar is already drawn, just clear from line 2 onwards
    for y = 2, monitor_height do
        term.setCursorPos(1, y)
        term.clearLine()
    end

    zoom_factor = math.pow(2, monitor_zoom_level)
    -- Account for tab bar (1 row) when calculating map area
    local map_height = monitor_height - 1
    min_location = {
        x = monitor_location.x - math.floor(monitor_width * zoom_factor / 2) - 1,
        z = monitor_location.z - math.floor(map_height * zoom_factor / 2) - 1
    }

    local mined = {}
    local xz
    -- Account for tab bar (1 row) when calculating map area
    local map_height = monitor_height - 1
    for x = min_location.x, min_location.x + (monitor_width * zoom_factor), zoom_factor do
        for z = min_location.z, min_location.z + (map_height * zoom_factor), zoom_factor do
            xz = x .. "," .. z
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

    pixel = draw_location(config.locations.mine_exit, colors.blue)
    if pixel then
        special[pixel.x .. "," .. pixel.y] = colors.blue
    end

    pixel = draw_location(config.locations.mine_enter, colors.cyan)
    if pixel then
        special[pixel.x .. "," .. pixel.y] = colors.cyan
    end

    -- Draw turtle assigned blocks (if they have blocks assigned)
    for _, turtle in pairs(state.turtles) do
        if turtle.block then
            local mine_enter_y =
                (config.locations and config.locations.mine_enter and config.locations.mine_enter.y) or
                (config.mine_entrance and config.mine_entrance.y) or
                config.hub_reference.y
            pixel = draw_location({x = turtle.block.x, y = mine_enter_y, z = turtle.block.z}, colors.green)
            if pixel then
                special[pixel.x .. "," .. pixel.y] = colors.green
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
                    str_pixel = pixel.x .. "," .. pixel.y
                    if special[str_pixel] then
                        term.setBackgroundColor(special[str_pixel])
                    elseif turtle.last_update + config.turtle_timeout < os.clock() then
                        term.setBackgroundColor(colors.red)
                    else
                        term.setBackgroundColor(colors.yellow)
                    end
                    if not turtles[str_pixel] then
                        turtles[str_pixel] = {turtle.id}
                        term.write("-")
                    else
                        table.insert(turtles[str_pixel], turtle.id)
                        if #turtles[str_pixel] <= 9 then
                            term.write(#turtles[str_pixel])
                        else
                            term.write("+")
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
                str_pixel = pixel.x .. "," .. pixel.y
                if pocket.last_update + config.pocket_timeout < os.clock() then
                    term.setBackgroundColor(colors.red)
                else
                    term.setBackgroundColor(colors.green)
                end
                term.write("M")
            end
        end
    end

    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.green)
    term.setCursorPos(elements.menu.x, elements.menu.y)
    term.write("*")
    term.setCursorPos(elements.all_turtles.x, elements.all_turtles.y)
    term.write("*")
    term.setCursorPos(elements.mining_turtles.x, elements.mining_turtles.y)
    term.write("*")
    term.setCursorPos(elements.center.x, elements.center.y)
    term.write("*")
    term.setCursorPos(elements.up.x, elements.up.y)
    term.write("N")
    term.setCursorPos(elements.down.x, elements.down.y)
    term.write("S")
    term.setCursorPos(elements.left.x, elements.left.y)
    term.write("W")
    term.setCursorPos(elements.right.x, elements.right.y)
    term.write("E")
    term.setCursorPos(elements.zoom_in.x, elements.zoom_in.y)
    term.write("+")
    term.setCursorPos(elements.zoom_out.x, elements.zoom_out.y)
    term.write("-")
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
    term.write(string.format("MINED: %4d", mined_count))
    term.setCursorPos(elements.zoom_indicator.x, elements.zoom_indicator.y)
    term.write("ZOOM: " .. monitor_zoom_level)
    term.setCursorPos(elements.x_indicator.x, elements.x_indicator.y)
    term.write("X: " .. monitor_location.x)
    term.setCursorPos(elements.z_indicator.x, elements.z_indicator.y)
    term.write("Z: " .. monitor_location.z)
    term.setCursorPos(elements.center_indicator.x, elements.center_indicator.y)
    term.write("-CENTER")
    term.setCursorPos(elements.menu_indicator.x, elements.menu_indicator.y)
    term.write("-MENU")
    term.setCursorPos(elements.all_indicator.x, elements.all_indicator.y)
    term.write("ALL-")
    term.setCursorPos(elements.mining_indicator.x, elements.mining_indicator.y)
    term.write("MINING-")

    term.redirect(monitor.restore_to)
end

function touch_monitor(monitor_touch)
    -- Handle tab bar clicks (y = 1)
    if monitor_touch.y == 1 then
        if monitor_touch.x >= 2 and monitor_touch.x <= 7 then
            current_tab = "menu"
        elseif monitor_touch.x >= 9 and monitor_touch.x <= 12 then
            current_tab = "map"
        elseif monitor_touch.x >= 14 and monitor_touch.x <= 21 then
            current_tab = "turtles"
        elseif monitor_touch.x >= 23 and monitor_touch.x <= 28 then
            current_tab = "stats"
        end
        return
    end

    -- Handle menu tab button clicks
    if current_tab == "menu" then
        if monitor_touch.x == elements.menu_toggle.x and monitor_touch.y == elements.menu_toggle.y then
            if state.on then
                table.insert(state.user_input, "off")
            else
                table.insert(state.user_input, "on")
            end
            return
        elseif monitor_touch.x == elements.menu_hub_update.x and monitor_touch.y == elements.menu_hub_update.y then
            table.insert(state.user_input, "hubupdate")
            return
        elseif monitor_touch.x == elements.menu_update.x and monitor_touch.y == elements.menu_update.y then
            table.insert(state.user_input, "update")
            return
        elseif monitor_touch.x == elements.menu_return.x and monitor_touch.y == elements.menu_return.y then
            table.insert(state.user_input, "return")
            return
        elseif monitor_touch.x == elements.menu_reboot.x and monitor_touch.y == elements.menu_reboot.y then
            table.insert(state.user_input, "reboot")
            return
        elseif monitor_touch.x == elements.menu_halt.x and monitor_touch.y == elements.menu_halt.y then
            table.insert(state.user_input, "halt")
            return
        elseif monitor_touch.x == elements.menu_clear.x and monitor_touch.y == elements.menu_clear.y then
            table.insert(state.user_input, "clear")
            return
        elseif monitor_touch.x == elements.menu_reset.x and monitor_touch.y == elements.menu_reset.y then
            table.insert(state.user_input, "reset")
            return
        end
    end

    -- Handle turtles tab button clicks
    if current_tab == "turtles" then
        if monitor_touch.x == elements.left.x and monitor_touch.y == elements.left.y then
            if #turtles_tab_ids > 0 then
                turtles_tab_selected = math.max(turtles_tab_selected - 1, 1)
            end
            return
        elseif monitor_touch.x == elements.right.x and monitor_touch.y == elements.right.y then
            if #turtles_tab_ids > 0 then
                turtles_tab_selected = math.min(turtles_tab_selected + 1, #turtles_tab_ids)
            end
            return
        elseif monitor_touch.x == elements.turtle_return.x and monitor_touch.y == elements.turtle_return.y then
            if #turtles_tab_ids > 0 then
                local turtle_id = turtles_tab_ids[turtles_tab_selected]
                table.insert(state.user_input, "return " .. turtle_id)
            end
            return
        elseif monitor_touch.x == elements.turtle_update.x and monitor_touch.y == elements.turtle_update.y then
            if #turtles_tab_ids > 0 then
                local turtle_id = turtles_tab_ids[turtles_tab_selected]
                table.insert(state.user_input, "update " .. turtle_id)
            end
            return
        elseif monitor_touch.x == elements.turtle_reboot.x and monitor_touch.y == elements.turtle_reboot.y then
            if #turtles_tab_ids > 0 then
                local turtle_id = turtles_tab_ids[turtles_tab_selected]
                table.insert(state.user_input, "reboot " .. turtle_id)
            end
            return
        elseif monitor_touch.x == elements.turtle_halt.x and monitor_touch.y == elements.turtle_halt.y then
            if #turtles_tab_ids > 0 then
                local turtle_id = turtles_tab_ids[turtles_tab_selected]
                table.insert(state.user_input, "halt " .. turtle_id)
            end
            return
        elseif monitor_touch.x == elements.turtle_clear.x and monitor_touch.y == elements.turtle_clear.y then
            if #turtles_tab_ids > 0 then
                local turtle_id = turtles_tab_ids[turtles_tab_selected]
                table.insert(state.user_input, "clear " .. turtle_id)
            end
            return
        elseif monitor_touch.x == elements.turtle_reset.x and monitor_touch.y == elements.turtle_reset.y then
            if #turtles_tab_ids > 0 then
                local turtle_id = turtles_tab_ids[turtles_tab_selected]
                table.insert(state.user_input, "reset " .. turtle_id)
            end
            return
        elseif monitor_touch.x == elements.turtle_find.x and monitor_touch.y == elements.turtle_find.y then
            if #turtles_tab_ids > 0 then
                local turtle_id = turtles_tab_ids[turtles_tab_selected]
                local turtle = state.turtles[turtle_id]
                if turtle and turtle.data and turtle.data.location then
                    monitor_location.x = turtle.data.location.x
                    monitor_location.z = turtle.data.location.z
                    current_tab = "map"
                end
            end
            return
        elseif monitor_touch.x == elements.turtle_forward.x and monitor_touch.y == elements.turtle_forward.y then
            if #turtles_tab_ids > 0 then
                local turtle_id = turtles_tab_ids[turtles_tab_selected]
                table.insert(state.user_input, "turtle " .. turtle_id .. " go forward")
            end
            return
        elseif monitor_touch.x == elements.turtle_back.x and monitor_touch.y == elements.turtle_back.y then
            if #turtles_tab_ids > 0 then
                local turtle_id = turtles_tab_ids[turtles_tab_selected]
                table.insert(state.user_input, "turtle " .. turtle_id .. " go back")
            end
            return
        elseif monitor_touch.x == elements.turtle_up.x and monitor_touch.y == elements.turtle_up.y then
            if #turtles_tab_ids > 0 then
                local turtle_id = turtles_tab_ids[turtles_tab_selected]
                table.insert(state.user_input, "turtle " .. turtle_id .. " go up")
            end
            return
        elseif monitor_touch.x == elements.turtle_down.x and monitor_touch.y == elements.turtle_down.y then
            if #turtles_tab_ids > 0 then
                local turtle_id = turtles_tab_ids[turtles_tab_selected]
                table.insert(state.user_input, "turtle " .. turtle_id .. " go down")
            end
            return
        elseif monitor_touch.x == elements.turtle_left.x and monitor_touch.y == elements.turtle_left.y then
            if #turtles_tab_ids > 0 then
                local turtle_id = turtles_tab_ids[turtles_tab_selected]
                table.insert(state.user_input, "turtle " .. turtle_id .. " go left")
            end
            return
        elseif monitor_touch.x == elements.turtle_right.x and monitor_touch.y == elements.turtle_right.y then
            if #turtles_tab_ids > 0 then
                local turtle_id = turtles_tab_ids[turtles_tab_selected]
                table.insert(state.user_input, "turtle " .. turtle_id .. " go right")
            end
            return
        elseif monitor_touch.x == elements.turtle_dig_up.x and monitor_touch.y == elements.turtle_dig_up.y then
            if #turtles_tab_ids > 0 then
                local turtle_id = turtles_tab_ids[turtles_tab_selected]
                local turtle = state.turtles[turtle_id]
                if turtle and turtle.data and turtle.data.turtle_type == "mining" then
                    table.insert(state.user_input, "turtle " .. turtle_id .. " digblock up")
                end
            end
            return
        elseif monitor_touch.x == elements.turtle_dig.x and monitor_touch.y == elements.turtle_dig.y then
            if #turtles_tab_ids > 0 then
                local turtle_id = turtles_tab_ids[turtles_tab_selected]
                local turtle = state.turtles[turtle_id]
                if turtle and turtle.data and turtle.data.turtle_type == "mining" then
                    table.insert(state.user_input, "turtle " .. turtle_id .. " digblock forward")
                end
            end
            return
        elseif monitor_touch.x == elements.turtle_dig_down.x and monitor_touch.y == elements.turtle_dig_down.y then
            if #turtles_tab_ids > 0 then
                local turtle_id = turtles_tab_ids[turtles_tab_selected]
                local turtle = state.turtles[turtle_id]
                if turtle and turtle.data and turtle.data.turtle_type == "mining" then
                    table.insert(state.user_input, "turtle " .. turtle_id .. " digblock down")
                end
            end
            return
        end
    end

    -- Only handle map controls when on map tab
    if current_tab ~= "map" then
        return
    end

    if monitor_touch.x == elements.up.x and monitor_touch.y == elements.up.y then
        monitor_location.z = monitor_location.z - zoom_factor
    elseif monitor_touch.x == elements.down.x and monitor_touch.y == elements.down.y then
        monitor_location.z = monitor_location.z + zoom_factor
    elseif monitor_touch.x == elements.left.x and monitor_touch.y == elements.left.y then
        monitor_location.x = monitor_location.x - zoom_factor
    elseif monitor_touch.x == elements.right.x and monitor_touch.y == elements.right.y then
        monitor_location.x = monitor_location.x + zoom_factor
    elseif monitor_touch.x == elements.level_up.x and monitor_touch.y == elements.level_up.y then
        monitor_level_index = math.min(monitor_level_index + 1, #config.mine_levels)
        select_mine_level()
    elseif monitor_touch.x == elements.level_down.x and monitor_touch.y == elements.level_down.y then
        monitor_level_index = math.max(monitor_level_index - 1, 1)
        select_mine_level()
    elseif monitor_touch.x == elements.zoom_in.x and monitor_touch.y == elements.zoom_in.y then
        monitor_zoom_level = math.max(monitor_zoom_level - 1, 0)
    elseif monitor_touch.x == elements.zoom_out.x and monitor_touch.y == elements.zoom_out.y then
        monitor_zoom_level = math.min(monitor_zoom_level + 1, config.monitor_max_zoom_level)
    elseif monitor_touch.x == elements.menu.x and monitor_touch.y == elements.menu.y then
        current_tab = "menu"
    elseif monitor_touch.x == elements.center.x and monitor_touch.y == elements.center.y then
        monitor_location = {x = config.default_monitor_location.x, z = config.default_monitor_location.z}
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
            if turtle.data and turtle.data.turtle_type == "mining" then
                table.insert(turtle_ids, turtle.id)
            end
        end
        if #turtle_ids then
            turtle_viewer(turtle_ids)
        end
    else
        local str_pos = monitor_touch.x .. "," .. monitor_touch.y
        if turtles[str_pos] then
            turtle_viewer(turtles[str_pos])
        end
    end
end

function init_elements()
    elements = {
        up = {x = math.ceil(monitor_width / 2), y = 2},
        down = {x = math.ceil(monitor_width / 2), y = monitor_height},
        left = {x = 1, y = math.ceil(monitor_height / 2)},
        right = {x = monitor_width, y = math.ceil(monitor_height / 2)},
        level_up = {x = monitor_width, y = 3}, -- Shifted down 2 lines
        level_down = {x = monitor_width - 11, y = 3}, -- Shifted down 2 lines
        level_indicator = {x = monitor_width - 10, y = 3}, -- Shifted down 2 lines
        zoom_in = {x = monitor_width, y = 4}, -- Shifted down 2 lines
        zoom_out = {x = monitor_width - 8, y = 4}, -- Shifted down 2 lines
        zoom_indicator = {x = monitor_width - 7, y = 4}, -- Shifted down 2 lines
        all_turtles = {x = monitor_width, y = monitor_height - 1},
        all_indicator = {x = monitor_width - 4, y = monitor_height - 1},
        mining_turtles = {x = monitor_width, y = monitor_height},
        mining_indicator = {x = monitor_width - 7, y = monitor_height},
        menu = {x = 1, y = monitor_height},
        menu_indicator = {x = 2, y = monitor_height},
        center = {x = 1, y = 2}, -- Shifted down 2 lines
        center_indicator = {x = 2, y = 2}, -- Shifted down 2 lines
        x_indicator = {x = 1, y = 3}, -- Shifted down 2 lines
        z_indicator = {x = 1, y = 4}, -- Shifted down 2 lines
        version = {x = 2, y = 2}, -- Shifted down 2 lines
        turtle_face = {x = 5, y = 2}, -- Shifted down 2 lines
        turtle_id = {x = 16, y = 2}, -- Shifted down 2 lines
        turtle_version = {x = 4, y = 7},
        turtle_lost = {x = 13, y = 1},
        turtle_data = {x = 4, y = 8},
        turtle_return = {x = 26, y = 8},
        turtle_reboot = {x = 26, y = 9},
        turtle_update = {x = 26, y = 10},
        turtle_halt = {x = 26, y = 11},
        turtle_clear = {x = 26, y = 12},
        turtle_reset = {x = 26, y = 13},
        turtle_find = {x = 26, y = 14},
        turtle_forward = {x = 10, y = 16},
        turtle_back = {x = 10, y = 18},
        turtle_up = {x = 23, y = 16},
        turtle_down = {x = 23, y = 18},
        turtle_left = {x = 6, y = 17},
        turtle_right = {x = 14, y = 17},
        turtle_dig_up = {x = 31, y = 16},
        turtle_dig = {x = 31, y = 17},
        turtle_dig_down = {x = 31, y = 18},
        menu_title = {x = 6, y = 4}, -- Shifted down 2 lines
        menu_version = {x = 6, y = 10}, -- Shifted down 2 lines
        menu_suffix = {x = 31, y = 10}, -- Shifted down 2 lines
        menu_hub_section = {x = 6, y = 12}, -- Shifted down 2 lines
        menu_toggle = {x = 6, y = 13}, -- Shifted down 2 lines
        menu_hub_update = {x = 6, y = 14}, -- Shifted down 2 lines
        menu_turtle_section = {x = 27, y = 12}, -- Shifted down 2 lines
        menu_return = {x = 33, y = 13}, -- Button on right, shifted down 2 lines
        menu_return_text = {x = 26, y = 13}, -- Text on left, shifted down 2 lines
        menu_update = {x = 33, y = 14}, -- Button on right, shifted down 2 lines
        menu_update_text = {x = 26, y = 14}, -- Text on left, shifted down 2 lines
        menu_reboot = {x = 33, y = 15}, -- Button on right, shifted down 2 lines
        menu_reboot_text = {x = 26, y = 15}, -- Text on left, shifted down 2 lines
        menu_halt = {x = 33, y = 16}, -- Button on right, shifted down 2 lines
        menu_halt_text = {x = 28, y = 16}, -- Text on left, shifted down 2 lines
        menu_clear = {x = 33, y = 17}, -- Button on right, shifted down 2 lines
        menu_clear_text = {x = 27, y = 17}, -- Text on left, shifted down 2 lines
        menu_reset = {x = 33, y = 18}, -- Button on right, shifted down 2 lines
        menu_reset_text = {x = 27, y = 18}, -- Text on left, shifted down 2 lines
        menu_statistics = {x = 10, y = 20} -- Shifted down 2 lines
    }
end

function select_mine_level()
    monitor_level = state.mine[0] -- Not used anymore
end

function draw_tab_bar()
    term.redirect(monitor)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)

    -- Draw tab bar background
    for x = 1, monitor_width do
        term.setCursorPos(x, 1)
        term.write(" ")
    end

    -- Draw tabs
    local tabs = {
        {name = "MENU", id = "menu", x = 2},
        {name = "MAP", id = "map", x = 9},
        {name = "TURTLES", id = "turtles", x = 14},
        {name = "STATS", id = "stats", x = 23}
    }

    for _, tab in ipairs(tabs) do
        if current_tab == tab.id then
            term.setBackgroundColor(colors.blue)
        else
            term.setBackgroundColor(colors.gray)
        end
        term.setCursorPos(tab.x, 1)
        term.write(" " .. tab.name .. " ")
    end

    term.setBackgroundColor(colors.black)
    term.redirect(monitor.restore_to)
end

function step()
    while #state.monitor_touches > 0 do
        touch_monitor(table.remove(state.monitor_touches))
    end

    -- Draw tab bar at top
    draw_tab_bar()

    -- Draw content based on active tab
    if current_tab == "menu" then
        draw_menu_content()
    elseif current_tab == "map" then
        draw_monitor()
    elseif current_tab == "turtles" then
        draw_turtles_view()
    elseif current_tab == "stats" then
        draw_stats_view()
    end

    monitor.setVisible(true)
    monitor.setVisible(false)
    sleep(sleep_len)
end

function main()
    sleep_len = 0.3

    local attached = peripheral.find("monitor")

    if not attached then
        error("No monitor connected.")
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
    monitor.setVisible(false)
    monitor.setCursorPos(1, 1)

    monitor_location = {x = config.locations.mine_enter.x, z = config.locations.mine_enter.z}
    monitor_zoom_level = config.default_monitor_zoom_level

    init_elements()

    -- Check GitHub version once on startup
    if github_api and http then
        github_version_cache = github_api.get_latest_release_version("Jemsire/CC-World-Eater")
    end

    while not state.mine do
        sleep(0.5)
    end

    monitor_level_index = 1
    select_mine_level()

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
