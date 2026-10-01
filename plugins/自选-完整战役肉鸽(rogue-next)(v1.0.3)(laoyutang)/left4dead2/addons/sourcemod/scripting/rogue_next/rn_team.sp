#if defined _rn_team_included
 #endinput
#endif
#define _rn_team_included

int g_Team_RoundKills;

/** 每次经验事件只读取一次人数系数，历史百分比不因人数变化重算。 */
float RN_Team_Scale(int count)
{
    if (RN_Config_Int(RN_CVAR_XP_SCALE_BY_PLAYERS) == 0) return 1.0;
    int floorCount = RN_Config_Int(RN_CVAR_XP_FLAT_UNTIL_PLAYERS);
    int effective = count > floorCount ? count : floorCount;
    float ratio = float(effective)/RN_Config_Float(RN_CVAR_XP_BASELINE_PLAYERS);
    float minimum = RN_Config_Float(RN_CVAR_XP_SCALE_MIN);
    float maximum = RN_Config_Float(RN_CVAR_XP_SCALE_MAX);
    return ratio < minimum ? minimum : (ratio > maximum ? maximum : ratio);
}

/** 查看界面的即时需求估算，不回写当前百分比。 */
float RN_Team_Need()
{
    return RN_Math_Need(g_Run_Level, RN_Config_Float(RN_CVAR_XP_BASE),
        RN_Config_Float(RN_CVAR_XP_STEP), RN_Config_Float(RN_CVAR_XP_NEED_CAP),
        RN_Team_Scale(RN_Common_SurvivorCount()));
}

/** 准备全部达摩升级入账，含离线档案；任一溢出时不提交任何档案。 */
bool RN_Team_PrepareProfiles(int nextLevel, int gained, ArrayList prepared)
{
    for (int index = 0; index < g_Profile_Records.Length; index++)
    {
        PlayerProfile profile;
        RN_Profile_Get(index, profile);
        int extra, bonus, total, pending;
        if (!RN_Math_Multiply(gained, profile.buff[PLAYBUFF_DAMOCLESSWORD], extra) ||
            !RN_Math_Add(profile.bonusChoices, extra, bonus) ||
            !RN_Math_Budget(g_Run_InitialChoices, g_Run_ChoicesPerLevel, nextLevel,
                bonus, profile.usedChoices, total, pending)) return false;
        profile.bonusChoices = bonus;
        prepared.PushArray(profile, sizeof(profile));
    }
    return true;
}

/** 内存提交没有引擎副作用，最后统一公告和提醒。 */
bool RN_Team_Commit(int nextLevel, float nextProgress, int gained)
{
    ArrayList prepared = new ArrayList(sizeof(PlayerProfile));
    int basic;
    if (!RN_Math_Multiply(gained, g_Run_ChoicesPerLevel, basic) ||
        !RN_Team_PrepareProfiles(nextLevel, gained, prepared))
    {
        delete prepared;
        LogError("[rogue-next] 团队升级预算溢出，保留之前的团队与档案。");
        return false;
    }
    g_Run_Level = nextLevel;
    g_Run_Progress = nextProgress;
    for (int index = 0; index < prepared.Length; index++)
    {
        PlayerProfile profile;
        prepared.GetArray(index, profile, sizeof(profile));
        RN_Profile_Save(index, profile);
    }
    delete prepared;
    if (gained > 0)
    {
        RN_Notify_Upgrade(nextLevel, nextProgress, gained, basic);
        RN_Notify_AllPending();
    }
    return true;
}

/** 按实际浮点XP模拟击杀或管理员经验；保留小数，全部级别和档案预算合法后才提交。 */
bool RN_Team_Gain(float xp, int count)
{
    if (!RN_Config_Enabled() || !RN_Math_Finite(xp) || xp < 0.0 || count <= 0) return false;
    int level, gained;
    float progress;
    if (!RN_Math_GainXP(g_Run_Level, g_Run_Progress, xp,
        RN_Config_Float(RN_CVAR_XP_BASE), RN_Config_Float(RN_CVAR_XP_STEP),
        RN_Config_Float(RN_CVAR_XP_NEED_CAP), RN_Team_Scale(count), level, progress, gained))
    {
        LogError("[rogue-next] XP模拟失败，未提交任何升级。");
        return false;
    }
    if (gained == 0) { g_Run_Progress = progress; return true; }
    return RN_Team_Commit(level, progress, gained);
}

/** 管理员调试等级；降低不回收既得BUFF或历史消费，待选预算自然钳制。 */
bool RN_Team_SetLevel(int level)
{
    if (!RN_Config_Enabled() || level < 0) return false;
    int gained = level > g_Run_Level ? level - g_Run_Level : 0;
    return RN_Team_Commit(level, 0.0, gained);
}

/** 每回合只清调试击杀统计；正常round_start不得清团队成长。 */
void RN_Team_RoundStart()
{
    g_Team_RoundKills = 0;
}

/** 完整新场/失败/终局清理团队数据。 */
void RN_Team_Clear()
{
    g_Run_Level = 0;
    g_Run_Progress = 0.0;
    g_Team_RoundKills = 0;
}
