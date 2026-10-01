#if defined _rn_config_included
 #endinput
#endif
#define _rn_config_included

enum RN_ConfigKey
{
    RN_CVAR_ENABLE,
    RN_CVAR_DEBUG,
    RN_CVAR_INITIAL_CHOICES,
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
    RN_CVAR_SCALING_IGNORE_EMPTY,
    RN_CVAR_SCALING_MAX_TIER,
    RN_CVAR_SCALING_ANNOUNCE,
    RN_CVAR_DOUBLETAP_MS,
    RN_CVAR_REMIND_ENABLE,
    RN_CVAR_REMIND_INTERVAL,
    RN_CVAR_AUTO_BIND,
    RN_CVAR_JOIN_TIP,
    RN_CVAR_MENU_IN_COMBAT,
    RN_CVAR_FANXING_CHOICES,
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
    RN_CVAR_MAGAZINEMULTIPLE_SURV,
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

/** 由统一定义登记全部参数；BUFF数值沿用旧版，三个章节难度参数除外。 */
void RN_Config_BuildDefinitions()
{
    RN_Config_Define(RN_CVAR_ENABLE, "rne_enable", "1",
        "启用肉鸽；关闭保留档案并撤销效果", true, 0.0000, 1.0000);
    RN_Config_Define(RN_CVAR_DEBUG, "rne_debug", "0",
        "启用经验与生命周期调试日志", true, 0.0000, 1.0000);
    RN_Config_Define(RN_CVAR_INITIAL_CHOICES, "rne_initial_choices", "0",
        "本战役初始选择预算，下场生效", true, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_CHOICES_PER_LEVEL, "rne_choices_per_level", "1",
        "每个团队等级的基础选择预算，下场生效", true, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_INITIAL_ROLLS, "rne_initial_rolls", "5",
        "初始ROLL次数，下场生效", true, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_XP_BASE, "rne_xp_base", "100",
        "4人基准首级需求", false, 1.0000, -1.0);
    RN_Config_Define(RN_CVAR_XP_STEP, "rne_xp_step", "54",
        "每升一级增加的基准需求", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_XP_NEED_CAP, "rne_xp_need_cap", "1200",
        "单级需求上限；先封顶再按人数缩放", false, 1.0000, -1.0);
    RN_Config_Define(RN_CVAR_XP_SMOKER, "rne_xp_smoker", "10",
        "直接击杀Smoker的基准团队经验，乘游戏难度倍率；0关闭该类经验", true, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_XP_BOOMER, "rne_xp_boomer", "5",
        "直接击杀Boomer的基准团队经验，乘游戏难度倍率；0关闭该类经验", true, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_XP_HUNTER, "rne_xp_hunter", "12",
        "直接击杀Hunter的基准团队经验，乘游戏难度倍率；0关闭该类经验", true, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_XP_SPITTER, "rne_xp_spitter", "10",
        "直接击杀Spitter的基准团队经验，乘游戏难度倍率；0关闭该类经验", true, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_XP_JOCKEY, "rne_xp_jockey", "12",
        "直接击杀Jockey的基准团队经验，乘游戏难度倍率；0关闭该类经验", true, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_XP_CHARGER, "rne_xp_charger", "15",
        "直接击杀Charger的基准团队经验，乘游戏难度倍率；0关闭该类经验", true, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_XP_WITCH, "rne_xp_witch", "40",
        "直接击杀Witch的基准团队经验，乘游戏难度倍率；0关闭该类经验", true, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_XP_TANK, "rne_xp_tank", "100",
        "直接击杀Tank的基准团队经验，乘游戏难度倍率；0关闭该类经验", true, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_XP_RATE_EASY, "rne_xp_rate_easy", "3.0",
        "简单难度Easy的击杀经验倍率，0关闭该难度击杀经验", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_XP_RATE_NORMAL, "rne_xp_rate_normal", "2.0",
        "普通难度Normal的击杀经验倍率，0关闭该难度击杀经验", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_XP_RATE_HARD, "rne_xp_rate_hard", "1.5",
        "高级难度Hard的击杀经验倍率，0关闭该难度击杀经验", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_XP_RATE_EXPERT, "rne_xp_rate_expert", "1.0",
        "专家难度Impossible的击杀经验倍率，0关闭该难度击杀经验", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_XP_COUNT_BOTS, "rne_xp_count_bots", "1",
        "生还者BOT直接击杀是否计入经验", true, 0.0000, 1.0000);
    RN_Config_Define(RN_CVAR_XP_SCALE_BY_PLAYERS, "rne_xp_scale_by_players", "1",
        "按生还者总人数（含BOT）缩放需求", true, 0.0000, 1.0000);
    RN_Config_Define(RN_CVAR_XP_BASELINE_PLAYERS, "rne_xp_baseline_players", "4",
        "经验缩放基准人数", true, 1.0000, -1.0);
    RN_Config_Define(RN_CVAR_XP_FLAT_UNTIL_PLAYERS, "rne_xp_flat_until_players", "1",
        "经验缩放人数下限", true, 1.0000, -1.0);
    RN_Config_Define(RN_CVAR_XP_SCALE_MIN, "rne_xp_scale_min", "0.25",
        "人数缩放系数下限", false, 0.0001, -1.0);
    RN_Config_Define(RN_CVAR_XP_SCALE_MAX, "rne_xp_scale_max", "4.0",
        "人数缩放系数上限", false, 0.0001, -1.0);
    RN_Config_Define(RN_CVAR_SCALING_ENABLE, "rne_scaling_enable", "1",
        "启用时间难度；关闭暂停难度时钟", true, 0.0000, 1.0000);
    RN_Config_Define(RN_CVAR_SCALING_INTERVAL_MIN, "rne_scaling_interval_min", "5",
        "每档所需有效游戏分钟", false, 0.0001, -1.0);
    RN_Config_Define(RN_CVAR_SCALING_WAIT_LEAVESAFE, "rne_scaling_wait_leavesafe", "1",
        "等待首次出门启动时钟", true, 0.0000, 1.0000);
    RN_Config_Define(RN_CVAR_HP_PER_TIER, "rne_hp_per_tier", "0.067",
        "每档感染者血量增量", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_DMG_PER_TIER, "rne_dmg_per_tier", "0.067",
        "每档感染者伤害增量", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_TANK_SPEED_PER_TIER, "rne_tank_speed_per_tier", "0.033",
        "每档Tank移速增量", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_TANK_HP_FACTOR, "rne_tank_hp_factor", "2.0",
        "Tank出生额外血量倍率", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_TANK_COUNT_SCALING, "rne_tank_count_scaling", "1",
        "Tank出生时按N/4额外缩放血量", true, 0.0000, 1.0000);
    RN_Config_Define(RN_CVAR_SCALING_IGNORE_EMPTY, "rne_scaling_ignore_empty", "1",
        "无真人连接时暂停难度时钟", true, 0.0000, 1.0000);
    RN_Config_Define(RN_CVAR_SCALING_MAX_TIER, "rne_scaling_max_tier", "0",
        "难度档位上限，0不限", true, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_SCALING_ANNOUNCE, "rne_scaling_announce", "1",
        "公告开局和难度档位", true, 0.0000, 1.0000);
    RN_Config_Define(RN_CVAR_DOUBLETAP_MS, "rne_doubletap_ms", "300",
        "K/L命令的双击窗口毫秒", true, 1.0000, -1.0);
    RN_Config_Define(RN_CVAR_REMIND_ENABLE, "rne_remind_enable", "1",
        "启用私聊待选提醒", true, 0.0000, 1.0000);
    RN_Config_Define(RN_CVAR_REMIND_INTERVAL, "rne_remind_interval", "300",
        "私聊提醒间隔秒数", false, 0.0100, -1.0);
    RN_Config_Define(RN_CVAR_AUTO_BIND, "rne_auto_bind", "1",
        "尝试绑定K/L；不能保证客户端执行", true, 0.0000, 1.0000);
    RN_Config_Define(RN_CVAR_JOIN_TIP, "rne_join_tip", "1",
        "真人成为生还者时显示指令帮助", true, 0.0000, 1.0000);
    RN_Config_Define(RN_CVAR_MENU_IN_COMBAT, "rne_menu_in_combat", "0",
        "允许倒地或被控时选卡；不允许死者", true, 0.0000, 1.0000);
    RN_Config_Define(RN_CVAR_FANXING_CHOICES, "rne_fanxing_choices", "10",
        "繁星兑换历史预算后发放的新次数", true, 1.0000, -1.0);
    RN_Config_Define(RN_CVAR_MELEE_BASE_DAMAGE, "rne_melee_base_damage", "500.0",
        "近战基础伤害", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_CRIT_BASE_MULTIPLIER, "rne_crit_base_multiplier", "1.5",
        "基础暴击乘区", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_TANK_DISARM_CHANCE, "rne_tank_disarm_chance", "20",
        "Tank被近战攻击时缴械概率百分比", true, 0.0000, 100.0000);
    RN_Config_Define(RN_CVAR_ADDMAXHEALTH_SURV, "rne_addmaxhealth_surv", "50",
        "先点到40增加多少血量上限", true, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_HEALHP_SURV, "rne_healhp_surv", "1.0",
        "奶一口每秒回多少血量", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_ADDMULTIPLE_SURV, "rne_addmultiple_surv", "0.20",
        "认真一拳增加多少倍伤害", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_PUTONGQUANPU_ADDMULTIPLE_SURV, "rne_putongquanpu_addmultiple_surv", "0.1",
        "普通一拳增加多少倍伤害", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_SUBMULTIPLE_SURV, "rne_submultiple_surv", "0.1",
        "因为怕痛减免多少倍伤害", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_PROBINVINCIBILITY_SURV, "rne_probinvincibility_surv", "10",
        "下次一定增加多少几率免疫控制", true, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_POWANGFA_PROBINVINCIBILITY_SURV, "rne_powangfa_probinvincibility_surv", "100",
        "破万法增加多少几率免疫控制", true, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_PROBIGNITE_SURV, "rne_probignite_surv", "4",
        "火之高兴增加多少几率点燃目标", true, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_IGNITEDURATION_SURV, "rne_igniteduration_surv", "3.0",
        "火之高兴点燃目标持续多少秒", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_PROBFREEZE_SURV, "rne_probfreeze_surv", "2",
        "霜之哀伤增加多少几率冰冻目标", true, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_FREEZEDURATION_SURV, "rne_freezeduration_surv", "2.0",
        "霜之哀伤冰冻目标持续多少秒", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_NEVERFALLNUM_SURV, "rne_neverfallnum_surv", "3",
        "读档战神倒地复活多少次", true, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_NEVERFALLHEALTH_SURV, "rne_neverfallhealth_surv", "100",
        "读档战神倒地复活多少血", true, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_MAGAZINEMULTIPLE_SURV, "rne_magazinemultiple_surv", "0.03",
        "弹药专家增加多少倍弹匣容量", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_RELOADSPEEDMULTIPLE_SURV, "rne_reloadspeedmultiple_surv", "0.03",
        "搞快点增加多少倍换弹速度", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_FIRERATEMULTIPLE_SURV, "rne_fireratemultiple_surv", "0.03",
        "连射狂人增加多少倍射击速度", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_MOVESPEEDMULTIPLE_SURV, "rne_movespeedmultiple_surv", "0.2",
        "风行者增加多少倍移动速度", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_LUOYANEBU_MOVESPEEDMULTIPLE_SURV, "rne_luoyanebu_movespeedmultiple_surv", "0.1",
        "罗烟步增加多少倍移动速度", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_GLASSCANNON_DAMAGE_SURV, "rne_glasscannon_damage_surv", "0.5",
        "玻璃大炮增加多少倍伤害", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_GLASSCANNON_DAMAGEREDUCTION_SURV, "rne_glasscannon_damagereduction_surv", "0.5",
        "玻璃大炮减少多少免伤比例", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_PYROMANIAC_PROBIGNITE_SURV, "rne_pyromaniac_probignite_surv", "8",
        "纵火狂增加多少点燃几率", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_PYROMANIAC_DMGREDUCTION_SURV, "rne_pyromaniac_dmgreduction_surv", "0.10",
        "纵火狂减少多少倍伤害", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_CRYOPHILIA_PROBFREEZE_SURV, "rne_cryophilia_probfreeze_surv", "4",
        "多冻症增加多少冰冻几率", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_CRYOPHILIA_DMGREDUCTION_SURV, "rne_cryophilia_dmgreduction_surv", "0.10",
        "多冻症减少多少倍伤害", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_DAMOCLESSWORD_DEATHPROB_SURV, "rne_damoclessword_deathprob_surv", "10",
        "达摩之剑每万分之多少概率即死", true, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_ZHAOZAI_SPAWNTANKPROB_SURV, "rne_zhaozai_spawntankprob_surv", "20",
        "招灾每万分之多少概率生成Tank", true, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_IMMOVABLE_MAXHEALTH_SURV, "rne_immovable_maxhealth_surv", "200",
        "不动如山增加多少点血量上限", true, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_IMMOVABLE_MOVESPEEDREDUCTION_SURV, "rne_immovable_movespeedreduction_surv", "0.1",
        "不动如山减少多少倍移动速度", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_DUOBAOXIANREN_ROLLBONUS_SURV, "rne_duobaoxianren_rollbonus_surv", "3",
        "多宝仙人增加多少次ROLL次数", true, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_SHILENBAODI_ROLLBONUS_SURV, "rne_shilenbaodi_rollbonus_surv", "10",
        "十连保底增加多少次ROLL次数", true, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_TIANXINGJIAN_SUBMULTIPLE_SURV, "rne_tianxingjian_submultiple_surv", "0.3",
        "天行健减免多少倍伤害", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_TIANXINGJIAN_HEALHP_SURV, "rne_tianxingjian_healhp_surv", "3.0",
        "天行健每秒回多少血量", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_SHEXINGZOUWEI_DODGECHANCE_SURV, "rne_shexingzouwei_dodgechance_surv", "10.0",
        "蛇形走位闪避伤害的百分比概率", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_ZIZAIJIYI_DODGECHANCE_SURV, "rne_zizaijiyi_dodgechance_surv", "20.0",
        "自在极意闪避伤害的百分比概率", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_YIJIANSANLIAN_DAMAGE_SURV, "rne_yijiansanlian_damage_surv", "0.10",
        "一键三连增加多少倍伤害", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_YIJIANSANLIAN_MAXHEALTH_SURV, "rne_yijiansanlian_maxhealth_surv", "50",
        "一键三连增加多少血量上限", true, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_YIJIANSANLIAN_HEALHP_SURV, "rne_yijiansanlian_healhp_surv", "1.0",
        "一键三连每秒回多少血量", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_ZHIMINGYIJI_CRITRATE_SURV, "rne_zhimingyiji_critrate_surv", "0.05",
        "致命一鸡增加多少暴击率", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_AIYOUWEI_CRITRATE_SURV, "rne_aiyouwei_critrate_surv", "0.1",
        "哎呦喂增加多少暴击率", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_JIANSHENG_CRITDAMAGE_SURV, "rne_jiansheng_critdamage_surv", "0.25",
        "剑圣增加多少暴击伤害倍率", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_HUANYINGCIKE_CRITDAMAGE_SURV, "rne_huanyingcike_critdamage_surv", "0.5",
        "幻影刺客增加多少暴击伤害倍率", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_QIANGYUN_PROBBONUS_SURV, "rne_qiangyun_probbonus_surv", "0.5",
        "强运增加多少概率加成倍率", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_BAOTIANMA_MELEEDAMAGE_SURV, "rne_baotianma_meleedamage_surv", "0.10",
        "包甜吗增加多少倍近战伤害", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_SANDAOLIU_MELEEDAMAGE_SURV, "rne_sandaoliu_meleedamage_surv", "0.20",
        "三刀流增加多少倍近战伤害", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_JIEWANGQUAN_MELEEDAMAGE_SURV, "rne_jiewangquan_meleedamage_surv", "1.50",
        "界王拳增加多少倍近战伤害", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_RARITY_WEIGHT_COMMON, "rne_rarity_weight_common", "100",
        "普通稀有度BUFF的权重", true, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_RARITY_WEIGHT_RARE, "rne_rarity_weight_rare", "50",
        "稀有稀有度BUFF的权重", true, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_RARITY_WEIGHT_EPIC, "rne_rarity_weight_epic", "10",
        "史诗稀有度BUFF的权重", true, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_RARITY_WEIGHT_LEGENDARY, "rne_rarity_weight_legendary", "1",
        "传说稀有度BUFF的权重", true, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_FAITH_RARE_THRESHOLD, "rne_faith_rare_threshold", "3",
        "信念层数达到多少时激发稀有奖励", true, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_FAITH_EPIC_THRESHOLD, "rne_faith_epic_threshold", "6",
        "信念层数达到多少时激发史诗奖励", true, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_FAITH_LEGENDARY_THRESHOLD, "rne_faith_legendary_threshold", "9",
        "信念层数达到多少时激发传说奖励", true, 0.0000, -1.0);
}

/** 创建所有ConVar后统一挂钩，避免创建一半时触发读取。 */
void RN_Config_Init()
{
    RN_Config_BuildDefinitions();
    CreateConVar("rne_version", RN_VERSION, "rogue-next版本", FCVAR_NOTIFY|FCVAR_DONTRECORD);
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
    int weightSum;
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

