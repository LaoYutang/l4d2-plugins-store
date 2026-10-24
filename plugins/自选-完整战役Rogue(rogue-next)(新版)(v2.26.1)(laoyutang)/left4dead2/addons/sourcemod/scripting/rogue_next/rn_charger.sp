#if defined _rn_charger_included
 #endinput
#endif
#define _rn_charger_included

/** 同一次牛攻击的双方快照；失败也缓存，不能在拍地阶段再抽一次。 */
enum struct RN_ChargerAttempt
{
    int id;
    int run;
    int map;
    int attackerSerial;
    int victimSerial;
    int attackerLife;
    int victimLife;
    int stages;
    bool blocked;
    bool pending;
    float chance;
    float until;
    float origin[3];
}

RN_ChargerAttempt g_Charger_Attempts[MAXPLAYERS + 1][MAXPLAYERS + 1];
int g_Charger_NextId;
bool g_Charger_Charging[MAXPLAYERS + 1];
float g_Charger_Until[MAXPLAYERS + 1];
int g_Charger_ResetVersion[MAXPLAYERS + 1];
char g_Charger_LogPath[PLATFORM_MAX_PATH];

/** 控制和日志读属性均先核对客户端；不存在的关系以-1表示。 */
int RN_Charger_Prop(int client, const char[] property)
{
    return RN_Common_Client(client) && HasEntProp(client, Prop_Send, property)
        ? GetEntPropEnt(client, Prop_Send, property) : -1;
}

/** 通过已公开的实体属性读取父实体，兼容两种属性名而不硬编码偏移。 */
int RN_Charger_Parent(int client)
{
    if (!RN_Common_Client(client)) return -1;
    if (HasEntProp(client, Prop_Send, "moveparent")) return GetEntPropEnt(client, Prop_Send, "moveparent");
    if (HasEntProp(client, Prop_Data, "m_hMoveParent")) return GetEntPropEnt(client, Prop_Data, "m_hMoveParent");
    return -1;
}

/** 只接受存活、非GHOST的Charger，不将其他SI的回调混入牛账本。 */
bool RN_Charger_Alive(int client)
{
    return RN_Common_Infected(client) && IsPlayerAlive(client) &&
        GetEntProp(client, Prop_Send, "m_zombieClass") == 6 && GetEntProp(client, Prop_Send, "m_isGhost") == 0;
}

/** 日志逐条写入专用文件；SDK操作前后分别记录，异常取消同样保留。 */
void RN_Charger_Log(const char[] step, int attacker, int victim, int id, float chance = -1.0)
{
    int aSerial, vSerial, aUser, vUser;
    float aPos[3], vPos[3];
    int charging = -1, move = -1, aClass = -1, ghost = -1, aAlive, vAlive;
    if (chance < 0.0 && attacker > 0 && attacker <= MaxClients && victim > 0 && victim <= MaxClients &&
        g_Charger_Attempts[attacker][victim].id == id && id != 0) chance = g_Charger_Attempts[attacker][victim].chance;
    if (RN_Common_Client(attacker))
    {
        aSerial = GetClientSerial(attacker);
        aUser = GetClientUserId(attacker);
        aClass = GetEntProp(attacker, Prop_Send, "m_zombieClass");
        ghost = GetEntProp(attacker, Prop_Send, "m_isGhost");
        aAlive = IsPlayerAlive(attacker);
        GetClientAbsOrigin(attacker, aPos);
        int ability = RN_Charger_Prop(attacker, "m_customAbility");
        if (ability > 0 && IsValidEntity(ability) && HasEntProp(ability, Prop_Send, "m_isCharging"))
            charging = GetEntProp(ability, Prop_Send, "m_isCharging");
    }
    if (RN_Common_Client(victim))
    {
        vSerial = GetClientSerial(victim);
        vUser = GetClientUserId(victim);
        vAlive = IsPlayerAlive(victim);
        GetClientAbsOrigin(victim, vPos);
        move = view_as<int>(GetEntityMoveType(victim));
    }
    LogToFileEx(g_Charger_LogPath,
        "[Rogue] charger v=%s map=%s run=%d mapEpoch=%d id=%d step=%s chance=%.1f a=%d/u%d/s%d/l%d v=%d/u%d/s%d/l%d carry=%d/%d pummel=%d/%d parent=%d charging=%d move=%d alive=%d/%d class=%d ghost=%d apos=%.1f,%.1f,%.1f vpos=%.1f,%.1f,%.1f",
        RN_VERSION, g_Run_Map, g_Run_Epoch, g_Run_MapEpoch, id, step, chance,
        attacker, aUser, aSerial, attacker > 0 && attacker <= MaxClients ? g_Common_Life[attacker] : -1,
        victim, vUser, vSerial, victim > 0 && victim <= MaxClients ? g_Common_Life[victim] : -1,
        RN_Charger_Prop(attacker, "m_carryVictim"), RN_Charger_Prop(victim, "m_carryAttacker"),
        RN_Charger_Prop(attacker, "m_pummelVictim"), RN_Charger_Prop(victim, "m_pummelAttacker"), RN_Charger_Parent(victim), charging, move,
        aAlive, vAlive, aClass, ghost,
        aPos[0], aPos[1], aPos[2], vPos[0], vPos[1], vPos[2]);
}

