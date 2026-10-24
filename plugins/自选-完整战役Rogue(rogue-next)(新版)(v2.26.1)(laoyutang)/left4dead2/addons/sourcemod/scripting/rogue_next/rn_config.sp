#if defined _rn_config_included
 #endinput
#endif
#define _rn_config_included

enum RN_ConfigKey
{
    RN_CVAR_ENABLE,
    RN_CVAR_DEBUG,
    RN_CVAR_INITIAL_CHOICES_EASY,
    RN_CVAR_INITIAL_CHOICES_NORMAL,
    RN_CVAR_INITIAL_CHOICES_HARD,
    RN_CVAR_INITIAL_CHOICES_EXPERT,
    RN_CVAR_CHOICES_PER_LEVEL,
    RN_CVAR_INITIAL_ROLLS,
    RN_CVAR_XP_BASE,
    RN_CVAR_XP_STEP,
    RN_CVAR_XP_NEED_CAP,
    RN_CVAR_XP_SMOKER,
    RN_CVAR_XP_BOOMER,
    RN_CVAR_XP_HUNTER,
    RN_CVAR_XP_SPITTER,
    RN_CVAR_XP_JOCKEY,
    RN_CVAR_XP_CHARGER,
    RN_CVAR_XP_WITCH,
    RN_CVAR_XP_TANK,
    RN_CVAR_XP_RATE_EASY,
    RN_CVAR_XP_RATE_NORMAL,
    RN_CVAR_XP_RATE_HARD,
    RN_CVAR_XP_RATE_EXPERT,
    RN_CVAR_XP_COUNT_BOTS,
    RN_CVAR_XP_SCALE_BY_PLAYERS,
    RN_CVAR_XP_BASELINE_PLAYERS,
    RN_CVAR_XP_FLAT_UNTIL_PLAYERS,
    RN_CVAR_XP_SCALE_MIN,
    RN_CVAR_XP_SCALE_MAX,
    RN_CVAR_SCALING_ENABLE,
    RN_CVAR_SCALING_INTERVAL_MIN,
    RN_CVAR_SCALING_WAIT_LEAVESAFE,
    RN_CVAR_HP_PER_TIER,
    RN_CVAR_DMG_PER_TIER,
    RN_CVAR_TANK_SPEED_PER_TIER,
    RN_CVAR_TANK_HP_FACTOR,
    RN_CVAR_TANK_COUNT_SCALING,
    RN_CVAR_WITCH_HP_FACTOR,
    RN_CVAR_WITCH_COUNT_SCALING,
    RN_CVAR_SCALING_IGNORE_EMPTY,
    RN_CVAR_SCALING_MAX_TIER,
    RN_CVAR_SCALING_ANNOUNCE,
    RN_CVAR_REMIND_ENABLE,
    RN_CVAR_REMIND_INTERVAL,
    RN_CVAR_JOIN_TIP,
    RN_CVAR_MENU_IN_COMBAT,
    RN_CVAR_FANXING_CHOICES,
    RN_CVAR_FANXING_PERCENT,
    RN_CVAR_MELEE_BASE_DAMAGE,
    RN_CVAR_CRIT_BASE_MULTIPLIER,
    RN_CVAR_TANK_DISARM_CHANCE,
    RN_CVAR_ADDMAXHEALTH_SURV,
    RN_CVAR_HEALHP_SURV,
    RN_CVAR_ADDMULTIPLE_SURV,
    RN_CVAR_PUTONGQUANPU_ADDMULTIPLE_SURV,
    RN_CVAR_SUBMULTIPLE_SURV,
    RN_CVAR_PROBINVINCIBILITY_SURV,
    RN_CVAR_POWANGFA_PROBINVINCIBILITY_SURV,
    RN_CVAR_PROBIGNITE_SURV,
    RN_CVAR_IGNITEDURATION_SURV,
    RN_CVAR_PROBFREEZE_SURV,
    RN_CVAR_FREEZEDURATION_SURV,
    RN_CVAR_NEVERFALLNUM_SURV,
    RN_CVAR_NEVERFALLHEALTH_SURV,
    RN_CVAR_NEVERFALL_PROTECTION_TIME,
    RN_CVAR_RELOADSPEEDMULTIPLE_SURV,
    RN_CVAR_FIRERATEMULTIPLE_SURV,
    RN_CVAR_MOVESPEEDMULTIPLE_SURV,
    RN_CVAR_LUOYANEBU_MOVESPEEDMULTIPLE_SURV,
    RN_CVAR_GLASSCANNON_DAMAGE_SURV,
    RN_CVAR_GLASSCANNON_DAMAGEREDUCTION_SURV,
    RN_CVAR_PYROMANIAC_PROBIGNITE_SURV,
    RN_CVAR_PYROMANIAC_DMGREDUCTION_SURV,
    RN_CVAR_CRYOPHILIA_PROBFREEZE_SURV,
    RN_CVAR_CRYOPHILIA_DMGREDUCTION_SURV,
    RN_CVAR_DAMOCLESSWORD_DEATHPROB_SURV,
    RN_CVAR_ZHAOZAI_SPAWNTANKPROB_SURV,
    RN_CVAR_IMMOVABLE_MAXHEALTH_SURV,
    RN_CVAR_IMMOVABLE_MOVESPEEDREDUCTION_SURV,
    RN_CVAR_DUOBAOXIANREN_ROLLBONUS_SURV,
    RN_CVAR_SHILENBAODI_ROLLBONUS_SURV,
    RN_CVAR_TIANXINGJIAN_SUBMULTIPLE_SURV,
    RN_CVAR_TIANXINGJIAN_HEALHP_SURV,
    RN_CVAR_SHEXINGZOUWEI_DODGECHANCE_SURV,
    RN_CVAR_ZIZAIJIYI_DODGECHANCE_SURV,
    RN_CVAR_YIJIANSANLIAN_DAMAGE_SURV,
    RN_CVAR_YIJIANSANLIAN_MAXHEALTH_SURV,
    RN_CVAR_YIJIANSANLIAN_HEALHP_SURV,
    RN_CVAR_ZHIMINGYIJI_CRITRATE_SURV,
    RN_CVAR_AIYOUWEI_CRITRATE_SURV,
    RN_CVAR_JIANSHENG_CRITDAMAGE_SURV,
    RN_CVAR_HUANYINGCIKE_CRITDAMAGE_SURV,
    RN_CVAR_QIANGYUN_PROBBONUS_SURV,
    RN_CVAR_BAOTIANMA_MELEEDAMAGE_SURV,
    RN_CVAR_SANDAOLIU_MELEEDAMAGE_SURV,
    RN_CVAR_JIEWANGQUAN_MELEEDAMAGE_SURV,
    RN_CVAR_RARITY_WEIGHT_COMMON,
    RN_CVAR_RARITY_WEIGHT_RARE,
    RN_CVAR_RARITY_WEIGHT_EPIC,
    RN_CVAR_RARITY_WEIGHT_LEGENDARY,
    RN_CVAR_FAITH_RARE_THRESHOLD,
    RN_CVAR_FAITH_EPIC_THRESHOLD,
    RN_CVAR_FAITH_LEGENDARY_THRESHOLD,
    RN_CVAR_IGNITE_BASE_DPS,
    RN_CVAR_PYROMANIAC_BURN_DPS_SURV,
    RN_CVAR_FLAMEHEART_BURN_BONUS_SURV,
    RN_CVAR_ELEMENT_EXPLOSION_ENABLE,
    RN_CVAR_ELEMENT_EXPLOSION_RADIUS,
    RN_CVAR_ELEMENT_EXPLOSION_SPLASH_FACTOR,
    RN_CVAR_PROFESSION_ENABLE,
    RN_CVAR_GUNSLINGER_DAMAGE_PER_LEVEL,
    RN_CVAR_BLADEMASTER_ATTACK_SPEED_BONUS,
    RN_CVAR_ELEMENTALIST_PROBABILITY_BONUS,
    RN_CVAR_SNIPER_DAMAGE_PER_100_UNITS,
    RN_CVAR_SNIPER_MAX_DISTANCE,
    RN_CVAR_BERSERKER_HEAL,
    RN_CVAR_ORA_ATTACK_SPEED_BONUS,
    RN_CVAR_DUAL_ELEMENT_IGNITE_CHANCE,
    RN_CVAR_DUAL_ELEMENT_FREEZE_CHANCE,
    RN_CVAR_DUAL_ELEMENT_DAMAGE_REDUCTION,
    RN_CVAR_ART_EXPLOSION_RADIUS_BONUS,
    RN_CVAR_EXPOSED_DAMAGE_PER_100_UNITS,
    RN_CVAR_RISE_SNIPER_DAMAGE_BONUS,
    RN_CVAR_DAILY_TRAINING_DAMAGE_PER_LEVEL,
    RN_CVAR_TENACITY_CONTROL_CHANCE,
    RN_CVAR_EXPLOSIVE_BULLET_CHANCE,
    RN_CVAR_EXPLOSIVE_BULLET_RADIUS,
    RN_CVAR_DAMAGE_STATS_ENABLE,
    RN_CVAR_DAMAGE_STATS_TOP,
    RN_CVAR_SNIPER_START_WEAPON,
    RN_CVAR_BLADEMASTER_DISARM_IMMUNITY,
    RN_CVAR_ELEMENT_EXPLOSION_CRIT_ENABLE,
    RN_CVAR_HUD_ENABLE,
    RN_CVAR_HUD_TOP,
    RN_CVAR_SWORD_WAVE_ENABLE,
    RN_CVAR_SWORD_WAVE_RANGE,
    RN_CVAR_SWORD_WAVE_SPEED,
    RN_CVAR_SWORD_WAVE_HALFWIDTH,
    RN_CVAR_SWORD_WAVE_MAX_HITS,
    RN_CVAR_SWORD_PIERCE_HITS,
    RN_CVAR_SWORD_REACH_DISTANCE,
    RN_CVAR_SWORD_WAVE_DAMAGE_FACTOR,
    RN_CVAR_DISASTER_ENABLE,
    RN_CVAR_DISASTER_CHANCE_EASY,
    RN_CVAR_DISASTER_CHANCE_NORMAL,
    RN_CVAR_DISASTER_CHANCE_HARD,
    RN_CVAR_DISASTER_CHANCE_EXPERT,
    RN_CVAR_DISASTER_WEIGHT_ELEMENT,
    RN_CVAR_DISASTER_WEIGHT_PHYSICAL,
    RN_CVAR_DISASTER_WEIGHT_MUD,
    RN_CVAR_DISASTER_WEIGHT_MONSOON,
    RN_CVAR_DISASTER_WEIGHT_PUNISHMENT,
    RN_CVAR_DISASTER_ELEMENT_PER_TIER,
    RN_CVAR_DISASTER_ELEMENT_CAP,
    RN_CVAR_DISASTER_PHYSICAL_PER_TIER,
    RN_CVAR_DISASTER_PHYSICAL_CAP,
    RN_CVAR_DISASTER_MUD_PER_TIER,
    RN_CVAR_DISASTER_MUD_CAP,
    RN_CVAR_DISASTER_MONSOON_PER_TIER,
    RN_CVAR_DISASTER_MONSOON_CAP,
    RN_CVAR_DISASTER_PUNISHMENT_PER_TIER,
    RN_CVAR_DISASTER_PUNISHMENT_CAP,
    RN_CVAR_REAPER_DAMAGE_PER_KILL,
    RN_CVAR_REAPER_PENALTY_PER_KILL,
    RN_CVAR_DEMON_CONTRACT_DAMAGE_PER_KILL,
    RN_CVAR_DEMON_CONTRACT_PENALTY_PER_KILL,
    RN_CVAR_CONGXIN_PENALTY_REDUCTION,
    RN_CVAR_SOUL_DRAIN_HEAL,
    RN_CVAR_GRENADE_ENABLE,
    RN_CVAR_GRENADE_DAMAGE,
    RN_CVAR_GRENADE_RADIUS,
    RN_CVAR_GRENADE_BOUNCE_SPEED,
    RN_CVAR_GRENADE_RETENTION,
    RN_CVAR_GRENADE_SPLIT_SPEED,
    RN_CVAR_GRENADE_SPLIT_ANGLE,
    RN_CVAR_MAGICIAN_START_WEAPON,
    RN_CVAR_MAGICIAN_BOUNCES,
    RN_CVAR_MAGICIAN_SPLIT_CHANCE,
    RN_CVAR_PINGPONG_BOUNCES,
    RN_CVAR_BIG_SCENE_SPLIT_CHANCE,
    RN_CVAR_BIG_SCENE_BOUNCE_PENALTY,
    RN_CVAR_GRENADE_BOUNCE_DAMAGE_DECAY,
    RN_CVAR_BIABIABIA_GUN_DAMAGE,
    RN_CVAR_PATRICK_EXPLOSION_DAMAGE_BONUS,
    RN_CVAR_PATRICK_EXPLOSION_RADIUS_BONUS,
    RN_CVAR_ELECTRIC_ENABLE,
    RN_CVAR_ELECTRIC_BASE_DAMAGE,
    RN_CVAR_ELECTRIC_JUMPS,
    RN_CVAR_ELECTRIC_DECAY,
    RN_CVAR_ELECTRIC_RADIUS,
    RN_CVAR_ELECTRIC_INTERVAL,
    RN_CVAR_ELECTRIC_COOLDOWN,
    RN_CVAR_ELECTRIC_FIRE_ENABLE,
    RN_CVAR_ELECTRIC_ADDICT_CHANCE,
    RN_CVAR_SUPERCONDUCTOR_JUMPS,
    RN_CVAR_FIVE_WHIP_CHANCE,
    RN_CVAR_FIVE_WHIP_DAMAGE,
    RN_CVAR_FIVE_WHIP_GUN_COST,
    RN_CVAR_THUNDER_KING_BONUS,
    RN_CVAR_KNIGHT_HEALTH_BONUS,
    RN_CVAR_KNIGHT_HEALTH_PER_LEVEL,
    RN_CVAR_KNIGHT_ATTACK_HP_RATIO,
    RN_CVAR_KNIGHT_BURST_HITS,
    RN_CVAR_KNIGHT_BURST_MIN_HITS,
    RN_CVAR_KNIGHT_HIT_INTERVAL,
    RN_CVAR_KNIGHT_BURST_BASE_DAMAGE,
    RN_CVAR_KNIGHT_BURST_HP_RATIO,
    RN_CVAR_KNIGHT_BURST_RADIUS,
    RN_CVAR_KNIGHT_BURST_RADIUS_CAP,
    RN_CVAR_PAIN_PLEASURE_HEAL_RATIO,
    RN_CVAR_PAIN_PLEASURE_DURATION,
    RN_CVAR_BLOOD_VIGOR_HP_RATIO,
    RN_CVAR_LAST_STRAW_HITS_REDUCTION,
    RN_CVAR_COUNT
}


