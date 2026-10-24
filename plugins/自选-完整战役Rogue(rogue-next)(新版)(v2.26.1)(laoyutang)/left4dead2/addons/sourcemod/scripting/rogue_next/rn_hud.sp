#if defined _rn_hud_included
 #endinput
#endif
#define _rn_hud_included

#include <l4d2_ems_hud>

#define RN_HUD_MAX_ROWS 15
#define RN_HUD_ROWS 16
#define RN_HUD_BYTES 128
#define RN_HUD_CELL 33
#define RN_HUD_SLOTS 11
#define RN_HUD_TOP 0.085
#define RN_HUD_TEXT_HEIGHT 0.021
#define RN_HUD_SLOT_HEIGHT 0.030
#define RN_HUD_PADDING 0.012

static const int g_HUD_Slots[RN_HUD_SLOTS] = {
    HUD_RIGHT_TOP, HUD_FAR_RIGHT, HUD_LEFT_BOT,
    HUD_MID_TOP, HUD_TICKER, HUD_MID_BOT, HUD_FAR_LEFT,
    HUD_MID_BOX, HUD_SCORE_TITLE, HUD_SCORE_1, HUD_SCORE_2
};
static const float g_HUD_X[RN_HUD_SLOTS] = {
    0.155, 0.155, 0.00, 0.045, 0.045, 0.110, 0.110, 0.82, 0.82, 0.82, 0.82
};
static const float g_HUD_Width[RN_HUD_SLOTS] = {
    0.435, 0.435, 0.035, 0.055, 0.055, 0.035, 0.035, 0.17, 0.17, 0.17, 0.17
};
static const char g_HUD_Titles[][] = {"玩家名", "职业", "伤害", "特感"};
bool g_HUD_MapActive;
bool g_HUD_ModeCaptured;
bool g_HUD_ModeBase;
int g_HUD_ShownRows;
int g_HUD_MapTick;
char g_HUD_LastText[RN_HUD_SLOTS][RN_HUD_BYTES];
bool g_HUD_DisasterShown;
char g_HUD_DisasterText[2][RN_HUD_BYTES];

/** 灾害占用独立两槽，关闭后立即撤销，不影响原十一槽布局。 */
void RN_HUD_DisasterClear()
{
    if (g_HUD_MapActive && g_HUD_DisasterShown)
    {
        RemoveHUD(HUD_SCORE_3); RemoveHUD(HUD_SCORE_4);
    }
    g_HUD_DisasterShown = false;
    g_HUD_DisasterText[0][0] = '\0'; g_HUD_DisasterText[1][0] = '\0';
}

/** 以右侧第四行文字为锚，空一行后显示名称与实际强度，不随榜单人数下移。 */
void RN_HUD_DisasterTick()
{
    if (!RN_Disaster_Active()) { RN_HUD_DisasterClear(); return; }
    char name[32], detail[80], text[2][RN_HUD_BYTES];
    RN_Disaster_Text(name, sizeof(name), detail, sizeof(detail));
    FormatEx(text[0], RN_HUD_BYTES, "灾害：%s\n ", name);
    FormatEx(text[1], RN_HUD_BYTES, " \n%s", detail);
    float height = RN_HUD_SLOT_HEIGHT * 2 + RN_HUD_PADDING;
    float top = RN_HUD_TOP + RN_HUD_TEXT_HEIGHT * 5 - (height - RN_HUD_TEXT_HEIGHT * 2) / 2.0;
    for (int item = 0; item < 2; item++)
    {
        if (g_HUD_DisasterShown && StrEqual(g_HUD_DisasterText[item], text[item])) continue;
        int slot = item == 0 ? HUD_SCORE_3 : HUD_SCORE_4;
        HUDSetLayout(slot, HUD_FLAG_NOBG | HUD_FLAG_TEAM_SURVIVORS | HUD_FLAG_TEXT | HUD_FLAG_ALIGN_LEFT, "%s", text[item]);
        HUDPlace(slot, 0.820, top, 0.170, height);
        strcopy(g_HUD_DisasterText[item], RN_HUD_BYTES, text[item]);
    }
    g_HUD_DisasterShown = true;
}

