#if defined _rn_admin_included
 #endinput
#endif
#define _rn_admin_included

/** 单人显示全员排名，未贡献明确标明；暂停统计仍可查看已保存的累计。 */
void RN_Admin_PrintDamage(int client, int index, const int[][] leaders, int used, const int whole[2])
{
    int value[2], rank;
    if (g_Damage_Totals != null && index < g_Damage_Totals.Length)
        g_Damage_Totals.GetArray(index, value, sizeof(value));
    char amount[32], percent[24];
    RN_Damage_Text(value, amount, sizeof(amount));
    if (used < 0)
    {
        ReplyToCommand(client, "[Rogue]   累计伤害=%s 占比=无法计算 排名=无法计算", amount);
        return;
    }
    RN_Damage_Percent(value, whole, percent, sizeof(percent));
    for (int row = 0; row < used; row++)
        if (leaders[row][0] == index) { rank = row + 1; break; }
    if (rank > 0) ReplyToCommand(client, "[Rogue]   累计伤害=%s 占比=%s%% 排名=%d", amount, percent, rank);
    else ReplyToCommand(client, "[Rogue]   累计伤害=%s 占比=%s%% 排名=未上榜", amount, percent);
}

/** BUFF层数只输出一次标题，每行两项，奇数末项与空档案明确输出。 */
void RN_Admin_PrintBuffs(int client, PlayerProfile profile)
{
    ReplyToCommand(client, "[Rogue]   BUFF层数：");
    char entries[2][80];
    int used, count;
    for (int id = 1; id < MAXBUFFENUM; id++)
    {
        if (profile.buff[id] <= 0) continue;
        char name[64];
        RN_Buff_Name(id, name, sizeof(name));
        FormatEx(entries[used], sizeof(entries[]), "%s x%d", name, profile.buff[id]);
        used++; count++;
        if (used == 2)
        {
            ReplyToCommand(client, "[Rogue]     %s | %s", entries[0], entries[1]);
            used = 0;
        }
    }
    if (used == 1) ReplyToCommand(client, "[Rogue]     %s", entries[0]);
    if (count == 0) ReplyToCommand(client, "[Rogue]     暂无BUFF");
}

/** 复用个人查看的全部实际合计属性，查询结束立即释放临时行容器。 */
void RN_Admin_PrintAttributes(int client, PlayerProfile profile)
{
    if (!RN_Config_Enabled())
    {
        ReplyToCommand(client, "[Rogue]   当前合计属性：Rogue已关闭，属性加成未生效。");
        return;
    }
    int attributes;
    Menu details = RN_Menu_BuildView(profile, attributes);
    if (details == null)
    {
        ReplyToCommand(client, "[Rogue]   当前合计属性：计算失败，请检查档案或配置。");
        return;
    }
    ReplyToCommand(client, "[Rogue]   当前合计属性（%d项）：", attributes);
    for (int item = 0; item < details.ItemCount; item++)
    {
        char info[1], text[192];
        int style;
        if (details.GetItem(item, info, sizeof(info), style, text, sizeof(text)))
            ReplyToCommand(client, "[Rogue]     %s", text);
    }
    delete details;
}