/** 每个参数的定义与类型约束；集中登记防止配置名/默认值分散。 */
enum struct RN_ConfigDefinition
{
    char name[64];
    char defaultValue[32];
    char description[256];
    bool integer;
    float minimum;
    float maximum;
}
RN_ConfigDefinition g_Config_Definitions[RN_CVAR_COUNT];
ConVar g_Config_Handles[RN_CVAR_COUNT];
float g_Config_Values[RN_CVAR_COUNT];
bool g_Config_Initialized;
bool g_Config_RollingBack;

/** 登记单个参数，maximum=-1表示没有额外数值上界。 */
void RN_Config_Define(RN_ConfigKey key, const char[] name, const char[] value,
                      const char[] description, bool integer, float minimum, float maximum)
{
    strcopy(g_Config_Definitions[key].name, 64, name);
    strcopy(g_Config_Definitions[key].defaultValue, 32, value);
    strcopy(g_Config_Definitions[key].description, 256, description);
    g_Config_Definitions[key].integer = integer;
    g_Config_Definitions[key].minimum = minimum;
    g_Config_Definitions[key].maximum = maximum;
}

#include "rn_config_defs.sp"
#include "rn_disaster_config.sp"

/** 创建所有ConVar后统一挂钩，避免创建一半时触发读取。 */
void RN_Config_Init()
{
    RN_Config_BuildDefinitions();
    CreateConVar("rne_version", RN_VERSION, "rogue-next版本", FCVAR_NOTIFY|FCVAR_DONTRECORD);
    RN_Knight_LegacyConfig();
    for (int i = 0; i < view_as<int>(RN_CVAR_COUNT); i++)
        g_Config_Handles[i] = CreateConVar(g_Config_Definitions[i].name,
            g_Config_Definitions[i].defaultValue, g_Config_Definitions[i].description, FCVAR_NOTIFY);
    for (int i = 0; i < view_as<int>(RN_CVAR_COUNT); i++)
        g_Config_Handles[i].AddChangeHook(RN_Config_OnChanged);
    if (!RN_Config_Read())
    {
        LogError("[rogue-next] 首载已有ConVar非法，恢复整组内置默认值。");
        if (!RN_Config_RestoreDefaults()) SetFailState("rogue-next内置默认配置未通过校验。");
    }
    g_Config_Initialized = true;
    AutoExecConfig(true, "rogue_next");
}

