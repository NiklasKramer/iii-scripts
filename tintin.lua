print("\n^______^ tintin")

key_long = false

-- four voices, each with a melody sequence
note = {}

-- Sequence 1: A minor pentatonic scale expanding upwards
note[1] = {}
do
    local scale = { 45, 48, 50, 52, 55 }
    for i = 0, 15 do
        table.insert(note[1], scale[(i % #scale) + 1] + 12 * math.floor(i / #scale))
    end
end

-- Sequence 2: Rolling triads in C major
note[2] = {}
do
    local triads = {
        { 48, 52, 55 }, -- C
        { 50, 53, 57 }, -- Dm
        { 52, 55, 59 }, -- Em
        { 53, 57, 60 }, -- F
        { 55, 59, 62 }, -- G
        { 57, 60, 64 }, -- Am
    }
    for i = 1, 16 do
        local chord = triads[(math.floor(i / 4) % #triads) + 1]
        table.insert(note[2], chord[(i % 3) + 1])
    end
end

-- Sequence 3: Ascending A major scale
note[3] = {}
do
    local scale = { 69, 71, 72, 74, 76, 77, 79, 81 }
    for i = 0, 15 do
        table.insert(note[3], scale[(i % #scale) + 1])
    end
end

-- Sequence 4: Repeating E minor arpeggios
note[4] = {}
do
    local arp = { 52, 55, 59, 64 }
    for i = 0, 15 do
        table.insert(note[4], arp[(i % #arp) + 1] + 12 * math.floor(i / 16))
    end
end

seq = { 1, 1, 1, 1 }
pos = { 0, 0, 0, 0 }
window_start = { 1, 1, 1, 1 }
window_length = { 3, 3, 3, 3 }
sp = { 0, 0, 0, 0 }

local root_note = 60
local triad = { 4, 7, 11 }


-- Tintinnabuli mode per encoder: 1 = 2nd pos superior, 2 = 1st pos superior, 3 = 1st pos inferior, 4 = 2nd pos inferior, 5 = random, 0 = off
tintin_mode = { 5, 5, 5, 5 }

-- Velocity settings
base_melody_velocity = 70
base_tintin_velocity = 60
melody_velocity_range = 20
tintin_velocity_range = 30

mode = 1
edit_mode = 1

arc_refresh()

function generate_tintinnabuli(m_note, n)
    if not m_note or tintin_mode[n] == 0 then return nil end
    local m_pitch = m_note % 12
    local mode = tintin_mode[n] or 0
    if mode == 5 then mode = math.random(1, 4) end

    -- Find closest triad note
    local closest_index = 1
    local min_dist = 12
    for idx, i in ipairs(triad) do
        local t_pitch = (root_note + i) % 12
        local dist = math.abs(m_pitch - t_pitch)
        if dist < min_dist then
            min_dist = dist
            closest_index = idx
        end
    end

    -- Determine triad position
    local triad_len = #triad
    local target_index = closest_index
    if mode == 1 then -- 2nd pos superior
        target_index = ((closest_index + 1) - 1) % triad_len + 1
        target_index = ((target_index + 1) - 1) % triad_len + 1
    elseif mode == 2 then -- 1st pos superior
        target_index = ((closest_index + 1) - 1) % triad_len + 1
    elseif mode == 3 then -- 1st pos inferior
        target_index = ((closest_index - 2) % triad_len) + 1
    elseif mode == 4 then -- 2nd pos inferior
        target_index = ((closest_index - 3) % triad_len) + 1
    end

    return root_note + triad[target_index]
end

function tick()
    step_voices()
    arc_redraw()
end

function step_voices()
    for n = 1, 4 do
        pos[n] = pos[n] + sp[n]
        local ch = n

        if pos[n] < 0 or pos[n] > 1023 then
            midi_note_off(note[n][seq[n]], 127, ch)
            local start = window_start[n]
            local len = window_length[n]
            seq[n] = ((seq[n] - start + (sp[n] > 0 and 1 or -1)) % len + len) % len + start
            local mel = note[n][seq[n]]
            local tnt = generate_tintinnabuli(mel, n)
            local mel_vel = base_melody_velocity + math.random(-melody_velocity_range, melody_velocity_range)
            local tintin_velocity = base_tintin_velocity + math.random(-tintin_velocity_range, tintin_velocity_range)
            midi_note_on(mel, mel_vel, ch)
            if tnt then midi_note_on(tnt, tintin_velocity, ch) end
            pos[n] = pos[n] % 1024
        end
    end
end

function arc_redraw()
    if mode == 1 then
        clear_arc()
        for n = 1, 4 do
            arc_led_all(n, 0)
            local s = window_start[n]
            local l = window_length[n]
            for i = 0, l - 1 do
                local step_index = s + i
                if step_index == seq[n] then
                    arc_led(n, 32 + step_index * 2, 9)
                else
                    arc_led(n, 32 + step_index * 2, 1)
                end
            end
            point(n, pos[n])
        end
        arc_refresh()
    elseif mode == 2 then
        if edit_mode == 1 then
            for n = 1, 4 do
                arc_led_all(n, 0)
                local active_mode = tintin_mode[n]
                for i = 1, 5 do
                    arc_led(n, 10 + i * 4, (i == active_mode and active_mode > 0) and 15 or 2)
                end

                local center = 40
                for offset = -2, 2 do
                    arc_led(n, center + offset, active_mode == 0 and 2 or 10)
                end
            end
            arc_refresh()
        elseif edit_mode == 2 then
            for n = 1, 4 do
                arc_led_all(n, 0)
                local s = window_start[n]
                local l = window_length[n]
                for i = 1, #note[n] do
                    local pos = 10 + ((i - 1) % 64)
                    if i == s then
                        arc_led(n, pos, 15)
                    elseif i > s and i < s + l then
                        arc_led(n, pos, 5)
                    else
                        arc_led(n, pos, 1)
                    end
                end
            end
            arc_refresh()
        elseif edit_mode == 3 then
            for n = 1, 4 do
                arc_led_all(n, 0)
                local s = window_start[n]
                local l = window_length[n]
                -- Show all steps dimly
                for i = 1, #note[n] do
                    arc_led(n, 10 + ((i - 1) % 64), 1)
                end
                -- Highlight current window
                for i = 0, l - 1 do
                    local step = (s + i - 1) % 64
                    local level = (i == l - 1) and 12 or 5
                    arc_led(n, 10 + step, level)
                end
            end
            arc_refresh()
        end
    end
end

function clear_arc()
    for i = 1, 4 do
        arc_led_all(i, 0)
    end
    arc_refresh()
end

m = metro.new(tick, 33)

function arc(n, d)
    if mode == 1 then
        sp[n] = clamp(sp[n] + d, -32, 32)
    elseif mode == 2 and edit_mode == 1 then
        tintin_mode[n] = clamp(tintin_mode[n] + d, 0, 5)
        print(string.format("encoder %d tintin_mode = %d", n, tintin_mode[n]))
    elseif mode == 2 and edit_mode == 2 then
        window_start[n] = clamp(window_start[n] + d, 1, math.max(1, #note[n] - window_length[n] + 1))
        print(string.format("encoder %d window_start = %d", n, window_start[n]))
    elseif mode == 2 and edit_mode == 3 then
        window_length[n] = clamp(window_length[n] + d, 1, #note[n] - window_start[n] + 1)
        print(string.format("encoder %d window_length = %d", n, window_length[n]))
    end
end

function arc_key(z)
    if z == 1 then
        key_long = false
        if km then metro.stop(km) end
        km = metro.new(function()
            key_long = true
            arc_key_long()
        end, 500, 1)
    elseif z == 0 and km then
        metro.stop(km)
        km = nil
        if not key_long then
            print("keyshort")
            if mode == 1 then
                for n = 1, 4 do sp[n] = 0 end
            else
                edit_mode = edit_mode % 3 + 1
                print("edit_mode" .. edit_mode)
            end
        end
    end
end

function arc_key_long()
    if mode == 1 then
        mode = 2
        for i = 1, 4 do
            arc_res(i, 20)
        end

        print("EDIT MODE")
    else
        mode = 1
        for i = 1, 4 do
            arc_res(i, 1)
        end
        print("PLAY_MODE")
    end
end

function point(n, x)
    local c = x >> 4
    arc_led_rel(n, c % 64 + 1, 15)
    arc_led_rel(n, (c + 1) % 64 + 1, x % 16)
    arc_led_rel(n, (c + 63) % 64 + 1, 15 - (x % 16))
end
