-- Load shared APIs (config, state, utilities)
loadfile('/init_apis.lua')()

-- CONTINUOUSLY AWAIT USER INPUT AND PLACE IN TABLE
while true do
    table.insert(state.user_input, read())
end