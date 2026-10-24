#if defined _rn_stats_included
 #endinput
#endif
#define _rn_stats_included

enum RN_Stat
{
    RN_STAT_HEAL,
    RN_STAT_MOVE,
    RN_STAT_DAMAGE,
    RN_STAT_MELEE,
    RN_STAT_INCOMING,
    RN_STAT_LUCK,
    RN_STAT_CRIT_CHANCE,
    RN_STAT_CRIT_MULTIPLIER,
    RN_STAT_IGNITE,
    RN_STAT_FREEZE,
    RN_STAT_DODGE,
    RN_STAT_CONTROL,
    RN_STAT_BURN_BASE,
    RN_STAT_BURN_BONUS,
    RN_STAT_BURN_DPS,
    RN_STAT_EXPLOSIVE_BULLET,
    RN_STAT_GUN_DAMAGE,
    RN_STAT_EXPLOSION_DAMAGE,
    RN_STAT_EXPLOSION_RADIUS,
    RN_STAT_ELECTRIC_CHANCE,
    RN_STAT_ELECTRIC_BASE,
    RN_STAT_ELECTRIC_BONUS,
    RN_STAT_ELECTRIC_DAMAGE
};

/** 档案层数与配置相乘；战斗、实体属性和查看共用，不做整数中间乘法。 */
float RN_Stats_Value(PlayerProfile profile, int buff, RN_ConfigKey key)
{
    if (profile.profession == RN_PROFESSION_KNIGHT && RN_Buff_KnightRestricted(buff)) return 0.0;
    if (RN_Profession_NoElements(profile) && RN_Buff_Element(buff)
        && !(profile.profession == RN_PROFESSION_KNIGHT && buff == PLAYBUFF_ART)) return 0.0;
    if (RN_Profession_NoElementsOrControl(profile))
    {
        switch (buff)
        {
            case PLAYBUFF_PROBIGNITE, PLAYBUFF_PROBFREEZE, PLAYBUFF_PYROMANIAC,
                 PLAYBUFF_CRYOPHILIA, PLAYBUFF_FLAMEHEART, PLAYBUFF_PROBINVULNERABILITY,
                 PLAYBUFF_POWANGFA: return 0.0;
        }
    }
    return float(profile.buff[buff]) * RN_Config_Float(key);
}

/** 旧版百分比按最近整数取整；大浮点已无小数，避免转int溢出。 */
float RN_Stats_RoundChance(float chance)
{
    if (!RN_Math_Finite(chance) || FloatAbs(chance) >= RN_INT_FLOAT_LIMIT) return chance;
    return float(RoundToNearest(chance));
}

/** 读档实际回血至少1，执行、选卡与查看共用同一值。 */
int RN_Stats_NeverFallHealth()
{
    int health = RN_Config_Int(RN_CVAR_NEVERFALLHEALTH_SURV);
    return health > 0 ? health : 1;
}

/** 火焰共享通用输出及辛辣乘区；全部元素卡代价只扣枪械伤害。 */
float RN_Stats_BurnOutput(PlayerProfile profile, int kills = -1)
{
    return RN_Stats_Get(profile, RN_STAT_DAMAGE, kills) * (1.0 + float(profile.buff[PLAYBUFF_XINLATIANSAI]));
}

