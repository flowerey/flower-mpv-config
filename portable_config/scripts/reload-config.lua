-- reload-config.lua - Re-read script options and provide feedback
-- Note: mpv.conf and input.conf changes require a restart.
-- This script re-reads script-opts and notifies the user.
-- Default binding: Ctrl+Shift+r

local msg = require 'mp.msg'

local function reload_config()
    -- Re-read all script options by triggering a re-evaluate
    mp.command("script-message reload-script-opts")
    mp.osd_message("Script options reloaded.\nmpv.conf/input.conf changes require restart.", 3)
    msg.info("Script options reloaded. mpv.conf/input.conf changes require restart.")
end

mp.add_key_binding("Ctrl+Shift+r", "reload-config", reload_config)
