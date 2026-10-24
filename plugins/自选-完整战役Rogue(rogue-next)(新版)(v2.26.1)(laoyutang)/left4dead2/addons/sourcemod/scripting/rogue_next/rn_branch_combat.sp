#if defined _rn_branch_combat_included
 #endinput
#endif
#define _rn_branch_combat_included

/** 动作蓄势只属于当前生命和地图；档案中的转职身份另行保留。 */
enum struct RN_BranchMotion
{
    int serial;
    int life;
    int run;
    int map;
    int version;
    float sampled;
    float progress;
    float invalidSince;
    bool valid;
}
RN_BranchMotion g_Branch_Motion[MAXPLAYERS + 1];
bool g_Branch_ConfigEnabled;

/** 线性成长采用秒数，避免依赖服务器tickrate；达到时长后封顶。 */
float RN_Branch_Linear(float elapsed, float duration, float maximum)
{
    if (elapsed <= 0.0 || duration <= 0.0) return 0.0;
    return elapsed >= duration ? maximum : elapsed / duration * maximum;
}

/** 一次动作采样将有效时段累计；宽限中暂停，连续无效超过半秒才清零。 */
void RN_Branch_MotionSample(int client, bool valid, float now, int version)
{
    RN_BranchMotion state;
    state = g_Branch_Motion[client];
    if (state.serial != GetClientSerial(client) || state.life != g_Common_Life[client]
        || state.run != g_Run_Epoch || state.map != g_Run_MapEpoch || state.version != version)
    {
        RN_BranchMotion empty;
        state = empty;
        state.serial = GetClientSerial(client);
        state.life = g_Common_Life[client];
        state.run = g_Run_Epoch;
        state.map = g_Run_MapEpoch;
        state.version = version;
        state.sampled = now;
        state.invalidSince = -1.0;
    }
    float interval = now - state.sampled;
    if (interval < 0.0) interval = 0.0;
    if (state.valid)
    {
        state.progress += interval;
        if (state.progress > 5.0) state.progress = 5.0;
    }
    else if (state.invalidSince >= 0.0 && now - state.invalidSince > 0.5)
        state.progress = 0.0;
    if (!valid && state.valid) state.invalidSince = now;
    if (valid) state.invalidSince = -1.0;
    else if (state.invalidSince < 0.0) state.invalidSince = now;
    state.sampled = now;
    state.valid = valid;
    g_Branch_Motion[client] = state;
}

/** 总血量读取有效药丸虚血；超过正常上限不产生负增伤。 */
float RN_Branch_DancerFactor(float health, float maximum)
{
    if (maximum <= 0.0 || health >= maximum) return 1.0;
    float ratio = health / maximum;
    return ratio <= 0.1 ? 2.0 : 1.0 + (1.0 - ratio) / 0.9;
}

/** 源增益在新事件捕获一次；复制、传火和延迟伤害继承该快照。 */
float RN_Branch_SourceFactor(int attacker)
{
    int branch = RN_Branch_Get(attacker);
    float factor = RN_BranchKnight_HolyFactor(attacker);
    if (branch == RN_BRANCH_DANCER && IsPlayerAlive(attacker))
    {
        float health = float(GetEntProp(attacker, Prop_Data, "m_iHealth"))
            + RN_Knight_Temporary(attacker, GetGameTime());
        factor *= RN_Branch_DancerFactor(health, float(GetEntProp(attacker, Prop_Data, "m_iMaxHealth")));
    }
    return factor;
}

/** 夺命针对本次实际受伤目标；不能把首目标满血资格传播给整条电链。 */
float RN_Branch_TargetFactor(int attacker, int victim, int branchSnapshot = -1)
{
    int branch = branchSnapshot >= RN_BRANCH_NONE ? branchSnapshot : RN_Branch_Get(attacker);
    if (!RN_Config_Enabled() || RN_Config_Int(RN_CVAR_PROFESSION_ENABLE) == 0
        || branch != RN_BRANCH_DEATH || !RN_Burn_Living(victim)) return 1.0;
    int maximum = GetEntProp(victim, Prop_Data, "m_iMaxHealth");
    return maximum > 0 && GetEntProp(victim, Prop_Data, "m_iHealth") >= maximum ? 2.0 : 1.0;
}

