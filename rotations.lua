print("rotations is based on snow")
note = {}
note[1] = { 45, 43, nil, 50 }
note[2] = { 55, 64 }
note[3] = { 69, 74, 76, 79 }
note[4] = { 86, 83, 81, 72, 79 }

seq = { 1, 1, 1, 1 }

pos = { 0, 0, 0, 0 }
sp = { 0, 0, 0, 0 }
last_led_step = { 0, 0, 0, 0 }

local MIDI_VELOCITY = 75

local function play_note(note_val, ch)
    midi_note_on(note_val, MIDI_VELOCITY, ch)
end

local function stop_note(note_val, ch)
    midi_note_off(note_val, MIDI_VELOCITY, ch)
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
    local sensitivity = 0.10
    sp[n] = clamp(sp[n] + d * sensitivity, -32, 32)
end

function arc_key(z)
    for n = 1, 4 do sp[n] = 0 end
end

function point(n, x)
    x = math.floor(x)
    local c = math.floor(x / 16)
    arc_led_rel(n, c % 64 + 1, 15)
    arc_led_rel(n, (c + 1) % 64 + 1, x % 16)
    arc_led_rel(n, (c + 63) % 64 + 1, 15 - (x % 16))
end
