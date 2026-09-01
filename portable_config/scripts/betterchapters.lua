-- betterchapters.lua - Chapter seeking with OSD notification
-- Seeks to next/prev chapter, wraps to playlist boundaries
-- Shows chapter title on OSD when available

function chapter_seek(direction)
    local chapters = mp.get_property_number("chapters") or 0
    local chapter  = mp.get_property_number("chapter") or 0

    if chapter + direction < 0 then
        mp.command("playlist_prev")
        mp.commandv("script-message", "osc-playlist")
    elseif chapter + direction >= chapters then
        mp.command("playlist_next")
        mp.commandv("script-message", "osc-playlist")
    else
        mp.commandv("add", "chapter", direction)
        mp.commandv("script-message", "osc-chapterlist")
    end
end

local function show_chapter_info(_, chapter)
    if chapter == nil then return end
    local total = mp.get_property_number("chapters", 0)
    if total == 0 then return end

    local title = mp.get_property("chapter-metadata/title")
    local msg
    if title and title ~= "" then
        msg = string.format("Chapter %d/%d — %s", chapter + 1, total, title)
    else
        msg = string.format("Chapter %d/%d", chapter + 1, total)
    end
    mp.osd_message(msg, 2)
end

mp.add_key_binding("PGUP", "chapter_next", function() chapter_seek(1) end)
mp.add_key_binding("PGDWN", "chapter_prev", function() chapter_seek(-1) end)
mp.observe_property("chapter", "number", show_chapter_info)
