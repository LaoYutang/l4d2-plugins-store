#if defined _rn_combat_included
 #endinput
#endif
#define _rn_combat_included

/** 读档保护只属于当前会话/生命/地图，不随SteamID档案跨边界保留。 */
enum struct RN_ReviveProtection
{
    float until;
    int serial;
    int life;
    int run;
    int map;
}
RN_ReviveProtection g_Combat_Protection[MAXPLAYERS + 1];

/** 清除单个客户端的保护；无效事件userid不会影响其他玩家。 */
void RN_Combat_ProtectionClear(int client)
{
    if (client > 0 && client <= MaxClients) g_Combat_Protection[client].until = 0.0;
}

/** 关闭功能或保护配置时立即撤销全部窗口，不保留再次启用可恢复的时间戳。 */
void RN_Combat_ProtectionClearAll()
{
    for (int client = 1; client <= MaxClients; client++) RN_Combat_ProtectionClear(client);
}

/** 只在成功读档后固定结束时间；重复伤害/回调不能延长窗口。 */
void RN_Combat_Protect(int client)
{
    RN_Combat_ProtectionClear(client);
    float duration = RN_Config_Float(RN_CVAR_NEVERFALL_PROTECTION_TIME);
    if (duration <= 0.0) return;
    float now = GetTickedTime(), until = now + duration;
    if (!RN_Math_Finite(until) || until <= now)
    {
        LogError("[rogue-next] 读档保护结束时间不可表达，未建立窗口：client=%d duration=%.4f。", client, duration);
        return;
    }
    g_Combat_Protection[client].serial = GetClientSerial(client);
    g_Combat_Protection[client].life = g_Common_Life[client];
    g_Combat_Protection[client].run = g_Run_Epoch;
    g_Combat_Protection[client].map = g_Run_MapEpoch;
    g_Combat_Protection[client].until = until;
}

/** 先用空时间戳快速排除普通命中，再核对启用状态与完整生命周期。 */
bool RN_Combat_Protected(int client)
{
    if (client < 1 || client > MaxClients || g_Combat_Protection[client].until <= 0.0) return false;
    if (!RN_Config_Enabled() || RN_Config_Float(RN_CVAR_NEVERFALL_PROTECTION_TIME) <= 0.0 ||
        !RN_Common_Survivor(client) || IsFakeClient(client) || !IsPlayerAlive(client) ||
        g_Combat_Protection[client].serial != GetClientSerial(client) ||
        g_Combat_Protection[client].life != g_Common_Life[client] ||
        g_Combat_Protection[client].run != g_Run_Epoch || g_Combat_Protection[client].map != g_Run_MapEpoch ||
        GetTickedTime() >= g_Combat_Protection[client].until)
    {
        RN_Combat_ProtectionClear(client);
        return false;
    }
    return true;
}

/** 层数乘参数统一转float，避免整型层数乘法先溢出。 */
float RN_Combat_Value(int client, int buff, RN_ConfigKey key)
{
    return float(RN_Profile_Buff(client, buff)) * RN_Config_Float(key);
}

/** BOT、无档案和停用状态使用零层档案；派生属性与查看界面同源。 */
void RN_Combat_Profile(int client, PlayerProfile profile)
{
    if (RN_Config_Enabled() && RN_Common_Survivor(client) && !IsFakeClient(client))
        RN_Profile_Get(g_Profile_Index[client], profile);
}

/** 百分比判定采用旧版1~100整数抽样；高概率先钳制以免转整数溢出。 */
bool RN_Combat_Percent(float chance)
{
    if (chance <= 0.0 || !RN_Math_Finite(chance)) return false;
    if (chance >= 100.0) return true;
    return float(GetRandomInt(1, 100)) <= chance;
}

/** 生生不息与闪避优先；Tank仅穿透正向减伤的一半，随后才乘时间难度。 */
bool RN_Combat_Incoming(int victim, int attacker, float &damage)
{
    PlayerProfile profile;
    RN_Combat_Profile(victim, profile);
    if (profile.buff[PLAYBUFF_SHENGSHENGBUXI] > 0) { damage = 0.0; return true; }
    float dodge = RN_Stats_Get(profile, RN_STAT_DODGE);
    if (dodge > 0.0 && GetRandomFloat(0.0, 100.0) < dodge)
        { damage = 0.0; return true; }
    damage *= RN_Stats_Incoming(profile, RN_Common_Tank(attacker));
    return false;
}

