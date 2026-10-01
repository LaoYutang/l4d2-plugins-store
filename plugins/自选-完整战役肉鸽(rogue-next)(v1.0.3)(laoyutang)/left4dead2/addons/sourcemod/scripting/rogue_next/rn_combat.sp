#if defined _rn_combat_included
 #endinput
#endif
#define _rn_combat_included

/** 层数乘参数统一转float，避免整型层数乘法先溢出。 */
float RN_Combat_Value(int client, int buff, RN_ConfigKey key)
{
    return float(RN_Profile_Buff(client, buff)) * RN_Config_Float(key);
}

/** 强运只影响旧版概率效果，概率达到100%后自然必中。 */
float RN_Combat_Luck(int client)
{
    return 1.0 + RN_Combat_Value(client, PLAYBUFF_QIANGYUN, RN_CVAR_QIANGYUN_PROBBONUS_SURV);
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
    if (RN_Profile_Buff(victim, PLAYBUFF_SHENGSHENGBUXI) > 0) { damage = 0.0; return true; }
    float dodge = RN_Combat_Value(victim, PLAYBUFF_SHEXINGZOUWEI, RN_CVAR_SHEXINGZOUWEI_DODGECHANCE_SURV)
        + RN_Combat_Value(victim, PLAYBUFF_ZIZAIJIYI, RN_CVAR_ZIZAIJIYI_DODGECHANCE_SURV);
    if (dodge > 0.0 && GetRandomFloat(0.0, 100.0) < dodge * RN_Combat_Luck(victim))
        { damage = 0.0; return true; }
    float factor = 1.0 - RN_Combat_Value(victim, PLAYBUFF_SUFFERHRAM, RN_CVAR_SUBMULTIPLE_SURV)
        - RN_Combat_Value(victim, PLAYBUFF_TIANXINGJIAN, RN_CVAR_TIANXINGJIAN_SUBMULTIPLE_SURV)
        + RN_Combat_Value(victim, PLAYBUFF_GLASSCANNON, RN_CVAR_GLASSCANNON_DAMAGEREDUCTION_SURV);
    if (RN_Common_Tank(attacker) && factor < 1.0) factor = 1.0 - (1.0 - factor) * 0.5;
    if (factor < 0.0) factor = 0.0;
    damage *= factor;
    return false;
}

/** Tank缴械保留现有近战实体和脚本；不先删除再冒险创建替代物。 */
bool RN_Combat_Disarm(int attacker, int weapon)
{
    if (!RN_Common_Melee(weapon) || !RN_Combat_Percent(RN_Config_Float(RN_CVAR_TANK_DISARM_CHANCE))) return false;
    SDKHooks_DropWeapon(attacker, weapon);
    int primary = GetPlayerWeaponSlot(attacker, 0);
    if (primary > MaxClients && IsValidEntity(primary))
    {
        char classname[64];
        GetEntityClassname(primary, classname, sizeof(classname));
        FakeClientCommand(attacker, "use %s", classname);
    }
    if (!IsFakeClient(attacker)) PrintToChat(attacker, "\x04[rogue]\x01Tank击落了你的近战武器。");
    return true;
}