/** 站定和移动蓄势读取同一状态；换身份后的旧秒数不提供伤害。 */
float RN_Branch_MotionFactor(int client)
{
    RN_BranchMotion state;
    state = g_Branch_Motion[client];
    if (state.serial != GetClientSerial(client) || state.life != g_Common_Life[client]
        || state.run != g_Run_Epoch || state.map != g_Run_MapEpoch) return 1.0;
    return 1.0 + RN_Branch_Linear(state.progress, 5.0, 1.0);
}

/** 单一临时状态清理入口不改持久分支身份，也不发放任何奖励。 */
void RN_Branch_ResetClient(int client)
{
    if (client < 1 || client > MaxClients) return;
    RN_BranchMotion empty;
    g_Branch_Motion[client] = empty;
    RN_BranchSoldier_ResetClient(client);
    RN_Sword_BranchReset(client);
    RN_BranchKnight_Forget(client);
}

/** 地图结束、清档或停用使所有短期分支状态失效。 */
void RN_Branch_Clear()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        RN_BranchMotion empty;
        g_Branch_Motion[client] = empty;
    }
    RN_BranchSoldier_Clear();
    RN_Sword_BranchClear();
    RN_BranchKnight_Clear();
}

/** 职业重新启用时建立蓄势起点，不能延迟到第一刀才开始计时。 */
void RN_Branch_ConfigApplied()
{
    bool enabled = RN_Config_Int(RN_CVAR_ENABLE) != 0 && RN_Config_Int(RN_CVAR_PROFESSION_ENABLE) != 0;
    if (!enabled) RN_Branch_Clear();
    else if (!g_Branch_ConfigEnabled)
        for (int client = 1; client <= MaxClients; client++) RN_Branch_ResetClient(client);
    g_Branch_ConfigEnabled = enabled;
}

/** 合格攻击的分支源倍率供直击与派生元素共用；受控榴弹使用发射快照。 */
float RN_Branch_AttackFactor(int attacker, int inflictor, int weapon, int type, bool derived = false)
{
    float source = RN_Grenade_SourceFactor(inflictor);
    if (source > 0.0) return source * (derived ? RN_Grenade_DerivedFactor(inflictor) : 1.0);
    float factor = RN_Branch_SourceFactor(attacker);
    int gun = RN_Profession_GunSource(attacker, inflictor, weapon, type);
    int index = RN_Weapons_Index(gun);
    if (index >= 0) factor *= RN_BranchSoldier_Factor(attacker, gun);
    int branch = RN_Branch_Get(attacker);
    if ((branch == RN_BRANCH_HAWKEYE || branch == RN_BRANCH_RANGER) && index >= 12 && index <= 15)
        factor *= RN_Branch_MotionFactor(attacker);
    return factor;
}

/** 目标满血倍率只在本次实际目标结算，不在源攻击倍率中传播给其他目标。 */
float RN_Branch_DirectFactor(int victim, int attacker, int inflictor, int weapon, int type)
{
    return RN_Branch_AttackFactor(attacker, inflictor, weapon, type)
        * RN_Branch_TargetFactor(attacker, victim, RN_Grenade_TargetBranch(inflictor));
}

/** 仅对当前操作客户端采样弹夹和动作，不增加全玩家逐帧扫描。 */
void RN_Branch_Command(int client, int buttons)
{
    if (!g_Run_MapReady || client < 1 || client > MaxClients) return;
    RN_BranchSoldier_Command(client, buttons);
    int branch = RN_Branch_Get(client);
    if (branch != RN_BRANCH_HAWKEYE && branch != RN_BRANCH_RANGER)
    {
        RN_BranchMotion empty;
        g_Branch_Motion[client] = empty;
        return;
    }
    if (!IsPlayerAlive(client) || RN_Common_Incapacitated(client))
    {
        RN_BranchMotion empty;
        g_Branch_Motion[client] = empty;
        return;
    }
    float actual[3];
    GetEntPropVector(client, Prop_Data, "m_vecVelocity", actual);
    bool moving = actual[0] * actual[0] + actual[1] * actual[1] > 1.0;
    bool grounded = (GetEntityFlags(client) & FL_ONGROUND) != 0;
    PlayerProfile profile;
    if (RN_Profile_Get(g_Profile_Index[client], profile))
        RN_Branch_MotionSample(client, branch == RN_BRANCH_RANGER ? moving : (!moving && grounded),
            GetTickedTime(), profile.branchVersion);
    return;
}
