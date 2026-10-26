-- next-episode.lua - advance to the next playlist entry when a file ends
--
-- keep-open=yes parks playback on the last frame forever, which is right for
-- films but wrong for a folder of episodes: nothing ever moves on. When the
-- end of a file is reached and the playlist has another entry, show a
-- countdown and continue. Enter jumps immediately, Esc stays put, and seeking
-- back or opening another file cancels it.
--
-- It reacts to eof-reached rather than end-file because keep-open keeps the
-- file loaded (end-file may never fire).

local mp = require "mp"
local msg = require "mp.msg"

local opts = {
    enabled = true,  -- set to no to disable auto-advance entirely
    delay = 10,      -- seconds to wait; 0 advances immediately
}

mp.options.read_options(opts, "next_episode")

local timer = nil
local remaining = 0
local keys_bound = false
local next_name = nil

local function unbind_keys()
    if not keys_bound then return end
    pcall(mp.remove_key_binding, "next-episode-skip")
    pcall(mp.remove_key_binding, "next-episode-cancel")
    keys_bound = false
end

local function advance()
    if timer then
        timer:kill()
        timer = nil
    end
    remaining = 0
    unbind_keys()
    mp.command("playlist-next force")
end

local function stop_countdown(announce)
    if timer then
        timer:kill()
        timer = nil
    end
    remaining = 0
    unbind_keys()
    if announce then
        mp.osd_message("Staying on this file", 1)
    end
end

local function tick()
    timer = nil
    if remaining <= 0 then
        advance()
        return
    end
    mp.osd_message(string.format("Next: %s  in %ds  ([Enter] now, [Esc] stay)",
        next_name or "next file", remaining), 1.5)
    remaining = remaining - 1
    timer = mp.add_timeout(1, tick)
end

local function start()
    if not opts.enabled or timer then return end
    if mp.get_property_native("idle-active") then return end

    -- looping the file or an A-B segment means the end is intentional, not a handover
    local loop_file = mp.get_property("loop-file")
    if loop_file == "inf" or tonumber(loop_file) then return end
    if mp.get_property("ab-loop-b") ~= "no" then return end

    local pos = mp.get_property_number("playlist-pos", -1)
    local count = mp.get_property_number("playlist-count", 0)
    if pos < 0 or pos + 1 >= count then
        return
    end

    next_name = mp.get_property("playlist/" .. (pos + 1) .. "/filename") or "next file"
    remaining = tonumber(opts.delay) or 0

    if remaining <= 0 then
        advance()
        return
    end

    if not keys_bound then
        mp.add_forced_key_binding("ENTER", "next-episode-skip", advance)
        mp.add_forced_key_binding("ESC", "next-episode-cancel", function()
            stop_countdown(true)
        end)
        keys_bound = true
    end

    tick()
end

mp.observe_property("eof-reached", "bool", function(_, reached)
    if reached then
        start()
    else
        stop_countdown(false)
    end
end)

mp.register_event("file-loaded", function()
    stop_countdown(false)
end)

mp.register_script_message("next-episode/cancel", function()
    stop_countdown(true)
end)

mp.register_script_message("next-episode/advance", advance)

msg.verbose("Loaded next-episode.lua")
