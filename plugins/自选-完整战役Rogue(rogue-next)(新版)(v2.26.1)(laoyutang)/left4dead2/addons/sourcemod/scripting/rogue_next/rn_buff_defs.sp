#if defined _rn_buff_defs_included
 #endinput
#endif
#define _rn_buff_defs_included

/** 选卡浮点数共用显示舍入；各项仍使用原有显示精度。 */
void RN_Buff_DescriptionNumbers(char[] text, int maxlength, const char[] format,
    float first, int firstDecimals = 0, float second = 0.0, int secondDecimals = 0,
    float third = 0.0, int thirdDecimals = 0)
{
    char one[64], two[64], three[64];
    RN_Math_NumberText(first, one, sizeof(one), firstDecimals);
    RN_Math_NumberText(second, two, sizeof(two), secondDecimals);
    RN_Math_NumberText(third, three, sizeof(three), thirdDecimals);
    FormatEx(text, maxlength, format, one, two, three);
}

/** 生成当前配置的单次获卡说明；已获得的合计属性由rn_stats计算。 */
void RN_Buff_Description(int buff, char[] text, int maxlength)
{
    char one[64], two[64];
    switch (buff)
    {
        case PLAYBUFF_MAXHEALTH: FormatEx(text, maxlength, "上限+%d并回复新增实血", RN_Config_Int(RN_CVAR_ADDMAXHEALTH_SURV));
        case PLAYBUFF_HEALING: RN_Buff_DescriptionNumbers(text, maxlength, "每秒回复%s实血", RN_Config_Float(RN_CVAR_HEALHP_SURV), 2);
        case PLAYBUFF_RELOADSPEED: RN_Buff_DescriptionNumbers(text, maxlength, "全队换弹时间-%s%%", RN_Config_Float(RN_CVAR_RELOADSPEEDMULTIPLE_SURV)*100.0, 0);
        case PLAYBUFF_FIRERATE: RN_Buff_DescriptionNumbers(text, maxlength, "全队射击间隔-%s%%", RN_Config_Float(RN_CVAR_FIRERATEMULTIPLE_SURV)*100.0, 0);
        case PLAYBUFF_CAUSEHARM: RN_Buff_DescriptionNumbers(text, maxlength, "输出加成+%s%%", RN_Config_Float(RN_CVAR_ADDMULTIPLE_SURV)*100.0, 0);
        case PLAYBUFF_PUTONGQUANPU: RN_Buff_DescriptionNumbers(text, maxlength, "输出加成+%s%%", RN_Config_Float(RN_CVAR_PUTONGQUANPU_ADDMULTIPLE_SURV)*100.0, 0);
        case PLAYBUFF_SUFFERHRAM: RN_Buff_DescriptionNumbers(text, maxlength, "承伤减免+%s%%", RN_Config_Float(RN_CVAR_SUBMULTIPLE_SURV)*100.0, 0);
        case PLAYBUFF_PROBINVULNERABILITY: FormatEx(text, maxlength, "四类免控+%d%%，强运可加成", RN_Config_Int(RN_CVAR_PROBINVINCIBILITY_SURV));
        case PLAYBUFF_POWANGFA: FormatEx(text, maxlength, "四类免控+%d%%，强运可加成", RN_Config_Int(RN_CVAR_POWANGFA_PROBINVINCIBILITY_SURV));
        case PLAYBUFF_PROBIGNITE:
        {
            RN_Math_NumberText(RN_Config_Float(RN_CVAR_IGNITEDURATION_SURV), one, sizeof(one));
            FormatEx(text, maxlength, "点燃+%d%%，持续%s秒", RN_Config_Int(RN_CVAR_PROBIGNITE_SURV), one);
        }
        case PLAYBUFF_PROBFREEZE:
        {
            RN_Math_NumberText(RN_Config_Float(RN_CVAR_FREEZEDURATION_SURV), one, sizeof(one));
            FormatEx(text, maxlength, "%d%%概率冰冻，持续%s秒", RN_Config_Int(RN_CVAR_PROBFREEZE_SURV), one);
        }
        case PLAYBUFF_NEVERFALL:
        {
            if (RN_Config_Float(RN_CVAR_NEVERFALL_PROTECTION_TIME) > 0.0)
            {
                RN_Math_NumberText(RN_Config_Float(RN_CVAR_NEVERFALL_PROTECTION_TIME), one, sizeof(one));
                FormatEx(text, maxlength, "拦截+%d次，回复%d实血，免伤%s秒",
                    RN_Config_Int(RN_CVAR_NEVERFALLNUM_SURV), RN_Stats_NeverFallHealth(), one);
            }
            else FormatEx(text, maxlength, "增加%d次倒地拦截，回复%d实血",
                RN_Config_Int(RN_CVAR_NEVERFALLNUM_SURV), RN_Stats_NeverFallHealth());
        }
        case PLAYBUFF_MOVESPEED: RN_Buff_DescriptionNumbers(text, maxlength, "移速+%s%%", RN_Config_Float(RN_CVAR_MOVESPEEDMULTIPLE_SURV)*100.0, 0);
        case PLAYBUFF_LUOYANEBU: RN_Buff_DescriptionNumbers(text, maxlength, "移速+%s%%", RN_Config_Float(RN_CVAR_LUOYANEBU_MOVESPEEDMULTIPLE_SURV)*100.0, 0);
        case PLAYBUFF_GLASSCANNON: RN_Buff_DescriptionNumbers(text, maxlength, "输出+%s%%，承伤+%s%%", RN_Config_Float(RN_CVAR_GLASSCANNON_DAMAGE_SURV)*100.0, 0, RN_Config_Float(RN_CVAR_GLASSCANNON_DAMAGEREDUCTION_SURV)*100.0, 0);
        case PLAYBUFF_PYROMANIAC: RN_Buff_DescriptionNumbers(text, maxlength, "点燃+%s%%，基础灼烧+%s/秒\n枪械伤害-%s%%", RN_Config_Float(RN_CVAR_PYROMANIAC_PROBIGNITE_SURV), 0, RN_Config_Float(RN_CVAR_PYROMANIAC_BURN_DPS_SURV), 0, RN_Config_Float(RN_CVAR_PYROMANIAC_DMGREDUCTION_SURV)*100.0, 0);
        case PLAYBUFF_FLAMEHEART: RN_Buff_DescriptionNumbers(text, maxlength, "灼烧伤害+%s%%", RN_Config_Float(RN_CVAR_FLAMEHEART_BURN_BONUS_SURV)*100.0, 0);
        case PLAYBUFF_CRYOPHILIA: RN_Buff_DescriptionNumbers(text, maxlength, "冰冻概率+%s%%，枪械伤害-%s%%", RN_Config_Float(RN_CVAR_CRYOPHILIA_PROBFREEZE_SURV), 0, RN_Config_Float(RN_CVAR_CRYOPHILIA_DMGREDUCTION_SURV)*100.0, 0);
        case PLAYBUFF_DAMOCLESSWORD: FormatEx(text, maxlength, "升级额外选+1；每秒%d/万受伤999", RN_Config_Int(RN_CVAR_DAMOCLESSWORD_DEATHPROB_SURV));
        case PLAYBUFF_IMMOVABLE:
        {
            RN_Math_NumberText(RN_Config_Float(RN_CVAR_IMMOVABLE_MOVESPEEDREDUCTION_SURV)*100.0, one, sizeof(one), 0);
            FormatEx(text, maxlength, "上限+%d，移速-%s%%", RN_Config_Int(RN_CVAR_IMMOVABLE_MAXHEALTH_SURV), one);
        }
        case PLAYBUFF_DUOBAOXIANREN: FormatEx(text, maxlength, "ROLL+%d", RN_Config_Int(RN_CVAR_DUOBAOXIANREN_ROLLBONUS_SURV));
        case PLAYBUFF_SHILENBAODI: FormatEx(text, maxlength, "ROLL+%d", RN_Config_Int(RN_CVAR_SHILENBAODI_ROLLBONUS_SURV));
        case PLAYBUFF_SHUANGSHENGHUA: strcopy(text, maxlength, "每层复制手选1次，自身/D4/繁星除外");
        case PLAYBUFF_SHENGSHENGBUXI: strcopy(text, maxlength, "免疫所有伤害");
        case PLAYBUFF_TIANXINGJIAN: RN_Buff_DescriptionNumbers(text, maxlength, "免伤+%s%%，每秒回血%s", RN_Config_Float(RN_CVAR_TIANXINGJIAN_SUBMULTIPLE_SURV)*100.0, 0, RN_Config_Float(RN_CVAR_TIANXINGJIAN_HEALHP_SURV), 2);
        case PLAYBUFF_SHEXINGZOUWEI: RN_Buff_DescriptionNumbers(text, maxlength, "闪避概率+%s%%，受强运影响", RN_Config_Float(RN_CVAR_SHEXINGZOUWEI_DODGECHANCE_SURV), 0);
        case PLAYBUFF_ZIZAIJIYI: RN_Buff_DescriptionNumbers(text, maxlength, "闪避概率+%s%%，受强运影响", RN_Config_Float(RN_CVAR_ZIZAIJIYI_DODGECHANCE_SURV), 0);
        case PLAYBUFF_YIJIANSANLIAN:
        {
            RN_Math_NumberText(RN_Config_Float(RN_CVAR_YIJIANSANLIAN_HEALHP_SURV), one, sizeof(one), 2);
            RN_Math_NumberText(RN_Config_Float(RN_CVAR_YIJIANSANLIAN_DAMAGE_SURV)*100.0, two, sizeof(two), 0);
            FormatEx(text, maxlength, "上限+%d，回血%s/秒，伤害+%s%%", RN_Config_Int(RN_CVAR_YIJIANSANLIAN_MAXHEALTH_SURV), one, two);
        }
        case PLAYBUFF_ZAILAIYIPING: strcopy(text, maxlength, "额外选择+1");
        case PLAYBUFF_HAIYOUSANBEI: strcopy(text, maxlength, "额外选择+3");
        case PLAYBUFF_XINLATIANSAI: strcopy(text, maxlength, "最终输出独立乘以(1+层数)");
        case PLAYBUFF_JIFA: FormatEx(text, maxlength, "信念+1；%d/%d/%d起获稀/史/传最高档随机奖", RN_Config_Int(RN_CVAR_FAITH_RARE_THRESHOLD), RN_Config_Int(RN_CVAR_FAITH_EPIC_THRESHOLD), RN_Config_Int(RN_CVAR_FAITH_LEGENDARY_THRESHOLD));
        case PLAYBUFF_DIANREN: strcopy(text, maxlength, "获得所有普通BUFF各一次");
        case PLAYBUFF_ZHIMINGYIJI: RN_Buff_DescriptionNumbers(text, maxlength, "暴击率+%s%%", RN_Config_Float(RN_CVAR_ZHIMINGYIJI_CRITRATE_SURV)*100.0, 0);
        case PLAYBUFF_AIYOUWEI: RN_Buff_DescriptionNumbers(text, maxlength, "暴击率+%s%%", RN_Config_Float(RN_CVAR_AIYOUWEI_CRITRATE_SURV)*100.0, 0);
        case PLAYBUFF_JIANSHENG: RN_Buff_DescriptionNumbers(text, maxlength, "暴击倍率+%s", RN_Config_Float(RN_CVAR_JIANSHENG_CRITDAMAGE_SURV), 2);
        case PLAYBUFF_HUANYINGCIKE: RN_Buff_DescriptionNumbers(text, maxlength, "暴击倍率+%s", RN_Config_Float(RN_CVAR_HUANYINGCIKE_CRITDAMAGE_SURV), 2);
        case PLAYBUFF_QIANGYUN: RN_Buff_DescriptionNumbers(text, maxlength, "概率效果乘以(1+%sx层数)", RN_Config_Float(RN_CVAR_QIANGYUN_PROBBONUS_SURV), 2);
        case PLAYBUFF_ZHAOZAI: FormatEx(text, maxlength, "每秒%d/万概率在前方召唤Tank", RN_Config_Int(RN_CVAR_ZHAOZAI_SPAWNTANKPROB_SURV));
        case PLAYBUFF_YUXI: strcopy(text, maxlength, "清BUFF，历史预算全重抽，保留ROLL");
        case PLAYBUFF_BAOTIANMA: RN_Buff_DescriptionNumbers(text, maxlength, "近战加成+%s%%", RN_Config_Float(RN_CVAR_BAOTIANMA_MELEEDAMAGE_SURV)*100.0, 0);
        case PLAYBUFF_SANDAOLIU: RN_Buff_DescriptionNumbers(text, maxlength, "近战加成+%s%%", RN_Config_Float(RN_CVAR_SANDAOLIU_MELEEDAMAGE_SURV)*100.0, 0);
        case PLAYBUFF_JIEWANGQUAN: RN_Buff_DescriptionNumbers(text, maxlength, "近战加成+%s%%", RN_Config_Float(RN_CVAR_JIEWANGQUAN_MELEEDAMAGE_SURV)*100.0, 0);
        case PLAYBUFF_FANXING:
            RN_Buff_DescriptionNumbers(text, maxlength, "清BUFF重配x%s，至少额外+%s次",
                float(RN_Config_Int(RN_CVAR_FANXING_PERCENT)) / 100.0, 2,
                float(RN_Config_Int(RN_CVAR_FANXING_CHOICES)), 0);
        case PLAYBUFF_YELI: strcopy(text, maxlength, "信念+3，本卡不触发激发奖励");
        case PLAYBUFF_BOZANG: strcopy(text, maxlength, "有效被击杀：每层随机普通BUFF+1");
        case PLAYBUFF_FENGGUANGDAZANG: strcopy(text, maxlength, "有效被击杀：每层50%稀有/50%倒爷");
        case PLAYBUFF_BERSERKER: FormatEx(text, maxlength, "击杀特感回复%d实血，含Tank", RN_Config_Int(RN_CVAR_BERSERKER_HEAL));
        case PLAYBUFF_ORA: RN_Buff_DescriptionNumbers(text, maxlength, "近战攻速+%s%%", RN_Config_Float(RN_CVAR_ORA_ATTACK_SPEED_BONUS)*100.0);
        case PLAYBUFF_SWORD_PIERCE: FormatEx(text, maxlength, "剑气敌人命中上限+%d", RN_Config_Int(RN_CVAR_SWORD_PIERCE_HITS));
        case PLAYBUFF_SWORD_REACH: RN_Buff_DescriptionNumbers(text, maxlength, "剑气距离+%s码", RN_Config_Float(RN_CVAR_SWORD_REACH_DISTANCE), 1);
        case PLAYBUFF_DUAL_ELEMENT: RN_Buff_DescriptionNumbers(text, maxlength, "点燃+%s%% 冰冻+%s%% 枪械伤害-%s%%", RN_Config_Float(RN_CVAR_DUAL_ELEMENT_IGNITE_CHANCE), 0, RN_Config_Float(RN_CVAR_DUAL_ELEMENT_FREEZE_CHANCE), 0, RN_Config_Float(RN_CVAR_DUAL_ELEMENT_DAMAGE_REDUCTION)*100.0);
        case PLAYBUFF_ART: RN_Buff_DescriptionNumbers(text, maxlength, "爆炸半径+%s，含受难爆发", RN_Config_Float(RN_CVAR_ART_EXPLOSION_RADIUS_BONUS));
        case PLAYBUFF_EXPOSED: RN_Buff_DescriptionNumbers(text, maxlength, "狙击每100单位增伤+%s%%", RN_Config_Float(RN_CVAR_EXPOSED_DAMAGE_PER_100_UNITS)*100.0);
        case PLAYBUFF_RISE: RN_Buff_DescriptionNumbers(text, maxlength, "独立狙击伤害+%s%%", RN_Config_Float(RN_CVAR_RISE_SNIPER_DAMAGE_BONUS)*100.0);
        case PLAYBUFF_DAILY_TRAINING: RN_Buff_DescriptionNumbers(text, maxlength, "职业每级枪伤额外+%s%%", RN_Config_Float(RN_CVAR_DAILY_TRAINING_DAMAGE_PER_LEVEL)*100.0);
        case PLAYBUFF_TENACITY: RN_Buff_DescriptionNumbers(text, maxlength, "四类免控+%s%%，强运可加成", RN_Config_Float(RN_CVAR_TENACITY_CONTROL_CHANCE));
        case PLAYBUFF_EXPLOSIVE_BULLET: RN_Buff_DescriptionNumbers(text, maxlength, "狙击爆炸+%s%%，半径%s\n周边完整子弹伤害", RN_Config_Float(RN_CVAR_EXPLOSIVE_BULLET_CHANCE), 0, RN_Config_Float(RN_CVAR_EXPLOSIVE_BULLET_RADIUS));
        case PLAYBUFF_CONGXIN: RN_Buff_DescriptionNumbers(text, maxlength, "契约惩罚整体降低%s%%", RN_Config_Float(RN_CVAR_CONGXIN_PENALTY_REDUCTION)*100.0);
        case PLAYBUFF_DEMON_CONTRACT: RN_Buff_DescriptionNumbers(text, maxlength, "每杀额外伤害+%s%% 减伤-%s%%", RN_Config_Float(RN_CVAR_DEMON_CONTRACT_DAMAGE_PER_KILL)*100.0, 1, RN_Config_Float(RN_CVAR_DEMON_CONTRACT_PENALTY_PER_KILL)*100.0, 1);
        case PLAYBUFF_SOUL_DRAIN: FormatEx(text, maxlength, "特感击杀回复%d实血", RN_Config_Int(RN_CVAR_SOUL_DRAIN_HEAL));
        case PLAYBUFF_PINGPONG: FormatEx(text, maxlength, "榴弹弹跳次数+%d，先抵扣预存负值", RN_Config_Int(RN_CVAR_PINGPONG_BOUNCES));
        case PLAYBUFF_BIG_SCENE:
        {
            int penalty = RN_Config_Int(RN_CVAR_BIG_SCENE_BOUNCE_PENALTY);
            if (penalty > 0)
                RN_Buff_DescriptionNumbers(text, maxlength, "分裂+%s%% 弹跳次数-%s\n最低0，负值预存", RN_Config_Float(RN_CVAR_BIG_SCENE_SPLIT_CHANCE), 0, float(penalty), 0);
            else
                RN_Buff_DescriptionNumbers(text, maxlength, "分裂+%s%%", RN_Config_Float(RN_CVAR_BIG_SCENE_SPLIT_CHANCE));
        }
        case PLAYBUFF_BIABIABIA: RN_Buff_DescriptionNumbers(text, maxlength, "枪械伤害+%s%%", RN_Config_Float(RN_CVAR_BIABIABIA_GUN_DAMAGE)*100.0, 0);
        case PLAYBUFF_PATRICK: RN_Buff_DescriptionNumbers(text, maxlength, "爆炸伤害+%s%% 范围+%s%%", RN_Config_Float(RN_CVAR_PATRICK_EXPLOSION_DAMAGE_BONUS)*100.0, 0, RN_Config_Float(RN_CVAR_PATRICK_EXPLOSION_RADIUS_BONUS)*100.0, 0);
        case PLAYBUFF_ELECTRIC_ADDICT: RN_Buff_DescriptionNumbers(text, maxlength, "电击概率+%s%%，受元素大师及强运影响", RN_Config_Float(RN_CVAR_ELECTRIC_ADDICT_CHANCE));
        case PLAYBUFF_SUPERCONDUCTOR: FormatEx(text, maxlength, "电弹射目标+%d，伤害非正结束连锁", RN_Config_Int(RN_CVAR_SUPERCONDUCTOR_JUMPS));
        case PLAYBUFF_FIVE_WHIP: RN_Buff_DescriptionNumbers(text, maxlength, "电击+%s%% 电基础伤害+%s\n枪械伤害-%s%%", RN_Config_Float(RN_CVAR_FIVE_WHIP_CHANCE), 0, RN_Config_Float(RN_CVAR_FIVE_WHIP_DAMAGE), 0, RN_Config_Float(RN_CVAR_FIVE_WHIP_GUN_COST)*100.0);
        case PLAYBUFF_THUNDER_KING: RN_Buff_DescriptionNumbers(text, maxlength, "电伤害+%s%%，层数加算", RN_Config_Float(RN_CVAR_THUNDER_KING_BONUS)*100.0);
        case PLAYBUFF_PAIN_PLEASURE: RN_Buff_DescriptionNumbers(text, maxlength,
            "受伤续时%s秒，每秒回上限%s%%",
            RN_Config_Float(RN_CVAR_PAIN_PLEASURE_DURATION), 1, RN_Config_Float(RN_CVAR_PAIN_PLEASURE_HEAL_RATIO)*100.0, 1);
        case PLAYBUFF_BLOOD_VIGOR: RN_Buff_DescriptionNumbers(text, maxlength,
            "生命附伤增加最大生命的%s%%", RN_Config_Float(RN_CVAR_BLOOD_VIGOR_HP_RATIO)*100.0, 1);
        case PLAYBUFF_LAST_STRAW: FormatEx(text, maxlength, "「受难爆发」次数-%d，最低%d次",
            RN_Config_Int(RN_CVAR_LAST_STRAW_HITS_REDUCTION), RN_Config_Int(RN_CVAR_KNIGHT_BURST_MIN_HITS));
        default: strcopy(text, maxlength, "");
    }
}

