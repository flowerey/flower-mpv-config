# Changelog

## [2.1.0] - 2025-08-31

### Changed
- **discord-rpc.lua** — AniList GraphQL as primary metadata source (Jikan fallback)
- **discord-rpc.lua** — event-driven updates (was 1/s push; now: state changes + 15s keepalive)
- **discord-rpc.lua** — stable startTimestamp anchor (elapsed ticks per-second client-side)
- **discord-rpc.lua** — immediate ClearPresence on end-file/shutdown
- **quality-menu.lua** — replaced custom 5KB script with upstream v4.2.1 (christoph-heinrich)
- **input.conf** — added F/Alt+f/Ctrl+r bindings for quality-menu
- **mpv.conf** — removed invalid `audio-passthrough` option (mpv 0.41 rejects it)
- **autoload.lua** — synced to mpv master
- **thumbfast.lua** — synced to latest (po5/thumbfast)
- **playlistmanager.lua** — synced to latest (jonniek/mpv-playlistmanager)
- **dynamic-crop.lua** — synced to latest (Ashyni/mpv-scripts)
- **README.md** — fixed keybinding docs, updated Discord RPC section for AniList

### Fixed
- **discord-rpc.lua** — elapsed timer freezing (re-anchored every push; Discord throttled to 7-10s)
- **discord-rpc.lua** — presence lingering on mpv close (no ClearPresence before Shutdown)
- **discord-rpc.lua** — base64url mp:external encoding was invalid (hash is server-generated)
- **auto-save-state.lua** — forward-declared local variables before use
- **quality-menu.lua** — fixed Lua syntax error with `track.CodecDescription`
- **mpv.conf** — removed invalid `audio-passthrough` option

### Removed
- **trackselect.lua** (root leftover, was a 404 download artifact)
- **portable_config/historybookmarks/** (runtime data, not config; now in .gitignore)
- **scripts-opts/autocrop.conf** (legacy, replaced by dynamic_crop.conf)

## [2.0.0] - 2025-08-29

### Added

#### New Scripts
- **abloop.lua** — A-B loop with OSD position indicator (`l` key)
- **notify-chapters.lua** — Show chapter title on OSD when seeking chapters
- **quality-menu.lua** — Quick track/quality selector menu (`o`, `O`, `Ctrl+A`, `Ctrl+S`)
- **reload-config.lua** — Reload script options without restart (`Ctrl+Shift+r`)
- **evafast.lua** — Hybrid fast-forward/seek (tap RIGHT to seek, hold to speed up, subtitle-aware)
- **history-bookmark.lua** — Per-directory auto-resume across episodes
- **dynamic-crop.lua** — Continuous real-time black bar detection (replaces autocrop)

#### New Config Files
- `scripts-opts/evafast.conf` — evafast options (speed cap, lookahead, subtitle-aware)
- `scripts-opts/history_bookmark.conf` — history-bookmark options (timeout, save period)
- `scripts-opts/dynamic_crop.conf` — dynamic-crop options (mode 4, aspect ratios)
- `scripts-opts/autocrop.conf` — autocrop options (legacy, can be removed)
- `scripts-opts/autoload.conf` — playlist auto-loading options
- `scripts-opts/auto-save-state.conf` — save interval (60s)
- `scripts-opts/manga-reader.conf` — manga reader defaults

#### New Key Bindings (input.conf expanded from 2 to 30+)
- Subtitles: `j`/`Shift+j` cycle tracks, `[`/`]` scale, `v` visibility, `Ctrl+arrows` delay, `k` ASS toggle
- Audio: `a`/`Shift+a` cycle tracks, `arrows` volume, `m` mute, `Alt+arrows` delay
- Video: `d` deinterlace, `p` pansan, `s`/`Shift+s` screenshots, `C` dynamic crop
- Navigation: `l` A-B loop, `PGUP`/`PGDWN` chapters, `Shift+Enter` playlist, `e` chapter list
- Track selector: `o` all tracks, `O` video, `Ctrl+A` audio, `Ctrl+S` subtitles

#### New mpv.conf Settings
- `video-sync=display-resample` — smoother playback
- `interpolation=yes` — motion interpolation
- `panscan=0.5` — auto-zoom to fill screen
- `deband=yes` with iterations/threshold/range
- `volume-max=200` — volume boost beyond 100%
- `audio-normalize-downmix=yes` — normalize multi-channel audio
- `audio-passthrough=ac3,eac3,dts,dtshd,truehd` — pass surround to receiver
- `cache=yes` with `demuxer-max-bytes=500MiB`
- `cursor-autohide=1000`, `osd-duration=2500`
- `input-ar-delay=300` — evafast tap-vs-hold threshold

#### New Profiles
- **SD-Content** — automatic settings for content below 720p (higher antiring, stronger deband)
- **4K-Native** — automatic settings for 4K content (bilinear scale, no deband/interpolation)
- **HDR-Content** — automatic settings for HDR video (spline tone-mapping, contrast recovery)

### Changed
- **betterchapters.lua** — added chapter title notification on seek
- **pause-when-minimize.lua** — added `on_focus_loss` option
- **change-refresh.lua** — added Linux xrandr support, auto-detection
- **change-refresh.lua** — replaced busy-wait loop with `mp.add_timeout` (async)
- **input.conf** — expanded from 2 bindings to 30+
- **README.md** — comprehensive rewrite with all new features documented

### Fixed
- **mpv.conf** — merged duplicate `sub-ass-style-overrides` (second value was silently overwriting first)
- **mpv.conf** — fixed Manga profile condition operator precedence (parentheses)
- **manga-reader.lua:212** — fixed typo `opts.continous` → `opts.continuous`
- **manga-reader.lua:618** — fixed always-false condition `index + continuous_size < 0`
- **webm.lua:1992** — fixed undefined `bitrate` → `video_bitrate or audio_bitrate`
- **auto-save-state.lua** — made globals `can_delete`/`timer` local
- **change-refresh.lua** — made `msg`/`utils` local (were polluting global scope)

### Removed
- **autocrop.lua** — replaced by dynamic-crop (continuous detection vs one-shot)
- **scripts-opts/autocrop.conf** — removed with autocrop

## [1.0.0] - 2025-08-28

### Initial Release
- Fork of thewiki.moe config
- 12 Lua scripts: autocrop, autoload, auto-save-state, betterchapters, change-refresh, manga-reader, osc, pause-when-minimize, playlistmanager, thumbfast, trackselect, webm
- Custom subtitle styling with Gandhi Sans font
- 2 GLSL shaders: nnedi3, ArtCNN
- Profiles: Manga, crunchyroll, simulcast
- 2 key bindings in input.conf
