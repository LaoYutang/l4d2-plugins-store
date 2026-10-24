#if defined _rn_branch_elements_included
 #endinput
#endif
#define _rn_branch_elements_included

/** 烈焰只延长新点燃快照；电链传火直接复用载荷时长，不重复加时。 */
float RN_Branch_FireDuration(PlayerProfile profile)
{
    float duration = RN_Config_Float(RN_CVAR_IGNITEDURATION_SURV);
    return duration > 0.0 && RN_Branch_Active(profile, RN_BRANCH_FLAME) ? duration + 2.0 : duration;
}

/** 雷电按初始电伤线性增加；普通电链保持可热改的原始线性衰减。 */
float RN_Branch_ElectricDamage(float initial, int hop, bool thunder, float decay)
{
    return initial * (1.0 + float(hop) * (thunder ? 0.30 : -decay));
}

/** 混乱每跳增加初始榴弹伤害20%，不在上一次已增强伤害上复乘。 */
float RN_Branch_ChaosDamage(float initial, int hop)
{
    return initial * (1.0 + float(hop) * 0.20);
}

/** 和平只折算后续期望伤害的一半；逐项验证，拒绝溢出而不截断玩法数值。 */
bool RN_Branch_PeaceDamage(float initial, int bounces, float splitChance, float decay, float &damage)
{
    damage = initial;
    float next = initial, ratio = (1.0 - decay) * (1.0 + splitChance / 100.0);
    if (!RN_Math_Finite(initial) || initial < 0.0 || initial >= RN_INT_FLOAT_LIMIT
        || !RN_Math_Finite(ratio) || ratio < 0.0) return false;
    for (int hop = 1; hop <= bounces; hop++)
    {
        next *= ratio;
        damage += next * 0.5;
        if (!RN_Math_Finite(next) || !RN_Math_Finite(damage) || damage >= RN_INT_FLOAT_LIMIT) return false;
    }
    return true;
}
