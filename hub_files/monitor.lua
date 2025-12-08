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

-- Cache for GitHub version check (only checked once on startup)
local github_version_cache = nil

-- Store selected turtle for turtles tab
local turtles_tab_selected = 1
local turtles_tab_ids = {}

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

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
    -- Only show -DEV if dev == true (dev_suffix is for metadata only)
    if version.dev == true then
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

function is_hub_up_to_date()
    local hub_version = get_hub_version()
    if not hub_version or not github_version_cache then
        return nil
    end
    return github_api.compare_versions(hub_version, github_version_cache) >= 0
end

function turtle_matches_hub(turtle_version)
    local hub_version = get_hub_version()
    if not hub_version or not turtle_version then
        return false
    end
    return github_api.compare_versions(turtle_version, hub_version) == 0
end

function is_turtle_up_to_date(turtle)
    if not turtle or not turtle.data or not turtle.data.version then
        return nil
    end
    return turtle_matches_hub(turtle.data.version)
end

function clear_content_area()
    term.setBackgroundColor(colors.black)
    for y = 2, monitor_height do
        term.setCursorPos(1, y)
        term.clearLine()
    end
end

-- ============================================================================
-- REUSABLE UI DRAWING FUNCTIONS
-- ============================================================================

function draw_button(x, y, label, button_color, label_color)
    button_color = button_color or colors.green
    label_color = label_color or colors.brown
    term.setCursorPos(x, y)
    term.setTextColor(colors.white)
    term.setBackgroundColor(button_color)
    term.write("*")
    term.setBackgroundColor(label_color)
    term.write("-" .. label)
end