/** 用中文输出职业、伤害、档案账本、BUFF层数和合计属性，支持离线SteamID档案。 */
void RN_Admin_PrintProfile(int client, int index, const int[][] leaders, int used, const int whole[2])
{
    PlayerProfile profile;
    if (!RN_Profile_Get(index, profile)) { ReplyToCommand(client, "[Rogue] 未找到档案。"); return; }
    int total, pending;
    RN_Profile_Budget(profile, total, pending);
    char profession[64];
    RN_Profession_Name(profile.profession, profession, sizeof(profession));
    if (profile.profession != RN_PROFESSION_NONE && RN_Config_Int(RN_CVAR_PROFESSION_ENABLE) == 0)
        StrCat(profession, sizeof(profession), "（已停用）");
    ReplyToCommand(client, "[Rogue] 档案#%d 玩家=%s 标识=%s", index, profile.name, profile.id);
    ReplyToCommand(client, "[Rogue]   职业=%s 稳定身份=%s", profession, profile.stableIdentity ? "是" : "否");
    RN_Admin_PrintDamage(client, index, leaders, used, whole);
    ReplyToCommand(client, "[Rogue]   累计特感=%d", RN_HUDStats_Read(index));
    ReplyToCommand(client, "[Rogue]   总加点=%d 已用=%d 额外=%d 待选=%d 剩余重抽=%d",
        total, profile.usedChoices, profile.bonusChoices, pending, profile.rollLeft);
    ReplyToCommand(client, "[Rogue]   候选版本=%d 读档已用=%d", profile.optionVersion, profile.neverFallUsed);
    RN_Admin_PrintBuffs(client, profile);
    RN_Admin_PrintAttributes(client, profile);
}

/** 手动榜单仅回复执行者，人数与HUD独立配置，查询不改变战役状态。 */
void RN_Admin_PrintRanking(int client, const int[][] leaders, int used, const int whole[2])
{
    if (used < 0)
    {
        ReplyToCommand(client, "[Rogue] 伤害累计超出统计容量，无法显示排名和占比。");
        return;
    }
    if (used == 0)
    {
        ReplyToCommand(client, "[Rogue] 战役累计伤害排名：暂无有效伤害。");
        return;
    }
    ReplyToCommand(client, "[Rogue] 战役累计伤害排名");
    int limit = RN_Config_Int(RN_CVAR_DAMAGE_STATS_TOP);
    if (limit == 0 || limit > used) limit = used;
    for (int rank = 0; rank < limit; rank++)
    {
        char row[256];
        if (RN_Damage_RankText(leaders[rank], rank + 1, whole, row, sizeof(row)))
            ReplyToCommand(client, "[Rogue] %s", row);
    }
}

