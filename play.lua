-- Grid Pattern Recorder with Playback and Visual Indicators
print("Grid Pattern Recorder Initialized")
TRANSPOSE_DEFAULT      = 0
DEFAULT_VELOCITY       = 90
DEFAULT_INTERVAL       = 10
global_time            = 0
playback_active        = false
playback_index         = 1
midichannel            = 1
flash_state            = false

screen_mode            = { channel_edit = 1, play = 2, pattern_edit = 3 }
current_screen         = screen_mode.play

transpose              = TRANSPOSE_DEFAULT
shift                  = 0
selected_scale         = 1
scales                 = {
    { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 },
    { 0, 2, 4, 7, 9 },
    { 0, 2, 4, 7, 9, 11 },
    { 0, 2, 4, 5, 7, 9 },
    { 0, 2, 4, 5, 7, 9, 11 }
}

playback_speed_options = { 0.25, 0.33, 0.5, 0.75, 1, 1.25, 1.5, 2, 4 }

recorders              = {
    { recording = {}, recording_active = false, playback_active = false, playback_index = 1, record_start_time = 0, playback_speed = 1 },
    { recording = {}, recording_active = false, playback_active = false, playback_index = 1, record_start_time = 0, playback_speed = 1 },
    { recording = {}, recording_active = false, playback_active = false, playback_index = 1, record_start_time = 0, playback_speed = 1 },
    { recording = {}, recording_active = false, playback_active = false, playback_index = 1, record_start_time = 0, playback_speed = 1 },
    { recording = {}, recording_active = false, playback_active = false, playback_index = 1, record_start_time = 0, playback_speed = 1 },
    { recording = {}, recording_active = false, playback_active = false, playback_index = 1, record_start_time = 0, playback_speed = 1 },
    { recording = {}, recording_active = false, playback_active = false, playback_index = 1, record_start_time = 0, playback_speed = 1 },
    { recording = {}, recording_active = false, playback_active = false, playback_index = 1, record_start_time = 0, playback_speed = 1 }
}


chords = {
    { 0 },
    { 0, 12 },
    { 0, 5 },
    { 0, 7 },
    { 0, 2, 7 },
    { 0, 5, 7 },
    { 0, 5, 10 },
    { 0, 7, 14 },
    { 0, 3, 7 },
    { 0, 4, 7 },
    { 0, 7, 15 },
    { 0, 7, 16 },
    { 0, 4, 7, 11 },
    { 0, 3, 7, 10 },
    { 0, 7, 10 },
    { 0, 7, 12 },
}

channels = {
    { velocity = DEFAULT_VELOCITY, velocity_range = 7, sustain = 0, octave = 0, transpose = 0, chord = chords[1] },
    { velocity = DEFAULT_INTERVAL, velocity_range = 7, sustain = 0, octave = 0, transpose = 0, chord = chords[1] },
    { velocity = DEFAULT_INTERVAL, velocity_range = 7, sustain = 0, octave = 0, transpose = 0, chord = chords[1] },
    { velocity = DEFAULT_INTERVAL, velocity_range = 7, sustain = 0, octave = 0, transpose = 0, chord = chords[1] },
    { velocity = DEFAULT_INTERVAL, velocity_range = 7, sustain = 0, octave = 0, transpose = 0, chord = chords[1] },
    { velocity = DEFAULT_INTERVAL, velocity_range = 7, sustain = 0, octave = 0, transpose = 0, chord = chords[1] },
    { velocity = DEFAULT_INTERVAL, velocity_range = 7, sustain = 0, octave = 0, transpose = 0, chord = chords[1] },
    { velocity = DEFAULT_INTERVAL, velocity_range = 7, sustain = 0, octave = 0, transpose = 0, chord = chords[1] }

}

held_notes = {}


--
--
-- // PATTER RECORDER \\

function start_recording(index)
    local recorder = recorders[index]
    recorder.recording = {}
    recorder.playback_speed = 1
    recorder.recording_active = true
    recorder.record_start_time = global_time
    flash_state = true
    metro_set(4, 500, -1)

    local x, y = (index - 1) % 4 + 9, math.floor((index - 1) / 4) + 1
    grid_led(x, y, 15)
    grid_refresh()
    print("Recorder " .. index .. " started recording")
end

