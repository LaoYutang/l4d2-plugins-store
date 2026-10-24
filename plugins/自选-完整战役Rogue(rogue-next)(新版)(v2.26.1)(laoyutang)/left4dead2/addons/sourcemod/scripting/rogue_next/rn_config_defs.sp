#if defined _rn_config_defs_included
 #endinput
#endif
#define _rn_config_defs_included

/** 由统一定义登记全部参数；BUFF数值沿用旧版，三个章节难度参数除外。 */
void RN_Config_BuildDefinitions()
{
    RN_Disaster_BuildConfig();
    RN_Config_Define(RN_CVAR_SWORD_WAVE_ENABLE, "rne_sword_wave_enable", "1",
        "剑客成功挥动普通近战时发出剑气；0关闭", true, 0.0, 1.0);
    RN_Config_Define(RN_CVAR_SWORD_WAVE_RANGE, "rne_sword_wave_range", "300",
        "剑气中心基础飞行距离，游戏单位", false, 50.0, RN_SWORD_RANGE_MAX);
    RN_Config_Define(RN_CVAR_SWORD_WAVE_SPEED, "rne_sword_wave_speed", "1100",
        "剑气飞行速度，游戏单位每秒", false, 100.0, 3000.0);
    RN_Config_Define(RN_CVAR_SWORD_WAVE_HALFWIDTH, "rne_sword_wave_halfwidth", "48",
        "剑气半宽；完整弧线可命中，中心碰墙才消失", false, 4.0, 96.0);
    RN_Config_Define(RN_CVAR_SWORD_WAVE_MAX_HITS, "rne_sword_wave_max_hits", "1",
        "剑气基础敌人命中上限；队友与同刀近战目标不消耗", true, 1.0, 32.0);
    RN_Config_Define(RN_CVAR_SWORD_PIERCE_HITS, "rne_sword_pierce_hits", "1",
        "剑气透体每层增加敌人命中上限；最终上限32", true, 0.0, 32.0);
    RN_Config_Define(RN_CVAR_SWORD_REACH_DISTANCE, "rne_sword_reach_distance", "100",
        "剑气纵横每层增加飞行距离；最终距离上限3000", false, 0.0, RN_SWORD_RANGE_MAX);
    RN_Config_Define(RN_CVAR_SWORD_WAVE_DAMAGE_FACTOR, "rne_sword_wave_damage_factor", "0.60",
        "剑气继承当前近战伤害的比例，0.60为60%；仍可暴击", false, 0.0, 10.0);
    RN_Config_Define(RN_CVAR_ENABLE, "rne_enable", "1",
        "启用 Rogue；关闭保留档案并撤销效果", true, 0.0000, 1.0000);
    RN_Config_Define(RN_CVAR_DEBUG, "rne_debug", "0",
        "启用经验、生命周期与牛免控详细日志", true, 0.0000, 1.0000);
    RN_Config_Define(RN_CVAR_DAMAGE_STATS_ENABLE, "rne_damage_stats_enable", "1",
        "启用真人战役伤害累计；关闭保留伤害，特感继续累计供HUD与死神共用", true, 0.0000, 1.0000);
    RN_Config_Define(RN_CVAR_DAMAGE_STATS_TOP, "rne_damage_stats_top", "5",
        "管理员伤害排名最多显示人数；0显示全部真人贡献者", true, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_HUD_ENABLE, "rne_hud_enable", "1",
        "显示内置战役排行榜与右侧章节、路程、团队等级和时间难度；关闭不影响累计", true, 0.0000, 1.0000);
    RN_Config_Define(RN_CVAR_HUD_TOP, "rne_hud_top", "15",
        "内置HUD最多显示真人生还者人数，按战役伤害排序；范围1到15", true, 1.0000, 15.0000);
    RN_Config_Define(RN_CVAR_INITIAL_CHOICES_EASY, "rne_initial_choices_easy", "4",
        "简单难度Easy的初始选择次数，下场生效；0不送初始选择", true, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_INITIAL_CHOICES_NORMAL, "rne_initial_choices_normal", "3",
        "普通难度Normal的初始选择次数，下场生效；0不送初始选择", true, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_INITIAL_CHOICES_HARD, "rne_initial_choices_hard", "2",
        "高级难度Hard的初始选择次数，下场生效；0不送初始选择", true, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_INITIAL_CHOICES_EXPERT, "rne_initial_choices_expert", "1",
        "专家难度Impossible的初始选择次数，下场生效；0不送初始选择", true, 0.0000, -1.0);
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
    RN_Config_Define(RN_CVAR_HP_PER_TIER, "rne_hp_per_tier", "0.25",
        "每档感染者血量增量", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_DMG_PER_TIER, "rne_dmg_per_tier", "0.25",
        "每档感染者伤害增量", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_TANK_SPEED_PER_TIER, "rne_tank_speed_per_tier", "0.08",
        "每档Tank移速增量", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_TANK_HP_FACTOR, "rne_tank_hp_factor", "2.0",
        "Tank出生额外血量倍率", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_TANK_COUNT_SCALING, "rne_tank_count_scaling", "1",
        "Tank出生时按N/4额外缩放血量", true, 0.0000, 1.0000);
    RN_Config_Define(RN_CVAR_WITCH_HP_FACTOR, "rne_witch_hp_factor", "1.5",
        "Witch出生额外血量倍率", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_WITCH_COUNT_SCALING, "rne_witch_count_scaling", "1",
        "Witch出生时按N/4额外缩放血量", true, 0.0000, 1.0000);
    RN_Config_Define(RN_CVAR_SCALING_IGNORE_EMPTY, "rne_scaling_ignore_empty", "1",
        "无真人连接时暂停难度时钟", true, 0.0000, 1.0000);
    RN_Config_Define(RN_CVAR_SCALING_MAX_TIER, "rne_scaling_max_tier", "0",
        "难度档位上限，0不限", true, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_SCALING_ANNOUNCE, "rne_scaling_announce", "1",
        "公告开局和难度档位", true, 0.0000, 1.0000);
    RN_Config_Define(RN_CVAR_REMIND_ENABLE, "rne_remind_enable", "1",
        "启用私聊待选提醒", true, 0.0000, 1.0000);
    RN_Config_Define(RN_CVAR_REMIND_INTERVAL, "rne_remind_interval", "300",
        "私聊提醒间隔秒数", false, 0.0100, -1.0);
    RN_Config_Define(RN_CVAR_JOIN_TIP, "rne_join_tip", "1",
        "真人成为生还者时显示指令帮助", true, 0.0000, 1.0000);
    RN_Config_Define(RN_CVAR_MENU_IN_COMBAT, "rne_menu_in_combat", "0",
        "允许倒地或被控时选卡；不允许死者", true, 0.0000, 1.0000);
    RN_Config_Define(RN_CVAR_FANXING_CHOICES, "rne_fanxing_choices", "10",
        "繁星重配时最低额外增加次数，0只按比例增长", true, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_FANXING_PERCENT, "rne_fanxing_percent", "130",
        "繁星重配总量百分比，130表示1.3倍；整数四舍五入，不低于100", true, 100.0000, -1.0);
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
    RN_Config_Define(RN_CVAR_PROBIGNITE_SURV, "rne_probignite_surv", "2",
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
    RN_Config_Define(RN_CVAR_NEVERFALL_PROTECTION_TIME, "rne_neverfall_protection_time", "1.0",
        "读档战神起身后的免伤秒数；0关闭，时长不随层数增加", false, 0.0000, -1.0);
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
    RN_Config_Define(RN_CVAR_PYROMANIAC_PROBIGNITE_SURV, "rne_pyromaniac_probignite_surv", "2",
        "纵火狂增加多少点燃几率", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_PYROMANIAC_DMGREDUCTION_SURV, "rne_pyromaniac_dmgreduction_surv", "0.15",
        "纵火狂每层枪械伤害加算扣减，0.15为15%", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_CRYOPHILIA_PROBFREEZE_SURV, "rne_cryophilia_probfreeze_surv", "4",
        "多冻症增加多少冰冻几率", false, 0.0000, -1.0);
    RN_Config_Define(RN_CVAR_CRYOPHILIA_DMGREDUCTION_SURV, "rne_cryophilia_dmgreduction_surv", "0.15",
        "多冻症每层枪械伤害加算扣减，0.15为15%", false, 0.0000, -1.0);
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
    RN_Config_Define(RN_CVAR_IGNITE_BASE_DPS, "rne_ignite_base_dps", "50",
        "Rogue点燃的独立基础灼烧伤害，每秒点数", false, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_PYROMANIAC_BURN_DPS_SURV, "rne_pyromaniac_burn_dps_surv", "25",
        "纵火狂每层增加多少点基础灼烧伤害，每秒点数", false, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_FLAMEHEART_BURN_BONUS_SURV, "rne_flameheart_burn_bonus_surv", "1.0",
        "三级烈焰之心每层增加多少倍独立灼烧伤害，1为100%", false, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_ELEMENT_EXPLOSION_ENABLE, "rne_element_explosion_enable", "1",
        "启用冰火爆炸，结算剩余灼烧并消耗触发目标的元素状态", true, 0.0, 1.0);
    RN_Config_Define(RN_CVAR_ELEMENT_EXPLOSION_CRIT_ENABLE, "rne_element_explosion_crit_enable", "1",
        "冰火爆炸按原点燃者的暴击属性独立暴击一次；0关闭", true, 0.0, 1.0);
    RN_Config_Define(RN_CVAR_ELEMENT_EXPLOSION_RADIUS, "rne_element_explosion_radius", "300",
        "冰火爆炸半径，游戏单位；墙体阻挡，0关闭联动", false, 0.0, 16384.0);
    RN_Config_Define(RN_CVAR_ELEMENT_EXPLOSION_SPLASH_FACTOR, "rne_element_explosion_splash_factor", "0.5",
        "冰火爆炸对周边敌人的余火伤害倍率，0至1；中心保持完整结算", false, 0.0, 1.0);
    RN_Config_Define(RN_CVAR_PROFESSION_ENABLE, "rne_profession_enable", "1",
        "启用职业选择与个人能力；关闭保留已选职业", true, 0.0, 1.0);
    RN_Config_Define(RN_CVAR_REAPER_DAMAGE_PER_KILL, "rne_reaper_damage_per_kill", "0.02",
        "死神每次特感击杀的通用伤害成长，按排行榜累计重算；0.02为2%", false, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_REAPER_PENALTY_PER_KILL, "rne_reaper_penalty_per_kill", "0.02",
        "死神每次特感击杀的减伤惩罚，按排行榜累计重算；0.02为2个百分点", false, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_DEMON_CONTRACT_DAMAGE_PER_KILL, "rne_demon_contract_damage_per_kill", "0.02",
        "恶魔契约每层每次特感击杀的额外通用伤害成长，追补累计击杀", false, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_DEMON_CONTRACT_PENALTY_PER_KILL, "rne_demon_contract_penalty_per_kill", "0.02",
        "恶魔契约每层每次特感击杀的额外减伤惩罚，追补累计击杀", false, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_CONGXIN_PENALTY_REDUCTION, "rne_congxin_penalty_reduction", "0.10",
        "从心每层削减死神与恶魔契约原惩罚的比例，线性加算且最多免除全部惩罚", false, 0.0, 1.0);
    RN_Config_Define(RN_CVAR_SOUL_DRAIN_HEAL, "rne_soul_drain_heal", "5",
        "灵魂汲取每层每次特感击杀回复实血，仅站立存活时生效", true, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_GUNSLINGER_DAMAGE_PER_LEVEL, "rne_gunslinger_damage_per_level", "0.05",
        "士兵每个团队等级的枪械伤害加算成长，0.05为5%", false, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_BLADEMASTER_ATTACK_SPEED_BONUS, "rne_blademaster_attack_speed_bonus", "0.20",
        "剑客个人近战攻速加成，0.20为20%", false, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_ELEMENTALIST_PROBABILITY_BONUS, "rne_elementalist_probability_bonus", "0.50",
        "元素大师火冰电概率的额外倍率，与强运相乘，0.50为额外50%", false, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_SNIPER_DAMAGE_PER_100_UNITS, "rne_sniper_damage_per_100_units", "0.15",
        "狙神每100游戏单位距离的独立增伤，0.15为15%", false, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_SNIPER_MAX_DISTANCE, "rne_sniper_max_distance", "2000",
        "狙神距离成长停止增加的距离，0关闭距离增伤；专属卡仍提高远端伤害", false, 0.0, 16384.0);
    RN_Config_Define(RN_CVAR_SNIPER_START_WEAPON, "rne_sniper_start_weapon", "1",
        "狙神选择时赠送十五连，重连或死亡复活缺少狙击枪时补发；正常过图不补发，0关闭", true, 0.0, 1.0);
    RN_Config_Define(RN_CVAR_BLADEMASTER_DISARM_IMMUNITY, "rne_blademaster_disarm_immunity", "1",
        "剑客免疫Tank近战缴械；0关闭，职业停用时不生效", true, 0.0, 1.0);
    RN_Config_Define(RN_CVAR_BERSERKER_HEAL, "rne_berserker_heal", "5",
        "嗜血狂战每层每次击杀特感回复的实血，含Tank，攻击方式不限", true, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_ORA_ATTACK_SPEED_BONUS, "rne_ora_attack_speed_bonus", "0.15",
        "欧拉欧拉每层个人近战攻速增量，与剑客能力加算，0.15为15%", false, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_DUAL_ELEMENT_IGNITE_CHANCE, "rne_dual_element_ignite_chance", "4",
        "冰火两重天每层点燃概率，百分点；受职业和强运影响", false, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_DUAL_ELEMENT_FREEZE_CHANCE, "rne_dual_element_freeze_chance", "4",
        "冰火两重天每层冰冻概率，百分点；受职业和强运影响", false, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_DUAL_ELEMENT_DAMAGE_REDUCTION, "rne_dual_element_damage_reduction", "0.30",
        "冰火两重天每层枪械伤害加算扣减，0.30为30%", false, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_ART_EXPLOSION_RADIUS_BONUS, "rne_art_explosion_radius_bonus", "100",
        "艺术每层增加的爆炸半径，榴弹与冰火共用，仅使用引爆者的层数", false, 0.0, 16384.0);
    RN_Config_Define(RN_CVAR_EXPOSED_DAMAGE_PER_100_UNITS, "rne_exposed_damage_per_100_units", "0.15",
        "露头就秒每层每100单位狙击增伤增量，与职业能力加算，0.15为15%", false, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_RISE_SNIPER_DAMAGE_BONUS, "rne_rise_sniper_damage_bonus", "0.30",
        "我起了每层独立狙击伤害增量，同类加算后乘距离倍率，0.30为30%", false, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_DAILY_TRAINING_DAMAGE_PER_LEVEL, "rne_daily_training_damage_per_level", "0.03",
        "日常训练每层增加士兵每个团队等级的枪械伤害加算成长，0.03为额外3%", false, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_TENACITY_CONTROL_CHANCE, "rne_tenacity_control_chance", "30",
        "坚韧每层四类免控概率，百分点；与通用免控加算并受强运影响", false, 0.0, 100.0);
    RN_Config_Define(RN_CVAR_EXPLOSIVE_BULLET_CHANCE, "rne_explosive_bullet_chance", "20",
        "爆裂子弹每层狙击命中爆炸概率，百分点；受强运影响", false, 0.0, 100.0);
    RN_Config_Define(RN_CVAR_EXPLOSIVE_BULLET_RADIUS, "rne_explosive_bullet_radius", "300",
        "爆裂子弹半径，周边敌人受到完整子弹伤害；墙体阻挡，0关闭", false, 0.0, 16384.0);
    RN_Config_Define(RN_CVAR_GRENADE_ENABLE, "rne_grenade_enable", "1",
        "接管新发射的生还者榴弹，使用Rogue爆炸与弹跳分裂；0清理受控弹并恢复原生榴弹", true, 0.0, 1.0);
    RN_Config_Define(RN_CVAR_GRENADE_DAMAGE, "rne_grenade_damage", "300",
        "榴弹首次爆炸的基础伤害，后续按弹跳次数衰减，接受枪械与全伤加成", false, 0.0, 10000.0);
    RN_Config_Define(RN_CVAR_GRENADE_BOUNCE_DAMAGE_DECAY, "rne_grenade_bounce_damage_decay", "0.20",
        "榴弹每次弹跳降低当前基础伤害的比例，0.20为20%；分裂继承衰减次数", false, 0.0, 1.0);
    RN_Config_Define(RN_CVAR_GRENADE_RADIUS, "rne_grenade_radius", "100",
        "榴弹基础爆炸半径，游戏单位；感染者身体中心计距，墙门实物挡伤害", false, 0.0, 16384.0);
    RN_Config_Define(RN_CVAR_GRENADE_BOUNCE_SPEED, "rne_grenade_bounce_speed", "320",
        "榴弹落地后的向上弹跳速度，游戏单位每秒", false, 100.0, 800.0);
    RN_Config_Define(RN_CVAR_GRENADE_RETENTION, "rne_grenade_horizontal_retention", "0.75",
        "榴弹地面弹跳保留的水平速度比例", false, 0.0, 1.0);
    RN_Config_Define(RN_CVAR_GRENADE_SPLIT_SPEED, "rne_grenade_split_speed", "350",
        "榴弹分裂弹沿碰撞后前进方向散开的水平速度", false, 100.0, 800.0);
    RN_Config_Define(RN_CVAR_GRENADE_SPLIT_ANGLE, "rne_grenade_split_angle", "30",
        "榴弹分裂扇形水平总夹角，两弹各偏一半；墙顶分裂方向朝外", false, 0.0, 90.0);
    RN_Config_Define(RN_CVAR_MAGICIAN_START_WEAPON, "rne_magician_start_weapon", "1",
        "艺术家选择时赠送榴弹枪，重连或死亡复活缺少榴弹枪时补发；正常过图不补发，0关闭", true, 0.0, 1.0);
    RN_Config_Define(RN_CVAR_MAGICIAN_BOUNCES, "rne_magician_bounces", "1",
        "艺术家榴弹初始额外弹跳次数，不含首次碰撞；实际次数最多63", true, 0.0, 63.0);
    RN_Config_Define(RN_CVAR_MAGICIAN_SPLIT_CHANCE, "rne_magician_split_chance", "10",
        "艺术家榴弹初始分裂概率，百分点；每满100%必多1发，余数概率再多1发", false, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_PINGPONG_BOUNCES, "rne_pingpong_bounces", "1",
        "乒乓球每层增加的榴弹弹跳次数，先抵扣大场面预存负值", true, 0.0, 63.0);
    RN_Config_Define(RN_CVAR_BIG_SCENE_SPLIT_CHANCE, "rne_big_scene_split_chance", "20",
        "大场面每层增加的榴弹分裂概率，百分点；可超过100%，末次碰撞不分裂", false, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_BIG_SCENE_BOUNCE_PENALTY, "rne_big_scene_bounce_penalty", "0",
        "大场面每层扣减的榴弹弹跳次数，0不扣减且隐藏说明；实际最低0，负值预存供抵扣", true, 0.0, 63.0);
    RN_Config_Define(RN_CVAR_BIABIABIA_GUN_DAMAGE, "rne_biabiabia_gun_damage", "0.15",
        "biabiabia每层枪械伤害加成，与士兵成长、元素枪伤减益和全伤加算，0.15为15%", false, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_PATRICK_EXPLOSION_DAMAGE_BONUS, "rne_patrick_explosion_damage_bonus", "1.0",
        "派大星每层增加爆炸伤害，1为100%；多层加算后独立乘爆炸伤害", false, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_PATRICK_EXPLOSION_RADIUS_BONUS, "rne_patrick_explosion_radius_bonus", "1.0",
        "派大星每层增加爆炸范围，1为100%；艺术加半径后乘倍率，半径上限16384", false, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_ELECTRIC_ENABLE, "rne_electric_enable", "1",
        "启用电击及敌人间电弧连锁；0取消电链，不改变已有灼烧", true, 0.0, 1.0);
    RN_Config_Define(RN_CVAR_ELECTRIC_BASE_DAMAGE, "rne_electric_base_damage", "200",
        "电击首目标基础伤害，接受通用增伤及辛辣，不额外暴击", false, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_ELECTRIC_JUMPS, "rne_electric_jumps", "2",
        "电击初始额外弹射次数，不含首目标；技术上限63，伤害非正提前结束", true, 0.0, 63.0);
    RN_Config_Define(RN_CVAR_ELECTRIC_DECAY, "rne_electric_decay", "0.15",
        "每跳扣除本条链初始电伤的比例，0.15为15%线性衰减，伤害非正结束", false, 0.0, 1.0);
    RN_Config_Define(RN_CVAR_ELECTRIC_RADIUS, "rne_electric_radius", "200",
        "电弧每跳搜索距离，码即游戏单位；最近可见未命中感染者，0不弹射", false, 0.0, 16384.0);
    RN_Config_Define(RN_CVAR_ELECTRIC_INTERVAL, "rne_electric_interval", "0.12",
        "电弧逐跳间隔秒数，每人同时至多一条电链", false, 0.01, 5.0);
    RN_Config_Define(RN_CVAR_ELECTRIC_COOLDOWN, "rne_electric_cooldown", "0.6",
        "每名玩家触发新电链的冷却秒数，0无额外冷却但不重叠起链", false, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_ELECTRIC_FIRE_ENABLE, "rne_electric_fire_enable", "1",
        "电链继承首目标Rogue灼烧100%DPS及完整时长，传播不再抽元素", true, 0.0, 1.0);
    RN_Config_Define(RN_CVAR_ELECTRIC_ADDICT_CHANCE, "rne_electric_addict_chance", "2",
        "一级电之沉迷每层电击概率，百分点；受元素大师及强运影响", false, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_SUPERCONDUCTOR_JUMPS, "rne_superconductor_jumps", "1",
        "二级超导体每层增加额外弹射目标数，受非正伤害及63跳上限限制", true, 0.0, 63.0);
    RN_Config_Define(RN_CVAR_FIVE_WHIP_CHANCE, "rne_five_whip_chance", "2",
        "二级五连鞭每层电击概率，百分点；受元素大师及强运影响", false, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_FIVE_WHIP_DAMAGE, "rne_five_whip_damage", "40",
        "五连鞭每层增加初始基础电伤，先加基础再乘雷电法王及通用增伤", false, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_FIVE_WHIP_GUN_COST, "rne_five_whip_gun_cost", "0.15",
        "五连鞭每层枪械伤害加算扣减，包含Rogue榴弹，0.15为15%", false, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_THUNDER_KING_BONUS, "rne_thunder_king_bonus", "1.0",
        "三级雷电法王每层电伤加成，1为100%；同卡层数加算，不放大传染火伤", false, 0.0, -1.0);
    RN_Knight_DefineConfig();
}
