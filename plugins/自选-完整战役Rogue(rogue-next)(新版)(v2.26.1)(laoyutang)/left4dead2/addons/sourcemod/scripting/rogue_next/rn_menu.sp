#if defined _rn_menu_included
 #endinput
#endif
#define _rn_menu_included

Menu g_Menu_Open[MAXPLAYERS + 1];

enum
{
    RN_MENU_ALLOWED, RN_MENU_CLIENT, RN_MENU_DISABLED, RN_MENU_RESTART,
    RN_MENU_TRANSITION, RN_MENU_NO_RUN, RN_MENU_UNREADY, RN_MENU_TEAM,
    RN_MENU_BOT, RN_MENU_DEAD, RN_MENU_LEDGE, RN_MENU_INCAP, RN_MENU_CONTROL,
    RN_MENU_PROFILE, RN_MENU_BUDGET, RN_MENU_NO_CHOICES, RN_MENU_OLD_MENU,
    RN_MENU_ITEM, RN_MENU_OLD_RUN, RN_MENU_OLD_MAP, RN_MENU_OLD_SESSION,
    RN_MENU_OLD_OPTIONS, RN_MENU_NO_ROLLS, RN_MENU_POOL, RN_MENU_VERSION,
    RN_MENU_DISPLAY, RN_MENU_PROFESSION_REQUIRED, RN_MENU_PROFESSION_DISABLED,
    RN_MENU_PROFESSION_CHOSEN, RN_MENU_OLD_PROFESSION, RN_MENU_PROFESSION_BUFF,
    RN_MENU_BRANCH_CHOSEN, RN_MENU_BRANCH_LOCKED, RN_MENU_OLD_BRANCH
}

static const char g_Menu_Reasons[][] = {
    "", "客户端尚未进入游戏。", "Rogue 当前已关闭，暂时无法选卡。",
    "战役正在重启，请等待新回合开始。", "正在切换章节，请等待地图准备完成。",
    "当前没有进行中的战役，暂时无法选卡。", "Rogue 尚未准备就绪，请稍后重试。",
    "当前不在生还者队伍，无法选卡。", "BOT 无法使用选卡菜单。",
    "你已死亡，复活后才能选卡。", "你正在挂边，获救后才能选卡。",
    "你已倒地，起身后才能选卡。", "你正被特感控制，解除控制后才能选卡。",
    "你的玩家档案尚未准备好，请稍后重试。", "选择次数计算异常，请联系管理员。",
    "你当前没有可用的选择次数。", "这个选卡菜单已失效，请重新打开。",
    "这个菜单选项无效，请重新打开选卡菜单。",
    "战役已经变化，请重新打开选卡菜单。", "地图已经变化，请重新打开选卡菜单。",
    "玩家会话或档案已经变化，请重新打开选卡菜单。",
    "候选卡已经变化，请重新打开选卡菜单。", "ROLL 已用完，无法重新抽取。",
    "无法生成候选卡，请联系管理员；本次未消耗资源。",
    "选卡菜单版本无法更新，请联系管理员；本次未消耗资源。",
    "选卡菜单显示失败，请重新尝试打开。",
    "请先选择职业，再选择BUFF。", "职业功能已关闭，请重新打开选卡菜单。",
    "你已选择职业，本战役无法重新选择。", "职业菜单已经变化，请重新打开。", "当前职业无法获得这张BUFF，请重新打开选卡菜单。",
    "你已完成转职，本战役内无法重新选择。", "团队达到13级后才能转职。", "转职菜单已经变化，请重新打开。"
};

