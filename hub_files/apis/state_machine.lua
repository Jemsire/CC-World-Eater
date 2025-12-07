-- ============================================
-- State Machine Module
-- Handles turtle state transitions and command logic
-- ============================================

-- Get API references
-- These must be available when this module loads (init_apis.lua loads config/state/utilities first)
local config = API.getConfig()
local state = API.getState()
local utilities = API.getUtilities()

function command_turtles()
    -- Check for out-of-date turtles and set them to updating state
    check_turtle_versions()
    
    -- Check if all updating turtles are done and update hub if needed
    if state.update_hub_after then
        local any_updating = false
        for _, turtle in pairs(state.turtles) do
            if turtle.data and turtle.state == 'updating' then
                any_updating = true
                break
            end
        end
        
        if not any_updating then
            print('All turtles updated. Updating hub...')
            sleep(1)
            if state.force_update then
                os.run({}, '/update', 'force')
            else
                os.run({}, '/update')
            end
            API.setStateValue('update_hub_after', false)
            API.setStateValue('force_update', false)
        end
    end
    
    local turtles_for_pair = {}
    
    for _, turtle in pairs(state.turtles) do
        
        if turtle.data then
        
            -- Check if turtle sent initialization_report (self-initialized)
            if turtle.data.action == 'initialization_report' then
                -- Turtle has self-initialized and is reporting readiness
                print('Turtle ' .. turtle.id .. ' initialized - type: ' .. (turtle.data.turtle_type or 'unknown'))
                
                -- Store location from initialization report (in case regular reports don't include it yet)
                if turtle.data.location then
                    turtle.init_location = turtle.data.location
                    turtle.init_orientation = turtle.data.orientation
                end
                
                -- Mark turtle as not ready until handshake is received
                turtle.ready = false
                
                -- Check if turtle has old session_id (hub restarted, turtle didn't)
                if turtle.data.session_id and turtle.data.session_id ~= session_id then
                    print('Turtle ' .. turtle.id .. ' has old session_id - forcing reboot')
                    -- Free turtle from assignments
                    free_turtle(turtle)
                    -- Clear tasks
                    turtle.tasks = {}
                    -- Send reboot command
                    DataThread.send(turtle.id, {
                        action = 'reboot',
                    }, 'mastermine')
                    turtle.needs_reboot = true
                    turtle.data.action = nil  -- Clear action so we don't process it again
                    -- Skip the rest of initialization for this turtle
                else
                    -- Check if turtle needs update BEFORE sending config
                    check_turtle_version_on_init(turtle)
                    
                    -- Send config to complete initialization (unless turtle needs update first)
                    if turtle.state ~= 'updating' then
                        if not turtle.data.session_id or turtle.data.session_id ~= session_id or not turtle.ready then
                            -- Turtle needs config or needs to re-send handshake
                            initialize_turtle(turtle)
                            
                            -- Immediately send the initialize task if it was added
                            if #turtle.tasks > 0 and turtle.tasks[1].action == 'initialize' then
                                send_tasks(turtle)
                            end
                        end
                    end
                    -- Clear the action flag so normal reporting continues
                    turtle.data.action = nil
                end
            elseif turtle.data.session_id ~= session_id then
                -- Turtle has mismatched session_id - either never initialized or has old session_id
                if turtle.data.session_id then
                    -- Turtle has old session_id (hub restarted) - needs to reboot to clear state
                    if not turtle.needs_reboot then
                        -- Get current session_id safely
                        local current_session_id = session_id
                        if not current_session_id and fs.exists('/session_id') then
                            local session_file = fs.open('/session_id', 'r')
                            if session_file then
                                current_session_id = tonumber(session_file.readAll())
                                session_file.close()
                            end
                        end
                        local session_str = current_session_id and tostring(current_session_id) or 'unknown'
                        print('Turtle ' .. turtle.id .. ' has old session_id (' .. turtle.data.session_id .. 
                              '), current hub session: ' .. session_str .. '. Forcing reboot...')
                        -- Free turtle from assignments
                        free_turtle(turtle)
                        -- Clear tasks
                        turtle.tasks = {}
                        -- Send reboot command
                        DataThread.send(turtle.id, {
                            action = 'reboot',
                        }, 'mastermine')
                        turtle.needs_reboot = true  -- Mark to prevent duplicate reboots
                    end
                else
                    -- Turtle has no session_id (never initialized) - send initialize command
                    if (not turtle.tasks) or (not turtle.tasks[1]) or (not (turtle.tasks[1].action == 'initialize')) then
                        initialize_turtle(turtle)
                        
                        -- Immediately send the initialize task if it was added
                        if #turtle.tasks > 0 and turtle.tasks[1].action == 'initialize' then
                            send_tasks(turtle)
                        end
                    end
                end
            end
            
            -- Check if turtle that completed update now has version data to verify
            if turtle.update_complete and turtle.data and turtle.data.version then
                verify_turtle_version_after_update(turtle)
            end

            -- Ensure tasks is initialized
            if not turtle.tasks then
                turtle.tasks = {}
            end
            
            -- Ensure ready flag is initialized
            if turtle.ready == nil then
                turtle.ready = false
            end
            
            -- Send initialize tasks immediately (even if turtle not ready yet)
            -- Other tasks only sent if turtle is ready
            -- Updating turtles can send update-related tasks (go_to_disk, go_to_home, calibrate, update)
            if #turtle.tasks > 0 then
                local has_initialize_task = false
                local is_update_task = false
                for _, task in ipairs(turtle.tasks) do
                    if task.action == 'initialize' then
                        has_initialize_task = true
                        break
                    elseif task.action == 'go_to_disk' or task.action == 'go_to_home' or 
                           task.action == 'calibrate' or task.action == 'update' then
                        is_update_task = true
                        break
                    end
                end
                
                if has_initialize_task then
                    -- Send initialize task immediately (turtle needs this to become ready)
                    send_tasks(turtle)
                elseif turtle.state == 'updating' and is_update_task then
                    -- Updating turtle - only send update-related tasks
                    send_tasks(turtle)
                elseif turtle.state ~= 'updating' and turtle.ready then
                    -- TURTLE IS READY - send other tasks (but not if updating)
                    send_tasks(turtle)
                end
            elseif not turtle.ready and turtle.state ~= 'updating' then
                -- No tasks and not ready - check if we need to send initialize
                if turtle.data.session_id == session_id and turtle.data.action ~= 'initialization_report' then
                    -- Turtle has session_id but not ready - might need to re-send initialize to trigger handshake
                    -- Check if turtle has initialize task queued
                    local has_initialize = false
                    if turtle.tasks and #turtle.tasks > 0 then
                        for _, task in ipairs(turtle.tasks) do
                            if task.action == 'initialize' then
                                has_initialize = true
                                break
                            end
                        end
                    end
                    
                    if not has_initialize then
                        -- Turtle has session_id but isn't ready and has no initialize task - send initialize
                        initialize_turtle(turtle)
                        -- Immediately send the initialize task if it was added
                        if #turtle.tasks > 0 and turtle.tasks[1].action == 'initialize' then
                            send_tasks(turtle)
                        end
                    end
                end
            end

            elseif not turtle.data.location then
                -- TURTLE NEEDS A MAP
                -- Check if turtle has location from initialization report (self-initialized turtles)
                if turtle.init_location then
                    -- Use stored location from initialization report
                    turtle.data.location = turtle.init_location
                    turtle.data.orientation = turtle.init_orientation
                    print('Using stored location from initialization report for turtle ' .. turtle.id)
                -- But only if turtle is initialized (has session_id matching hub)
                -- Self-initialized turtles already have location, so this is for legacy turtles
                elseif turtle.data.session_id == session_id then
                    -- Check if calibrate task already exists to prevent loops
                    local has_calibrate_task = false
                    if turtle.tasks then
                        for _, task in ipairs(turtle.tasks) do
                            if task.action == 'calibrate' then
                                has_calibrate_task = true
                                break
                            end
                        end
                    end
                    if not has_calibrate_task then
                        add_task(turtle, {action = 'calibrate'})
                    end
                end

            elseif turtle.state ~= 'halt' then
                -- TURTLE IS READY AND CAN RECEIVE COMMANDS
                -- Handle initial routing after handshake (turtle just became ready)
                if turtle.ready and turtle.data.session_id == session_id and turtle.just_became_ready then
                    -- Turtle just completed handshake - route based on on/off state
                    -- Only route if turtle is in 'lost' state (initial state after initialization)
                    -- Don't route if turtle is updating - let it finish updating first
                    if turtle.state == 'lost' then
                        print('Turtle ' .. turtle.id .. ' just became ready - routing based on on/off state (on=' .. tostring(state.on) .. ')')
                        if state.on then
                            -- System is on - send turtle to idle state (will be assigned mining tasks)
                            add_task(turtle, {action = 'pass', end_state = 'idle'})
                        else
                            -- System is off - send turtle to park
                            add_task(turtle, {action = 'go_to_home', end_state = 'park'})
                        end
                    elseif turtle.state == 'updating' then
                        -- Turtle is updating - don't route yet, will route after update completes
                        print('Turtle ' .. turtle.id .. ' just became ready but is updating - will route after update completes')
                    end
                    -- Clear the flag so we don't route again
                    turtle.just_became_ready = false
                end

                if turtle.state == 'park' then
                    -- TURTLE FOUND PARKING
                    if state.on and (config.use_chunky_turtles or turtle.data.turtle_type == 'mining') then
                        add_task(turtle, {action = 'pass', end_state = 'idle'})
                    end

                elseif not state.on and turtle.state ~= 'idle' then
                    -- TURTLE HAS TO STOP
                    add_task(turtle, {action = 'pass', end_state = 'idle'})

                elseif turtle.state == 'lost' then
                    -- TURTLE IS CONFUSED
                    if turtle.data.location.y < config.locations.mine_enter.y and (turtle.pair or not config.use_chunky_turtles) then
                        add_task(turtle, {action = 'pass', end_state = 'trip'})
                        if turtle.block then
                            add_task(turtle, {
                                action = 'go_to_block',
                                data = {turtle.block},
                                end_state = 'wait'
                            })
                        else
                            add_task(turtle, {action = 'pass', end_state = 'idle'})
                        end
                    else
                        add_task(turtle, {action = 'pass', end_state = 'idle'})
                    end

                elseif turtle.state == 'idle' then
                    -- TURTLE IS BORED
                    free_turtle(turtle)
                    if turtle.data.location.y < config.locations.mine_enter.y then
                        send_turtle_up(turtle)
                    elseif not utilities.in_area(turtle.data.location, config.locations.control_room_area) then
                        halt(turtle)
                    elseif turtle.data.item_count > 0 or (turtle.data.fuel_level ~= "unlimited" and turtle.data.fuel_level < config.fuel_per_unit) then
                        add_task(turtle, {action = 'prepare', data = {config.fuel_per_unit}})
                    elseif state.on then
                        add_task(turtle, {
                            action = 'go_to_waiting_room',
                            end_function = check_pair_fuel,
                            end_function_args = {turtle},
                        })
                    else
                        add_task(turtle, {action = 'go_to_home', end_state = 'park'})
                    end

                elseif turtle.state == 'pair' then
                    -- TURTLE NEEDS A FRIEND
                    if config.use_chunky_turtles then
                        if not state.pair_hold then
                            if not turtle.pair then
                                table.insert(turtles_for_pair, turtle)
                            end
                        else
                            local state_refresh = API.getState()
                            if state_refresh.pair_hold and not (state_refresh.pair_hold[1].pair and state_refresh.pair_hold[2].pair) then
                                API.setStateValue('pair_hold', nil)
                            end
                        end
                    else
                        solo_turtle_begin(turtle)
                    end

                elseif turtle.state == 'trip' then
                    -- TURTLE IS TRAVELING TO BLOCK
                    -- If turtle has no tasks but has a block assignment, ensure it continues navigation
                    if turtle.block and (#turtle.tasks == 0) then
                        -- Check if this is a chunky turtle that should wait for pair_turtles_send callback
                        -- But if mining turtle is already at wait state, the callback may have been missed
                        if turtle.pair and turtle.data.turtle_type == 'chunky' and turtle.pair.state == 'wait' then
                            -- Mining turtle is already at block, add tasks for chunky turtle to catch up
                            add_task(turtle, {
                                action = 'go_to_mine_enter',
                                end_function = pair_turtles_finish
                            })
                            -- Chunky turtle should be one block south of mining turtle
                            add_task(turtle, {
                                action = 'go_to_block_offset',
                                data = {turtle.block, 1},  -- 1 block south (positive Z)
                                end_state = 'wait',
                            })
                        elseif not turtle.pair or turtle.data.turtle_type == 'mining' then
                            -- Mining turtle or solo turtle - continue to block
                            if not utilities.in_area(turtle.data.location, config.locations.waiting_room_area) then
                                add_task(turtle, {action = 'go_to_mine_enter'})
                            end
                            add_task(turtle, {
                                action = 'go_to_block',
                                data = {turtle.block},
                                end_state = 'wait',
                            })
                        end
                        -- If chunky turtle and mining turtle not at wait yet, wait for pair_turtles_send callback
                    elseif not turtle.block then
                        -- No block assignment, go idle
                        add_task(turtle, {action = 'pass', end_state = 'idle'})
                    end

                elseif turtle.state == 'wait' then
                    -- TURTLE GO DO SOME WORK
                    if turtle.block then
                        if turtle.pair then
                            if turtle.data.turtle_type == 'mining' and turtle.pair.state == 'wait' then
                                -- Check if inventory full or fuel low
                                if (turtle.data.empty_slot_count == 0 and turtle.pair.data.empty_slot_count == 0) or not good_on_fuel(turtle, turtle.pair) then
                                    add_task(turtle, {action = 'pass', end_state = 'idle'})
                                    add_task(turtle.pair, {action = 'pass', end_state = 'idle'})
                                elseif turtle.data.empty_slot_count == 0 then
                                    -- Dump items
                                    add_task(turtle, {action = 'dump', data = {'north'}})
                                else
                                    add_task(turtle, {action = 'pass', end_state = 'mine'})
                                    add_task(turtle.pair, {action = 'pass', end_state = 'mine'})
                                    go_mine(turtle)
                                end
                            end
                        elseif not config.use_chunky_turtles then
                            -- Solo turtle mining block
                            if turtle.data.empty_slot_count == 0 or not good_on_fuel(turtle) then
                                add_task(turtle, {action = 'pass', end_state = 'idle'})
                            else
                                add_task(turtle, {action = 'pass', end_state = 'mine'})
                                go_mine(turtle)
                            end
                        else
                            add_task(turtle, {action = 'pass', end_state = 'idle'})
                        end
                    else
                        -- No assignment, go idle
                        add_task(turtle, {action = 'pass', end_state = 'idle'})
                    end
                elseif turtle.state == 'mine' then
                    if config.use_chunky_turtles and not turtle.pair then
                        add_task(turtle, {action = 'pass', end_state = 'idle'})
                    end
                    
                elseif turtle.state == 'updating' then
                    -- TURTLE IS UPDATING
                    -- First, ensure turtle is not halted (clear halt if it exists)
                    if fs.exists(state.turtles_dir_path .. turtle.id .. '/halt') then
                        unhalt(turtle)
                    end
                    
                    -- Check if turtle needs to return home first
                    local is_home = false
                    local is_at_disk = false
                    local is_near_home = false
                    
                    if turtle.data and turtle.data.location then
                        is_home = (config.locations.home_area and utilities.in_area(turtle.data.location, config.locations.home_area)) or
                                  utilities.in_area(turtle.data.location, config.locations.greater_home_area)
                        is_at_disk = utilities.in_location(turtle.data.location, config.locations.disk_drive)
                        is_near_home = is_home or utilities.in_area(turtle.data.location, config.locations.greater_home_area)
                    end
                    
                    if is_at_disk then
                        -- Turtle is at disk drive
                        -- Mark that turtle has reached disk
                        turtle.update_sent_to_disk = true
                        
                        -- Check if other turtles are updating (wait if so)
                        local turtles_at_disk = count_turtles_at_disk()
                        if turtles_at_disk > 1 then
                            -- Another turtle is updating, wait
                            if not turtle.update_waiting_at_disk then
                                print('Turtle ' .. turtle.id .. ' waiting at disk drive (other turtle updating)...')
                                turtle.update_waiting_at_disk = true
                            end
                            -- Just wait, don't send update command yet
                        else
                            -- No other turtles updating, proceed with update
                            if not turtle.update_waiting_at_disk or turtle.update_waiting_at_disk then
                                -- Clear waiting flag and send update command
                                turtle.update_waiting_at_disk = nil
                                print('Turtle ' .. turtle.id .. ' at disk drive. Starting update...')
                                -- Clear any existing tasks before sending update command
                                turtle.tasks = {}
                                DataThread.send(turtle.id, {
                                    action = 'update',
                                }, 'mastermine')
                            end
                        end
                    elseif is_near_home then
                        -- Turtle is near home, navigate to disk drive
                        if not turtle.update_sent_to_disk and not turtle.update_waiting_at_disk then
                            add_task(turtle, {
                                action = 'go_to_disk',
                                end_state = 'updating',  -- Stay in updating state
                            })
                            -- Don't set update_sent_to_disk yet - wait until turtle reaches disk
                        end
                    elseif turtle.data and turtle.data.location then
                        -- Turtle needs to return home first (only if we have location data)
                        if not turtle.update_sent_home then
                            send_turtle_up(turtle)
                            add_task(turtle, {
                                action = 'go_to_home',
                                end_state = 'updating',  -- Stay in updating state
                            })
                            turtle.update_sent_home = true
                        end
                    else
                        -- Turtle doesn't have location data - need to calibrate first
                        if not turtle.update_sent_home then
                            add_task(turtle, {
                                action = 'calibrate',
                                end_state = 'updating',  -- Stay in updating state after calibration
                            })
                            turtle.update_sent_home = true  -- Mark that we've started the update process
                        end
                    end
                    
                    -- Version verification happens after update completes and turtle initializes
                    -- See verify_turtle_version_after_update() which is called when turtle reports version
                    
                elseif turtle.state == 'following' then
                    -- CHUNKY TURTLE FOLLOWING MINING TURTLE
                    -- Keep chunky turtle 2 blocks above mining turtle during mining
                    if turtle.pair and turtle.pair.data and turtle.pair.data.location then
                        local mining_location = turtle.pair.data.location
                        local target_location = {
                            x = mining_location.x,
                            y = mining_location.y + 2,  -- 2 blocks above
                            z = mining_location.z
                        }
                        
                        -- Check if chunky turtle needs to move
                        if turtle.data and turtle.data.location then
                            local current = turtle.data.location
                            -- If not at target position, move there
                            if current.x ~= target_location.x or 
                               current.y ~= target_location.y or 
                               current.z ~= target_location.z then
                                add_task(turtle, {
                                    action = 'follow_mining_turtle',
                                    data = {target_location},
                                    end_state = 'following',  -- Stay in following state
                                })
                            end
                        else
                            -- No location data, try to get there anyway
                            add_task(turtle, {
                                action = 'follow_mining_turtle',
                                data = {target_location},
                                end_state = 'following',
                            })
                        end
                    else
                        -- No pair or no location data, go idle
                        add_task(turtle, {action = 'pass', end_state = 'idle'})
                    end
                end
            end
        end
    end
    if #turtles_for_pair == 2 then
        pair_turtles_begin(turtles_for_pair[1], turtles_for_pair[2])
    end
end

