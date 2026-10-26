-- help-overlay.lua - quick key reference for this config
local mp = require "mp"

local help_text = [[flower's mpv - key reference

RIGHT (hold)  fast-forward       l  A-B loop
e  revert seek                g  cycle shaders
j / Shift+j  subtitle track   a / Shift+a  audio track
v  subtitles                  [/]  subtitle size
Ctrl+Left/Right  subtitle delay
Alt+Left/Right   audio delay
Up/Down  volume               m  mute
PGUP / PGDWN  chapters        Shift+Enter  playlist
F  stream quality             W  export clip
d  deinterlace                A  aspect ratio
L / Shift+L  loop file/playlist  Ctrl+v  audio-only
C  dynamic crop               y  manga reader
c / d / m  reader continuous / double / direction
p  cycle panscan              k  ASS style override
D  Discord RPC                Ctrl+Shift+r  restart notice
? / F1  this help
Next episode and subtitle delay are handled automatically.]]

local function show_help()
    mp.osd_message(help_text, 7)
end

mp.add_key_binding("?", "help-overlay", show_help)
mp.add_key_binding("F1", "help-overlay-f1", show_help)
