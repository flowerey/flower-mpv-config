# flower's MPV Config

[![Featured on FMHY](https://cdn.jsdelivr.net/gh/JMcrafter26/badges@main/src/assets/available/fmhy/cozy.svg)](https://fmhy.net)

Movies/TV/anime-focused mpv config with 22 Lua scripts (next-episode auto-advance, subtitle-delay memory, manga reader, dynamic crop, thumbfast, history resume, Discord RPC), custom subtitles, upscaling shaders, and automatic SD/4K/HDR profiles.

Fork of the [thewiki.moe config](https://github.com/Snaacky/thewiki/commit/6202ded8b9c5f1e446a4a821663d3604266439bb). **[Download the latest release](https://github.com/flowerey/flower-mpv-config/releases/latest)**.

## Install

1. Download and extract the latest release.
2. Put `portable_config` next to `mpv.exe` for portable use, or copy it to:
   - **Windows:** `%APPDATA%\mpv`
   - **Linux/macOS:** `~/.config/mpv`
3. Or launch mpv with it directly:

```bash
mpv --config-dir=/path/to/portable_config video.mkv
```

Requires mpv 0.41+ (use a LuaJIT build for Discord RPC).

## Common Keys

| Key | Action |
|-----|--------|
| `RIGHT` | Tap: seek / Hold: fast-forward |
| `l` | A-B loop |
| `PGUP` / `PGDWN` | Next/previous chapter |
| `e` | Revert seek |
| `g` | Cycle upscaling shaders |
| `C` | Toggle dynamic crop |
| `s` / `Shift+s` | Screenshot / screenshot without OSD |
| `j` / `Shift+j` | Cycle subtitle tracks |
| `a` / `Shift+a` | Cycle audio tracks |
| `v` | Toggle subtitles |
| `m` | Mute |
| `p` | Cycle panscan |
| `k` | Toggle ASS style override |
| `Shift+Enter` | Playlist manager |
| `F` / `Alt+f` | Stream video/audio quality menu |
| `W` | Export a clip |
| `y` | Toggle manga reader |
| `D` | Toggle Discord Rich Presence |
| `Ctrl+Shift+r` | Config restart notice |

Full list: `portable_config/input.conf`.

These keys replace stock mpv bindings, so the originals are gone: `p` no longer pauses (use `Space` or right-click), the mouse wheel no longer changes volume, `[`/`]` no longer change speed, `Ctrl+Left/Right` no longer jump between subtitles, `Shift+s` no longer takes a video-only screenshot, `W` no longer pans, and `?`/`g` no longer open mpv's stats/select menus.

## Configuration

- `portable_config/mpv.conf` — video/audio/subtitle settings and auto profiles.
- `portable_config/input.conf` — key bindings.
- `portable_config/script-opts/` — per-script settings.
- `portable_config/shaders/` — shaders cycled with `g`.
- `portable_config/fonts/` — included subtitle font.

## Notes

- **Dynamic crop** requires `hwdec=no` or a `*-copy` mode (default is `auto-copy`).
- **History resume** prompts automatically in previously watched directories (`1` resume, `0` cancel); data is stored in `historybookmarks/`.
- **Discord RPC** needs LuaJIT and the Discord desktop client. The Windows DLL is bundled; Linux/macOS need `libdiscord-rpc`.
- **Manga reader** is toggled with `y`. While open, `c`/`d`/`m` toggle continuous/double-page/direction; defaults are in `script-opts/manga-reader.conf`.
- **Next episode** advances on its own. Because `keep-open=yes` parks on the last frame, a file in a playlist would otherwise never hand over; a countdown appears at EOF, `Enter` goes immediately and `Esc` stays. Delay is in `script-opts/next_episode.conf`.
- **Subtitle delay memory** (no key) stores the offset you set with `Ctrl+Left/Right` and reapplies it to the same file and folder, so a batch only needs syncing once. `Ctrl+9` clears it. Disable in `script-opts/auto_sub_sync.conf`.
- **Panscan is off by default.** It fills the screen by cropping, which removes the top/bottom of 4:3 releases and the edges of scope (2.39:1) releases — exactly where typesetting lives. Press `p` or use the mouse wheel when you want it.
- **ASS subtitles render exactly as authored.** `sub-ass-override=no`, which also switches off `sub-ass-style-overrides`, so no config value can move or rescale a release's signs (press `k` to force the styling on). Your `sub-font`/`sub-color` settings apply to plain-text subtitles only.
- **Refresh-rate switching (`F10`)** needs `nircmd.exe` on Windows (not bundled; put it on `PATH` or set `nircmd` in `script-opts/changerefresh.conf`) and `xrandr` on Linux. Without them the key does nothing.
- **Thumbnail previews** come from thumbfast, which spawns a helper mpv for each thumbnail. That needs `mpv` to be resolvable: if you run mpv portably without it on `PATH`, set `mpv_path` to the full `mpv.exe` in `script-opts/thumbfast.conf`.
- **Low-power playback.** The defaults assume a desktop GPU (interpolation, deband, high-quality scalers, up to 750 MiB of cache). On a laptop or integrated GPU, launch mpv with `--profile=low-power` (put it in a shortcut or script): it disables interpolation and deband, uses bilinear scalers and a 200 MiB cache.
- **Network use.** Discord RPC sends the parsed title (never the file path) to AniList/Jikan to fetch artwork, and the clip exporter can upload to catbox.moe when you choose that option. Turn RPC off with `D`; simply do not use the upload entry.

## Checks

CI runs two checks; you can run the first locally:

```bash
node tools/check-config.mjs   # duplicate options, dead bindings, wrong script targets, CRLF, Lua 5.2 syntax
```

The second parses every script with `luac5.1`, since mpv ships LuaJIT (Lua 5.1) and rejects 5.2-only syntax such as `goto`.

## Links

- [mpv manual](https://mpv.io/manual/master/)
- [Issues](https://github.com/flowerey/flower-mpv-config/issues)
