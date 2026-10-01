#if defined _rn_menu_included
 #endinput
#endif
#define _rn_menu_included

Menu g_Menu_Open[MAXPLAYERS + 1];
float g_Menu_LastTap[MAXPLAYERS + 1][2];
bool g_Menu_TapArmed[MAXPLAYERS + 1][2];

/** 会话/生存条件每次打开与选择都验证；in_combat只放宽倒地/被控。 */
bool RN_Menu_Eligible(int client, bool requirePending = true)
{
    if (!RN_Config_Enabled() || !RN_Common_Survivor(client) || IsFakeClient(client) || !IsPlayerAlive(client)) return false;
    if (RN_Config_Int(RN_CVAR_MENU_IN_COMBAT) == 0 &&
        (RN_Common_Incapacitated(client) || RN_Common_Controlled(client))) return false;
    PlayerProfile profile;
    int total, pending;
    return RN_Profile_Get(g_Profile_Index[client], profile) &&
        RN_Profile_Budget(profile, total, pending) && (!requirePending || pending > 0);
}

/** 只取消当前显示对象；档案三项候选保留，关闭不能免费换卡。 */
void RN_Menu_Close(int client)
{
    Menu menu = g_Menu_Open[client];
    g_Menu_Open[client] = null;
    if (menu != null) menu.Cancel();
}

/** 地图结束/关停关闭所有菜单并清理双击会话时间。 */
void RN_Menu_Clear()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        RN_Menu_Close(client);
        RN_Menu_Disconnect(client);
    }
}

/** 断线/接管清理键位状态，避免复用槽位继承首击。 */
void RN_Menu_Disconnect(int client)
{
    RN_Menu_Close(client);
    for (int key = 0; key < 2; key++)
    {
        g_Menu_LastTap[client][key] = 0.0;
        g_Menu_TapArmed[client][key] = false;
    }
}

/** 信息串携带完整上下文，菜单回调不依赖客户端槽位独自证明身份。 */
void RN_Menu_ItemInfo(int client, PlayerProfile profile, int slot, int buff, char[] info, int maxlength)
{
    FormatEx(info, maxlength, "%d:%d:%d:%d:%d:%d:%d", g_Run_Epoch, g_Run_MapEpoch,
        GetClientSerial(client), g_Profile_Index[client], profile.optionVersion, slot, buff);
}

/** 严格解析并校验菜单项；旧局、旧图、旧会话、旧版本和伪选项均拒绝。 */
bool RN_Menu_Validate(Menu menu, int client, int item, PlayerProfile profile, int &slot, int &buff)
{
    if (client < 1 || client > MaxClients || g_Menu_Open[client] != menu ||
        !RN_Menu_Eligible(client) || !RN_Profile_Get(g_Profile_Index[client], profile)) return false;
    char info[128], parts[7][16];
    if (!menu.GetItem(item, info, sizeof(info)) || ExplodeString(info, ":", parts, sizeof(parts), sizeof(parts[])) != 7)
        return false;
    int value[7];
    for (int i = 0; i < sizeof(value); i++)
        if (!RN_Common_ParseUnsigned(parts[i], value[i])) return false;
    if (value[0] != g_Run_Epoch || value[1] != g_Run_MapEpoch || value[2] != GetClientSerial(client) ||
        value[3] != g_Profile_Index[client] || value[4] != profile.optionVersion) return false;
    slot = value[5];
    buff = value[6];
    if (slot == RN_OPTIONS) return buff == PLAYBUFF_NULL && profile.rollLeft > 0;
    return slot >= 0 && slot < RN_OPTIONS && buff > PLAYBUFF_NULL && buff < MAXBUFFENUM &&
        profile.optionBuff[slot] == buff;
}

/** ROLL先准备三项与版本，再扣资源一次；任何失败保留旧候选和余额。 */
bool RN_Menu_Roll(int client, PlayerProfile profile)
{
    int options[RN_OPTIONS], version;
    if (profile.rollLeft <= 0 || !RN_Pool_Options(options) ||
        !RN_Math_Add(profile.optionVersion, 1, version)) return false;
    for (int i = 0; i < RN_OPTIONS; i++) profile.optionBuff[i] = options[i];
    profile.optionVersion = version;
    profile.optionStamp = GetTickedTime();
    profile.rollLeft--;
    RN_Profile_Save(g_Profile_Index[client], profile);
    return true;
}