/** 剑客先免除缴械且不抽样；其他职业保留近战实体和脚本，不创建替代物。 */
bool RN_Combat_Disarm(int attacker, int weapon, PlayerProfile profile)
{
    if (!RN_Common_Survivor(attacker) || !IsPlayerAlive(attacker) || !RN_Common_Melee(weapon) ||
        GetPlayerWeaponSlot(attacker, 1) != weapon || RN_Profession_DisarmImmune(profile) ||
        !RN_Combat_Percent(RN_Config_Float(RN_CVAR_TANK_DISARM_CHANCE))) return false;
    SDKHooks_DropWeapon(attacker, weapon);
    int primary = GetPlayerWeaponSlot(attacker, 0);
    if (primary > MaxClients && IsValidEntity(primary))
    {
        char classname[64];
        GetEntityClassname(primary, classname, sizeof(classname));
        FakeClientCommand(attacker, "use %s", classname);
    }
    RN_Notify_Disarm(attacker);
    return true;
}

/** 连续火焰没有武器命中标志；燃烧子弹/近战/普通爆炸仍属于直接攻击。 */
bool RN_Combat_ContinuousFire(int damagetype)
{
    return (damagetype & (DMG_BURN | DMG_SLOWBURN)) != 0
        && (damagetype & (DMG_BULLET | DMG_BUCKSHOT | DMG_SLASH | DMG_CLUB | DMG_BLAST)) == 0;
}

/** 直接攻击与冰火爆炸共用暴击属性；一次调用只抽样一次，零概率不抽样。 */
float RN_Combat_CriticalFactor(PlayerProfile profile, bool &critical)
{
    float chance = RN_Stats_Get(profile, RN_STAT_CRIT_CHANCE);
    critical = RN_Combat_CriticalDraw(chance);
    return critical ? RN_Stats_Get(profile, RN_STAT_CRIT_MULTIPLIER) : 1.0;
}

/** 剑气使用发射时快照，仍沿用直接攻击的同一次概率抽样口径。 */
bool RN_Combat_CriticalDraw(float chance)
{
    return chance > 0.0 && GetRandomFloat(0.0, 1.0) < chance;
}

/** 不需要暴击标记的剑气共用倍率判定，零概率不消耗随机数。 */
float RN_Combat_CriticalRoll(float chance, float multiplier)
{
    return RN_Combat_CriticalDraw(chance) ? multiplier : 1.0;
}

/** 普通近战和剑气共用暴击前伤害，含全部近战、通用输出及辛辣乘区。 */
float RN_Combat_MeleeBase(PlayerProfile profile)
{
    return RN_Config_Float(RN_CVAR_MELEE_BASE_DAMAGE) * RN_Stats_Get(profile, RN_STAT_MELEE)
        * RN_Stats_Get(profile, RN_STAT_DAMAGE) * (1.0 + float(profile.buff[PLAYBUFF_XINLATIANSAI]));
}

/** 枪械弹丸及榴弹接入净枪伤加算，其他爆炸、近战和连续火沿用各自通用输出。 */
void RN_Combat_Outgoing(int victim, int attacker, int inflictor, float &damage, int &damagetype, int weapon = -1)
{
    if (RN_Common_Tank(victim) && RN_Common_Incapacitated(victim)) return;
    PlayerProfile profile;
    RN_Combat_Profile(attacker, profile);
    if (RN_Combat_ContinuousFire(damagetype))
    {
        damage *= RN_Stats_BurnOutput(profile) * RN_Branch_SourceFactor(attacker)
            * RN_Branch_TargetFactor(attacker, victim);
        return;
    }
    if (RN_Common_Melee(inflictor))
    {
        if (RN_Common_Tank(victim) && RN_Combat_Disarm(attacker, inflictor, profile)) { damage = 0.0; return; }
        damage = RN_Combat_MeleeBase(profile);
    }
    else
    {
        RN_Stat stat = RN_Profession_GunIndex(attacker, inflictor, weapon, damagetype) >= 0 || RN_Grenade_Shot(inflictor, damagetype)
            ? RN_STAT_GUN_DAMAGE : RN_STAT_DAMAGE;
        damage *= RN_Stats_Get(profile, stat);
        damage *= 1.0 + float(profile.buff[PLAYBUFF_XINLATIANSAI]);
    }
    damage *= RN_Profession_DamageFactor(profile, victim, attacker, inflictor, weapon, damagetype);
    if (RN_Grenade_Shot(inflictor, damagetype)) damage *= RN_Stats_Get(profile, RN_STAT_EXPLOSION_DAMAGE);
    bool critical;
    damage *= RN_Combat_CriticalFactor(profile, critical);
    damage *= RN_Branch_DirectFactor(victim, attacker, inflictor, weapon, damagetype);
}

