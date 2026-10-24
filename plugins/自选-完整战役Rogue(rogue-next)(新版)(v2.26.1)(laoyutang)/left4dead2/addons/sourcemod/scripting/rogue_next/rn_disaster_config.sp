#if defined _rn_disaster_config_included
 #endinput
#endif
#define _rn_disaster_config_included

/** 概率按四档游戏难度配置，强度按章初时间档位封顶。 */
void RN_Disaster_BuildConfig()
{
    RN_Config_Define(RN_CVAR_DISASTER_ENABLE, "rne_disaster_enable", "1",
        "启用章节灾害；关闭结束本章全部效果，重新开启下一章参与；HUD关闭也停用", true, 0.0, 1.00);
    RN_Config_Define(RN_CVAR_DISASTER_CHANCE_EASY, "rne_disaster_chance_easy", "10",
        "简单难度灾害概率百分比；首章不触发，下一章生效", false, 0.0, 100.00);
    RN_Config_Define(RN_CVAR_DISASTER_CHANCE_NORMAL, "rne_disaster_chance_normal", "20",
        "普通难度灾害概率百分比；首章不触发，下一章生效", false, 0.0, 100.00);
    RN_Config_Define(RN_CVAR_DISASTER_CHANCE_HARD, "rne_disaster_chance_hard", "30",
        "高级难度灾害概率百分比；首章不触发，下一章生效", false, 0.0, 100.00);
    RN_Config_Define(RN_CVAR_DISASTER_CHANCE_EXPERT, "rne_disaster_chance_expert", "40",
        "专家难度灾害概率百分比；首章不触发，下一章生效", false, 0.0, 100.00);
    RN_Config_Define(RN_CVAR_DISASTER_WEIGHT_ELEMENT, "rne_disaster_weight_element", "1",
        "元素浩劫抽取权重；0不参与，下一章生效", true, 0.0, -1.00);
    RN_Config_Define(RN_CVAR_DISASTER_WEIGHT_PHYSICAL, "rne_disaster_weight_physical", "1",
        "铜墙铁壁抽取权重；0不参与，下一章生效", true, 0.0, -1.00);
    RN_Config_Define(RN_CVAR_DISASTER_WEIGHT_MUD, "rne_disaster_weight_mud", "1",
        "如陷泥潭抽取权重；0不参与，下一章生效", true, 0.0, -1.00);
    RN_Config_Define(RN_CVAR_DISASTER_WEIGHT_MONSOON, "rne_disaster_weight_monsoon", "1",
        "季风抽取权重；0不参与，下一章生效", true, 0.0, -1.00);
    RN_Config_Define(RN_CVAR_DISASTER_WEIGHT_PUNISHMENT, "rne_disaster_weight_punishment", "1",
        "天罚抽取权重；0不参与，下一章生效", true, 0.0, -1.00);
    RN_Config_Define(RN_CVAR_DISASTER_ELEMENT_PER_TIER, "rne_disaster_element_per_tier", "0.10",
        "元素浩劫每时间档位抗性；下一章生效", false, 0.0, 0.50);
    RN_Config_Define(RN_CVAR_DISASTER_ELEMENT_CAP, "rne_disaster_element_cap", "0.50",
        "元素浩劫抗性上限；下一章生效", false, 0.0, 0.50);
    RN_Config_Define(RN_CVAR_DISASTER_PHYSICAL_PER_TIER, "rne_disaster_physical_per_tier", "0.10",
        "铜墙铁壁每时间档位抗性；下一章生效", false, 0.0, 0.50);
    RN_Config_Define(RN_CVAR_DISASTER_PHYSICAL_CAP, "rne_disaster_physical_cap", "0.50",
        "铜墙铁壁抗性上限；下一章生效", false, 0.0, 0.50);
    RN_Config_Define(RN_CVAR_DISASTER_MUD_PER_TIER, "rne_disaster_mud_per_tier", "0.10",
        "如陷泥潭每时间档位独立减速；下一章生效", false, 0.0, 0.30);
    RN_Config_Define(RN_CVAR_DISASTER_MUD_CAP, "rne_disaster_mud_cap", "0.30",
        "如陷泥潭减速上限，最终倍率最低0.1；下一章生效", false, 0.0, 0.30);
    RN_Config_Define(RN_CVAR_DISASTER_MONSOON_PER_TIER, "rne_disaster_monsoon_per_tier", "0.10",
        "季风每时间档位地面加速；下一章生效", false, 0.0, 0.50);
    RN_Config_Define(RN_CVAR_DISASTER_MONSOON_CAP, "rne_disaster_monsoon_cap", "0.30",
        "季风加速上限，默认30%、可调0至50%；下一章生效", false, 0.0, 0.50);
    RN_Config_Define(RN_CVAR_DISASTER_PUNISHMENT_PER_TIER, "rne_disaster_punishment_per_tier", "1.0",
        "天罚每时间档位每秒扣血；下一章生效", false, 0.0, 3.00);
    RN_Config_Define(RN_CVAR_DISASTER_PUNISHMENT_CAP, "rne_disaster_punishment_cap", "3.0",
        "天罚每秒上限，先临时血后实血、最低1血；下一章生效", false, 0.0, 3.00);
}

/** 五项权重合计检查整数溢出，全零是合法停用卡池。 */
bool RN_Disaster_ValidateConfig(const float values[RN_CVAR_COUNT])
{
    int total;
    for (int i = view_as<int>(RN_CVAR_DISASTER_WEIGHT_ELEMENT); i <= view_as<int>(RN_CVAR_DISASTER_WEIGHT_PUNISHMENT); i++)
        if (!RN_Math_Add(total, RoundToZero(values[i]), total))
        {
            LogError("[rogue-next] 灾害权重合计溢出，保留原配置。");
            return false;
        }
    return true;
}
