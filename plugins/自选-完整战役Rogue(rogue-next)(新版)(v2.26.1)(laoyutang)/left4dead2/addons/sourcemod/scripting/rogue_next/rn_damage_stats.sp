#if defined _rn_damage_stats_included
 #endinput
#endif
#define _rn_damage_stats_included

#define RN_DAMAGE_BASE 1000000000
ArrayList g_Damage_Totals;

/** 累计与BUFF档案分离，命中时不复制/覆盖整份玩家档案。 */
void RN_Damage_Init()
{
    g_Damage_Totals = new ArrayList(2);
    RN_Damage_CaptureInit();
}

/** 完整清档归零累计并释放瞬时采集；正常换章保留累计。 */
void RN_Damage_Clear()
{
    if (g_Damage_Totals != null) g_Damage_Totals.Clear();
    RN_Damage_CaptureClear();
}

/** 非负双整数以十亿为基数精确相加，失败不改变原账本。 */
bool RN_Damage_Add(const int left[2], const int right[2], int result[2])
{
    int low = left[1] + right[1];
    int carry = low >= RN_DAMAGE_BASE ? 1 : 0;
    int high;
    if (!RN_Math_Add(left[0], right[0], high) || !RN_Math_Add(high, carry, high)) return false;
    result[0] = high;
    result[1] = low - carry * RN_DAMAGE_BASE;
    return true;
}

/** 按高位、低位比较，累计超过float32精度或32位整数仍稳定排序。 */
bool RN_Damage_Greater(const int left[2], const int right[2])
{
    return left[0] > right[0] || (left[0] == right[0] && left[1] > right[1]);
}

/** 扣血是引擎整数；仅在明确归属的实际扣血后更新该档案的独立累计。 */
void RN_Damage_Award(int index, int amount)
{
    if (amount <= 0 || index < 0 || index >= g_Profile_Records.Length) return;
    int empty[2];
    while (g_Damage_Totals.Length <= index) g_Damage_Totals.PushArray(empty, sizeof(empty));
    int previous[2], increment[2], total[2];
    g_Damage_Totals.GetArray(index, previous, sizeof(previous));
    increment[0] = amount / RN_DAMAGE_BASE;
    increment[1] = amount % RN_DAMAGE_BASE;
    if (!RN_Damage_Add(previous, increment, total))
    {
        LogError("[rogue-next] 伤害累计超出账本容量：profile=%d。", index);
        return;
    }
    g_Damage_Totals.SetArray(index, total, sizeof(total));
}

/** 大整数输出不先转换float，保持每一点累计的精确十进制显示。 */
void RN_Damage_Text(const int total[2], char[] text, int maxlength)
{
    char digits[32];
    if (total[0] == 0) FormatEx(digits, sizeof(digits), "%d", total[1]);
    else FormatEx(digits, sizeof(digits), "%d%09d", total[0], total[1]);
    if (maxlength <= 0) return;
    int length = strlen(digits), written;
    for (int index = 0; index < length && written < maxlength - 1; index++)
    {
        if (index > 0 && (length - index) % 3 == 0)
        {
            text[written++] = ',';
            if (written >= maxlength - 1) break;
        }
        text[written++] = digits[index];
    }
    text[written] = '\0';
}

/** 占比只在查看或章节输出时转换，沿用已修复的百分比显示舍入。 */
void RN_Damage_Percent(const int part[2], const int whole[2], char[] text, int maxlength)
{
    float denominator = float(whole[0]) * float(RN_DAMAGE_BASE) + float(whole[1]);
    float numerator = float(part[0]) * float(RN_DAMAGE_BASE) + float(part[1]);
    RN_Math_NumberText(denominator > 0.0 ? numerator / denominator * 100.0 : 0.0, text, maxlength, 1);
}

/** 查看或章节输出才读取在线姓名，离线使用保留档案；控制字符不能插入新聊天行。 */
bool RN_Damage_Name(int index, PlayerProfile profile, char[] name, int maxlength)
{
    char full[MAX_NAME_LENGTH];
    strcopy(full, sizeof(full), profile.name);
    bool online;
    for (int client = 1; client <= MaxClients; client++)
        if (RN_Common_Client(client) && !IsFakeClient(client) && g_Profile_Index[client] == index)
        {
            GetClientName(client, full, sizeof(full));
            online = true;
            break;
        }
    for (int i = 0; full[i] != '\0'; i++)
        if (full[i] < 32 || full[i] == 127) full[i] = ' ';
    RN_Common_ShortText(full[0] != '\0' ? full : "未命名", name, maxlength);
    return online;
}

/** 共用只读排名快照；稳定同分顺序、全员分母，不结算命中或改变播报代次。 */
int RN_Damage_Ranking(int[][] leaders, int limit, int total[2])
{
    total[0] = 0; total[1] = 0;
    if (g_Damage_Totals == null || limit <= 0) return 0;
    int count = g_Damage_Totals.Length;
    if (count > g_Profile_Records.Length) count = g_Profile_Records.Length;
    int used;
    for (int index = 0; index < count; index++)
    {
        int value[2], next[2];
        g_Damage_Totals.GetArray(index, value, sizeof(value));
        if (value[0] == 0 && value[1] == 0) continue;
        if (!RN_Damage_Add(total, value, next))
        {
            LogError("[rogue-next] 全队伤害累计超出账本容量，未输出误导占比。");
            return -1;
        }
        total = next;
        int insert;
        while (insert < used)
        {
            int previous[2];
            previous[0] = leaders[insert][1]; previous[1] = leaders[insert][2];
            if (RN_Damage_Greater(value, previous)) break;
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

/** 管理员查询复用姓名、职业、离线标记及精确千分位文案。 */
bool RN_Damage_RankText(const int[] entry, int rank, const int total[2], char[] text, int maxlength)
{
    PlayerProfile profile;
    if (!RN_Profile_Get(entry[0], profile)) return false;
    int value[2];
    value[0] = entry[1]; value[1] = entry[2];
    char name[49], career[24], amount[32], percent[24];
    bool online = RN_Damage_Name(entry[0], profile, name, sizeof(name));
    RN_Profession_Name(profile.profession, career, sizeof(career));
    RN_Damage_Text(value, amount, sizeof(amount));
    RN_Damage_Percent(value, total, percent, sizeof(percent));
    FormatEx(text, maxlength, "%d. %s（%s）%s：%s（%s%%）",
        rank, name, career, online ? "" : "[离线]", amount, percent);
    return true;
}

#include "rn_damage_capture.sp"
