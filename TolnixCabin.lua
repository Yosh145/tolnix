-- tolnix (Toliss-Fenix) cabin announcements
-- v1.0.1
--
-- Directory structure:
--   .../FlyWithLua/Scripts/TolnixCabin.lua
--   .../FlyWithLua/Scripts/Announcements/{ICAO}/{files}.ogg

local RUNNING_IN_XPLANE = (SCRIPT_DIRECTORY ~= nil)

if not RUNNING_IN_XPLANE then
    local script_path = arg and arg[0] or "."
    local dir = script_path:match("^(.*[/\\])") or "./"
    SCRIPT_DIRECTORY  = dir
    SYSTEM_DIRECTORY  = dir

    function logMsg(msg) print("[TolnixCabin] " .. msg) end

    function dataref(global_name, _, _)
        _G[global_name] = 0
    end
    function dataref_table(_)
        return setmetatable({}, {
            __index = function() return 0 end
        })
    end

    function do_every_draw(_) end

    function float_wnd_create(...)  return {} end
    function float_wnd_destroy(...) end
    function float_wnd_set_title(...)        end
    function float_wnd_set_imgui_builder(...) end
    function float_wnd_set_position(...)     end
    function add_macro(...)     end
    function create_command(...) end

    -- imgui stub
    local function make_sink()
        local sink = {}
        setmetatable(sink, {
            __index = function(_, _) return make_sink() end,
            __call  = function(_, ...) return 0 end,
        })
        return sink
    end
    imgui = make_sink()

    -- bit stub
    if not bit then
        bit = {
            bor  = function(a, b) return a | b end,
            band = function(a, b) return a & b end,
        }
    end

    logMsg("Running outside FlyWithLua — stubs active, sound/GUI disabled")
end

-- ===
-- config constants
-- ===

local TC = {} 

TC.VERSION = "1.0.1"
TC.WINDOW_TITLE = "Tolnix Cabin Announcements"
TC.WINDOW_WIDTH = 820
TC.WINDOW_HEIGHT = 420
TC.RUNNING_IN_XPLANE = RUNNING_IN_XPLANE

-- announcements path
TC.ANNOUNCEMENTS_DIR = SCRIPT_DIRECTORY .. "Announcements"

-- categories
TC.CATEGORIES = {
    {
        name = "Boarding",
        announcements = {"BoardingWelcome", "BoardingMusic", "BoardingComplete"}
    },
    {
        name = "Taxi",
        announcements = {"ArmDoors", "PreSafetyBriefing", "SafetyBriefing"}
    },
    {
        name = "Takeoff",
        announcements = {"CabinDimTakeoff", "CrewSeatsTakeoff", "CallCabinSecureTakeoff"}
    },
    {
        name = "Cruise",
        announcements = {"AfterTakeoff", "FastenSeatbelt"}
    },
    {
        name = "Landing",
        announcements = {"DescentSeatbelts", "CrewSeatsLanding", "CallCabinSecureLanding"}
    },
    {
        name = "After Landing",
        announcements = {"AfterLanding", "DisarmDoors", "DisembarkStarted"}
    }
}

-- display names
TC.DISPLAY_NAMES = {
    BoardingWelcome         = "Boarding\nWelcome",
    BoardingMusic           = "Boarding\nMusic",
    BoardingComplete        = "Boarding\nComplete",
    ArmDoors                = "Arm\nDoors",
    PreSafetyBriefing       = "Pre Safety\nBriefing",
    SafetyBriefing          = "Safety\nBriefing",
    CabinDimTakeoff         = "Cabin Dim\nTakeoff",
    CrewSeatsTakeoff        = "Crew Seats\nTakeoff",
    CallCabinSecureTakeoff  = "Cabin Secure\nTakeoff",
    AfterTakeoff            = "After\nTakeoff",
    FastenSeatbelt          = "Fasten\nSeatbelt",
    DescentSeatbelts        = "Descent\nSeatbelts",
    CrewSeatsLanding        = "Crew Seats\nLanding",
    CallCabinSecureLanding  = "Cabin Secure\nLanding",
    AfterLanding            = "After\nLanding",
    DisarmDoors             = "Disarm\nDoors",
    DisembarkStarted        = "Disembark\nStarted"
}

-- valid names
TC.VALID_BASE_NAMES = {}
for _, cat in ipairs(TC.CATEGORIES) do
    for _, ann in ipairs(cat.announcements) do
        TC.VALID_BASE_NAMES[ann] = true
    end
end

-- time tags
TC.TIME_TAGS = {
    Night     = true,  -- 00:00 - 05:59
    Morning   = true,  -- 06:00 - 11:59
    Afternoon = true,  -- 12:00 - 17:59
    Evening   = true   -- 18:00 - 23:59
}

-- aircraft tags
TC.AIRCRAFT_TAGS = {
    A319 = true, A320 = true, A321 = true,
    A330 = true, A340 = true, A350 = true
}

-- music loop threshold
TC.BOARDING_MUSIC_LOOP_THRESHOLD = 300