/** SDKHooks唯一结算入口；玩家与NPC共用数学顺序，不复制两套效果逻辑。 */
public Action RN_Combat_OnDamage(int victim, int &attacker, int &inflictor, float &damage,
                                 int &damagetype, int &weapon, float force[3], float position[3])
{
    if (!RN_Config_Enabled() || damage <= 0.0 || !RN_Math_Finite(damage)) return Plugin_Continue;
    if (RN_Combat_Protected(victim)) { damage = 0.0; return Plugin_Handled; }
    if (RN_Burn_Internal(victim, attacker)) return Plugin_Continue;
    if (RN_Sword_Internal(victim, attacker, inflictor, weapon, damagetype)) return Plugin_Continue;
    bool transferred = RN_BranchKnight_ClaimTransfer(victim, attacker, inflictor, damagetype, weapon);
    Action branchAction = RN_BranchKnight_OnDamage(victim, attacker, inflictor, damage,
        damagetype, weapon, transferred);
    if (branchAction != Plugin_Continue) return branchAction;
    float before = damage;
    int beforeType = damagetype;
    int beforeAttacker = attacker;
    if (RN_Combat_ContinuousFire(damagetype) && RN_Burn_Living(victim))
        attacker = RN_Burn_NativeOwner(victim, attacker, inflictor);
    if (RN_Common_Survivor(victim) && RN_Combat_Incoming(victim, attacker, damage))
        return Plugin_Changed;
    if (RN_Common_Survivor(attacker) && (RN_Common_Infected(victim) || RN_Common_Zombie(victim)))
    {
        RN_Element_Capture(victim, attacker, inflictor, damage, damagetype, weapon);
        RN_Combat_Outgoing(victim, attacker, inflictor, damage, damagetype, weapon);
    }
    if (RN_Common_Infected(attacker) || RN_Common_Zombie(attacker))
        damage *= RN_Scaling_DamageFactor();
    damage *= RN_Disaster_AttackFactor(victim, damagetype, inflictor, weapon);
    if (!RN_Math_Finite(damage) || damage >= RN_INT_FLOAT_LIMIT)
    {
        LogError("[rogue-next] 不可表达的伤害计算被拒绝（victim=%d, attacker=%d）。", victim, attacker);
        damage = before;
        damagetype = beforeType;
        attacker = beforeAttacker;
        return Plugin_Continue;
    }
    return before != damage || beforeType != damagetype || beforeAttacker != attacker ? Plugin_Changed : Plugin_Continue;
}

/** 冰冻攻击者不能建立新控制；舌头、扑倒与骑乘共用免疫，牛另有两阶段处理。 */
Action RN_Combat_Control(int victim, int attacker)
{
    if (!RN_Config_Enabled() || !RN_Common_Survivor(victim)) return Plugin_Continue;
    if (RN_Common_Infected(attacker) && RN_FX_Frozen(attacker)) return Plugin_Handled;
    PlayerProfile profile;
    RN_Combat_Profile(victim, profile);
    if (!RN_Combat_Percent(RN_Stats_Get(profile, RN_STAT_CONTROL))) return Plugin_Continue;
    if (RN_Common_Infected(attacker))
    {
        L4D_CleanupPlayerState(attacker);
        L4D_StaggerPlayer(attacker, victim, NULL_VECTOR);
    }
    return Plugin_Handled;
}

