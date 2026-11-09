/*
 * Mutation4 Director Diagnostics - logging prototype.
 * GPL-3.0-or-later. Uses the Left4DHooks API by Silvers and contributors.
 * Director reads remain unchanged; EMS HUD follows lyt_ems_hud / sorallll.
 */
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <l4d2_ems_hud>

#define VERSION "0.3.2"
#define GAMEDATA "my_mutation4_diag"
#define INVALID_DIRECTOR_FLOW -9999.0

enum Param
{
    BuildMin,
    SustainMin,
    SustainMax,
    RelaxMin,
    RelaxMax,
    FlowLimit,
    PeakThreshold,
    RelaxThreshold,
    ParamCount
};

static const char g_ParamKey[][] =
{
    "BuildUpMinInterval", "SustainPeakMinTime", "SustainPeakMaxTime",
    "RelaxMinInterval", "RelaxMaxInterval", "RelaxMaxFlowTravel",
    "IntensityThreshold", "IntensityRelaxThreshold"
};
static const char g_ParamCvar[][] =
{
    "director_build_up_min_interval", "director_sustain_peak_min_time",
    "director_sustain_peak_max_time", "director_relax_min_interval",
    "director_relax_max_interval", "director_relax_max_flow_travel",
    "director_intensity_threshold", "director_intensity_relax_threshold"
};
static const char g_StageName[][] =
{
    "BUILD_UP", "SUSTAIN_PEAK", "PEAK_FADE", "RELAX"
};
static const char g_StageRule[][] =
{
    "timer_elapsed AND max_internal_intensity >= peak_threshold",
    "timer_elapsed",
    "(director_tanks <= 0 AND max_internal_intensity < relax_threshold) OR flow_advanced > flow_limit",
    "timer_elapsed OR flow_advanced > flow_limit"
};

public Plugin myinfo =
{
    name = "Mutation4 Director Diagnostics",
    author = "OpenAI",
    description = "Director diagnostics and shared EMS HUD",
    version = VERSION,
    url = ""
};

ConVar g_Enable, g_Interval, g_Internal;
Handle g_Timer, g_LockCall, g_MaxIntensityCall;
bool g_MapReady, g_Late, g_Library, g_ProfileReady, g_ProfileAttempted, g_LogError;
bool g_WriteOK;
bool g_LockEntryValidated, g_LockEntryDetoured;
int g_ManagerRef = INVALID_ENT_REFERENCE;
int g_LastStage = -1, g_Sequence, g_StateOffset, g_TimerOffset, g_FlowOffset;
Address g_LockAddress;
int g_LockVtableByteOffset;
char g_ProfileStatus[96] = "not_initialized";
char g_ProfileFailure[96], g_ProfileDetail[256];
char g_Map[128], g_Mode[128], g_OS[32] = "unknown";
char g_SMVersion[96], g_L4DVersion[96], g_L4DCvarVersion[96];
int g_L4DNativeVersion = -1;
float g_Param[ParamCount];
bool g_ParamValid[ParamCount];

// Six shared slots: top-left status, top-right clock, stats header, three player blocks.
// Each player block owns three rows (9 survivors/page), but ALL statistics slots
// share the full canvas, line count, and blank placeholders, following lyt_ems_hud.
#define M4_HUD_ROWS 6
#define M4_STATS_SLOT_ROW_HEIGHT 0.030
#define M4_STATS_PADDING 0.012
ConVar g_HudEnable, g_HudInterval, g_HudSlotsCvar, g_HudX, g_HudY, g_HudWidth, g_HudRow, g_HudPage;
Handle g_HudTimer;
int g_HudSlots[M4_HUD_ROWS];
char g_HudLast[M4_HUD_ROWS][128];
float g_HudRetryAt;
char g_HudStatus[96] = "waiting";

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int errMax)
{
    if (GetEngineVersion() != Engine_Left4Dead2)
    {
        strcopy(error, errMax, "This plugin requires Left 4 Dead 2.");
        return APLRes_SilentFailure;
    }
    g_Late = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
    g_Enable = CreateConVar("sm_m4diag_enable", "1", "Enable periodic diagnostic logging.", FCVAR_NONE, true, 0.0, true, 1.0);
    g_Interval = CreateConVar("sm_m4diag_interval", "1.0", "Snapshot interval in game seconds, minimum 0.1.", FCVAR_NONE, true, 0.1);
    g_Internal = CreateConVar("sm_m4diag_internal", "1", "Use a validated Windows/Linux x86 internal profile; unmatched game builds keep basic logging.", FCVAR_NONE, true, 0.0, true, 1.0);
    ConVar version = CreateConVar("sm_m4diag_version", VERSION, "Diagnostic plugin version.", FCVAR_NOTIFY | FCVAR_DONTRECORD);
    version.SetString(VERSION);
    g_Enable.AddChangeHook(OnSettingsChanged);
    g_Interval.AddChangeHook(OnSettingsChanged);
    g_Internal.AddChangeHook(OnSettingsChanged);
    RegAdminCmd("sm_m4diag_status", CommandStatus, ADMFLAG_GENERIC, "Show available diagnostic modules.");
    RegAdminCmd("sm_m4diag_snapshot", CommandSnapshot, ADMFLAG_GENERIC, "Write one diagnostic snapshot.");
    RegAdminCmd("sm_m4diag_probe", CommandProbe, ADMFLAG_GENERIC, "Retry profile validation and print read-only function diagnostics.");
    for (int i; i < M4_HUD_ROWS; i++) g_HudSlots[i] = -1;
    g_HudEnable = CreateConVar("sm_m4hud_enable", "1", "Shared all-player EMS HUD. Independent of diagnostic logging.", _, true, 0.0, true, 1.0);
    g_HudInterval = CreateConVar("sm_m4hud_interval", "1.0", "HUD refresh in game seconds.", _, true, 0.2);
    g_HudSlotsCvar = CreateConVar("sm_m4hud_slots", "auto", "auto finds six empty EMS slots; or six distinct slot IDs separated by commas (0..14).");
    g_HudX = CreateConVar("sm_m4hud_x", "0.00", "Statistics panel X.", _, true, 0.0, true, 0.9);
    g_HudY = CreateConVar("sm_m4hud_y", "0.085", "Statistics panel Y.", _, true, 0.0, true, 0.65);
    g_HudWidth = CreateConVar("sm_m4hud_width", "0.60", "Statistics panel width.", _, true, 0.1, true, 1.0);
    g_HudRow = CreateConVar("sm_m4hud_row", "0.021", "Statistics row spacing.", _, true, 0.018, true, 0.040);
    g_HudPage = CreateConVar("sm_m4hud_page_seconds", "5.0", "Nine survivors per intensity page; seconds per page.", _, true, 2.0);
    g_HudEnable.AddChangeHook(OnHudSettingsChanged);
    g_HudInterval.AddChangeHook(OnHudSettingsChanged);
    g_HudSlotsCvar.AddChangeHook(OnHudSettingsChanged);
    RegConsoleCmd("sm_dhud", CommandToggleHud, "Toggle the entire shared director HUD for all players.");
    RegAdminCmd("sm_m4hud_status", CommandHudStatus, ADMFLAG_GENERIC, "Show shared HUD slot state.");
    AutoExecConfig(true, "my_mutation4_diag");
    if (g_Late)
    {
        g_MapReady = true;
        RequestFrame(InitializeMap);
    }
    RestartSampler();
    RestartHud();
}

public void OnAllPluginsLoaded()
{
    RefreshDependencies();
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "left4dhooks"))
        RefreshDependencies();
}

public void OnLibraryRemoved(const char[] name)
{
    if (StrEqual(name, "left4dhooks"))
    {
        g_Library = false;
        ResetProfile();
        strcopy(g_ProfileStatus, sizeof(g_ProfileStatus), "left4dhooks_unloaded");
    }
}

