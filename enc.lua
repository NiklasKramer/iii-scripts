local screen_index = 1
local cc_map = {
    { 100, 101, 102, 103 },
    { 104, 105, 106, 107 },
    { 108, 109, 110, 111 },
    { 112, 113, 114, 115 }
}
local values = {
    { 0, 0, 0, 0 },
    { 0, 0, 0, 0 },
    { 0, 0, 0, 0 },
    { 0, 0, 0, 0 }
}

local m = metro.new(function()
    for n = 1, 4 do
        arc_redraw(n)
    end
end, 33)

function arc(n, d)
    values[screen_index][n] = clamp(values[screen_index][n] + d, 0, 127)
    midi_cc(cc_map[screen_index][n], values[screen_index][n], 1)
end

function arc_redraw(n)
    arc_led_all(n, 0)
    local start_led = 48 -- 8 o'clock
    local end_led = 17   -- 4 o'clock
    local led_span = ((end_led - start_led + 64) % 64)
    local led_pos = math.floor(values[screen_index][n] / 127 * led_span)
    for i = 0, led_pos do
        local led = ((start_led + i) % 64) + 1
        arc_led(n, led, 2)
    end
    local highlight = ((start_led + led_pos) % 64) + 1
    arc_led(n, highlight, 10)
    arc_refresh()

    if n == 1 then
        local base = 26
        local spacing = 4
        for i = 0, 3 do
            local led = (base + (3 - i) * spacing) % 64
            arc_led(n, led, (i + 1) == screen_index and 10 or 2)
        end
    end
end

function arc_key(k, z)
    if k == 1 then
        screen_index = (screen_index % 4) + 1
        print('')
    end
end