-- fmod
TC.FMOD_OK              = 0
TC.FMOD_DEFAULT         = 0x00000000
TC.FMOD_LOOP_OFF        = 0x00000001
TC.FMOD_LOOP_NORMAL     = 0x00000002
TC.FMOD_CREATESTREAM    = 0x00000080
TC.FMOD_TIMEUNIT_MS     = 0x00000001

-- xplane audio
TC.XPLM_AUDIO_INTERIOR  = 4

-- ===
-- state vars
-- ===

TC.state = {
    -- gui
    window              = nil,
    window_visible      = false,
    current_category    = 1,

    -- soundpack
    available_icaos     = {},
    current_icao        = "",
    current_icao_idx    = 0,

    -- library
    announcement_files  = {},

    -- crew number
    flight_crew_number  = 1,
    max_crew_variations = 1,

    -- sound engine
    fmod_ready          = false,
    fmod_core           = nil,
    fmod_channel_group  = nil,

    -- loaded sounds
    loaded_sounds       = {},

    -- active channel
    active_channel      = nil,
    active_announcement = nil,

    -- loop state
    loop_prompt_active  = false,
    loop_prompt_ann_id  = nil,
    boarding_music_loop = false,

    -- aircraft
    aircraft_type       = ""
}

-- ===
-- dataref access
-- ===

-- local time
dataref("tc_local_time_sec", "sim/time/local_time_sec", "readonly")

-- aircraft icao
local acf_icao_table = dataref_table("sim/aircraft/view/acf_ICAO")

-- read aircraft
local function get_aircraft_icao()
    local s = ""
    for i = 0, 39 do
        local b = acf_icao_table[i]
        if b == nil or b == 0 then break end
        s = s .. string.char(b)
    end
    return s
end

-- time of day
function TC.get_time_of_day()
    local hours = (tc_local_time_sec or 0) / 3600
    if hours < 6 then
        return "Night"
    elseif hours < 12 then
        return "Morning"
    elseif hours < 18 then
        return "Afternoon"
    else
        return "Evening"
    end
end

-- format time
function TC.format_sim_time()
    local total_sec = tc_local_time_sec or 0
    local h = math.floor(total_sec / 3600) % 24
    local m = math.floor((total_sec % 3600) / 60)
    return string.format("%02d:%02d", h, m)
end

-- ===
-- sound engine fmod
-- ===

local ffi_ok, ffi = pcall(require, "ffi")
if not ffi_ok then
    -- puc lua
    ffi = {
        os = (package.config:sub(1,1) == "\\") and "Windows" or "Linux",
        cdef = function() end,
        new  = function() return {} end,
        C    = {},
    }
    logMsg("LuaJIT FFI not available — sound engine will be disabled")
end

-- ffi fmod xplm
ffi.cdef[[
    /* Opaque FMOD types */
    typedef struct FMOD_SYSTEM        FMOD_SYSTEM;
    typedef struct FMOD_SOUND         FMOD_SOUND;
    typedef struct FMOD_CHANNEL       FMOD_CHANNEL;
    typedef struct FMOD_CHANNELGROUP  FMOD_CHANNELGROUP;
    typedef struct FMOD_STUDIO_SYSTEM FMOD_STUDIO_SYSTEM;

    typedef int          FMOD_RESULT;
    typedef unsigned int FMOD_MODE;
    typedef int          FMOD_BOOL;

    /* XPLM Sound API (SDK 4.0 / X-Plane 12.04+) */
    FMOD_STUDIO_SYSTEM* XPLMGetFMODStudio(void);
    FMOD_CHANNELGROUP*  XPLMGetFMODChannelGroup(int audioType);

    /* FMOD Studio -> Core bridge */
    FMOD_RESULT FMOD_Studio_System_GetCoreSystem(
        FMOD_STUDIO_SYSTEM *system,
        FMOD_SYSTEM       **coresystem
    );

    /* FMOD Core functions */
    FMOD_RESULT FMOD_System_CreateSound(
        FMOD_SYSTEM      *system,
        const char       *name_or_data,
        FMOD_MODE         mode,
        void             *exinfo,
        FMOD_SOUND      **sound
    );

    FMOD_RESULT FMOD_System_PlaySound(
        FMOD_SYSTEM       *system,
        FMOD_SOUND        *sound,
        FMOD_CHANNELGROUP *channelgroup,
        FMOD_BOOL          paused,
        FMOD_CHANNEL     **channel
    );

    FMOD_RESULT FMOD_Sound_Release(FMOD_SOUND *sound);

    FMOD_RESULT FMOD_Sound_GetLength(
        FMOD_SOUND   *sound,
        unsigned int *length,
        unsigned int  lengthtype
    );

    FMOD_RESULT FMOD_Channel_Stop(FMOD_CHANNEL *channel);

    FMOD_RESULT FMOD_Channel_IsPlaying(
        FMOD_CHANNEL *channel,
        FMOD_BOOL    *isplaying
    );

    FMOD_RESULT FMOD_Channel_SetVolume(FMOD_CHANNEL *channel, float volume);

    FMOD_RESULT FMOD_Channel_SetMode(FMOD_CHANNEL *channel, FMOD_MODE mode);
]]

