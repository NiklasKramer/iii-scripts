local screen_index = 1

arc_sensitivity = 3

local cc_map = {
    {
        { cc = 7, ch = 1, min = 0, max = 127 },
        { cc = 7, ch = 2, min = 0, max = 127 },
        { cc = 7, ch = 3, min = 0, max = 127 },
        { cc = 7, ch = 4, min = 0, max = 127 }
    },
    {
        { cc = 7, ch = 5, min = 0, max = 127 },
        { cc = 7, ch = 6, min = 0, max = 127 },
        { cc = 7, ch = 7, min = 0, max = 127 },
        { cc = 7, ch = 8, min = 0, max = 127 }
    },
    {
        { cc = 108, ch = 1, min = 0, max = 127 },
        { cc = 109, ch = 1, min = 0, max = 127 },
        { cc = 110, ch = 1, min = 0, max = 127 },
        { cc = 111, ch = 1, min = 0, max = 127 }
    },
    {
        { cc = 112, ch = 1, min = 0, max = 127 },
        { cc = 113, ch = 1, min = 0, max = 127 },
        { cc = 114, ch = 1, min = 0, max = 127 },
        { cc = 115, ch = 1, min = 0, max = 127 }
    }
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
end, 30)

function arc(n, d)
    local config = cc_map[screen_index][n]
    values[screen_index][n] = clamp(values[screen_index][n] + d, config.min, config.max)
    midi_cc(config.cc, values[screen_index][n], config.ch)
end

function midi_rx(ch, status, data1, data2)
    if status == 176 then -- CC message
        for i = 1, 4 do
            local config = cc_map[screen_index][i]
            if data1 == config.cc and ch == config.ch then
                values[screen_index][i] = clamp(data2, config.min, config.max)
            end
        end
    end
end

function arc_redraw(n)
    arc_led_all(n, 0)
    local start_led = 44
    local end_led = 21
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
        local base = 28
        local spacing = 3
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

for i = 1, 4 do
    arc_res(i, arc_sensitivity)
end
