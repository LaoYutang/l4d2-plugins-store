#if defined _rn_common_included
 #endinput
#endif
#define _rn_common_included

#define RN_VERSION "1.0.3"
#define RN_MAX_INT 2147483647
#define RN_INT_FLOAT_LIMIT 2147483520.0
#define RN_OPTIONS 3
#define RN_MAX_REWARD_STEPS 4096
#define RN_MAX_LEVEL_STEPS 4096

enum
{
  PLAYBUFF_NULL,
  PLAYBUFF_MAXHEALTH,
  PLAYBUFF_HEALING,
  PLAYBUFF_MAGAZINE,
  PLAYBUFF_RELOADSPEED,
  PLAYBUFF_FIRERATE,
  PLAYBUFF_CAUSEHARM,
  PLAYBUFF_PUTONGQUANPU,
  PLAYBUFF_SUFFERHRAM,
  PLAYBUFF_PROBINVULNERABILITY,
  PLAYBUFF_POWANGFA,
  PLAYBUFF_PROBIGNITE,
  PLAYBUFF_PROBFREEZE,
  PLAYBUFF_NEVERFALL,
  PLAYBUFF_MOVESPEED,
  PLAYBUFF_LUOYANEBU,
  PLAYBUFF_GLASSCANNON,
  PLAYBUFF_PYROMANIAC,
  PLAYBUFF_CRYOPHILIA,
  PLAYBUFF_DAMOCLESSWORD,
  PLAYBUFF_IMMOVABLE,
  PLAYBUFF_DUOBAOXIANREN,
  PLAYBUFF_SHILENBAODI,
  PLAYBUFF_SHUANGSHENGHUA,
  PLAYBUFF_SHENGSHENGBUXI,
  PLAYBUFF_TIANXINGJIAN,
  PLAYBUFF_SHEXINGZOUWEI,
  PLAYBUFF_ZIZAIJIYI,
  PLAYBUFF_YIJIANSANLIAN,
  PLAYBUFF_ZAILAIYIPING,
  PLAYBUFF_HAIYOUSANBEI,
  PLAYBUFF_XINLATIANSAI,
  PLAYBUFF_JIFA,
  PLAYBUFF_DIANREN,
  PLAYBUFF_ZHIMINGYIJI,
  PLAYBUFF_AIYOUWEI,
  PLAYBUFF_JIANSHENG,
  PLAYBUFF_HUANYINGCIKE,
  PLAYBUFF_QIANGYUN,
  PLAYBUFF_ZHAOZAI,
  PLAYBUFF_YUXI,
  PLAYBUFF_BAOTIANMA,
  PLAYBUFF_SANDAOLIU,
  PLAYBUFF_JIEWANGQUAN,
  PLAYBUFF_FANXING,
  PLAYBUFF_YELI,
  PLAYBUFF_BOZANG,
  PLAYBUFF_FENGGUANGDAZANG,
  MAXBUFFENUM
}

enum
{
  RARITY_COMMON = 0,  // 普通 - Ⅰ
  RARITY_RARE,        // 稀有 - Ⅱ
  RARITY_EPIC,        // 史诗 - Ⅲ
  RARITY_LEGENDARY,   // 传说 - Ⅳ
  MAX_RARITY_LEVELS
}

/** 战役阶段；MapReady另行阻止地图初始化期间的结算。 */
enum RN_RunPhase
{
    RN_WAITING, RN_RUNNING, RN_TRANSITION, RN_RESTARTING, RN_FINISHED
}

/** SteamID档案；禁止在这里保存客户端槽位或实体句柄。 */
enum struct PlayerProfile
{
    char id[40];
    bool stableIdentity;
    char name[MAX_NAME_LENGTH];
    int usedChoices;
    int bonusChoices;
    int rollLeft;
    int buff[MAXBUFFENUM];
    int optionBuff[RN_OPTIONS];
    int optionVersion;
    float optionStamp;
    int neverFallUsed;
    float healProgress;
    float nextRemindAt;
    int deferredHealthBonus;
}

RN_RunPhase g_Run_Phase = RN_FINISHED;
int g_Run_Epoch;
int g_Run_MapEpoch;
bool g_Run_MapReady;
bool g_Run_HasCampaign;
bool g_Run_Transition;
int g_Run_Level;
float g_Run_Progress;
int g_Run_InitialChoices;
int g_Run_ChoicesPerLevel;
int g_Run_InitialRolls;
int g_Run_Chapter = -1;
char g_Run_Mission[128];
char g_Run_FirstMap[PLATFORM_MAX_PATH];
char g_Run_Map[PLATFORM_MAX_PATH];
int g_Common_Life[MAXPLAYERS + 1];

/** 判断客户端是否在游戏；调用任何实体属性前先使用本方法。 */
bool RN_Common_Client(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client);
}

