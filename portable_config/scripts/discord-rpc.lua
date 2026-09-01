-- discord-rpc.lua — Discord Rich Presence for mpv
-- Shows anime/movie/TV presence with MAL cover art and episode titles
-- Requires: LuaJIT, discord-rpc native library, curl, Discord running

local mp = require "mp"
local msg = require "mp.msg"
local utils = require "mp.utils"
local options = require "mp.options"

-- ============================================================
-- Configuration
-- ============================================================
local o = {
    active = true,
    key_toggle = "D",
    fetch_episode_titles = true,
    search_cache_ttl = 300,
    episode_cache_ttl = 86400,
    api_delay = 400,
}

options.read_options(o, "discord_rpc")

-- ============================================================
-- Check for LuaJIT
-- ============================================================
if not pcall(require, "ffi") then
    msg.error("discord-rpc requires LuaJIT. mpv must be compiled with LuaJIT support.")
    o.active = false
    return
end

local ffi = require "ffi"

-- ============================================================
-- FFI: discord-rpc native library
-- ============================================================
ffi.cdef[[
typedef struct DiscordRichPresence {
    const char* state;
    const char* details;
    int64_t startTimestamp;
    int64_t endTimestamp;
    const char* largeImageKey;
    const char* largeImageText;
    const char* smallImageKey;
    const char* smallImageText;
    const char* partyId;
    int partySize;
    int partyMax;
    const char* matchSecret;
    const char* joinSecret;
    const char* spectateSecret;
    int8_t instance;
} DiscordRichPresence;

typedef struct DiscordUser {
    const char* userId;
    const char* username;
    const char* discriminator;
    const char* avatar;
} DiscordUser;

typedef void (*readyPtr)(const DiscordUser* request);
typedef void (*disconnectedPtr)(int errorCode, const char* message);
typedef void (*erroredPtr)(int errorCode, const char* message);
typedef void (*joinGamePtr)(const char* joinSecret);
typedef void (*spectateGamePtr)(const char* spectateSecret);
typedef void (*joinRequestPtr)(const DiscordUser* request);

typedef struct DiscordEventHandlers {
    readyPtr ready;
    disconnectedPtr disconnected;
    erroredPtr errored;
    joinGamePtr joinGame;
    spectateGamePtr spectateGame;
    joinRequestPtr joinRequest;
} DiscordEventHandlers;

void Discord_Initialize(const char* applicationId,
                        DiscordEventHandlers* handlers,
                        int autoRegister,
                        const char* optionalSteamId);
void Discord_Shutdown(void);
void Discord_RunCallbacks(void);
void Discord_UpdatePresence(const DiscordRichPresence* presence);
void Discord_ClearPresence(void);
void Discord_Respond(const char* userid, int reply);
]]

local discordRPClib
local rpc_initialized = false

local function load_discord_rpc()
    local mpv_dir = mp.get_property("mpv-home") or ""

    -- Platform-specific library search paths
    local paths = {}
    if jit.os == "Windows" then
        paths = {
            "discord-rpc",
            mpv_dir ~= "" and (mpv_dir .. "/discord-rpc.dll") or nil,
            mpv_dir ~= "" and (mpv_dir .. "/libdiscord-rpc.dll") or nil,
            "C:/msys64/mingw64/bin/libdiscord-rpc.dll",
            os.getenv("LOCALAPPDATA") and (os.getenv("LOCALAPPDATA") .. "/mpv/discord-rpc.dll") or nil,
        }
    else
        paths = {
            "discord-rpc",
            os.getenv("HOME") .. "/.local/lib/libdiscord-rpc.so",
            "/usr/local/lib/libdiscord-rpc.so",
            "/usr/lib/libdiscord-rpc.so",
            mpv_dir ~= "" and (mpv_dir .. "/libdiscord-rpc.so") or nil,
            mpv_dir ~= "" and (mpv_dir .. "/discord-rpc.so") or nil,
        }
    end

    for _, path in ipairs(paths) do
        if path then
            local ok, lib = pcall(ffi.load, path)
            if ok then
                discordRPClib = lib
                msg.info("Loaded discord-rpc from: " .. path)
                return true
            end
        end
    end

    local hint = jit.os == "Windows"
        and "Download from github.com/discord/discord-rpc/releases and place DLL next to mpv.exe"
        or "Install to ~/.local/lib/ or /usr/local/lib/"
    msg.error("Failed to load discord-rpc library. " .. hint)
    return false
