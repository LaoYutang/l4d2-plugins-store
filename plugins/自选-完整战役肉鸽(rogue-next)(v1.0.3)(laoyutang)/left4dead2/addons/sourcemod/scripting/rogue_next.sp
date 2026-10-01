/**
 * rogue-next：完整战役肉鸽。唯一编译入口，子模块不可单独编译。
 * 构建：spcomp rogue_next.sp -iinclude -o../plugins/rogue_next.smx -E
 * 依赖：SourceMod 1.11、SDKHooks、Left 4 DHooks（L4D2）。
 */
#pragma semicolon 1
#pragma newdecls required
#pragma dynamic 32768

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

#include "rogue_next/rn_common.sp"
#include "rogue_next/rn_math.sp"
#include "rogue_next/rn_buff_meta.sp"
#include "rogue_next/rn_config.sp"
#include "rogue_next/rn_buff_defs.sp"
#include "rogue_next/rn_profile.sp"
#include "rogue_next/rn_notify.sp"
#include "rogue_next/rn_buff_pool.sp"
#include "rogue_next/rn_weapons.sp"
#include "rogue_next/rn_team.sp"
#include "rogue_next/rn_clock.sp"
#include "rogue_next/rn_scaling.sp"
#include "rogue_next/rn_combat_fx.sp"
#include "rogue_next/rn_combat.sp"
#include "rogue_next/rn_buff_apply.sp"
#include "rogue_next/rn_xp_source.sp"
#include "rogue_next/rn_mission.sp"
#include "rogue_next/rn_menu.sp"
#include "rogue_next/rn_admin.sp"

public Plugin myinfo =
{
    name = "rogue-next",
    author = "laoyutang",
    description = "完整战役肉鸽：团队经验、个人选卡与时间难度",
    version = RN_VERSION,
    url = ""
};

bool g_Main_Initialized;
bool g_Main_MapStarted;
bool g_Main_Late;
Handle g_Main_Scheduler;
Handle g_Main_Restart;

#include "rogue_next/rn_events.sp"

/** 限制L4D2；安全区/起点门API可选，缺少时保留有效首杀兜底。 */
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int maxlength)
{
    if (GetEngineVersion() != Engine_Left4Dead2)
    {
        strcopy(error, maxlength, "rogue-next仅支持Left 4 Dead 2。");
        return APLRes_SilentFailure;
    }
    g_Main_Late = late;
    MarkNativeAsOptional("L4D_HasAnySurvivorLeftSafeArea");
    MarkNativeAsOptional("L4D_GetCheckpointFirst");
    return APLRes_Success;
}

/** 确保旧插件没有同时运行；不能同时注册命令或重复修改战斗/换图。 */
void RN_CheckLegacy()
{
    static const char filenames[][] = {"rogue_buff.smx", "rogue_random_map.smx"};
    for (int i = 0; i < sizeof(filenames); i++)
    {
        Handle plugin = FindPluginByFile(filenames[i]);
        if (plugin != null && GetPluginStatus(plugin) == Plugin_Running)
            SetFailState("请先停用旧插件%s；rogue-next禁止与旧肉鸽/随机章节同时运行。", filenames[i]);
    }
}

/** 构造模块容器后再创建配置和钩子，所有回调都有已初始化的依赖。 */
public void OnPluginStart()
{
    RN_CheckLegacy();
    RN_Profile_Init();
    RN_FX_Init();
    RN_Scaling_Init();
    RN_XP_Init();
    RN_Config_Init();
    RN_Menu_Init();
    RN_Admin_Init();
    RN_Events_Init();
    g_Main_Initialized = true;
    RN_Common_Log("初始化完成，等待地图配置就绪。");
    g_Main_Scheduler = CreateTimer(1.0, RN_Main_Tick, _, TIMER_REPEAT);
    for (int client = 1; client <= MaxClients; client++)
        if (RN_Common_Client(client)) RN_Main_HookClient(client);
}