public void OnMapStart()
{
    ForgetHudSlots();
    g_HudRetryAt = 0.0;
    g_MapReady = true;
    g_ManagerRef = INVALID_ENT_REFERENCE;
    g_LastStage = -1;
    g_LogError = false;
    ResetProfile();
    RequestFrame(InitializeMap);
}

public void OnMapEnd()
{
    ForgetHudSlots();
    strcopy(g_HudStatus, sizeof(g_HudStatus), "waiting_for_map");
    g_MapReady = false;
    g_ManagerRef = INVALID_ENT_REFERENCE;
    g_LastStage = -1;
    ResetProfile();
}

public void OnPluginEnd()
{
    delete g_Timer;
    delete g_HudTimer;
    ReleaseHud();
    ResetProfile();
}

public void OnConfigsExecuted()
{
    RestartSampler();
    RestartHud();
}

public void InitializeMap(any data)
{
    if (!g_MapReady)
        return;
    GetCurrentMap(g_Map, sizeof(g_Map));
    FindManager();
    RefreshDependencies();
}

public void OnSettingsChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_Internal)
        ResetProfile();
    RestartSampler();
    RestartHud();
}

void RestartSampler()
{
    delete g_Timer;
    if (g_Enable.BoolValue)
        g_Timer = CreateTimer(g_Interval.FloatValue, OnSnapshotTimer, _, TIMER_REPEAT);
}

public Action OnSnapshotTimer(Handle timer)
{
    if (g_MapReady)
        WriteSnapshot();
    return Plugin_Continue;
}

// Observes the published state each frame; no guessed transition time is used.
public void OnGameFrame()
{
    if (!g_MapReady || !g_Enable.BoolValue)
        return;
    int entity = EntRefToEntIndex(g_ManagerRef);
    if (entity == INVALID_ENT_REFERENCE)
        return;
    int stage = GetEntProp(entity, Prop_Send, "m_tempoState");
    if (stage == g_LastStage)
        return;
    File file = OpenDiagnosticLog();
    if (file != null)
    {
        Fragment(file, "{\"schema\":1,\"event\":\"tempo_observed\",\"epoch\":%d,\"game_time\":%.3f,\"previous\":%d,\"current\":%d}\n",
            GetTime(), GetGameTime(), g_LastStage, stage);
        delete file;
    }
    g_LastStage = stage;
}

bool NativeAvailable(const char[] name)
{
    return GetFeatureStatus(FeatureType_Native, name) == FeatureStatus_Available;
}

bool DirectorAPIReady()
{
    // This native protects the first-map-frame and dependency reload cases.
    return g_Library && NativeAvailable("L4D_HasMapStarted") && L4D_HasMapStarted();
}

void ReadVersion(const char[] cvarName, char[] output, int length)
{
    ConVar cvar = FindConVar(cvarName);
    if (cvar == null)
        strcopy(output, length, "unknown");
    else
        cvar.GetString(output, length);
}

void RefreshDependencies()
{
    g_Library = LibraryExists("left4dhooks");
    ReadVersion("sourcemod_version", g_SMVersion, sizeof(g_SMVersion));
    ReadVersion("left4dhooks_version", g_L4DCvarVersion, sizeof(g_L4DCvarVersion));
    strcopy(g_L4DVersion, sizeof(g_L4DVersion), g_L4DCvarVersion);
    g_L4DNativeVersion = -1;
    if (g_Library && NativeAvailable("Left4DHooks_Version"))
    {
        g_L4DNativeVersion = Left4DHooks_Version();
        if (g_L4DNativeVersion >= 1000)
            FormatEx(g_L4DVersion, sizeof(g_L4DVersion), "%d.%03d", g_L4DNativeVersion / 1000, g_L4DNativeVersion % 1000);
    }
    strcopy(g_OS, sizeof(g_OS), "unknown");
    if (g_Library && NativeAvailable("L4D_GetServerOS"))
        strcopy(g_OS, sizeof(g_OS), L4D_GetServerOS() == 0 ? "windows" : "linux");
}

void FindManager()
{
    if (EntRefToEntIndex(g_ManagerRef) != INVALID_ENT_REFERENCE)
        return;
    g_ManagerRef = INVALID_ENT_REFERENCE;
    for (int entity = MaxClients + 1; entity < GetMaxEntities(); entity++)
    {
        if (IsValidEntity(entity) && HasEntProp(entity, Prop_Send, "m_tempoState"))
        {
            g_ManagerRef = EntIndexToEntRef(entity);
            return;
        }
    }
}

void ResetProfile()
{
    delete g_LockCall;
    delete g_MaxIntensityCall;
    g_ProfileReady = false;
    g_ProfileAttempted = false;
    g_LockAddress = Address_Null;
    g_StateOffset = 0;
    g_TimerOffset = 0;
    g_FlowOffset = 0;
    g_LockVtableByteOffset = 0;
    g_ProfileFailure[0] = '\0';
    g_ProfileDetail[0] = '\0';
    g_LockEntryValidated = false;
    g_LockEntryDetoured = false;
    strcopy(g_ProfileStatus, sizeof(g_ProfileStatus), "not_initialized");
}

int Read32(Address address, int displacement)
{
    return LoadFromAddress(address + view_as<Address>(displacement), NumberType_Int32);
}

bool Finite(float value)
{
    return (view_as<int>(value) & 0x7f800000) != 0x7f800000;
}

bool ProfileFailure(const char[] reason, const char[] detail)
{
    strcopy(g_ProfileFailure, sizeof(g_ProfileFailure), reason);
    strcopy(g_ProfileDetail, sizeof(g_ProfileDetail), detail);
    return false;
}

bool MatchBytes(Address address, int displacement, const int[] expected, int count, const char[] label)
{
    for (int i = 0; i < count; i++)
    {
        int observed = LoadFromAddress(address + view_as<Address>(displacement + i), NumberType_Int8) & 0xff;
        if (observed != expected[i])
        {
            FormatEx(g_ProfileFailure, sizeof(g_ProfileFailure), "linux_%s_mismatch", label);
            FormatEx(g_ProfileDetail, sizeof(g_ProfileDetail), "%s byte +0x%X: actual=%02X expected=%02X", label, displacement + i, observed, expected[i]);
            return false;
        }
    }
    return true;
}

bool CheckLinuxValue(const char[] label, int observed, int expected)
{
    if (observed == expected)
        return true;
    FormatEx(g_ProfileFailure, sizeof(g_ProfileFailure), "linux_%s_mismatch", label);
    FormatEx(g_ProfileDetail, sizeof(g_ProfileDetail), "%s: actual=0x%08X expected=0x%08X", label, observed, expected);
    return false;
}

