-- Grid Pattern Recorder with Playback and Visual Indicators
print("Grid Pattern Recorder Initialized")

-- Global variables
global_time = 0
playback_active = false
playback_index = 1
midichannel = 1
flash_state = false
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

-- Initialize 4 independent recorders
recorders = {
    { recording = {}, recording_active = false, playback_active = false, playback_index = 1, record_start_time = 0 },
    { recording = {}, recording_active = false, playback_active = false, playback_index = 1, record_start_time = 0 },
    { recording = {}, recording_active = false, playback_active = false, playback_index = 1, record_start_time = 0 },
    { recording = {}, recording_active = false, playback_active = false, playback_index = 1, record_start_time = 0 }
}





-- // PATTER RECORDER \\

function start_recording(index)
    local recorder = recorders[index]
    recorder.recording = {}                  -- Clear previous recording
    recorder.recording_active = true
    recorder.record_start_time = global_time -- Capture start time
    flash_state = true
    metro_set(4, 500, -1)                    -- Flash indicator every 500ms
    grid_led(index + 7, 1, 15)               -- Highlight the button for active recording
    grid_refresh()
    print("Recorder " .. index .. " started recording")
end

function stop_recording(index)
    local recorder = recorders[index]
    recorder.recording_active = false
    flash_state = false
    metro_set(4, 0)            -- Stop flashing
    grid_led(index + 7, 1, 10) -- Dim the button to indicate stopped recording
    grid_refresh()
    print("Recorder " .. index .. " stopped recording")
end

function record_event(x, y, z)
    print("Recording event at x:" .. x .. " y:" .. y .. " z:" .. z)
    for index, recorder in ipairs(recorders) do
        if recorder.recording_active then
            local timestamp = global_time - recorder.record_start_time -- Relative time
            table.insert(recorder.recording, { x = x, y = y, z = z, time = timestamp, channel = midichannel })
            print("Recorded event in Recorder " .. index .. " at time " .. timestamp)
        end
    end
end

