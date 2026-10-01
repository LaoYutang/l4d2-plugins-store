#if defined _rn_buff_defs_included
 #endinput
#endif
#define _rn_buff_defs_included

/** 生成当前配置的效果说明；卡片、查看界面使用同一份实现。 */
void RN_Buff_Description(int buff, char[] text, int maxlength)
{
    switch (buff)
    {
        case PLAYBUFF_MAXHEALTH: FormatEx(text, maxlength, "血量上限+%d，获得时奖励新增实血", RN_Config_Int(RN_CVAR_ADDMAXHEALTH_SURV));
        case PLAYBUFF_HEALING: FormatEx(text, maxlength, "每秒回复%.2f实血", RN_Config_Float(RN_CVAR_HEALHP_SURV));
        case PLAYBUFF_MAGAZINE: FormatEx(text, maxlength, "全队弹匣容量+%.0f%%", RN_Config_Float(RN_CVAR_MAGAZINEMULTIPLE_SURV)*100.0);
        case PLAYBUFF_RELOADSPEED: FormatEx(text, maxlength, "全队换弹时间-%.0f%%", RN_Config_Float(RN_CVAR_RELOADSPEEDMULTIPLE_SURV)*100.0);
        case PLAYBUFF_FIRERATE: FormatEx(text, maxlength, "全队射击间隔-%.0f%%", RN_Config_Float(RN_CVAR_FIRERATEMULTIPLE_SURV)*100.0);
        case PLAYBUFF_CAUSEHARM: FormatEx(text, maxlength, "输出加成+%.0f%%", RN_Config_Float(RN_CVAR_ADDMULTIPLE_SURV)*100.0);
        case PLAYBUFF_PUTONGQUANPU: FormatEx(text, maxlength, "输出加成+%.0f%%", RN_Config_Float(RN_CVAR_PUTONGQUANPU_ADDMULTIPLE_SURV)*100.0);
        case PLAYBUFF_SUFFERHRAM: FormatEx(text, maxlength, "承伤减免+%.0f%%", RN_Config_Float(RN_CVAR_SUBMULTIPLE_SURV)*100.0);
        case PLAYBUFF_PROBINVULNERABILITY: FormatEx(text, maxlength, "每层%d%%概率免疫四类控制，受强运影响", RN_Config_Int(RN_CVAR_PROBINVINCIBILITY_SURV));
        case PLAYBUFF_POWANGFA: FormatEx(text, maxlength, "每层%d%%概率免疫四类控制，受强运影响", RN_Config_Int(RN_CVAR_POWANGFA_PROBINVINCIBILITY_SURV));
        case PLAYBUFF_PROBIGNITE: FormatEx(text, maxlength, "%d%%概率点燃，持续%.1f秒", RN_Config_Int(RN_CVAR_PROBIGNITE_SURV), RN_Config_Float(RN_CVAR_IGNITEDURATION_SURV));
        case PLAYBUFF_PROBFREEZE: FormatEx(text, maxlength, "%d%%概率冰冻，持续%.1f秒", RN_Config_Int(RN_CVAR_PROBFREEZE_SURV), RN_Config_Float(RN_CVAR_FREEZEDURATION_SURV));
        case PLAYBUFF_NEVERFALL: FormatEx(text, maxlength, "增加%d次倒地拦截，回复%d实血", RN_Config_Int(RN_CVAR_NEVERFALLNUM_SURV), RN_Config_Int(RN_CVAR_NEVERFALLHEALTH_SURV));
        case PLAYBUFF_MOVESPEED: FormatEx(text, maxlength, "移速+%.0f%%", RN_Config_Float(RN_CVAR_MOVESPEEDMULTIPLE_SURV)*100.0);
        case PLAYBUFF_LUOYANEBU: FormatEx(text, maxlength, "移速+%.0f%%", RN_Config_Float(RN_CVAR_LUOYANEBU_MOVESPEEDMULTIPLE_SURV)*100.0);
        case PLAYBUFF_GLASSCANNON: FormatEx(text, maxlength, "输出+%.0f%%，承伤+%.0f%%", RN_Config_Float(RN_CVAR_GLASSCANNON_DAMAGE_SURV)*100.0, RN_Config_Float(RN_CVAR_GLASSCANNON_DAMAGEREDUCTION_SURV)*100.0);
        case PLAYBUFF_PYROMANIAC: FormatEx(text, maxlength, "点燃概率+%.0f%%，输出-%.0f%%", RN_Config_Float(RN_CVAR_PYROMANIAC_PROBIGNITE_SURV), RN_Config_Float(RN_CVAR_PYROMANIAC_DMGREDUCTION_SURV)*100.0);
        case PLAYBUFF_CRYOPHILIA: FormatEx(text, maxlength, "冰冻概率+%.0f%%，输出-%.0f%%", RN_Config_Float(RN_CVAR_CRYOPHILIA_PROBFREEZE_SURV), RN_Config_Float(RN_CVAR_CRYOPHILIA_DMGREDUCTION_SURV)*100.0);
        case PLAYBUFF_DAMOCLESSWORD: FormatEx(text, maxlength, "此后每次升级额外选择+1；每秒每层%d/万概率承受999普通伤害", RN_Config_Int(RN_CVAR_DAMOCLESSWORD_DEATHPROB_SURV));
        case PLAYBUFF_IMMOVABLE: FormatEx(text, maxlength, "上限+%d，移速-%.0f%%", RN_Config_Int(RN_CVAR_IMMOVABLE_MAXHEALTH_SURV), RN_Config_Float(RN_CVAR_IMMOVABLE_MOVESPEEDREDUCTION_SURV)*100.0);
        case PLAYBUFF_DUOBAOXIANREN: FormatEx(text, maxlength, "ROLL+%d", RN_Config_Int(RN_CVAR_DUOBAOXIANREN_ROLLBONUS_SURV));
        case PLAYBUFF_SHILENBAODI: FormatEx(text, maxlength, "ROLL+%d", RN_Config_Int(RN_CVAR_SHILENBAODI_ROLLBONUS_SURV));
        case PLAYBUFF_SHUANGSHENGHUA: strcopy(text, maxlength, "按手选前层数额外复制手选效果；不复制自身/D4/繁星");
        case PLAYBUFF_SHENGSHENGBUXI: strcopy(text, maxlength, "免疫所有伤害");
        case PLAYBUFF_TIANXINGJIAN: FormatEx(text, maxlength, "免伤+%.0f%%，每秒回血%.2f", RN_Config_Float(RN_CVAR_TIANXINGJIAN_SUBMULTIPLE_SURV)*100.0, RN_Config_Float(RN_CVAR_TIANXINGJIAN_HEALHP_SURV));
        case PLAYBUFF_SHEXINGZOUWEI: FormatEx(text, maxlength, "闪避概率+%.0f%%，受强运影响", RN_Config_Float(RN_CVAR_SHEXINGZOUWEI_DODGECHANCE_SURV));
        case PLAYBUFF_ZIZAIJIYI: FormatEx(text, maxlength, "闪避概率+%.0f%%，受强运影响", RN_Config_Float(RN_CVAR_ZIZAIJIYI_DODGECHANCE_SURV));
        case PLAYBUFF_YIJIANSANLIAN: FormatEx(text, maxlength, "上限+%d，回血%.2f/秒，输出+%.0f%%", RN_Config_Int(RN_CVAR_YIJIANSANLIAN_MAXHEALTH_SURV), RN_Config_Float(RN_CVAR_YIJIANSANLIAN_HEALHP_SURV), RN_Config_Float(RN_CVAR_YIJIANSANLIAN_DAMAGE_SURV)*100.0);
        case PLAYBUFF_ZAILAIYIPING: strcopy(text, maxlength, "额外选择+1");
        case PLAYBUFF_HAIYOUSANBEI: strcopy(text, maxlength, "额外选择+3");
        case PLAYBUFF_XINLATIANSAI: strcopy(text, maxlength, "最终输出独立乘以(1+层数)");
        case PLAYBUFF_JIFA: FormatEx(text, maxlength, "信念+1；达到%d/%d/%d时发当前最高档随机奖励", RN_Config_Int(RN_CVAR_FAITH_RARE_THRESHOLD), RN_Config_Int(RN_CVAR_FAITH_EPIC_THRESHOLD), RN_Config_Int(RN_CVAR_FAITH_LEGENDARY_THRESHOLD));
        case PLAYBUFF_DIANREN: strcopy(text, maxlength, "获得所有普通BUFF各一次");
        case PLAYBUFF_ZHIMINGYIJI: FormatEx(text, maxlength, "暴击率+%.0f%%", RN_Config_Float(RN_CVAR_ZHIMINGYIJI_CRITRATE_SURV)*100.0);
        case PLAYBUFF_AIYOUWEI: FormatEx(text, maxlength, "暴击率+%.0f%%", RN_Config_Float(RN_CVAR_AIYOUWEI_CRITRATE_SURV)*100.0);
        case PLAYBUFF_JIANSHENG: FormatEx(text, maxlength, "暴击倍率+%.2f", RN_Config_Float(RN_CVAR_JIANSHENG_CRITDAMAGE_SURV));
        case PLAYBUFF_HUANYINGCIKE: FormatEx(text, maxlength, "暴击倍率+%.2f", RN_Config_Float(RN_CVAR_HUANYINGCIKE_CRITDAMAGE_SURV));
        case PLAYBUFF_QIANGYUN: FormatEx(text, maxlength, "概率效果乘以(1+%.2f×层数)", RN_Config_Float(RN_CVAR_QIANGYUN_PROBBONUS_SURV));
        case PLAYBUFF_ZHAOZAI: FormatEx(text, maxlength, "每秒每层%d/万概率在前方生成Tank", RN_Config_Int(RN_CVAR_ZHAOZAI_SPAWNTANKPROB_SURV));
        case PLAYBUFF_YUXI: strcopy(text, maxlength, "兑换全部历史预算，随机重抽同等次数；保留ROLL");
        case PLAYBUFF_BAOTIANMA: FormatEx(text, maxlength, "近战加成+%.0f%%", RN_Config_Float(RN_CVAR_BAOTIANMA_MELEEDAMAGE_SURV)*100.0);
        case PLAYBUFF_SANDAOLIU: FormatEx(text, maxlength, "近战加成+%.0f%%", RN_Config_Float(RN_CVAR_SANDAOLIU_MELEEDAMAGE_SURV)*100.0);
        case PLAYBUFF_JIEWANGQUAN: FormatEx(text, maxlength, "近战加成+%.0f%%", RN_Config_Float(RN_CVAR_JIEWANGQUAN_MELEEDAMAGE_SURV)*100.0);
        case PLAYBUFF_FANXING: FormatEx(text, maxlength, "兑换历史预算并清BUFF，获得%d次新选择；保留ROLL", RN_Config_Int(RN_CVAR_FANXING_CHOICES));
        case PLAYBUFF_YELI: strcopy(text, maxlength, "业力+1，提供3层信念；单独获得业力不触发激发奖励");
        case PLAYBUFF_BOZANG: strcopy(text, maxlength, "有效被击杀时，每层获得一个随机普通BUFF");
        case PLAYBUFF_FENGGUANGDAZANG: strcopy(text, maxlength, "有效被击杀时，每层50%获得稀有BUFF，50%出现倒爷");
        default: strcopy(text, maxlength, "");
    }
}

