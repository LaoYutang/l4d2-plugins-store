#if defined _rn_disaster_included
 #endinput
#endif
#define _rn_disaster_included

enum RN_Disaster
{
    RN_DISASTER_NONE, RN_DISASTER_ELEMENT, RN_DISASTER_PHYSICAL,
    RN_DISASTER_MUD, RN_DISASTER_MONSOON, RN_DISASTER_PUNISHMENT, RN_DISASTER_COUNT
}
enum RN_AddedDamage
{
    RN_ADDED_ELEMENT, RN_ADDED_SETTLED_ELEMENT, RN_ADDED_SETTLED_PHYSICAL
}
static const char g_Disaster_Names[][] = {
    "无灾害", "元素浩劫", "铜墙铁壁", "如陷泥潭", "季风", "天罚"
};
static const char g_Disaster_GameNames[][] = {"简单", "普通", "高级", "专家"};
RN_Disaster g_Disaster_Type;
int g_Disaster_Epoch, g_Disaster_MapEpoch, g_Disaster_Progress;
int g_Disaster_Difficulty, g_Disaster_Tier;
float g_Disaster_Chance, g_Disaster_Amount;
bool g_Disaster_Prepared, g_Disaster_Terminated, g_Disaster_Departed;
float g_Disaster_DepartureAt = -1.0;
float g_Disaster_PendingDeparture = -1.0;
int g_Disaster_NoticeSerial[MAXPLAYERS + 1];
int g_Disaster_ClientSerial[MAXPLAYERS + 1], g_Disaster_ClientLife[MAXPLAYERS + 1];
float g_Disaster_ClientLast[MAXPLAYERS + 1], g_Disaster_ClientCarry[MAXPLAYERS + 1];

/** 总开关、HUD及时间难度共同控制整个灾害系统。 */
bool RN_Disaster_Allowed()
{
    return RN_Config_Enabled() && RN_Config_Int(RN_CVAR_HUD_ENABLE) != 0 &&
        RN_Config_Int(RN_CVAR_DISASTER_ENABLE) != 0 && RN_Config_Int(RN_CVAR_SCALING_ENABLE) != 0;
}

/** 只接受当前战役/地图一次准备的有效快照。 */
bool RN_Disaster_Active()
{
    return g_Disaster_Type != RN_DISASTER_NONE && !g_Disaster_Terminated && RN_Disaster_Allowed() &&
        g_Disaster_Epoch == g_Run_Epoch && g_Disaster_MapEpoch == g_Run_MapEpoch;
}

/** 先比较封顶点再乘大档位，防止无上限时间难度产生溢出。 */
float RN_Disaster_Strength(int tier, float perTier, float cap)
{
    if (tier <= 0 || perTier <= 0.0 || cap <= 0.0) return 0.0;
    if (float(tier) >= cap / perTier) return cap;
    float amount = float(tier) * perTier;
    return amount < cap ? amount : cap;
}

/** 单一伤害金额的一次抗性；地图强杀/无关对象由调用者排除。 */
float RN_Disaster_DamageFactor(bool element)
{
    if (!RN_Disaster_Active()) return 1.0;
    return g_Disaster_Type == (element ? RN_DISASTER_ELEMENT : RN_DISASTER_PHYSICAL)
        ? 1.0 - g_Disaster_Amount : 1.0;
}

/** 个人净移速和章节减速共用最终下限，BOT同样读取章节效果。 */
float RN_Disaster_MoveFactor(float personal)
{
    if (RN_Disaster_Active() && g_Disaster_Type == RN_DISASTER_MUD)
        personal *= 1.0 - g_Disaster_Amount;
    return personal < 0.1 ? 0.1 : personal;
}

/** 稳定短文案供HUD、菜单、聊天和管理员查询共用。 */
void RN_Disaster_Text(char[] name, int nameLength, char[] detail, int detailLength)
{
    strcopy(name, nameLength, g_Disaster_Names[view_as<int>(g_Disaster_Type)]);
    if (!RN_Disaster_Active()) { strcopy(detail, detailLength, "本章无有效灾害"); return; }
    char number[32];
    RN_Math_NumberText(g_Disaster_Amount * (g_Disaster_Type == RN_DISASTER_PUNISHMENT ? 1.0 : 100.0),
        number, sizeof(number), g_Disaster_Type == RN_DISASTER_PUNISHMENT ? 1 : 0);
    switch (g_Disaster_Type)
    {
        case RN_DISASTER_ELEMENT: FormatEx(detail, detailLength, "元素抗性%s%%", number);
        case RN_DISASTER_PHYSICAL: FormatEx(detail, detailLength, "物理抗性%s%%", number);
        case RN_DISASTER_MUD: FormatEx(detail, detailLength, "移速降低%s%%", number);
        case RN_DISASTER_MONSOON: FormatEx(detail, detailLength, "感染者移速+%s%%", number);
        case RN_DISASTER_PUNISHMENT: FormatEx(detail, detailLength, "每秒扣血%s", number);
    }
}

