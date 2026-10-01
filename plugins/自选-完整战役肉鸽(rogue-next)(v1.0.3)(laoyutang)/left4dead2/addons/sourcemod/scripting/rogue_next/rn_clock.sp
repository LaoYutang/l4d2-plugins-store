#if defined _rn_clock_included
 #endinput
#endif
#define _rn_clock_included

float g_Clock_Start = -1.0;
float g_Clock_Paused;
float g_Clock_PauseStart = -1.0;
int g_Clock_Tier;
float g_Clock_PendingDeparture = -1.0;
float g_Clock_PendingPaused;
float g_Clock_PendingPauseStart = -1.0;

/** 暂停条件使用并集；加载/旁观真人仍算在线，断线客户端由exclude排除。 */
bool RN_Clock_ShouldPause(int exclude = 0)
{
    return RN_Config_Int(RN_CVAR_ENABLE) == 0 || RN_Config_Int(RN_CVAR_SCALING_ENABLE) == 0 ||
        (RN_Config_Int(RN_CVAR_SCALING_IGNORE_EMPTY) != 0 && !RN_Common_HasHuman(exclude));
}

/** 更新尚未就绪地图的出门缓冲，防止等待配置期间错误计入空服时间。 */
void RN_Clock_UpdatePending(int exclude = 0)
{
    if (g_Clock_PendingDeparture < 0.0) return;
    float now = GetTickedTime();
    bool pause = RN_Clock_ShouldPause(exclude);
    if (pause && g_Clock_PendingPauseStart < 0.0) g_Clock_PendingPauseStart = now;
    else if (!pause && g_Clock_PendingPauseStart >= 0.0)
    {
        g_Clock_PendingPaused += now - g_Clock_PendingPauseStart;
        g_Clock_PendingPauseStart = -1.0;
    }
}

/** 在线状态/配置修改立即更新并集暂停区间，避免定时器相位误差。 */
void RN_Clock_UpdatePause(int exclude = 0)
{
    RN_Clock_UpdatePending(exclude);
    if (g_Clock_Start < 0.0) return;
    float now = GetTickedTime();
    bool pause = RN_Clock_ShouldPause(exclude);
    if (pause && g_Clock_PauseStart < 0.0) g_Clock_PauseStart = now;
    else if (!pause && g_Clock_PauseStart >= 0.0)
    {
        g_Clock_Paused += now - g_Clock_PauseStart;
        g_Clock_PauseStart = -1.0;
    }
}

/** 当前有效秒数由单调时间戳计算，调度器从不累计分钟。 */
float RN_Clock_Elapsed()
{
    return RN_Math_Elapsed(GetTickedTime(), g_Clock_Start, g_Clock_Paused, g_Clock_PauseStart);
}

/** 首次出门才开始；地图未就绪时保存首次事件和该段暂停时间。 */
void RN_Clock_Departure()
{
    if (!g_Run_MapReady)
    {
        if (g_Clock_PendingDeparture < 0.0) g_Clock_PendingDeparture = GetTickedTime();
        RN_Clock_UpdatePending();
        return;
    }
    if (!RN_Common_ActiveRun() || g_Clock_Start >= 0.0) return;
    g_Clock_Start = GetTickedTime();
    g_Clock_Paused = 0.0;
    g_Clock_PauseStart = -1.0;
    g_Run_Phase = RN_RUNNING;
    RN_Clock_UpdatePause();
    if (RN_Config_Int(RN_CVAR_ENABLE) != 0) RN_Notify_Started();
}

/** 原生接口可用时补判是否已出门；不追溯热加载前时间。 */
bool RN_Clock_AlreadyDeparted()
{
    return GetFeatureStatus(FeatureType_Native, "L4D_HasAnySurvivorLeftSafeArea") == FeatureStatus_Available &&
        L4D_HasAnySurvivorLeftSafeArea();
}

/** 新战役/当前图重置开始后调用；正常跨图不重新设起点。 */
void RN_Clock_Ready(bool acceptBuffered)
{
    if (g_Clock_Start >= 0.0) { RN_Clock_UpdatePause(); return; }
    if (acceptBuffered && g_Clock_PendingDeparture >= 0.0)
    {
        RN_Clock_UpdatePending();
        g_Clock_Start = g_Clock_PendingDeparture;
        g_Clock_Paused = g_Clock_PendingPaused;
        g_Clock_PauseStart = g_Clock_PendingPauseStart;
        g_Run_Phase = RN_RUNNING;
        RN_Clock_UpdatePause();
        if (RN_Config_Int(RN_CVAR_ENABLE) != 0) RN_Notify_Started();
    }
    else if (RN_Config_Int(RN_CVAR_SCALING_WAIT_LEAVESAFE) == 0 || RN_Clock_AlreadyDeparted())
        RN_Clock_Departure();
    g_Clock_PendingDeparture = -1.0;
    g_Clock_PendingPaused = 0.0;
    g_Clock_PendingPauseStart = -1.0;
}

/** 只从有效时间计算档位；公告在档位真正变化后触发一次。 */
void RN_Clock_Tick()
{
    if (!RN_Common_ActiveRun()) return;
    RN_Clock_UpdatePause();
    float elapsed = RN_Clock_Elapsed();
    int tier = RN_Clock_CurrentTier();
    if (tier == g_Clock_Tier) return;
    g_Clock_Tier = tier;
    if (RN_Config_Int(RN_CVAR_SCALING_ANNOUNCE) != 0 && RN_Config_Int(RN_CVAR_ENABLE) != 0 &&
        RN_Config_Int(RN_CVAR_SCALING_ENABLE) != 0) RN_Notify_Tier(tier, elapsed);
}

/** 地图开始时仅清缓冲，保留同一战役的实际计时。 */
void RN_Clock_MapStart()
{
    g_Clock_PendingDeparture = -1.0;
    g_Clock_PendingPaused = 0.0;
    g_Clock_PendingPauseStart = -1.0;
}

/** 完整清档重置时钟；地图初始化缓冲由入口决定是否接纳。 */
void RN_Clock_Clear()
{
    g_Clock_Start = -1.0;
    g_Clock_Paused = 0.0;
    g_Clock_PauseStart = -1.0;
    g_Clock_Tier = 0;
}

/** 出生/伤害使用即时档位，秒级调度的公告相位不能推迟实际难度。 */
int RN_Clock_CurrentTier()
{
    return RN_Math_Tier(RN_Clock_Elapsed(), RN_Config_Float(RN_CVAR_SCALING_INTERVAL_MIN) * 60.0,
        RN_Config_Int(RN_CVAR_SCALING_MAX_TIER));
}

