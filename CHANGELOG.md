# Changelog

## [Unreleased]

### Added
- **next-episode.lua** — advances to the next playlist entry with a countdown when a file ends; `Enter` skips the wait, `Esc` stays, seeking back cancels. Needed because `keep-open=yes` otherwise parks on the last frame forever.
- **auto-sub-sync.lua** — keyless subtitle-delay memory: the offset you set with `Ctrl+Left/Right` is stored per file and per folder and reapplied on load, so one manual sync covers a whole batch. `Ctrl+9` clears it.
- **`W`** — clip export binding for the bundled webm.lua encoder (it was only reachable through the script's own default key, which nothing documented).
- **`tools/check-config.mjs`** and **`.github/workflows/ci.yml`** — lint duplicate options, dead key bindings, wrong `script-binding`/`script-message` targets, misnamed or unread `script-opts` files, missing `~~/` files, CRLF, and Lua 5.2-only syntax; plus `luac5.1 -p` over every script. The checks follow mpv's own name rules: `_` and `-` are interchangeable in command names, and script client names sanitize non-alphanumerics to `_`.
- **`.gitattributes`** — LF normalization for all text files.
- **`.gitignore`** — `sub-delays.json`, the runtime store written by auto-sub-sync into the config directory.
- **mpv.conf** — `[low-power]` profile for laptops/integrated GPUs (no interpolation or deband, bilinear scalers, 150/50 MiB cache). Select it with `--profile=low-power`.

### Changed
- **autoload.lua** — synced to mpv master (directory-path guard)
- **manga-reader.lua** — synced to upstream master; kept continuous-mode boundary fix
- **webm.lua** — updated to the latest upstream release build
- **osc.lua** — `vidscale` now supports `auto`/`yes`/`no` as in current mpv
- **README.md** — corrected script descriptions and keybinding notes
- **script-opts/** — renamed from `scripts-opts/` so mpv actually loads every option file. Names follow mpv's own rule: a script's client name replaces every non-alphanumeric character with `_`, so `dynamic-crop.lua` reads `dynamic_crop.conf`; explicit identifiers such as `manga-reader` stay exactly as written
- **mpv.conf** — disabled the built-in OSC (`osc=no`) because the custom `scripts/osc.lua` is authoritative; guarded resolution/filename profile conditions
- **mpv.conf** — `deband` is no longer global. It was enabled with 4 iterations, threshold 35 and range 16, applied to every file including ones that do not band; mpv's built-in parameters (1 iteration, threshold 64, range 16) are already sensible and debanding is destructive, so it is now off and toggled per video with `b` (mpv's stock keybind, left unbound here). `[simulcast]` is the only profile that turns it on, which is what upstream thewiki's `simulcast` profile is for
- **mpv.conf** — `interpolation` is off; it was on globally, giving every file motion interpolation at significant GPU cost. `video-sync=display-resample` stays, since that is what removes 23.976-on-60Hz judder and it does not depend on interpolation
- **mpv.conf** — `[SD-Content]` no longer sets `deband-iterations=6`; the extra passes only blurred the SD sources the profile was meant to improve. It now applies antiring alone
- **mpv.conf** — dropped the `deband=no`/`interpolation=no` lines from `[Manga]`, `[4K-Native]` and `[low-power]`. Those are the global defaults now, so the profiles only state what they actually change (`dscale`, cache size, `video-sync`)
- **mpv.conf** — removed the global `panscan=0.5`. It fills the screen by cropping, which cut the top/bottom off 4:3 releases and the edges off scope releases, taking typesetting with it. `p` and the wheel still pan on demand
- **mpv.conf** — `[4K-Native]` now sets `dscale=bilinear` instead of `scale=bilinear`; `scale` only applies when upscaling, so it never affected 4K playback on a smaller screen
- **mpv.conf** — `[Manga]` sets `profile-restore=copy` like every other auto profile, so `deband=no` no longer leaks into the next video opened in the same session
- **mpv.conf** — `[simulcast]` no longer matches `SubsPlease`/`HorribleSubs` files; `[crunchyroll]` owns those, so the two auto profiles can no longer both apply to one file
- **betterchapters.lua** / **trackselect.lua** — helpers are locals now instead of globals (`chapter_seek`, `contains`, `preferred`, `copy`, `track_layout_hash`, …)
- **history-bookmark.lua** — directory creation uses PowerShell's `New-Item -Path` with a single-quoted, escaped path instead of `mkdir "…"`, and the failure message reads `error_string`
- **auto-sub-sync.lua** — prunes its store past `max_entries` (default 500) instead of growing forever; option added to `auto_sub_sync.conf`
- **mpv.yml** — the hourly mpv commit poll now authenticates to the GitHub API instead of sharing the unauthenticated rate limit
- **README.md / help-overlay.lua** — dropped every key that was never actually bound (see Removed) and documented `W`, `p` and `k`
- **README.md** — documents the stock mpv keys this config replaces, the `low-power` profile, thumbfast's `mpv_path`, `nircmd` for `F10`, and which scripts talk to the network
- **README.md** — documents `b`, that deband and interpolation are now off by default, and what `[low-power]` actually changes
- **Repository** — all text files are now LF instead of CRLF

### Fixed
- **mpv.conf** — `scale-antiring=0.6` looked like a restatement of `profile=high-quality`, but that profile only gained `scale-antiring=0.6` after mpv 0.41 — on 0.41 it brings no antiring at all. Kept, with a comment saying why, so the oldest supported mpv and the bundled mpv git build behave identically
- **mpv.conf** — removed the inert `sub-ass-style-overrides` line. It used `playresx`/`playresy`, but the option's keys are `res_x`/`res_y`, and `sub-ass-override=no` disables style overrides anyway, so it never did anything
- **mpv.conf** — restored `sub-ass-override=no`, which an earlier cleanup in this release had dropped; without it every ASS release renders with this config's override styles instead of its own typesetting
- **input.conf** — `k` now spells the command `cycle-values` (`cycle_values` also worked: mpv rewrites `_` to `-` when resolving command names)
- **input.conf** — comment documenting that `F`/`Alt+f`/`Ctrl+r` target the sanitized script name `quality_menu`, not the file name `quality-menu`
- **mpv.conf** — `save-position-on-quit` had no value; it is now explicit (`=yes`)
- **change-refresh.lua** — removed Lua 5.2-only `goto`, restoring LuaJIT/Lua 5.1 compatibility
- **discord-rpc.lua** — resolve bundled Discord RPC DLL from the mpv config directory
- **history-bookmark.lua** — hardened config/environment path handling and language fallback
- **abloop.lua** — handles the `script-message ab-loop` binding used by `input.conf`
- **betterchapters.lua** — replaced deprecated OSC messages with `show-text`; avoids duplicate chapter OSD
- **input.conf** — `Shift+s` now uses valid `no-osd screenshot`; PGUP/PGDWN use chapter-wrap bindings; `Shift+Enter` uses the real playlistmanager binding
- **reload-config.lua** — no longer claims to reload options that mpv only reads at startup
- **manga-reader.lua** — reader lifecycle and bookmark hardening; forced `c`/`d`/`m` keys only while open; valid image path stored in bookmarks; resets page cache when the playlist changes; clean `force-window`/title restore
- **history-bookmark.lua** — resets prompt/timer state between directories, saves the first session, caches bookmark paths, tolerates CRLF/malformed records, and cleans up on unload
- **auto-save-state.lua** — restores `save-position-on-quit` after EOF so later files still save
- **pause-when-minimize.lua** — a manual pause is no longer overridden by minimize/restore
- **dynamic-crop.lua** — skips still images and videos whose dimensions are not ready, avoiding nil-dimension errors
- **change-refresh.lua** — handles missing displays/frame rates and preserves custom rate mappings
- **abloop.lua** / **notify-chapters.lua** / **betterchapters.lua** — clear stale loop/chapter state on new files; chapterless files no longer skip playlist items or show duplicate chapter OSD
- **trackselect.lua** — handles external tracks without titles
- **discord-rpc.lua** — rejects weak AniList/Jikan title matches instead of mislabeling unrelated files

### Removed
- **Documented track-selector keys** — `o`/`O` and `Ctrl+A`/`Ctrl+S` were described as track selectors, but `trackselect.lua` only auto-selects tracks and binds no keys; `o`/`O` are mpv's own show-progress/OSD-level keys
- **`Ctrl+Alt+s` "sync subtitles"** in the help overlay — nothing ever handled it

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
- **quality-menu.lua** — Stream quality selector menu (`F`, `Alt+f`, `Ctrl+r`)
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
- Navigation: `l` A-B loop, `PGUP`/`PGDWN` chapters, `Shift+Enter` playlist, `e` revert seek

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