function stop_recording(index)
    local recorder = recorders[index]
    recorder.recording_active = false
    flash_state = false
    metro_set(4, 0)

    clear_all_held_notes()
    refresh_recorder_leds()

    print("Recorder " .. index .. " stopped recording and cleared all stuck notes")
end

function start_playback(index)
    local recorder = recorders[index]
    if #recorder.recording == 0 then
        print("Recorder " .. index .. " has no recorded events")
        return
    end
    recorder.playback_active = true
    recorder.playback_index = 1
    recorder.record_start_time = global_time

    local interval = DEFAULT_INTERVAL / (recorder.playback_speed or 1)
    metro_set(2, interval, -1)

    refresh_recorder_leds()

    print("Recorder " .. index .. " started playback with speed " .. recorder.playback_speed)
end

function stop_playback(index)
    local recorder = recorders[index]
    recorder.playback_active = false

    recorder.playback_index = 1
    recorder.record_start_time = 0

    clear_all_held_notes()

    refresh_recorder_leds()

    print("Recorder " .. index .. " stopped playback and cleared all stuck notes")
end

function record_event(x, y, z)
    for index, recorder in ipairs(recorders) do
        if recorder.recording_active then
            local timestamp = global_time - recorder.record_start_time
            table.insert(recorder.recording, { x = x, y = y, z = z, time = timestamp, channel = midichannel })
            print("Recorded event in Recorder " .. index .. " at time " .. timestamp)
        end
    end
end

function handle_pattern_recorder(x, y, z)
    if (y == 1 or y == 2) and x >= 9 and x <= 12 then
        local index = (y - 1) * 4 + (x - 8)
        local recorder = recorders[index]

        if shift == 1 then
            recorder.recording = {}
            recorder.recording_active = false
            recorder.playback_active = false
            grid_led(x, y, 1)
            grid_refresh()
            print("Recorder " .. index .. " cleared")
        elseif z == 1 then
            if not recorder.recording_active and not recorder.playback_active and #recorder.recording == 0 then
                start_recording(index)
            elseif recorder.recording_active then
                stop_recording(index)
                start_playback(index)
            elseif recorder.playback_active then
                stop_playback(index)
            elseif not recorder.playback_active and #recorder.recording > 0 then
                start_playback(index)
            end
        end
    end
end

--
--
-- // SCALES AND TRANSPOSE
function handle_scale_selection(x)
    for i = 2, #scales + 1 do
        grid_led(i, 16, 5)
    end
    selected_scale = x - 1
    grid_led(x, 16, 15)
    grid_refresh()
end

function handle_transpose(x, z)
    if z == 1 then
        clear_all_held_notes()

        transpose = transpose + (x == 14 and -1 or x == 15 and 1 or 0)
        if shift == 1 then
            transpose = TRANSPOSE_DEFAULT
        end
        grid_led(14, 16, transpose < TRANSPOSE_DEFAULT and 15 or 5)
        grid_led(15, 16, transpose > TRANSPOSE_DEFAULT and 15 or 5)
        grid_refresh()
        print("Transpose set to:", transpose)
    end
end

--
--
-- // CHANNEL EDIT MODE \\

-- HANDLERS
function handle_channel_edit_mode(x, y, z)
    if current_screen == screen_mode.channel_edit then
        display_channel_edit_mode()
    end

    if y == 4 then
        handle_velocity_selection(x, y, z)
    elseif y == 5 then
        handle_velocity_range_selection(x, y, z)
    elseif y == 7 then
        handle_sustain_selection(x, y, z)
    elseif y == 9 then
        handle_octave_selection(x, y, z)
    elseif y == 10 then
        handle_channel_transpose_selection(x, y, z)
    elseif y == 12 then
        handle_chord_selection(x, y, z)
    end
end

--
--
-- // RECORDER EDIT MODE \\
function handle_pattern_edit_mode(x, y, z)
    clear_section_leds()
    print("Recorder Edit Mode")
end

function handle_pattern_playback_speed(x, y, z)
    if z == 1 and y >= 4 and y <= 11 then
        local speed_positions = { 4, 5, 6, 7, 8, 9, 10, 11, 12 }


        for i, pos in ipairs(speed_positions) do
            if x == pos then
                local selected_speed = playback_speed_options[i] or 1

                local pattern_index = y - 3
                if recorders[pattern_index] then
                    recorders[pattern_index].playback_speed = selected_speed
                    print("Pattern " .. pattern_index .. " playback speed set to " .. selected_speed .. "x")
                end

                break
            end
        end

        display_pattern_edit_mode()
    end