-- load libs
local xplm_lib   = nil
local fmod_lib    = nil
local fmod_st_lib = nil

local function load_ffi_libraries()
    local xp_dir = SYSTEM_DIRECTORY or ""

    -- try xplm
    local ok
    ok = pcall(function()
        local _ = ffi.C.XPLMGetFMODStudio   -- test symbol resolution
        xplm_lib = ffi.C
    end)
    if not ok then
        ok = pcall(function()
            xplm_lib = ffi.load(xp_dir .. "Resources/plugins/XPLM_64")
        end)
    end
    if not ok then
        logMsg("TolnixCabin: WARNING - Could not load XPLM library via FFI")
        return false
    end

    -- fmod core
    ok = pcall(function()
        if ffi.os == "Windows" then
            fmod_lib = ffi.load("fmod")
        else
            fmod_lib = ffi.load("fmod")
        end
    end)
    if not ok then
        -- try path
        ok = pcall(function()
            if ffi.os == "Windows" then
                fmod_lib = ffi.load(xp_dir .. "fmod")
            elseif ffi.os == "Linux" then
                fmod_lib = ffi.load(xp_dir .. "libfmod.so.13")
            else
                fmod_lib = ffi.load(xp_dir .. "libfmod.dylib")
            end
        end)
    end
    if not ok then
        logMsg("TolnixCabin: WARNING - Could not load FMOD core library")
        return false
    end

    -- fmod studio
    ok = pcall(function()
        if ffi.os == "Windows" then
            fmod_st_lib = ffi.load("fmodstudio")
        else
            fmod_st_lib = ffi.load("fmodstudio")
        end
    end)
    if not ok then
        ok = pcall(function()
            if ffi.os == "Windows" then
                fmod_st_lib = ffi.load(xp_dir .. "fmodstudio")
            elseif ffi.os == "Linux" then
                fmod_st_lib = ffi.load(xp_dir .. "libfmodstudio.so.13")
            else
                fmod_st_lib = ffi.load(xp_dir .. "libfmodstudio.dylib")
            end
        end)
    end
    if not ok then
        logMsg("TolnixCabin: WARNING - Could not load FMOD Studio library")
        return false
    end

    return true
end

-- init fmod
function TC.init_sound_engine()
    if not RUNNING_IN_XPLANE or not ffi_ok then
        logMsg("TolnixCabin: Sound engine skipped (not in X-Plane or no FFI)")
        TC.state.fmod_ready = false
        return
    end

    if not load_ffi_libraries() then
        logMsg("TolnixCabin: Sound engine init FAILED (FFI libraries)")
        TC.state.fmod_ready = false
        return
    end

    local ok, err = pcall(function()
        -- get xplane
        local studio = xplm_lib.XPLMGetFMODStudio()
        if studio == nil then error("XPLMGetFMODStudio returned nil") end

        -- get core
        local core_ptr = ffi.new("FMOD_SYSTEM*[1]")
        local res = fmod_st_lib.FMOD_Studio_System_GetCoreSystem(studio, core_ptr)
        if res ~= TC.FMOD_OK then error("GetCoreSystem failed: " .. tostring(res)) end
        TC.state.fmod_core = core_ptr[0]

        -- get interior
        TC.state.fmod_channel_group = xplm_lib.XPLMGetFMODChannelGroup(
            TC.XPLM_AUDIO_INTERIOR
        )
    end)

    if ok then
        TC.state.fmod_ready = true
        logMsg("TolnixCabin: FMOD sound engine initialised OK")
    else
        TC.state.fmod_ready = false
        logMsg("TolnixCabin: Sound engine init FAILED - " .. tostring(err))
    end
end

-- load ogg
function TC.load_sound(file_path, stream)
    if not TC.state.fmod_ready then return nil end

    local mode = TC.FMOD_DEFAULT
    if stream then
        mode = bit.bor(TC.FMOD_CREATESTREAM, TC.FMOD_LOOP_OFF)
    end

    local sound_ptr = ffi.new("FMOD_SOUND*[1]")
    local res = fmod_lib.FMOD_System_CreateSound(
        TC.state.fmod_core,
        file_path,
        mode,
        nil,
        sound_ptr
    )

    if res ~= TC.FMOD_OK then
        logMsg("TolnixCabin: Failed to load sound " .. file_path .. " (err " .. res .. ")")
        return nil
    end

    return sound_ptr[0]
end

-- sound length
function TC.get_sound_length_sec(fmod_sound)
    if fmod_sound == nil then return 0 end
    local len = ffi.new("unsigned int[1]")
    local res = fmod_lib.FMOD_Sound_GetLength(fmod_sound, len, TC.FMOD_TIMEUNIT_MS)
    if res ~= TC.FMOD_OK then return 0 end
    return len[0] / 1000.0