/** 初始化专用日志并记录实际DHooks版本，不能把仓库依赖版本当实服版本。 */
void RN_Charger_Init()
{
    BuildPath(Path_SM, g_Charger_LogPath, sizeof(g_Charger_LogPath), "logs/rogue_next_charger.log");
    char version[32] = "unknown";
    ConVar hooks = FindConVar("left4dhooks_version");
    if (hooks != null) hooks.GetString(version, sizeof(version));
    LogToFileEx(g_Charger_LogPath, "[Rogue] charger init v=%s hooks=%s endCarry=%d endPummel=%d",
        RN_VERSION, version, GetFeatureStatus(FeatureType_Native, "L4D2_Charger_EndCarry") == FeatureStatus_Available,
        GetFeatureStatus(FeatureType_Native, "L4D2_Charger_EndPummel") == FeatureStatus_Available);
}

/** 会话/生命/队伍变更取消其作为攻击者和受害者的全部旧判定与帧任务。 */
void RN_Charger_Forget(int client)
{
    if (client < 1 || client > MaxClients) return;
    if (g_Charger_ResetVersion[client] == RN_MAX_INT) { SetFailState("牛免控状态版本耗尽，请重载 Rogue。"); return; }
    g_Charger_ResetVersion[client]++;
    RN_ChargerAttempt empty;
    for (int i = 1; i <= MaxClients; i++)
    {
        g_Charger_Attempts[client][i] = empty;
        g_Charger_Attempts[i][client] = empty;
    }
    g_Charger_Charging[client] = false;
    g_Charger_Until[client] = 0.0;
}

/** 地图/回合/清档/关停先取消登记；已排队帧仍自行释放DataPack。 */
void RN_Charger_Clear()
{
    for (int i = 1; i <= MaxClients; i++) RN_Charger_Forget(i);
}

/** 缓存必须属于同一战役、地图、双方会话与生命。 */
bool RN_Charger_Identity(RN_ChargerAttempt attempt, int attacker, int victim)
{
    return attempt.id != 0 && attempt.run == g_Run_Epoch && attempt.map == g_Run_MapEpoch &&
        RN_Charger_Alive(attacker) && RN_Common_Survivor(victim) && IsPlayerAlive(victim) &&
        attempt.attackerSerial == GetClientSerial(attacker) && attempt.victimSerial == GetClientSerial(victim) &&
        attempt.attackerLife == g_Common_Life[attacker] && attempt.victimLife == g_Common_Life[victim];
}

