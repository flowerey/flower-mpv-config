-- notify-chapters.lua - Show chapter title on OSD when chapter changes

local last_chapter = nil

local function on_chapter_change(_, chapter)
    if chapter == nil or chapter == last_chapter then return end
    last_chapter = chapter

    local total = mp.get_property_number("chapters", 0)
    if total == 0 then return end

    local title = mp.get_property("chapter-metadata/title")
    local msg
    if title and title ~= "" then
        msg = string.format("Chapter %d/%d: %s", chapter + 1, total, title)
    else
        msg = string.format("Chapter %d/%d", chapter + 1, total)
    end
    mp.osd_message(msg, 2)
end

mp.observe_property("chapter", "number", on_chapter_change)