/** 共用输出管线：近战→加减伤→辛辣独立倍率→暴击→点燃。 */
void RN_Combat_Outgoing(int victim, int attacker, int inflictor, float &damage, int &damagetype)
{
    if (RN_Common_Tank(victim) && RN_Common_Incapacitated(victim)) return;
    if (RN_Common_Melee(inflictor))
    {
        if (RN_Common_Tank(victim) && RN_Combat_Disarm(attacker, inflictor)) { damage = 0.0; return; }
        damage = RN_Config_Float(RN_CVAR_MELEE_BASE_DAMAGE);
        damage *= 1.0 + RN_Combat_Value(attacker, PLAYBUFF_BAOTIANMA, RN_CVAR_BAOTIANMA_MELEEDAMAGE_SURV)
            + RN_Combat_Value(attacker, PLAYBUFF_SANDAOLIU, RN_CVAR_SANDAOLIU_MELEEDAMAGE_SURV)
            + RN_Combat_Value(attacker, PLAYBUFF_JIEWANGQUAN, RN_CVAR_JIEWANGQUAN_MELEEDAMAGE_SURV);
    }
    float factor = 1.0 + RN_Combat_Value(attacker, PLAYBUFF_CAUSEHARM, RN_CVAR_ADDMULTIPLE_SURV)
        + RN_Combat_Value(attacker, PLAYBUFF_PUTONGQUANPU, RN_CVAR_PUTONGQUANPU_ADDMULTIPLE_SURV)
        + RN_Combat_Value(attacker, PLAYBUFF_GLASSCANNON, RN_CVAR_GLASSCANNON_DAMAGE_SURV)
        + RN_Combat_Value(attacker, PLAYBUFF_YIJIANSANLIAN, RN_CVAR_YIJIANSANLIAN_DAMAGE_SURV)
        - RN_Combat_Value(attacker, PLAYBUFF_PYROMANIAC, RN_CVAR_PYROMANIAC_DMGREDUCTION_SURV)
        - RN_Combat_Value(attacker, PLAYBUFF_CRYOPHILIA, RN_CVAR_CRYOPHILIA_DMGREDUCTION_SURV);
    damage *= factor > 0.0 ? factor : 0.0;
    damage *= 1.0 + float(RN_Profile_Buff(attacker, PLAYBUFF_XINLATIANSAI));
    float luck = RN_Combat_Luck(attacker);
    float critical = RN_Combat_Value(attacker, PLAYBUFF_ZHIMINGYIJI, RN_CVAR_ZHIMINGYIJI_CRITRATE_SURV)
        + RN_Combat_Value(attacker, PLAYBUFF_AIYOUWEI, RN_CVAR_AIYOUWEI_CRITRATE_SURV);
    if (critical > 0.0 && GetRandomFloat(0.0, 1.0) < critical * luck)
        damage *= RN_Config_Float(RN_CVAR_CRIT_BASE_MULTIPLIER)
            + RN_Combat_Value(attacker, PLAYBUFF_JIANSHENG, RN_CVAR_JIANSHENG_CRITDAMAGE_SURV)
            + RN_Combat_Value(attacker, PLAYBUFF_HUANYINGCIKE, RN_CVAR_HUANYINGCIKE_CRITDAMAGE_SURV);
    float ignite = RN_Combat_Value(attacker, PLAYBUFF_PROBIGNITE, RN_CVAR_PROBIGNITE_SURV)
        + RN_Combat_Value(attacker, PLAYBUFF_PYROMANIAC, RN_CVAR_PYROMANIAC_PROBIGNITE_SURV);
    if ((damagetype & (DMG_BURN | DMG_SLOWBURN)) == 0 && RN_Combat_Percent(ignite * luck))
    {
        damagetype = 0x10000008;
        RN_FX_Fire(victim, RN_Config_Float(RN_CVAR_IGNITEDURATION_SURV));
    }
}

/** SDKHooks唯一结算入口；玩家与NPC共用数学顺序，不复制两套效果逻辑。 */
public Action RN_Combat_OnDamage(int victim, int &attacker, int &inflictor, float &damage,
                                 int &damagetype, int &weapon, float force[3], float position[3])
{
    if (!RN_Config_Enabled() || damage <= 0.0 || !RN_Math_Finite(damage)) return Plugin_Continue;
    float before = damage;
    int beforeType = damagetype;
    if (RN_Common_Survivor(victim) && RN_Combat_Incoming(victim, attacker, damage))
        return Plugin_Changed;
    if (RN_Common_Survivor(attacker) && (RN_Common_Infected(victim) || RN_Common_Zombie(victim)))
        RN_Combat_Outgoing(victim, attacker, inflictor, damage, damagetype);
    if (RN_Common_Infected(attacker) || RN_Common_Zombie(attacker))
        damage *= RN_Scaling_DamageFactor();
    if (!RN_Math_Finite(damage))
    {
        LogError("[rogue-next] 不可表达的伤害计算被拒绝（victim=%d, attacker=%d）。", victim, attacker);
        damage = before;
        damagetype = beforeType;
        return Plugin_Continue;
    }
    return before != damage || beforeType != damagetype ? Plugin_Changed : Plugin_Continue;
}

/** 命中后的冻结统一入口；事件路由只负责提取玩家userid或NPC entityid。 */
void RN_Combat_Hit(int victim, int attacker)
{
    if (!RN_Config_Enabled() || !RN_Common_Survivor(attacker) ||
        (!RN_Common_Infected(victim) && !RN_Common_Zombie(victim))) return;
    float chance = RN_Combat_Value(attacker, PLAYBUFF_PROBFREEZE, RN_CVAR_PROBFREEZE_SURV)
        + RN_Combat_Value(attacker, PLAYBUFF_CRYOPHILIA, RN_CVAR_CRYOPHILIA_PROBFREEZE_SURV);
    if (RN_Combat_Percent(chance * RN_Combat_Luck(attacker)))
        RN_FX_Freeze(victim, RN_Config_Float(RN_CVAR_FREEZEDURATION_SURV));
}

