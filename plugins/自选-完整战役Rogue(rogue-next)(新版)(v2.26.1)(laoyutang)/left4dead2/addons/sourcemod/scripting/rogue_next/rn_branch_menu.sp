#if defined _rn_branch_menu_included
 #endinput
#endif
#define _rn_branch_menu_included

Menu g_BranchMenu_Open[MAXPLAYERS + 1];

/** 手动入口优先提供免费分支，高等级未选基础职业者先选职业，零普通余额亦可进入。 */
bool RN_BranchMenu_Route(int client, PlayerProfile profile)
{
    if (RN_Branch_Ready(profile)) { RN_Menu_Close(client); RN_BranchMenu_Show(client, profile); return true; }
    if (RN_Branch_NeedsProfession(profile)) { RN_Menu_Close(client); RN_ProfessionMenu_Show(client, profile); return true; }
    return false;
}

/** 个人与管理员共用同一条分支说明，不复制选择菜单多行文案。 */
void RN_BranchMenu_Details(Menu menu, PlayerProfile profile)
{
    if (!RN_Branch_Active(profile, profile.branch)) return;
    char name[32], description[160];
    RN_Branch_Name(profile.branch, name, sizeof(name));
    RN_Branch_Description(profile.branch, description, sizeof(description));
    RN_Menu_Detail(menu, "%s：%s", name, description);
}

/** 只返回已确认的当前职业两项简版说明，不混入待定规则或额外确认页。 */
void RN_BranchMenu_Label(int branch, char[] text, int maxlength)
{
    static const char labels[][] = {
        "", "战术\n   换弹时剩余弹药越多\n   下一弹夹伤害越高\n",
        "谢幕\n   弹夹最后一发增伤50%\n",
        "居合\n   2秒不出刀，强化下次剑气\n   宽度翻倍，增伤150%\n",
        "剑豪\n   每第3次攻击强化剑气\n   宽度翻倍，增伤50%\n",
        "烈焰\n   燃烧时间延长2秒\n",
        "雷电\n   电链可往返弹跳\n   每次弹跳增伤30%\n",
        "鹰眼\n   站立越久，伤害越高\n   5秒达到100%增伤\n",
        "游侠\n   移动越久，伤害越高\n   5秒达到100%增伤\n",
        "夺命\n   对满血目标增伤100%\n",
        "舞者\n   血量越低，伤害越高\n   最高增伤100%\n",
        "和平\n   取消弹跳，将后续伤害\n   集中为一次强力爆炸\n",
        "混乱\n   弹跳次数增加1次\n   每次弹跳增伤20%\n",
        "守护\n   代受200码内队友的伤害\n",
        "圣光\n   攻击队友可治疗\n   并提供50%增伤，持续3秒\n"
    };
    strcopy(text, maxlength, labels[branch > RN_BRANCH_NONE && branch < sizeof(labels) ? branch : 0]);
}

/** 职业功能关闭时取消当前分支框，不清除已保存分支或普通候选。 */
void RN_BranchMenu_ConfigApplied()
{
    if (RN_Config_Int(RN_CVAR_PROFESSION_ENABLE) != 0) return;
    for (int client = 1; client <= MaxClients; client++)
        if (g_BranchMenu_Open[client] != null && g_Menu_Open[client] == g_BranchMenu_Open[client]) RN_Menu_Close(client);
}