/** 实际控制关系持续期间沿用原判定，冲锋结束后的转换窗口保留半秒。 */
bool RN_Charger_Cached(RN_ChargerAttempt attempt, int attacker, int victim)
{
    if (!RN_Charger_Identity(attempt, attacker, victim)) return false;
    int ability = RN_Charger_Prop(attacker, "m_customAbility");
    bool charging = g_Charger_Charging[attacker];
    if (ability > 0 && IsValidEntity(ability) && HasEntProp(ability, Prop_Send, "m_isCharging"))
        charging = GetEntProp(ability, Prop_Send, "m_isCharging") != 0;
    return charging || GetTickedTime() <= attempt.until ||
        GetTickedTime() <= g_Charger_Until[attacker] || RN_Charger_Prop(attacker, "m_carryVictim") == victim ||
        RN_Charger_Prop(victim, "m_carryAttacker") == attacker || RN_Charger_Prop(attacker, "m_pummelVictim") == victim ||
        RN_Charger_Prop(victim, "m_pummelAttacker") == attacker || RN_Charger_Parent(victim) == attacker;
}

/** 成功时只返回阻止并排队；原引擎调用栈内不得清理、踉跄或传送。 */
Action RN_Charger_Control(int victim, int attacker, int stage)
{
    if (!RN_Config_Enabled() || !RN_Charger_Alive(attacker) || !RN_Common_Survivor(victim) ||
        !IsPlayerAlive(victim)) return Plugin_Continue;
    RN_ChargerAttempt attempt;
    attempt = g_Charger_Attempts[attacker][victim];
    bool cached = RN_Charger_Cached(attempt, attacker, victim);
    bool frozen = RN_FX_Frozen(attacker);
    if (!cached)
    {
        if (g_Charger_NextId == RN_MAX_INT) { SetFailState("牛免控编号耗尽，请重载 Rogue。"); return Plugin_Continue; }
        RN_ChargerAttempt fresh;
        attempt = fresh;
        attempt.id = ++g_Charger_NextId;
        attempt.run = g_Run_Epoch;
        attempt.map = g_Run_MapEpoch;
        attempt.attackerSerial = GetClientSerial(attacker);
        attempt.victimSerial = GetClientSerial(victim);
        attempt.attackerLife = g_Common_Life[attacker];
        attempt.victimLife = g_Common_Life[victim];
        PlayerProfile profile;
        RN_Combat_Profile(victim, profile);
        attempt.chance = RN_Stats_Get(profile, RN_STAT_CONTROL);
        attempt.blocked = frozen || RN_Combat_Percent(attempt.chance);
        attempt.until = GetTickedTime() + 0.5;
        GetClientAbsOrigin(victim, attempt.origin);
    }
    bool firstStage = (attempt.stages & stage) == 0;
    if (frozen) attempt.blocked = true;
    attempt.stages |= stage;
    if ((attempt.blocked && firstStage) || RN_Config_Int(RN_CVAR_DEBUG) != 0)
    {
        char step[48], action[16];
        switch (stage)
        {
            case 1: strcopy(action, sizeof(action), "carry");
            case 2: strcopy(action, sizeof(action), "pummel");
            case 4: strcopy(action, sizeof(action), "fling");
            case 8: strcopy(action, sizeof(action), "stagger");
            case 16: strcopy(action, sizeof(action), "knockdown");
            case 32: strcopy(action, sizeof(action), "slam");
        }
        FormatEx(step, sizeof(step), "%s_%s_%s", action,
            frozen ? "freeze" : (cached ? "reuse" : "draw"), attempt.blocked ? "block" : "allow");
        RN_Charger_Log(step, attacker, victim, attempt.id, attempt.chance);
    }
    if (attempt.blocked && !attempt.pending)
    {
        attempt.pending = true;
        DataPack pack = new DataPack();
        pack.WriteCell(attacker);
        pack.WriteCell(victim);
        pack.WriteCell(attempt.id);
        RequestFrame(RN_Charger_OnRelease, pack);
    }
    g_Charger_Attempts[attacker][victim] = attempt;
    return attempt.blocked ? Plugin_Handled : Plugin_Continue;
}

