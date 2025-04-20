local screen_index = 1

local arc_sensitivity = 3
local key1_held = false
local key1_time = 0
local pattern_touched = {
    { false, false, false, false },
    { false, false, false, false },
    { false, false, false, false },
    { false, false, false, false }
}
local patterns = {}

for s = 1, 4 do
    patterns[s] = {}
    for n = 1, 4 do
        patterns[s][n] = {
            recording = false,
            playing = false,
            data = {},
            index = 1
        }
    end
end

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

function arc(n, d)
    local config = cc_map[screen_index][n]
    local pat = patterns[screen_index][n]

    if key1_held and not pattern_touched[screen_index][n] then
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
        pattern_touched[screen_index][n] = true
    end

    local target = clamp(values[screen_index][n] + d, config.min, config.max)
    values[screen_index][n] = target
    midi_cc(config.cc, target, config.ch)

    if pat.recording then
        table.insert(pat.data, {
            value = target,
            time = get_time() - pat.start_time
        })
    end
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

function arc_key(z)
    print(ps(z))
    if z == 1 then
        key1_held = true
        key1_time = get_time()
        print("KEY 1 PRESSED at " .. key1_time)
    else
        key1_held = false
        local release_time = get_time()
        print("KEY 1 RELEASED at " .. release_time)
        for i = 1, 4 do
            pattern_touched[screen_index][i] = false
        end
        if release_time - key1_time < 500 then
            screen_index = (screen_index % 4) + 1
            print("SWITCHED TO SCREEN " .. screen_index)
        end
        -- stop recording
        for n = 1, 4 do
            local pat = patterns[screen_index][n]
            if pat.recording then
                pat.recording = false
                pat.play_start_time = get_time()
                pat.playing = true
                pat.index = 1
                print("PLAYING PATTERN " .. n)
            end
        end
    end
end

for i = 1, 4 do
    arc_res(i, arc_sensitivity)
end

metro.new(function()
    for n = 1, 4 do
        arc_redraw(n)
    end
end, 33)

metro.new(function()
    for n = 1, 4 do
        local pat = patterns[screen_index][n]

        -- playback logic
        local now = get_time()
        if pat.playing and pat.play_start_time then
            while true do
                local step = pat.data[pat.index]
                if not step or type(step) ~= "table" then break end
                if now - pat.play_start_time >= step.time then
                    values[screen_index][n] = step.value
                    local config = cc_map[screen_index][n]
                    midi_cc(config.cc, step.value, config.ch)
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

        -- recording logic: unconditionally record while pattern is active
        if pat.recording then
            local now = get_time()
            local current_value = values[screen_index][n]
            pat.data[#pat.data + 1] = {
                value = current_value,
                time = now - pat.start_time
            }
        end
    end
end, 33)