/** 每次换图立即使旧地图回调失效；实际战役边界等配置执行后确定。 */
public void OnMapStart()
{
    if (!g_Main_Initialized) return;
    delete g_Main_Restart;
    if (g_Run_MapEpoch == RN_MAX_INT) { SetFailState("地图代次耗尽，请重载rogue-next。"); return; }
    g_Run_MapEpoch++;
    g_Main_MapStarted = true;
    g_Run_MapReady = false;
    GetCurrentMap(g_Run_Map, sizeof(g_Run_Map));
    RN_Clock_MapStart();
}

/** 全部cfg执行后才接纳事件、绑定档案和修改实体。 */
public void OnConfigsExecuted()
{
    if (!g_Main_Initialized || g_Run_MapReady) return;
    RN_CheckLegacy();
    if (!g_Main_MapStarted) OnMapStart();
    RN_Main_Ready();
}

/** 先清地图资源，再断会话映射；成长与出门时间保留等待边界判定。 */
public void OnMapEnd()
{
    if (!g_Main_Initialized) return;
    g_Run_MapReady = false;
    delete g_Main_Restart;
    RN_Menu_Clear();
    RN_FX_Clear();
    RN_Scaling_Clear();
    RN_Weapons_Restore();
    g_Weapons_Captured = false;
    RN_Profile_EndMap();
    RN_XP_Clear();
    g_Main_MapStarted = false;
}

/** 初始化/重置时补处理当前实体；不依赖进服/出生事件再次发生。 */
void RN_Main_Bootstrap()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!RN_Common_Client(client)) continue;
        RN_Main_HookClient(client);
        if (!IsFakeClient(client) && IsClientAuthorized(client)) RN_Profile_Bind(client);
        if (g_XP_ClientSerial[client] != GetClientSerial(client) || g_XP_ClientLife[client] != g_Common_Life[client])
            RN_Main_ClientBirth(client);
        else
        {
            RN_Profile_Recalc(client);
            RN_Scaling_Birth(client);
        }
    }
    for (int entity = MaxClients + 1; entity < GetMaxEntities(); entity++)
    {
        if (!RN_Common_Zombie(entity)) continue;
        SDKUnhook(entity, SDKHook_OnTakeDamage, RN_Combat_OnDamage);
        SDKHook(entity, SDKHook_OnTakeDamage, RN_Combat_OnDamage);
        RN_XP_WitchBirth(entity);
        RN_Scaling_Birth(entity);
    }
    RN_Weapons_Refresh();
    RN_Notify_AllPending();
}

/** 完整清档由入口按顺序协调；先使异步回调失效再释放其对应资源。 */
void RN_Main_Clear(RN_RunPhase phase)
{
    if (g_Run_Epoch == RN_MAX_INT) { SetFailState("战役代次耗尽，请重载rogue-next。"); return; }
    g_Run_Epoch++;
    g_Run_Phase = phase;
    delete g_Main_Restart;
    RN_Menu_Clear();
    RN_FX_Clear();
    RN_Scaling_Clear();
    RN_Weapons_Restore();
    RN_Profile_HealLimits(false);
    RN_Profile_Clear();
    RN_XP_Clear();
    RN_Team_Clear();
    RN_Clock_Clear();
    g_Run_HasCampaign = false;
    g_Run_Transition = false;
}

/** 新战役快照初始参数；正常换图不能调用本接口重发资源。 */
void RN_Main_Begin(const char[] mission, const char[] firstMap, int chapter, bool buffered)
{
    RN_Main_Clear(RN_WAITING);
    strcopy(g_Run_Mission, sizeof(g_Run_Mission), mission);
    strcopy(g_Run_FirstMap, sizeof(g_Run_FirstMap), firstMap);
    g_Run_Chapter = chapter;
    g_Run_InitialChoices = RN_Config_Int(RN_CVAR_INITIAL_CHOICES);
    g_Run_ChoicesPerLevel = RN_Config_Int(RN_CVAR_CHOICES_PER_LEVEL);
    g_Run_InitialRolls = RN_Config_Int(RN_CVAR_INITIAL_ROLLS);
    g_Run_HasCampaign = true;
    g_Run_MapReady = true;
    RN_Clock_Ready(buffered);
    RN_Clock_Tick();
    RN_Profile_HealLimits(RN_Config_Enabled());
    RN_Main_Bootstrap();
    if (RN_Config_Int(RN_CVAR_DEBUG) != 0)
        LogMessage("[rogue-next] BEGIN run=%d map=%s mission=%s first=%s late=%d", g_Run_Epoch,
            g_Run_Map, g_Run_Mission, g_Run_FirstMap, g_Main_Late);
}

