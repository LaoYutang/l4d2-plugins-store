#if defined _rn_buff_pool_included
 #endinput
#endif
#define _rn_buff_pool_included

/** 职业专属卡与禁用项共用资格；职业停用不解除已选职业的获卡限制。 */
bool RN_Buff_Allowed(int buff, int profession)
{
    if (buff <= PLAYBUFF_NULL || buff >= MAXBUFFENUM) return false;
    if (profession == RN_PROFESSION_KNIGHT && RN_Buff_KnightRestricted(buff)) return false;
    if ((profession == RN_PROFESSION_BLADEMASTER || profession == RN_PROFESSION_SNIPER)
        && RN_Buff_Element(buff)) return false;
    if (profession == RN_PROFESSION_ELEMENTALIST)
    {
        switch (buff)
        {
            case PLAYBUFF_BIABIABIA, PLAYBUFF_ZHIMINGYIJI, PLAYBUFF_AIYOUWEI,
                 PLAYBUFF_JIANSHENG, PLAYBUFF_HUANYINGCIKE: return false;
        }
    }
    int exclusive = RN_Buff_Profession(buff);
    if (exclusive != RN_PROFESSION_NONE)
        return RN_Config_Int(RN_CVAR_PROFESSION_ENABLE) != 0 && RN_Buff_ProfessionMatches(buff, profession);
    if (profession == RN_PROFESSION_SNIPER)
    {
        switch (buff)
        {
            case PLAYBUFF_PROBIGNITE, PLAYBUFF_PROBFREEZE, PLAYBUFF_PYROMANIAC,
                 PLAYBUFF_CRYOPHILIA, PLAYBUFF_FLAMEHEART, PLAYBUFF_PROBINVULNERABILITY,
                 PLAYBUFF_POWANGFA: return false;
        }
    }
    return true;
}

/**
 * 在合法候选上直接加权，不展开大数组或有限次数重试。
 * @param rarity -1表示所有稀有度；指定稀有度时候选内等权，保留旧奖励口径。
 * @param excludeTransforms 自动奖励统一排除D4/繁星，嵌套奖励必须沿用。
 * @return 没有合法候选时false，调用方不得消费预算或ROLL。
 */
bool RN_Pool_Draw(int &buff, int rarity = -1, bool excludeTransforms = false, int profession = RN_PROFESSION_NONE)
{
    int total;
    for (int id = 1; id < MAXBUFFENUM; id++)
    {
        if (!RN_Buff_Allowed(id, profession)) continue;
        if (rarity >= 0 && RN_Buff_Rarity(id) != rarity) continue;
        if (excludeTransforms && (id == PLAYBUFF_YUXI || id == PLAYBUFF_FANXING)) continue;
        int weight = rarity >= 0 ? 1 : RN_Config_Int(view_as<RN_ConfigKey>(view_as<int>(RN_CVAR_RARITY_WEIGHT_COMMON) + RN_Buff_Rarity(id)));
        int next;
        if (!RN_Math_Add(total, weight, next)) return false;
        total = next;
    }
    if (total <= 0) return false;
    int pick = GetRandomInt(1, total);
    for (int id = 1; id < MAXBUFFENUM; id++)
    {
        if (!RN_Buff_Allowed(id, profession)) continue;
        if (rarity >= 0 && RN_Buff_Rarity(id) != rarity) continue;
        if (excludeTransforms && (id == PLAYBUFF_YUXI || id == PLAYBUFF_FANXING)) continue;
        int weight = rarity >= 0 ? 1 : RN_Config_Int(view_as<RN_ConfigKey>(view_as<int>(RN_CVAR_RARITY_WEIGHT_COMMON) + RN_Buff_Rarity(id)));
        pick -= weight;
        if (pick <= 0) { buff = id; return true; }
    }
    return false;
}

/** 一次准备三张独立卡片，允许重复；任一失败都不写档案。 */
bool RN_Pool_Options(int options[RN_OPTIONS], int profession = RN_PROFESSION_NONE)
{
    int result[RN_OPTIONS];
    for (int i = 0; i < RN_OPTIONS; i++)
        if (!RN_Pool_Draw(result[i], -1, false, profession)) return false;
    for (int i = 0; i < RN_OPTIONS; i++) options[i] = result[i];
    return true;
}