/** 整数商余数四舍五入到一位小数；单位边界晋级，不损失排序账本精度。 */
void RN_HUD_DamageText(const int total[2], char[] text, int maxlength)
{
    int low = total[1];
    if (total[0] > 0 || low >= 999950000)
    {
        int whole = total[0], tenth = (low + 50000000) / 100000000;
        if (tenth == 10)
        {
            if (whole == RN_MAX_INT)
            {
                FormatEx(text, maxlength, "%d%d.0B", whole / 10, whole % 10 + 1);
                return;
            }
            whole++; tenth = 0;
        }
        FormatEx(text, maxlength, "%d.%dB", whole, tenth);
    }
    else if (low >= 999950)
    {
        int tenths = (low + 50000) / 100000;
        FormatEx(text, maxlength, "%d.%dM", tenths / 10, tenths % 10);
    }
    else if (low >= 1000)
    {
        int tenths = (low + 50) / 100;
        FormatEx(text, maxlength, "%d.%dK", tenths / 10, tenths % 10);
    }
    else IntToString(low, text, maxlength);
}

/** 以完整UTF-8字符截断，姓名清洗仍复用现有伤害榜规则。 */
void RN_HUD_Truncate(const char[] source, int budget, char[] text, int maxlength)
{
    int length, available = maxlength - 1;
    if (budget < available) available = budget;
    while (source[length] != '\0')
    {
        int byte = source[length] & 0xFF;
        int size = byte < 0x80 ? 1 : (byte < 0xE0 ? 2 : (byte < 0xF0 ? 3 : 4));
        if (length + size > available) break;
        length += size;
    }
    for (int index = 0; index < length; index++) text[index] = source[index];
    text[length] = '\0';
}

/** 在线真人生还者及对应托管者入榜；BOT和纯旁观者不产生新排名行。 */
bool RN_HUD_Participant(int client)
{
    if (!RN_Common_Client(client) || IsFakeClient(client)) return false;
    if (GetClientTeam(client) == 2) return true;
    if (GetClientTeam(client) != 1) return false;
    for (int bot = 1; bot <= MaxClients; bot++)
        if (RN_Common_Survivor(bot) && IsFakeClient(bot) &&
            HasEntProp(bot, Prop_Send, "m_humanSpectatorUserID") &&
            GetClientOfUserId(GetEntProp(bot, Prop_Send, "m_humanSpectatorUserID")) == client) return true;
    return false;
}

/** 包含零伤害玩家，按精确累计降序，同分按档案先后稳定排列。 */
int RN_HUD_Ranking(int[][] leaders, int limit)
{
    int used;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!RN_HUD_Participant(client)) continue;
        int index = g_Profile_Index[client];
        if (index < 0 || index >= g_Profile_Records.Length) continue;
        int value[2];
        if (index < g_Damage_Totals.Length) g_Damage_Totals.GetArray(index, value, sizeof(value));
        int insert;
        while (insert < used)
        {
            int previous[2]; previous[0] = leaders[insert][1]; previous[1] = leaders[insert][2];
            if (RN_Damage_Greater(value, previous) ||
                (!RN_Damage_Greater(previous, value) && index < leaders[insert][0])) break;
            insert++;
        }
        if (insert >= limit) continue;
        if (used < limit) used++;
        for (int move = used - 1; move > insert; move--)
            for (int cell = 0; cell < 3; cell++) leaders[move][cell] = leaders[move - 1][cell];
        leaders[insert][0] = index;
        leaders[insert][1] = value[0]; leaders[insert][2] = value[1];
    }
    return used;
}

/** 拼接前检查127字节预算，拒绝截断最后几行或半个中文字符。 */
bool RN_HUD_Append(char[] text, const char[] part)
{
    if (strlen(text) + strlen(part) >= RN_HUD_BYTES) return false;
    StrCat(text, RN_HUD_BYTES, part);
    return true;
}

/** 双槽位各保存相同总行数，不负责的行填空格，复用lyt的纵向拼接方式。 */
bool RN_HUD_PackColumn(char column[RN_HUD_ROWS][RN_HUD_CELL], int count, int rows,
    char[] first, char[] second, bool alwaysSplit = false)
{
    if (!alwaysSplit)
    {
        bool fits = true;
        for (int row = 0; row < rows && fits; row++)
        {
            if (row > 0) fits = RN_HUD_Append(first, "\n");
            if (fits) fits = RN_HUD_Append(first, column[row]);
        }
        if (fits)
        {
            for (int row = 0; row < rows; row++)
            {
                if (row > 0) RN_HUD_Append(second, "\n");
                RN_HUD_Append(second, " ");
            }
            return true;
        }
        first[0] = '\0';
    }
    int split = alwaysSplit ? (count + 1) / 2 : count / 2;
    for (int row = 0; row < rows; row++)
    {
        if (row > 0 && (!RN_HUD_Append(first, "\n") || !RN_HUD_Append(second, "\n"))) return false;
        bool left = row == 0 || (row <= split && row <= count);
        bool right = row > split && row <= count;
        if (!RN_HUD_Append(first, left ? column[row] : " ") ||
            !RN_HUD_Append(second, right ? column[row] : " ")) return false;
    }
    return true;
}

