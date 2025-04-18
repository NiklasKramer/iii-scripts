print("rotations is based on snow")

local base_scale = { 0, 2, 4, 7, 9, 11 }
local scale = {}
for i = 0, 7 do
    for _, v in ipairs(base_scale) do
        table.insert(scale, v + 12 * i)
    end
end
local key1_held = false
local key1_press_time = 0

note = {}
note[1] = { 1, 2, nil, 4 }
note[2] = { 3, 5 }
note[3] = { 6, 1, 2, 3 }
note[4] = { 4, 2, 5, 6, 1 }

seq = { 1, 1, 1, 1 }

pos = { 0, 0, 0, 0 }
sp = { 0, 0, 0, 0 }
last_led_step = { 0, 0, 0, 0 }

local MIDI_VELOCITY = 75
local ARC_SENSITIVITY = 0.10

local function random_pattern(range, d)
    local max_steps = 32
    local min_steps = 4
    local scaled_d = d * 0.2
    local steps = clamp(math.floor(8 + scaled_d * 2), min_steps, max_steps)
    local nil_chance = clamp(0.2 + (-scaled_d * 0.05), 0.2, 0.8)
    local pattern = {}
    local last_note = nil
    for i = 1, steps do
        if math.random() < nil_chance then
            pattern[i] = nil
        else
            local note
            repeat
                note = math.random(range[1], range[2])
            until note ~= last_note
            pattern[i] = note
            last_note = note
        end
    end
    return pattern
end

local function play_note(note_val, ch)
    if note_val ~= nil then
        local scale_note = scale[note_val]
        if scale_note == nil then
            -- clamp to the closest index in scale
            local clamped_index = math.max(1, math.min(note_val, #scale))
            scale_note = scale[clamped_index]
        end
        midi_note_on(24 + scale_note, MIDI_VELOCITY, ch)
    end
end

local function stop_note(note_val, ch)
    if note_val ~= nil then
        local scale_note = scale[note_val]
        if scale_note == nil then
            local clamped_index = math.max(1, math.min(note_val, #scale))
            scale_note = scale[clamped_index]
        end
        midi_note_off(24 + scale_note, MIDI_VELOCITY, ch)
    end
end

local function draw_arc_notes(n)
    for m = 1, #note[n] do
        if note[n][m] ~= nil then
            local led_pos = math.floor((m - 1) * 64 / #note[n]) + 1
            arc_led(n, led_pos, 1)
        end
    end
    if note[n][seq[n]] ~= nil then
        local active_pos = math.floor((seq[n] - 1) * 64 / #note[n]) + 1
        arc_led(n, active_pos, 10)
    end
end

local function update_position_and_trigger(n)
    pos[n] = pos[n] + sp[n]
    pos[n] = pos[n] % 1024
    local current_led_step = math.floor(pos[n] / 16)
    if current_led_step ~= last_led_step[n] then
        last_led_step[n] = current_led_step
        for m = 1, #note[n] do
            local note_led = math.floor((m - 1) * 64 / #note[n])
            if note_led == current_led_step then
                if note[n][m] ~= nil then
                    stop_note(note[n][seq[n]], n)
                    seq[n] = m
                    play_note(note[n][seq[n]], n)
                else
                    stop_note(note[n][seq[n]], n)
                    seq[n] = m
                end
            end
        end
    end
end

arc_refresh()

function tick()
    for n = 1, 4 do
        arc_led_all(n, 0)
        update_position_and_trigger(n)
        draw_arc_notes(n)
        point(n, pos[n])
    end
    arc_refresh()
end

m = metro.new(tick, 33)

function arc(n, d)
    if key1_held then
        local ranges = {
            { 1,  11 }, -- bass
            { 12, 23 }, -- low mids
            { 24, 35 }, -- mids
            { 36, 47 }, -- highs
        }
        note[n] = random_pattern(ranges[n], d)
    else
        sp[n] = clamp(sp[n] + d * ARC_SENSITIVITY, -32, 32)
    end
end

function arc_key(z)
    time = get_time()
    print(time)
    if z == 1 then
        key1_held = true
        key1_press_time = get_time()
    else
        print("else")
        key1_held = false

        if get_time() - key1_press_time < 250 then
            print('quicktime')
            for n = 1, 4 do sp[n] = 0 end
        end
    end
end

function point(n, x)
    x = math.floor(x)
    local c = math.floor(x / 16)
    arc_led_rel(n, c % 64 + 1, 15)
    arc_led_rel(n, (c + 1) % 64 + 1, x % 16)
    arc_led_rel(n, (c + 63) % 64 + 1, 15 - (x % 16))
end