/** 返回当前首个拒绝原因；与原资格口径一致，in_combat只放宽倒地/挂边/被控。 */
int RN_Menu_EligibilityReason(int client, bool requirePending = true)
{
    if (!RN_Common_Client(client)) return RN_MENU_CLIENT;
    if (!RN_Config_Enabled())
    {
        if (RN_Config_Int(RN_CVAR_ENABLE) == 0) return RN_MENU_DISABLED;
        if (g_Run_Phase == RN_RESTARTING) return RN_MENU_RESTART;
        if (g_Run_Phase == RN_TRANSITION) return RN_MENU_TRANSITION;
        if (g_Run_Phase == RN_FINISHED) return RN_MENU_NO_RUN;
        return RN_MENU_UNREADY;
    }
    if (!RN_Common_Survivor(client)) return RN_MENU_TEAM;
    if (IsFakeClient(client)) return RN_MENU_BOT;
    if (!IsPlayerAlive(client)) return RN_MENU_DEAD;
    if (RN_Config_Int(RN_CVAR_MENU_IN_COMBAT) == 0)
    {
        if (GetEntProp(client, Prop_Send, "m_isHangingFromLedge") != 0) return RN_MENU_LEDGE;
        if (GetEntProp(client, Prop_Send, "m_isIncapacitated") != 0) return RN_MENU_INCAP;
        if (RN_Common_Controlled(client)) return RN_MENU_CONTROL;
    }
    PlayerProfile profile;
    int total, pending;
    if (!RN_Profile_Get(g_Profile_Index[client], profile)) return RN_MENU_PROFILE;
    if (!RN_Profile_Budget(profile, total, pending)) return RN_MENU_BUDGET;
    return requirePending && pending <= 0 ? RN_MENU_NO_CHOICES : RN_MENU_ALLOWED;
}

/** 后台续显与资源操作复用相同判定，本方法不主动发送聊天。 */
bool RN_Menu_Eligible(int client, bool requirePending = true)
{
    return RN_Menu_EligibilityReason(client, requirePending) == RN_MENU_ALLOWED;
}

/** 只向有效真人报告实际原因；异常生成/计数额外记录日志，普通状态拒绝不刷日志。 */
void RN_Menu_Rejected(int client, int reason)
{
    if (!RN_Common_Client(client) || IsFakeClient(client) || reason <= RN_MENU_ALLOWED ||
        reason >= sizeof(g_Menu_Reasons)) return;
    PrintToChat(client, "\x04[Rogue]\x01 %s", g_Menu_Reasons[reason]);
    if (reason == RN_MENU_BUDGET || reason == RN_MENU_POOL || reason == RN_MENU_VERSION || reason == RN_MENU_DISPLAY)
        LogError("[rogue-next] client=%d选卡菜单被拒绝，reason=%d：%s", client, reason, g_Menu_Reasons[reason]);
}

/** 只取消当前显示对象；档案三项候选保留，关闭不能免费换卡。 */
void RN_Menu_Close(int client)
{
    Menu menu = g_Menu_Open[client];
    g_Menu_Open[client] = null;
    if (menu != null) menu.Cancel();
}

/** 地图结束/关停关闭所有会话菜单。 */
void RN_Menu_Clear()
{
    for (int client = 1; client <= MaxClients; client++)
        RN_Menu_Close(client);
}

/** 信息串携带完整上下文，菜单回调不依赖客户端槽位独自证明身份。 */
void RN_Menu_ItemInfo(int client, PlayerProfile profile, int slot, int buff, char[] info, int maxlength)
{
    FormatEx(info, maxlength, "%d:%d:%d:%d:%d:%d:%d", g_Run_Epoch, g_Run_MapEpoch,
        GetClientSerial(client), g_Profile_Index[client], profile.optionVersion, slot, buff);
}

/** 解析完整上下文并返回准确拒绝原因；验证不消费资源或刷新候选。 */
int RN_Menu_ValidationReason(Menu menu, int client, int item, PlayerProfile profile, int &slot, int &buff)
{
    int reason = RN_Menu_EligibilityReason(client);
    if (reason != RN_MENU_ALLOWED) return reason;
    if (menu == null || g_Menu_Open[client] != menu) return RN_MENU_OLD_MENU;
    if (!RN_Profile_Get(g_Profile_Index[client], profile)) return RN_MENU_PROFILE;
    if (RN_Config_Int(RN_CVAR_PROFESSION_ENABLE) != 0 && profile.profession == RN_PROFESSION_NONE)
        return RN_MENU_PROFESSION_REQUIRED;
    char info[128], parts[7][16];
    if (!menu.GetItem(item, info, sizeof(info)) || ExplodeString(info, ":", parts, sizeof(parts), sizeof(parts[])) != 7)
        return RN_MENU_ITEM;
    int value[7];
    for (int i = 0; i < sizeof(value); i++)
        if (!RN_Common_ParseUnsigned(parts[i], value[i])) return RN_MENU_ITEM;
    if (value[0] != g_Run_Epoch) return RN_MENU_OLD_RUN;
    if (value[1] != g_Run_MapEpoch) return RN_MENU_OLD_MAP;
    if (value[2] != GetClientSerial(client) || value[3] != g_Profile_Index[client]) return RN_MENU_OLD_SESSION;
    if (value[4] != profile.optionVersion) return RN_MENU_OLD_OPTIONS;
    slot = value[5];
    buff = value[6];
    if (slot == RN_OPTIONS)
    {
        if (buff != PLAYBUFF_NULL) return RN_MENU_ITEM;
        return profile.rollLeft > 0 ? RN_MENU_ALLOWED : RN_MENU_NO_ROLLS;
    }
    if (slot < 0 || slot >= RN_OPTIONS || buff <= PLAYBUFF_NULL || buff >= MAXBUFFENUM) return RN_MENU_ITEM;
    if (!RN_Buff_Allowed(buff, profile.profession)) return RN_MENU_PROFESSION_BUFF;
    return profile.optionBuff[slot] == buff ? RN_MENU_ALLOWED : RN_MENU_OLD_OPTIONS;
}