bool ValidateLinuxLockEntry()
{
    // An existing plugin may replace the first five bytes with E9 rel32.
    // Verify all remaining function bytes, except the ELF-relocated string address.
    // Calls still use the original entry, so the game's existing interception runs.
    static const int lockBody[] = {
        0x55, 0x89, 0xe5, 0x53, 0x83, 0xec, 0x14, 0x8b, 0x5d, 0x08, 0x8b, 0x83,
        0x38, 0x06, 0x00, 0x00, 0x83, 0x38, 0x05, 0x74, 0x2b, 0xb8, 0x01, 0x00,
        0x00, 0x00, 0x89, 0x1c, 0x24, 0x89, 0x44, 0x24, 0x08, 0xc7, 0x44, 0x24,
        0x04, -1, -1, -1, -1, 0xe8, 0x92, 0xda, 0xff, 0xff, 0x85, 0xc0,
        0x0f, 0x95, 0xc0, 0x83, 0xc4, 0x14, 0x5b, 0x5d, 0xc3, 0x8d, 0xb4, 0x26,
        0x00, 0x00, 0x00, 0x00, 0x8b, 0x93, 0x40, 0x06, 0x00, 0x00, 0x80, 0x3a,
        0x00, 0x75, 0xca, 0x80, 0xb8, 0x11, 0x01, 0x00, 0x00, 0x00, 0x75, 0xc1,
        0x8b, 0x83, 0x3c, 0x06, 0x00, 0x00, 0x89, 0x04, 0x24, 0xe8, 0xfe, 0x6f,
        0x04, 0x00, 0x84, 0xc0, 0x75, 0xaf, 0x8b, 0x83, 0x44, 0x06, 0x00, 0x00,
        0x89, 0x04, 0x24, 0xe8, 0xac, 0x63, 0x03, 0x00, 0x0f, 0xb6, 0xc0, 0xeb,
        0xa1
    };
    g_LockEntryValidated = false;
    g_LockEntryDetoured = false;
    g_ProfileFailure[0] = '\0';
    g_ProfileDetail[0] = '\0';
    int opcode = LoadFromAddress(g_LockAddress, NumberType_Int8) & 0xff;
    int start;
    if (opcode == 0xe9)
    {
        Address destination = g_LockAddress + view_as<Address>(5 + Read32(g_LockAddress, 1));
        if (destination == g_LockAddress || (view_as<int>(destination) & 0xffff0000) == 0)
            return ProfileFailure("linux_lock_jump_target_invalid", "Entry E9 has an invalid relative destination; target not followed.");
        start = 5;
        g_LockEntryDetoured = true;
    }
    else if (opcode != lockBody[0])
    {
        FormatEx(g_ProfileDetail, sizeof(g_ProfileDetail), "lock entry actual=%02X; supported: original 55 or E9 rel32 with verified body.", opcode);
        strcopy(g_ProfileFailure, sizeof(g_ProfileFailure), "linux_lock_entry_unsupported");
        return false;
    }
    for (int i = start; i < sizeof(lockBody); i++)
    {
        if (lockBody[i] < 0)
            continue;
        int observed = LoadFromAddress(g_LockAddress + view_as<Address>(i), NumberType_Int8) & 0xff;
        if (observed != lockBody[i])
        {
            FormatEx(g_ProfileDetail, sizeof(g_ProfileDetail), "lock body byte +0x%X: actual=%02X expected=%02X; entry=%s", i, observed, lockBody[i], g_LockEntryDetoured ? "E9" : "original");
            strcopy(g_ProfileFailure, sizeof(g_ProfileFailure), "linux_lock_body_mismatch");
            return false;
        }
    }
    g_LockEntryValidated = true;
    return true;
}

bool ValidateWindowsProfile(Address update)
{
    // Instruction operand locations in the Windows x86 UpdateTempo function.
    g_StateOffset = Read32(update, 0x14);
    g_TimerOffset = Read32(update, 0x3a);
    g_FlowOffset = Read32(update, 0x10f);
    bool shape = g_StateOffset == Read32(update, 0x23)
        && g_TimerOffset == g_StateOffset + 4
        && g_FlowOffset == g_TimerOffset + 12
        && g_StateOffset > 0 && g_FlowOffset < 65536
        && Read32(update, 0x10b) == 0x86110ff3
        && Read32(update, 0x121) == 0x86110ff3
        && Read32(update, 0x211) == 0x86110ff3
        && g_FlowOffset == Read32(update, 0x125)
        && g_FlowOffset == Read32(update, 0x215);
    if (shape)
        g_LockVtableByteOffset = LoadFromAddress(update + view_as<Address>(0x0b), NumberType_Int8);
    return shape;
}

bool ValidateLinuxProfile(Address update, Address maximum, GameData data)
{
    // Independently verified from the supplied ELF32 server_srv.so, PatchVersion 2.2.4.3.
    // Symbol lookup alone does not prove the current function has the expected layout.
    static const int updateHeader[] = {
        0x55, 0x89, 0xe5, 0x57, 0x56, 0x53, 0x83, 0xec,
        0x3c, 0x8b, 0x5d, 0x08, 0x8b, 0x03, 0x89, 0x1c,
        0x24, 0xff, 0x50, 0x44, 0x84, 0xc0, 0x0f, 0x85
    };
    static const int maximumHeader[] = {
        0x55, 0x89, 0xe5, 0x83, 0xec, 0x28, 0x8d, 0x45,
        0xf4, 0xc7, 0x45, 0xf4, 0x00, 0x00, 0x00, 0x00,
        0x89, 0x04, 0x24, 0xe8
    };
    static const int maximumTail[] = {0xd9, 0x45, 0xf4, 0xc9, 0xc3};
    if (!MatchBytes(update, 0, updateHeader, sizeof(updateHeader), "update_header")
        || !MatchBytes(maximum, 0, maximumHeader, sizeof(maximumHeader), "maximum_header")
        || !MatchBytes(maximum, 24, maximumTail, sizeof(maximumTail), "maximum_tail")
        || !ValidateLinuxLockEntry())
        return false;
    Address iterator = data.GetAddress("M4_MaxIntensityIterator");
    if (iterator == Address_Null)
        return ProfileFailure("linux_maximum_iterator_missing", "M4_MaxIntensityIterator address is missing; verify paired gamedata and symbol availability.");
    Address actualTarget = maximum + view_as<Address>(24 + Read32(maximum, 20));
    if (!CheckLinuxValue("maximum_call_target", view_as<int>(actualTarget), view_as<int>(iterator)))
        return false;
    g_StateOffset = Read32(update, 0x1e);
    g_TimerOffset = Read32(update, 0x50);
    g_FlowOffset = Read32(update, 0x8d);
    bool shape = CheckLinuxValue("state_read_opcode", Read32(update, 0x1c) & 0xffff, 0x838b)
        && CheckLinuxValue("state_write_opcode", Read32(update, 0x190) & 0xffff, 0x83c7)
        && CheckLinuxValue("state_write_operand", Read32(update, 0x192), g_StateOffset)
        && CheckLinuxValue("timer_lea_opcode", Read32(update, 0x4e) & 0xffff, 0xb38d)
        && CheckLinuxValue("timer_field_relation", g_TimerOffset, g_StateOffset + 4)
        && CheckLinuxValue("flow_field_relation", g_FlowOffset, g_TimerOffset + 12)
        && CheckLinuxValue("deadline_opcode", Read32(update, 0x74) & 0xffffff, 0x832f0f)
        && CheckLinuxValue("deadline_operand", Read32(update, 0x77), g_TimerOffset + 8)
        && CheckLinuxValue("flow_read_opcode", Read32(update, 0x89), 0x83100ff3)
        && CheckLinuxValue("relax_flow_write_opcode", Read32(update, 0x36e), 0x83110ff3)
        && CheckLinuxValue("fade_flow_write_opcode", Read32(update, 0x403), 0x83110ff3)
        && CheckLinuxValue("relax_flow_operand", Read32(update, 0x372), g_FlowOffset)
        && CheckLinuxValue("fade_flow_operand", Read32(update, 0x407), g_FlowOffset)
        && CheckLinuxValue("lock_script_opcode", Read32(g_LockAddress, 0x21), 0x042444c7);
    if (shape && (g_StateOffset <= 0 || g_FlowOffset >= 65536))
        return ProfileFailure("linux_field_range_mismatch", "Derived field operands are outside the accepted object layout range.");
    if (shape)
        g_LockVtableByteOffset = LoadFromAddress(update + view_as<Address>(0x13), NumberType_Int8);
    return shape;
}