/** 在地图就绪时区分正常下一章与真正新场；mission缺失采用明确回退。 */
void RN_Main_Ready()
{
    char mission[128], first[PLATFORM_MAX_PATH];
    int chapter = -1;
    bool known = RN_Mission_Resolve(g_Run_Map, mission, sizeof(mission), first, sizeof(first), chapter);
    RN_Weapons_Capture();
    if (RN_Mission_Continue(known, mission, first, chapter))
    {
        if (known)
        {
            strcopy(g_Run_Mission, sizeof(g_Run_Mission), mission);
            strcopy(g_Run_FirstMap, sizeof(g_Run_FirstMap), first);
            g_Run_Chapter = chapter;
        }
        g_Run_Transition = false;
        g_Run_Phase = g_Clock_Start >= 0.0 ? RN_RUNNING : RN_WAITING;
        g_Run_MapReady = true;
        RN_Clock_Ready(false);
        RN_Clock_Tick();
        RN_Profile_HealLimits(RN_Config_Enabled());
        RN_Main_Bootstrap();
        return;
    }
    if (!known)
    {
        strcopy(mission, sizeof(mission), "unknown");
        strcopy(first, sizeof(first), g_Run_Map);
        LogError("[rogue-next] 无法解析%s的coop mission，建立新局并使用当前图作首图回退。", g_Run_Map);
    }
    RN_Main_Begin(mission, first, chapter, !g_Main_Late);
    g_Main_Late = false;
}

/** 手动重置从现在开始补判已出门，不接纳地图初始化前的旧出门时间。 */
void RN_ResetCurrentMap()
{
    char mission[128], first[PLATFORM_MAX_PATH];
    strcopy(mission, sizeof(mission), g_Run_Mission);
    strcopy(first, sizeof(first), g_Run_FirstMap);
    if (mission[0] == '\0' && !RN_Mission_Resolve(g_Run_Map, mission, sizeof(mission), first, sizeof(first), g_Run_Chapter))
    {
        strcopy(mission, sizeof(mission), "unknown");
        strcopy(first, sizeof(first), g_Run_Map);
    }
    RN_Clock_MapStart();
    RN_Main_Begin(mission, first, g_Run_Chapter, false);
}

/** 确认正常过关时只停地图效果，保留档案/选项/成长和计时起点。 */
void RN_Main_Transition()
{
    if (!RN_Common_ActiveRun() || g_Run_Transition) return;
    g_Run_Transition = true;
    g_Run_Phase = RN_TRANSITION;
    RN_Menu_Clear();
    RN_FX_Clear();
    for (int client = 1; client <= MaxClients; client++) RN_Profile_StopClient(client, false);
}

/** 重启回调同时核对阶段、战役和地图；管理员先换图会自动取消旧任务。 */
public Action RN_Main_OnRestart(Handle timer, DataPack pack)
{
    if (timer != g_Main_Restart) return Plugin_Stop;
    g_Main_Restart = null;
    pack.Reset();
    int epoch = pack.ReadCell(), mapEpoch = pack.ReadCell();
    char target[PLATFORM_MAX_PATH];
    pack.ReadString(target, sizeof(target));
    if (epoch != g_Run_Epoch || mapEpoch != g_Run_MapEpoch || g_Run_Phase != RN_RESTARTING ||
        !g_Run_MapReady || RN_Config_Int(RN_CVAR_ENABLE) == 0) return Plugin_Stop;
    if (!RN_Common_SafeMapName(target) || !IsMapValid(target))
    {
        LogError("[rogue-next] 重启任务目标无效：%s。", target);
        return Plugin_Stop;
    }
    ServerCommand("changelevel %s", target);
    return Plugin_Stop;
}