/** 分支令牌包含会话、基础职业版本和分支版本，免费入口不依赖普通卡余额。 */
int RN_BranchMenu_Reason(Menu menu, int client, int item, PlayerProfile profile, int &branch)
{
    int reason = RN_Menu_EligibilityReason(client, false);
    if (reason != RN_MENU_ALLOWED) return reason;
    if (RN_Config_Int(RN_CVAR_PROFESSION_ENABLE) == 0) return RN_MENU_PROFESSION_DISABLED;
    if (menu == null || g_Menu_Open[client] != menu || g_BranchMenu_Open[client] != menu) return RN_MENU_OLD_MENU;
    if (!RN_Profile_Get(g_Profile_Index[client], profile)) return RN_MENU_PROFILE;
    if (profile.branch != RN_BRANCH_NONE) return RN_MENU_BRANCH_CHOSEN;
    if (profile.profession == RN_PROFESSION_NONE) return RN_MENU_PROFESSION_REQUIRED;
    if (!RN_Branch_Ready(profile)) return RN_MENU_BRANCH_LOCKED;
    char info[160], parts[8][16];
    if (!menu.GetItem(item, info, sizeof(info)) ||
        ExplodeString(info, ":", parts, sizeof(parts), sizeof(parts[])) != 8 || !StrEqual(parts[0], "b")) return RN_MENU_ITEM;
    int values[7];
    for (int i = 0; i < sizeof(values); i++)
        if (!RN_Common_ParseUnsigned(parts[i + 1], values[i])) return RN_MENU_ITEM;
    if (values[0] != g_Run_Epoch) return RN_MENU_OLD_RUN;
    if (values[1] != g_Run_MapEpoch) return RN_MENU_OLD_MAP;
    if (values[2] != GetClientSerial(client) || values[3] != g_Profile_Index[client]) return RN_MENU_OLD_SESSION;
    if (values[4] != profile.professionVersion) return RN_MENU_OLD_PROFESSION;
    if (values[5] != profile.branchVersion) return RN_MENU_OLD_BRANCH;
    branch = values[6];
    return branch > RN_BRANCH_NONE && branch < RN_BRANCH_COUNT &&
        RN_Branch_Profession(branch) == profile.profession ? RN_MENU_ALLOWED : RN_MENU_ITEM;
}

/** 合法点击只提交分支及版本，不消费普通选择、ROLL或候选，也不重发初选赠枪。 */
public int RN_BranchMenu_OnChoice(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        for (int client = 1; client <= MaxClients; client++)
        {
            if (g_BranchMenu_Open[client] == menu) g_BranchMenu_Open[client] = null;
            if (g_Menu_Open[client] == menu) g_Menu_Open[client] = null;
        }
        delete menu;
    }
    else if (action == MenuAction_Select)
    {
        PlayerProfile profile;
        int branch;
        int reason = RN_BranchMenu_Reason(menu, param1, param2, profile, branch);
        if (reason != RN_MENU_ALLOWED) { RN_Menu_Rejected(param1, reason); return 0; }
        if (!RN_Math_Add(profile.branchVersion, 1, profile.branchVersion))
        {
            RN_Menu_Rejected(param1, RN_MENU_VERSION);
            return 0;
        }
        profile.branch = branch;
        if (!RN_Profile_Validate(profile) || !RN_Profile_ValidateClient(param1, profile))
        {
            RN_Menu_Rejected(param1, RN_MENU_BUDGET);
            return 0;
        }
        RN_Profile_Save(g_Profile_Index[param1], profile);
        RN_Branch_ResetClient(param1);
        char name[32];
        RN_Branch_Name(branch, name, sizeof(name));
        PrintToChat(param1, "\x04[Rogue]\x01已转职为%s，本战役内不可更改。", name);
        RN_Menu_Next(param1);
    }
    return 0;
}

/** 仅由主动加点入口展示当前职业二选一，沿用原生0退出且保留资格。 */
void RN_BranchMenu_Show(int client, PlayerProfile profile)
{
    Menu menu = new Menu(RN_BranchMenu_OnChoice);
    char profession[48];
    RN_Profession_Name(profile.profession, profession, sizeof(profession));
    menu.SetTitle("【%s · 转职】\n", profession);
    menu.Pagination = 7;
    int first = (profile.profession - 1) * 2 + 1;
    for (int branch = first; branch < first + 2; branch++)
    {
        char info[160], label[180];
        FormatEx(info, sizeof(info), "b:%d:%d:%d:%d:%d:%d:%d", g_Run_Epoch, g_Run_MapEpoch,
            GetClientSerial(client), g_Profile_Index[client], profile.professionVersion, profile.branchVersion, branch);
        RN_BranchMenu_Label(branch, label, sizeof(label));
        menu.AddItem(info, label);
    }
    g_BranchMenu_Open[client] = menu;
    g_Menu_Open[client] = menu;
    if (!menu.Display(client, 30))
    {
        g_BranchMenu_Open[client] = null;
        g_Menu_Open[client] = null;
        delete menu;
        RN_Menu_Rejected(client, RN_MENU_DISPLAY);
    }
}