/** 名字预算包含标题、两边空行与全部换行符，人数变化不会切掉后半榜。 */
int RN_HUD_NameBudget(int count, int rows)
{
    int split = (count + 1) / 2, budget = RN_HUD_CELL - 1;
    if (split > 0)
    {
        int first = (127 - (rows - 1) - (rows - split - 1) - strlen(g_HUD_Titles[0])) / split;
        if (first < budget) budget = first;
    }
    int remaining = count - split;
    if (remaining > 0)
    {
        int second = (127 - (rows - 1) - (rows - remaining)) / remaining;
        if (second < budget) budget = second;
    }
    return budget;
}

/** 数字列沿用lyt的空格右对齐，使用缩写后的实际宽度而非截断原值。 */
void RN_HUD_Align(char column[RN_HUD_ROWS][RN_HUD_CELL], int count)
{
    int width;
    for (int row = 1; row <= count; row++)
        if (strlen(column[row]) > width) width = strlen(column[row]);
    for (int row = 1; row <= count; row++)
    {
        char original[RN_HUD_CELL]; strcopy(original, sizeof(original), column[row]);
        int padding = width - strlen(original);
        for (int i = 0; i < padding; i++) column[row][i] = ' ';
        column[row][padding] = '\0';
        StrCat(column[row], RN_HUD_CELL, original);
    }
}

/** 姓名始终双槽位；极大伤害或击杀数字也可借第二槽位保留完整15行。 */
bool RN_HUD_BuildRanking(int[][] leaders, int count, int rows, char text[RN_HUD_SLOTS][RN_HUD_BYTES])
{
    char column[4][RN_HUD_ROWS][RN_HUD_CELL];
    for (int col = 0; col < 4; col++)
    {
        strcopy(column[col][0], RN_HUD_CELL, g_HUD_Titles[col]);
        for (int row = 1; row < rows; row++) strcopy(column[col][row], RN_HUD_CELL, " ");
    }
    int budget = RN_HUD_NameBudget(count, rows);
    for (int rank = 0; rank < count; rank++)
    {
        PlayerProfile profile;
        if (!RN_Profile_Get(leaders[rank][0], profile)) return false;
        char name[49]; RN_Damage_Name(leaders[rank][0], profile, name, sizeof(name));
        int row = rank + 1;
        RN_HUD_Truncate(name, budget, column[0][row], RN_HUD_CELL);
        RN_Branch_DisplayName(profile, column[1][row], RN_HUD_CELL);
        int value[2]; value[0] = leaders[rank][1]; value[1] = leaders[rank][2];
        RN_HUD_DamageText(value, column[2][row], RN_HUD_CELL);
        IntToString(RN_HUDStats_Read(leaders[rank][0]), column[3][row], RN_HUD_CELL);
    }
    RN_HUD_Align(column[2], count); RN_HUD_Align(column[3], count);
    if (!RN_HUD_PackColumn(column[0], count, rows, text[0], text[1], true)) return false;
    for (int row = 0; row < rows; row++)
    {
        if (row > 0 && !RN_HUD_Append(text[2], "\n")) return false;
        if (!RN_HUD_Append(text[2], column[1][row])) return false;
    }
    return RN_HUD_PackColumn(column[2], count, rows, text[3], text[4]) &&
        RN_HUD_PackColumn(column[3], count, rows, text[5], text[6]);
}

/** 路程按最前生还者的地图flow计算，缺失/非法回退0，并限制0到100。 */
int RN_HUD_Progress()
{
    float maximum = L4D2Direct_GetMapMaxFlowDistance();
    if (!RN_Math_Finite(maximum) || maximum <= 0.0) return 0;
    int client = L4D_GetHighestFlowSurvivor();
    float flow = RN_Common_Survivor(client) ? L4D2Direct_GetFlowDistance(client) : L4D2_GetFurthestSurvivorFlow();
    if (!RN_Math_Finite(flow) || flow <= 0.0) return 0;
    float ratio = flow / maximum;
    if (ratio >= 1.0) return 100;
    return RoundToCeil(ratio * 100.0);
}