/** 任务失败先保存首图，再完整清理；重复mission_lost不能重建任务。 */
void RN_Main_Failed()
{
    if (!RN_Common_ActiveRun()) return;
    char target[PLATFORM_MAX_PATH];
    bool valid = RN_Mission_RestartMap(target, sizeof(target));
    RN_Main_Clear(RN_RESTARTING);
    PrintToChatAll("\x04[rogue]\x01战役失败，成长已清空，返回战役首图。");
    if (!valid || RN_Config_Int(RN_CVAR_ENABLE) == 0) return;
    DataPack pack;
    g_Main_Restart = CreateDataTimer(2.0, RN_Main_OnRestart, pack);
    pack.WriteCell(g_Run_Epoch);
    pack.WriteCell(g_Run_MapEpoch);
    pack.WriteString(target);
}

/** 成功终局只清一次；FINISHED期间不会重新建档发初始资源。 */
void RN_Main_Finished()
{
    if (!RN_Common_ActiveRun() && g_Run_Phase != RN_TRANSITION) return;
    RN_Main_Clear(RN_FINISHED);
    PrintToChatAll("\x04[rogue]\x01完整战役结束，下一场将重新开始成长。");
}

/** 配置候选已经临时装入缓存时进行无副作用验证，失败由配置模块整体回滚。 */
bool RN_OnConfigValidate()
{
    if (!g_Main_Initialized) return true;
    float maximumNeed = RN_Config_Float(RN_CVAR_XP_NEED_CAP) * RN_Config_Float(RN_CVAR_XP_SCALE_MAX);
    if (!RN_Math_Finite(maximumNeed) || maximumNeed <= 0.0 ||
        !RN_Math_Finite(RN_Config_Float(RN_CVAR_SCALING_INTERVAL_MIN)*60.0) ||
        !RN_Math_Finite(1.0 + float(g_Clock_Tier)*RN_Config_Float(RN_CVAR_DMG_PER_TIER))) return false;
    PlayerProfile profile;
    for (int i = 0; i < g_Profile_Records.Length; i++)
        if (!RN_Profile_Get(i, profile) || !RN_Profile_Validate(profile)) return false;
    for (int client = 1; client <= MaxClients; client++)
        if (RN_Common_Survivor(client) && RN_Profile_Get(g_Profile_Index[client], profile) &&
            !RN_Profile_ValidateClient(client, profile)) return false;
    if (!RN_Weapons_Validate(-1, profile)) return false;
    return true;
}

/** 通过配置验证后统一同步实体与暂停区间；初始资源仍按战役快照。 */
void RN_OnConfigApplied()
{
    if (!g_Main_Initialized) return;
    RN_Clock_UpdatePause();
    if (g_Run_MapReady && RN_Common_ActiveRun() && g_Clock_Start < 0.0)
        RN_Clock_Ready(false);
    if (RN_Config_Int(RN_CVAR_ENABLE) == 0)
    {
        delete g_Main_Restart;
        RN_Menu_Clear();
        RN_FX_Clear();
    }
    RN_Scaling_Sync();
    RN_Profile_HealLimits(RN_Config_Enabled());
    for (int client = 1; client <= MaxClients; client++) RN_Profile_Recalc(client);
    RN_Weapons_Refresh();
    RN_Clock_Tick();
}

/** 全局一秒调度只检查时间，并处理旧版每秒回血/风险与低频提醒。 */
public Action RN_Main_Tick(Handle timer)
{
    if (!g_Run_MapReady) return Plugin_Continue;
    RN_Clock_Tick();
    RN_Profile_Tick();
    RN_Combat_Tick();
    if (RN_Config_Int(RN_CVAR_REMIND_ENABLE) != 0) RN_Notify_AllPending(false);
    return Plugin_Continue;
}

/** 卸载恢复自己写入的基线并释放全部持有句柄。 */
public void OnPluginEnd()
{
    if (!g_Main_Initialized) return;
    g_Profile_Unloading = true;
    RN_Main_Clear(RN_FINISHED);
    delete g_Main_Scheduler;
    RN_Profile_Destroy();
    delete g_FX_Records;
    delete g_Scaling_Records;
    delete g_XP_WitchBirth;
    delete g_XP_WitchDeaths;
    g_Main_Initialized = false;
}

