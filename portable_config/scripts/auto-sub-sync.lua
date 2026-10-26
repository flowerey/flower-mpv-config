-- auto-sub-sync.lua - remember subtitle delays and reapply them automatically
--
-- Subtitles that are off by a constant amount are almost always a property of
-- the release, not of one file: entire batches share the same offset. You nudge
-- it once with Ctrl+Left/Right, and this script stores the result per file and
-- per folder, then applies it again on load -- so the next episode of the batch
-- lines up without touching anything.
--
-- There is no key binding. It never guesses from audio content; it only replays
-- an offset you already dialled in, which is why it is safe to leave on.
-- Ctrl+9 (reset delay) clears the stored offset for the current folder.

local mp = require "mp"
local msg = require "mp.msg"
local utils = require "mp.utils"

local opts = {
    enabled = true,
    remember_folder = true,  -- reuse the last delay of a folder for new files in it
    threshold = 0.05,        -- ignore smaller offsets
    osd = true,
    max_entries = 500,       -- cap the store so it cannot grow forever
}

mp.options.read_options(opts, "auto_sub_sync")

local store_path = mp.command_native({ "expand-path", "~~/sub-delays.json" })
local store = { files = {}, folders = {} }
local write_timer = nil

local current_path = nil
local known_delay = 0
local saw_delay = false

local function is_local(path)
    if not path or path == "" then return false end
    -- skip network streams, dvb, edl, pipes and friends
    return path:match("^[%a][%w+.-]*://") == nil
end

local function flush()
    write_timer = nil
    local f, err = io.open(store_path, "w")
    if not f then
        msg.warn("cannot write " .. tostring(store_path) .. ": " .. tostring(err))
        return
    end
    f:write(utils.format_json(store, { pretty = true }))
    f:close()
end

local function schedule_flush()
    if write_timer then return end
    write_timer = mp.add_timeout(2, flush)
end

local function load_store()
    local f = io.open(store_path, "r")
    if not f then return end
    local data = f:read("*a")
    f:close()

    local parsed = utils.parse_json(data or "")
    if type(parsed) ~= "table" then
        msg.warn("ignoring malformed " .. store_path)
        return
    end
    if type(parsed.files) == "table" then store.files = parsed.files end
    if type(parsed.folders) == "table" then store.folders = parsed.folders end
end

local function has_subtitle_track()
    local sub = mp.get_property_native("current-tracks/sub")
    return type(sub) == "table" and sub.id ~= nil and sub.id ~= "no"
end

local function prune()
    local limit = tonumber(opts.max_entries) or 0
    if limit <= 0 then return end

    local count = 0
    for _ in pairs(store.files) do count = count + 1 end
    local excess = count - math.floor(limit)
    if excess <= 0 then return end

    -- no timestamps are stored, so the oldest entries are not distinguishable;
    -- drop arbitrary ones rather than keeping an unbounded file
    for key in pairs(store.files) do
        store.files[key] = nil
        excess = excess - 1
        if excess <= 0 then break end
    end
end

local function remember(path, delay)
    local rounded = math.floor(delay * 1000 + 0.5) / 1000
    if math.abs(rounded) < opts.threshold then
        -- a reset should stick, so drop the old entries instead of storing 0
        store.files[path] = nil
        if opts.remember_folder then
            local dir = utils.split_path(path)
            if dir then store.folders[dir] = nil end
        end
    else
        store.files[path] = rounded
        if opts.remember_folder then
            local dir = utils.split_path(path)
            if dir then store.folders[dir] = rounded end
        end
    end
    prune()
    schedule_flush()
end

local function restore()
    if not opts.enabled then return end
    local path = mp.get_property("path")
    if not is_local(path) then return end
    if not has_subtitle_track() then return end

    local delay, source = store.files[path], "remembered for this file"
    if delay == nil and opts.remember_folder then
        local dir = utils.split_path(path)
        delay, source = dir and store.folders[dir], "remembered for this folder"
    end
    if type(delay) ~= "number" or math.abs(delay) < opts.threshold then return end

    mp.set_property_number("sub-delay", delay)
    msg.info(string.format("restored subtitle delay %+.2fs for %s", delay, path))
    if opts.osd then
        mp.osd_message(string.format("Subtitle delay %+.2fs (%s)", delay, source), 2)
    end
end

-- Track the delay for the file that is currently loaded. Storing eagerly (with
-- a debounce) means nothing is lost when mpv is closed while sitting at EOF.
--
-- A delay of 0 only counts as "forget this offset" once this file has actually
-- had a nonzero one; the 0 mpv sets while loading must not wipe the folder.
mp.observe_property("sub-delay", "number", function(_, value)
    if value == nil or not current_path then return end
    if math.abs(value) >= opts.threshold then
        saw_delay = true
        known_delay = value
        remember(current_path, value)
    elseif saw_delay then
        saw_delay = false
        known_delay = 0
        remember(current_path, 0)
    end
end)

mp.register_event("start-file", function()
    -- the next file's initial delay reset must not be charged to the old file
    current_path = nil
    known_delay = 0
    saw_delay = false
end)

mp.register_event("file-loaded", function()
    local path = mp.get_property("path")
    if not is_local(path) then return end
    current_path = path
    restore()
end)

mp.register_event("shutdown", function()
    if current_path and saw_delay then remember(current_path, known_delay) end
    if write_timer then
        write_timer:kill()
        write_timer = nil
    end
    flush()
end)

mp.register_script_message("auto-sub-sync/forget", function()
    local path = mp.get_property("path")
    if not is_local(path) then return end
    store.files[path] = nil
    local dir = utils.split_path(path)
    if dir then store.folders[dir] = nil end
    schedule_flush()
    mp.osd_message("Cleared remembered subtitle delay", 2)
end)

load_store()
msg.verbose("Loaded auto-sub-sync.lua")