/** 搬运开始与贴墙前搬运均使用牛专属账本。 */
public Action L4D2_OnStartCarryingVictim(int victim, int attacker)
{
    return RN_Charger_Control(victim, attacker, 1);
}

/** 拍地准备是独立入口，注意其参数顺序与搬运回调相反。 */
public Action L4D2_OnPummelVictim(int attacker, int victim)
{
    return RN_Charger_Control(victim, attacker, 2);
}

/** 新冲锋清旧判定；结束保留转换窗口，不能先清掉拍地应复用的结果。 */
public void RN_Charger_Event(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("userid"));
    if (!RN_Common_Client(attacker)) return;
    if (StrEqual(name, "charger_charge_start"))
    {
        RN_Charger_Forget(attacker);
        g_Charger_Charging[attacker] = true;
    }
    else
    {
        g_Charger_Charging[attacker] = false;
        g_Charger_Until[attacker] = GetTickedTime() + 0.5;
    }
    if (RN_Config_Int(RN_CVAR_DEBUG) != 0) RN_Charger_Log(name, attacker, 0, 0);
}

/** 不能打断另一受害者或另一控制者，包括舌头、扑倒与骑乘。 */
bool RN_Charger_Foreign(int attacker, int victim)
{
    int parent = RN_Charger_Parent(victim);
    if (parent > 0 && parent != attacker) return true;
    static const char aProps[][] = {"m_carryVictim", "m_pummelVictim"};
    static const char vProps[][] = {"m_tongueOwner", "m_pounceAttacker", "m_jockeyAttacker", "m_carryAttacker", "m_pummelAttacker"};
    for (int i = 0; i < sizeof(aProps); i++)
    {
        int target = RN_Charger_Prop(attacker, aProps[i]);
        if (target > 0 && target != victim) return true;
    }
    for (int i = 0; i < sizeof(vProps); i++)
    {
        int source = RN_Charger_Prop(victim, vProps[i]);
        if (source > 0 && (i < 3 || source != attacker)) return true;
    }
    return false;
}

/** 每个SDK调用可能产生嵌套事件，继续前重新检查任务与双方真实状态。 */
bool RN_Charger_WorkValid(RN_ChargerAttempt attempt, int attacker, int victim)
{
    return RN_Config_Enabled() && RN_Charger_Identity(attempt, attacker, victim) &&
        g_Charger_Attempts[attacker][victim].id == attempt.id && !RN_Charger_Foreign(attacker, victim);
}

/** 碰撞扫描仅忽略本次双方，墙体、其他玩家与实体仍参与。 */
public bool RN_Charger_TraceFilter(int entity, int mask, any pair)
{
    return entity != pair / (MAXPLAYERS + 1) && entity != pair % (MAXPLAYERS + 1);
}

/** 路径和落点都使用实际玩家碰撞盒检查，不能把玩家推到墙里。 */
bool RN_Charger_PathClear(const float start[3], const float end[3], int attacker, int victim)
{
    float mins[3], maxs[3];
    GetClientMins(victim, mins);
    GetClientMaxs(victim, maxs);
    Handle trace = TR_TraceHullFilterEx(start, end, mins, maxs, MASK_PLAYERSOLID,
        RN_Charger_TraceFilter, attacker * (MAXPLAYERS + 1) + victim);
    bool clear = !TR_StartSolid(trace) && !TR_AllSolid(trace) && TR_GetFraction(trace) == 1.0;
    delete trace;
    return clear;
}

/** 按双方实际碰撞盒分离，避免径向距离足够但对角包围盒仍重叠。 */
bool RN_Charger_Separated(const float position[3], int attacker, int victim)
{
    float origin[3], aMin[3], aMax[3], vMin[3], vMax[3];
    GetClientAbsOrigin(attacker, origin);
    GetClientMins(attacker, aMin);
    GetClientMaxs(attacker, aMax);
    GetClientMins(victim, vMin);
    GetClientMaxs(victim, vMax);
    for (int i = 0; i < 3; i++)
        if (position[i] + vMax[i] + 4.0 <= origin[i] + aMin[i] ||
            position[i] + vMin[i] >= origin[i] + aMax[i] + 4.0) return true;
    return false;
}