function start_playback(index)
    local recorder = recorders[index]
    if #recorder.recording == 0 then
        print("Recorder " .. index .. " has no recorded events")
        return
    end
    recorder.playback_active = true
    recorder.playback_index = 1
    recorder.record_start_time = global_time -- Reset time for proper playback
    grid_led(index + 7, 1, 10)               -- Indicate playback state
    grid_refresh()
    print("Recorder " .. index .. " started playback with " .. #recorder.recording .. " events")
end

function stop_playback(index)
    local recorder = recorders[index]
    recorder.playback_active = false
    grid_led(index + 7, 1, 5) -- Dim the button to indicate paused playback
    grid_refresh()
    print("Recorder " .. index .. " stopped playback")
end

function handle_pattern_recorder(x, y, z)
    if y == 1 and x >= 8 and x <= 11 then
        local index = x - 7 -- Map grid button (8-11) to recorder (1-4)
        local recorder = recorders[index]

        if shift == 1 then
            -- 🎵 Shift + Button → Clear Recording
            recorder.recording = {}
            recorder.recording_active = false
            recorder.playback_active = false
            grid_led(x, y, 1) -- Dim the button
            grid_refresh()
            print("Recorder " .. index .. " cleared")
        elseif z == 1 then
            if not recorder.recording_active and not recorder.playback_active and #recorder.recording == 0 then
                -- 🎬 Start Fresh Recording
                start_recording(index)
            elseif recorder.recording_active then
                -- ⏹ Stop Recording & Start Playback
                stop_recording(index)
                start_playback(index)
            elseif recorder.playback_active then
                -- ⏸ Stop Playback
                stop_playback(index)
            elseif not recorder.playback_active and #recorder.recording > 0 then
                -- ▶ Resume Playback
                start_playback(index)
            end
        end
    end
end

-- // SCALES AND TRANSPOSE



function handle_scale_selection(x)
    for i = 2, #scales + 1 do
        grid_led(i, 16, 5) -- Reset to dim for all scales
    end
    selected_scale = x - 1
    grid_led(x, 16, 15) -- Highlight the selected scale
    grid_refresh()
end

function handle_transpose(x, z)
    if z == 1 then
        if x == 14 then
            transpose = transpose - 1 -- Transpose down
        elseif x == 15 then
            transpose = transpose + 1 -- Transpose up
        end
        -- Highlight the button being pressed
        grid_led(14, 16, x == 14 and 15 or 5) -- Highlight transpose down if pressed
        grid_led(15, 16, x == 15 and 15 or 5) -- Highlight transpose up if pressed
        grid_refresh()
        print("Transpose set to:", transpose)
    end
end

-- // GRID HANDLER \\

function handle_channel_selection(x, y, z)
    if z == 1 then
        if x >= 1 and x <= 4 and (y == 1 or y == 2) then
            -- 🎹 Clear all note LEDs from row 3 to 15 before switching
            for i = 3, 15 do
                for j = 1, 16 do
                    grid_led(j, i, 0) -- Turn off all note LEDs
                end
            end
            grid_refresh()

            -- 🛑 Prevent invalid channel selection
            local new_channel = (y - 1) * 4 + x
            if new_channel > 8 then return end

            -- 🔄 Turn off the LED for the previous channel
            local prev_x = ((midichannel - 1) % 4) + 1
            local prev_y = math.floor((midichannel - 1) / 4) + 1
            grid_led(prev_x, prev_y, 1) -- Reset previous selection to dim

            -- 🔀 Update the selected MIDI channel
            midichannel = new_channel

            -- 🔆 Highlight the newly selected channel
            grid_led(x, y, 10)
            grid_refresh()

            print("MIDI Channel set to:", midichannel)

            -- 🎵 Reapply LED states for the active channel
            for _, recorder in ipairs(recorders) do
                for _, event in ipairs(recorder.recording) do
                    if event.channel == midichannel then
                        grid_led(event.x, event.y, event.z * 15) -- Bright for active notes
                    else
                        grid_led(event.x, event.y, 1)            -- Super dim for other channels
                    end
                end
            end
            grid_refresh()
        end
    end
end

function clear_channel_leds(channel)
    for _, recorder in ipairs(recorders) do
        for _, event in ipairs(recorder.recording) do
            if event.channel == channel then
                grid_led(event.x, event.y, 1) -- Set to super dim instead of turning off
            end
        end
    end
    grid_refresh()
end

function handle_note_generation(x, y, z, playback_channel)
    local scale = scales[selected_scale] -- Get the currently selected scale

    -- Calculate the raw note based on grid position
    local raw_note = x + (7 - y) * 5 + 50

    -- Quantize the note to the selected scale
    local octave_offset = math.floor(raw_note / 12) * 12 -- Base octave
    local closest_note_in_scale = scale[1]               -- Initialize with the first note in the scale
    for _, note in ipairs(scale) do
        local scaled_note = octave_offset + note
        if math.abs(raw_note - scaled_note) <
            math.abs(raw_note - (octave_offset + closest_note_in_scale)) then
            closest_note_in_scale = note
        end
    end

    -- Calculate the final quantized note
    local quantized_note = octave_offset + closest_note_in_scale + transpose

    -- Determine MIDI channel: Use playback event's channel or current selected channel
    local target_channel = playback_channel or midichannel

    -- Send the MIDI note and update the grid
    midi_tx(0, 0x90 + target_channel, quantized_note, z * 90)
    grid_led(x, y, z * 15)
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

    -- 🎬 Handle Pattern Recorder Buttons (Row 1, Keys 8-11)
    if x >= 8 and x <= 11 and y == 1 then
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

    handle_note_generation(x, y, z)
    grid_refresh()
end

-- // METRO CALLBACK \\
function metro(index, stage)
    if index == 2 then
        global_time = global_time + 0.01 -- Increment time in seconds

        for rec_index, recorder in ipairs(recorders) do
            if recorder.playback_active and recorder.playback_index <= #recorder.recording then
                local event = recorder.recording[recorder.playback_index]
                if global_time >= event.time + recorder.record_start_time then
                    -- 🎵 Send MIDI note to its original channel
                    handle_note_generation(event.x, event.y, event.z, event.channel)

                    -- 🔹 Adjust LED brightness based on channel
                    if event.channel == midichannel then
                        grid_led(event.x, event.y, event.z * 15) -- Full brightness for active channel
                    else
                        grid_led(event.x, event.y, event.z * 1)  -- Super dim for other channels
                    end

                    recorder.playback_index = recorder.playback_index + 1
                    if recorder.playback_index > #recorder.recording then
                        recorder.playback_index = 1              -- Loop playback
                        recorder.record_start_time = global_time -- 🔄 Reset playback timing to prevent speed-up
                        print("Recorder " .. rec_index .. " looped playback")
                    end
                end
            end
        end
    elseif index == 3 then -- Turn off clear button light
        grid_led(16, 4, 0)
        grid_refresh()
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

-- // INIT \\
function initialize_grid()
    -- 🌟 Clear Grid First
    for x = 1, 16 do
        for y = 1, 16 do
            grid_led(x, y, 0) -- Reset all LEDs
        end
    end

    -- 🎹 Highlight Scales (Dynamic)
    for i = 2, #scales + 1 do
        grid_led(i, 16, (i - 1) == selected_scale and 15 or 5) -- Bright for selected, dim for others
    end

    -- 🎛 Highlight MIDI Channels (Dynamic)
    for y = 1, 2 do
        for x = 1, 4 do
            local channel = (y - 1) * 4 + x
            if channel <= 8 then
                grid_led(x, y, channel == midichannel and 10 or 1) -- Bright if selected
            end
        end
    end

    -- 🎚 Highlight Transpose Buttons
    grid_led(14, 16, 5) -- Dim transpose down
    grid_led(15, 16, 5) -- Dim transpose up

    -- 🎬 Highlight Pattern Recorder Buttons (Row 1, Columns 8-11)
    for i = 8, 11 do
        local index = i - 7
        local recorder = recorders[index]
        grid_led(i, 1, 1)
    end

    -- ⚡ Preserve Shift Button State
    grid_led(16, 1, shift * 15)

    -- 💡 Refresh Grid Once
    grid_refresh()
end

start_global_timer()
initialize_grid()