void PrepareProfile()
{
    if (!g_Internal.BoolValue)
    {
        strcopy(g_ProfileStatus, sizeof(g_ProfileStatus), "disabled_by_config");
        return;
    }
    if (g_ProfileAttempted)
        return;
    if (!DirectorAPIReady())
    {
        strcopy(g_ProfileStatus, sizeof(g_ProfileStatus), "director_api_not_ready");
        return;
    }
    g_ProfileAttempted = true;
    bool windows = StrEqual(g_OS, "windows");
    if (!windows && !StrEqual(g_OS, "linux"))
    {
        strcopy(g_ProfileStatus, sizeof(g_ProfileStatus), "server_os_unknown");
        return;
    }
    if (!NativeAvailable("L4D_GetPointer"))
    {
        strcopy(g_ProfileStatus, sizeof(g_ProfileStatus), "missing_director_pointer_native");
        return;
    }
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "gamedata/%s.txt", GAMEDATA);
    if (!FileExists(path))
    {
        strcopy(g_ProfileStatus, sizeof(g_ProfileStatus), "gamedata_missing");
        return;
    }
    GameData data = new GameData(GAMEDATA);
    if (data == null)
    {
        strcopy(g_ProfileStatus, sizeof(g_ProfileStatus), "gamedata_load_failed");
        return;
    }
    Address update = data.GetAddress("M4_UpdateTempo");
    g_LockAddress = data.GetAddress("M4_IsTempoLocked");
    Address maximum = data.GetAddress("M4_GetMaxIntensity");
    if (update == Address_Null || g_LockAddress == Address_Null || maximum == Address_Null)
    {
        strcopy(g_ProfileStatus, sizeof(g_ProfileStatus), "game_function_signature_mismatch");
        delete data;
        return;
    }
    bool shape = windows ? ValidateWindowsProfile(update) : ValidateLinuxProfile(update, maximum, data);
    if (!shape)
    {
        strcopy(g_ProfileStatus, sizeof(g_ProfileStatus), g_ProfileFailure[0] ? g_ProfileFailure : "game_function_layout_mismatch");
        delete data;
        return;
    }
    StartPrepSDKCall(SDKCall_Raw);
    bool prepared = PrepSDKCall_SetFromConf(data, SDKConf_Signature, "M4_IsTempoLocked");
    PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
    g_LockCall = EndPrepSDKCall();
    if (!prepared)
        delete g_LockCall;
    StartPrepSDKCall(SDKCall_Raw);
    prepared = PrepSDKCall_SetFromConf(data, SDKConf_Signature, "M4_GetMaxIntensity");
    PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
    g_MaxIntensityCall = EndPrepSDKCall();
    if (!prepared)
        delete g_MaxIntensityCall;
    delete data;
    if (g_LockCall == null || g_MaxIntensityCall == null)
    {
        strcopy(g_ProfileStatus, sizeof(g_ProfileStatus), "sdkcall_preparation_failed");
        return;
    }
    g_ProfileReady = true;
    if (windows)
        strcopy(g_ProfileStatus, sizeof(g_ProfileStatus), "windows_x86_structure_validated");
    else
        strcopy(g_ProfileStatus, sizeof(g_ProfileStatus), g_LockEntryDetoured ? "linux_x86_lock_jump_validated" : "linux_x86_structure_validated");
}

bool ReadInternal(int publishedStage, int &rawStage, bool &locked, bool &timerStarted,
    float &duration, float &remaining, float &baseline, float &maximum, char[] status, int statusLength)
{
    PrepareProfile();
    strcopy(status, statusLength, g_ProfileStatus);
    if (!g_ProfileReady || !DirectorAPIReady())
        return false;
    if (StrEqual(g_OS, "linux"))
    {
        // Recheck before calling a function another plugin can patch or restore.
        if (!ValidateLinuxLockEntry())
        {
            strcopy(status, statusLength, g_ProfileFailure);
            return false;
        }
        strcopy(status, statusLength, g_LockEntryDetoured ? "linux_x86_lock_jump_validated" : "linux_x86_structure_validated");
    }
    Address director = L4D_GetPointer(POINTER_DIRECTOR);
    if (director == Address_Null)
    {
        strcopy(status, statusLength, "director_pointer_unavailable");
        return false;
    }
    Address vtable = view_as<Address>(Read32(director, 0));
    if (vtable == Address_Null || view_as<Address>(Read32(vtable, g_LockVtableByteOffset)) != g_LockAddress)
    {
        strcopy(status, statusLength, "director_vtable_mismatch");
        return false;
    }
    rawStage = Read32(director, g_StateOffset);
    if (rawStage < 0 || rawStage > 3 || publishedStage < 0 || rawStage != publishedStage)
    {
        strcopy(status, statusLength, "tempo_crosscheck_pending");
        return false;
    }
    duration = view_as<float>(Read32(director, g_TimerOffset + 4));
    float deadline = view_as<float>(Read32(director, g_TimerOffset + 8));
    baseline = view_as<float>(Read32(director, g_FlowOffset));
    if (!Finite(duration) || !Finite(deadline) || !Finite(baseline))
    {
        strcopy(status, statusLength, "nonfinite_internal_value");
        return false;
    }
    timerStarted = deadline > 0.0;
    remaining = deadline - GetGameTime();
    locked = view_as<bool>(SDKCall(g_LockCall, director));
    maximum = SDKCall(g_MaxIntensityCall, director);
    if (!Finite(maximum))
    {
        strcopy(status, statusLength, "nonfinite_internal_intensity");
        return false;
    }
    return true;
}

void ReadParameters(bool ready)
{
    for (int i = 0; i < view_as<int>(ParamCount); i++)
    {
        g_ParamValid[i] = false;
        ConVar cvar = FindConVar(g_ParamCvar[i]);
        if (ready && cvar != null && NativeAvailable("L4D2_GetScriptValueFloat"))
        {
            g_Param[i] = L4D2_GetScriptValueFloat(g_ParamKey[i], cvar.FloatValue);
            g_ParamValid[i] = Finite(g_Param[i]);
        }
    }
}

bool PlayerFlow(int client, float &flow)
{
    if (!NativeAvailable("L4D_GetLastKnownArea") || !NativeAvailable("L4D2Direct_GetTerrorNavAreaFlow"))
        return false;
    Address area = view_as<Address>(L4D_GetLastKnownArea(client));
    if (area == Address_Null)
        return false;
    flow = L4D2Direct_GetTerrorNavAreaFlow(area);
    return Finite(flow) && flow != INVALID_DIRECTOR_FLOW;
}

File OpenDiagnosticLog()
{
    char path[PLATFORM_MAX_PATH], date[16];
    BuildPath(Path_SM, path, sizeof(path), "logs/my_mutation4_diag");
    if (!DirExists(path) && !CreateDirectory(path, 511))
    {
        if (!g_LogError)
        {
            LogError("Cannot create diagnostic log directory: %s", path);
            g_LogError = true;
        }
        return null;
    }
    FormatTime(date, sizeof(date), "%Y%m%d");
    BuildPath(Path_SM, path, sizeof(path), "logs/my_mutation4_diag/m4diag_%s.jsonl", date);
    File file = OpenFile(path, "a");
    if (file == null && !g_LogError)
    {
        LogError("Cannot open diagnostic log: %s", path);
        g_LogError = true;
    }
    g_WriteOK = file != null;
    return file;
}

void Fragment(File file, const char[] format, any ...)
{
    char text[4096];
    VFormat(text, sizeof(text), format, 3);
    if (!file.WriteString(text, false))
    {
        g_WriteOK = false;
        if (!g_LogError)
        {
            LogError("Writing diagnostic log failed; check available disk space and permissions.");
            g_LogError = true;
        }
    }
}

// All untrusted strings (including UTF-8 player names) are JSON escaped.
void JsonEscape(const char[] input, char[] output, int length)
{
    int target;
    for (int i = 0; input[i] != '\0'; i++)
    {
        int value = input[i] & 0xff;
        if (value < 32)
        {
            if (target + 6 >= length)
                break;
            FormatEx(output[target], length - target, "\\u%04x", value);
            target += 6;
        }
        else
        {
            int required = (value == 34 || value == 92) ? 2 : 1;
            if (target + required >= length)
                break;
            if (required == 2)
                output[target++] = '\\';
            output[target++] = input[i];
        }
    }
    output[target] = '\0';
}