end

function display_pattern_edit_mode()
    clear_section_leds()

    for i, recorder in ipairs(recorders) do
        display_playback_speed(3 + i, "Pattern " .. i, recorder.playback_speed)
    end

    grid_refresh()
end

function display_playback_speed(y, label, speed)
    local speed_positions = { 4, 5, 6, 7, 8, 9, 10, 11, 12 }

    for i, value in ipairs(playback_speed_options) do
        grid_led(speed_positions[i], y, value == speed and 15 or 5)
    end

    print(label .. " Speed: " .. speed .. "x")
end

------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------



function handle_velocity_selection(x, y, z)
    if z == 1 and y == 4 then
        local new_velocity = math.floor((x / 16) * 127)
        if shift == 1 then
            new_velocity = 0
        end
        channels[midichannel].velocity = new_velocity

        display_velocity_for_channel()

        print("Channel " .. midichannel .. " velocity set to " .. new_velocity)
    end
end

function handle_velocity_range_selection(x, y, z)
    if z == 1 and y == 5 then
        local new_range = math.floor((x / 16) * 127)
        if shift == 1 then
            new_range = 0
        end
        channels[midichannel].velocity_range = new_range

        display_velocity_range_for_channel()

        print("Channel " .. midichannel .. " velocity range set to " .. new_range)
    end
end

function handle_sustain_selection(x, y, z)
    if z == 1 and y == 7 then
        local channel = channels[midichannel]

        local previous_sustain = channel.sustain
        channel.sustain = (channel.sustain == 0) and 1 or 0

        local sustain_value = (channel.sustain == 1) and 127 or 0
        midi_tx(0, 0xB0 + midichannel - 1, 64, sustain_value)

        if previous_sustain == 1 and channel.sustain == 0 then
            for note, _ in pairs(held_notes) do
                midi_tx(0, 0x80 + midichannel - 1, note, 0) -- Send Note Off
                held_notes[note] = nil
            end
        end

        display_sustain_for_channel()
        print("Channel " ..
            midichannel .. " sustain set to " .. channel.sustain .. " (MIDI CC64 = " .. sustain_value .. ")")
    end
end

function handle_octave_selection(x, y, z)
    if z == 1 and y == 9 then
        clear_all_held_notes() -- ✅ Use helper function

        -- ✅ Change octave based on the grid position
        if x == 8 or x == 9 then
            channels[midichannel].octave = 0
        elseif x < 8 then
            channels[midichannel].octave = math.max(-4, x - 8)
        elseif x > 9 then
            channels[midichannel].octave = math.min(4, x - 9)
        end
        if shift == 1 then
            channels[midichannel].octave = 0
        end

        display_octave_for_channel()
        print("Channel " .. midichannel .. " octave set to " .. channels[midichannel].octave)
    end
end

function handle_channel_transpose_selection(x, y, z)
    if z == 1 and y == 10 then
        clear_all_held_notes()

        if x == 8 or x == 9 then
            channels[midichannel].transpose = 0
        elseif x < 8 then
            channels[midichannel].transpose = -(8 - x)
        elseif x > 9 then
            channels[midichannel].transpose = x - 9
        end
        if shift == 1 then
            channels[midichannel].transpose = 0
        end

        display_channel_transpose_for_channel()
        print("Channel " .. midichannel .. " transpose set to " .. channels[midichannel].transpose)
    end
end

function handle_chord_selection(x, y, z)
    if z == 1 and y == 12 then
        clear_all_held_notes()

        if x >= 1 and x <= #chords then
            if shift == 1 then
                channels[midichannel].chord = chords[1]
            else
                channels[midichannel].chord = chords[x]
            end
        end

        display_chord_selection()
        print("Channel " .. midichannel .. " chord set to index " .. x)
    end
end

------------------------------------------------------------------------------------------------------------------------

-- DISPLAY


