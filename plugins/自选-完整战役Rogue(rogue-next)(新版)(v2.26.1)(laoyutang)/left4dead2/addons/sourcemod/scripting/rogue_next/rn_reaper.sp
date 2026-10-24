#if defined _rn_reaper_included
 #endinput
#endif
#define _rn_reaper_included

/** 只读解析稳定档案身份，直接使用排行的唯一击杀账本，不创建或缓存第二份计数。 */
int RN_Reaper_Kills(PlayerProfile profile)
{
    int index;
    return g_Profile_Id2Index != null && g_Profile_Id2Index.GetValue(profile.id, index)
        ? RN_HUDStats_Read(index) : 0;
}

/** 天赋和契约各有独立成长参数；候选计数只供入账前验证，不写档案。 */
float RN_Reaper_Damage(PlayerProfile profile, int kills = -1)
{
    if (!RN_Profession_Is(profile, RN_PROFESSION_REAPER)) return 0.0;
    if (kills < 0) kills = RN_Reaper_Kills(profile);
    return float(kills) * RN_Reaper_DamageRate(profile);
}

/** 查看特性与每次击杀共用合计伤害成长，无击杀时仍能说明成长能力。 */
float RN_Reaper_DamageRate(PlayerProfile profile)
{
    return RN_Profession_Is(profile, RN_PROFESSION_REAPER) ? RN_Config_Float(RN_CVAR_REAPER_DAMAGE_PER_KILL)
        + float(profile.buff[PLAYBUFF_DEMON_CONTRACT]) * RN_Config_Float(RN_CVAR_DEMON_CONTRACT_DAMAGE_PER_KILL) : 0.0;
}

/** 原惩罚剩余比例只取从心层数；超过免除上限不会产生额外正向减伤。 */
float RN_Reaper_Remaining(PlayerProfile profile)
{
    float value = 1.0 - float(profile.buff[PLAYBUFF_CONGXIN]) * RN_Config_Float(RN_CVAR_CONGXIN_PENALTY_REDUCTION);
    return value > 0.0 ? value : 0.0;
}

/** 查看特性与惩罚使用同一实际每杀增量，包含从心削减且不改其他承伤来源。 */
float RN_Reaper_PenaltyRate(PlayerProfile profile)
{
    return RN_Profession_Is(profile, RN_PROFESSION_REAPER) ? (RN_Config_Float(RN_CVAR_REAPER_PENALTY_PER_KILL)
        + float(profile.buff[PLAYBUFF_DEMON_CONTRACT]) * RN_Config_Float(RN_CVAR_DEMON_CONTRACT_PENALTY_PER_KILL))
        * RN_Reaper_Remaining(profile) : 0.0;
}

/** 从心只削减这两个契约来源的原惩罚，线性加算并在100%封顶，不影响其他减伤。 */
float RN_Reaper_Penalty(PlayerProfile profile, int kills = -1)
{
    if (!RN_Profession_Is(profile, RN_PROFESSION_REAPER)) return 0.0;
    if (kills < 0) kills = RN_Reaper_Kills(profile);
    return float(kills) * RN_Reaper_PenaltyRate(profile);
}

/** 每杀回血为精确整数，层数乘配置溢出时返回失败值供事务验证。 */
int RN_Reaper_Heal(PlayerProfile profile)
{
    if (!RN_Profession_Is(profile, RN_PROFESSION_REAPER)) return 0;
    int amount;
    return RN_Math_Multiply(profile.buff[PLAYBUFF_SOUL_DRAIN], RN_Config_Int(RN_CVAR_SOUL_DRAIN_HEAL), amount) ? amount : -1;
}