/** 章初游戏难度名称供只读状态展示，不读取当前热改后的难度。 */
void RN_Disaster_GameName(char[] text, int maxlength)
{
    strcopy(text, maxlength, g_Disaster_GameNames[g_Disaster_Difficulty]);
}

/** 后加入/重连私人补告一次，不给BOT或相同会话重复发送。 */
void RN_Disaster_NotifyClient(int client)
{
    if (!RN_Disaster_Active() || !RN_Common_Survivor(client) || IsFakeClient(client)) return;
    int serial = GetClientSerial(client);
    if (g_Disaster_NoticeSerial[client] == serial) return;
    char name[32], detail[80]; RN_Disaster_Text(name, sizeof(name), detail, sizeof(detail));
    PrintToChat(client, "\x04[Rogue]\x01本章灾害：%s，%s，本章结束解除。", name, detail);
    g_Disaster_NoticeSerial[client] = serial;
}

/** 清除个人扣血游标，不把上一生命或托管实体的余额转交。 */
void RN_Disaster_ClientBirth(int client)
{
    if (client < 1 || client > MaxClients) return;
    g_Disaster_ClientSerial[client] = RN_Common_Client(client) ? GetClientSerial(client) : 0;
    g_Disaster_ClientLife[client] = g_Common_Life[client];
    g_Disaster_ClientLast[client] = GetTickedTime();
    g_Disaster_ClientCarry[client] = 0.0;
}

/** 清除效果时保留正常推进计数；新战役同时清零所有章节信息。 */
void RN_Disaster_Clear(bool newRun = true)
{
    g_Disaster_Type = RN_DISASTER_NONE;
    g_Disaster_Amount = 0.0;
    g_Disaster_Departed = false;
    g_Disaster_DepartureAt = -1.0;
    g_Disaster_PendingDeparture = -1.0;
    g_Disaster_Prepared = false;
    g_Disaster_Terminated = false;
    g_Disaster_Epoch = 0; g_Disaster_MapEpoch = 0;
    g_Disaster_Difficulty = 0; g_Disaster_Tier = 0; g_Disaster_Chance = 0.0;
    if (newRun) g_Disaster_Progress = 0;
    RN_Disaster_NPCSync(false);
    RN_HUD_DisasterClear();
    for (int client = 1; client <= MaxClients; client++)
    {
        g_Disaster_NoticeSerial[client] = 0;
        RN_Disaster_ClientBirth(client);
    }
}

/** 关闭即结束本章，不恢复旧结果、不利用反复开关补抽。 */
void RN_Disaster_ConfigApplied()
{
    if (!g_Disaster_Prepared || g_Disaster_Terminated || RN_Disaster_Allowed()) return;
    g_Disaster_Type = RN_DISASTER_NONE;
    g_Disaster_Amount = 0.0;
    g_Disaster_Difficulty = 0; g_Disaster_Tier = 0; g_Disaster_Chance = 0.0;
    g_Disaster_Departed = false; g_Disaster_DepartureAt = -1.0;
    g_Disaster_PendingDeparture = -1.0;
    g_Disaster_Terminated = true;
    RN_Disaster_NPCSync(false);
    RN_HUD_DisasterClear();
    for (int client = 1; client <= MaxClients; client++) RN_Disaster_ClientBirth(client);
}

/** 本章真实出门在战役时钟早退前登记，下一章仍需新通知。 */
void RN_Disaster_Departure(bool confirmed = true)
{
    if (!confirmed) return;
    if (!g_Run_MapReady || !g_Disaster_Prepared)
    {
        if (g_Disaster_PendingDeparture < 0.0) g_Disaster_PendingDeparture = GetTickedTime();
        return;
    }
    if (g_Disaster_Epoch != g_Run_Epoch || g_Disaster_MapEpoch != g_Run_MapEpoch ||
        g_Disaster_Departed || g_Disaster_Terminated) return;
    g_Disaster_Departed = true;
    g_Disaster_DepartureAt = GetTickedTime();
    for (int client = 1; client <= MaxClients; client++) RN_Disaster_ClientBirth(client);
}

