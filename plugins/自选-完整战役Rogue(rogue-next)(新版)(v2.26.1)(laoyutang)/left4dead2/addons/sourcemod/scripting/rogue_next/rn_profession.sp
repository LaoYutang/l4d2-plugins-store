#if defined _rn_profession_included
 #endinput
#endif
#define _rn_profession_included

float g_Profession_SniperCapSquared;
float g_Profession_NextWarning;

/** 职业只占独立档案字段；关闭功能时全部职业数学回到中性值。 */
bool RN_Profession_Is(PlayerProfile profile, int profession)
{
    return RN_Config_Int(RN_CVAR_PROFESSION_ENABLE) != 0 && profile.profession == profession;
}

/** 菜单与通知共用稳定名称，不将职业插入BUFF编号。 */
void RN_Profession_Name(int profession, char[] text, int maxlength)
{
    static const char names[][] = {"未选择", "士兵", "剑客", "元素大师", "狙神", "死神", "艺术家", "十字骑士"};
    strcopy(text, maxlength, names[profession >= 0 && profession < RN_PROFESSION_COUNT ? profession : 0]);
}

/** 无效数值只留下节流诊断，不逐次命中写日志。 */
void RN_Profession_Warn(const char[] operation)
{
    float now = GetTickedTime();
    if (now < g_Profession_NextWarning) return;
    g_Profession_NextWarning = now + 10.0;
    LogError("[rogue-next] 职业计算拒绝不可表达的%s，保留原效果。", operation);
}

/** 联合验证倍率与上限距离平方，禁用时也验证参数供以后安全启用。 */
bool RN_Profession_ValidateConfig(const float values[RN_CVAR_COUNT])
{
    if (!RN_Knight_ValidateConfig(values)) return false;
    for (int key = view_as<int>(RN_CVAR_REAPER_DAMAGE_PER_KILL);
         key <= view_as<int>(RN_CVAR_DEMON_CONTRACT_PENALTY_PER_KILL); key++)
        if (!RN_Math_Finite(1.0 + values[key]) || 1.0 + values[key] >= RN_INT_FLOAT_LIMIT)
        {
            LogError("[rogue-next] 死神成长参数不可表达，保留原配置。");
            return false;
        }
    for (int key = view_as<int>(RN_CVAR_GUNSLINGER_DAMAGE_PER_LEVEL);
         key <= view_as<int>(RN_CVAR_EXPLOSIVE_BULLET_RADIUS); key++)
    {
        float factor = 1.0 + values[key];
        if (!RN_Math_Finite(factor) || factor >= RN_INT_FLOAT_LIMIT)
        {
            LogError("[rogue-next] 职业参数倍率不可表达，保留原配置。");
            return false;
        }
    }
    float distance = values[RN_CVAR_SNIPER_MAX_DISTANCE];
    float sniper = (1.0 + distance/100.0 * (values[RN_CVAR_SNIPER_DAMAGE_PER_100_UNITS]
        + values[RN_CVAR_EXPOSED_DAMAGE_PER_100_UNITS])) * (1.0 + values[RN_CVAR_RISE_SNIPER_DAMAGE_BONUS]);
    if (!RN_Math_Finite(distance * distance) || !RN_Math_Finite(sniper) || sniper >= RN_INT_FLOAT_LIMIT)
    {
        LogError("[rogue-next] 狙神上限距离不可表达，保留原配置。");
        return false;
    }
    return true;
}

/** 配置整组提交成功后预计算距离上限，命中时无需反复除法。 */
void RN_Profession_Refresh()
{
    float distance = RN_Config_Float(RN_CVAR_SNIPER_MAX_DISTANCE);
    g_Profession_SniperCapSquared = distance * distance;
}

/** 当前团队等级派生枪伤加算贡献，汇总时与通用增伤和元素代价共同计算。 */
float RN_Profession_GunBonus(PlayerProfile profile)
{
    if (!RN_Profession_Is(profile, RN_PROFESSION_GUNSLINGER)) return 0.0;
    return float(g_Run_Level) * RN_Profession_GunRate(profile);
}