/** 一帧后显示下一张菜单；校验战役、地图和客户端serial，不跨图复活旧菜单。 */
public void RN_Menu_NextFrame(DataPack pack)
{
    pack.Reset();
    int epoch = pack.ReadCell(), mapEpoch = pack.ReadCell(), serial = pack.ReadCell();
    delete pack;
    int client = GetClientFromSerial(serial);
    if (epoch == g_Run_Epoch && mapEpoch == g_Run_MapEpoch && RN_Menu_Eligible(client)) RN_Menu_Show(client);
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
        if (!RN_Menu_Validate(menu, param1, param2, profile, slot, buff)) return 0;
        bool success = slot == RN_OPTIONS ? RN_Menu_Roll(param1, profile) : RN_Apply_Choose(param1, buff);
        if (success) RN_Menu_Next(param1);
    }
    return 0;
}

/** 缓存不存在才生成；初次开菜单与再次打开不会分别抽卡。 */
void RN_Menu_Show(int client)
{
    if (!RN_Menu_Eligible(client))
    {
        if (RN_Common_Client(client) && !IsFakeClient(client))
            PrintToChat(client, "\x04[rogue]\x01当前无法选卡：需存活生还者、有待选次数，默认倒地或被控时不能选择。");
        return;
    }
    RN_Menu_Close(client);
    PlayerProfile profile;
    RN_Profile_Get(g_Profile_Index[client], profile);
    if (profile.optionBuff[0] == PLAYBUFF_NULL)
    {
        if (!RN_Pool_Options(profile.optionBuff) ||
            !RN_Math_Add(profile.optionVersion, 1, profile.optionVersion)) { RN_Notify_Rejected(client); return; }
        profile.optionStamp = GetTickedTime();
        RN_Profile_Save(g_Profile_Index[client], profile);
    }
    int total, pending;
    RN_Profile_Budget(profile, total, pending);
    Menu menu = new Menu(RN_Menu_OnChoice);
    menu.SetTitle("肉鸽 | Lv.%d %.1f%% | 待选%d ROLL%d\n有效%.1f分钟 | 难度%d",
        g_Run_Level, g_Run_Progress, pending, profile.rollLeft, RN_Clock_Elapsed()/60.0, g_Clock_Tier);
    for (int i = 0; i < RN_OPTIONS; i++)
    {
        char info[128], name[64], rarity[32], description[180], shortText[58], label[160];
        int buff = profile.optionBuff[i];
        RN_Menu_ItemInfo(client, profile, i, buff, info, sizeof(info));
        RN_Buff_Name(buff, name, sizeof(name));
        RN_Buff_RarityText(RN_Buff_Rarity(buff), rarity, sizeof(rarity));
        RN_Buff_Description(buff, description, sizeof(description));
        RN_Common_ShortText(description, shortText, sizeof(shortText));
        FormatEx(label, sizeof(label), "%s [%s]\n%s", name, rarity, shortText);
        menu.AddItem(info, label);
    }
    char info[128], label[64];
    RN_Menu_ItemInfo(client, profile, RN_OPTIONS, PLAYBUFF_NULL, info, sizeof(info));
    FormatEx(label, sizeof(label), "重新ROLL（剩余%d）", profile.rollLeft);
    menu.AddItem(info, label, profile.rollLeft > 0 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
    g_Menu_Open[client] = menu;
    if (!menu.Display(client, 30))
    {
        g_Menu_Open[client] = null;
        delete menu;
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

/** 统一描述展示当前档案和全队武器层数，不将选择预算当作BUFF层数。 */
void RN_Menu_View(int client)
{
    if (!RN_Common_Survivor(client) || IsFakeClient(client) || !RN_Config_Enabled()) return;
    PlayerProfile profile;
    if (!RN_Profile_Get(g_Profile_Index[client], profile)) return;
    RN_Menu_Close(client);
    int total, pending, layers, magazine, reload, cycle;
    RN_Profile_Budget(profile, total, pending);
    for (int id = 1; id < MAXBUFFENUM; id++)
        if (!RN_Math_Add(layers, profile.buff[id], layers)) { layers = RN_MAX_INT; break; }
    RN_Weapons_Totals(-1, profile, magazine, reload, cycle);
    Menu menu = new Menu(RN_Menu_OnView);
    menu.Pagination = 3;
    menu.SetTitle("我的肉鸽 | Lv.%d %.1f%% | 难度%d\n有效%.1f分钟 | 待选%d ROLL%d\n已消费%d | 持续BUFF共%d层\n全队：弹匣%d 换弹%d 射速%d",
        g_Run_Level, g_Run_Progress, g_Clock_Tier, RN_Clock_Elapsed()/60.0, pending, profile.rollLeft,
        profile.usedChoices, layers, magazine, reload, cycle);
    for (int id = 1; id < MAXBUFFENUM; id++)
    {
        if (profile.buff[id] <= 0) continue;
        char name[64], description[180], shortText[58], label[160];
        RN_Buff_Name(id, name, sizeof(name));
        RN_Buff_Description(id, description, sizeof(description));
        RN_Common_ShortText(description, shortText, sizeof(shortText));
        FormatEx(label, sizeof(label), "%s × %d\n%s", name, profile.buff[id], shortText);
        menu.AddItem("", label, ITEMDRAW_DISABLED);
    }
    if (layers == 0) menu.AddItem("", "尚无持续BUFF", ITEMDRAW_DISABLED);
    g_Menu_Open[client] = menu;
    if (!menu.Display(client, 30)) { g_Menu_Open[client] = null; delete menu; }
}

/** 聊天选卡指令始终打开当前缓存候选。 */
public Action RN_Menu_CommandChoice(int client, int args)
{
    if (client > 0) RN_Menu_Show(client);
    return Plugin_Handled;
}

/** 聊天查看指令显示当前个人持续BUFF和团队武器贡献。 */
public Action RN_Menu_CommandView(int client, int args)
{
    if (client > 0) RN_Menu_View(client);
    return Plugin_Handled;
}

/** 独立K/L双击状态；首击静默，第二击触发后解除武装。 */
public Action RN_Menu_CommandTap(int client, int args)
{
    if (!RN_Common_Client(client) || IsFakeClient(client)) return Plugin_Handled;
    char command[32];
    GetCmdArg(0, command, sizeof(command));
    int key = StrEqual(command, "sm_rn_k") ? 0 : 1;
    float now = GetTickedTime();
    float window = RN_Config_Float(RN_CVAR_DOUBLETAP_MS)/1000.0;
    if (g_Menu_TapArmed[client][key] && now - g_Menu_LastTap[client][key] <= window)
    {
        g_Menu_TapArmed[client][key] = false;
        if (key == 0) RN_Menu_Show(client);
        else RN_Menu_View(client);
    }
    else
    {
        g_Menu_LastTap[client][key] = now;
        g_Menu_TapArmed[client][key] = true;
    }
    return Plugin_Handled;
}

/** 进服尝试绑定并给出手动入口；客户端拒绝bind不会影响聊天命令。 */
void RN_Menu_JoinTip(int client)
{
    if (!RN_Common_Client(client) || IsFakeClient(client)) return;
    if (RN_Config_Int(RN_CVAR_AUTO_BIND) != 0)
    {
        ClientCommand(client, "bind k sm_rn_k");
        ClientCommand(client, "bind l sm_rn_l");
    }
    if (RN_Config_Int(RN_CVAR_JOIN_TIP) != 0)
        PrintToChat(client, "\x04[rogue]\x01!ba选卡，!buff查看；双击K/L。自动绑定若被客户端拒绝，可控制台输入 bind k sm_rn_k / bind l sm_rn_l。");
}

/** 统一登记聊天别名与绑定控制台入口。 */
void RN_Menu_Init()
{
    RegConsoleCmd("sm_ba", RN_Menu_CommandChoice);
    RegConsoleCmd("sm_buffadd", RN_Menu_CommandChoice);
    RegConsoleCmd("sm_buff", RN_Menu_CommandView);
    RegConsoleCmd("sm_b", RN_Menu_CommandView);
    RegConsoleCmd("sm_rn_k", RN_Menu_CommandTap);
    RegConsoleCmd("sm_rn_l", RN_Menu_CommandTap);
}