/** 中文查看全局状态；无目标列出全部战役档案，单人查询优先稳定ID再userid。 */
public Action RN_Admin_Info(int client, int args)
{
    static const char phases[][] = {"准备中", "进行中", "切换章节", "重新开始", "已结束"};
    int phase = view_as<int>(g_Run_Phase);
    ReplyToCommand(client, "[Rogue] 版本=%s 阶段=%s 战役代次=%d 地图代次=%d 地图就绪=%s",
        RN_VERSION, phases[phase >= 0 && phase < sizeof(phases) ? phase : 0],
        g_Run_Epoch, g_Run_MapEpoch, g_Run_MapReady ? "是" : "否");
    ReplyToCommand(client, "[Rogue] 当前地图=%s 战役文件=%s 首图=%s 章节=%d",
        g_Run_Map, g_Run_Mission, g_Run_FirstMap, g_Run_Chapter);
    ReplyToCommand(client, "[Rogue] 等级=%d 进度=%.4f%% 升级所需经验=%.2f 生还者人数=%d 真人在队=%s",
        g_Run_Level, g_Run_Progress, RN_Team_Need(), RN_Common_SurvivorCount(), RN_Common_HasHuman() ? "是" : "否");
    ReplyToCommand(client, "[Rogue] 有效时间=%.2f秒 时间难度档=%d 计时暂停=%s 本轮击杀=%d 玩家档案=%d",
        RN_Clock_Elapsed(), g_Clock_Tier, g_Clock_PauseStart >= 0.0 ? "是" : "否",
        g_Team_RoundKills, g_Profile_Records.Length);
    char difficulty[32];
    float rate = RN_XP_Rate(difficulty, sizeof(difficulty));
    if (StrEqual(difficulty, "Easy", false)) strcopy(difficulty, sizeof(difficulty), "简单");
    else if (StrEqual(difficulty, "Normal", false)) strcopy(difficulty, sizeof(difficulty), "普通");
    else if (StrEqual(difficulty, "Hard", false)) strcopy(difficulty, sizeof(difficulty), "高级");
    else if (StrEqual(difficulty, "Impossible", false)) strcopy(difficulty, sizeof(difficulty), "专家");
    ReplyToCommand(client, "[Rogue] 游戏难度=%s 经验倍率=%.3fx", difficulty, rate);
    if (RN_Disaster_Active())
    {
        char disaster[32], detail[80], game[16];
        RN_Disaster_Text(disaster, sizeof(disaster), detail, sizeof(detail));
        RN_Disaster_GameName(game, sizeof(game));
        ReplyToCommand(client, "[Rogue] 灾害=%s 效果=%s 章初游戏难度=%s 触发概率=%.1f%% 强度时间档=%d 本章已出门=%s",
            disaster, detail, game, g_Disaster_Chance, g_Disaster_Tier,
            g_Disaster_Departed ? "是" : "否");
    }
    else ReplyToCommand(client, "[Rogue] 灾害=%s", g_Disaster_Terminated ? "本章停用" : "本章无灾害");
    ReplyToCommand(client, "[Rogue] 伤害统计=%s",
        RN_Config_Enabled() && RN_Config_Int(RN_CVAR_DAMAGE_STATS_ENABLE) != 0 ? "已启用" : "已停用（保留累计）");
    int count = g_Profile_Records.Length;
    int[][] leaders = new int[count > 0 ? count : 1][3];
    int whole[2];
    int used = RN_Damage_Ranking(leaders, count, whole);
    if (args == 0)
    {
        RN_Admin_PrintRanking(client, leaders, used, whole);
        if (g_Profile_Records.Length == 0) ReplyToCommand(client, "[Rogue] 当前没有玩家档案。");
        for (int index = 0; index < count; index++) RN_Admin_PrintProfile(client, index, leaders, used, whole);
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
    RN_Admin_PrintProfile(client, index, leaders, used, whole);
    return Plugin_Handled;
}

/** 管理员经验仍走实际团队事务与当前人数缩放。 */
public Action RN_Admin_XP(int client, int args)
{
    char text[32];
    GetCmdArg(1, text, sizeof(text));
    int value;
    if (args != 1 || !RN_Common_ParseUnsigned(text, value))
        ReplyToCommand(client, "[Rogue] 用法：sm_rn_xp <非负整数>");
    else if (!RN_Team_Gain(float(value), RN_Common_SurvivorCount()))
        ReplyToCommand(client, "[Rogue] XP操作被拒绝，检查阶段/开关/数值范围。");
    else ReplyToCommand(client, "[Rogue] 团队Lv.%d，%.4f%%。", g_Run_Level, g_Run_Progress);
    return Plugin_Handled;
}

/** 降级只归零当前进度，不追回既得层数和历史消费。 */
public Action RN_Admin_Level(int client, int args)
{
    char text[32];
    GetCmdArg(1, text, sizeof(text));
    int value;
    if (args != 1 || !RN_Common_ParseUnsigned(text, value))
        ReplyToCommand(client, "[Rogue] 用法：sm_rn_level <非负整数>");
    else if (!RN_Team_SetLevel(value))
        ReplyToCommand(client, "[Rogue] 等级操作被拒绝，之前数据保留。");
    else ReplyToCommand(client, "[Rogue] 团队等级已设为%d。", g_Run_Level);
    return Plugin_Handled;
}

/** 当前地图重置；入口负责资源、属性、代次和计时顺序。 */
public Action RN_Admin_Reset(int client, int args)
{
    if (!g_Run_MapReady) ReplyToCommand(client, "[Rogue] 地图尚未就绪，不能重置。");
    else
    {
        RN_ResetCurrentMap();
        ReplyToCommand(client, "[Rogue] 已在当前地图建立新对局。");
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
