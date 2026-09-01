# flower's MPV Config

[![Featured on FMHY](https://cdn.jsdelivr.net/gh/JMcrafter26/badges@main/src/assets/available/fmhy/cozy.svg)](https://fmhy.net)

A comprehensive mpv configuration focused on **Movies, TV, and Anime**. Fork of the [thewiki.moe config](https://github.com/Snaacky/thewiki/commit/6202ded8b9c5f1e446a4a821663d3604266439bb).

This fork has much more updated scripts, manga reader built-in (toggled with `y`) and some other cool stuff.

Downloads are [here](https://github.com/flowerey/flower-mpv-config/releases/latest).

## Features

- **19 Lua scripts** — manga reader, A-B loop, fast-forward, auto-crop, history resume, and more
- **Custom subtitle styling** — Gandhi Sans font, ASS overrides, track auto-selection
- **Video upscaling shaders** — nnedi3 and ArtCNN (cycle with `g`)
- **Smart crop** — continuous real-time black bar detection (adapts to aspect ratio changes)
- **Per-directory history** — auto-resume where you left off in a series
- **Hybrid fast-forward** — tap to seek, hold to speed up (subtitle-aware)
- **Resolution profiles** — automatic settings for SD, 4K, and HDR content
- **Stream support** — auto-detects SubsPlease, Erai-raws, and other anime release groups
- **Configurable** — every script has its own `.conf` file in `scripts-opts/`

## Installation

Copy the `portable_config` folder to your mpv config directory:

| Platform | Path |
|----------|------|
| Linux | `~/.config/mpv/` |
| Windows | `%APPDATA%/mpv/` |
| macOS | `~/.config/mpv/` |

Or use it as a portable config by pointing mpv to it:

```bash
mpv --profile=portable --config-dir=path/to/portable_config video.mkv
```

## Key Bindings

### Subtitles
| Key | Action |
|-----|--------|
| `j` / `Shift+j` | Cycle subtitle tracks |
| `[` / `]` | Subtitle scale −/+ |
| `v` | Toggle subtitle visibility |
| `Ctrl+←/→` | Subtitle delay −/+ |
| `Ctrl+9` | Reset subtitle delay |
| `k` | Toggle ASS override (force/default) |

### Audio
| Key | Action |
|-----|--------|
| `a` / `Shift+a` | Cycle audio tracks |
| `↑/↓` | Volume +/− |
| `m` | Mute |
| `Alt+←/→` | Audio delay −/+ |
| `Alt+9` | Reset audio delay |

### Video
| Key | Action |
|-----|--------|
| `d` | Toggle deinterlace |
| `p` | Toggle panscan |
| `g` | Cycle shaders (nnedi3 → ArtCNN → off) |
| `s` | Screenshot (file) |
| `Shift+s` | Screenshot (no OSD) |
| `C` | Toggle dynamic crop (enable → keep crop → disable) |
| `RIGHT` | Tap: seek 5s / Hold: fast-forward (evafast) |

### Navigation
| Key | Action |
|-----|--------|
| `l` | A-B loop (set A → set B → clear) |
| `PGUP` / `PGDWN` | Next/prev chapter |
| `e` | Revert seek (resume playback before seek) |
| `Shift+Enter` | Playlist manager |
| `F` | Stream video quality menu |
| `Alt+f` | Stream audio quality menu |
| `Ctrl+r` | Reload stream |
| `Ctrl+Shift+r` | Reload script options |

### Track Selector
| Key | Action |
|-----|--------|
| `o` | All tracks menu |
| `O` | Video track selector |
| `Ctrl+a` | Audio track selector |
| `Ctrl+s` | Subtitle track selector |

### Manga Reader
| Key | Action |
|-----|--------|
| `y` | Toggle manga reader |
| `←/→` | Next/prev page |
| `Shift+←/→` | Single page skip |
| `Ctrl+←/→` | Skip 10 pages |
| `↑/↓` | Pan up/down |
| `Home/End` | First/last page |
| `c` | Toggle continuous mode |
| `d` | Toggle double page mode |
| `m` | Toggle manga reading direction |
| `/` | Jump to page number |
| `Ctrl+n` | Create bookmark |
| `Ctrl+u` | Update bookmark |
| `Ctrl+b` | Open bookmark list |
| `Ctrl+d` | Delete bookmark |

### History Resume
No key bindings needed — the script prompts automatically when you open a file in a directory you've watched before. Press `1` to resume, `0` to cancel.

### Discord RPC
| Key | Action |
|-----|--------|
| `D` | Toggle Discord Rich Presence on/off |

## Scripts

| Script | Description |
|--------|-------------|
| **abloop.lua** | A-B loop with OSD position indicator |
| **autoload.lua** | Auto-load directory files into playlist |
| **auto-save-state.lua** | Periodically save playback position |
| **betterchapters.lua** | Chapter seek with title notification |
| **change-refresh.lua** | Match display refresh rate to video fps (Windows/Linux) |
| **discord-rpc.lua** | Discord Rich Presence with AniList cover art and episode titles |
| **dynamic-crop.lua** | Continuous real-time black bar detection and cropping |
| **evafast.lua** | Hybrid fast-forward/seek (tap to seek, hold to speed up) |
| **history-bookmark.lua** | Per-directory auto-resume across episodes |
| **manga-reader.lua** | Read manga/comics (CBZ, CBR, etc.) |
| **notify-chapters.lua** | Show chapter title on OSD when seeking |
| **osc.lua** | On-screen controller (modernZ) |
| **pause-when-minimize.lua** | Pause on minimize/focus loss |
| **playlistmanager.lua** | Visual playlist manager |
| **quality-menu.lua** | Stream quality changer for yt-dlp/youtube-dl formats |
| **reload-config.lua** | Reload script options without restart |
| **thumbfast.lua** | Thumbnail generation for seek bar |
| **trackselect.lua** | Smart audio/subtitle track auto-selection |
| **webm.lua** | WebM/GIF/video clipping and encoding |

## Configuration

### mpv.conf Highlights

```
# Video
vo=gpu-next
video-sync=display-resample
interpolation=yes

# Audio
volume-max=200
audio-normalize-downmix=yes

# Subtitles
sub-font="Gandhi Sans"
sub-ass-style-overrides=playresx=1920,playresy=1080,Kerning=yes

# evafast integration
input-ar-delay=300
```

### Profiles

| Profile | Trigger | Behavior |
|---------|---------|----------|
| Manga | `.cbz`, `.cbr`, `.zip`, `.rar` | mitchell downscale, no deband |
| simulcast | SubsPlease, Erai-raws, etc. | Deband enabled |
| crunchyroll | SubsPlease, HorribleSubs | ASS aspect-ratio override |
| SD-Content | width < 1280 | Higher antiring, stronger deband |
| 4K-Native | width ≥ 3840 | Bilinear scale, no deband, no interpolation |
| HDR-Content | PQ/HLG gamma | Spline tone-mapping, contrast recovery |

## Shaders

Cycle between upscaling shaders with `g`:

1. **nnedi3-nns128-win8x4.hook** — Neural network upscaler (high quality, slower)
2. **ArtCNN_C4F32.glsl** — Artifact CNN upscaler (fast, good for anime)
3. Off (default bilinear/bicubic)

Place custom shaders in `portable_config/shaders/`.

## Fonts

Gandhi Sans is included in `portable_config/fonts/`. To change the subtitle font:

1. Put your font files (Bold, Regular, Italic variants) in the `fonts/` directory
2. Update `sub-font` in `mpv.conf` to the font **name** (not filename)
3. Make sure all weight variants are present or rendering may break

## Discord RPC

The `discord-rpc.lua` script shows what you're watching in Discord with AniList cover art and episode titles.

### Requirements

- **LuaJIT** — mpv must be compiled with LuaJIT (`ldd $(which mpv) | grep luajit`)
- **discord-rpc library** — native library for Discord IPC
- **curl** — for API calls (pre-installed on most systems)
- **Discord** — desktop client must be running

### Installing discord-rpc library

**Linux:**
```bash
# Download from discord-rpc releases
wget https://github.com/discord/discord-rpc/releases/download/v3.4.0/discord-rpc-linux.zip
unzip discord-rpc-linux.zip
sudo cp discord-rpc/linux/linux-dynamic/lib/libdiscord-rpc.so /usr/local/lib/
sudo ldconfig
```

**Windows:**
```
Download discord-rpc-win64.zip from releases.
Copy discord-rpc.dll next to mpv.exe.
```

**macOS:**
```bash
# For Apple Silicon
brew install discord-rpc
# Or manually from releases
```

### Configuration

Edit `scripts-opts/discord_rpc.conf`:

```ini
active=yes
key_toggle=D
fetch_episode_titles=yes
search_cache_ttl=300
episode_cache_ttl=86400
api_delay=400
```

### What it shows

- **Anime content**: AniList cover art (Jikan fallback), anime title, episode number + title, timestamps
- **Non-anime content**: mpv logo, filename/title, play state, timestamps
- **Toggle**: Press `D` to enable/disable

## Troubleshooting

**No thumbnails on seek bar?**
- Ensure `thumbfast` is enabled and a compatible mpv version is installed

**Subtitles look wrong?**
- Check `sub-ass-override` is set to `no` (use `k` to toggle to `force` when needed)
- Verify the font is in `fonts/` and `sub-font` matches its name

**Dynamic crop not working?**
- Requires `hwdec=no` or a `*-copy` variant (e.g. `hwdec=auto-copy`)
- Press `C` to cycle crop modes: enable → keep crop → disable
- Verify FFmpeg has `cropdetect` filter: `mpv --vf=help`

**Fast-forward not working?**
- `input-ar-delay=300` must be in mpv.conf (controls tap vs hold threshold)
- Hold RIGHT arrow for ~300ms to trigger fast-forward mode

**History resume not prompting?**
- History files are stored in `historybookmarks/` inside your mpv config dir
- Set `enabled=yes` in `scripts-opts/history_bookmark.conf`

**Manga reader not starting?**
- Press `y` to toggle manually, or set `auto_start=yes` in `scripts-opts/manga-reader.conf`

**Discord RPC not showing?**
- Check mpv has LuaJIT: `mpv --version` should show "LuaJIT" in features
- Check discord-rpc library is installed: `ldconfig -p | grep discord-rpc` (Linux)
- Ensure Discord desktop client is running
- Press `D` to toggle RPC on (check OSD message)
- Enable verbose logging: add `msg-level=discord-rpc=v` to mpv.conf

**Discord RPC shows wrong anime?**
- The script extracts titles from filenames — ensure your files follow standard naming
- For best results, use names like `[SubGroup] Title - 01 [1080p].mkv`
- The script searches AniList (primary) and Jikan (fallback) for matching metadata
- Season matching: use `S02E03` format in filenames for multi-season shows

## Links

- [awesome-mpv](https://github.com/stax76/awesome-mpv) — More mpv scripts and tools
- [mpv manual](https://mpv.io/manual/master/) — Official documentation
- [mpv wiki](https://github.com/mpv-player/mpv/wiki) — Community guides