/** 优先当前位置，再用动作前位置和周边八方向；路径和落点均需通过。 */
bool RN_Charger_FindSpace(RN_ChargerAttempt attempt, int attacker, int victim, float result[3])
{
    float current[3], candidate[3];
    GetClientAbsOrigin(victim, current);
    static const float offsets[][2] = {{0.0,0.0}, {1.0,0.0}, {-1.0,0.0}, {0.0,1.0}, {0.0,-1.0},
        {0.7071,0.7071}, {0.7071,-0.7071}, {-0.7071,0.7071}, {-0.7071,-0.7071}};
    for (int i = -1; i < sizeof(offsets); i++)
    {
        if (i == -1) candidate = current;
        else if (i == 0) candidate = attempt.origin;
        else
        {
            candidate = current;
            candidate[0] += offsets[i][0] * 64.0;
            candidate[1] += offsets[i][1] * 64.0;
        }
        if (!RN_Charger_Separated(candidate, attacker, victim) || !RN_Charger_PathClear(current, candidate, attacker, victim) ||
            !RN_Charger_PathClear(candidate, candidate, attacker, victim)) continue;
        result = candidate;
        return true;
    }
    return false;
}

/** 仅解除本次双方完整关系；单向残留不调用依赖完整关系的引擎方法。 */
bool RN_Charger_EndPair(RN_ChargerAttempt attempt, int attacker, int victim)
{
    bool pummel = RN_Charger_Prop(attacker, "m_pummelVictim") == victim && RN_Charger_Prop(victim, "m_pummelAttacker") == attacker;
    bool carry = RN_Charger_Prop(attacker, "m_carryVictim") == victim && RN_Charger_Prop(victim, "m_carryAttacker") == attacker;
    if (pummel || carry)
    {
        char api[40];
        strcopy(api, sizeof(api), pummel ? "L4D2_Charger_EndPummel" : "L4D2_Charger_EndCarry");
        if (GetFeatureStatus(FeatureType_Native, api) != FeatureStatus_Available)
        {
            RN_Charger_Log("missing_end_api", attacker, victim, attempt.id);
            return false;
        }
        RN_Charger_Log(pummel ? "before_end_pummel" : "before_end_carry", attacker, victim, attempt.id);
        if (pummel) L4D2_Charger_EndPummel(victim, attacker);
        else L4D2_Charger_EndCarry(victim, attacker);
        RN_Charger_Log(pummel ? "after_end_pummel" : "after_end_carry", attacker, victim, attempt.id);
        if (!RN_Charger_WorkValid(attempt, attacker, victim)) return false;
    }
    RN_Charger_Log("before_unlink", attacker, victim, attempt.id);
    static const char aProps[][] = {"m_carryVictim", "m_pummelVictim"};
    static const char vProps[][] = {"m_carryAttacker", "m_pummelAttacker"};
    for (int i = 0; i < sizeof(aProps); i++)
    {
        if (RN_Charger_Prop(attacker, aProps[i]) == victim) SetEntPropEnt(attacker, Prop_Send, aProps[i], -1);
        if (RN_Charger_Prop(victim, vProps[i]) == attacker) SetEntPropEnt(victim, Prop_Send, vProps[i], -1);
    }
    RN_Charger_Log("after_unlink", attacker, victim, attempt.id);
    if (RN_Charger_Parent(victim) == attacker)
    {
        RN_Charger_Log("before_clear_parent", attacker, victim, attempt.id);
        bool cleared = AcceptEntityInput(victim, "ClearParent");
        RN_Charger_Log(cleared ? "after_clear_parent" : "clear_parent_rejected", attacker, victim, attempt.id);
        if (!cleared || !RN_Charger_WorkValid(attempt, attacker, victim) || RN_Charger_Parent(victim) == attacker) return false;
    }
    return true;
}