/** 读取各灾害独立配置，用相同公式保存金额快照。 */
float RN_Disaster_Candidate(RN_Disaster type, int tier)
{
    if (type == RN_DISASTER_MONSOON && !RN_Disaster_NPCReady()) return 0.0;
    static const RN_ConfigKey perKeys[] = {
        RN_CVAR_DISASTER_ELEMENT_PER_TIER, RN_CVAR_DISASTER_PHYSICAL_PER_TIER,
        RN_CVAR_DISASTER_MUD_PER_TIER, RN_CVAR_DISASTER_MONSOON_PER_TIER, RN_CVAR_DISASTER_PUNISHMENT_PER_TIER
    };
    static const RN_ConfigKey caps[] = {
        RN_CVAR_DISASTER_ELEMENT_CAP, RN_CVAR_DISASTER_PHYSICAL_CAP,
        RN_CVAR_DISASTER_MUD_CAP, RN_CVAR_DISASTER_MONSOON_CAP, RN_CVAR_DISASTER_PUNISHMENT_CAP
    };
    int index = view_as<int>(type) - 1;
    return RN_Disaster_Strength(tier, RN_Config_Float(perKeys[index]), RN_Config_Float(caps[index]));
}

/** 就绪时仅一次抽取；首章、零强度及全零权重不消费随机数。 */
void RN_Disaster_Prepare(bool continued = false, bool chapterKnown = true)
{
    if (g_Disaster_Prepared && g_Disaster_Epoch == g_Run_Epoch && g_Disaster_MapEpoch == g_Run_MapEpoch) return;
    if (chapterKnown && g_Run_Chapter > 0) g_Disaster_Progress = g_Run_Chapter;
    else if (!continued) g_Disaster_Progress = 1;
    else if (g_Disaster_Progress < RN_MAX_INT) g_Disaster_Progress++;
    else { SetFailState("灾害章节计数耗尽，请重载Rogue。"); return; }
    g_Disaster_Prepared = true;
    g_Disaster_Epoch = g_Run_Epoch; g_Disaster_MapEpoch = g_Run_MapEpoch;
    g_Disaster_Terminated = !RN_Disaster_Allowed();
    g_Disaster_Type = RN_DISASTER_NONE; g_Disaster_Amount = 0.0;
    if (g_Disaster_PendingDeparture >= 0.0 || RN_Clock_AlreadyDeparted())
        RN_Disaster_Departure();
    g_Disaster_PendingDeparture = -1.0;
    if (g_Disaster_Terminated || g_Disaster_Progress <= 1) return;
    char difficulty[32];
    g_Disaster_Difficulty = RN_XP_DifficultyIndex(difficulty, sizeof(difficulty));
    static const RN_ConfigKey chances[] = {
        RN_CVAR_DISASTER_CHANCE_EASY, RN_CVAR_DISASTER_CHANCE_NORMAL,
        RN_CVAR_DISASTER_CHANCE_HARD, RN_CVAR_DISASTER_CHANCE_EXPERT
    };
    g_Disaster_Chance = RN_Config_Float(chances[g_Disaster_Difficulty]);
    g_Disaster_Tier = RN_Clock_CurrentTier();
    if (g_Disaster_Tier <= 0 || g_Disaster_Chance <= 0.0) return;
    int weights[RN_DISASTER_COUNT], sum;
    for (int type = 1; type < view_as<int>(RN_DISASTER_COUNT); type++)
    {
        if (RN_Disaster_Candidate(view_as<RN_Disaster>(type), g_Disaster_Tier) <= 0.0) continue;
        weights[type] = RN_Config_Int(view_as<RN_ConfigKey>(view_as<int>(RN_CVAR_DISASTER_WEIGHT_ELEMENT) + type - 1));
        if (!RN_Math_Add(sum, weights[type], sum)) return;
    }
    if (sum <= 0 || (g_Disaster_Chance < 100.0 && GetRandomFloat(0.0, 100.0) >= g_Disaster_Chance)) return;
    int pick = GetRandomInt(1, sum);
    for (int type = 1; type < view_as<int>(RN_DISASTER_COUNT); type++)
    {
        pick -= weights[type];
        if (pick > 0) continue;
        g_Disaster_Type = view_as<RN_Disaster>(type);
        g_Disaster_Amount = RN_Disaster_Candidate(g_Disaster_Type, g_Disaster_Tier);
        break;
    }
    RN_Disaster_NPCSync(g_Disaster_Type == RN_DISASTER_MONSOON);
    char name[32], detail[80]; RN_Disaster_Text(name, sizeof(name), detail, sizeof(detail));
    PrintToChatAll("\x04[Rogue]\x01本章灾害：%s，%s，本章结束解除。", name, detail);
    for (int client = 1; client <= MaxClients; client++)
        if (RN_Common_Survivor(client) && !IsFakeClient(client)) g_Disaster_NoticeSerial[client] = GetClientSerial(client);
    if (RN_Config_Int(RN_CVAR_DEBUG) != 0)
        LogMessage("[rogue-next] DISASTER chapter=%d game=%s chance=%.1f tier=%d type=%d amount=%.3f run=%d map=%d",
            g_Disaster_Progress, difficulty, g_Disaster_Chance, g_Disaster_Tier, g_Disaster_Type,
            g_Disaster_Amount, g_Run_Epoch, g_Run_MapEpoch);
}