/** 保护优先于耗尽判断；账本提交后先建立窗口，再回血/解除控制。 */
public Action L4D_OnIncapacitated(int victim, int &inflictor, int &attacker, float &damage, int &damagetype)
{
    if (!RN_Config_Enabled() || !RN_Common_Survivor(victim) || IsFakeClient(victim)) return Plugin_Continue;
    if (RN_Combat_Protected(victim)) return Plugin_Handled;
    PlayerProfile profile;
    int capacity;
    if (!RN_Profile_Get(g_Profile_Index[victim], profile) ||
        !RN_Math_Multiply(profile.buff[PLAYBUFF_NEVERFALL], RN_Config_Int(RN_CVAR_NEVERFALLNUM_SURV), capacity) ||
        profile.neverFallUsed >= capacity || !RN_Math_Add(profile.neverFallUsed, 1, profile.neverFallUsed))
        return Plugin_Continue;
    RN_Profile_Save(g_Profile_Index[victim], profile);
    RN_Combat_Protect(victim);
    SetEntProp(victim, Prop_Data, "m_iHealth", RN_Stats_NeverFallHealth());
    RN_FX_ReleaseControl(victim);
    RN_Notify_NeverFall(victim, capacity - profile.neverFallUsed);
    return Plugin_Handled;
}

/** Smoker控制前的统一免疫判定。 */
public Action L4D_OnGrabWithTongue(int victim, int attacker) { return RN_Combat_Control(victim, attacker); }

/** Hunter控制前的统一免疫判定。 */
public Action L4D_OnPouncedOnSurvivor(int victim, int attacker) { return RN_Combat_Control(victim, attacker); }

/** Jockey控制前的统一免疫判定。 */
public Action L4D2_OnJockeyRide(int victim, int attacker) { return RN_Combat_Control(victim, attacker); }

/** 一秒独立风险抽样，沿用旧版每万分之一口径。 */
void RN_Combat_Tick()
{
    if (!RN_Config_Enabled()) return;
    for (int client = 1; client <= MaxClients; client++)
    {
        // 使用当前会话的当前实体检查，没有跨图/跨生命的专属Tank定时器。
        if (RN_Common_Tank(client) && IsPlayerAlive(client) &&
            GetEntProp(client, Prop_Send, "m_isIncapacitated") != 0)
        {
            ForcePlayerSuicide(client);
            continue;
        }
        if (!RN_Common_Survivor(client) || IsFakeClient(client) || !IsPlayerAlive(client) ||
            RN_Common_Incapacitated(client)) continue;
        int serial = GetClientSerial(client), life = g_Common_Life[client];
        int run = g_Run_Epoch, map = g_Run_MapEpoch;
        float death = RN_Combat_Value(client, PLAYBUFF_DAMOCLESSWORD, RN_CVAR_DAMOCLESSWORD_DEATHPROB_SURV);
        if (death > 0.0 && GetRandomInt(1, 10000) <= death)
        {
            char name[64];
            RN_Notify_Name(client, name, sizeof(name));
            SDKHooks_TakeDamage(client, 0, 0, 999.0, DMG_GENERIC);
            RN_Notify_Risk(name, false);
        }
        if (!RN_Config_Enabled() || run != g_Run_Epoch || map != g_Run_MapEpoch) return;
        if (!RN_Common_Survivor(client) || IsFakeClient(client) || !IsPlayerAlive(client) ||
            GetClientSerial(client) != serial || g_Common_Life[client] != life || RN_Common_Incapacitated(client)) continue;
        float tank = RN_Combat_Value(client, PLAYBUFF_ZHAOZAI, RN_CVAR_ZHAOZAI_SPAWNTANKPROB_SURV);
        if (tank > 0.0 && GetRandomInt(1, 10000) <= tank)
        {
            char name[64];
            RN_Notify_Name(client, name, sizeof(name));
            float origin[3], angles[3];
            GetClientAbsOrigin(client, origin);
            GetClientEyeAngles(client, angles);
            origin[0] += Cosine(DegToRad(angles[1])) * 100.0;
            origin[1] += Sine(DegToRad(angles[1])) * 100.0;
            angles[0] = 0.0;
            angles[1] += 180.0;
            angles[2] = 0.0;
            int spawned = L4D2_SpawnTank(origin, angles);
            if (RN_Common_Tank(spawned) && IsPlayerAlive(spawned)) RN_Notify_Risk(name, true);
            else LogError("[rogue-next] 招灾未生成存活Tank：client=%d return=%d。", client, spawned);
        }
    }
}