void Number(File file, const char[] key, float value, bool valid)
{
    if (valid && Finite(value))
        Fragment(file, "\"%s\":%.6f", key, value);
    else
        Fragment(file, "\"%s\":null", key);
}

void Boolean(File file, const char[] key, bool value, bool valid = true)
{
    Fragment(file, "\"%s\":%s", key, valid ? (value ? "true" : "false") : "null");
}

bool WriteSnapshot(bool logging = true)
{
    FindManager();
    RefreshDependencies();
    bool ready = DirectorAPIReady();
    int manager = EntRefToEntIndex(g_ManagerRef);
    int stage = manager == INVALID_ENT_REFERENCE ? -1 : GetEntProp(manager, Prop_Send, "m_tempoState");
    bool knownStage = stage >= 0 && stage <= 3;
    int rawStage = -1;
    bool locked, started;
    float duration, remaining, baseline, maximum;
    char internalStatus[96];
    bool internal = ReadInternal(stage, rawStage, locked, started, duration, remaining, baseline, maximum, internalStatus, sizeof(internalStatus));
    ReadParameters(ready);
    int leader;
    float leaderFlow;
    bool leaderValid;
    if (ready && NativeAvailable("L4D_GetHighestFlowSurvivor"))
    {
        leader = L4D_GetHighestFlowSurvivor();
        if (leader >= 1 && leader <= MaxClients && IsClientInGame(leader))
            leaderValid = PlayerFlow(leader, leaderFlow);
    }
    bool baselineValid = internal && baseline != INVALID_DIRECTOR_FLOW;
    bool flowApplicable = knownStage && (stage == 2 || stage == 3);
    bool distanceValid = flowApplicable && baselineValid && leaderValid;
    bool flowValid = distanceValid && g_ParamValid[FlowLimit];
    float advanced = leaderFlow - baseline;
    float flowRemaining = g_Param[FlowLimit] - advanced;
    bool mobValid = ready && NativeAvailable("L4D2_CTimerHasStarted")
        && NativeAvailable("L4D2_CTimerGetRemainingTime") && NativeAvailable("L4D2_CTimerGetCountdownDuration");
    bool mobStarted;
    float mobRemaining, mobDuration;
    if (mobValid)
    {
        mobStarted = L4D2_CTimerHasStarted(L4D2CT_MobSpawnTimer);
        if (mobStarted)
        {
            mobRemaining = L4D2_CTimerGetRemainingTime(L4D2CT_MobSpawnTimer);
            mobDuration = L4D2_CTimerGetCountdownDuration(L4D2CT_MobSpawnTimer);
            mobValid = Finite(mobRemaining) && Finite(mobDuration);
        }
    }
    int counts[7], total;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client))
            continue;
        if (HasEntProp(client, Prop_Send, "m_isGhost") && GetEntProp(client, Prop_Send, "m_isGhost"))
            continue;
        int type = GetEntProp(client, Prop_Send, "m_zombieClass");
        if (type >= 1 && type <= 6)
        {
            counts[type]++;
            total++;
        }
    }
    int tanks;
    bool tanksValid = ready && NativeAvailable("L4D2_GetTankCount");
    if (tanksValid)
        tanks = L4D2_GetTankCount();
    bool conditionValid, condition;
    if (internal && !locked)
    {
        if (stage == 0)
        {
            conditionValid = started && g_ParamValid[PeakThreshold];
            condition = remaining <= 0.0 && maximum >= g_Param[PeakThreshold];
        }
        else if (stage == 1)
        {
            conditionValid = started;
            condition = remaining <= 0.0;
        }
        else if (stage == 2)
        {
            bool intensityValid = tanksValid && g_ParamValid[RelaxThreshold];
            bool intensityPassed = intensityValid && tanks <= 0 && maximum < g_Param[RelaxThreshold];
            condition = intensityPassed || (flowValid && flowRemaining < 0.0);
            conditionValid = condition || (intensityValid && flowValid);
        }
        else if (stage == 3)
        {
            condition = (started && remaining <= 0.0) || (flowValid && flowRemaining < 0.0);
            conditionValid = condition || (started && flowValid);
        }
    }
    float progress;
    int contributors;
    char progressStatus[48];
    bool progressValid = ReadProgress(ready, progress, contributors, progressStatus, sizeof(progressStatus));
    if (!logging)
    {
        RenderHud(stage, internal, locked, started, remaining, flowValid, flowRemaining,
            mobValid, mobStarted, mobRemaining, total, progressValid, progress);
        return true;
    }
    File file = OpenDiagnosticLog();
    if (file == null)
        return false;
    char time[48], map[768], mode[768];
    FormatTime(time, sizeof(time), "%Y-%m-%d %H:%M:%S %z");
    GetCurrentMap(g_Map, sizeof(g_Map));
    ReadVersion("mp_gamemode", g_Mode, sizeof(g_Mode));
    JsonEscape(g_Map, map, sizeof(map));
    JsonEscape(g_Mode, mode, sizeof(mode));
    Fragment(file, "{\"schema\":1,\"event\":\"snapshot\",\"sample\":%d,\"epoch\":%d,\"server_time\":\"%s\",\"game_time\":%.3f,\"map\":\"%s\",\"mode\":\"%s\",",
        ++g_Sequence, GetTime(), time, GetGameTime(), map, mode);
    char smVersion[576], l4dVersion[576], l4dCvarVersion[576];
    JsonEscape(g_SMVersion, smVersion, sizeof(smVersion));
    JsonEscape(g_L4DVersion, l4dVersion, sizeof(l4dVersion));
    JsonEscape(g_L4DCvarVersion, l4dCvarVersion, sizeof(l4dCvarVersion));
    Fragment(file, "\"runtime\":{\"plugin\":\"%s\",\"sourcemod\":\"%s\",\"left4dhooks\":\"%s\",\"os\":\"%s\",\"director_api_ready\":%s,\"internal_status\":\"%s\",\"lock_entry_body_checked\":%s,\"lock_entry_rel32_jump\":%s,\"left4dhooks_version_source\":\"%s\",\"left4dhooks_cvar\":\"%s\",\"left4dhooks_native_version\":",
        VERSION, smVersion, l4dVersion, g_OS, ready ? "true" : "false", internalStatus,
        g_LockEntryValidated ? "true" : "false", g_LockEntryDetoured ? "true" : "false",
        g_L4DNativeVersion >= 1000 ? "native" : "cvar_fallback", l4dCvarVersion);
    if (g_L4DNativeVersion >= 0)
        Fragment(file, "%d},", g_L4DNativeVersion);
    else
        Fragment(file, "null},");
    Fragment(file, "\"tempo\":{\"value\":%d,\"name\":\"%s\",\"source\":\"%s\",\"raw_internal\":%d},",
        stage, knownStage ? g_StageName[stage] : "UNKNOWN", manager == INVALID_ENT_REFERENCE ? "unavailable" : "m_tempoState", rawStage);
    Fragment(file, "\"director\":{");
    Boolean(file, "lock_effective", locked, internal);
    Fragment(file, ",\"stage_timer\":{");
    Boolean(file, "started", started, internal);
    Fragment(file, ",");
    Boolean(file, "active_for_stage", !locked && stage != 2, internal);
    Fragment(file, ",");
    Number(file, "duration_s", duration, internal && started);
    Fragment(file, ",");
    Number(file, "remaining_s", remaining, internal && started);
    Fragment(file, "},");
    Number(file, "max_internal_intensity", maximum, internal);
    Fragment(file, ",\"director_tanks\":");
    if (tanksValid)
        Fragment(file, "%d", tanks);
    else
        Fragment(file, "null");
    Fragment(file, ",\"flow\":{");
    Boolean(file, "applicable", flowApplicable, knownStage);
    Fragment(file, ",");
    Number(file, "baseline_raw", baseline, internal);
    Fragment(file, ",");
    Boolean(file, "baseline_valid", baselineValid, internal);
    Fragment(file, ",\"leader_userid\":%d,", leaderValid ? GetClientUserId(leader) : 0);
    Number(file, "leader_flow", leaderFlow, leaderValid);
    Fragment(file, ",");
    Number(file, "advanced_flow", advanced, distanceValid);
    Fragment(file, ",");
    Number(file, "remaining_flow", flowRemaining, flowValid);
    Fragment(file, ",");
    Boolean(file, "strictly_exceeded", flowRemaining < 0.0, flowValid);
    Fragment(file, "},\"transition\":{\"rule\":\"%s\",", knownStage ? g_StageRule[stage] : "unknown");
    Boolean(file, "condition_observed", condition, conditionValid);
    Fragment(file, "},\"parameters\":{\"source\":\"script_lookup_with_live_cvar_default\",\"values\":{");
    for (int i = 0; i < view_as<int>(ParamCount); i++)
    {
        if (i)
            Fragment(file, ",");
        Number(file, g_ParamKey[i], g_Param[i], g_ParamValid[i]);
    }
    Fragment(file, "}}},\"mob_timer\":{\"meaning\":\"natural_timer_reading_not_guaranteed_spawn\",");
    Boolean(file, "started", mobStarted, mobValid);
    Fragment(file, ",");
    Number(file, "remaining_s", mobRemaining, mobValid && mobStarted);
    Fragment(file, ",");
    Number(file, "duration_s", mobDuration, mobValid && mobStarted);
    Fragment(file, ",");
    Boolean(file, "elapsed", mobRemaining <= 0.0, mobValid && mobStarted);
    Fragment(file, "},\"specials\":{\"total\":%d,\"smoker\":%d,\"boomer\":%d,\"hunter\":%d,\"spitter\":%d,\"jockey\":%d,\"charger\":%d},\"progress\":{\"status\":\"%s\",\"contributors\":%d,",
        total, counts[1], counts[2], counts[3], counts[4], counts[5], counts[6], progressStatus, contributors);
    Number(file, "percent", progress, progressValid);
    Fragment(file, "},\"survivors\":[");
    bool comma;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || GetClientTeam(client) != 2)
            continue;
        char name[256], escaped[1536];
        GetClientName(client, name, sizeof(name));
        JsonEscape(name, escaped, sizeof(escaped));
        if (comma)
            Fragment(file, ",");
        comma = true;
        Fragment(file, "{\"userid\":%d,\"name\":\"%s\",\"bot\":%s,\"alive\":%s,\"incapacitated\":%s,\"hanging\":%s,",
            GetClientUserId(client), escaped, IsFakeClient(client) ? "true" : "false", IsPlayerAlive(client) ? "true" : "false",
            GetEntProp(client, Prop_Send, "m_isIncapacitated") ? "true" : "false", GetEntProp(client, Prop_Send, "m_isHangingFromLedge") ? "true" : "false");
        bool intensityValid = HasEntProp(client, Prop_Send, "m_clientIntensity");
        float intensity;
        if (intensityValid)
            intensity = float(GetEntProp(client, Prop_Send, "m_clientIntensity")) / 100.0;
        Number(file, "intensity", intensity, intensityValid);
        Fragment(file, ",");
        Number(file, "intensity_percent", intensity * 100.0, intensityValid);
        Fragment(file, ",\"intensity_source\":\"m_clientIntensity\",");
        float flow;
        bool validFlow = ready && PlayerFlow(client, flow);
        Number(file, "nav_flow", flow, validFlow);
        Fragment(file, "}");
    }
    Fragment(file, "]}\n");
    delete file;
    return g_WriteOK;
}

