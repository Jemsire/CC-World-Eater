-- APIs are loaded by startup.lua - this file uses globals from there

function get_action_keys()
    local keys = {}
    -- Use _G.actions to ensure we get the real actions table, not the os.loadAPI wrapper
    local actions_table = _G.actions or actions
    for k, v in pairs(actions_table) do
        table.insert(keys, k)
    end
    return keys
end

function parse_requests()
    -- PROCESS ALL REDNET REQUESTS
    while #state.requests > 0 do
        local request = table.remove(state.requests, 1)
        sender, message, protocol = request[1], request[2], request[3]

        -- Safety check: ensure message exists and has action
        if not message or not message.action then
            print("ERROR: Invalid request format - missing message or action")
            return
        end

        local action = message.action
        local request_id = message.request_id or "nil"

        -- DEBUG: Show processing
        print(
            "[DEBUG] Processing action: " ..
                tostring(action) ..
                    " (request_id: " .. tostring(request_id) .. " vs current: " .. tostring(state.request_id) .. ")"
        )

        if action == "shutdown" then
            os.shutdown()
        elseif action == "reboot" then
            os.reboot()
        elseif action == "update" then
            os.run({}, "/update")
        else
            -- For initialize action, accept with any request_id if not initialized (allows initialization to work)
            -- For other actions, require request_id match
            local request_id_matches = (message.request_id == -1 or message.request_id == state.request_id)
            local is_initialize_action = (message.action == "initialize")
            local should_accept = request_id_matches or (is_initialize_action and not state.initialized)

            if should_accept then
                -- Old code logic: allow initialize action even if not initialized, or any action if initialized
                if state.initialized or message.action == "initialize" then
                    state.busy = true
                    -- Force use of _G.actions - don't fallback to actions wrapper
                    if not _G.actions then
                        print('[DEBUG] ERROR: _G.actions is nil! This should not happen.')
                        state.success = false
                    else
                        -- Check if action exists
                        if not _G.actions[message.action] then
                            print('ERROR: Action "' .. tostring(message.action) .. '" not found in actions table')
                            -- Debug: Show what's actually in _G.actions
                            local keys = {}
                            for k, v in pairs(_G.actions) do
                                table.insert(keys, k)
                            end
                            print('[DEBUG] Available actions in _G.actions: ' .. table.concat(keys, ', '))
                            print('[DEBUG] _G.actions type: ' .. tostring(type(_G.actions)))
                            print('[DEBUG] _G.actions.initialize type: ' .. tostring(type(_G.actions.initialize)))
                            print('[DEBUG] _G.actions.initialize value: ' .. tostring(_G.actions.initialize))
                            -- Also check the wrapper table
                            if actions and type(actions) == "table" then
                                local wrapper_keys = {}
                                for k, v in pairs(actions) do
                                    table.insert(wrapper_keys, k)
                                end
                                print('[DEBUG] Wrapper actions table keys: ' .. table.concat(wrapper_keys, ', '))
                            end
                            state.success = false
                        else
                            -- Safely unpack message.data (handle nil case)
                            local data = message.data or {}
                            print(
                                "[DEBUG] Executing action: " ..
                                    tostring(action) .. " with data: " .. tostring(#data) .. " args"
                            )
                            
                            -- Debug: Show data contents for initialize
                            if action == "initialize" then
                                print("[DEBUG] message.data type: " .. tostring(type(message.data)))
                                print("[DEBUG] message.data value: " .. tostring(message.data))
                                if type(data) == "table" then
                                    print("[DEBUG] data table size: " .. tostring(#data))
                                    print("[DEBUG] data[1] (session_id): " .. tostring(data[1]))
                                    print("[DEBUG] data[2] (config) type: " .. tostring(type(data[2])))
                                end
                                print(
                                    "[DEBUG] INITIALIZE - Before: initialized=" ..
                                        tostring(state.initialized) ..
                                            ", request_id=" ..
                                                tostring(state.request_id) .. ", session_id=" .. tostring(state.session_id)
                                )
                            end

                            local success, result =
                                pcall(
                                function()
                                    return _G.actions[message.action](unpack(data))
                                end
                            )
                            if success then
                                state.success = result
                                print(
                                    "[DEBUG] Action " .. tostring(action) .. " completed with result: " .. tostring(result)
                                )

                                -- Special debug for initialize
                                if action == "initialize" then
                                    print(
                                        "[DEBUG] INITIALIZE - After: initialized=" ..
                                            tostring(state.initialized) ..
                                                ", request_id=" ..
                                                    tostring(state.request_id) ..
                                                        ", session_id=" .. tostring(state.session_id)
                                    )
                                end

                                -- Special debug for calibrate
                                if action == "calibrate" then
                                    if state.location then
                                        print(
                                            "[DEBUG] Calibrate SUCCESS - Location set to: " ..
                                                tostring(state.location.x) ..
                                                    "," ..
                                                        tostring(state.location.y) ..
                                                            "," ..
                                                                tostring(state.location.z) ..
                                                                    " Orientation: " .. tostring(state.orientation)
                                        )
                                    else
                                        print("[DEBUG] Calibrate FAILED - Location is still nil!")
                                    end
                                end
                            else
                                print('ERROR executing action "' .. tostring(message.action) .. '": ' .. tostring(result))
                                state.success = false
                            end
                        end
                    end
                    state.busy = false
                    if not state.success then
                        sleep(1)
                    end
                    state.request_id = state.request_id + 1
                    print("[DEBUG] Updated request_id to: " .. tostring(state.request_id))
                else
                    print(
                        "[DEBUG] Skipping action " ..
                            tostring(action) .. " - turtle not initialized and action is not initialize"
                    )
                end
            else
                print(
                    "[DEBUG] Ignoring action " ..
                        tostring(action) ..
                            " - request_id mismatch (got " ..
                                tostring(request_id) .. ", expected " .. tostring(state.request_id) .. ")"
                )
            end
        end
    end
end

function main()
    state.last_ping = os.clock()
    while true do
        parse_requests()
        sleep(0.3)
    end
end

main()
