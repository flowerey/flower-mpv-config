-- abloop.lua - A-B loop with OSD indicator
-- Press l to set point A, l again to set point B (starts looping),
-- l again to clear and reset.

local a_pos = nil
local b_pos = nil
local looping = false

local function format_time(seconds)
    if seconds == nil then return "??:??" end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    if h > 0 then
        return string.format("%d:%02d:%02d", h, m, s)
    else
        return string.format("%02d:%02d", m, s)
    end
end

local function show_osd()
    if a_pos ~= nil and b_pos ~= nil then
        local duration = b_pos - a_pos
        mp.osd_message(string.format("A-B Loop: %s - %s (%s)",
            format_time(a_pos), format_time(b_pos), format_time(duration)), 3)
    elseif a_pos ~= nil then
        mp.osd_message(string.format("A-B Loop: A = %s (set B with l)", format_time(a_pos)), 3)
    else
        mp.osd_message("A-B Loop: cleared", 1)
    end
end

local function ab_loop()
    local pos = mp.get_property_number("time-pos")
    if pos == nil then return end

    if not looping then
        if a_pos == nil then
            -- Set point A
            a_pos = pos
            show_osd()
        elseif b_pos == nil then
            -- Set point B, start looping
            b_pos = pos
            if b_pos <= a_pos then
                -- B is before A, swap
                a_pos, b_pos = b_pos, a_pos
            end
            looping = true
            mp.set_property_number("ab-loop-a", a_pos)
            mp.set_property_number("ab-loop-b", b_pos)
            show_osd()
        end
    else
        -- Clear loop
        a_pos = nil
        b_pos = nil
        looping = false
        mp.set_property("ab-loop-a", "no")
        mp.set_property("ab-loop-b", "no")
        show_osd()
    end
end

mp.add_key_binding("l", "ab-loop", ab_loop)
