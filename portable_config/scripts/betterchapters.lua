-- betterchapters.lua - Chapter seeking with playlist wrap
-- Seeks to next/prev chapter, wraps to adjacent playlist entries.
-- Chapter title notifications are handled by notify-chapters.lua.

local function chapter_seek(direction)
    local chapters = mp.get_property_number("chapters") or 0
    local chapter  = mp.get_property_number("chapter") or 0

    -- Do not turn chapter keys into playlist navigation for chapterless files.
    if chapters <= 0 then return end

    if chapter + direction < 0 then
        mp.command("playlist_prev")
        if (mp.get_property_number("playlist-count", 1) or 1) > 1 then
            mp.command("show-text ${playlist} 3000")
        end
    elseif chapter + direction >= chapters then
        mp.command("playlist_next")
        if (mp.get_property_number("playlist-count", 1) or 1) > 1 then
            mp.command("show-text ${playlist} 3000")
        end
    else
        -- notify-chapters.lua displays the chapter title.
        mp.commandv("add", "chapter", direction)
    end
end

mp.add_key_binding("PGUP", "chapter_next", function() chapter_seek(1) end)
mp.add_key_binding("PGDWN", "chapter_prev", function() chapter_seek(-1) end)
