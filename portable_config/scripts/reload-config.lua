-- reload-config.lua - Remind the user how to apply config changes
-- mpv reads script-opts and config files only when scripts/player start, and
-- there is no API to reload them from disk at runtime.
-- Default binding: Ctrl+Shift+r

local msg = require 'mp.msg'

local function reload_config()
    mp.osd_message("Config files are read at startup.\nRestart mpv to apply changes.", 3)
    msg.info("Config changes require an mpv restart.")
end

mp.add_key_binding("Ctrl+Shift+r", "reload-config", reload_config)
