-- Grid Pattern Recorder with Playback and Visual Indicators
print("Grid Pattern Recorder Initialized")

global_time = 0
playback_active = false
playback_index = 1
midichannel = 1
flash_state = false
channel_edit_mode = false
transpose = 24
shift = 0
selected_scale = 1
scales = {
    { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 },
    { 0, 2, 4, 7, 9 },
    { 0, 2, 4, 7, 9, 11 },
    { 0, 2, 4, 5, 7, 9 },
    { 0, 2, 4, 5, 7, 9, 11 }
}

recorders = {
    { recording = {}, recording_active = false, playback_active = false, playback_index = 1, record_start_time = 0 },
    { recording = {}, recording_active = false, playback_active = false, playback_index = 1, record_start_time = 0 },
    { recording = {}, recording_active = false, playback_active = false, playback_index = 1, record_start_time = 0 },
    { recording = {}, recording_active = false, playback_active = false, playback_index = 1, record_start_time = 0 },
    { recording = {}, recording_active = false, playback_active = false, playback_index = 1, record_start_time = 0 },
    { recording = {}, recording_active = false, playback_active = false, playback_index = 1, record_start_time = 0 },
    { recording = {}, recording_active = false, playback_active = false, playback_index = 1, record_start_time = 0 },
    { recording = {}, recording_active = false, playback_active = false, playback_index = 1, record_start_time = 0 }
}

channels = {
    { velocity = 90, velocity_range = 0, sustain = 0, octave = 0, transpose = 0 },
    { velocity = 90, velocity_range = 0, sustain = 0, octave = 0, transpose = 0 },
    { velocity = 90, velocity_range = 0, sustain = 0, octave = 0, transpose = 0 },
    { velocity = 90, velocity_range = 0, sustain = 0, octave = 0, transpose = 0 },
    { velocity = 90, velocity_range = 0, sustain = 0, octave = 0, transpose = 0 },
    { velocity = 90, velocity_range = 0, sustain = 0, octave = 0, transpose = 0 },
    { velocity = 90, velocity_range = 0, sustain = 0, octave = 0, transpose = 0 },
    { velocity = 90, velocity_range = 0, sustain = 0, octave = 0, transpose = 0 }
}

--
--
-- // PATTER RECORDER \\

