#if defined _rn_magician_included
 #endinput
#endif
#define _rn_magician_included

/** 从保留的正负BUFF层数计算原始弹跳账本，钳零不能写回档案。 */
bool RN_Magician_Balance(PlayerProfile profile, int &balance)
{
    balance = 0;
    if (!RN_Profession_Is(profile, RN_PROFESSION_MAGICIAN)) return true;
    int positive, penalty;
    if (!RN_Math_Multiply(profile.buff[PLAYBUFF_PINGPONG], RN_Config_Int(RN_CVAR_PINGPONG_BOUNCES), positive) ||
        !RN_Math_Add(positive, RN_Config_Int(RN_CVAR_MAGICIAN_BOUNCES), positive) ||
        !RN_Math_Multiply(profile.buff[PLAYBUFF_BIG_SCENE], RN_Config_Int(RN_CVAR_BIG_SCENE_BOUNCE_PENALTY), penalty)) return false;
    balance = positive - penalty;
    return true;
}

/** 原职业额外弹跳最低0、最高63；和平折算使用此值，不丢失后续预算。 */
int RN_Magician_BaseBounces(PlayerProfile profile)
{
    int balance;
    if (!RN_Magician_Balance(profile, balance) || balance < 0) return 0;
    return balance > 63 ? 63 : balance;
}

/** 和平取消实际弹跳；混乱在原有效次数上增加1次，保留63次技术上限。 */
int RN_Magician_Bounces(PlayerProfile profile)
{
    if (RN_Branch_Active(profile, RN_BRANCH_PEACE)) return 0;
    int bounces = RN_Magician_BaseBounces(profile);
    return RN_Branch_Active(profile, RN_BRANCH_CHAOS) && bounces < 63 ? bounces + 1 : bounces;
}

/** 和平期望预算复用原弹跳衰减与分裂概率，首发不计入折算项。 */
bool RN_Magician_PeaceDamage(PlayerProfile profile, float &damage)
{
    return RN_Branch_PeaceDamage(RN_Config_Float(RN_CVAR_GRENADE_DAMAGE), RN_Magician_BaseBounces(profile),
        RN_Magician_SplitChance(profile), RN_Config_Float(RN_CVAR_GRENADE_BOUNCE_DAMAGE_DECAY), damage);
}

/** 分裂按百分点直接加算，超过100%可增加弹数，与元素概率倍率分开。 */
float RN_Magician_SplitChance(PlayerProfile profile)
{
    if (!RN_Profession_Is(profile, RN_PROFESSION_MAGICIAN)) return 0.0;
    return RN_Config_Float(RN_CVAR_MAGICIAN_SPLIT_CHANCE)
        + RN_Profession_Value(profile, PLAYBUFF_BIG_SCENE, RN_CVAR_BIG_SCENE_SPLIT_CHANCE);
}

/** 榴弹和元素爆炸共用原艺术属性；两类爆炸各自叠加到基础半径。 */
float RN_Magician_Radius(PlayerProfile profile)
{
    float radius = RN_Config_Float(RN_CVAR_GRENADE_RADIUS)
        + RN_Profession_Value(profile, PLAYBUFF_ART, RN_CVAR_ART_EXPLOSION_RADIUS_BONUS);
    return RN_Stats_ExplosionRadius(profile, radius);
}

/** 档案与热改同时校验整数账本及通用增伤、辛辣和最大暴击输出。 */
bool RN_Magician_Validate(PlayerProfile profile)
{
    int balance;
    float initial = RN_Grenade_Damage(0);
    if (RN_Branch_Active(profile, RN_BRANCH_PEACE) && !RN_Magician_PeaceDamage(profile, initial)) return false;
    if (RN_Branch_Active(profile, RN_BRANCH_CHAOS)) initial = RN_Branch_ChaosDamage(initial, RN_Magician_Bounces(profile));
    float damage = initial * RN_Stats_Get(profile, RN_STAT_GUN_DAMAGE)
        * (1.0 + float(profile.buff[PLAYBUFF_XINLATIANSAI])) * RN_Stats_Get(profile, RN_STAT_CRIT_MULTIPLIER)
        * RN_Stats_Get(profile, RN_STAT_EXPLOSION_DAMAGE);
    return RN_Magician_Balance(profile, balance) && RN_Math_Finite(RN_Magician_SplitChance(profile))
        && RN_Math_Finite(damage) && damage < RN_INT_FLOAT_LIMIT;
}