/** 汇总同一属性的全部来源；保留战斗原有乘区、强运及移速/输出下限。 */
float RN_Stats_Get(PlayerProfile profile, RN_Stat stat, int kills = -1)
{
    switch (stat)
    {
        case RN_STAT_BURN_BASE:
            return RN_Config_Float(RN_CVAR_IGNITE_BASE_DPS)
                + RN_Stats_Value(profile, PLAYBUFF_PYROMANIAC, RN_CVAR_PYROMANIAC_BURN_DPS_SURV);
        case RN_STAT_BURN_BONUS:
            return RN_Stats_Value(profile, PLAYBUFF_FLAMEHEART, RN_CVAR_FLAMEHEART_BURN_BONUS_SURV);
        case RN_STAT_BURN_DPS:
        {
            return RN_Stats_Get(profile, RN_STAT_BURN_BASE) * (1.0 + RN_Stats_Get(profile, RN_STAT_BURN_BONUS))
                * RN_Stats_BurnOutput(profile, kills);
        }
        case RN_STAT_HEAL:
            return RN_Stats_Value(profile, PLAYBUFF_HEALING, RN_CVAR_HEALHP_SURV)
                + RN_Stats_Value(profile, PLAYBUFF_TIANXINGJIAN, RN_CVAR_TIANXINGJIAN_HEALHP_SURV)
                + RN_Stats_Value(profile, PLAYBUFF_YIJIANSANLIAN, RN_CVAR_YIJIANSANLIAN_HEALHP_SURV);
        case RN_STAT_MOVE:
        {
            float factor = 1.0 + RN_Stats_Value(profile, PLAYBUFF_MOVESPEED, RN_CVAR_MOVESPEEDMULTIPLE_SURV)
                + RN_Stats_Value(profile, PLAYBUFF_LUOYANEBU, RN_CVAR_LUOYANEBU_MOVESPEEDMULTIPLE_SURV)
                - RN_Stats_Value(profile, PLAYBUFF_IMMOVABLE, RN_CVAR_IMMOVABLE_MOVESPEEDREDUCTION_SURV);
            return factor < 0.1 ? 0.1 : factor;
        }
        case RN_STAT_DAMAGE, RN_STAT_GUN_DAMAGE:
        {
            float factor = 1.0 + RN_Reaper_Damage(profile, kills) + RN_Stats_Value(profile, PLAYBUFF_CAUSEHARM, RN_CVAR_ADDMULTIPLE_SURV)
                + RN_Stats_Value(profile, PLAYBUFF_PUTONGQUANPU, RN_CVAR_PUTONGQUANPU_ADDMULTIPLE_SURV)
                + RN_Stats_Value(profile, PLAYBUFF_GLASSCANNON, RN_CVAR_GLASSCANNON_DAMAGE_SURV)
                + RN_Stats_Value(profile, PLAYBUFF_YIJIANSANLIAN, RN_CVAR_YIJIANSANLIAN_DAMAGE_SURV);
            if (stat == RN_STAT_GUN_DAMAGE)
            {
                factor += RN_Profession_GunBonus(profile)
                    + RN_Stats_Value(profile, PLAYBUFF_BIABIABIA, RN_CVAR_BIABIABIA_GUN_DAMAGE);
                float cost = RN_Stats_Value(profile, PLAYBUFF_PYROMANIAC, RN_CVAR_PYROMANIAC_DMGREDUCTION_SURV)
                    + RN_Stats_Value(profile, PLAYBUFF_CRYOPHILIA, RN_CVAR_CRYOPHILIA_DMGREDUCTION_SURV)
                    + RN_Profession_Value(profile, PLAYBUFF_DUAL_ELEMENT, RN_CVAR_DUAL_ELEMENT_DAMAGE_REDUCTION)
                    + RN_Stats_Value(profile, PLAYBUFF_FIVE_WHIP, RN_CVAR_FIVE_WHIP_GUN_COST);
                if (!RN_Math_Finite(cost)) return cost;
                factor -= cost;
                return factor < 0.1 ? 0.1 : factor;
            }
            return factor > 0.0 ? factor : 0.0;
        }
        case RN_STAT_MELEE:
            return 1.0 + RN_Stats_Value(profile, PLAYBUFF_BAOTIANMA, RN_CVAR_BAOTIANMA_MELEEDAMAGE_SURV)
                + RN_Stats_Value(profile, PLAYBUFF_SANDAOLIU, RN_CVAR_SANDAOLIU_MELEEDAMAGE_SURV)
                + RN_Stats_Value(profile, PLAYBUFF_JIEWANGQUAN, RN_CVAR_JIEWANGQUAN_MELEEDAMAGE_SURV);
        case RN_STAT_INCOMING:
            return 1.0 + RN_Reaper_Penalty(profile, kills) - RN_Stats_Value(profile, PLAYBUFF_SUFFERHRAM, RN_CVAR_SUBMULTIPLE_SURV)
                - RN_Stats_Value(profile, PLAYBUFF_TIANXINGJIAN, RN_CVAR_TIANXINGJIAN_SUBMULTIPLE_SURV)
                + RN_Stats_Value(profile, PLAYBUFF_GLASSCANNON, RN_CVAR_GLASSCANNON_DAMAGEREDUCTION_SURV);
        case RN_STAT_LUCK:
            return 1.0 + RN_Stats_Value(profile, PLAYBUFF_QIANGYUN, RN_CVAR_QIANGYUN_PROBBONUS_SURV);
        case RN_STAT_CRIT_CHANCE:
            return (RN_Stats_Value(profile, PLAYBUFF_ZHIMINGYIJI, RN_CVAR_ZHIMINGYIJI_CRITRATE_SURV)
                + RN_Stats_Value(profile, PLAYBUFF_AIYOUWEI, RN_CVAR_AIYOUWEI_CRITRATE_SURV))
                * RN_Stats_Get(profile, RN_STAT_LUCK);
        case RN_STAT_CRIT_MULTIPLIER:
            return RN_Config_Float(RN_CVAR_CRIT_BASE_MULTIPLIER)
                + RN_Stats_Value(profile, PLAYBUFF_JIANSHENG, RN_CVAR_JIANSHENG_CRITDAMAGE_SURV)
                + RN_Stats_Value(profile, PLAYBUFF_HUANYINGCIKE, RN_CVAR_HUANYINGCIKE_CRITDAMAGE_SURV);
        case RN_STAT_IGNITE:
        {
            if (RN_Profession_NoElements(profile)) return 0.0;
            return RN_Stats_RoundChance((RN_Stats_Value(profile, PLAYBUFF_PROBIGNITE, RN_CVAR_PROBIGNITE_SURV)
                + RN_Stats_RoundChance(RN_Stats_Value(profile, PLAYBUFF_PYROMANIAC, RN_CVAR_PYROMANIAC_PROBIGNITE_SURV))
                + RN_Profession_Value(profile, PLAYBUFF_DUAL_ELEMENT, RN_CVAR_DUAL_ELEMENT_IGNITE_CHANCE))
                * RN_Stats_Get(profile, RN_STAT_LUCK) * RN_Profession_ElementFactor(profile));
        }
        case RN_STAT_FREEZE:
        {
            if (RN_Profession_NoElements(profile)) return 0.0;
            return RN_Stats_RoundChance((RN_Stats_Value(profile, PLAYBUFF_PROBFREEZE, RN_CVAR_PROBFREEZE_SURV)
                + RN_Stats_RoundChance(RN_Stats_Value(profile, PLAYBUFF_CRYOPHILIA, RN_CVAR_CRYOPHILIA_PROBFREEZE_SURV))
                + RN_Profession_Value(profile, PLAYBUFF_DUAL_ELEMENT, RN_CVAR_DUAL_ELEMENT_FREEZE_CHANCE))
                * RN_Stats_Get(profile, RN_STAT_LUCK) * RN_Profession_ElementFactor(profile));
        }
        case RN_STAT_DODGE:
            return (RN_Stats_Value(profile, PLAYBUFF_SHEXINGZOUWEI, RN_CVAR_SHEXINGZOUWEI_DODGECHANCE_SURV)
                + RN_Stats_Value(profile, PLAYBUFF_ZIZAIJIYI, RN_CVAR_ZIZAIJIYI_DODGECHANCE_SURV))
                * RN_Stats_Get(profile, RN_STAT_LUCK);
        case RN_STAT_CONTROL:
        {
            if (RN_Profession_NoElementsOrControl(profile)) return 0.0;
            return RN_Stats_RoundChance((RN_Stats_Value(profile, PLAYBUFF_PROBINVULNERABILITY, RN_CVAR_PROBINVINCIBILITY_SURV)
                + RN_Stats_Value(profile, PLAYBUFF_POWANGFA, RN_CVAR_POWANGFA_PROBINVINCIBILITY_SURV)
                + RN_Profession_Control(profile))
                * RN_Stats_Get(profile, RN_STAT_LUCK));
        }
        case RN_STAT_EXPLOSIVE_BULLET:
            return RN_Stats_RoundChance(RN_Profession_Value(profile, PLAYBUFF_EXPLOSIVE_BULLET, RN_CVAR_EXPLOSIVE_BULLET_CHANCE)
                * RN_Stats_Get(profile, RN_STAT_LUCK));
        case RN_STAT_EXPLOSION_DAMAGE:
            return 1.0 + RN_Profession_Value(profile, PLAYBUFF_PATRICK, RN_CVAR_PATRICK_EXPLOSION_DAMAGE_BONUS);
        case RN_STAT_EXPLOSION_RADIUS:
            return 1.0 + RN_Profession_Value(profile, PLAYBUFF_PATRICK, RN_CVAR_PATRICK_EXPLOSION_RADIUS_BONUS);
        case RN_STAT_ELECTRIC_CHANCE:
        {
            if (RN_Profession_NoElements(profile) || RN_Config_Int(RN_CVAR_ELECTRIC_ENABLE) == 0) return 0.0;
            return RN_Stats_RoundChance((RN_Stats_Value(profile, PLAYBUFF_ELECTRIC_ADDICT, RN_CVAR_ELECTRIC_ADDICT_CHANCE)
                + RN_Stats_Value(profile, PLAYBUFF_FIVE_WHIP, RN_CVAR_FIVE_WHIP_CHANCE))
                * RN_Stats_Get(profile, RN_STAT_LUCK) * RN_Profession_ElementFactor(profile));
        }
        case RN_STAT_ELECTRIC_BASE:
            return RN_Config_Float(RN_CVAR_ELECTRIC_BASE_DAMAGE)
                + RN_Stats_Value(profile, PLAYBUFF_FIVE_WHIP, RN_CVAR_FIVE_WHIP_DAMAGE);
        case RN_STAT_ELECTRIC_BONUS:
            return RN_Stats_Value(profile, PLAYBUFF_THUNDER_KING, RN_CVAR_THUNDER_KING_BONUS);
        case RN_STAT_ELECTRIC_DAMAGE:
            return RN_Stats_Get(profile, RN_STAT_ELECTRIC_BASE) * (1.0 + RN_Stats_Get(profile, RN_STAT_ELECTRIC_BONUS))
                * RN_Stats_BurnOutput(profile, kills);
    }
    return 0.0;
}

