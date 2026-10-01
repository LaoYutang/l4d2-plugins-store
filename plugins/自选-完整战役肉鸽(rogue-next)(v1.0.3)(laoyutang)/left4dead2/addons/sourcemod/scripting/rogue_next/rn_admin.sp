#if defined _rn_admin_included
 #endinput
#endif
#define _rn_admin_included

/** 输出一份档案账本及效果层数，支持离线SteamID档案。 */
void RN_Admin_PrintProfile(int client, int index)
{
    PlayerProfile profile;
    if (!RN_Profile_Get(index, profile)) { ReplyToCommand(client, "[rogue] 未找到档案。"); return; }
    int total, pending;
    RN_Profile_Budget(profile, total, pending);
    ReplyToCommand(client, "[rogue] #%d %s (%s) stable=%d total=%d used=%d bonus=%d pending=%d roll=%d version=%d neverFallUsed=%d",
        index, profile.name, profile.id, profile.stableIdentity, total, profile.usedChoices,
        profile.bonusChoices, pending, profile.rollLeft, profile.optionVersion, profile.neverFallUsed);
    for (int id = 1; id < MAXBUFFENUM; id++)
    {
        if (profile.buff[id] <= 0) continue;
        char name[64];
        RN_Buff_Name(id, name, sizeof(name));
        ReplyToCommand(client, "[rogue]   %d %s x%d", id, name, profile.buff[id]);
    }
}

/** 查看当前阶段/时间与可选目标；目标优先稳定ID，其次userid。 */
public Action RN_Admin_Info(int client, int args)
{
    ReplyToCommand(client, "[rogue] v%s phase=%d run=%d mapEpoch=%d ready=%d map=%s mission=%s first=%s chapter=%d",
        RN_VERSION, g_Run_Phase, g_Run_Epoch, g_Run_MapEpoch, g_Run_MapReady,
        g_Run_Map, g_Run_Mission, g_Run_FirstMap, g_Run_Chapter);
    ReplyToCommand(client, "[rogue] level=%d progress=%.4f%% need=%.2f N=%d human=%d elapsed=%.2fs tier=%d paused=%d kills=%d profiles=%d",
        g_Run_Level, g_Run_Progress, RN_Team_Need(), RN_Common_SurvivorCount(), RN_Common_HasHuman(),
        RN_Clock_Elapsed(), g_Clock_Tier, g_Clock_PauseStart >= 0.0, g_Team_RoundKills, g_Profile_Records.Length);
    char difficulty[32];
    float rate = RN_XP_Rate(difficulty, sizeof(difficulty));
    ReplyToCommand(client, "[rogue] z_difficulty=%s xpRate=%.3fx", difficulty, rate);
    if (args == 0)
    {
        if (RN_Common_Client(client)) RN_Admin_PrintProfile(client, g_Profile_Index[client]);
        return Plugin_Handled;
    }
    char target[40];
    GetCmdArg(1, target, sizeof(target));
    int index = -1, userid;
    if (!g_Profile_Id2Index.GetValue(target, index))
    {
        bool valid = target[0] == '#' ? RN_Common_ParseUnsigned(target[1], userid) :
            RN_Common_ParseUnsigned(target, userid);
        if (valid)
        {
            int selected = GetClientOfUserId(userid);
            if (RN_Common_Client(selected)) index = g_Profile_Index[selected];
        }
    }
    RN_Admin_PrintProfile(client, index);
    return Plugin_Handled;
}

/** 管理员经验仍走实际团队事务与当前人数缩放。 */
public Action RN_Admin_XP(int client, int args)
{
    char text[32];
    GetCmdArg(1, text, sizeof(text));
    int value;
    if (args != 1 || !RN_Common_ParseUnsigned(text, value))
        ReplyToCommand(client, "[rogue] 用法：sm_rn_xp <非负整数>");
    else if (!RN_Team_Gain(float(value), RN_Common_SurvivorCount()))
        ReplyToCommand(client, "[rogue] XP操作被拒绝，检查阶段/开关/数值范围。");
    else ReplyToCommand(client, "[rogue] 团队Lv.%d，%.4f%%。", g_Run_Level, g_Run_Progress);
    return Plugin_Handled;
}

/** 降级只归零当前进度，不追回既得层数和历史消费。 */
public Action RN_Admin_Level(int client, int args)
{
    char text[32];
    GetCmdArg(1, text, sizeof(text));
    int value;
    if (args != 1 || !RN_Common_ParseUnsigned(text, value))
        ReplyToCommand(client, "[rogue] 用法：sm_rn_level <非负整数>");
    else if (!RN_Team_SetLevel(value))
        ReplyToCommand(client, "[rogue] 等级操作被拒绝，之前数据保留。");
    else ReplyToCommand(client, "[rogue] 团队等级已设为%d。", g_Run_Level);
    return Plugin_Handled;
}

/** 当前地图重置；入口负责资源、属性、代次和计时顺序。 */
public Action RN_Admin_Reset(int client, int args)
{
    if (!g_Run_MapReady) ReplyToCommand(client, "[rogue] 地图尚未就绪，不能重置。");
    else
    {
        RN_ResetCurrentMap();
        ReplyToCommand(client, "[rogue] 已在当前地图建立新对局。");
    }
    return Plugin_Handled;
}

/** 所有调试入口都要求ROOT权限。 */
void RN_Admin_Init()
{
    RegAdminCmd("sm_rn_info", RN_Admin_Info, ADMFLAG_ROOT);
    RegAdminCmd("sm_rn_xp", RN_Admin_XP, ADMFLAG_ROOT);
    RegAdminCmd("sm_rn_level", RN_Admin_Level, ADMFLAG_ROOT);
    RegAdminCmd("sm_rn_reset", RN_Admin_Reset, ADMFLAG_ROOT);
}