function draw_button_right(x, y, label, button_color, label_color)
    -- Button on right, text on left
    button_color = button_color or colors.green
    label_color = label_color or colors.brown
    term.setBackgroundColor(label_color)
    term.setTextColor(colors.white)
    term.setCursorPos(x - #label - 1, y)
    term.write(label .. "-")
    term.setBackgroundColor(button_color)
    term.setCursorPos(x, y)
    term.write("*")
end

function draw_movement_button(x, y, symbol, label, enabled)
    term.setCursorPos(x, y)
    term.setTextColor(colors.white)
    term.setBackgroundColor(enabled and colors.green or colors.gray)
    term.write(symbol)
    term.setTextColor(colors.gray)
    term.setBackgroundColor(colors.black)
    term.write("-" .. label)
end

function draw_version_status(x, y, version, is_up_to_date)
    term.setCursorPos(x, y)
    
    -- Status indicator block
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
    
    if version then
        term.write(" v" .. format_version(version))
    else
        term.write(" unknown")
    end
end

function draw_decimal_id(x, y, id)
    for decimal_string in string.format("%04d", id):gmatch "." do
        for y_offset, line in pairs(decimals[tonumber(decimal_string)]) do
            term.setCursorPos(x, y + y_offset - 1)
            for char in line:gmatch "." do
                term.setBackgroundColor(char == "#" and colors.green or colors.black)
                term.write(" ")
            end
        end
        x = x + 6
    end
end

function draw_peripheral(x, y, peripheral_type)
    local colors_map = {
        modem = {colors.lightGray, colors.lightGray, colors.lightGray},
        pick = {colors.cyan, colors.cyan, colors.brown},
        chunkLoader = {colors.gray, colors.blue, colors.gray},
        chunky = {colors.white, colors.red, colors.white}
    }
    
    local c = colors_map[peripheral_type]
    if c then
        term.setBackgroundColor(c[1])
        term.setCursorPos(x, y + 1)
        term.write(" ")
        term.setBackgroundColor(c[2])
        term.setCursorPos(x, y + 2)
        term.write(" ")
        term.setBackgroundColor(c[3])
        term.setCursorPos(x, y + 3)
        term.write(" ")
    end
end

function draw_turtle_face(x, y, turtle_data)
    -- Main body
    term.setBackgroundColor(colors.yellow)
    for row = 0, 4 do
        term.setCursorPos(x + 1, y + row)
        if row == 1 then
            term.write(" ")
            term.setBackgroundColor(colors.gray)
            term.write("     ")
            term.setBackgroundColor(colors.yellow)
            term.write(" ")
        else
            term.write("       ")
        end
    end
    
    -- Peripherals
    draw_peripheral(x, y, turtle_data.peripheral_right)
    draw_peripheral(x + 8, y, turtle_data.peripheral_left)
end

function draw_turtle_data(x, y, turtle)
    local data = turtle.data
    local fields = {
        {"State: ", turtle.state},
        {"X: ", data.location and data.location.x or ""},
        {"Y: ", data.location and data.location.y or ""},
        {"Z: ", data.location and data.location.z or ""},
        {"Facing: ", data.orientation},
        {"Fuel: ", data.fuel_level},
        {"Items: ", data.item_count}
    }
    
    for i, field in ipairs(fields) do
        term.setCursorPos(x, y + i - 1)
        term.setTextColor(colors.white)
        term.write(field[1])
        term.setTextColor(colors.green)
        term.write(tostring(field[2]))
    end
end

function draw_turtle_controls(turtle_id, is_mining)
    -- Command buttons
    draw_button(elements.turtle_return.x, elements.turtle_return.y, "RETURN")
    draw_button(elements.turtle_update.x, elements.turtle_update.y, "UPDATE")
    draw_button(elements.turtle_reboot.x, elements.turtle_reboot.y, "REBOOT")
    draw_button(elements.turtle_halt.x, elements.turtle_halt.y, "HALT")
    draw_button(elements.turtle_clear.x, elements.turtle_clear.y, "CLEAR")
    draw_button(elements.turtle_reset.x, elements.turtle_reset.y, "RESET")
    draw_button(elements.turtle_find.x, elements.turtle_find.y, "FIND")
    
    -- Movement buttons
    draw_movement_button(elements.turtle_forward.x, elements.turtle_forward.y, "^", "FORWARD", true)
    draw_movement_button(elements.turtle_back.x, elements.turtle_back.y, "V", "BACK", true)
    draw_movement_button(elements.turtle_up.x, elements.turtle_up.y, "^", "UP", true)
    draw_movement_button(elements.turtle_down.x, elements.turtle_down.y, "V", "DOWN", true)
    draw_movement_button(elements.turtle_left.x, elements.turtle_left.y, "<", "LEFT", true)
    draw_movement_button(elements.turtle_right.x, elements.turtle_right.y, ">", "RIGHT", true)
    
    -- Dig buttons
    term.setTextColor(colors.white)
    term.setBackgroundColor(is_mining and colors.green or colors.gray)
    term.setCursorPos(elements.turtle_dig_up.x, elements.turtle_dig_up.y)
    term.write("^")
    term.setCursorPos(elements.turtle_dig.x, elements.turtle_dig.y)
    term.write("*")
    term.setTextColor(colors.gray)
    term.setBackgroundColor(colors.black)
    term.write("-DIG")
    term.setTextColor(colors.white)
    term.setBackgroundColor(is_mining and colors.green or colors.gray)
    term.setCursorPos(elements.turtle_dig_down.x, elements.turtle_dig_down.y)
    term.write("v")
end

function draw_turtle_nav_buttons(selected, total)
    term.setTextColor(colors.white)
    term.setBackgroundColor(selected == 1 and colors.gray or colors.green)
    term.setCursorPos(elements.left.x, elements.left.y)
    term.write("<")
    term.setBackgroundColor(selected == total and colors.gray or colors.green)
    term.setCursorPos(elements.right.x, elements.right.y)
    term.write(">")
end

function draw_turtle_details(turtle, turtle_id, show_exit_button)
    local background_color = colors.black
    term.setBackgroundColor(background_color)
    
    -- Connection status
    if turtle.last_update + config.turtle_timeout < os.clock() then
        term.setCursorPos(elements.turtle_lost.x, elements.turtle_lost.y)
        term.setTextColor(colors.red)
        term.write("CONNECTION LOST")
    end
    
    -- Turtle ID
    draw_decimal_id(elements.turtle_id.x, elements.turtle_id.y, turtle_id)
    
    -- Turtle face
    draw_turtle_face(elements.turtle_face.x, elements.turtle_face.y, turtle.data)
    
    term.setBackgroundColor(background_color)
    
    -- Turtle data
    draw_turtle_data(elements.turtle_data.x, elements.turtle_data.y, turtle)
    
    -- Version status
    draw_version_status(elements.turtle_version.x, elements.turtle_version.y, 
                        turtle.data.version, is_turtle_up_to_date(turtle))
    
    term.setTextColor(colors.white)
    
    -- Controls
    draw_turtle_controls(turtle_id, turtle.data.turtle_type == "mining")
    
    -- Exit button (only in viewer mode)
    if show_exit_button then
        term.setBackgroundColor(colors.red)
        term.setCursorPos(elements.viewer_exit.x, elements.viewer_exit.y)
        term.write("x")
    end
end

-- ============================================================================
-- TAB BAR
-- ============================================================================

function draw_tab_bar()
    term.redirect(monitor)
    local background_color = state.on and colors.lime or colors.red
    term.setTextColor(colors.black)
    term.setBackgroundColor(background_color)

    for x = 1, monitor_width do
        term.setCursorPos(x, 1)
        term.write(" ")
    end

    local tabs = {
        {name = "MENU", id = "menu", x = 2},
        {name = "MAP", id = "map", x = 9},
        {name = "TURTLES", id = "turtles", x = 14},
        {name = "STATS", id = "stats", x = 23}
    }

    for _, tab in ipairs(tabs) do
        if current_tab == tab.id then
            term.setBackgroundColor(colors.brown)
            term.setTextColor(colors.white)
        else
            term.setBackgroundColor(background_color)
            term.setTextColor(colors.black)
        end
        term.setCursorPos(tab.x, 1)
        term.write(" " .. tab.name .. " ")
    end

    term.setBackgroundColor(colors.black)
    term.redirect(monitor.restore_to)
end

-- ============================================================================
-- TURTLE VIEWER (Modal)
-- ============================================================================

function turtle_viewer(turtle_ids)
    term.redirect(monitor)
    local selected = 1

    while true do
        draw_tab_bar()
        
        local turtle_id = turtle_ids[selected]
        local turtle = state.turtles[turtle_id]

        -- Handle monitor touches
        while #state.monitor_touches > 0 do
            local touch = table.remove(state.monitor_touches)
            
            -- Tab bar clicks
            if touch.y == 1 then
                local tab_map = {
                    {2, 7, "menu"}, {9, 12, "map"}, {14, 21, "turtles"}, {23, 28, "stats"}
                }
                for _, t in ipairs(tab_map) do
                    if touch.x >= t[1] and touch.x <= t[2] then
                        current_tab = t[3]
                        term.redirect(monitor.restore_to)
                        return
                    end
                end
            elseif touch.x == elements.left.x and touch.y == elements.left.y then
                selected = math.max(selected - 1, 1)
            elseif touch.x == elements.right.x and touch.y == elements.right.y then
                selected = math.min(selected + 1, #turtle_ids)
            elseif touch.x == elements.viewer_exit.x and touch.y == elements.viewer_exit.y then
                term.redirect(monitor.restore_to)
                return
            elseif touch.x == elements.turtle_find.x and touch.y == elements.turtle_find.y then
                monitor_location.x = turtle.data.location.x
                monitor_location.z = turtle.data.location.z
                monitor_zoom_level = 0
                if turtle.block then
                    monitor_location.x = turtle.block.x
                    monitor_location.z = turtle.block.z
                end
                term.redirect(monitor.restore_to)
                return
            else
                -- Command button handling
                local commands = {
                    {elements.turtle_return, "return"},
                    {elements.turtle_reboot, "reboot"},
                    {elements.turtle_halt, "halt"},
                    {elements.turtle_clear, "clear"},
                    {elements.turtle_reset, "reset"},
                    {elements.turtle_update, "update"},
                }
                for _, cmd in ipairs(commands) do
                    if touch.x == cmd[1].x and touch.y == cmd[1].y then
                        table.insert(state.user_input, cmd[2] .. " " .. turtle_id)
                        break
                    end
                end
                
                -- Movement handling
                local movements = {
                    {elements.turtle_forward, "go forward"},
                    {elements.turtle_back, "go back"},
                    {elements.turtle_up, "go up"},
                    {elements.turtle_down, "go down"},
                    {elements.turtle_left, "go left"},
                    {elements.turtle_right, "go right"},
                }
                for _, mov in ipairs(movements) do
                    if touch.x == mov[1].x and touch.y == mov[1].y then
                        table.insert(state.user_input, "turtle " .. turtle_id .. " " .. mov[2])
                        break
                    end
                end
                
                -- Dig handling (mining only)
                if turtle.data.turtle_type == "mining" then
                    local digs = {
                        {elements.turtle_dig_up, "digblock up"},
                        {elements.turtle_dig, "digblock forward"},
                        {elements.turtle_dig_down, "digblock down"},
                    }
                    for _, dig in ipairs(digs) do
                        if touch.x == dig[1].x and touch.y == dig[1].y then
                            table.insert(state.user_input, "turtle " .. turtle_id .. " " .. dig[2])
                            break
                        end
                    end
                end
            end
        end

        turtle_id = turtle_ids[selected]
        turtle = state.turtles[turtle_id]

        clear_content_area()
        draw_turtle_details(turtle, turtle_id, true)
        draw_turtle_nav_buttons(selected, #turtle_ids)

        monitor.setVisible(true)
        monitor.setVisible(false)
        sleep(sleep_len)
    end
end

-- ============================================================================
-- TAB CONTENT DRAWING
-- ============================================================================

function draw_menu_content()
    term.redirect(monitor)
    clear_content_area()

    term.setTextColor(colors.white)
    term.setCursorPos(elements.menu_title.x, elements.menu_title.y)
    term.write("WORLD")

    for y_offset, line in pairs(menu_lines) do
        term.setCursorPos(elements.menu_title.x, elements.menu_title.y + y_offset)
        for char in line:gmatch "." do
            term.setBackgroundColor(char == "#" and (state.on and colors.lime or colors.red) or colors.black)
            term.write(" ")
        end
    end

    term.setCursorPos(elements.menu_title.x, elements.menu_title.y + 1)
    term.setTextColor(colors.gray)
    term.write(state.on and "ON" or "OFF")

    term.setBackgroundColor(colors.black)
    term.setCursorPos(elements.menu_suffix.x, elements.menu_suffix.y)
    term.write(".lua")

    draw_version_status(elements.menu_version.x, elements.menu_version.y, get_hub_version(), is_hub_up_to_date())

    -- Hub Controls Section
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.setCursorPos(elements.menu_hub_section.x, elements.menu_hub_section.y)
    term.write("HUB:")

    draw_button(elements.menu_toggle.x, elements.menu_toggle.y, "TOGGLE POWER")
    draw_button(elements.menu_hub_update.x, elements.menu_hub_update.y, "UPDATE HUB")

    -- Turtle Commands Section
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.setCursorPos(elements.menu_turtle_section.x, elements.menu_turtle_section.y)
    term.write("TURTLES:")

    local turtle_buttons = {
        {elements.menu_return.x, elements.menu_return.y, "RETURN"},
        {elements.menu_update.x, elements.menu_update.y, "UPDATE"},
        {elements.menu_reboot.x, elements.menu_reboot.y, "REBOOT"},
        {elements.menu_halt.x, elements.menu_halt.y, "HALT"},
        {elements.menu_clear.x, elements.menu_clear.y, "CLEAR"},
        {elements.menu_reset.x, elements.menu_reset.y, "RESET"},
    }
    for _, btn in ipairs(turtle_buttons) do
        draw_button_right(btn[1], btn[2], btn[3])
    end

    term.redirect(monitor.restore_to)
end

function draw_turtles_view()
    term.redirect(monitor)
    clear_content_area()
    
    -- Collect turtle IDs
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
    
    draw_turtle_details(turtle, turtle_id, false)
    draw_turtle_nav_buttons(turtles_tab_selected, #turtles_tab_ids)
    
    -- Turtle selector info
    term.setCursorPos(2, monitor_height)
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.black)
    term.write("Turtle " .. turtles_tab_selected .. "/" .. #turtles_tab_ids)
    
    term.redirect(monitor.restore_to)
end

function draw_stats_view()
    term.redirect(monitor)
    clear_content_area()

    term.setTextColor(colors.white)
    term.setCursorPos(2, 2)
    term.write("STATISTICS")
    term.setCursorPos(2, 3)
    term.write("==========")

    local turtle_count, active_count, mining_count, idle_count, halt_count = 0, 0, 0, 0, 0
    
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
    
    local mined_count = 0
    if state.mined_blocks then
        for _, z_table in pairs(state.mined_blocks) do
            for _, _ in pairs(z_table) do
                mined_count = mined_count + 1
            end
        end
    end

    local stats = {
        "Total Turtles: " .. turtle_count,
        "Active Turtles: " .. active_count,
        "Idle Turtles: " .. idle_count,
        "Halted Turtles: " .. halt_count,
        "Mining Turtles: " .. mining_count,
        "Blocks Mined: " .. mined_count,
    }
    
    for i, stat in ipairs(stats) do
        term.setCursorPos(2, 3 + i)
        term.write(stat)
    end
    
    term.setCursorPos(2, 11)
    term.write("System Status: ")
    term.setTextColor(state.on and colors.green or colors.red)
    term.write(state.on and "ON" or "OFF")
    term.setTextColor(colors.white)
    
    term.setCursorPos(2, 13)
    term.write("Hub Version: ")
    draw_version_status(15, 13, get_hub_version(), is_hub_up_to_date())

    term.redirect(monitor.restore_to)
end

-- ============================================================================
-- MAP DRAWING
-- ============================================================================

function draw_location(location, color)
    if location then
        local pixel = {
            x = math.floor((location.x - min_location.x) / zoom_factor),
            y = math.floor((location.z - min_location.z) / zoom_factor) + 1
        }
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
    clear_content_area()

    zoom_factor = math.pow(2, monitor_zoom_level)
    local map_height = monitor_height - 1
    min_location = {
        x = monitor_location.x - math.floor(monitor_width * zoom_factor / 2) - 1,
        z = monitor_location.z - math.floor(map_height * zoom_factor / 2) - 1
    }

    local mined = {}
    for x = min_location.x, min_location.x + (monitor_width * zoom_factor), zoom_factor do
        for z = min_location.z, min_location.z + (map_height * zoom_factor), zoom_factor do
            local xz = x .. "," .. z
            if not mined[xz] then
                local is_mined = state.mined_blocks and state.mined_blocks[x] and state.mined_blocks[x][z]
                mined[xz] = true
                draw_location({x = x, z = z}, is_mined and colors.lightGray or colors.gray)
            end
        end
    end

    local special = {}
    local pixel

    pixel = draw_location(config.locations.mine_exit, colors.blue)
    if pixel then special[pixel.x .. "," .. pixel.y] = colors.blue end

    pixel = draw_location(config.locations.mine_enter, colors.cyan)
    if pixel then special[pixel.x .. "," .. pixel.y] = colors.cyan end

    -- Draw turtle assigned blocks
    for _, turtle in pairs(state.turtles) do
        if turtle.block then
            local mine_enter_y = (config.locations and config.locations.mine_enter and config.locations.mine_enter.y)
                or (config.mine_entrance and config.mine_entrance.y)
                or config.hub_reference.y
            pixel = draw_location({x = turtle.block.x, y = mine_enter_y, z = turtle.block.z}, colors.green)
            if pixel then special[pixel.x .. "," .. pixel.y] = colors.green end
        end
    end

    term.setTextColor(colors.black)
    turtles = {}
    for _, turtle in pairs(state.turtles) do
        if turtle.data then
            local location = turtle.data.location
            if location and location.x and location.y then
                pixel = draw_location(location)
                if pixel then
                    term.setCursorPos(pixel.x, pixel.y)
                    local str_pixel = pixel.x .. "," .. pixel.y
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
                        term.write(#turtles[str_pixel] <= 9 and #turtles[str_pixel] or "+")
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
                term.setBackgroundColor(pocket.last_update + config.pocket_timeout < os.clock() and colors.red or colors.green)
                term.write("M")
            end
        end
    end

    -- Map controls
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.green)
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
        for _, z_table in pairs(state.mined_blocks) do
            for _, _ in pairs(z_table) do
                mined_count = mined_count + 1
            end
        end
    end
    term.setCursorPos(elements.mined_indicator.x, elements.mined_indicator.y)
    term.write(string.format("MINED: %4d", mined_count))
    term.setCursorPos(elements.zoom_indicator.x, elements.zoom_indicator.y)
    term.write("ZOOM: " .. monitor_zoom_level)
    term.setCursorPos(elements.x_indicator.x, elements.x_indicator.y)
    term.write("X: " .. monitor_location.x)
    term.setCursorPos(elements.z_indicator.x, elements.z_indicator.y)
    term.write("Z: " .. monitor_location.z)
    term.setCursorPos(elements.center_indicator.x, elements.center_indicator.y)
    term.write("-CENTER")

    term.redirect(monitor.restore_to)
end

-- ============================================================================
-- TOUCH HANDLING
-- ============================================================================

function handle_tab_click(x)
    local tab_map = {{2, 7, "menu"}, {9, 12, "map"}, {14, 21, "turtles"}, {23, 28, "stats"}}
    for _, t in ipairs(tab_map) do
        if x >= t[1] and x <= t[2] then
            current_tab = t[3]
            return true
        end
    end
    return false
end

function touch_monitor(touch)
    if touch.y == 1 then
        handle_tab_click(touch.x)
        return
    end

    if current_tab == "menu" then
        local menu_actions = {
            {elements.menu_toggle, function() table.insert(state.user_input, state.on and "off" or "on") end},
            {elements.menu_hub_update, function() table.insert(state.user_input, "hubupdate") end},
            {elements.menu_update, function() table.insert(state.user_input, "update") end},
            {elements.menu_return, function() table.insert(state.user_input, "return") end},
            {elements.menu_reboot, function() table.insert(state.user_input, "reboot") end},
            {elements.menu_halt, function() table.insert(state.user_input, "halt") end},
            {elements.menu_clear, function() table.insert(state.user_input, "clear") end},
            {elements.menu_reset, function() table.insert(state.user_input, "reset") end},
        }
        for _, action in ipairs(menu_actions) do
            if touch.x == action[1].x and touch.y == action[1].y then
                action[2]()
                return
            end
        end
    elseif current_tab == "turtles" then
        if #turtles_tab_ids == 0 then return end
        
        local turtle_id = turtles_tab_ids[turtles_tab_selected]
        local turtle = state.turtles[turtle_id]
        
        -- Navigation
        if touch.x == elements.left.x and touch.y == elements.left.y then
            turtles_tab_selected = math.max(turtles_tab_selected - 1, 1)
            return
        elseif touch.x == elements.right.x and touch.y == elements.right.y then
            turtles_tab_selected = math.min(turtles_tab_selected + 1, #turtles_tab_ids)
            return
        end
        
        -- Commands
        local commands = {
            {elements.turtle_return, "return"}, {elements.turtle_update, "update"},
            {elements.turtle_reboot, "reboot"}, {elements.turtle_halt, "halt"},
            {elements.turtle_clear, "clear"}, {elements.turtle_reset, "reset"},
        }
        for _, cmd in ipairs(commands) do
            if touch.x == cmd[1].x and touch.y == cmd[1].y then
                table.insert(state.user_input, cmd[2] .. " " .. turtle_id)
                return
            end
        end
        
        -- Find button
        if touch.x == elements.turtle_find.x and touch.y == elements.turtle_find.y then
            if turtle and turtle.data and turtle.data.location then
                monitor_location.x = turtle.data.location.x
                monitor_location.z = turtle.data.location.z
                current_tab = "map"
            end
            return
        end
        
        -- Movement
        local movements = {
            {elements.turtle_forward, "go forward"}, {elements.turtle_back, "go back"},
            {elements.turtle_up, "go up"}, {elements.turtle_down, "go down"},
            {elements.turtle_left, "go left"}, {elements.turtle_right, "go right"},
        }
        for _, mov in ipairs(movements) do
            if touch.x == mov[1].x and touch.y == mov[1].y then
                table.insert(state.user_input, "turtle " .. turtle_id .. " " .. mov[2])
                return
            end
        end
        
        -- Dig (mining only)
        if turtle and turtle.data and turtle.data.turtle_type == "mining" then
            local digs = {
                {elements.turtle_dig_up, "digblock up"},
                {elements.turtle_dig, "digblock forward"},
                {elements.turtle_dig_down, "digblock down"},
            }
            for _, dig in ipairs(digs) do
                if touch.x == dig[1].x and touch.y == dig[1].y then
                    table.insert(state.user_input, "turtle " .. turtle_id .. " " .. dig[2])
                    return
                end
            end
        end
    elseif current_tab == "map" then
        if touch.x == elements.up.x and touch.y == elements.up.y then
            monitor_location.z = monitor_location.z - zoom_factor
        elseif touch.x == elements.down.x and touch.y == elements.down.y then
            monitor_location.z = monitor_location.z + zoom_factor
        elseif touch.x == elements.left.x and touch.y == elements.left.y then
            monitor_location.x = monitor_location.x - zoom_factor
        elseif touch.x == elements.right.x and touch.y == elements.right.y then
            monitor_location.x = monitor_location.x + zoom_factor
        elseif touch.x == elements.zoom_in.x and touch.y == elements.zoom_in.y then
            monitor_zoom_level = math.max(monitor_zoom_level - 1, 0)
        elseif touch.x == elements.zoom_out.x and touch.y == elements.zoom_out.y then
            monitor_zoom_level = math.min(monitor_zoom_level + 1, config.monitor_max_zoom_level)
        elseif touch.x == elements.center.x and touch.y == elements.center.y then
            monitor_location = {x = config.default_monitor_location.x, z = config.default_monitor_location.z}
        else
            local str_pos = touch.x .. "," .. touch.y
            if turtles[str_pos] then
                turtle_viewer(turtles[str_pos])
            end
        end
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function init_elements()
    elements = {
        up = {x = math.ceil(monitor_width / 2), y = 2},
        down = {x = math.ceil(monitor_width / 2), y = monitor_height},
        left = {x = 1, y = math.ceil(monitor_height / 2)},
        right = {x = monitor_width, y = math.ceil(monitor_height / 2)},
        mined_indicator = {x = monitor_width - 10, y = 3},
        zoom_in = {x = monitor_width, y = 2},
        zoom_out = {x = monitor_width - 8, y = 2},
        zoom_indicator = {x = monitor_width - 7, y = 2},
        center = {x = 1, y = 4},
        center_indicator = {x = 2, y = 4},
        x_indicator = {x = 1, y = 2},
        z_indicator = {x = 1, y = 3},
        version = {x = 2, y = 2},
        viewer_exit = {x = monitor_width, y = 2},
        turtle_face = {x = 5, y = 2},
        turtle_id = {x = 16, y = 2},
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
        menu_title = {x = 6, y = 4},
        menu_version = {x = 6, y = 10},
        menu_suffix = {x = 31, y = 10},
        menu_hub_section = {x = 6, y = 12},
        menu_toggle = {x = 6, y = 13},
        menu_hub_update = {x = 6, y = 14},
        menu_turtle_section = {x = 27, y = 12},
        menu_return = {x = 33, y = 13},
        menu_update = {x = 33, y = 14},
        menu_reboot = {x = 33, y = 15},
        menu_halt = {x = 33, y = 16},
        menu_clear = {x = 33, y = 17},
        menu_reset = {x = 33, y = 18},
    }
end

-- ============================================================================
-- MAIN LOOP
-- ============================================================================

function step()
    while #state.monitor_touches > 0 do
        touch_monitor(table.remove(state.monitor_touches))
    end

    draw_tab_bar()

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

    if monitor_width < 29 or monitor_height < 12 then
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