public Action CommandStatus(int client, int args)
{
    RefreshDependencies();
    PrepareProfile();
    FindManager();
    ReplyToCommand(client, "[M4Diag %s] OS=%s SM=%s Left4DHooks=%s", VERSION, g_OS, g_SMVersion, g_L4DVersion);
    ReplyToCommand(client, "[M4Diag] left4dhooks_native=%d version_cvar=%s version_source=%s", g_L4DNativeVersion, g_L4DCvarVersion, g_L4DNativeVersion >= 1000 ? "native" : "cvar_fallback");
    ReplyToCommand(client, "[M4Diag] enable=%d interval=%.3f internal=%s", g_Enable.BoolValue, g_Interval.FloatValue, g_ProfileStatus);
    if (g_ProfileDetail[0])
        ReplyToCommand(client, "[M4Diag] detail=%s", g_ProfileDetail);
    ReplyToCommand(client, "[M4Diag] offsets: state=%d timer=%d flow=%d; progress=coop_markers_average; HUD=installed", g_StateOffset, g_TimerOffset, g_FlowOffset);
    int manager = EntRefToEntIndex(g_ManagerRef);
    int published = manager == INVALID_ENT_REFERENCE ? -1 : GetEntProp(manager, Prop_Send, "m_tempoState");
    int raw = -1;
    bool locked, started;
    float duration, remaining, baseline, maximum;
    char probe[96];
    bool read = ReadInternal(published, raw, locked, started, duration, remaining, baseline, maximum, probe, sizeof(probe));
    ReplyToCommand(client, "[M4Diag] live_read=%d reason=%s published=%d internal=%d", read, probe, published, raw);
    if (StrEqual(g_OS, "linux"))
        ReplyToCommand(client, "[M4Diag] lock_entry_body_checked=%d entry_rel32_jump=%d", g_LockEntryValidated, g_LockEntryDetoured);
    if (read)
        ReplyToCommand(client, "[M4Diag] lock=%d timer_started=%d remaining=%.3f baseline=%.3f max_intensity=%.6f", locked, started, remaining, baseline, maximum);
    CommandHudStatus(client, 0);
    ReplyToCommand(client, "[M4Diag] Logs: addons/sourcemod/logs/my_mutation4_diag/m4diag_YYYYMMDD.jsonl");
    return Plugin_Handled;
}

public Action CommandSnapshot(int client, int args)
{
    if (!g_MapReady)
        ReplyToCommand(client, "[M4Diag] Map is not ready.");
    else
    {
        bool written = WriteSnapshot();
        ReplyToCommand(client, "[M4Diag] %s", written ? "Snapshot written." : "Snapshot failed: check disk space and log directory permissions.");
    }
    return Plugin_Handled;
}

void ProbeFunction(int client, const char[] name, Address address)
{
    if (address == Address_Null)
    {
        ReplyToCommand(client, "[M4Diag probe] %s=unavailable", name);
        return;
    }
    char bytes[128];
    int used;
    for (int i = 0; i < 32; i++)
    {
        int value = LoadFromAddress(address + view_as<Address>(i), NumberType_Int8) & 0xff;
        used += FormatEx(bytes[used], sizeof(bytes) - used, "%02X ", value);
    }
    ReplyToCommand(client, "[M4Diag probe] %s=0x%08X bytes=%s", name, address, bytes);
}

