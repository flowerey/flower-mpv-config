-- pause-when-minimize.lua
-- Pauses playback when minimizing the window or losing focus,
-- and resumes playback when restored.
-- If the player was already paused, it won't mess with the pause state.

local options = {
    -- Pause when window is minimized
    on_minimize = true,
    -- Pause when window loses focus (platform-dependent)
    on_focus_loss = false,
}

require "mp.options".read_options(options)

local did_minimize = false
local did_focus_loss = false

-- Pause on minimize
if options.on_minimize then
    mp.observe_property("window-minimized", "bool", function(_, value)
        local pause = mp.get_property_native("pause")
        if value == true then
            if pause == false then
                mp.set_property_native("pause", true)
                did_minimize = true
            end
        elseif value == false then
            if did_minimize and (pause == true) then
                mp.set_property_native("pause", false)
            end
            did_minimize = false
        end
    end)
end

-- Pause on focus loss
if options.on_focus_loss then
    mp.observe_property("focused", "bool", function(_, value)
        local pause = mp.get_property_native("pause")
        if value == false then
            if pause == false then
                mp.set_property_native("pause", true)
                did_focus_loss = true
            end
        elseif value == true then
            if did_focus_loss and (pause == true) then
                mp.set_property_native("pause", false)
            end
            did_focus_loss = false
        end
    end)
end
