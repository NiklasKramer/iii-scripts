--[[
    iii arc scanner
    built for iii + arc by n kramer
]]

local arc_sensitivity = 2

local EDIT_MODE = {
    scan = 0,
    single = 1,
    set_min = 2,
    set_max = 3
}

local key1_held = false
local key1_time = 0
local edit_mode = EDIT_MODE.scan
local manual_scan = false
local manual_toggle_direction = 0

local c = {}
for i = 1, 4 do
    c[i] = { cc = 7, ch = i, min = 0, max = 127, value = 64, speed = 0 }
end

for i = 1, 4 do
    arc_res(i, arc_sensitivity)
end

-- Utility functions

local function get_quad_panning_values(pos)
    local segment = 127 / 4
    local rel_pos = pos % 127
    local index = math.floor(rel_pos / segment) + 1
    local next_index = (index % 4) + 1
    local within_segment = (rel_pos % segment) / segment

    local values = { 0, 0, 0, 0 }
    values[index] = math.floor((1 - within_segment) * 127)
    values[next_index] = math.floor(within_segment * 127)
    return values
end

local function send_quad_midi(pan_vals)
    for i = 1, 4 do
        local mapped_value = c[i].min + (pan_vals[i] / 127) * (c[i].max - c[i].min)
        mapped_value = math.floor(clamp(mapped_value, c[i].min, c[i].max))
        midi_cc(c[i].cc, mapped_value, c[i].ch)
    end
end

local function send_single_midi(n)
    midi_cc(c[n].cc, c[n].value, c[n].ch)
end


-- Key interaction handlers

local function handle_key_press()
    key1_held = true
    key1_time = get_time()
end

local function handle_key_release()
    local release_time = get_time()
    if release_time - key1_time < 500 then
        edit_mode = (edit_mode + 1) % (EDIT_MODE.set_max + 1)
        local handler = edit_mode_key_handlers and edit_mode_key_handlers[edit_mode]
        if handler then handler() end

        if edit_mode == EDIT_MODE.scan then
            redraw_all_arcs()
        end
    end
    key1_held = false
end

function arc_key(z)
    if z == 1 then
        handle_key_press()
    else
        handle_key_release()
    end
end

-- Mode handling

local function handle_scan_mode(n, d)
    if n == 1 then
        if manual_scan then
            c[1].value = (c[1].value + d) % 128
            local pan_vals = get_quad_panning_values(c[1].value)
            send_quad_midi(pan_vals)
            arc_redraw(1)
        else
            c[1].speed = clamp(c[1].speed + d * 0.1, -20, 20)
        end
    elseif n == 4 then
        local dir = d > 0 and 1 or -1

        if manual_toggle_direction ~= dir then
            manual_toggle_direction = dir
            manual_toggle_counter = 0
        end

        manual_toggle_counter = manual_toggle_counter + d

        if math.abs(manual_toggle_counter) >= 20 then
            manual_scan = not manual_scan
            manual_toggle_counter = 0
            arc_redraw(4)
        end
    end
end

local function handle_set_min(n, d)
    c[n].min = clamp(c[n].min + d, 0, c[n].max)
end

local function handle_set_max(n, d)
    c[n].max = clamp(c[n].max + d, c[n].min, 127)
end

local function handle_edit_mode(n, d)
    if edit_mode == EDIT_MODE.scan then
        handle_scan_mode(n, d)
    elseif edit_mode == EDIT_MODE.single then
        c[n].value = clamp(c[n].value + d, c[n].min, c[n].max)
        send_single_midi(n)
    elseif edit_mode == EDIT_MODE.set_min then
        handle_set_min(n, d)
    elseif edit_mode == EDIT_MODE.set_max then
        handle_set_max(n, d)
    end
end

-- Arc input

function arc(n, d)
    if key1_held and n == 1 then
        c[1].speed = 0
        return
    end

    handle_edit_mode(n, d)
end

-- Drawing functions
local function draw_range_leds(n, min_val, max_val, highlight_pos)
    local min_pos = (min_val / 127) * 64
    local max_pos = (max_val / 127) * 64
    for i = math.floor(min_pos), math.floor(max_pos) do
        local led_pos = (i % 64) + 1
        arc_led(n, led_pos, 2)
    end
    local highlight_led = (math.floor(highlight_pos) % 64) + 1
    arc_led(n, highlight_led, 10)
end


local function draw_gradient_leds(n, value)
    local pos = (math.floor((value / 127) * 64) % 64)
    for i = -3, 3 do
        local led_pos = ((pos + i) % 64) + 1
        local brightness = math.max(0, 15 - math.abs(i) * 4)
        arc_led(n, led_pos, brightness)
    end
end


local function draw_scan_mode(n)
    if n == 1 then
        draw_gradient_leds(n, c[n].value)
    elseif n == 4 then
        local left_start = 20
        local right_start = 44
        for i = 0, 8 do
            local left_pos = (left_start + i) % 64
            local right_pos = (right_start + i) % 64
            arc_led(n, left_pos + 1, manual_scan and 10 or 2)
            arc_led(n, right_pos + 1, manual_scan and 2 or 10)
        end
    end
end

local arc_draw_modes = {
    [EDIT_MODE.scan] = draw_scan_mode,
    [EDIT_MODE.single] = function(n)
        draw_range_leds(n, c[n].min, c[n].max, (c[n].value / 127) * 64)
    end,
    [EDIT_MODE.set_min] = function(n)
        draw_range_leds(n, c[n].min, c[n].max, (c[n].min / 127) * 64)
    end,
    [EDIT_MODE.set_max] = function(n)
        draw_range_leds(n, c[n].min, c[n].max, (c[n].max / 127) * 64)
    end,
}

-- Redraw helpers
function arc_redraw(n)
    arc_led_all(n, 0)
    local draw_fn = arc_draw_modes[edit_mode]
    if draw_fn then
        draw_fn(n)
    end
    arc_refresh()
end

function redraw_all_arcs()
    for i = 1, 4 do
        arc_redraw(i)
    end
end

function redraw_arc_scan()
    if not manual_scan then
        for n = 1, 4 do
            if c[n].speed ~= 0 then
                c[n].value = (c[n].value + c[n].speed) % 128
                local pan_vals = get_quad_panning_values(c[n].value)
                send_quad_midi(pan_vals)
                arc_redraw(n)
            end
        end
    else
        arc_redraw(1)
        arc_redraw(4)
    end
end

-- Update loop

local mode_update_handlers = {
    [EDIT_MODE.scan] = redraw_arc_scan,
    [EDIT_MODE.single] = redraw_all_arcs,
    [EDIT_MODE.set_min] = redraw_all_arcs,
    [EDIT_MODE.set_max] = redraw_all_arcs
}

metro.new(function()
    local handler = mode_update_handlers[edit_mode]
    if handler then handler() end
end, 33)
