--[[
    iii arc scanner

    built for iii + arc by n kramer
]]
local arc_sensitivity = 8
local speed = { 0 }
local cc_map = {
    {
        { cc = 7, ch = 1, min = 0, max = 127 },
        { cc = 7, ch = 2, min = 0, max = 127 },
        { cc = 7, ch = 3, min = 0, max = 127 },
        { cc = 7, ch = 4, min = 0, max = 127 },

    },
}

local key1_held = false
local pattern_touched = { false }
local patterns = {}
local values = { 0 }

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

local function record_step(pat, value, limit, now)
    if not pat or not pat.data or not pat.start_time then return end
    if #pat.data < limit then
        table.insert(pat.data, {
            value = value,
            time = now - pat.start_time
        })
    else
        pat.recording = false
        pat.playing = true
        pat.play_start_time = get_time()
        pat.index = 1
        print("AUTO STOPPED RECORDING at " .. limit .. " steps")
    end
end

local function play_step(pat, n, values, now)
    if not pat or not pat.data or not pat.play_start_time or not pat.index or not values[n] then return end
    while true do
        local step = pat.data[pat.index]
        if not step or type(step) ~= "table" then break end
        if now - pat.play_start_time >= step.time then
            values[n] = step.value
            local config = cc_map[n]
            midi_cc(config[1].cc, step.value, config[1].ch)
            pat.index = pat.index + 1
            if pat.index > #pat.data then
                pat.index = 1
                pat.play_start_time = get_time()
                break
            end
        else
            break
        end
    end
end

for n = 1, 1 do
    patterns[n] = {
        recording = false,
        playing = false,
        data = {},
        index = 1
    }
end

function arc(n, d)
    if n ~= 1 then return end
    if not cc_map[n] then return end
    if not patterns[n] then return end
    if not values[n] then return end
    local config = cc_map[n]
    local pat = patterns[n]

    if key1_held and not pattern_touched[n] then
        if pat.playing or #pat.data > 0 then
            pat.data = {}
            pat.playing = false
            pat.index = 1
            pat.start_time = nil
            pat.play_start_time = nil
            print("cleared pattern " .. n)
        else
            pat.recording = true
            pat.start_time = get_time()
            pat.data = {}
            pat.index = 1
            print("recording pattern " .. n)
        end
        pattern_touched[n] = true
    end

    speed[n] = clamp(speed[n] + d * 0.1, -5, 5)

    if pat.recording then
        local now = get_time()
        local last_step = pat.data[#pat.data]
        if not last_step or math.abs(values[n] - last_step.value) > 2 or now - pat.start_time - last_step.time > 100 then
            table.insert(pat.data, {
                value = values[n],
                time = now - pat.start_time
            })
        end
    end
end

function arc_redraw(n)
    arc_led_all(n, 0)
    local pos = (math.floor((values[n] / 127) * 64) % 64)
    for i = -3, 3 do
        local led_pos = ((pos + i) % 64) + 1
        local brightness = math.max(0, 15 - math.abs(i) * 4)
        arc_led(n, led_pos, brightness)
    end
    arc_refresh()
end

function arc_key(z)
    -- Implementation has been added to arc_redraw(n)
end

for i = 1, 1 do
    arc_res(i, arc_sensitivity)
end

metro.new(function()
    local now = get_time()
    for n = 1, 1 do
        if speed[n] ~= 0 then
            values[n] = (values[n] + speed[n]) % 128
            local config = cc_map[n]
            local pan_vals = get_quad_panning_values(values[n])
            for i = 1, #config do
                midi_cc(config[i].cc, pan_vals[i], config[i].ch)
            end
            arc_redraw(n)
        end

        local pat = patterns[n]
        if pat.recording then
            local last_step = pat.data[#pat.data]
            if not last_step or math.abs(values[n] - last_step.value) > 2 or now - pat.start_time - last_step.time > 100 then
                table.insert(pat.data, {
                    value = values[n],
                    time = now - pat.start_time
                })
            end
        end
    end
end, 33)
