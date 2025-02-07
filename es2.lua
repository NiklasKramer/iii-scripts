-- Grid Pattern Recorder with Playback and Visual Indicators
print("Grid Pattern Recorder Initialized")

-- Global variables
recording = {}
recording_active = false
record_start_time = 0
global_time = 0
playback_active = false
playback_index = 1
midichannel = 1
flash_state = false
transpose = 24
shift = 0
selected_scale = 1
scales = {
    { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }, -- Chromatic
    { 0, 2, 4, 7, 9 },                        -- Pentatonic
    { 0, 2, 4, 7, 9, 11 },
    { 0, 2, 4, 5, 7, 9 },                     -- Major Pentatonic
    { 0, 2, 4, 5, 7, 9, 11 }                  -- Major scale
}

-- Start the global timer
function start_global_timer()
    metro_set(2, 10, -1) -- Update every 10ms
    print("Global timer started")
end

-- Stop the global timer
function stop_global_timer()
    metro_set(2, 0) -- Stop the timer
    print("Global timer stopped")
end

function start_recording()
    recording = {}
    recording_active = true
    record_start_time = global_time -- Capture start time
    flash_state = true
    grid_led(16, 2, 15)             -- Turn on recording indicator
    metro_set(4, 500, -1)           -- Flash indicator every 500ms
    grid_refresh()
    print("Recording started")
end

function stop_recording()
    recording_active = false
    flash_state = false
    metro_set(4, 0)    -- Stop flashing
    grid_led(16, 2, 0) -- Turn off recording indicator
    grid_refresh()
    print("Recording stopped")
end

-- Record a single event
function record_event(x, y, z)
    if recording_active then
        local timestamp = global_time - record_start_time -- Relative time
        table.insert(recording, { x = x, y = y, z = z, time = timestamp })
    end
end

-- Start playback with visual feedback
function start_playback()
    if #recording == 0 then
        return
    end
    playback_active = true
    playback_index = 1
    global_time = 0     -- Reset the timer
    grid_led(16, 3, 15) -- Turn on playback indicator
    grid_refresh()
    print("Playback started")
end

-- Stop playback with visual feedback
function stop_playback()
    if playback_active and playback_index > #recording then
        print("Looping playback")
        playback_index = 1 -- Reset to the first event
        global_time = 0    -- Reset the timer for looping
    else
        playback_active = false
        grid_led(16, 3, 0) -- Turn off playback indicator
        grid_refresh()
        print("Playback stopped")
    end
end

-- Initialize scales
function initialize_scales()
    for i = 2, 5 do
        grid_led(i, 1, 5)               -- Dimly light scale options
    end
    grid_led(selected_scale + 1, 1, 15) -- Highlight selected scale

    -- Set dim lights for transpose buttons
    grid_led(14, 1, 5) -- Dim light for transpose down
    grid_led(15, 1, 5) -- Dim light for transpose up
    grid_refresh()
end

-- Handle scale selection
function handle_scale_selection(x)
    for i = 2, #scales + 1 do
        grid_led(i, 1, 5) -- Reset to dim for all scales
    end
    selected_scale = x - 1
    grid_led(x, 1, 15) -- Highlight the selected scale
    grid_refresh()
end

-- Handle MIDI channel selection
function handle_channel_selection(y, z)
    if z == 1 then
        grid_led(1, midichannel + 1, 0) -- Turn off the LED for the previously selected channel
        midichannel = y - 1             -- Update the current MIDI channel
        grid_led(1, midichannel + 1, 3) -- Turn on the LED for the newly selected channel
        grid_refresh()
    end
end

-- Handle transpose buttons
function handle_transpose(x, z)
    if z == 1 then
        if x == 14 then
            transpose = transpose - 1 -- Transpose down
        elseif x == 15 then
            transpose = transpose + 1 -- Transpose up
        end
        -- Highlight the button being pressed
        grid_led(14, 1, x == 14 and 15 or 5) -- Highlight transpose down if pressed
        grid_led(15, 1, x == 15 and 15 or 5) -- Highlight transpose up if pressed
        grid_refresh()
        print("Transpose set to:", transpose)
    end
end

-- Handle note generation
function handle_note_generation(x, y, z)
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

    -- Send the MIDI note and update the grid
    midi_tx(0, 0x90 + midichannel, quantized_note, z * 90)
    grid_led(x, y, z * 15)
    grid_refresh()
end

-- Handle shift button
function handle_shift(x, y, z)
    shift = z -- Active while pressed
    grid_led(16, 1, z * 15)
    grid_refresh()
end

-- Handle control buttons for recording and playback
function handle_control_buttons(x, y, z)
    if z == 1 then
        if x == 16 and y == 2 then
            if recording_active then
                stop_recording()
            else
                start_recording()
            end
        elseif x == 16 and y == 3 then
            if playback_active then
                stop_playback()
            else
                start_playback()
            end
        elseif x == 16 and y == 4 then
            recording = {}
            grid_led(16, 4, 15)  -- Flash clear indicator
            grid_refresh()
            metro_set(3, 200, 1) -- Metro to turn off the light after 200ms
            print("Recording cleared")
        end
    end
end

grid = function(x, y, z)
    -- Column 16: Control Buttons Only
    if x == 16 then
        handle_control_buttons(x, y, z) -- Only handle control buttons
        return                          -- Stop further processing for Column 16
    end

    -- Row 1: Scale Selection and Transpose Buttons
    if y == 1 then
        if x > 1 and x <= #scales + 1 then
            handle_scale_selection(x) -- Handle scale selection
        elseif x == 14 or x == 15 then
            handle_transpose(x, z)    -- Handle transpose
        end
        return                        -- Stop further processing for Row 1
    end

    -- Column 1: MIDI Channel Selection
    if x == 1 then
        handle_channel_selection(y, z) -- Handle MIDI channel selection
        return                         -- Stop further processing for Column 1
    end

    -- All Other Columns: Note Generation and Recording
    if recording_active then
        record_event(x, y, z)       -- Record events when recording is active
    end
    handle_note_generation(x, y, z) -- Generate notes
    grid_refresh()                  -- Refresh the grid state
end

-- Metro callback
function metro(index, stage)
    if index == 2 then                   -- Global timer updates
        global_time = global_time + 0.01 -- Increment time in seconds
        if playback_active and playback_index <= #recording then
            local event = recording[playback_index]
            if global_time >= event.time then
                handle_note_generation(event.x, event.y, event.z) -- Play the event
                playback_index = playback_index + 1
                if playback_index > #recording then
                    stop_playback()
                end
            end
        end
    elseif index == 3 then -- Turn off clear button light
        grid_led(16, 4, 0)
        grid_refresh()
    end
end

-- Initialize everything
initialize_scales()
start_global_timer()