/** 默认静默校验；主动点击可请求拒绝原因提示，两条路径共用相同判定。 */
bool RN_Menu_Validate(Menu menu, int client, int item, PlayerProfile profile, int &slot, int &buff, bool notify = false)
{
    int reason = RN_Menu_ValidationReason(menu, client, item, profile, slot, buff);
    if (notify && reason != RN_MENU_ALLOWED) RN_Menu_Rejected(client, reason);
    return reason == RN_MENU_ALLOWED;
}

/** ROLL先准备三项与版本，再扣资源一次；任何失败保留旧候选和余额。 */
bool RN_Menu_Roll(int client, PlayerProfile profile)
{
    int options[RN_OPTIONS], version;
    if (profile.rollLeft <= 0) { RN_Menu_Rejected(client, RN_MENU_NO_ROLLS); return false; }
    if (!RN_Pool_Options(options, profile.profession)) { RN_Menu_Rejected(client, RN_MENU_POOL); return false; }
    if (!RN_Math_Add(profile.optionVersion, 1, version)) { RN_Menu_Rejected(client, RN_MENU_VERSION); return false; }
    for (int i = 0; i < RN_OPTIONS; i++) profile.optionBuff[i] = options[i];
    profile.optionVersion = version;
    profile.optionStamp = GetTickedTime();
    profile.rollLeft--;
    RN_Profile_Save(g_Profile_Index[client], profile);
    RN_Notify_Roll(client, profile.rollLeft);
    return true;
}

/** 一帧后显示下一张菜单；校验战役、地图和客户端serial，不跨图复活旧菜单。 */
public void RN_Menu_NextFrame(DataPack pack)
{
    pack.Reset();
    int epoch = pack.ReadCell(), mapEpoch = pack.ReadCell(), serial = pack.ReadCell();
    delete pack;
    int client = GetClientFromSerial(serial);
    if (epoch == g_Run_Epoch && mapEpoch == g_Run_MapEpoch && RN_Menu_Eligible(client)) RN_Menu_Show(client, false);
}

/** 成功选卡/ROLL才安排下一菜单，关闭或超时不会刷新候选。 */
void RN_Menu_Next(int client)
{
    DataPack pack = new DataPack();
    pack.WriteCell(g_Run_Epoch);
    pack.WriteCell(g_Run_MapEpoch);
    pack.WriteCell(GetClientSerial(client));
    RequestFrame(RN_Menu_NextFrame, pack);
}

/** End只释放自己的显示对象；不能清候选或后来新建的菜单。 */
public int RN_Menu_OnChoice(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        for (int client = 1; client <= MaxClients; client++)
            if (g_Menu_Open[client] == menu) g_Menu_Open[client] = null;
        delete menu;
    }
    else if (action == MenuAction_Select)
    {
        PlayerProfile profile;
        int slot, buff;
        if (!RN_Menu_Validate(menu, param1, param2, profile, slot, buff, true)) return 0;
        bool success = slot == RN_OPTIONS ? RN_Menu_Roll(param1, profile) : RN_Apply_Choose(param1, buff);
        if (success) RN_Menu_Next(param1);
    }
    return 0;
}

