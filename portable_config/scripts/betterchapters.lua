-- betterchapters.lua - Chapter seeking with playlist wrap
-- Seeks to next/prev chapter, wraps to adjacent playlist entries.
-- Chapter title notifications are handled by notify-chapters.lua.

function chapter_seek(direction)
    local chapters = mp.get_property_number("chapters") or 0
    local chapter  = mp.get_property_number("chapter") or 0

    if chapter + direction < 0 then
        mp.command("playlist_prev")
        mp.command("show-text ${playlist} 3000")
    elseif chapter + direction >= chapters then
        mp.command("playlist_next")
        mp.command("show-text ${playlist} 3000")
    else
        mp.commandv("add", "chapter", direction)
        mp.command("show-text ${chapter-list} 3000")
    end
end

mp.add_key_binding("PGUP", "chapter_next", function() chapter_seek(1) end)
mp.add_key_binding("PGDWN", "chapter_prev", function() chapter_seek(-1) end)