/** 帧任务先释放句柄，再校验所有代次；每个SDK操作前后均写崩溃定位标记。 */
public void RN_Charger_OnRelease(DataPack pack)
{
    pack.Reset();
    int attacker = pack.ReadCell(), victim = pack.ReadCell(), id = pack.ReadCell();
    delete pack;
    RN_ChargerAttempt attempt;
    attempt = g_Charger_Attempts[attacker][victim];
    char reason[64];
    if (attempt.id != id) strcopy(reason, sizeof(reason), "cancel_replaced_or_cleared");
    else if (!attempt.pending || !attempt.blocked) strcopy(reason, sizeof(reason), "cancel_not_pending_or_not_blocked");
    else if (!RN_Config_Enabled()) strcopy(reason, sizeof(reason), "cancel_disabled_or_inactive");
    else if (attempt.run != g_Run_Epoch || attempt.map != g_Run_MapEpoch) strcopy(reason, sizeof(reason), "cancel_run_or_map");
    else if (!RN_Charger_Identity(attempt, attacker, victim)) strcopy(reason, sizeof(reason), "cancel_identity_life_dead_team_or_ghost");
    else if (RN_Charger_Foreign(attacker, victim)) strcopy(reason, sizeof(reason), "cancel_foreign_relationship");
    if (reason[0] != '\0')
    {
        RN_Charger_Log(reason, attacker, victim, id);
        if (attempt.id == id) g_Charger_Attempts[attacker][victim].pending = false;
        return;
    }
    g_Charger_Attempts[attacker][victim].pending = false;
    RN_Charger_Log("release_begin", attacker, victim, id, attempt.chance);
    float destination[3];
    bool space = RN_Charger_FindSpace(attempt, attacker, victim, destination);
    RN_Charger_Log(space ? "space_found" : "space_unavailable", attacker, victim, id);
    if (space) LogToFileEx(g_Charger_LogPath, "[Rogue] charger id=%d step=escape_target xyz=%.3f,%.3f,%.3f",
        id, destination[0], destination[1], destination[2]);
    if (!RN_Charger_EndPair(attempt, attacker, victim) || !RN_Charger_WorkValid(attempt, attacker, victim))
    {
        RN_Charger_Log("cancel_after_end_pair", attacker, victim, id);
        return;
    }
    RN_Charger_Log("before_stagger", attacker, victim, id);
    L4D_StaggerPlayer(attacker, victim, NULL_VECTOR);
    RN_Charger_Log("after_stagger", attacker, victim, id);
    if (!RN_Charger_WorkValid(attempt, attacker, victim))
    {
        RN_Charger_Log("cancel_after_stagger", attacker, victim, id);
        return;
    }
    if (GetEntityMoveType(victim) == MOVETYPE_NONE) SetEntityMoveType(victim, MOVETYPE_WALK);
    if (space && RN_Charger_Separated(destination, attacker, victim) && RN_Charger_PathClear(destination, destination, attacker, victim))
    {
        float position[3];
        GetClientAbsOrigin(victim, position);
        bool changed;
        for (int i = 0; i < 3; i++) if (FloatAbs(position[i] - destination[i]) > 0.001) changed = true;
        if (changed)
        {
            RN_Charger_Log("before_teleport", attacker, victim, id);
            float velocity[3];
            TeleportEntity(victim, destination, NULL_VECTOR, velocity);
            RN_Charger_Log("after_teleport", attacker, victim, id);
        }
        else RN_Charger_Log("position_kept", attacker, victim, id);
    }
    else RN_Charger_Log("no_safe_teleport", attacker, victim, id);
    bool complete = RN_Charger_WorkValid(attempt, attacker, victim) && !RN_Common_Controlled(victim) && RN_Charger_Parent(victim) != attacker;
    if (complete)
    {
        float position[3];
        GetClientAbsOrigin(victim, position);
        complete = RN_Charger_Separated(position, attacker, victim) && RN_Charger_PathClear(position, position, attacker, victim);
    }
    RN_Charger_Log(complete ? "release_done" : "release_residual_or_changed", attacker, victim, id);
}