end

-- ============================================================
-- Callback proxies (must not be garbage collected)
-- ============================================================
local proxies = {}

local function unpack_user(request)
    return ffi.string(request.userId), ffi.string(request.username),
        ffi.string(request.discriminator), ffi.string(request.avatar)
end

local function init_callbacks()
    proxies.ready = ffi.cast("readyPtr", function(request)
        local _, username, discrim = unpack_user(request)
        msg.verbose("Discord connected: " .. username .. "#" .. discrim)
    end)

    proxies.disconnected = ffi.cast("disconnectedPtr", function(code, message)
        msg.warn("Discord disconnected: " .. code .. " - " .. ffi.string(message))
    end)

    proxies.errored = ffi.cast("erroredPtr", function(code, message)
        msg.error("Discord error: " .. code .. " - " .. ffi.string(message))
    end)

    proxies.joinGame = ffi.cast("joinGamePtr", function(s)
        msg.verbose("Discord join: " .. ffi.string(s))
    end)

    proxies.spectateGame = ffi.cast("spectateGamePtr", function(s)
        msg.verbose("Discord spectate: " .. ffi.string(s))
    end)

    proxies.joinRequest = ffi.cast("joinRequestPtr", function(request)
        local _, username = unpack_user(request)
        msg.verbose("Discord join request: " .. username)
        discordRPClib.Discord_Respond(_, 1)
    end)
end

local function free_callbacks()
    for k, v in pairs(proxies) do
        pcall(function() v:free() end)
    end
    proxies = {}
end

local function drpc_init()
    if rpc_initialized then return true end
    if not discordRPClib then
        if not load_discord_rpc() then return false end
    end

    init_callbacks()

    local handlers = ffi.new("struct DiscordEventHandlers")
    handlers.ready = proxies.ready
    handlers.disconnected = proxies.disconnected
    handlers.errored = proxies.errored
    handlers.joinGame = proxies.joinGame
    handlers.spectateGame = proxies.spectateGame
    handlers.joinRequest = proxies.joinRequest

    local app_id = "448016723057049601"
    discordRPClib.Discord_Initialize(app_id, handlers, 1, nil)
    rpc_initialized = true
    msg.info("Discord RPC initialized")
    return true
end

local function drpc_shutdown()
    if not rpc_initialized then return end
    discordRPClib.Discord_ClearPresence()
    discordRPClib.Discord_Shutdown()
    free_callbacks()
    rpc_initialized = false
    msg.info("Discord RPC shut down")
end

local function drpc_update_presence(presence)
    if not rpc_initialized then return end
    discordRPClib.Discord_UpdatePresence(presence)
end

local function drpc_clear()
    if not rpc_initialized then return end
    discordRPClib.Discord_ClearPresence()
end

local function drpc_run_callbacks()
    if not rpc_initialized then return end
    discordRPClib.Discord_RunCallbacks()
end
jit.off(drpc_run_callbacks)

-- ============================================================
-- API client (AniList primary, Jikan fallback)
-- ============================================================
local search_cache = {}
local episode_cache = {}
local last_api_call = 0

local function rate_limit()
    local now = mp.get_time() * 1000
    local elapsed = now - last_api_call
    if elapsed < o.api_delay then
        return false
    end
    last_api_call = now
    return true
end