/** 纵横与元素卡显示本层实际增量，距离上限、取整、强运及封顶与触发共用。 */
void RN_Buff_DescriptionForProfile(PlayerProfile profile, int buff, char[] text, int maxlength)
{
    RN_Buff_Description(buff, text, maxlength);
    if (buff == PLAYBUFF_ELECTRIC_ADDICT || buff == PLAYBUFF_FIVE_WHIP || buff == PLAYBUFF_SUPERCONDUCTOR)
    {
        PlayerProfile proposed;
        proposed = profile;
        if (!RN_Math_Add(proposed.buff[buff], 1, proposed.buff[buff])) return;
        float delta = RN_Stats_Percent(RN_Stats_Get(proposed, RN_STAT_ELECTRIC_CHANCE), true)
            - RN_Stats_Percent(RN_Stats_Get(profile, RN_STAT_ELECTRIC_CHANCE), true);
        if (buff == PLAYBUFF_ELECTRIC_ADDICT)
            RN_Buff_DescriptionNumbers(text, maxlength, "电击概率+%s%%", delta);
        else if (buff == PLAYBUFF_FIVE_WHIP)
            RN_Buff_DescriptionNumbers(text, maxlength, "电击+%s%% 电基础伤害+%s\n枪械伤害-%s%%", delta, 0, RN_Config_Float(RN_CVAR_FIVE_WHIP_DAMAGE), 0, RN_Config_Float(RN_CVAR_FIVE_WHIP_GUN_COST)*100.0);
        else
        {
            int extra = RN_Stats_ElectricJumps(proposed) - RN_Stats_ElectricJumps(profile);
            if (extra > 0) FormatEx(text, maxlength, "电弹射目标+%d", extra);
            else strcopy(text, maxlength, "电弹射目标+0，已达当前有效上限");
        }
        return;
    }
    if (buff == PLAYBUFF_CONGXIN && RN_Profession_Is(profile, RN_PROFESSION_REAPER))
    {
        PlayerProfile proposed;
        proposed = profile;
        float delta;
        if (RN_Math_Add(proposed.buff[buff], 1, proposed.buff[buff]))
            delta = RN_Reaper_Remaining(profile) - RN_Reaper_Remaining(proposed);
        RN_Buff_DescriptionNumbers(text, maxlength, "契约惩罚整体降低%s%%", delta*100.0);
        return;
    }
    if (buff == PLAYBUFF_SWORD_REACH && RN_Profession_Sword(profile))
    {
        PlayerProfile proposed;
        proposed = profile;
        float delta;
        if (RN_Math_Add(proposed.buff[buff], 1, proposed.buff[buff]))
            delta = RN_Profession_SwordRange(proposed) - RN_Profession_SwordRange(profile);
        RN_Buff_DescriptionNumbers(text, maxlength, "剑气距离+%s码", delta, 1);
        return;
    }
    if (!RN_Profession_Is(profile, RN_PROFESSION_ELEMENTALIST) ||
        (buff != PLAYBUFF_PROBIGNITE && buff != PLAYBUFF_PROBFREEZE &&
         buff != PLAYBUFF_PYROMANIAC && buff != PLAYBUFF_CRYOPHILIA && buff != PLAYBUFF_DUAL_ELEMENT)) return;
    PlayerProfile proposed;
    proposed = profile;
    if (!RN_Math_Add(proposed.buff[buff], 1, proposed.buff[buff])) return;
    RN_Stat stat = buff == PLAYBUFF_PROBIGNITE || buff == PLAYBUFF_PYROMANIAC ? RN_STAT_IGNITE : RN_STAT_FREEZE;
    float delta = RN_Stats_Percent(RN_Stats_Get(proposed, stat), true) - RN_Stats_Percent(RN_Stats_Get(profile, stat), true);
    switch (buff)
    {
        case PLAYBUFF_PROBIGNITE: RN_Buff_DescriptionNumbers(text, maxlength, "点燃+%s%%，持续%s秒", delta, 0, RN_Config_Float(RN_CVAR_IGNITEDURATION_SURV), 1);
        case PLAYBUFF_PROBFREEZE: RN_Buff_DescriptionNumbers(text, maxlength, "冰冻概率+%s%%，持续%s秒", delta, 0, RN_Config_Float(RN_CVAR_FREEZEDURATION_SURV), 1);
        case PLAYBUFF_PYROMANIAC: RN_Buff_DescriptionNumbers(text, maxlength, "点燃+%s%%，基础灼烧+%s/秒\n枪械伤害-%s%%", delta, 0, RN_Config_Float(RN_CVAR_PYROMANIAC_BURN_DPS_SURV), 0, RN_Config_Float(RN_CVAR_PYROMANIAC_DMGREDUCTION_SURV)*100.0, 0);
        case PLAYBUFF_CRYOPHILIA: RN_Buff_DescriptionNumbers(text, maxlength, "冰冻概率+%s%%，枪械伤害-%s%%", delta, 0, RN_Config_Float(RN_CVAR_CRYOPHILIA_DMGREDUCTION_SURV)*100.0, 0);
        case PLAYBUFF_DUAL_ELEMENT:
        {
            float ignite = RN_Stats_Percent(RN_Stats_Get(proposed, RN_STAT_IGNITE), true) - RN_Stats_Percent(RN_Stats_Get(profile, RN_STAT_IGNITE), true);
            RN_Buff_DescriptionNumbers(text, maxlength, "点燃+%s%% 冰冻+%s%% 枪械伤害-%s%%", ignite, 0, delta, 0, RN_Config_Float(RN_CVAR_DUAL_ELEMENT_DAMAGE_REDUCTION)*100.0);
        }
    }
}