function display_velocity_for_channel()
    for i = 1, 16 do
        grid_led(i, 4, 0)
    end

    local velocity_x = math.ceil(channels[midichannel].velocity / 127 * 16)

    for i = 1, velocity_x do
        grid_led(i, 4, 1)
    end

    grid_led(velocity_x, 4, 10)
    grid_refresh()
end

function display_velocity_range_for_channel()
    for i = 1, 16 do
        grid_led(i, 5, 0)
    end

    local range_x = math.ceil(channels[midichannel].velocity_range / 127 * 16)
    for i = 1, range_x do
        grid_led(i, 5, 1)
    end

    grid_led(range_x, 5, 10)
    grid_refresh()
end

function display_channel_transpose_for_channel()
    for i = 1, 16 do
        grid_led(i, 10, 0)
    end

    for i = 1, 16 do
        grid_led(i, 10, 1)
    end

    local transpose = channels[midichannel].transpose
    local center_x = 8
    grid_led(8, 10, 8)
    grid_led(9, 10, 8)

    if transpose == 0 then
        grid_led(8, 10, 15)
        grid_led(9, 10, 15)
    elseif transpose < 0 then
        grid_led(center_x + transpose, 10, 10)
    else
        grid_led(center_x + transpose + 1, 10, 10)
    end

    grid_refresh()
end

function display_sustain_for_channel()
    for i = 1, 16 do
        grid_led(i, 7, 0) -- Clear row first
    end

    -- Use different LED brightness for a pattern
    for i = 1, 16, 3 do
        local brightness = (channels[midichannel].sustain == 1) and 15 or 3
        grid_led(i, 7, brightness) -- Bright LEDs for sustain ON
    end

    grid_refresh()
end

function display_octave_for_channel()
    for i = 1, 16 do
        grid_led(i, 9, 0) -- Clear row
    end

    -- Pre-light the full octave range (-4 to +4)
    for i = 4, 13 do
        grid_led(i, 9, 1)
    end
    grid_led(8, 9, 8)
    grid_led(9, 9, 8)

    local octave = channels[midichannel].octave
    local center_x = 8 -- Middle keys (8 & 9) represent octave 0

    -- Highlight selected octave
    if octave == 0 then
        grid_led(8, 9, 17)
        grid_led(9, 9, 15)
    elseif octave < 0 then
        grid_led(center_x + octave, 9, 10)     -- Left side (down)
    else
        grid_led(center_x + octave + 1, 9, 10) -- Right side (up)
    end

    grid_refresh()
end

function display_chord_selection()
    for i = 1, 16 do
        grid_led(i, 12, 1) -- Dim pre-highlight for all options
    end

    -- Highlight selected chord
    for i, chord in ipairs(chords) do
        if chord == channels[midichannel].chord then
            grid_led(i, 12, 15) -- Brightest for selected chord
        end
    end

    grid_refresh()
end

function display_channel_edit_mode()
    clear_section_leds()

    display_velocity_for_channel()
    display_velocity_range_for_channel()
    display_sustain_for_channel()
    display_octave_for_channel()
    display_channel_transpose_for_channel()
    display_chord_selection()
end

--
--
-- // GRID HANDLER \\
function handle_channel_selection(x, y, z)
    if z == 1 then
        if x >= 1 and x <= 4 and (y == 1 or y == 2) then
            local new_channel = (y - 1) * 4 + x
            if new_channel > 8 then return end

            local prev_x = ((midichannel - 1) % 4) + 1
            local prev_y = math.floor((midichannel - 1) / 4) + 1
            grid_led(prev_x, prev_y, 3)

            -- ✅ Set new channel
            midichannel = new_channel

            -- ✅ Highlight selected channel properly
            grid_led(x, y, 10)
            grid_refresh()

            print("MIDI Channel set to:", midichannel)
            if current_screen == screen_mode.channel_edit then
                display_channel_edit_mode()
            end
        end
    end
end