end

-- play sound
function TC.play_sound(fmod_sound, loop)
    if not TC.state.fmod_ready or fmod_sound == nil then return nil end

    -- stop playing
    TC.stop_current()

    -- set loop
    if loop then
        -- mode channel
    end

    local chan_ptr = ffi.new("FMOD_CHANNEL*[1]")
    local res = fmod_lib.FMOD_System_PlaySound(
        TC.state.fmod_core,
        fmod_sound,
        TC.state.fmod_channel_group,  -- route to interior bus
        0,   -- not paused
        chan_ptr
    )

    if res ~= TC.FMOD_OK then
        logMsg("TolnixCabin: PlaySound failed (err " .. res .. ")")
        return nil
    end

    local channel = chan_ptr[0]

    -- apply loop
    if loop and channel ~= nil then
        fmod_lib.FMOD_Channel_SetMode(channel, TC.FMOD_LOOP_NORMAL)
    end

    return channel
end

-- check playing
function TC.is_channel_playing()
    if TC.state.active_channel == nil then return false end
    local playing = ffi.new("FMOD_BOOL[1]")
    local res = fmod_lib.FMOD_Channel_IsPlaying(TC.state.active_channel, playing)
    if res ~= TC.FMOD_OK then
        -- channel invalid
        TC.state.active_channel = nil
        TC.state.active_announcement = nil
        return false
    end
    return playing[0] ~= 0
end

-- stop announce
function TC.stop_current()
    if TC.state.active_channel ~= nil then
        pcall(function()
            fmod_lib.FMOD_Channel_Stop(TC.state.active_channel)
        end)
        TC.state.active_channel = nil
        TC.state.active_announcement = nil
        TC.state.boarding_music_loop = false
    end
end

-- release sounds
function TC.release_all_sounds()
    TC.stop_current()
    for id, snd in pairs(TC.state.loaded_sounds) do
        pcall(function()
            fmod_lib.FMOD_Sound_Release(snd)
        end)
    end
    TC.state.loaded_sounds = {}
end

-- ===
-- parser tags
-- ===

-- parse filename
function TC.parse_filename(filename)
    local name_no_ext = filename:match("^(.+)%.ogg$")
    if not name_no_ext then return nil end

    local base_name = name_no_ext:match("^([^%[]+)")
    if not base_name or base_name == "" then return nil end

    -- known names
    if not TC.VALID_BASE_NAMES[base_name] then return nil end

    local tags = {}
    for tag in name_no_ext:gmatch("%[([^%]]+)%]") do
        table.insert(tags, tag)
    end

    return {
        base_name = base_name,
        tags      = tags,
        filename  = filename
    }
end

-- categorize tags
function TC.categorise_tags(tags)
    local result = { time = nil, number = nil, aircraft = nil, special = {} }
    for _, tag in ipairs(tags) do
        if TC.TIME_TAGS[tag] then
            result.time = tag
        elseif tonumber(tag) then
            result.number = tonumber(tag)
        elseif TC.AIRCRAFT_TAGS[tag] then
            result.aircraft = tag
        else
            -- valid tag
            if tag:match("^%a[%w]*$") then
                table.insert(result.special, tag)
            end
            -- invalid ignored
        end
    end
    return result
end

-- ===
-- file scanner
-- ===

-- scan icao
function TC.scan_icao_folders()
    local icaos = {}
    local ok, lfs = pcall(require, "lfs")
    if not ok then
        logMsg("TolnixCabin: WARNING - lfs (LuaFileSystem) not available, using io.popen fallback")
        -- fallback popen
        local sep = package.config:sub(1, 1)
        local cmd
        if ffi.os == "Windows" then
            cmd = 'dir /b /ad "' .. TC.ANNOUNCEMENTS_DIR .. '"'
        else
            cmd = 'ls -1d "' .. TC.ANNOUNCEMENTS_DIR .. '"/*/ 2>/dev/null'
        end
        local handle = io.popen(cmd)
        if handle then
            for line in handle:lines() do
                local name = line:match("([^/\\]+)/?$")
                if name and name ~= "." and name ~= ".." then
                    table.insert(icaos, name)
                end
            end
            handle:close()
        end
    else
        -- lfs scan
        local iter_ok, err_msg = pcall(function()
            for entry in lfs.dir(TC.ANNOUNCEMENTS_DIR) do
                if entry ~= "." and entry ~= ".." then
                    local full = TC.ANNOUNCEMENTS_DIR .. "/" .. entry
                    local attr = lfs.attributes(full)
                    if attr and attr.mode == "directory" then
                        table.insert(icaos, entry)
                    end
                end
            end
        end)
        if not iter_ok then
            logMsg("TolnixCabin: Could not scan Announcements dir - " .. tostring(err_msg))
        end
    end

    table.sort(icaos)
    return icaos
end

