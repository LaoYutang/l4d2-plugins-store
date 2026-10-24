#if defined _rn_branch_included
 #endinput
#endif
#define _rn_branch_included

int g_Branch_RemindSerial[MAXPLAYERS + 1];
int g_Branch_RemindRun[MAXPLAYERS + 1];
int g_Branch_RemindProfile[MAXPLAYERS + 1];

/** 分支顺序与基础职业一一对应，不将HUD名称用于真实资格。 */
int RN_Branch_Profession(int branch)
{
    return branch > RN_BRANCH_NONE && branch < RN_BRANCH_COUNT ? (branch + 1) / 2 : RN_PROFESSION_NONE;
}

/** 存档验证不受功能开关影响，禁止跨职业分支和负版本进入档案。 */
bool RN_Branch_Valid(PlayerProfile profile)
{
    return profile.branchVersion >= 0 && profile.branch >= RN_BRANCH_NONE && profile.branch < RN_BRANCH_COUNT &&
        (profile.branch == RN_BRANCH_NONE || RN_Branch_Profession(profile.branch) == profile.profession);
}

/** 纯档案能力判定沿用职业开关，不因临时死亡或管理员降级抹掉已选分支。 */
bool RN_Branch_Active(PlayerProfile profile, int branch)
{
    return branch > RN_BRANCH_NONE && branch < RN_BRANCH_COUNT && profile.branch == branch &&
        RN_Branch_Valid(profile) && RN_Profession_Is(profile, RN_Branch_Profession(branch));
}

/** 战斗入口只读取启用状态下真人生还者的真实档案，BOT和错误映射均返回未转职。 */
int RN_Branch_Get(int client)
{
    PlayerProfile profile;
    return RN_Config_Enabled() && RN_Common_Survivor(client) && !IsFakeClient(client) &&
        RN_Profile_Get(g_Profile_Index[client], profile) && RN_Branch_Active(profile, profile.branch)
        ? profile.branch : RN_BRANCH_NONE;
}

/** 菜单、HUD与查询共用分支称号，未转职不伪装成基础职业。 */
void RN_Branch_Name(int branch, char[] text, int maxlength)
{
    static const char names[][] = {"未转职", "战术", "谢幕", "居合", "剑豪", "烈焰", "雷电", "鹰眼", "游侠", "夺命", "舞者", "和平", "混乱", "守护", "圣光"};
    strcopy(text, maxlength, names[branch >= 0 && branch < sizeof(names) ? branch : 0]);
}

/** HUD保持原两字基础职业回退，已选有效分支仅替换显示称号。 */
void RN_Branch_DisplayName(PlayerProfile profile, char[] text, int maxlength)
{
    static const char names[][] = {"未选", "士兵", "剑客", "元素", "狙神", "死神", "艺术", "骑士"};
    if (RN_Branch_Active(profile, profile.branch)) RN_Branch_Name(profile.branch, text, maxlength);
    else strcopy(text, maxlength, names[profile.profession >= 0 && profile.profession < sizeof(names) ? profile.profession : 0]);
}

/** 自身查询只增加一句核心能力，保留基础职业与原有属性信息。 */
void RN_Branch_Description(int branch, char[] text, int maxlength)
{
    static const char descriptions[][] = {
        "", "换弹余弹越多，下一弹夹伤害越高。", "弹夹最后一发增伤50%。",
        "蓄刀2秒，剑气加宽，增伤150%。", "每第3次攻击剑气加宽，增伤50%。",
        "燃烧时间延长2秒。", "电链可往返弹跳，每跳增伤30%。",
        "站立越久伤害越高，5秒增伤100%。", "移动越久伤害越高，5秒增伤100%。",
        "对满血目标增伤100%。", "血量越低伤害越高，最高增伤100%。",
        "取消弹跳，将后续伤害集中为一次爆炸。", "弹跳次数增加1次，每跳增伤20%。",
        "代受200码内队友的伤害。", "攻击队友可治疗，并提供50%增伤3秒。"
    };
    strcopy(text, maxlength, descriptions[branch >= 0 && branch < sizeof(descriptions) ? branch : 0]);
}

/** 资格由共享等级派生，晚加入、跨级和重连无需补发普通卡或独立奖励。 */
bool RN_Branch_Ready(PlayerProfile profile)
{
    return RN_Config_Enabled() && RN_Config_Int(RN_CVAR_PROFESSION_ENABLE) != 0 && g_Run_Level >= 13 &&
        profile.branch == RN_BRANCH_NONE && profile.profession > RN_PROFESSION_NONE &&
        profile.profession < RN_PROFESSION_COUNT && RN_Branch_Valid(profile);
}

/** 高等级玩家即使没有普通待选次数，也可先免费确定基础职业再转职。 */
bool RN_Branch_NeedsProfession(PlayerProfile profile)
{
    return RN_Config_Enabled() && RN_Config_Int(RN_CVAR_PROFESSION_ENABLE) != 0 && g_Run_Level >= 13 &&
        profile.profession == RN_PROFESSION_NONE && profile.branch == RN_BRANCH_NONE && RN_Branch_Valid(profile);
}

/** 新解锁及重新绑定只私人提醒一次，不自动显示菜单或修改选择预算。 */
void RN_Branch_Remind(int client)
{
    PlayerProfile profile;
    if (!RN_Common_Survivor(client) || IsFakeClient(client) ||
        !RN_Profile_Get(g_Profile_Index[client], profile) ||
        (!RN_Branch_Ready(profile) && !RN_Branch_NeedsProfession(profile))) return;
    int serial = GetClientSerial(client), index = g_Profile_Index[client];
    if (g_Branch_RemindSerial[client] == serial && g_Branch_RemindRun[client] == g_Run_Epoch &&
        g_Branch_RemindProfile[client] == index) return;
    g_Branch_RemindSerial[client] = serial;
    g_Branch_RemindRun[client] = g_Run_Epoch;
    g_Branch_RemindProfile[client] = index;
    PrintToChat(client, "\x04[Rogue]\x01已解锁免费转职，输入 !ba 选择；本战役只能选择一次。");
}