/** 缓存不存在或不符合职业时才生成；初次开菜单与再次打开不会分别抽卡。 */
void RN_Menu_Show(int client, bool allowBranch = true)
{
    int reason = RN_Menu_EligibilityReason(client, false);
    if (reason != RN_MENU_ALLOWED)
    {
        RN_Menu_Rejected(client, reason);
        return;
    }
    PlayerProfile profile;
    RN_Profile_Get(g_Profile_Index[client], profile);
    if (allowBranch && RN_BranchMenu_Route(client, profile)) return;
    reason = RN_Menu_EligibilityReason(client);
    if (reason != RN_MENU_ALLOWED) { RN_Menu_Rejected(client, reason); return; }
    RN_Menu_Close(client);
    if (RN_Config_Int(RN_CVAR_PROFESSION_ENABLE) != 0 && profile.profession == RN_PROFESSION_NONE)
    {
        RN_ProfessionMenu_Show(client, profile);
        return;
    }
    bool validOptions = true;
    for (int i = 0; i < RN_OPTIONS; i++)
        if (!RN_Buff_Allowed(profile.optionBuff[i], profile.profession)) validOptions = false;
    if (!validOptions)
    {
        if (!RN_Pool_Options(profile.optionBuff, profile.profession)) { RN_Menu_Rejected(client, RN_MENU_POOL); return; }
        if (!RN_Math_Add(profile.optionVersion, 1, profile.optionVersion)) { RN_Menu_Rejected(client, RN_MENU_VERSION); return; }
        profile.optionStamp = GetTickedTime();
        RN_Profile_Save(g_Profile_Index[client], profile);
    }
    int total, pending;
    RN_Profile_Budget(profile, total, pending);
    Menu menu = new Menu(RN_Menu_OnChoice);
    menu.SetTitle("Rogue Lv.%d %.1f%% | 难度%d\n待选%d ROLL%d | 有效%.1f分",
        g_Run_Level, g_Run_Progress, g_Clock_Tier, pending, profile.rollLeft, RN_Clock_Elapsed()/60.0);
    for (int i = 0; i < RN_OPTIONS; i++)
    {
        char info[128], name[64], rarity[32], description[180], shortText[58], label[160];
        int buff = profile.optionBuff[i];
        RN_Menu_ItemInfo(client, profile, i, buff, info, sizeof(info));
        RN_Buff_Name(buff, name, sizeof(name));
        RN_Buff_RarityText(RN_Buff_Rarity(buff), rarity, sizeof(rarity));
        RN_Buff_DescriptionForProfile(profile, buff, description, sizeof(description));
        RN_Common_ShortText(description, shortText, sizeof(shortText));
        FormatEx(label, sizeof(label), "%s [%s]%s\n%s", name, rarity,
            RN_Buff_Profession(buff) != RN_PROFESSION_NONE ? " [专属]" : "", shortText);
        menu.AddItem(info, label);
    }
    char info[128], label[64];
    RN_Menu_ItemInfo(client, profile, RN_OPTIONS, PLAYBUFF_NULL, info, sizeof(info));
    FormatEx(label, sizeof(label), "ROLL 剩余%d", profile.rollLeft);
    menu.AddItem(info, label, profile.rollLeft > 0 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
    g_Menu_Open[client] = menu;
    if (!menu.Display(client, 30))
    {
        g_Menu_Open[client] = null;
        delete menu;
        RN_Menu_Rejected(client, RN_MENU_DISPLAY);
    }
}

/** 查看菜单没有资源操作，其End仅释放查看对象。 */
public int RN_Menu_OnView(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        for (int client = 1; client <= MaxClients; client++)
            if (g_Menu_Open[client] == menu) g_Menu_Open[client] = null;
        delete menu;
    }
    return 0;
}

/** 完整渲染一条属性信息，不截断中文或数值。 */
void RN_Menu_Detail(Menu menu, const char[] format, any ...)
{
    char text[192];
    VFormat(text, sizeof(text), format, 3);
    menu.AddItem("", text, ITEMDRAW_DISABLED);
}

/** 属性行共用显示舍入，实际统计值保持原精度。 */
void RN_Menu_Number(Menu menu, const char[] format, float value, int decimals = 1)
{
    char number[64];
    RN_Math_NumberText(value, number, sizeof(number), decimals);
    RN_Menu_Detail(menu, format, number);
}

/** 有符号百分比保留负面影响；枪伤被代价抵消时可保留实际零值以区分通用加成。 */
void RN_Menu_Percentage(Menu menu, const char[] name, float value, bool showZero = false)
{
    if (FloatAbs(value) < 0.05)
    {
        if (!showZero) return;
        value = 0.0;
    }
    char number[64];
    RN_Math_NumberText(value, number, sizeof(number));
    RN_Menu_Detail(menu, "%s：%s%s%%", name, value < 0.0 ? "" : "+", number);
}