public Action CommandProbe(int client, int args)
{
    // Re-evaluate cached failures. This does not patch, follow, or remove any detour.
    RefreshDependencies();
    ResetProfile();
    PrepareProfile();
    CommandStatus(client, 0);
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "gamedata/%s.txt", GAMEDATA);
    if (!FileExists(path))
    {
        ReplyToCommand(client, "[M4Diag probe] gamedata file missing.");
        return Plugin_Handled;
    }
    GameData data = new GameData(GAMEDATA);
    if (data == null)
    {
        ReplyToCommand(client, "[M4Diag probe] gamedata could not be loaded.");
        return Plugin_Handled;
    }
    Address update = data.GetAddress("M4_UpdateTempo");
    Address maximum = data.GetAddress("M4_GetMaxIntensity");
    Address locked = data.GetAddress("M4_IsTempoLocked");
    Address iterator = data.GetAddress("M4_MaxIntensityIterator");
    ProbeFunction(client, "UpdateTempo", update);
    ProbeFunction(client, "GetMaximumIntensity", maximum);
    ProbeFunction(client, "ShouldLockTempo", locked);
    ReplyToCommand(client, "[M4Diag probe] MaxIntensityIterator=0x%08X", iterator);
    if (StrEqual(g_OS, "linux") && maximum != Address_Null)
    {
        int opcode = LoadFromAddress(maximum + view_as<Address>(19), NumberType_Int8) & 0xff;
        if (opcode == 0xe8)
        {
            Address target = maximum + view_as<Address>(24 + Read32(maximum, 20));
            ReplyToCommand(client, "[M4Diag probe] maximum_call=0x%08X iterator=0x%08X", target, iterator);
        }
        else
            ReplyToCommand(client, "[M4Diag probe] maximum +19 opcode=%02X; expected E8, target not interpreted.", opcode);
    }
    ReplyToCommand(client, "[M4Diag probe] Native availability: pointer=%d map_ready=%d highest_flow=%d", NativeAvailable("L4D_GetPointer"), NativeAvailable("L4D_HasMapStarted"), NativeAvailable("L4D_GetHighestFlowSurvivor"));
    delete data;
    return Plugin_Handled;
}

// Coop Markers formula: mean current nav flow of living survivors / map max,
// rounded UP. Finale suppression matches the reference. No smoothing or clamp.
bool ReadProgress(bool ready, float &percent, int &contributors, char[] status, int length)
{
    contributors = 0;
    strcopy(status, length, "api_unavailable");
    if (!ready || !NativeAvailable("L4D2Direct_GetMapMaxFlowDistance")) return false;
    if (FindEntityByClassname(-1, "trigger_finale") != -1)
    {
        strcopy(status, length, "finale_disabled");
        return false;
    }
    float mapFlow = L4D2Direct_GetMapMaxFlowDistance();
    if (!Finite(mapFlow) || mapFlow <= 0.0)
    {
        strcopy(status, length, "invalid_map_flow");
        return false;
    }
    float sum;
    for (int i = 1; i <= MaxClients; i++)
    {
        float flow;
        if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && PlayerFlow(i, flow))
        {
            sum += flow;
            contributors++;
        }
    }
    if (!contributors)
    {
        strcopy(status, length, "no_valid_alive_survivors");
        return false;
    }
    float value = sum / float(contributors) / mapFlow * 100.0;
    // RoundToCeil takes a signed cell; reject unrepresentable results, not map-specific thresholds.
    if (!Finite(value) || value >= 2147483520.0 || value <= -2147483520.0)
    {
        strcopy(status, length, "invalid_ratio");
        return false;
    }
    percent = float(RoundToCeil(value));
    strcopy(status, length, "coop_markers_average");
    return true;
}

void ForgetHudSlots()
{
    for (int i; i < M4_HUD_ROWS; i++)
    {
        g_HudSlots[i] = -1;
        g_HudLast[i][0] = '\0';
    }
}

int HudFlags(int row)
{
    return HUD_FLAG_TEXT | HUD_FLAG_NOBG | (row == 1 ? HUD_FLAG_ALIGN_RIGHT : HUD_FLAG_ALIGN_LEFT);
}

bool HudOwned(int row)
{
    int slot = g_HudSlots[row];
    if (slot < 0 || !g_HudLast[row][0]) return false;
    char current[128];
    GameRules_GetPropString("m_szScriptedHUDStringSet", current, sizeof(current), slot);
    return StrEqual(current, g_HudLast[row])
        && GameRules_GetProp("m_iScriptedHUDFlags", _, slot) == HudFlags(row);
}

void ReleaseHud()
{
    if (g_MapReady)
        for (int i; i < M4_HUD_ROWS; i++)
            if (HudOwned(i)) RemoveHUD(g_HudSlots[i]);
    ForgetHudSlots();
    // m_bChallengeModeActive is shared with maps/other HUDs. Never switch it off globally.
}

void RestartHud()
{
    delete g_HudTimer;
    if (g_HudEnable.BoolValue)
        g_HudTimer = CreateTimer(g_HudInterval.FloatValue, OnHudTimer, _, TIMER_REPEAT);
    else
    {
        ReleaseHud();
        strcopy(g_HudStatus, sizeof(g_HudStatus), "disabled");
    }
}

public void OnHudSettingsChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    ReleaseHud();
    g_HudRetryAt = 0.0;
    RestartHud();
}

bool HudSlotFree(int slot)
{
    char text[128];
    GameRules_GetPropString("m_szScriptedHUDStringSet", text, sizeof(text), slot);
    int flags = GameRules_GetProp("m_iScriptedHUDFlags", _, slot);
    return !text[0] && (flags == 0 || (flags & HUD_FLAG_NOTVISIBLE) != 0);
}

bool AcquireHud()
{
    if (g_HudSlots[0] >= 0)
    {
        for (int i; i < M4_HUD_ROWS; i++)
        {
            if (!HudOwned(i))
            {
                ReleaseHud();
                g_HudRetryAt = GetGameTime() + 15.0;
                strcopy(g_HudStatus, sizeof(g_HudStatus), "slot_overwritten_retry_15s");
                return false;
            }
        }
        return true;
    }
    if (GetGameTime() < g_HudRetryAt) return false;
    int wanted[M4_HUD_ROWS], count;
    char setting[128];
    g_HudSlotsCvar.GetString(setting, sizeof(setting));
    TrimString(setting);
    if (StrEqual(setting, "auto", false))
    {
        for (int slot; slot < MAX_SIZE_HUD && count < M4_HUD_ROWS; slot++)
            if (HudSlotFree(slot)) wanted[count++] = slot;
    }
    else
    {
        char parts[7][16];
        int number = ExplodeString(setting, ",", parts, sizeof(parts), sizeof(parts[]));
        if (number == M4_HUD_ROWS)
        {
            for (int i; i < M4_HUD_ROWS; i++)
            {
                TrimString(parts[i]);
                int slot;
                int parsed = StringToIntEx(parts[i], slot);
                if (!parsed || parsed != strlen(parts[i]) || slot < 0 || slot >= MAX_SIZE_HUD) break;
                bool duplicate;
                for (int j; j < count; j++) if (wanted[j] == slot) duplicate = true;
                if (duplicate || !HudSlotFree(slot)) break;
                wanted[count++] = slot;
            }
        }
    }
    if (count != M4_HUD_ROWS)
    {
        strcopy(g_HudStatus, sizeof(g_HudStatus), "need_six_free_slots_or_check_config");
        g_HudRetryAt = GetGameTime() + 15.0;
        return false;
    }
    for (int i; i < M4_HUD_ROWS; i++) g_HudSlots[i] = wanted[i];
    EnableHUD(); // Same EMS activation as the supplied lyt_ems_hud reference.
    strcopy(g_HudStatus, sizeof(g_HudStatus), "active");
    return true;
}

public Action OnHudTimer(Handle timer)
{
    if (g_MapReady && g_HudEnable.BoolValue && AcquireHud()) WriteSnapshot(false);
    return Plugin_Continue;
}

// Whole UTF-8 codepoints only; names cannot add HUD lines or spoof formatting.
void HudPlayerName(int client, char[] result, int length)
{
    char name[256];
    GetClientName(client, name, sizeof(name));
    int used;
    for (int i; name[i] && used < length - 1; )
    {
        int width = GetCharBytes(name[i]);
        if (width <= 0) width = 1;
        if (used + width >= length) break;
        if (width == 1 && (name[i] < 32 || name[i] == 127))
        {
            result[used++] = ' ';
            i++;
            continue;
        }
        for (int j; j < width; j++) result[used++] = name[i++];
    }
    result[used] = '\0';
}

