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

local auto_paused = false
local expected_pause = nil

local function paused()
    return mp.get_property_native("pause") == true
end

local function set_pause(value)
    expected_pause = value
    mp.set_property_native("pause", value)
end

-- A pause change that we did not make came from the user. Cancel pending
-- auto-resume so a manual pause survives minimizing/restoring.
mp.observe_property("pause", "bool", function(_, value)
    if expected_pause == value then
        expected_pause = nil
        return
    end
    auto_paused = false
end)

local function should_stay_paused()
    if options.on_minimize and mp.get_property_native("window-minimized") then
        return true
    end
    if options.on_focus_loss and mp.get_property_native("focused") == false then
        return true
    end
    return false
end

local function maybe_unpause()
    if not auto_paused then return end
    if not paused() then
        -- The user resumed manually; don't override that later.
        auto_paused = false
        return
    end
    if should_stay_paused() then return end

    set_pause(false)
    auto_paused = false
end

-- Pause on minimize
if options.on_minimize then
    mp.observe_property("window-minimized", "bool", function(_, value)
        if value == true then
            if not paused() then
                set_pause(true)
                auto_paused = true
            end
        elseif value == false then
            maybe_unpause()
        end
    end)
end

-- Pause on focus loss
if options.on_focus_loss then
    mp.observe_property("focused", "bool", function(_, value)
        if value == false then
            if not paused() then
                set_pause(true)
                auto_paused = true
            end
        elseif value == true then
            maybe_unpause()
        end
    end)
end