/** 先按实际抽样口径钳制概率，再过滤无变化值；持续时间采用短句显示。 */
void RN_Menu_Chance(Menu menu, const char[] name, float value, bool integerRoll = false, float duration = -1.0)
{
    float chance = RN_Stats_Percent(value, integerRoll);
    if (chance < 0.05) return;
    char percent[64], seconds[64];
    RN_Math_NumberText(chance, percent, sizeof(percent), integerRoll || duration >= 0.0 ? 0 : 1);
    if (duration >= 0.0)
    {
        RN_Math_NumberText(duration, seconds, sizeof(seconds));
        RN_Menu_Detail(menu, "%s：%s%%，%s秒", name, percent, seconds);
    }
    else RN_Menu_Detail(menu, "%s：%s%%", name, percent);
}

/** 只读生成合计属性行，供个人菜单和管理员查询共用，不显示或替换客户端菜单。 */
Menu RN_Menu_BuildView(PlayerProfile profile, int &attributes)
{
    int health, reload, cycle;
    float reloadFactor, cycleFactor;
    if (!RN_Profile_HealthBonus(profile, health) ||
        !RN_Weapons_Totals(-1, profile, reload, cycle) ||
        !RN_Weapons_Factors(reload, cycle, reloadFactor, cycleFactor)) return null;
    Menu menu = new Menu(RN_Menu_OnView);
    menu.Pagination = 7;
    RN_ProfessionMenu_Details(menu, profile);
    RN_BranchMenu_Details(menu, profile);
    if (health > 0) RN_Menu_Detail(menu, "血量上限：+%d", health);
    float healing = RN_Stats_Get(profile, RN_STAT_HEAL);
    if (healing >= 0.005) RN_Menu_Number(menu, "每秒回血：+%s实血", healing, 2);
    RN_Knight_CardDetails(menu, profile);
    float damage = RN_Stats_Get(profile, RN_STAT_DAMAGE), gunDamage = RN_Stats_Get(profile, RN_STAT_GUN_DAMAGE);
    RN_Menu_Percentage(menu, "伤害加成", (damage - 1.0)*100.0);
    if (FloatAbs(gunDamage - damage) >= 0.0005)
        RN_Menu_Percentage(menu, "枪械伤害加成", (gunDamage - 1.0)*100.0, true);
    RN_Menu_Percentage(menu, "爆炸伤害加成", (RN_Stats_Get(profile, RN_STAT_EXPLOSION_DAMAGE) - 1.0)*100.0);
    RN_Menu_Percentage(menu, "爆炸范围加成", (RN_Stats_Get(profile, RN_STAT_EXPLOSION_RADIUS) - 1.0)*100.0);
    RN_Menu_Percentage(menu, "近战伤害加成", (RN_Stats_Get(profile, RN_STAT_MELEE) - 1.0)*100.0);
    RN_Menu_Chance(menu, "暴击概率", RN_Stats_Get(profile, RN_STAT_CRIT_CHANCE)*100.0);
    float critical = RN_Stats_Get(profile, RN_STAT_CRIT_MULTIPLIER);
    if (FloatAbs(critical - RN_Config_Float(RN_CVAR_CRIT_BASE_MULTIPLIER)) >= 0.005)
        RN_Menu_Number(menu, "暴击伤害：%s倍", critical, 2);
    RN_Menu_Percentage(menu, "伤害减免", (1.0 - RN_Stats_Incoming(profile))*100.0);
    RN_Menu_Percentage(menu, "对Tank伤害减免", (1.0 - RN_Stats_Incoming(profile, true))*100.0);
    RN_Menu_Percentage(menu, "移动速度", (RN_Disaster_MoveFactor(RN_Stats_Get(profile, RN_STAT_MOVE)) - 1.0)*100.0);
    if (RN_Disaster_Active())
    {
        char disaster[32], detail[80];
        RN_Disaster_Text(disaster, sizeof(disaster), detail, sizeof(detail));
        RN_Menu_Detail(menu, "灾害：%s，%s", disaster, detail);
    }
    RN_Menu_Chance(menu, "免控概率", RN_Stats_Get(profile, RN_STAT_CONTROL), true);
    RN_Menu_Chance(menu, "点燃概率", RN_Stats_Get(profile, RN_STAT_IGNITE), true,
        RN_Branch_FireDuration(profile));
    RN_Menu_Chance(menu, "冰冻概率", RN_Stats_Get(profile, RN_STAT_FREEZE), true,
        RN_Config_Float(RN_CVAR_FREEZEDURATION_SURV));
    if (!RN_Profession_NoElements(profile) && (profile.buff[PLAYBUFF_ELECTRIC_ADDICT] > 0
        || profile.buff[PLAYBUFF_SUPERCONDUCTOR] > 0 || profile.buff[PLAYBUFF_FIVE_WHIP] > 0
        || profile.buff[PLAYBUFF_THUNDER_KING] > 0))
    {
        if (RN_Config_Int(RN_CVAR_ELECTRIC_ENABLE) == 0) RN_Menu_Detail(menu, "电元素：已关闭");
        else
        {
            RN_Menu_Number(menu, "电击概率：%s%%", RN_Stats_Percent(RN_Stats_Get(profile, RN_STAT_ELECTRIC_CHANCE), true), 0);
            RN_Menu_Number(menu, "基础电伤：%s", RN_Stats_Get(profile, RN_STAT_ELECTRIC_BASE));
            RN_Menu_Percentage(menu, "电伤加成", RN_Stats_Get(profile, RN_STAT_ELECTRIC_BONUS)*100.0);
            RN_Menu_Number(menu, "首目标电伤：%s", RN_Stats_Get(profile, RN_STAT_ELECTRIC_DAMAGE)*RN_Disaster_DamageFactor(true));
            RN_Menu_Detail(menu, "有效额外弹射：%d（伤害非正结束）", RN_Stats_ElectricJumps(profile));
            RN_Menu_Number(menu, "电弧每跳距离：%s码", RN_Config_Float(RN_CVAR_ELECTRIC_RADIUS), 0);
            RN_Menu_Number(menu, RN_Branch_Active(profile, RN_BRANCH_THUNDER) ? "每跳加初始电伤：%s%%" : "每跳扣初始电伤：%s%%",
                RN_Branch_Active(profile, RN_BRANCH_THUNDER) ? 30.0 : RN_Config_Float(RN_CVAR_ELECTRIC_DECAY)*100.0, 0);
            RN_Menu_Number(menu, "电链触发冷却：%s秒", RN_Config_Float(RN_CVAR_ELECTRIC_COOLDOWN), 2);
            if (RN_Config_Int(RN_CVAR_ELECTRIC_FIRE_ENABLE) != 0)
                RN_Menu_Detail(menu, "电火：继承100%%火伤与完整时长");
        }
    }
    RN_Menu_Percentage(menu, "灼烧伤害加成", RN_Stats_Get(profile, RN_STAT_BURN_BONUS)*100.0);
    if (RN_Stats_Percent(RN_Stats_Get(profile, RN_STAT_IGNITE), true) > 0.0
        && RN_Config_Float(RN_CVAR_IGNITEDURATION_SURV) > 0.0)
    {
        float base = RN_Stats_Get(profile, RN_STAT_BURN_BASE);
        float dps = RN_Stats_Get(profile, RN_STAT_BURN_DPS);
        if (base > 0.0) RN_Menu_Number(menu, "基础灼烧：%s/秒", base);
        if (dps > 0.0) RN_Menu_Number(menu, "实际灼烧：%s/秒", dps);
        if (RN_Stats_Percent(RN_Stats_Get(profile, RN_STAT_FREEZE), true) > 0.0
            && RN_Config_Float(RN_CVAR_FREEZEDURATION_SURV) > 0.0
            && RN_Config_Int(RN_CVAR_ELEMENT_EXPLOSION_ENABLE) != 0
            && RN_Profession_ExplosionRadius(profile) > 0.0)
        {
            RN_Menu_Number(menu, "冰火爆炸：半径%s", RN_Profession_ExplosionRadius(profile), 0);
            RN_Menu_Number(menu, "冰火：中心100%% 周边%s%%",
                RN_Config_Float(RN_CVAR_ELEMENT_EXPLOSION_SPLASH_FACTOR)*100.0);
        }
    }
    RN_Menu_Chance(menu, "闪避概率", RN_Stats_Get(profile, RN_STAT_DODGE));
    float luck = RN_Stats_Get(profile, RN_STAT_LUCK);
    if (FloatAbs(luck - 1.0) >= 0.005)
        RN_Menu_Number(menu, "强运：概率乘%s倍", luck, 2);
    if (profile.buff[PLAYBUFF_SHENGSHENGBUXI] > 0)
        RN_Menu_Detail(menu, "生生不息：免疫所有伤害");
    if (profile.buff[PLAYBUFF_XINLATIANSAI] > 0)
        RN_Menu_Number(menu, "辛辣天塞：独立输出乘%s倍", 1.0 + float(profile.buff[PLAYBUFF_XINLATIANSAI]), 0);
    if (profile.buff[PLAYBUFF_NEVERFALL] > 0)
    {
        int capacity;
        RN_Math_Multiply(profile.buff[PLAYBUFF_NEVERFALL], RN_Config_Int(RN_CVAR_NEVERFALLNUM_SURV), capacity);
        if (capacity > 0)
        {
            char protection[80];
            if (RN_Config_Float(RN_CVAR_NEVERFALL_PROTECTION_TIME) > 0.0)
            {
                char seconds[64];
                RN_Math_NumberText(RN_Config_Float(RN_CVAR_NEVERFALL_PROTECTION_TIME), seconds, sizeof(seconds));
                FormatEx(protection, sizeof(protection), "，免伤%s秒", seconds);
            }
            RN_Menu_Detail(menu, "读档拦截：剩%d次，回血%d%s", capacity > profile.neverFallUsed ? capacity - profile.neverFallUsed : 0,
                RN_Stats_NeverFallHealth(), protection);
        }
    }
    if (profile.buff[PLAYBUFF_DAMOCLESSWORD] > 0)
    {
        RN_Menu_Detail(menu, "达摩之剑：升级选+%d", profile.buff[PLAYBUFF_DAMOCLESSWORD]);
        float risk = RN_Stats_Value(profile, PLAYBUFF_DAMOCLESSWORD, RN_CVAR_DAMOCLESSWORD_DEATHPROB_SURV);
        if (RN_Stats_Percent(risk/100.0) >= 0.005)
            RN_Menu_Number(menu, "达摩风险：每秒%s%%受伤999", RN_Stats_Percent(risk/100.0), 2);
    }
    if (profile.buff[PLAYBUFF_ZHAOZAI] > 0)
    {
        float risk = RN_Stats_Percent(RN_Stats_Value(profile, PLAYBUFF_ZHAOZAI, RN_CVAR_ZHAOZAI_SPAWNTANKPROB_SURV)/100.0);
        if (risk >= 0.005) RN_Menu_Number(menu, "招灾：每秒%s%%召唤Tank", risk, 2);
    }
    if (profile.buff[PLAYBUFF_SHUANGSHENGHUA] > 0)
        RN_Menu_Detail(menu, "双生花：手选多生效%d次", profile.buff[PLAYBUFF_SHUANGSHENGHUA]);
    if (profile.buff[PLAYBUFF_JIFA] > 0 || profile.buff[PLAYBUFF_YELI] > 0)
    {
        int faith;
        RN_Math_Multiply(profile.buff[PLAYBUFF_YELI], 3, faith);
        RN_Math_Add(faith, profile.buff[PLAYBUFF_JIFA], faith);
        RN_Menu_Detail(menu, "信念：%d（激发/业力）", faith);
    }
    if (profile.buff[PLAYBUFF_BOZANG] > 0)
        RN_Menu_Detail(menu, "薄葬：被击杀获%d随机普通BUFF", profile.buff[PLAYBUFF_BOZANG]);
    if (profile.buff[PLAYBUFF_FENGGUANGDAZANG] > 0)
    {
        RN_Menu_Detail(menu, "风光大葬：被击杀抽奖%d次", profile.buff[PLAYBUFF_FENGGUANGDAZANG]);
        RN_Menu_Detail(menu, "大葬：50%%稀有/50%%倒爷");
    }
    if (reloadFactor <= 0.0) RN_Menu_Detail(menu, "全队换弹时间：0.001秒下限");
    else RN_Menu_Percentage(menu, "全队换弹时间", (reloadFactor - 1.0)*100.0);
    if (cycleFactor <= 0.0) RN_Menu_Detail(menu, "全队射击间隔：0.001秒下限");
    else RN_Menu_Percentage(menu, "全队射击间隔", (cycleFactor - 1.0)*100.0);
    attributes = menu.ItemCount;
    if (attributes == 0) RN_Menu_Detail(menu, "暂无属性加成");
    return menu;
}