/** 右侧四项各占一槽，并补齐与左侧相同的总行数和首行位置。 */
void RN_HUD_BuildInfo(int rows, char text[RN_HUD_SLOTS][RN_HUD_BYTES])
{
    char info[4][80];
    int chapter = L4D_GetCurrentChapter(), maximum = L4D_GetMaxChapters();
    if (chapter <= 0) chapter = g_Run_Chapter;
    if (chapter > 0 && maximum >= chapter) FormatEx(info[0], sizeof(info[]), "章节：%d/%d", chapter, maximum);
    else if (chapter > 0) FormatEx(info[0], sizeof(info[]), "章节：%d/?", chapter);
    else strcopy(info[0], sizeof(info[]), "章节：?/?");
    FormatEx(info[1], sizeof(info[]), "路程：%d%%", RN_HUD_Progress());
    FormatEx(info[2], sizeof(info[]), "团队等级：%d", g_Run_Level);
    bool scaling = RN_Config_Int(RN_CVAR_SCALING_ENABLE) != 0;
    FormatEx(info[3], sizeof(info[]), "难度等级：%d%s", scaling ? RN_Clock_CurrentTier() : 0, scaling ? "" : "（停用）");
    for (int item = 0; item < 4; item++)
        for (int row = 0; row < rows; row++)
        {
            if (row > 0) RN_HUD_Append(text[7 + item], "\n");
            RN_HUD_Append(text[7 + item], row == item ? info[item] : " ");
        }
}

/** 立即清理内置HUD并使文字缓存失效，不改变统计或战役状态。 */
void RN_HUD_Clear()
{
    RN_HUD_DisasterClear();
    if (g_HUD_MapActive && g_HUD_ShownRows > 0)
        for (int slot = 0; slot < RN_HUD_SLOTS; slot++) RemoveHUD(g_HUD_Slots[slot]);
    g_HUD_ShownRows = 0;
    for (int slot = 0; slot < RN_HUD_SLOTS; slot++) g_HUD_LastText[slot][0] = '\0';
}

/** 每图重新捕获HUD启用基线；就绪前不读取地图进度或绘制。 */
void RN_HUD_MapStart()
{
    RN_HUD_Clear();
    g_HUD_MapActive = true;
    g_HUD_ModeCaptured = false;
    g_HUD_MapTick = GetGameTickCount();
}

/** 换图或卸载释放本图显示，并恢复本插件启用前的挑战HUD开关。 */
void RN_HUD_MapEnd()
{
    RN_HUD_Clear();
    if (g_HUD_MapActive && g_HUD_ModeCaptured)
        GameRules_SetProp("m_bChallengeModeActive", g_HUD_ModeBase, _, _, true);
    g_HUD_ModeCaptured = false;
    g_HUD_MapActive = false;
}

/** 复用一秒调度；相同文字不反复清除重绘，所有槽位共用lyt的顶部补偿。 */
void RN_HUD_Tick()
{
    if (!g_HUD_MapActive) return;
    if (!RN_Config_Enabled() || RN_Config_Int(RN_CVAR_HUD_ENABLE) == 0 ||
        !g_Run_MapReady || !g_Run_HasCampaign || !RN_Common_ActiveRun() || !RN_Common_HasHuman())
    {
        RN_HUD_Clear();
        return;
    }
    if (GetGameTickCount() <= g_HUD_MapTick) return;
    int[][] leaders = new int[RN_HUD_MAX_ROWS][3];
    int count = RN_HUD_Ranking(leaders, RN_Config_Int(RN_CVAR_HUD_TOP));
    int rows = count + 1;
    if (rows < 4) rows = 4;
    char text[RN_HUD_SLOTS][RN_HUD_BYTES];
    if (!RN_HUD_BuildRanking(leaders, count, rows, text))
    {
        RN_HUD_Clear();
        LogError("[rogue-next] HUD列超出文字预算，未发送截断榜单。");
        return;
    }
    RN_HUD_BuildInfo(rows, text);
    bool mode = GameRules_GetProp("m_bChallengeModeActive") != 0;
    if (!g_HUD_ModeCaptured)
    {
        g_HUD_ModeBase = mode;
        g_HUD_ModeCaptured = true;
    }
    if (!mode) EnableHUD();
    float height = RN_HUD_SLOT_HEIGHT * rows + RN_HUD_PADDING;
    float top = RN_HUD_TOP - (height - RN_HUD_TEXT_HEIGHT * rows) / 2.0;
    for (int slot = 0; slot < RN_HUD_SLOTS; slot++)
    {
        if (g_HUD_ShownRows == rows && StrEqual(g_HUD_LastText[slot], text[slot])) continue;
        int flags = HUD_FLAG_NOBG | HUD_FLAG_TEAM_SURVIVORS | HUD_FLAG_TEXT | HUD_FLAG_ALIGN_LEFT;
        HUDSetLayout(g_HUD_Slots[slot], flags, "%s", text[slot]);
        HUDPlace(g_HUD_Slots[slot], g_HUD_X[slot], top, g_HUD_Width[slot], height);
        strcopy(g_HUD_LastText[slot], RN_HUD_BYTES, text[slot]);
    }
    g_HUD_ShownRows = rows;
    RN_HUD_DisasterTick();
}
