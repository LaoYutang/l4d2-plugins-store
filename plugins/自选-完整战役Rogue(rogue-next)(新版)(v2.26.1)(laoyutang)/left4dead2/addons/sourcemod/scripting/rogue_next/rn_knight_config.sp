#if defined _rn_knight_config_included
 #endinput
#endif
#define _rn_knight_config_included

/** 十字骑士参数使用统一配置事务；爆发仅保留受伤计数间隔。 */
void RN_Knight_DefineConfig()
{
    RN_Config_Define(RN_CVAR_KNIGHT_HEALTH_BONUS, "rne_knight_health_bonus", "100",
        "十字骑士初始额外最大生命，选择时补充新增实血", true, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_KNIGHT_HEALTH_PER_LEVEL, "rne_knight_health_per_level", "10",
        "十字骑士每个团队等级增加的最大生命，实际升级补充本次增量", true, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_KNIGHT_ATTACK_HP_RATIO, "rne_knight_attack_hp_ratio", "0.02",
        "生命附伤的最大生命比例，每颗有效子弹或普通近战命中独立计算", false, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_KNIGHT_BURST_HITS, "rne_knight_burst_hits", "8",
        "受难爆发基础受伤次数", true, 1.0, -1.0);
    RN_Config_Define(RN_CVAR_KNIGHT_BURST_MIN_HITS, "rne_knight_burst_min_hits", "4",
        "忍无可忍降低次数后的下限，不得高于基础次数", true, 1.0, -1.0);
    RN_Config_Define(RN_CVAR_KNIGHT_HIT_INTERVAL, "rne_knight_hit_interval", "0.5",
        "同一玩家受难爆发计数的最短间隔秒数，所有伤害来源共用", false, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_KNIGHT_BURST_BASE_DAMAGE, "rne_knight_burst_base_damage", "100",
        "受难爆发固定基础伤害，另加最大生命比例伤害", false, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_KNIGHT_BURST_HP_RATIO, "rne_knight_burst_hp_ratio", "0.8",
        "受难爆发的最大生命伤害比例，接受全伤、辛辣天塞和派大星", false, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_KNIGHT_BURST_RADIUS, "rne_knight_burst_radius", "150",
        "受难爆发基础半径，艺术先加半径再乘派大星，墙门阻挡", false, 0.0, 16384.0);
    RN_Config_Define(RN_CVAR_KNIGHT_BURST_RADIUS_CAP, "rne_knight_burst_radius_cap", "800",
        "受难爆发所有范围加成结算后的半径上限，仅影响此能力", false, 0.0, 16384.0);
    RN_Config_Define(RN_CVAR_PAIN_PLEASURE_HEAL_RATIO, "rne_pain_pleasure_heal_ratio", "0.02",
        "痛并快乐每层每秒回复的最大生命比例，层数加算不封顶，实血不超过上限", false, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_PAIN_PLEASURE_DURATION, "rne_pain_pleasure_duration", "6",
        "痛并快乐受伤后持续秒数，重复受伤只续时，不叠加窗口或重置节拍", false, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_BLOOD_VIGOR_HP_RATIO, "rne_blood_vigor_hp_ratio", "0.01",
        "血气方刚每层增加生命附伤的比例，0.01为增加1个百分点", false, 0.0, -1.0);
    RN_Config_Define(RN_CVAR_LAST_STRAW_HITS_REDUCTION, "rne_last_straw_hits_reduction", "1",
        "忍无可忍每层减少受难爆发次数，受最低门槛限制", true, 0.0, -1.0);
}

/** 旧cfg中的超时键只作兼容；不生成到新cfg、不校验、不挂热改钩子。 */
void RN_Knight_LegacyConfig()
{
    ConVar retired = FindConVar("rne_knight_counter_timeout");
    bool existed = retired != null;
    if (!existed)
        retired = CreateConVar("rne_knight_counter_timeout", "10",
            "已废弃：受难计数不再因未受伤超时清空；仅兼容旧cfg，任何值均忽略", FCVAR_DONTRECORD);
    retired.Flags = (retired.Flags | FCVAR_DONTRECORD) & ~FCVAR_NOTIFY;
    if (existed) LogMessage("[rogue-next] rne_knight_counter_timeout已废弃，仅兼容旧cfg，任何值均忽略。");
}

/** 时间必须可表达；比例不设玩法上限，由组合校验拒绝实际数值溢出。 */
bool RN_Knight_ValidateConfig(const float values[RN_CVAR_COUNT])
{
    if (values[RN_CVAR_KNIGHT_BURST_MIN_HITS] > values[RN_CVAR_KNIGHT_BURST_HITS]) return false;
    RN_ConfigKey times[] = {RN_CVAR_KNIGHT_HIT_INTERVAL, RN_CVAR_PAIN_PLEASURE_DURATION};
    for (int i = 0; i < sizeof(times); i++)
        if (values[times[i]] <= 0.0 || values[times[i]] >= RN_INT_FLOAT_LIMIT) return false;
    float health = 100.0 + values[RN_CVAR_KNIGHT_HEALTH_BONUS]
        + float(g_Run_Level) * values[RN_CVAR_KNIGHT_HEALTH_PER_LEVEL];
    float attack = health * values[RN_CVAR_KNIGHT_ATTACK_HP_RATIO];
    float burst = values[RN_CVAR_KNIGHT_BURST_BASE_DAMAGE] + health * values[RN_CVAR_KNIGHT_BURST_HP_RATIO];
    return RN_Math_Finite(health) && health < RN_INT_FLOAT_LIMIT
        && RN_Math_Finite(attack) && attack < RN_INT_FLOAT_LIMIT
        && RN_Math_Finite(burst) && burst < RN_INT_FLOAT_LIMIT
        && RN_Math_Finite(values[RN_CVAR_KNIGHT_ATTACK_HP_RATIO] * 100.0)
        && RN_Math_Finite(values[RN_CVAR_PAIN_PLEASURE_HEAL_RATIO] * 100.0)
        && RN_Math_Finite(values[RN_CVAR_BLOOD_VIGOR_HP_RATIO] * 100.0);
}