/** 展示合并后的个人加成与全队武器贡献，使用战斗/实体属性的实际公式。 */
void RN_Menu_View(int client)
{
    if (!RN_Common_Client(client) || IsFakeClient(client)) return;
    if (!RN_Common_Survivor(client))
    {
        PrintToChat(client, "\x04[Rogue]\x01 只有生还者可以查看BUFF信息。");
        return;
    }
    if (!RN_Config_Enabled())
    {
        PrintToChat(client, "\x04[Rogue]\x01 Rogue已关闭，暂时无法查看加成。");
        return;
    }
    PlayerProfile profile;
    if (!RN_Profile_Get(g_Profile_Index[client], profile)) return;
    RN_Menu_Close(client);
    int total, pending, attributes;
    RN_Profile_Budget(profile, total, pending);
    Menu menu = RN_Menu_BuildView(profile, attributes);
    if (menu == null) return;
    char profession[64];
    RN_Profession_Name(profile.profession, profession, sizeof(profession));
    if (profile.profession != RN_PROFESSION_NONE && RN_Config_Int(RN_CVAR_PROFESSION_ENABLE) == 0)
        StrCat(profession, sizeof(profession), "（已停用）");
    menu.SetTitle("Rogue 加成%d项 | Lv.%d %.1f%%\n待选%d ROLL%d | 难度%d %.1f分\n职业：%s",
        attributes, g_Run_Level, g_Run_Progress, pending, profile.rollLeft, g_Clock_Tier, RN_Clock_Elapsed()/60.0, profession);
    g_Menu_Open[client] = menu;
    if (!menu.Display(client, 30)) { g_Menu_Open[client] = null; delete menu; }
}