/** 判断阵营2；包含BOT和已死亡但仍留队的客户端。 */
bool RN_Common_Survivor(int client)
{
    return RN_Common_Client(client) && GetClientTeam(client) == 2;
}

/** 判断有效特感客户端，不隐含存活或GHOST条件。 */
bool RN_Common_Infected(int client)
{
    return RN_Common_Client(client) && GetClientTeam(client) == 3;
}

/** 判断是否为Tank；必须先验证客户端，避免世界实体索引误读。 */
bool RN_Common_Tank(int client)
{
    return RN_Common_Infected(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == 8;
}

/** 判断普通感染者或Witch实体；不接受已销毁的索引。 */
bool RN_Common_Zombie(int entity)
{
    if (entity <= MaxClients || !IsValidEntity(entity)) return false;
    char classname[32];
    GetEntityClassname(entity, classname, sizeof(classname));
    return StrEqual(classname, "infected") || StrEqual(classname, "witch");
}

/** 倒地与挂边都不应用站立属性。 */
bool RN_Common_Incapacitated(int client)
{
    return RN_Common_Client(client) &&
        (GetEntProp(client, Prop_Send, "m_isIncapacitated") != 0 ||
         GetEntProp(client, Prop_Send, "m_isHangingFromLedge") != 0);
}

/** 检查控制者；被控玩家默认不能打开菜单。 */
bool RN_Common_Controlled(int client)
{
    static const char props[][] = {"m_tongueOwner", "m_pounceAttacker", "m_jockeyAttacker", "m_carryAttacker", "m_pummelAttacker"};
    if (!RN_Common_Survivor(client)) return false;
    for (int i = 0; i < sizeof(props); i++)
        if (GetEntPropEnt(client, Prop_Send, props[i]) > 0) return true;
    return false;
}

/** 统计生还者总人数；BOT、死亡留队者都算，加载中与旁观者不算。 */
int RN_Common_SurvivorCount()
{
    int count;
    for (int client = 1; client <= MaxClients; client++)
        if (RN_Common_Survivor(client)) count++;
    return count;
}

/** 真人存在口径使用Connected；断线事件通过exclude排除即将离开的客户端。 */
bool RN_Common_HasHuman(int exclude = 0)
{
    for (int client = 1; client <= MaxClients; client++)
        if (client != exclude && IsClientConnected(client) && !IsFakeClient(client)) return true;
    return false;
}

/** 只允许已就绪的准备/进行阶段结算，不在过渡或终局结算。 */
bool RN_Common_ActiveRun()
{
    return g_Run_MapReady && g_Run_HasCampaign &&
        (g_Run_Phase == RN_WAITING || g_Run_Phase == RN_RUNNING);
}

/** 跨平台校验地图标识，禁止将mission文件内容直接拼成可执行命令。 */
bool RN_Common_SafeMapName(const char[] map)
{
    if (map[0] == '\0') return false;
    for (int i = 0; map[i] != '\0'; i++)
    {
        int c = map[i];
        if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
              (c >= '0' && c <= '9') || c == '_' || c == '-' || c == '/')) return false;
    }
    return true;
}

/** 判断SDKHooks伤害中的近战武器实体。 */
bool RN_Common_Melee(int entity)
{
    if (entity <= MaxClients || !IsValidEntity(entity)) return false;
    char classname[32];
    GetEntityClassname(entity, classname, sizeof(classname));
    return StrEqual(classname, "weapon_melee");
}

/** 使用UTF-8安全的常规聊天接口；调用方保证格式字符串来自代码。 */
void RN_Common_Log(const char[] message)
{
    LogMessage("[rogue-next] %s", message);
}

/** 严格解析非负十进制整数；拒绝负号、尾随字符与整型溢出。 */
bool RN_Common_ParseUnsigned(const char[] text, int &value)
{
    if (text[0] == '\0') return false;
    int result;
    for (int i = 0; text[i] != '\0'; i++)
    {
        int digit = text[i] - '0';
        if (digit < 0 || digit > 9 || result > (RN_MAX_INT - digit) / 10) return false;
        result = result * 10 + digit;
    }
    value = result;
    return true;
}

/** 按UTF-8字符边界缩短菜单文案，为512字节无线电菜单保留空间。 */
void RN_Common_ShortText(const char[] source, char[] result, int maxlength)
{
    int cursor, limit = maxlength - 4;
    while (source[cursor] != '\0' && cursor < limit)
    {
        int first = source[cursor] & 0xFF;
        int bytes = first < 0x80 ? 1 : (first < 0xE0 ? 2 : (first < 0xF0 ? 3 : 4));
        if (cursor + bytes > limit) break;
        cursor += bytes;
    }
    strcopy(result, maxlength, source);
    result[cursor] = '\0';
    if (source[cursor] != '\0') StrCat(result, maxlength, "…");
}