-- scan ogg soundpack
function TC.scan_soundpack(icao)
    local dir_path = TC.ANNOUNCEMENTS_DIR .. "/" .. icao
    local library = {}   -- [base_name] = { {parsed_entry}, ... }
    local max_num = 0    -- track highest numbered variation

    local files = {}

    -- collect ogg
    local ok, lfs = pcall(require, "lfs")
    if ok then
        pcall(function()
            for entry in lfs.dir(dir_path) do
                if entry:match("%.ogg$") then
                    table.insert(files, entry)
                end
            end
        end)
    else
        -- Fallback
        local cmd
        if ffi.os == "Windows" then
            cmd = 'dir /b "' .. dir_path .. '\\*.ogg" 2>NUL'
        else
            cmd = 'ls -1 "' .. dir_path .. '"/*.ogg 2>/dev/null'
        end
        local handle = io.popen(cmd)
        if handle then
            for line in handle:lines() do
                local name = line:match("([^/\\]+)$")
                if name then table.insert(files, name) end
            end
            handle:close()
        end
    end

    -- parse each
    for _, fname in ipairs(files) do
        local parsed = TC.parse_filename(fname)
        if parsed then
            parsed.full_path = dir_path .. "/" .. fname
            parsed.cat_tags  = TC.categorise_tags(parsed.tags)

            if not library[parsed.base_name] then
                library[parsed.base_name] = {}
            end
            table.insert(library[parsed.base_name], parsed)

            -- track max
            if parsed.cat_tags.number and parsed.cat_tags.number > max_num then
                max_num = parsed.cat_tags.number
            end
        end
    end

    return library, max_num
end

-- ===
-- sound selection
-- ===

