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
local tap_times = { 0, 0, 0, 0 }

note = {}
note[1] = {}
note[2] = {}
note[3] = {}
note[4] = {}

running = { true, true, true, true }

seq = { 1, 1, 1, 1 }

pos = { 0, 0, 0, 0 }
sp = { 0, 0, 0, 0 }
last_led_step = { 0, 0, 0, 0 }

local MIDI_VELOCITY = 75
local ARC_SENSITIVITY = 0.1

local screen_index = 1
local octave = { 0, 0, 0, 0 }

local function play_note(note_val, ch)
    if note_val ~= nil then
        local scale_note = scale[note_val]
        if scale_note == nil then
            local clamped_index = math.max(1, math.min(note_val, #scale))
            scale_note = scale[clamped_index]
        end
        midi_note_on(30 + scale_note + 12 * octave[ch], MIDI_VELOCITY, ch)
    end
end

local function stop_note(note_val, ch)
    if note_val ~= nil then
        local scale_note = scale[note_val]
        if scale_note == nil then
            local clamped_index = math.max(1, math.min(note_val, #scale))
            scale_note = scale[clamped_index]
        end
        midi_note_off(30 + scale_note + 12 * octave[ch], MIDI_VELOCITY, ch)
    end
end

local function draw_arc_notes(n)
    if screen_index == 1 then
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
    elseif screen_index == 2 then
        -- clear LEDs first
        arc_led_all(n, 0)
        local center = 32
        for i = -4, 4 do
            local center_pos = center + i * 6
            for offset = -1, 1 do
                local led_pos = center_pos + offset
                if led_pos >= 1 and led_pos <= 64 then
                    arc_led(n, led_pos, i == octave[n] and 15 or 4)
                end
            end
        end
    end
end

local function update_position_and_trigger(n)
    if not running[n] then return end
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
    if screen_index == 1 then
        if key1_held then
            if d > 0 then
                local ranges = {
                    { 1,  11 },
                    { 12, 23 },
                    { 24, 35 },
                    { 36, 47 },
                }
                local r = ranges[n]
                local new_note = math.random(r[1], r[2])
                local insert_pos = math.random(1, #note[n] + 1)
                table.insert(note[n], insert_pos, new_note)
                if not note[n]._added then note[n]._added = {} end
                table.insert(note[n]._added, insert_pos)
            elseif d < 0 then
                if note[n]._added and #note[n]._added > 0 then
                    local last_added = table.remove(note[n]._added)
                    table.remove(note[n], last_added)
                end
            end
        else
            sp[n] = clamp(sp[n] + d * ARC_SENSITIVITY, -32, 32)
        end
    elseif screen_index == 2 then
        octave[n] = clamp(octave[n] + d, -4, 4)
    end
end

local long_press_triggered = false

function arc_key(z)
    if z == 1 then
        key1_held = true
        key1_press_time = get_time()
        long_press_triggered = false
    else
        key1_held = false
        local now = get_time()
        if now - key1_press_time > 250 then
            long_press_triggered = true
        end
        for n = 1, 4 do
            if now - tap_times[n] < 250 then
                print("here")
                running[n] = not running[n]
                tap_times[n] = 0
                return
            else
                tap_times[n] = now
            end
        end
        if not long_press_triggered then
            screen_index = (screen_index % 2) + 1 -- toggle between 1 and 2 for now
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