/** 基础成长与日常训练每层增量加算，0级的查看仍显示当前每级成长。 */
float RN_Profession_GunRate(PlayerProfile profile)
{
    return RN_Profession_Is(profile, RN_PROFESSION_GUNSLINGER)
        ? RN_Config_Float(RN_CVAR_GUNSLINGER_DAMAGE_PER_LEVEL)
            + RN_Profession_Value(profile, PLAYBUFF_DAILY_TRAINING, RN_CVAR_DAILY_TRAINING_DAMAGE_PER_LEVEL) : 0.0;
}

/** 个人近战速度与间隔互为倒数，不借全队武器脚本实现。 */
float RN_Profession_MeleeFactor(PlayerProfile profile)
{
    return RN_Profession_Is(profile, RN_PROFESSION_BLADEMASTER)
        ? 1.0 + RN_Config_Float(RN_CVAR_BLADEMASTER_ATTACK_SPEED_BONUS)
            + RN_Profession_Value(profile, PLAYBUFF_ORA, RN_CVAR_ORA_ATTACK_SPEED_BONUS) : 1.0;
}

/** 元素倍率供点燃/冰冻/电击合并后、最终取整前使用。 */
float RN_Profession_ElementFactor(PlayerProfile profile)
{
    return RN_Profession_Is(profile, RN_PROFESSION_ELEMENTALIST)
        ? 1.0 + RN_Config_Float(RN_CVAR_ELEMENTALIST_PROBABILITY_BONUS) : 1.0;
}

/** 剑客抗缴械独立于免控概率；战斗与职业特性共用当前启用状态。 */
bool RN_Profession_DisarmImmune(PlayerProfile profile)
{
    return RN_Profession_Is(profile, RN_PROFESSION_BLADEMASTER)
        && RN_Config_Int(RN_CVAR_BLADEMASTER_DISARM_IMMUNITY) != 0;
}

/** 狙击距离平方达到上限则直接封顶，未封顶最多求一次平方根。 */
float RN_Profession_SniperFactor(PlayerProfile profile, float squared)
{
    if (!RN_Profession_Is(profile, RN_PROFESSION_SNIPER) || g_Profession_SniperCapSquared <= 0.0) return 1.0;
    if (!RN_Math_Finite(squared) || squared < 0.0) { RN_Profession_Warn("距离"); return 1.0; }
    float distance = squared >= g_Profession_SniperCapSquared
        ? RN_Config_Float(RN_CVAR_SNIPER_MAX_DISTANCE) : SquareRoot(squared);
    return 1.0 + distance / 100.0 * RN_Profession_SniperRate(profile);
}

/** 专属层数只在对应职业能力启用时参与，不销毁停用期间的存档。 */
float RN_Profession_Value(PlayerProfile profile, int buff, RN_ConfigKey key)
{
    return RN_Config_Int(RN_CVAR_PROFESSION_ENABLE) != 0 && RN_Buff_ProfessionMatches(buff, profile.profession)
        ? float(profile.buff[buff]) * RN_Config_Float(key) : 0.0;
}

/** 嗜血狂战每杀回复使用精确整数配置，溢出交给档案验证拒绝而不部分回血。 */
int RN_Profession_BerserkerHeal(PlayerProfile profile)
{
    if (!RN_Profession_Is(profile, RN_PROFESSION_BLADEMASTER)) return 0;
    int amount;
    return RN_Math_Multiply(profile.buff[PLAYBUFF_BERSERKER], RN_Config_Int(RN_CVAR_BERSERKER_HEAL), amount) ? amount : -1;
}

/** 剑客不再提供初始免控；士兵坚韧并入通用免控后统一乘强运。 */
float RN_Profession_Control(PlayerProfile profile)
{
    return RN_Profession_Value(profile, PLAYBUFF_TENACITY, RN_CVAR_TENACITY_CONTROL_CHANCE);
}