local function api_get(url, post_body)
    -- Detect HTTP client: curl (Linux/macOS), curl.exe (Windows 10+), or PowerShell fallback
    local curl_cmd = "curl"
    if jit.os == "Windows" then
        -- On Windows, 'curl' might alias to PowerShell's curl alias; use curl.exe
        local test = mp.command_native({
            name = "subprocess", capture_stdout = true, playback_only = false,
            args = { "curl.exe", "--version" }
        })
        if test.status == 0 then
            curl_cmd = "curl.exe"
        else
            -- PowerShell fallback for HTTP requests
            local ps_args = {
                "powershell", "-NoProfile", "-Command",
                string.format(
                    "[System.Net.ServicePointManager]::SecurityProtocol=[System.Net.SecurityProtocolType]::Tls12; " ..
                    "$r=Invoke-WebRequest -Uri '%s' -UseBasicParsing -TimeoutSec 10%s; " ..
                    "$r.Content",
                    url,
                    post_body and (" -Method POST -ContentType 'application/json' -Body '" .. post_body:gsub("'", "''") .. "'") or ""
                )
            }
            local result = mp.command_native({
                name = "subprocess", capture_stdout = true, playback_only = false,
                args = ps_args
            })
            if result.status ~= 0 or not result.stdout or result.stdout == "" then
                msg.warn("PowerShell request failed")
                return nil
            end
            local json = utils.parse_json(result.stdout)
            return json
        end
    end

    local args = { curl_cmd, "-s", "-m", "10" }
    if post_body then
        args = { curl_cmd, "-s", "-m", "10", "-X", "POST",
                 "-H", "Content-Type: application/json",
                 "-H", "Accept: application/json",
                 "-d", post_body, url }
    else
        args[#args + 1] = url
    end
    local result = mp.command_native({
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        args = args
    })
    if result.status ~= 0 then
        msg.warn("curl failed: " .. tostring(result.error_string))
        return nil
    end
    if not result.stdout or result.stdout == "" then
        msg.warn("curl returned empty stdout")
        return nil
    end
    local json = utils.parse_json(result.stdout)
    if not json then
        msg.warn("Failed to parse JSON: " .. result.stdout:sub(1, 100))
        return nil
    end
    return json
end

local function encode_title(title)
    return title:gsub(" ", "%%20"):gsub("&", "%%26"):gsub("'", "%%27")
end

-- ============================================================
-- AniList (GraphQL) — primary source
-- Reliable CDN, gives cover + episode titles + relations
-- ============================================================
local ANILIST_QUERY = [[
query ($search: String) {
  Media(search: $search, type: ANIME) {
    id
    title { romaji english }
    coverImage { extraLarge large }
    episodes
    status
    averageScore
    relations {
      edges { relationType node { id title { romaji english } format } }
    }
    streamingEpisodes { title thumbnail site }
  }
}]]

local function graphql_escape(s)
    return s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n")
end

local function anilist_search(title, season_num)
    local body = string.format('{"query":"%s","variables":{"search":"%s"}}',
        graphql_escape(ANILIST_QUERY), graphql_escape(title))
    local resp = api_get("https://graphql.anilist.co", body)
    if not resp or not resp.data or not resp.data.Media then
        msg.verbose("AniList: no result for " .. title)
        return nil
    end
    local media = resp.data.Media

    -- Season matching via relations: if file is S2+, look for a sequel
    if season_num and season_num > 1 then
        local current = media
        for _ = 2, season_num do
            local next_season = nil
            if current.relations and current.relations.edges then
                for _, edge in ipairs(current.relations.edges) do
                    if edge.relationType == "SEQUEL" and edge.node.format == "TV" then
                        next_season = edge.node
                        break
                    end
                end
            end
            if not next_season then break end
            -- Fetch full data for the sequel
            local b = string.format('{"query":%s,"variables":{"id":%d}}',
                graphql_escape([[query ($id: Int) { Media(id: $id, type: ANIME) {
                    id title { romaji english } coverImage { extraLarge large }
                    episodes status averageScore
                    streamingEpisodes { title thumbnail site } } }]]),
                next_season.id)
            local r2 = api_get("https://graphql.anilist.co", b)
            if not r2 or not r2.data or not r2.data.Media then break end
            current = r2.data.Media
        end
        media = current
    end

    -- Build unified anime object
    local title_en = media.title and (media.title.english or media.title.romaji) or nil
    local cover = nil
    if media.coverImage then
        cover = media.coverImage.extraLarge or media.coverImage.large
    end

    -- Episode titles from streamingEpisodes (if available)
    local eps = {}
    if media.streamingEpisodes then
        for i, ep in ipairs(media.streamingEpisodes) do
            eps[i] = { title = ep.title, thumbnail = ep.thumbnail }
        end
    end

    return {
        title = title_en,
        cover_url = cover,
        episodes_total = media.episodes,
        ep_titles = eps,
        score = media.averageScore and (media.averageScore / 10) or nil,
        status = media.status,
        source = "anilist",
    }
end

-- Jikan fallback: search by name
local function search_jikan(title)
    local encoded = encode_title(title)
    local url = "https://api.jikan.moe/v4/anime?q=" .. encoded .. "&limit=5"
    local resp = api_get(url)
    if not resp or resp.status then return nil end
    if not resp.data or #resp.data == 0 then return nil end

    local best = nil
    local best_score = -1
    for _, anime in ipairs(resp.data) do
        local score = anime.score or 0
        if anime.type == "TV" then score = score + 10 end
        if anime.type == "Movie" then score = score + 5 end
        if score > best_score then
            best_score = score
            best = anime
        end
    end
    if not best then return nil end

    local cover = nil
    if best.images and best.images.jpg then
        cover = best.images.jpg.large_image_url or best.images.jpg.image_url
    end
    return {
        title = best.title_english or best.title,
        cover_url = cover,
        episodes_total = best.episodes,
        ep_titles = {},
        score = best.score,
        status = best.status,
        source = "jikan",
    }
end

-- Jikan fallback: get episode titles
local function get_jikan_episodes(mal_id)
    local url = "https://api.jikan.moe/v4/anime/" .. mal_id .. "/episodes?page=1"
    local resp = api_get(url)
    if not resp or not resp.data then return {} end
    local eps = {}
    for _, ep in ipairs(resp.data) do
        eps[ep.mal_id] = { title = ep.title }
    end
    return eps
end

-- Unified search: try AniList first, then Jikan
local function search_anime(title, season_num)
    local cached = search_cache[title .. ":" .. tostring(season_num)]
    if cached and (mp.get_time() - cached.time) < o.search_cache_ttl then
        return cached.data
    end

    local result = anilist_search(title, season_num)
    if not result then
        rate_limit()
        result = search_jikan(title)
    end

    if result then
        search_cache[title .. ":" .. tostring(season_num)] = { data = result, time = mp.get_time() }
        msg.verbose("API match: " .. tostring(result.title) .. " (source: " .. result.source .. ")")
    else
        msg.verbose("No match for: " .. title)
    end
    return result
end

-- ============================================================
-- Filename parser (extract anime title + episode number)
-- ============================================================

local function strip_extension(name)
    return name:gsub("%.[^%.]+$", "")
end

local function extract_episode(filename)
    local name = strip_extension(filename)

    -- S01E03 / S01E01-E03 / S01E01E02E03 / S01.5E01 (half-season)
    local season, ep = name:match("[Ss](%d+%.?%d*)[Ee](%d+)")
    if season and ep then return tonumber(ep), tonumber(season) end

    -- Separated tags: [S01][E01] or [S01] [E01]
    local s_tag = name:match("%[S(%d+)%]")
    local e_tag = name:match("%[E(%d+)%]")
    if s_tag and e_tag then return tonumber(e_tag), tonumber(s_tag) end
    if e_tag then return tonumber(e_tag), nil end

    -- EP01 / EP.01 / Ep 01 / EP-01 / Epi01
    local ep_num = name:match("[Ee][Pp][i]?[%s%.%-]*(%d+)")
    if ep_num then return tonumber(ep_num), nil end

    -- Episode 01 / Episode 1
    ep_num = name:match("[Ee]pisode[%s%.%-]+(%d+)")
    if ep_num then return tonumber(ep_num), nil end

    -- #01 hash-style episode marker
    ep_num = name:match("#(%d+)")
    if ep_num then return tonumber(ep_num), nil end

    -- Title - 01 (or Title - 01v2, Title - 01 (1080p), etc.)
    -- Must come AFTER date check to avoid matching dates
    local is_date = name:match("(%d%d%d%d)[%-%./](%d%d)[%-%./](%d%d)")
    if not is_date then
        ep_num = name:match("%s%-+%s*(%d+%.?%d*)")
        if ep_num then return tonumber(ep_num), nil end
    end

    -- Title [01]
    ep_num = name:match("%[(%d+%.?%d*)%]")
    if ep_num then return tonumber(ep_num), nil end

    -- Underscore episode markers: _01_, _01 at end
    ep_num = name:match("_(%d+)_")
    if ep_num then return tonumber(ep_num), nil end

    -- Title 01 (bare number after dash) — also date-protected
    if not is_date then
        ep_num = name:match("%-+%s*(%d+)")
        if ep_num then return tonumber(ep_num), nil end
    end

    -- SP01 / SP.01 (special episodes with number)
    ep_num = name:match("[Ss][Pp][%.%s%-]*(%d+)")
    if ep_num then return tonumber(ep_num), nil end

    -- EX01 / EX.01 (extra episodes)
    ep_num = name:match("[Ee][Xx][%.%s%-]*(%d+)")
    if ep_num then return tonumber(ep_num), nil end

    -- Chapter 01
    ep_num = name:match("[Cc]hapter[%s%.%-]+(%d+)")
    if ep_num then return tonumber(ep_num), nil end

    -- Cour 1 - 01 (cour is like a half-season block)
    ep_num = name:match("[Cc]our[%s%.%-]+%d+[%s%.%-]+(%d+)")
    if ep_num then return tonumber(ep_num), nil end

    -- NCOP / NCED (non-credit open/end) → episode 0
    if name:match("[Nn][Cc][Oo][Pp]") or name:match("[Nn][Cc][Ee][Dd]") then
        return 0, nil
    end

    -- OVA / OAD / ONA / Special / SP (without number) → episode 0
    if name:match("[Oo][Vv][Aa]") or name:match("[Oo][Aa][Dd]") or
       name:match("[Oo][Nn][Aa]") or name:match("[Ss]pecial") or
       name:match("[Ss][Pp]%d") then
        return 0, nil
    end

    -- End / Final / Last / Recap / Preview → episode 0
    if name:match("[Ee]nd%s*$") or name:match("[Ff]inal%s*$") or
       name:match("[Ll]ast%s*$") or name:match("[Rr]ecap%s*$") or
       name:match("[Pp]review%s*$") then
        return 0, nil
    end

    -- Part 1 / Part I → episode = part number
    local part = name:match("[Pp]art[%s%.%-]+(%d+)")
    if part then return tonumber(part), nil end
    local roman = name:match("[Pp]art[%s%.%-]+([IVX]+)")
    if roman then
        local vals = { I=1, V=5, X=10 }
        local n = 0
        for ch in roman:upper():gmatch(".") do n = n + (vals[ch] or 0) end
        return n, nil
    end

    return nil, nil
end

local function extract_title(filename)
    local name = strip_extension(filename)

    -- Remove leading group tags: [Group] or 【Group】 (multiple)
    while name:match("^%s*%[.-%]%s*") do name = name:gsub("^%s*%[.-%]%s*", "") end
    while name:match("^%s*【.-%】%s*") do name = name:gsub("^%s*【.-%】%s*", "") end

    -- Dotted scene-release names: cut at first quality/codec marker, convert dots
    local dot_count = 0
    for _ in name:gmatch("%.") do dot_count = dot_count + 1 end
    if dot_count >= 3 then
        local markers = {
            "%.%d+[Pp]", "%.[Bb][Dd]%-?[Rr]ip", "%.[Bb][Dd]",
            "%.[Ww][Ee][Bb]%-?[Rr]ip", "%.[Ww][Ee][Bb]%-?[Dd][Ll]",
            "%.[Hh][Dd][Rr]%-?[Ii]p", "%.[Dd][Vv][Dd]%-?[Rr]ip",
            "%.[Xx]26[45]", "%.[Hh][Ee][Vv][Cc]", "%.[Aa][Vv]1",
            "%.[Oo]pus", "%.[Aa][Aa][Cc]", "%.[Ff][Ll][Aa][Cc]",
            "%.[Ss]ubs[Pp]lease", "%.[Ee]rai", "%.[Hh]orrible",
        }
        for _, marker in ipairs(markers) do
            local pos = name:find(marker)
            if pos and pos > 2 then name = name:sub(1, pos - 1); break end
        end
        name = name:gsub("%.", " ")
    end

    -- Remove S01E03 and everything after (also handles S01.5E01 half-season)
    name = name:gsub("[Ss]%d+%.?%d*[Ee]%d+.*$", "")
    -- Also handle when dots were already converted: S01 5E01
    name = name:gsub("[Ss]%d+%s*%d*[Ee]%d+.*$", "")

    -- Remove separated S/E tags: [S01][E01] or [S01] [E01] or [E01]
    name = name:gsub("%[S%d+%]", "")
    name = name:gsub("%[E%d+%]", "")
    name = name:gsub("%s+", " ")

    -- Remove episode markers
    name = name:gsub("%s%-+%s*%d+.*$", "")
    name = name:gsub("%s*%[%d+%.?%d*%].*$", "")
    name = name:gsub("[Ee][Pp][i]?[%s%.%-]*%d+.*$", "")
    name = name:gsub("[Ee]pisode[%s%.%-]*%d+.*$", "")
    name = name:gsub("#%d+.*$", "")
    -- Underscore episode markers: _01_, _02_
    name = name:gsub("_%d+_.-$", " ")

    -- Remove season markers
    name = name:gsub("[Ss]eason%s*%d+.*$", "")
    name = name:gsub("[Ss]%d+%s*$", "")
    name = name:gsub("[Ss]%d+%s*%-", "-")

    -- Remove special markers
    name = name:gsub("[Oo][Vv][Aa].*$", "")
    name = name:gsub("[Oo][Aa][Dd].*$", "")
    name = name:gsub("[Oo][Nn][Aa].*$", "")
    name = name:gsub("[Ss]pecial.*$", "")
    name = name:gsub("[Ss][Pp][%.%s%-]*%d+.*$", "")
    name = name:gsub("[Nn][Cc][Oo][Pp].*$", "")
    name = name:gsub("[Nn][Cc][Ee][Dd].*$", "")
    name = name:gsub("[Ee][Xx][%.%s%-]*%d+.*$", "")
    name = name:gsub("[Cc]hapter[%s%.%-]+%d+.*$", "")
    name = name:gsub("[Cc]our[%s%.%-]+%d+[%s%.%-]+%d+.*$", "")
    name = name:gsub("[Cc]our[%s%.%-]+%d+.*$", "")
    name = name:gsub("[Ee]nd%s*$", "")
    name = name:gsub("[Ff]inal%s*$", "")
    name = name:gsub("[Ll]ast%s*$", "")
    name = name:gsub("[Rr]ecap%s*$", "")
    name = name:gsub("[Pp]review%s*$", "")

    -- Remove Part markers
    name = name:gsub("[Pp]art%s+[IVX%d]+.*$", "")

    -- Remove version tags: v2, v3 (with or without brackets)
    name = name:gsub("%s+v%d+.*$", "")
    name = name:gsub("%s*%[v%d+%].*$", "")

    -- Remove date markers: 2023-01-15
    name = name:gsub("%s*%d%d%d%d[%-%./]%d%d[%-%./]%d%d.*$", "")

    -- Remove quality/technical tags (bracketed)
    local tag_patterns = {
        "%[%d+p%]", "%[%d+x%d+%]", "%[BD%]", "%[BDRip%]", "%[WEBRip%]",
        "%[WEB%DL%]", "%[HDRip%]", "%[DVDRip%]", "%[Blu%-ray%]",
        "%[x264%]", "%[x265%]", "%[HEVC%]", "%[AV1%]",
        "%[FLAC%]", "%[AAC%]", "%[OPUS%]", "%[5%.1%]", "%[7%.1%]",
        "%[10%-bit%]", "%[8%-bit%]", "%[HDR%]", "%[DV%]",
        "%[%w+%.?%w+%]$", -- CRC hashes [ABCD1234] or [AB1234CD]
        "%[%d+%]",         -- lone bracket numbers
    }
    for _, p in ipairs(tag_patterns) do name = name:gsub(p, "") end

    -- Remove trailing year
    name = name:gsub("%s*%(%d%d%d%d%)%s*$", "")
    name = name:gsub("%s*%[%d%d%d%d%]%s*$", "")
    name = name:gsub("%s*%d%d%d%d%s*$", "")  -- bare year

    -- Normalize
    name = name:gsub("^%s*%-+%s*", "")
    name = name:gsub("%s*%-+%s*$", "")
    name = name:gsub("_", " ")
    name = name:gsub("%s+", " ")
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    name = name:gsub("%.$", "")
    name = name:gsub("%-$", "")
    name = name:gsub("%s*[%.,:]+$", "")

    return name
end

-- ============================================================
-- State
-- ============================================================
local state = {
    anime = nil,       -- MAL anime object
    episodes = {},     -- episode cache for current anime
    episode_num = nil, -- current episode number
    season_num = nil,  -- current season number
    cover_url = nil,   -- cover art URL
    title = nil,       -- display title
    ep_title = nil,    -- episode title
    is_anime = false,  -- is this anime content?
}

local function reset_state()
    state.anime = nil
    state.episodes = {}
    state.episode_num = nil
    state.season_num = nil
    state.cover_url = nil
    state.title = nil
    state.ep_title = nil
    state.is_anime = false
end

-- ============================================================
-- Detect if content is anime
-- ============================================================
local function is_anime_content()
    local filename = mp.get_property("filename") or ""
    local path = mp.get_property("path") or ""

    -- Check for common anime release group patterns
    local group_patterns = {
        "SubsPlease", "Erai%-raws", "HorribleSubs", "Tsundere%-Raws",
        "SubsPlus%+", "Yameii", "%-VARYG", "Kaguya%-", "vivi%-",
        "ANi", "GANGSTA%+", "FGAMD", "Lilith%-Raws", "Mellow%+Subs",
        "Raizel", "Tenkuu%+Fansub", "Sakura%-Fansub", "Sakurato",
        "Kira%-", "Kuro%-", "Koi%-", "FLAC", "Deadshot",
    }
    for _, pattern in ipairs(group_patterns) do
        if filename:match(pattern) or path:match(pattern) then
            return true
        end
    end

    -- Check for anime file extensions and naming patterns
    if filename:match("%[.-%]%s*%-") then
        return true
    end

    -- Check for common anime video qualities in path (anime tends to be 1080p with specific codecs)
    if path:match("[Aa]nime") then return true end

    return false
end

-- ============================================================
-- Update anime metadata (AniList primary, Jikan fallback)
-- ============================================================
local function update_anime_metadata()
    if not state.title then return end

    local anime

    -- Try progressive title shortening for better matches
    local titles_to_try = { state.title }
    -- Add stripped year
    local stripped = state.title:gsub("%s*%(%d%d%d%d%)%s*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if stripped ~= state.title then table.insert(titles_to_try, stripped) end
    -- Add progressively shorter versions (drop last word each time)
    local words = {}
    for w in state.title:gmatch("%S+") do table.insert(words, w) end
    for i = #words - 1, math.max(2, math.floor(#words / 2)), -1 do
        local short = table.concat(words, " ", 1, i)
        if short ~= state.title then table.insert(titles_to_try, short) end
    end

    for _, try_title in ipairs(titles_to_try) do
        anime = search_anime(try_title, state.season_num)
        if anime then break end
    end

    if not anime then
        state.is_anime = false
        return
    end

    state.anime = anime
    state.is_anime = true
    state.title = anime.title or state.title
    state.cover_url = anime.cover_url

    -- Episode title
    if o.fetch_episode_titles and state.episode_num and anime.ep_titles then
        local ep = anime.ep_titles[state.episode_num]
        if ep and ep.title then
            state.ep_title = ep.title:gsub("^Episode %d+%s*%-?%s*", "")
        end
    end
end

-- ============================================================
-- Build and send presence
-- ============================================================
local start_time = 0  -- set on file-loaded

-- Persistent string storage: prevents Lua GC from collecting strings
-- before Discord reads the presence struct (FFI const char* issue)
local _strs = {}

local function set_str(field, value)
    if value and value ~= "" then
        _strs[field] = value
        return value
    end
    _strs[field] = nil
    return nil
end

local function format_time(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    if h > 0 then
        return string.format("%d:%02d:%02d", h, m, s)
    else
        return string.format("%02d:%02d", m, s)
    end
end

local function build_presence()
    local presence = ffi.new("struct DiscordRichPresence")
    ffi.fill(presence, ffi.sizeof(presence))

    local paused = mp.get_property_bool("pause")
    local idle = mp.get_property_bool("idle-active")
    local dur_str = mp.get_property("duration")
    local pos_str = mp.get_property("time-pos")
    local duration = (dur_str and tonumber(dur_str)) or 0
    local position = (pos_str and tonumber(pos_str)) or 0

    -- Determine play state
    local state_label, small_key, small_text
    if idle then
        state_label = "Idle"
        small_key = "player_stop"
        small_text = "Idle"
    elseif paused then
        state_label = "Paused"
        small_key = "player_pause"
        small_text = "Paused"
    else
        state_label = "Playing"
        small_key = "player_play"
        small_text = "Playing"
    end

    -- Line 1 (details): title
    local title = state.title or "Unknown"
    if title == "" then title = "Unknown" end
    if #title > 127 then title = title:sub(1, 124) .. "..." end

    -- Line 2 (state): episode info + time + playback state
    local time_str = ""
    if duration > 0 then
        time_str = format_time(position) .. " / " .. format_time(duration)
    end

    local state_line
    if state.episode_num then
        local ep_str
        if state.season_num and state.season_num > 1 then
            ep_str = "S" .. state.season_num .. ":E" .. state.episode_num
        else
            ep_str = "Episode " .. state.episode_num
        end
        if state.ep_title then
            ep_str = ep_str .. ": " .. state.ep_title
        end
        state_line = ep_str
    else
        state_line = state_label
    end

    -- Append time and state
    if time_str ~= "" then
        state_line = state_line .. " (" .. time_str .. ")"
    end
    state_line = state_line .. " - " .. state_label

    if #state_line > 127 then state_line = state_line:sub(1, 124) .. "..." end

    -- Assign strings through persistent table to prevent GC
    presence.details = set_str("details", title)
    presence.state = set_str("state", state_line)

    -- Large image: anime cover art URL if available, else mpv logo
    if state.cover_url then
        presence.largeImageKey = set_str("largeImageKey", state.cover_url)
    else
        presence.largeImageKey = set_str("largeImageKey", "mpv")
    end
    presence.largeImageText = set_str("largeImageText", title)
    presence.smallImageKey = set_str("smallImageKey", small_key)
    presence.smallImageText = set_str("smallImageText", small_text)

    -- Timestamps: elapsed time (re-anchored every update so Discord's
    -- client-side ticker stays accurate and seeks reflect instantly)
    if not idle then
        presence.startTimestamp = os.time() - math.floor(position)
    end

    return presence
end

-- ============================================================
-- Update loop
-- Discord hard rate-limits SET_ACTIVITY (~5 pushes / 20s).
-- Pushing every second floods the queue: updates arrive in
-- 7-10s bursts and ClearPresence gets stuck behind the backlog.
-- Instead we push only on state changes (load, seek, pause
-- toggles) plus a 15s keepalive. Discord renders the elapsed
-- timer client-side from the startTimestamp anchor, so it still
-- ticks every second without any pushes.
-- ============================================================
local rpc_timer = nil
local last_push = 0

local function push_presence()
    if not o.active then return end
    if not rpc_initialized then
        if not drpc_init() then return end
    end
    local presence = build_presence()
    drpc_update_presence(presence)
    drpc_run_callbacks()
    last_push = mp.get_time()
end

-- Rate-limit guard: skip if we pushed within the last 4s
-- (Discord allows ~5 SET_ACTIVITY per 20s; bursts get dropped)
local function schedule_push()
    if not o.active then return end
    local since = mp.get_time() - last_push
    if since >= 4 then
        push_presence()
    end
end

-- Keepalive: Discord may drop stale activities; refresh every 15s.
-- The elapsed timer ticks client-side every second regardless.
local function start_keepalive()
    if rpc_timer then rpc_timer:kill() end
    rpc_timer = mp.add_periodic_timer(15, function()
        if o.active then push_presence() end
    end)
end

-- ============================================================
-- Event handlers
-- ============================================================
local function on_file_loaded()
    if not o.active then return end

    reset_state()

    -- Extract title and episode from filename
    local filename = mp.get_property("filename") or ""
    state.title = extract_title(filename)
    state.episode_num, state.season_num = extract_episode(filename)

    -- Look up anime metadata (AniList primary, Jikan fallback)
    update_anime_metadata()

    -- If nothing matched, keep the extracted title
    if not state.is_anime and (not state.title or state.title == "") then
        state.title = mp.get_property("media-title") or "Unknown"
    end

    if not rpc_initialized then
        drpc_init()
    end

    start_keepalive()
    push_presence()
end

local function on_file_end()
    drpc_clear()
    last_push = mp.get_time()
end

local function on_shutdown()
    if rpc_timer then
        rpc_timer:kill()
        rpc_timer = nil
    end
    drpc_clear()
    drpc_shutdown()
end

-- ============================================================
-- Toggle
-- ============================================================
local function toggle_rpc()
    o.active = not o.active
    if o.active then
        mp.osd_message("Discord RPC: ON", 1.5)
        on_file_loaded()
    else
        mp.osd_message("Discord RPC: OFF", 1.5)
        if rpc_timer then
            rpc_timer:kill()
            rpc_timer = nil
        end
        drpc_clear()
    end
end

-- ============================================================
-- Register events
-- ============================================================
if o.active then
    load_discord_rpc()
    mp.register_event("file-loaded", on_file_loaded)
    mp.register_event("end-file", on_file_end)
    mp.register_event("shutdown", on_shutdown)

    -- Pause/resume: push immediately (throttled)
    mp.observe_property("pause", "bool", function()
        if o.active then schedule_push() end
    end)

    -- Seek: re-anchor the elapsed timer at the new position
    -- (position changes many times per second while seeking,
    -- so throttle to avoid flooding Discord's rate limit)
    mp.observe_property("seeking", "bool", function(_, seeking)
        if o.active and not seeking then
            schedule_push()
        end
    end)
end

mp.add_key_binding(o.key_toggle, "toggle-discord-rpc", toggle_rpc)