function handle_note_generation(x, y, z, playback_channel)
    local target_channel = playback_channel or midichannel
    local channel_settings = channels[target_channel]

    local raw_note = x + (7 - y) * 5 + 50

    local scale = scales[selected_scale]
    local octave_offset = math.floor(raw_note / 12) * 12
    local closest_note_in_scale = scale[1]

    for _, note in ipairs(scale) do
        local scaled_note = octave_offset + note
        if math.abs(raw_note - scaled_note) < math.abs(raw_note - (octave_offset + closest_note_in_scale)) then
            closest_note_in_scale = note
        end
    end

    local quantized_note = octave_offset + closest_note_in_scale
    quantized_note = quantized_note + (channel_settings.octave * 12) + channel_settings.transpose + transpose

    local base_velocity = channel_settings.velocity
    local velocity_range = channel_settings.velocity_range
    local final_velocity = math.max(0, math.min(127, base_velocity + math.random(-velocity_range, velocity_range)))

    local chord_intervals = channel_settings.chord

    if z == 1 then
        for _, interval in ipairs(chord_intervals) do
            local chord_note = quantized_note + interval
            local note_velocity = math.max(0, math.min(127, base_velocity + math.random(-velocity_range, velocity_range)))
            midi_tx(0, 0x90 + target_channel - 1, chord_note, note_velocity)

            if not held_notes[target_channel] then
                held_notes[target_channel] = {}
            end
            held_notes[target_channel][chord_note] = true
        end

        if current_screen == screen_mode.play then
            grid_led(x, y, 15)
        end
    else
        if held_notes[target_channel] then
            for _, interval in ipairs(chord_intervals) do
                local chord_note = quantized_note + interval
                send_note_off(target_channel, chord_note)
            end
        end

        if current_screen == screen_mode.play then
            grid_led(x, y, 0)
        end
    end

    grid_refresh()
end

function handle_shift(x, y, z)
    shift = z                               -- Active while pressed
    grid_led(16, 1, shift == 1 and 15 or 1) -- Bright when active, dim otherwise
    grid_refresh()
    print("Shift " .. (shift == 1 and "Activated" or "Deactivated"))
end

function handle_edit_mode_toggle(x, y, z)
    if x == 15 and y == 1 and z == 1 then
        current_screen = (current_screen == screen_mode.channel_edit) and screen_mode.play or screen_mode.channel_edit

        refresh_recorder_leds()
        grid_refresh()

        if current_screen == screen_mode.channel_edit then
            display_channel_edit_mode()
            print("Edit Mode Enabled")
        else
            print("Play Mode Enabled")
        end
    end
end

function handle_pattern_edit_toggle(x, y, z)
    if z == 1 then
        if current_screen == screen_mode.pattern_edit then
            current_screen = screen_mode.play
            grid_led(14, 1, 1)
            print("Pattern Edit Mode Disabled")

            refresh_recorder_leds()
        else
            current_screen = screen_mode.pattern_edit
            grid_led(14, 1, 10)
            print("Pattern Edit Mode Enabled")

            display_pattern_edit_mode()
        end
    end
    grid_refresh()
end

grid = function(x, y, z)
    if x == 15 and y == 1 then
        handle_edit_mode_toggle(x, y, z)
        return
    end

    if x == 14 and y == 1 then
        handle_pattern_edit_toggle(x, y, z)
        return
    end

    if x == 16 and y == 1 then
        handle_shift(x, y, z)
        return
    end

    if (y == 1 or y == 2) and x >= 9 and x <= 12 then
        handle_pattern_recorder(x, y, z)
        return
    end

    if y == 16 then
        if x > 1 and x <= #scales + 1 then
            handle_scale_selection(x)
        elseif x == 14 or x == 15 then
            handle_transpose(x, z)
        end
        return
    end

    if y < 3 then
        handle_channel_selection(x, y, z)
        return
    end

    local any_recorder_active = false
    for _, recorder in ipairs(recorders) do
        if recorder.recording_active then
            any_recorder_active = true
            break
        end
    end

    if any_recorder_active then
        record_event(x, y, z)
    end

    if current_screen == screen_mode.pattern_edit then
        handle_pattern_playback_speed(x, y, z)
        return
    end


    if current_screen == screen_mode.channel_edit then
        handle_channel_edit_mode(x, y, z)
    else
        handle_note_generation(x, y, z)
    end

    grid_refresh()
end