-- select sound
function TC.select_sound(base_name, time_of_day, aircraft_type, crew_number)
    local candidates = TC.state.announcement_files[base_name]
    if not candidates or #candidates == 0 then return nil end

    -- filter aircraft
    local acf_filtered = {}
    for _, f in ipairs(candidates) do
        if f.cat_tags.aircraft == nil or f.cat_tags.aircraft == aircraft_type then
            table.insert(acf_filtered, f)
        end
    end
    if #acf_filtered == 0 then return nil end

    -- time matching
    local time_matched = {}
    local no_time      = {}
    for _, f in ipairs(acf_filtered) do
        if f.cat_tags.time == time_of_day then
            table.insert(time_matched, f)
        elseif f.cat_tags.time == nil then
            table.insert(no_time, f)
        end
    end
    local pool = #time_matched > 0 and time_matched or no_time
    if #pool == 0 then
        -- fallback candidates
        pool = acf_filtered
    end

    -- numbered vars
    local numbered   = {}  -- [num] = file_entry
    local unnumbered = {}
    for _, f in ipairs(pool) do
        if f.cat_tags.number then
            numbered[f.cat_tags.number] = f
        else
            table.insert(unnumbered, f)
        end
    end

    if next(numbered) then
        -- Try to use the per-flight crew number
        if numbered[crew_number] then
            return numbered[crew_number]
        end
        -- random crew
        local keys = {}
        for k, _ in pairs(numbered) do table.insert(keys, k) end
        return numbered[keys[math.random(#keys)]]
    end

    -- random unnumbered
    if #unnumbered > 0 then
        return unnumbered[math.random(#unnumbered)]
    end

    return nil
end

-- has sound
function TC.has_sound(base_name)
    return TC.select_sound(
        base_name,
        TC.get_time_of_day(),
        TC.state.aircraft_type,
        TC.state.flight_crew_number
    ) ~= nil
end

-- ===
-- playback
-- ===

-- load soundpack
function TC.load_soundpack(icao)
    TC.release_all_sounds()
    TC.state.current_icao = icao

    local library, max_num = TC.scan_soundpack(icao)
    TC.state.announcement_files = library
    TC.state.max_crew_variations = math.max(max_num, 1)

    -- crew number
    TC.state.flight_crew_number = math.random(1, TC.state.max_crew_variations)

    -- aircraft type
    TC.state.aircraft_type = get_aircraft_icao()

    logMsg(string.format(
        "TolnixCabin: Loaded soundpack '%s' (%d file types, crew#%d, aircraft=%s)",
        icao,
        TC.table_count(library),
        TC.state.flight_crew_number,
        TC.state.aircraft_type
    ))
end

-- toggle announce
function TC.toggle_announcement(ann_id)
    -- stop if playing
    if TC.state.active_announcement == ann_id and TC.is_channel_playing() then
        TC.stop_current()
        return
    end

    local file_entry = TC.select_sound(
        ann_id,
        TC.get_time_of_day(),
        TC.state.aircraft_type,
        TC.state.flight_crew_number
    )
    if not file_entry then return end

    -- load cached
    local snd = TC.state.loaded_sounds[file_entry.full_path]
    if snd == nil then
        -- stream large
        local use_stream = (ann_id == "BoardingMusic")
        snd = TC.load_sound(file_entry.full_path, use_stream)
        if snd == nil then return end
        TC.state.loaded_sounds[file_entry.full_path] = snd
    end

    -- prompt loop
    if ann_id == "BoardingMusic" then
        local length_sec = TC.get_sound_length_sec(snd)
        if length_sec > 0 and length_sec < TC.BOARDING_MUSIC_LOOP_THRESHOLD then
            -- show prompt
            TC.state.loop_prompt_active = true
            TC.state.loop_prompt_ann_id = ann_id
            TC.state.loop_prompt_sound = snd
            return  -- wait user
        end
    end

    -- play default
    TC.play_announcement(ann_id, snd, false)
end

-- play sound
function TC.play_announcement(ann_id, fmod_sound, loop)
    local channel = TC.play_sound(fmod_sound, loop)
    if channel then
        TC.state.active_channel = channel
        TC.state.active_announcement = ann_id
        TC.state.boarding_music_loop = loop
    end
end

-- new flight
function TC.new_flight()
    if TC.state.max_crew_variations > 0 then
        TC.state.flight_crew_number = math.random(1, TC.state.max_crew_variations)
    end
    TC.stop_current()
    logMsg("TolnixCabin: New flight - crew variation #" .. TC.state.flight_crew_number)
end

-- ===
-- utils
-- ===

-- count table
function TC.table_count(t)
    local c = 0
    for _ in pairs(t) do c = c + 1 end
    return c
end

-- ===
-- gui imgui
-- ===

-- colors
local CLR = {
    -- buttons
    btn_playing    = {0.10, 0.45, 0.10, 1.0},  -- green
    btn_available  = {0.35, 0.12, 0.12, 1.0},  -- dark red/maroon
    btn_unavail    = {0.20, 0.20, 0.20, 0.6},  -- grey, semi-transparent
    btn_hover_play = {0.15, 0.55, 0.15, 1.0},
    btn_hover_avl  = {0.45, 0.18, 0.18, 1.0},

    -- text
    text_title     = {0.80, 0.85, 1.00, 1.0},
    text_info      = {0.70, 0.75, 0.85, 1.0},
    text_category  = {0.90, 0.90, 1.00, 1.0},
    text_icao      = {0.60, 0.90, 0.60, 1.0},
    text_disabled  = {0.40, 0.40, 0.40, 1.0},

    -- info bg
    info_bg        = {0.10, 0.12, 0.22, 0.9},

    -- arrows
    nav_arrow      = {0.30, 0.60, 1.00, 1.0},

    -- sep
    separator      = {0.25, 0.35, 0.60, 1.0},
}

-- push color
local function push_color(style_var, clr)
    imgui.PushStyleColor(style_var, clr[1], clr[2], clr[3], clr[4])
end

-- build gui
function TolnixCabin_on_build(wnd, x, y)
    local win_w = imgui.GetWindowWidth()
    local win_h = imgui.GetWindowHeight()
    local cat = TC.CATEGORIES[TC.state.current_category]

    -- title
    push_color(imgui.constant.Col.Text, CLR.text_title)
    local title = TC.WINDOW_TITLE
    local title_w = imgui.CalcTextSize(title)
    imgui.SetCursorPosX((win_w - title_w) / 2)
    imgui.TextUnformatted(title)
    imgui.PopStyleColor()

    imgui.Spacing()

    -- nav row
    push_color(imgui.constant.Col.Text, CLR.nav_arrow)
    push_color(imgui.constant.Col.Button, {0.0, 0.0, 0.0, 0.0})
    push_color(imgui.constant.Col.ButtonHovered, {0.2, 0.3, 0.5, 0.5})
    push_color(imgui.constant.Col.ButtonActive, {0.2, 0.3, 0.5, 0.8})

    if imgui.Button("  <  ##nav_left", 40, 25) then
        TC.state.current_category = TC.state.current_category - 1
        if TC.state.current_category < 1 then
            TC.state.current_category = #TC.CATEGORIES
        end
    end

    imgui.SameLine()

    -- center category
    push_color(imgui.constant.Col.Text, CLR.text_category)
    local cat_text = cat.name
    local cat_text_w = imgui.CalcTextSize(cat_text)
    local nav_center_x = (win_w * 0.72 - cat_text_w) / 2 + 40
    if nav_center_x > imgui.GetCursorPosX() then
        imgui.SetCursorPosX(nav_center_x)
    end
    imgui.SetCursorPosY(imgui.GetCursorPosY() + 3)
    imgui.TextUnformatted(cat_text)
    imgui.PopStyleColor()  -- text

    imgui.SameLine()

    -- right arrow
    local arrow_right_x = win_w * 0.72 - 40
    if arrow_right_x > imgui.GetCursorPosX() then
        imgui.SetCursorPosX(arrow_right_x)
    end
    imgui.SetCursorPosY(imgui.GetCursorPosY() - 3)
    if imgui.Button("  >  ##nav_right", 40, 25) then
        TC.state.current_category = TC.state.current_category + 1
        if TC.state.current_category > #TC.CATEGORIES then
            TC.state.current_category = 1
        end
    end

    imgui.PopStyleColor(4)  -- nav colors

    -- icao select
    imgui.SameLine()
    imgui.SetCursorPosX(win_w - 175)
    imgui.SetCursorPosY(imgui.GetCursorPosY())

    imgui.PushItemWidth(160)
    if imgui.BeginCombo("##icao_select", TC.state.current_icao) then
        for i, icao in ipairs(TC.state.available_icaos) do
            local is_selected = (icao == TC.state.current_icao)
            if imgui.Selectable(icao, is_selected) then
                TC.load_soundpack(icao)
            end
        end
        imgui.EndCombo()
    end
    imgui.PopItemWidth()

    -- sep line
    push_color(imgui.constant.Col.Separator, CLR.separator)
    imgui.Separator()
    imgui.PopStyleColor()

    -- info bar
    local info_start_y = imgui.GetCursorPosY()

    -- draw bg rect
    local draw_list = imgui.GetWindowDrawList()
    local cx, cy = imgui.GetCursorScreenPos()
    local info_bar_h = 38
    imgui.ImDrawList_AddRectFilled(
        draw_list,
        cx, cy,
        cx + win_w - 16, cy + info_bar_h,
    imgui.PopStyleColor(4)  -- nav colors", "oldString": "        0xE6192030,   -- ABGR packed: ~CLR.info_bg"}, {"filePath": "/home/yoshiunix/Documents/Projects/TolnixCabin/TolnixCabin.lua", "newString": "        0xE6192030,   -- color
        4.0
    )

    imgui.SetCursorPosX(12)
    push_color(imgui.constant.Col.Text, CLR.text_info)
    imgui.TextUnformatted(string.format("  You are in %s Mode", cat.name))
    imgui.SetCursorPosX(12)
    imgui.TextUnformatted(string.format("  %s | %s", TC.get_time_of_day(), TC.format_sim_time()))
    imgui.PopStyleColor()

    -- airline label
    imgui.SetCursorPosY(info_start_y + 10)
    push_color(imgui.constant.Col.Text, CLR.text_icao)
    local loaded_text = "Loaded Airline: " .. TC.state.current_icao
    local loaded_w = imgui.CalcTextSize(loaded_text)
    imgui.SetCursorPosX(win_w - loaded_w - 20)
    imgui.TextUnformatted(loaded_text)
    imgui.PopStyleColor()

    imgui.SetCursorPosY(info_start_y + info_bar_h + 8)

    -- btns announce
    local announcements = cat.announcements
    local num_cols = 3
    local padding = 20
    local btn_spacing = 16
    local btn_w = (win_w - padding * 2 - btn_spacing * (num_cols - 1)) / num_cols
    local btn_h = 65
    local available_height = win_h - imgui.GetCursorPosY() - 10
    local num_rows = math.ceil(#announcements / num_cols)
    local total_btn_height = num_rows * btn_h + (num_rows - 1) * btn_spacing
    local vert_offset = math.max(0, (available_height - total_btn_height) / 2)

    imgui.SetCursorPosY(imgui.GetCursorPosY() + vert_offset)

    for i, ann_id in ipairs(announcements) do
        local col = ((i - 1) % num_cols)
        local row = math.floor((i - 1) / num_cols)

        if col == 0 then
            imgui.SetCursorPosX(padding)
        else
            imgui.SameLine()
            imgui.SetCursorPosX(padding + col * (btn_w + btn_spacing))
        end

        -- button state
        local is_playing = (TC.state.active_announcement == ann_id and TC.is_channel_playing())
        local has_file   = TC.has_sound(ann_id)

        local btn_clr, btn_hover_clr, btn_active_clr, txt_clr

        if is_playing then
            btn_clr        = CLR.btn_playing
            btn_hover_clr  = CLR.btn_hover_play
            btn_active_clr = {0.05, 0.35, 0.05, 1.0}
            txt_clr        = {1.0, 1.0, 1.0, 1.0}
        elseif has_file then
            btn_clr        = CLR.btn_available
            btn_hover_clr  = CLR.btn_hover_avl
            btn_active_clr = {0.50, 0.20, 0.20, 1.0}
            txt_clr        = {1.0, 1.0, 1.0, 1.0}
        else
            btn_clr        = CLR.btn_unavail
            btn_hover_clr  = CLR.btn_unavail
            btn_active_clr = CLR.btn_unavail
            txt_clr        = CLR.text_disabled
        end

        push_color(imgui.constant.Col.Button, btn_clr)
        push_color(imgui.constant.Col.ButtonHovered, btn_hover_clr)
        push_color(imgui.constant.Col.ButtonActive, btn_active_clr)
        push_color(imgui.constant.Col.Text, txt_clr)

        -- rounded border
        imgui.PushStyleVar(imgui.constant.StyleVar.FrameRounding, 6.0)

        local display = TC.DISPLAY_NAMES[ann_id] or ann_id
        local btn_label = display .. "##" .. ann_id

        if imgui.Button(btn_label, btn_w, btn_h) then
            if has_file then
                TC.toggle_announcement(ann_id)
            end
        end

        imgui.PopStyleVar()
        imgui.PopStyleColor(4)
    end

    -- loop prompt modal
    if TC.state.loop_prompt_active then
        imgui.OpenPopup("Loop Boarding Music?##loop_prompt")
    end

    if imgui.BeginPopupModal("Loop Boarding Music?##loop_prompt", true) then
        imgui.TextUnformatted("This boarding music track is short (< 5 min).")
        imgui.TextUnformatted("Would you like to loop it?")
        imgui.Spacing()

        if imgui.Button("Yes, Loop##loop_yes", 120, 30) then
            TC.state.loop_prompt_active = false
            if TC.state.loop_prompt_sound then
                TC.play_announcement(
                    TC.state.loop_prompt_ann_id,
                    TC.state.loop_prompt_sound,
                    true  -- loop
                )
            end
            imgui.CloseCurrentPopup()
        end

        imgui.SameLine()

        if imgui.Button("No, Play Once##loop_no", 120, 30) then
            TC.state.loop_prompt_active = false
            if TC.state.loop_prompt_sound then
                TC.play_announcement(
                    TC.state.loop_prompt_ann_id,
                    TC.state.loop_prompt_sound,
                    false  -- no loop
                )
            end
            imgui.CloseCurrentPopup()
        end

        imgui.SameLine()

        if imgui.Button("Cancel##loop_cancel", 80, 30) then
            TC.state.loop_prompt_active = false
            imgui.CloseCurrentPopup()
        end

        imgui.EndPopup()
    end

    -- new flight btn
    imgui.SetCursorPosX(win_w - 130)
    imgui.SetCursorPosY(win_h - 35)
    push_color(imgui.constant.Col.Button, {0.15, 0.15, 0.30, 1.0})
    push_color(imgui.constant.Col.ButtonHovered, {0.20, 0.20, 0.40, 1.0})
    push_color(imgui.constant.Col.ButtonActive, {0.25, 0.25, 0.50, 1.0})
    push_color(imgui.constant.Col.Text, {0.7, 0.7, 0.9, 1.0})
    if imgui.Button("New Flight##nf", 115, 24) then
        TC.new_flight()
    end
    imgui.PopStyleColor(4)
end

-- ===
-- periodic update
-- ===

-- frame update
function TolnixCabin_every_frame()
    if TC.state.active_channel ~= nil then
        if not TC.is_channel_playing() then
            TC.state.active_channel = nil
            TC.state.active_announcement = nil
            TC.state.boarding_music_loop = false
        end
    end
end

-- register frame callback
do_every_draw("TolnixCabin_every_frame()")

-- ===
-- window menu
-- ===

-- show window
function TC.show_window()
    if TC.state.window == nil then
        TC.state.window = float_wnd_create(
            TC.WINDOW_WIDTH,
            TC.WINDOW_HEIGHT,
            1,    -- decoration type (1 = standard)
            true  -- resizable
        )
        float_wnd_set_title(TC.state.window, TC.WINDOW_TITLE)
        float_wnd_set_imgui_builder(TC.state.window, "TolnixCabin_on_build")

        -- position window
        float_wnd_set_position(TC.state.window, 200, 800)
    end
    TC.state.window_visible = true
end

-- hide window
function TC.hide_window()
    if TC.state.window ~= nil then
        float_wnd_destroy(TC.state.window)
        TC.state.window = nil
    end
    TC.state.window_visible = false
end

-- toggle window
function TC.toggle_window()
    if TC.state.window_visible then
        TC.hide_window()
    else
        TC.show_window()
    end
end

-- flywithlua macro
add_macro("TolnixCabin: Toggle Window", "TC.toggle_window()")

-- key command
create_command(
    "FlyWithLua/TolnixCabin/toggle",
    "Toggle TolnixCabin Cabin Announcements Window",
    "TC.toggle_window()",
    "",
    ""
)

-- ===
-- init
-- ===

function TC.initialise()
    logMsg("TolnixCabin v" .. TC.VERSION .. " initialising...")

    -- seed random
    math.randomseed(os.time())

    -- init fmod
    TC.init_sound_engine()

    -- scan soundpacks
    TC.state.available_icaos = TC.scan_icao_folders()

    if #TC.state.available_icaos > 0 then
        -- load first
        TC.load_soundpack(TC.state.available_icaos[1])
        TC.state.current_icao_idx = 1
    else
        logMsg("TolnixCabin: No announcement soundpacks found in " .. TC.ANNOUNCEMENTS_DIR)
        logMsg("TolnixCabin: Create subfolders with ICAO codes (e.g. 'BAW', 'DLH') containing .ogg files")
    end

    -- read aircraft
    TC.state.aircraft_type = get_aircraft_icao()

    logMsg("TolnixCabin: Initialisation complete. Found " ..
           #TC.state.available_icaos .. " soundpack(s). Aircraft: " ..
           TC.state.aircraft_type)
end

-- run init
TC.initialise()

-- auto window
-- TC.show_window()

logMsg("loaded")