function start_recording(index)
    local recorder = recorders[index]
    recorder.recording = {}
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

    local x, y = (index - 1) % 4 + 9, math.floor((index - 1) / 4) + 1
    grid_led(x, y, 10)
    grid_refresh()
    print("Recorder " .. index .. " stopped recording")
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

    -- ✅ Now fully ignores LED updates in edit mode
    if not channel_edit_mode then
        local x, y = (index - 1) % 4 + 9, math.floor((index - 1) / 4) + 1
        grid_led(x, y, 10)
        grid_refresh()
    end

    print("Recorder " .. index .. " started playback with " .. #recorder.recording .. " events")
end

function stop_playback(index)
    local recorder = recorders[index]
    recorder.playback_active = false

    -- ✅ Block LED clearing if in edit mode
    if not channel_edit_mode then
        for _, event in ipairs(recorder.recording) do
            grid_led(event.x, event.y, 0) -- Turns off playback lights only if not in edit mode
        end

        -- ✅ Prevent recorder LED from coming back in edit mode
        local x, y = (index - 1) % 4 + 9, math.floor((index - 1) / 4) + 1
        grid_led(x, y, 5)
        grid_refresh()
    end

    print("Recorder " .. index .. " stopped playback")
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
        if x == 14 then
            transpose = transpose - 1
        elseif x == 15 then
            transpose = transpose + 1
        end

        if transpose == 24 then
            grid_led(14, 16, 5)
            grid_led(15, 16, 5)
        else
            grid_led(14, 16, transpose < 24 and 15 or 5)
            grid_led(15, 16, transpose > 24 and 15 or 5)
        end

        grid_refresh()
        print("Transpose set to:", transpose)
    end
end

--
--
-- // CHANNEL EDIT MODE \\
function display_velocity_for_channel()
    for i = 1, 16 do
        grid_led(i, 3, 0)
    end

    local velocity_x = math.ceil(channels[midichannel].velocity / 127 * 16)
    for i = 1, velocity_x do
        grid_led(i, 3, 1)
    end

    grid_led(velocity_x, 3, 10)
    grid_refresh()
end

function display_velocity_range_for_channel()
    for i = 1, 16 do
        grid_led(i, 4, 0)
    end

    local range_x = math.ceil(channels[midichannel].velocity_range / 127 * 16)
    for i = 1, range_x do
        grid_led(i, 4, 1)
    end

    grid_led(range_x, 4, 10)
    grid_refresh()
end

function handle_velocity_range_selection(x, y, z)
    if z == 1 and y == 4 then
        local new_range = math.floor((x / 16) * 127)
        channels[midichannel].velocity_range = new_range

        display_velocity_range_for_channel()

        print("Channel " .. midichannel .. " velocity range set to " .. new_range)
    end
end

function handle_velocity_selection(x, y, z)
    if z == 1 and y == 3 then
        local new_velocity = math.floor((x / 16) * 127)
        channels[midichannel].velocity = new_velocity

        display_velocity_for_channel()

        print("Channel " .. midichannel .. " velocity set to " .. new_velocity)
    end
end

-- Make sure held_notes exists
held_notes = {}

function handle_sustain_selection(x, y, z)
    if z == 1 and y == 5 then
        local channel = channels[midichannel]

        -- Toggle sustain ON/OFF
        channel.sustain = (channel.sustain == 0) and 1 or 0

        -- ✅ Send MIDI CC64 for sustain pedal
        local sustain_value = (channel.sustain == 1) and 127 or 0
        midi_tx(0, 0xB0 + midichannel - 1, 64, sustain_value) -- CC64 Hold Pedal

        -- ✅ If sustain is OFF, release all held notes
        if channel.sustain == 0 then
            for note, _ in pairs(held_notes) do
                midi_tx(0, 0x80 + midichannel - 1, note, 0) -- Send Note Off
                held_notes[note] = nil                      -- Clear from held notes
            end
        end

        -- Update sustain LED display
        display_sustain_for_channel()

        print("Channel " ..
            midichannel .. " sustain set to " .. channel.sustain .. " (MIDI CC64 = " .. sustain_value .. ")")
    end
end

function display_sustain_for_channel()
    for i = 1, 16 do
        grid_led(i, 5, 0) -- Clear row first
    end

    -- Use different LED brightness for a pattern
    for i = 1, 16, 3 do
        local brightness = (channels[midichannel].sustain == 1) and 15 or 3
        grid_led(i, 5, brightness) -- Bright LEDs for sustain ON
    end

    grid_refresh()
end

function handle_octave_selection(x, y, z)
    if z == 1 and y == 6 then
        if x == 8 or x == 9 then
            channels[midichannel].octave = 0                   -- Reset to octave 0
        elseif x < 8 then
            channels[midichannel].octave = math.max(-4, x - 8) -- Left side lowers octave
        elseif x > 9 then
            channels[midichannel].octave = math.min(4, x - 9)  -- Right side increases octave
        end

        display_octave_for_channel()
        print("Channel " .. midichannel .. " octave set to " .. channels[midichannel].octave)
    end
end

function display_octave_for_channel()
    for i = 1, 16 do
        grid_led(i, 6, 0) -- Clear row
    end

    -- Pre-light the full octave range (-4 to +4)
    for i = 4, 13 do
        grid_led(i, 6, 3)
    end

    local octave = channels[midichannel].octave
    local center_x = 8 -- Middle keys (8 & 9) represent octave 0

    -- Highlight selected octave
    if octave == 0 then
        grid_led(8, 6, 15)
        grid_led(9, 6, 15)
    elseif octave < 0 then
        grid_led(center_x + octave, 6, 10)     -- Left side (down)
    else
        grid_led(center_x + octave + 1, 6, 10) -- Right side (up)
    end

    grid_refresh()
end

function handle_channel_transpose_selection(x, y, z)
    if z == 1 and y == 7 then
        if x == 8 or x == 9 then
            channels[midichannel].transpose = 0        -- Reset to transpose 0
        elseif x < 8 then
            channels[midichannel].transpose = -(8 - x) -- Left side lowers transpose
        elseif x > 9 then
            channels[midichannel].transpose = x - 9    -- Right side increases transpose
        end

        display_channel_transpose_for_channel()
        print("Channel " .. midichannel .. " transpose set to " .. channels[midichannel].transpose)
    end
end

function display_channel_transpose_for_channel()
    for i = 1, 16 do
        grid_led(i, 7, 0) -- Clear row
    end

    -- Pre-light the full transpose range (-7 to +7)
    for i = 1, 16 do
        grid_led(i, 7, 3)
    end

    local transpose = channels[midichannel].transpose
    local center_x = 8 -- Middle keys (8 & 9) represent transpose 0

    -- Highlight selected transpose
    if transpose == 0 then
        grid_led(8, 7, 15)
        grid_led(9, 7, 15)
    elseif transpose < 0 then
        grid_led(center_x + transpose, 7, 10)     -- Left side (down)
    else
        grid_led(center_x + transpose + 1, 7, 10) -- Right side (up)
    end

    grid_refresh()
end

-- Modify handle_channel_edit_mode to include sustain selection
function handle_channel_edit_mode(x, y, z)
    if channel_edit_mode then
        display_channel_edit_mode()
    end

    if y == 3 then
        handle_velocity_selection(x, y, z)
    elseif y == 4 then
        handle_velocity_range_selection(x, y, z)
    elseif y == 5 then
        handle_sustain_selection(x, y, z)
    elseif y == 6 then
        handle_octave_selection(x, y, z)
    elseif y == 7 then
        handle_channel_transpose_selection(x, y, z)
    end
end

function display_channel_edit_mode()
    display_velocity_for_channel()
    display_velocity_range_for_channel()
    display_sustain_for_channel()
    display_octave_for_channel()
    display_channel_transpose_for_channel()
end

--
--
-- // GRID HANDLER \\
function handle_channel_selection(x, y, z)
    if z == 1 then
        if x >= 1 and x <= 4 and (y == 1 or y == 2) then
            for i = 3, 15 do
                for j = 1, 16 do
                    grid_led(j, i, 0)
                end
            end



            local new_channel = (y - 1) * 4 + x
            if new_channel > 8 then return end

            local prev_x = ((midichannel - 1) % 4) + 1
            local prev_y = math.floor((midichannel - 1) / 4) + 1
            grid_led(prev_x, prev_y, 3)

            midichannel = new_channel

            if shift == 1 then
                channel_edit_mode = true
                display_channel_edit_mode()
            else
                channel_edit_mode = false
            end

            grid_led(x, y, 10)
            grid_refresh()

            print("MIDI Channel set to:", midichannel)
        end
    end
end

function handle_note_generation(x, y, z, playback_channel)
    local target_channel = playback_channel or midichannel
    local channel_settings = channels[target_channel]

    -- Get base note
    local raw_note = x + (7 - y) * 5 + 50

    -- Apply scale quantization
    local scale = scales[selected_scale]
    local octave_offset = math.floor(raw_note / 12) * 12
    local closest_note_in_scale = scale[1]
    for _, note in ipairs(scale) do
        local scaled_note = octave_offset + note
        if math.abs(raw_note - scaled_note) < math.abs(raw_note - (octave_offset + closest_note_in_scale)) then
            closest_note_in_scale = note
        end
    end

    -- ✅ Apply per-channel transpose & octave (independent of global transpose)
    local quantized_note = octave_offset + closest_note_in_scale
    quantized_note = quantized_note + (channel_settings.octave * 12) + channel_settings.transpose + transpose

    -- Compute velocity with randomness
    local base_velocity = channel_settings.velocity
    local velocity_range = channel_settings.velocity_range
    local random_offset = math.random(-velocity_range, velocity_range)
    local final_velocity = math.max(0, math.min(127, base_velocity + random_offset)) -- Clamp between 0-127

    -- Handle sustain and note-on/note-off logic
    if z == 1 then
        -- ✅ Send MIDI Note On
        midi_tx(0, 0x90 + target_channel - 1, quantized_note, final_velocity)

        -- ✅ Track note if sustain is ON
        if channel_settings.sustain == 1 then
            held_notes[quantized_note] = true
        end

        -- ✅ Prevent LEDs from changing in edit mode
        if not channel_edit_mode then
            grid_led(x, y, 15) -- Bright LED when playing
        end
    else
        -- ✅ Only send Note Off if sustain is OFF
        if channel_settings.sustain == 0 then
            midi_tx(0, 0x80 + target_channel - 1, quantized_note, 0)
        end

        -- ✅ Remove note from held notes if sustain is OFF
        held_notes[quantized_note] = nil

        -- ✅ Prevent LEDs from being turned off in edit mode
        if not channel_edit_mode then
            grid_led(x, y, 0)
        end
    end

    grid_refresh()
end

function handle_shift(x, y, z)
    print("Shift button pressed")
    shift = z -- Active while pressed
    grid_led(16, 1, z * 15)
    grid_refresh()
end

grid = function(x, y, z)
    -- 🎛 Handle Shift Button First (Row 1, Column 16)
    if x == 16 and y == 1 then
        handle_shift(x, y, z)
        return -- Stop further processing
    end

    -- 🎬 Handle Pattern Recorder Buttons (Row 1 & 2, Keys 8-11)
    if (y == 1 or y == 2) and x >= 9 and x <= 12 then
        handle_pattern_recorder(x, y, z)
        return
    end

    -- 🎹 Handle Scale Selection & Transpose Buttons
    if y == 16 then
        if x > 1 and x <= #scales + 1 then
            handle_scale_selection(x)
        elseif x == 14 or x == 15 then
            handle_transpose(x, z)
        end
        return
    end

    -- 🎛 Handle MIDI Channel Selection (Rows 1-2, Columns 1-4)
    if y < 3 then
        handle_channel_selection(x, y, z)
        return
    end

    -- 🎼 Handle Note Generation & Recording
    local any_recorder_active = false
    for _, recorder in ipairs(recorders) do
        if recorder.recording_active then
            any_recorder_active = true
            break
        end
    end

    if any_recorder_active then
        record_event(x, y, z) -- Only record if at least one recorder is active
    end
    if channel_edit_mode then
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
        global_time = global_time + 0.01 -- Increment time in seconds

        for rec_index, recorder in ipairs(recorders) do
            if recorder.playback_active and recorder.playback_index <= #recorder.recording then
                local event = recorder.recording[recorder.playback_index]

                if global_time >= event.time + recorder.record_start_time then
                    -- ✅ Generate the note, but do NOT overwrite LEDs in edit mode
                    handle_note_generation(event.x, event.y, event.z, event.channel)

                    -- ✅ Fully block LED updates while in edit mode
                    if not channel_edit_mode then
                        if event.channel == midichannel then
                            grid_led(event.x, event.y, event.z * 15) -- Full brightness for active channel
                        else
                            grid_led(event.x, event.y, event.z * 1)  -- Super dim for other channels
                        end
                    end

                    -- ✅ Move to the next recorded event
                    recorder.playback_index = recorder.playback_index + 1

                    -- ✅ If the playback reaches the end, loop it back
                    if recorder.playback_index > #recorder.recording then
                        recorder.playback_index = 1
                        recorder.record_start_time = global_time -- 🔄 Reset playback timing
                        print("Recorder " .. rec_index .. " looped playback")
                    end
                end
            end
        end
    elseif index == 3 then
        -- ✅ Only clear this specific LED if we are NOT in edit mode
        if not channel_edit_mode then
            grid_led(16, 4, 0)
            grid_refresh()
        end
    end
end

function start_global_timer()
    metro_set(2, 10, -1) -- Update every 10ms
    print("Global timer started")
end

function stop_global_timer()
    metro_set(2, 0) -- Stop the timer
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
            local recorder = recorders[index]
            grid_led(x, y, 1)
        end
    end

    grid_led(16, 1, shift * 15)
    grid_refresh()
end

start_global_timer()
initialize_grid()