/** 首载可能复用服务器留下的ConVar；整组回到默认值后重新验证，不保留半组候选。 */
bool RN_Config_RestoreDefaults()
{
    g_Config_RollingBack = true;
    for (int i = 0; i < view_as<int>(RN_CVAR_COUNT); i++)
        g_Config_Handles[i].SetString(g_Config_Definitions[i].defaultValue);
    g_Config_RollingBack = false;
    return RN_Config_Read();
}

/** 读取最后一份通过整组验证的浮点值，不读取正在修改的ConVar。 */
float RN_Config_Float(RN_ConfigKey key)
{
    return g_Config_Values[key];
}

/** 整数参数在配置验证时已校验整数与范围。 */
int RN_Config_Int(RN_ConfigKey key)
{
    return RoundToZero(g_Config_Values[key]);
}

/** 从所有ConVar准备候选配置，整组验证失败时保留全部旧值。 */
bool RN_Config_Read()
{
    float values[RN_CVAR_COUNT];
    for (int i = 0; i < view_as<int>(RN_CVAR_COUNT); i++)
    {
        char text[64];
        g_Config_Handles[i].GetString(text, sizeof(text));
        int integer;
        if (text[0] == '\0' || (g_Config_Definitions[i].integer && !RN_Common_ParseUnsigned(text, integer)) ||
            (!g_Config_Definitions[i].integer && StringToFloatEx(text, values[i]) != strlen(text)))
        {
            LogError("[rogue-next] 参数%s不是合法数字，保留原配置。", g_Config_Definitions[i].name);
            return false;
        }
        if (g_Config_Definitions[i].integer)
        {
            values[i] = float(integer);
            if (values[i] >= RN_INT_FLOAT_LIMIT || RoundToZero(values[i]) != integer)
            {
                LogError("[rogue-next] 参数%s超出精确整数范围。", g_Config_Definitions[i].name);
                return false;
            }
        }
        if (!RN_Math_Finite(values[i]) || values[i] < g_Config_Definitions[i].minimum ||
            (g_Config_Definitions[i].maximum >= 0.0 && values[i] > g_Config_Definitions[i].maximum) ||
            (g_Config_Definitions[i].integer && (values[i] >= RN_INT_FLOAT_LIMIT ||
             values[i] != float(RoundToZero(values[i])))))
        {
            LogError("[rogue-next] 非法参数 %s；保留上一份合法配置。", g_Config_Definitions[i].name);
            return false;
        }
    }
    if (values[RN_CVAR_XP_NEED_CAP] < values[RN_CVAR_XP_BASE] ||
        values[RN_CVAR_XP_SCALE_MAX] < values[RN_CVAR_XP_SCALE_MIN] ||
        values[RN_CVAR_FAITH_RARE_THRESHOLD] >= values[RN_CVAR_FAITH_EPIC_THRESHOLD] ||
        values[RN_CVAR_FAITH_EPIC_THRESHOLD] >= values[RN_CVAR_FAITH_LEGENDARY_THRESHOLD])
    {
        LogError("[rogue-next] 需求上限/人数比例/信念阈值组合无效；保留上一份合法配置。");
        return false;
    }
    // 每种基准XP与每档倍率的组合都必须有限，避免配置合法但后续击杀产生无穷经验。
    float maximumXP;
    for (int i = view_as<int>(RN_CVAR_XP_SMOKER); i <= view_as<int>(RN_CVAR_XP_TANK); i++)
        if (values[i] > maximumXP) maximumXP = values[i];
    for (int i = view_as<int>(RN_CVAR_XP_RATE_EASY); i <= view_as<int>(RN_CVAR_XP_RATE_EXPERT); i++)
        if (!RN_Math_Finite(maximumXP * values[i]))
        {
            LogError("[rogue-next] 参数%s与基准XP相乘溢出；保留上一份合法配置。", g_Config_Definitions[i].name);
            return false;
        }
    if (values[RN_CVAR_NEVERFALL_PROTECTION_TIME] >= RN_INT_FLOAT_LIMIT)
    {
        LogError("[rogue-next] 读档保护时间不可表达，保留原配置。");
        return false;
    }
    int weightSum;
    float burnBase = values[RN_CVAR_IGNITE_BASE_DPS] + values[RN_CVAR_PYROMANIAC_BURN_DPS_SURV];
    float burnTotal = burnBase * (1.0 + values[RN_CVAR_FLAMEHEART_BURN_BONUS_SURV]) * values[RN_CVAR_IGNITEDURATION_SURV];
    if (!RN_Math_Finite(burnTotal) || burnTotal >= RN_INT_FLOAT_LIMIT || burnBase >= RN_INT_FLOAT_LIMIT
        || values[RN_CVAR_IGNITEDURATION_SURV] >= RN_INT_FLOAT_LIMIT || values[RN_CVAR_FREEZEDURATION_SURV] >= RN_INT_FLOAT_LIMIT)
    {
        LogError("[rogue-next] 灼烧基础配置组合不可表达，保留原配置。");
        return false;
    }
    float electric = (values[RN_CVAR_ELECTRIC_BASE_DAMAGE] + values[RN_CVAR_FIVE_WHIP_DAMAGE])
        * (1.0 + values[RN_CVAR_THUNDER_KING_BONUS]);
    float electricChance = (values[RN_CVAR_ELECTRIC_ADDICT_CHANCE] + values[RN_CVAR_FIVE_WHIP_CHANCE])
        * (1.0 + values[RN_CVAR_ELEMENTALIST_PROBABILITY_BONUS]) * (1.0 + values[RN_CVAR_QIANGYUN_PROBBONUS_SURV]);
    if (!RN_Math_Finite(electric) || electric >= RN_INT_FLOAT_LIMIT || !RN_Math_Finite(electricChance)
        || !RN_Math_Finite(values[RN_CVAR_THUNDER_KING_BONUS] * 100.0)
        || values[RN_CVAR_ELECTRIC_COOLDOWN] >= RN_INT_FLOAT_LIMIT)
    {
        LogError("[rogue-next] 电元素基础配置组合不可表达，保留原配置。");
        return false;
    }
    for (int buff = 1; buff < MAXBUFFENUM; buff++)
    {
        int weight = RoundToZero(values[view_as<int>(RN_CVAR_RARITY_WEIGHT_COMMON) + RN_Buff_Rarity(buff)]);
        int next;
        if (!RN_Math_Add(weightSum, weight, next))
        {
            LogError("[rogue-next] BUFF总权重溢出；保留上一份合法配置。");
            return false;
        }
        weightSum = next;
    }
    if (weightSum <= 0)
    {
        LogError("[rogue-next] 全零BUFF权重被拒绝；保留上一份合法配置。");
        return false;
    }
    float previous[RN_CVAR_COUNT];
    if (!RN_Disaster_ValidateConfig(values)) return false;
    if (!RN_Profession_ValidateConfig(values)) return false;
    for (int i = 0; i < view_as<int>(RN_CVAR_COUNT); i++)
    {
        previous[i] = g_Config_Values[i];
        g_Config_Values[i] = values[i];
    }
    if (g_Config_Initialized && !RN_OnConfigValidate())
    {
        for (int i = 0; i < view_as<int>(RN_CVAR_COUNT); i++) g_Config_Values[i] = previous[i];
        LogError("[rogue-next] 候选配置令现有属性/预算不可表达，整组保留原配置。");
        return false;
    }
    RN_Profession_Refresh();
    return true;
}

/** 热修改通过整组验证后由入口同步时钟、菜单和实体属性。 */
public void RN_Config_OnChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (!g_Config_Initialized || g_Config_RollingBack) return;
    if (RN_Config_Read()) RN_OnConfigApplied();
    else
    {
        g_Config_RollingBack = true;
        convar.SetString(oldValue);
        g_Config_RollingBack = false;
    }
}

/** 当前地图与战役准备完毕且总开关打开，才允许BUFF和经验结算。 */
bool RN_Config_Enabled()
{
    return RN_Config_Int(RN_CVAR_ENABLE) != 0 && RN_Common_ActiveRun();
}