/** 无元素职业的限制不因职业加成暂时关闭而失效。 */
bool RN_Profession_NoElements(PlayerProfile profile)
{
    return profile.profession == RN_PROFESSION_BLADEMASTER || profile.profession == RN_PROFESSION_SNIPER
        || profile.profession == RN_PROFESSION_KNIGHT;
}

/** 剑气能力独立于攻速参数，零攻速加成仍可正常发出剑气。 */
bool RN_Profession_Sword(PlayerProfile profile)
{
    return RN_Profession_Is(profile, RN_PROFESSION_BLADEMASTER) && RN_Config_Int(RN_CVAR_SWORD_WAVE_ENABLE) != 0;
}

/** 发射和查看共用基础距离与纵横成长，先比较上界再乘层数。 */
float RN_Profession_SwordRange(PlayerProfile profile)
{
    if (!RN_Profession_Sword(profile)) return 0.0;
    float base = RN_Config_Float(RN_CVAR_SWORD_WAVE_RANGE);
    float step = RN_Config_Float(RN_CVAR_SWORD_REACH_DISTANCE);
    float layers = float(profile.buff[PLAYBUFF_SWORD_REACH]);
    if (step <= 0.0) return base;
    if (layers >= (RN_SWORD_RANGE_MAX - base) / step) return RN_SWORD_RANGE_MAX;
    return base + layers * step;
}

/** 伤害快照、查看比例和溢出校验读取同一个当前配置。 */
float RN_Profession_SwordDamageFactor(PlayerProfile profile)
{
    return RN_Profession_Sword(profile) ? RN_Config_Float(RN_CVAR_SWORD_WAVE_DAMAGE_FACTOR) : 0.0;
}

/** 先比较封顶所需层数，避免大量层数乘整数时溢出；查看与实战同源。 */
int RN_Profession_SwordHits(PlayerProfile profile)
{
    if (!RN_Profession_Sword(profile)) return 0;
    int base = RN_Config_Int(RN_CVAR_SWORD_WAVE_MAX_HITS);
    int step = RN_Config_Int(RN_CVAR_SWORD_PIERCE_HITS);
    int layers = profile.buff[PLAYBUFF_SWORD_PIERCE];
    if (step <= 0) return base;
    if (layers >= (32 - base + step - 1) / step) return 32;
    return base + layers * step;
}

/** 狙神和十字骑士固有禁用属性独立于暂时停用加成，旧层数也不能绕过。 */
bool RN_Profession_NoElementsOrControl(PlayerProfile profile)
{
    return profile.profession == RN_PROFESSION_SNIPER || profile.profession == RN_PROFESSION_KNIGHT;
}

/** 基础和露头就秒合并同一个距离系数，专属卡仍增加远端上限。 */
float RN_Profession_SniperRate(PlayerProfile profile)
{
    return RN_Profession_Is(profile, RN_PROFESSION_SNIPER)
        ? RN_Config_Float(RN_CVAR_SNIPER_DAMAGE_PER_100_UNITS)
            + RN_Profession_Value(profile, PLAYBUFF_EXPOSED, RN_CVAR_EXPOSED_DAMAGE_PER_100_UNITS) : 0.0;
}

/** 我起了同类加算后形成独立狙击倍率，枪械来源由战斗层核对。 */
float RN_Profession_SniperPower(PlayerProfile profile)
{
    return 1.0 + RN_Profession_Value(profile, PLAYBUFF_RISE, RN_CVAR_RISE_SNIPER_DAMAGE_BONUS);
}

/** 榴弹与冰火共用艺术增量，半径只读取引爆者；全局零仍关闭联动。 */
float RN_Profession_ExplosionRadius(PlayerProfile profile)
{
    float base = RN_Config_Float(RN_CVAR_ELEMENT_EXPLOSION_RADIUS);
    if (base <= 0.0) return 0.0;
    float radius = base + RN_Profession_Value(profile, PLAYBUFF_ART, RN_CVAR_ART_EXPLOSION_RADIUS_BONUS);
    return RN_Stats_ExplosionRadius(profile, radius);
}