--
--
-- // METRO CALLBACK \\
function metro(index, stage)
    if index == 2 then
        global_time = global_time + 0.01

        for rec_index, recorder in ipairs(recorders) do
            if recorder.playback_active and recorder.playback_index <= #recorder.recording then
                local event = recorder.recording[recorder.playback_index]

                local speed_factor = 1 / recorder.playback_speed
                if global_time >= event.time * speed_factor + recorder.record_start_time then
                    if recorder.playback_index > 1 then
                        local prev_event = recorder.recording[recorder.playback_index - 1]
                        send_note_off(prev_event.channel, prev_event.x + prev_event.y * 5 + 50)
                    end

                    handle_note_generation(event.x, event.y, event.z, event.channel)

                    if current_screen == screen_mode.play and not current_screen == screen_mode.pattern_edit then
                        if event.channel == midichannel then
                            -- Full brightness for the current channel
                            grid_led(event.x, event.y, event.z * 15)
                        else
                            -- Dim brightness for other channels
                            grid_led(event.x, event.y, event.z * 1)
                        end
                    end


                    recorder.playback_index = recorder.playback_index + 1

                    if recorder.playback_index > #recorder.recording then
                        recorder.playback_index = 1
                        recorder.record_start_time = global_time
                        print("Recorder " .. rec_index .. " looped playback at speed " .. recorder.playback_speed)
                    end
                end
            end
        end
    elseif index == 3 then
        if current_screen == screen_mode.play then
            grid_led(16, 4, 0)
            grid_refresh()
        end
    end
end

function start_global_timer()
    metro_set(2, 10, -1)
    print("Global timer started")
end

function stop_global_timer()
    metro_set(2, 0)
    print("Global timer stopped")
end

--
--
-- // HELPER FUNCTIONS \\
function clear_channel_leds(channel)
    for _, recorder in ipairs(recorders) do
        for _, event in ipairs(recorder.recording) do
            if event.channel == channel then
                grid_led(event.x, event.y, 1)
            end
        end
    end
    grid_refresh()
end

function clear_all_held_notes()
    for channel, notes in pairs(held_notes) do
        for note, _ in pairs(notes) do
            send_note_off(channel, note)
        end
    end
    held_notes = {}
end

function send_note_off(channel, note)
    if held_notes[channel] and held_notes[channel][note] then
        midi_tx(0, 0x80 + channel - 1, note, 0) -- ✅ Send MIDI Note Off
        held_notes[channel][note] = nil         -- ✅ Remove from tracking

        -- ✅ If no more held notes exist for this channel, clear the table
        if next(held_notes[channel]) == nil then
            held_notes[channel] = nil
        end
    end
end

function clear_section_leds()
    for y = 3, 15 do
        for x = 1, 16 do
            grid_led(x, y, 0)
        end
    end
end

function refresh_recorder_leds()
    -- ✅ Do not refresh if in pattern edit mode
    if current_screen == screen_mode.pattern_edit then
        return
    end

    initialize_grid()

    for index, recorder in ipairs(recorders) do
        local x, y = (index - 1) % 4 + 9, math.floor((index - 1) / 4) + 1

        if recorder.recording_active then
            grid_led(x, y, 15) -- 🔴 Recording (Bright Red)
        elseif recorder.playback_active then
            grid_led(x, y, 10) -- 🟠 Playing (Bright Orange)
        elseif #recorder.recording > 0 then
            grid_led(x, y, 5)  -- 🔵 Paused (Dim Blue)
        else
            grid_led(x, y, 1)  -- ⚫ Empty (Dim)
        end
    end

    grid_refresh()
end

--
--
-- // INIT \\
function initialize_grid()
    for x = 1, 16 do
        for y = 1, 16 do
            grid_led(x, y, 0)
        end
    end

    for i = 2, #scales + 1 do
        grid_led(i, 16, (i - 1) == selected_scale and 15 or 5)
    end

    for y = 1, 2 do
        for x = 1, 4 do
            local channel = (y - 1) * 4 + x
            if channel <= 8 then
                grid_led(x, y, channel == midichannel and 10 or 3)
            end
        end
    end


    grid_led(14, 16, 5)
    grid_led(15, 16, 5)



    for y = 1, 2 do
        for x = 9, 12 do
            local index = (y - 1) * 4 + (x - 7)
            grid_led(x, y, 1)
        end
    end


    grid_led(15, 1, current_screen == screen_mode.channel_edit and 15 or 5)

    grid_led(14, 1, current_screen == screen_mode.pattern_edit and 10 or 1)

    grid_led(16, 1, shift == 1 and 15 or 3)

    grid_refresh()
end

start_global_timer()
initialize_grid()