// Compact scientific display prevents unusually large map parameters from overrunning EMS.
// Ordinary countdowns and distances round to whole display units; raw logs retain precision.
void HudNumber(float value, char[] text, int length)
{
    if (!Finite(value))
    {
        strcopy(text, length, "NaN");
        return;
    }
    int exponent;
    if (FloatAbs(value) >= 10000000.0)
    {
        while (FloatAbs(value) >= 10.0 && exponent < 39)
        {
            value /= 10.0;
            exponent++;
        }
        FormatEx(text, length, "%.2fe%d", value, exponent);
    }
    else FormatEx(text, length, "%.0f", value);
}

void RenderHud(int stage, bool internal, bool locked, bool started, float remaining,
    bool flowValid, float flowRemaining,
    bool mobValid, bool mobStarted, float mobRemaining, int specials, bool progressValid, float progress)
{
    char rows[M4_HUD_ROWS][128];
    static const char names[][] = {"BuildUp", "SustainPeak", "PeakFade", "Relax"};
    bool known = stage >= 0 && stage < 4;
    char stageTime[24] = "NaN", stageFlow[24] = "NaN", route[24] = "NaN", mob[24] = "NaN";
    if (internal && started && stage != 2) HudNumber(remaining, stageTime, sizeof(stageTime));
    if (flowValid) HudNumber(flowRemaining, stageFlow, sizeof(stageFlow));
    if (progressValid) HudNumber(progress, route, sizeof(route));
    if (mobValid && mobStarted) HudNumber(mobRemaining, mob, sizeof(mob));
    FormatEx(rows[0], sizeof(rows[]), "当前阶段：%s （%s秒/%s flow） | 锁定：%s | 路程：%s%%",
        known ? names[stage] : "NaN", stageTime, stageFlow, internal ? (locked ? "开" : "关") : "NaN", route);
    // Server local time, 24-hour clock, same wall-clock source as the diagnostic log.
    FormatTime(rows[1], sizeof(rows[]), "%Y-%m-%d %H:%M:%S");

    int clients[MAXPLAYERS + 1], total, alive;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || GetClientTeam(client) != 2) continue;
        clients[total++] = client;
        if (IsPlayerAlive(client)) alive++;
    }
    int pages = (total + 8) / 9;
    if (pages < 1) pages = 1;
    int page = RoundToFloor(GetGameTime() / g_HudPage.FloatValue) % pages;
    FormatEx(rows[2], sizeof(rows[]), "尸潮：%s秒 | 特感：%d\n强度: [%d人/%d人]", mob, specials, alive, total);
    if (pages > 1)
    {
        char pageText[32];
        FormatEx(pageText, sizeof(pageText), " (%d/%d页)", page + 1, pages);
        StrCat(rows[2], sizeof(rows[]), pageText);
    }
    int visible = total - page * 9;
    if (visible > 9) visible = 9;
    // Empty-team placeholder is a real row, keeping all canvases aligned.
    int dataRows = visible > 0 ? visible : 1;
    int totalRows = 2 + dataRows;
    // Header slot owns rows 0 and 1; reserve every player row with a space.
    for (int r = 2; r < totalRows; r++) StrCat(rows[2], sizeof(rows[]), "\n ");
    for (int block; block < 3; block++)
    {
        int owned = visible - block * 3;
        if (owned > 3) owned = 3;
        if (owned < 0) owned = 0;
        // Budget newline bytes and blank rows BEFORE dividing the remaining
        // EMS 127-byte payload among names. Reserve 16 bytes per owned line
        // for ordinal, separators, and the intensity/death suffix.
        int nameBytes = 24;
        if (owned > 0)
        {
            nameBytes = (127 - (totalRows - 1) - (totalRows - owned)) / owned - 16;
            if (nameBytes > 24) nameBytes = 24;
        }
        for (int r; r < totalRows; r++)
        {
            char line[64] = " ";
            int index = r - 2;
            if (!total && block == 0 && index == 0)
                strcopy(line, sizeof(line), "暂无生还者");
            else if (index >= block * 3 && index < (block + 1) * 3 && index < visible)
            {
                int ordinal = page * 9 + index;
                int client = clients[ordinal];
                char name[25], value[24];
                HudPlayerName(client, name, nameBytes + 1);
                if (!IsPlayerAlive(client)) strcopy(value, sizeof(value), "死亡");
                else if (HasEntProp(client, Prop_Send, "m_clientIntensity"))
                    FormatEx(value, sizeof(value), "%d%%", GetEntProp(client, Prop_Send, "m_clientIntensity"));
                else strcopy(value, sizeof(value), "NaN");
                FormatEx(line, sizeof(line), "#%d %s：%s", ordinal + 1, name, value);
            }
            if (r) StrCat(rows[3 + block], sizeof(rows[]), "\n");
            StrCat(rows[3 + block], sizeof(rows[]), line);
        }
    }
    float x = g_HudX.FloatValue, width = g_HudWidth.FloatValue, spacing = g_HudRow.FloatValue;
    if (x + width > 1.0) width = 1.0 - x;
    // lyt_ems_hud ShowRankingHUD / ShowNameColumn: distinguish font-line
    // height from slot canvas height. Every split slot gets identical geometry.
    float textHeight = spacing * float(totalRows);
    float slotRowHeight = M4_STATS_SLOT_ROW_HEIGHT;
    if (slotRowHeight < spacing + 0.009) slotRowHeight = spacing + 0.009;
    float slotHeight = slotRowHeight * float(totalRows) + M4_STATS_PADDING;
    float top = g_HudY.FloatValue;
    float correction = (slotHeight - textHeight) / 2.0;
    float slotY = top - correction;
    if (slotY < 0.0) slotY = 0.0;
    if (slotY + slotHeight > 1.0) slotY = 1.0 - slotHeight;
    for (int i; i < M4_HUD_ROWS; i++)
    {
        if (i == 0) HUDPlace(g_HudSlots[i], 0.0, 0.0, 0.78, 0.03);
        else if (i == 1) HUDPlace(g_HudSlots[i], 0.78, 0.0, 0.22, 0.03);
        else HUDPlace(g_HudSlots[i], x, slotY, width, slotHeight);
        // A blank owned row keeps stale player data out after departures/page changes.
        if (!rows[i][0]) strcopy(rows[i], sizeof(rows[]), " ");
        HUDSetLayout(g_HudSlots[i], HudFlags(i), "%s", rows[i]);
        strcopy(g_HudLast[i], sizeof(g_HudLast[]), rows[i]);
    }
}

public Action CommandHudStatus(int client, int args)
{
    ReplyToCommand(client, "[M4HUD %s] enable=%d status=%s interval=%.2f; slots=%d,%d,%d,%d,%d,%d", VERSION,
        g_HudEnable.BoolValue, g_HudStatus, g_HudInterval.FloatValue,
        g_HudSlots[0], g_HudSlots[1], g_HudSlots[2], g_HudSlots[3], g_HudSlots[4], g_HudSlots[5]);
    return Plugin_Handled;
}

// EMS scripted HUD is shared by the whole server, as in lyt_ems_hud.
// This command intentionally has no admin requirement.
public Action CommandToggleHud(int client, int args)
{
    g_HudEnable.SetBool(!g_HudEnable.BoolValue);
    if (g_HudEnable.BoolValue)
    {
        if (g_MapReady && AcquireHud()) WriteSnapshot(false);
        ReplyToCommand(client, "[M4HUD] 全服导演 HUD 已开启。若未显示，请管理员检查 HUD 栏位占用。");
    }
    else ReplyToCommand(client, "[M4HUD] 全服导演 HUD 已关闭。");
    return Plugin_Handled;
}