/** 弹射数先按浮点层数计算，再受技术上限与线性衰减的正伤害范围约束。 */
int RN_Stats_ElectricJumps(PlayerProfile profile)
{
    if (RN_Profession_NoElements(profile) || RN_Config_Float(RN_CVAR_ELECTRIC_RADIUS) <= 0.0) return 0;
    float raw = RN_Config_Float(RN_CVAR_ELECTRIC_JUMPS)
        + RN_Stats_Value(profile, PLAYBUFF_SUPERCONDUCTOR, RN_CVAR_SUPERCONDUCTOR_JUMPS);
    if (!RN_Math_Finite(raw) || raw < 0.0) return 0;
    int maximum = raw >= float(RN_ELECTRIC_MAX_JUMPS) ? RN_ELECTRIC_MAX_JUMPS : RoundToFloor(raw);
    if (RN_Branch_Active(profile, RN_BRANCH_THUNDER)) return maximum;
    float decay = RN_Config_Float(RN_CVAR_ELECTRIC_DECAY);
    int jumps;
    while (jumps < maximum && 1.0 - float(jumps + 1) * decay > 0.0) jumps++;
    return jumps;
}

/** 艺术先叠加到各类基础半径，再乘爆炸范围属性；技术上限统一16384。 */
float RN_Stats_ExplosionRadius(PlayerProfile profile, float radius)
{
    radius *= RN_Stats_Get(profile, RN_STAT_EXPLOSION_RADIUS);
    return radius > 16384.0 ? 16384.0 : radius;
}

/** Tank先穿透正向减伤的一半再钳到0；无敌在穿透前生效。 */
float RN_Stats_Incoming(PlayerProfile profile, bool tank = false)
{
    if (profile.buff[PLAYBUFF_SHENGSHENGBUXI] > 0) return 0.0;
    float factor = RN_Stats_Get(profile, RN_STAT_INCOMING);
    if (tank && factor < 1.0) factor = 1.0 - (1.0 - factor) * 0.5;
    return factor < 0.0 ? 0.0 : factor;
}

/** 显示实际百分比；整数抽样的小数部分不会命中，超100%自然必中。 */
float RN_Stats_Percent(float chance, bool integerRoll = false)
{
    if (integerRoll && !RN_Math_Finite(chance)) return 0.0;
    if (chance >= 100.0) return 100.0;
    if (!RN_Math_Finite(chance) || chance <= 0.0) return 0.0;
    return integerRoll ? float(RoundToFloor(chance)) : chance;
}