/** 聊天或绑定按键单次调用立即打开当前缓存候选。 */
public Action RN_Menu_CommandChoice(int client, int args)
{
    if (client > 0) RN_Menu_Show(client);
    return Plugin_Handled;
}

/** 聊天或绑定按键单次调用立即显示个人属性和团队武器加成。 */
public Action RN_Menu_CommandView(int client, int args)
{
    if (client > 0) RN_Menu_View(client);
    return Plugin_Handled;
}

/** 只输出手动绑定命令；不向客户端发送修改键位的命令。 */
void RN_Menu_BindHelp(int client)
{
    if (!RN_Common_Client(client) || IsFakeClient(client)) return;
    PrintToChat(client, "\x04[Rogue]\x01K/L需手动绑定：控制台有一行绑定命令，单击K选卡、L查看。");
    PrintToConsole(client, "[Rogue] 在自己的游戏控制台粘贴这一行（K选卡，L查看，按一次即可）：");
    PrintToConsole(client, "bind k \"sm_ba\"; bind l \"sm_buff\"");
}

/** 随时重新查看手动绑定帮助；帮助指令本身不会执行bind。 */
public Action RN_Menu_CommandBind(int client, int args)
{
    RN_Menu_BindHelp(client);
    return Plugin_Handled;
}

/** 进服只给出聊天入口与手动绑定帮助，遵循进服提示开关。 */
void RN_Menu_JoinTip(int client)
{
    if (!RN_Common_Client(client) || IsFakeClient(client)) return;
    if (RN_Config_Int(RN_CVAR_JOIN_TIP) != 0)
    {
        PrintToChat(client, "\x04[Rogue]\x01!ba选卡，!buff查看加成，!rn_bind查看手动绑定帮助。");
        RN_Menu_BindHelp(client);
    }
}

/** 统一登记单次响应指令；旧K/L命令兼容已有手动绑定。 */
void RN_Menu_Init()
{
    RegConsoleCmd("sm_ba", RN_Menu_CommandChoice);
    RegConsoleCmd("sm_buffadd", RN_Menu_CommandChoice);
    RegConsoleCmd("sm_buff", RN_Menu_CommandView);
    RegConsoleCmd("sm_b", RN_Menu_CommandView);
    RegConsoleCmd("sm_rn_k", RN_Menu_CommandChoice);
    RegConsoleCmd("sm_rn_l", RN_Menu_CommandView);
    RegConsoleCmd("sm_rn_bind", RN_Menu_CommandBind);
}