/** 控制免疫的四类Left4DHooks回调共用判定。 */
Action RN_Combat_Control(int victim, int attacker)
{
    if (!RN_Config_Enabled() || !RN_Common_Survivor(victim)) return Plugin_Continue;
    float chance = RN_Combat_Value(victim, PLAYBUFF_PROBINVULNERABILITY, RN_CVAR_PROBINVINCIBILITY_SURV)
        + RN_Combat_Value(victim, PLAYBUFF_POWANGFA, RN_CVAR_POWANGFA_PROBINVINCIBILITY_SURV);
    if (!RN_Combat_Percent(chance * RN_Combat_Luck(victim))) return Plugin_Continue;
    if (RN_Common_Infected(attacker))
    {
        L4D_CleanupPlayerState(attacker);
        L4D_StaggerPlayer(attacker, victim, NULL_VECTOR);
    }
    return Plugin_Handled;
}

/** 读档账本先提交，再解除控制，以免伤害事件嵌套覆盖新消耗。 */
public Action L4D_OnIncapacitated(int victim, int &inflictor, int &attacker, float &damage, int &damagetype)
{
    if (!RN_Config_Enabled() || !RN_Common_Survivor(victim) || IsFakeClient(victim)) return Plugin_Continue;
    PlayerProfile profile;
    int capacity;
    if (!RN_Profile_Get(g_Profile_Index[victim], profile) ||
        !RN_Math_Multiply(profile.buff[PLAYBUFF_NEVERFALL], RN_Config_Int(RN_CVAR_NEVERFALLNUM_SURV), capacity) ||
        profile.neverFallUsed >= capacity || !RN_Math_Add(profile.neverFallUsed, 1, profile.neverFallUsed))
        return Plugin_Continue;
    RN_Profile_Save(g_Profile_Index[victim], profile);
    int health = RN_Config_Int(RN_CVAR_NEVERFALLHEALTH_SURV);
    SetEntProp(victim, Prop_Data, "m_iHealth", health > 0 ? health : 1);
    RN_FX_ReleaseControl(victim);
    PrintToChat(victim, "\x04[rogue]\x01读档战神生效，剩余%d次。", capacity - profile.neverFallUsed);
    return Plugin_Handled;
}

/** Smoker控制前的统一免疫判定。 */
public Action L4D_OnGrabWithTongue(int victim, int attacker) { return RN_Combat_Control(victim, attacker); }

/** Hunter控制前的统一免疫判定。 */
public Action L4D_OnPouncedOnSurvivor(int victim, int attacker) { return RN_Combat_Control(victim, attacker); }

/** Jockey控制前的统一免疫判定。 */
public Action L4D2_OnJockeyRide(int victim, int attacker) { return RN_Combat_Control(victim, attacker); }

/** Charger搬运前的统一免疫判定。 */
public Action L4D2_OnStartCarryingVictim(int victim, int attacker) { return RN_Combat_Control(victim, attacker); }

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
        if (!RN_Common_Survivor(client) || IsFakeClient(client) || !IsPlayerAlive(client)) continue;
        float death = RN_Combat_Value(client, PLAYBUFF_DAMOCLESSWORD, RN_CVAR_DAMOCLESSWORD_DEATHPROB_SURV);
        if (death > 0.0 && GetRandomInt(1, 10000) <= death)
            SDKHooks_TakeDamage(client, 0, 0, 999.0, DMG_GENERIC);
        if (!IsPlayerAlive(client)) continue;
        float tank = RN_Combat_Value(client, PLAYBUFF_ZHAOZAI, RN_CVAR_ZHAOZAI_SPAWNTANKPROB_SURV);
        if (tank > 0.0 && GetRandomInt(1, 10000) <= tank)
        {
            float origin[3], angles[3];
            GetClientAbsOrigin(client, origin);
            GetClientEyeAngles(client, angles);
            origin[0] += Cosine(DegToRad(angles[1])) * 100.0;
            origin[1] += Sine(DegToRad(angles[1])) * 100.0;
            L4D2_SpawnTank(origin, angles);
        }
    }
}

