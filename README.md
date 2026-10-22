# flower's MPV Config

[![Featured on FMHY](https://cdn.jsdelivr.net/gh/JMcrafter26/badges@main/src/assets/available/fmhy/cozy.svg)](https://fmhy.net)

Movies/TV/anime-focused mpv config with 19 Lua scripts (manga reader, dynamic crop, thumbfast, history resume, Discord RPC), custom subtitles, upscaling shaders, and automatic SD/4K/HDR profiles.

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
| `o` / `O` | Track selector / video track selector |
| `Shift+Enter` | Playlist manager |
| `F` / `Alt+f` | Stream video/audio quality menu |
| `y` | Toggle manga reader |
| `D` | Toggle Discord Rich Presence |
| `Ctrl+Shift+r` | Config restart notice |

Full list: `portable_config/input.conf`.

## Configuration

- `portable_config/mpv.conf` — video/audio/subtitle settings and auto profiles.
- `portable_config/input.conf` — key bindings.
- `portable_config/scripts-opts/` — per-script settings.
- `portable_config/shaders/` — shaders cycled with `g`.
- `portable_config/fonts/` — included subtitle font.

## Notes

- **Dynamic crop** requires `hwdec=no` or a `*-copy` mode (default is `auto-copy`).
- **History resume** prompts automatically in previously watched directories; data is stored in `historybookmarks/`.
- **Discord RPC** needs LuaJIT and the Discord desktop client. The Windows DLL is bundled; Linux/macOS need `libdiscord-rpc`.
- **Manga reader** is toggled with `y`; defaults are in `scripts-opts/manga-reader.conf`.

## Links

- [mpv manual](https://mpv.io/manual/master/)
- [Issues](https://github.com/flowerey/flower-mpv-config/issues)
