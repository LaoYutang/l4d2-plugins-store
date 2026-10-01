#if defined _rn_xp_source_included
 #endinput
#endif
#define _rn_xp_source_included

static const char g_XP_Names[8][] = {"smoker", "boomer", "hunter", "spitter", "jockey", "charger", "witch", "tank"};
static const RN_ConfigKey g_XP_Keys[8] = {
    RN_CVAR_XP_SMOKER, RN_CVAR_XP_BOOMER, RN_CVAR_XP_HUNTER, RN_CVAR_XP_SPITTER,
    RN_CVAR_XP_JOCKEY, RN_CVAR_XP_CHARGER, RN_CVAR_XP_WITCH, RN_CVAR_XP_TANK
};
int g_XP_ClientSerial[MAXPLAYERS + 1];
int g_XP_ClientLife[MAXPLAYERS + 1];
bool g_XP_DeathSeen[MAXPLAYERS + 1];
int g_XP_BirthClass[MAXPLAYERS + 1];
StringMap g_XP_WitchBirth;
StringMap g_XP_WitchDeaths;
ConVar g_XP_Difficulty;

/** 初始化动态女巫缓存并绑定游戏难度ConVar；经验参数由统一配置模块持有。 */
void RN_XP_Init()
{
    g_XP_WitchBirth = new StringMap();
    g_XP_WitchDeaths = new StringMap();
    g_XP_Difficulty = FindConVar("z_difficulty");
    if (g_XP_Difficulty == null)
        LogError("[rogue-next] 未找到z_difficulty，击杀经验按专家配置倍率回退。");
}

/** 读取类型的已验证基准经验；热改立即用于后续击杀，不保留第二份经验缓存。 */
int RN_XP_Value(int type)
{
    return type >= 0 && type < sizeof(g_XP_Keys) ? RN_Config_Int(g_XP_Keys[type]) : 0;
}

/** 读取击杀当时的游戏难度与已验证倍率；缺失或未知名称按专家配置回退。 */
float RN_XP_Rate(char[] difficulty, int length)
{
    if (g_XP_Difficulty == null)
    {
        strcopy(difficulty, length, "unavailable");
        return RN_Config_Float(RN_CVAR_XP_RATE_EXPERT);
    }
    g_XP_Difficulty.GetString(difficulty, length);
    if (StrEqual(difficulty, "Easy", false)) return RN_Config_Float(RN_CVAR_XP_RATE_EASY);
    if (StrEqual(difficulty, "Normal", false)) return RN_Config_Float(RN_CVAR_XP_RATE_NORMAL);
    if (StrEqual(difficulty, "Hard", false)) return RN_Config_Float(RN_CVAR_XP_RATE_HARD);
    return RN_Config_Float(RN_CVAR_XP_RATE_EXPERT);
}

/** 玩家出生建立serial+生命轮次标识，去重与阵营迁移不使用userid单独判断。 */
void RN_XP_Birth(int client)
{
    if (!RN_Common_Client(client)) return;
    g_XP_ClientSerial[client] = GetClientSerial(client);
    g_XP_ClientLife[client] = g_Common_Life[client];
    g_XP_DeathSeen[client] = false;
    g_XP_BirthClass[client] = RN_Common_Infected(client) ? GetEntProp(client, Prop_Send, "m_zombieClass") : 0;
}

/** 女巫出生缓存EntRef；事件到达时即使实体已移除也不读取无效属性。 */
void RN_XP_WitchBirth(int entity)
{
    if (!RN_Common_Zombie(entity)) return;
    char classname[32], key[16];
    GetEntityClassname(entity, classname, sizeof(classname));
    if (!StrEqual(classname, "witch")) return;
    IntToString(entity, key, sizeof(key));
    g_XP_WitchBirth.SetValue(key, EntIndexToEntRef(entity));
}

/** 直接经验归因独立于死亡奖励；纯BOT服不结算成长。 */
bool RN_XP_EligibleKiller(int attacker)
{
    return RN_Config_Enabled() && RN_Common_HasHuman() && RN_Common_Survivor(attacker) &&
        (!IsFakeClient(attacker) || RN_Config_Int(RN_CVAR_XP_COUNT_BOTS) != 0);
}

/** 死亡奖励接受明确敌方/友方击杀和有效口水实体，排除自杀与世界归因。 */
bool RN_XP_DeathRewardEligible(int victim, int attacker, int attackerEntity)
{
    if (attacker == victim) return false;
    if (RN_Common_Survivor(attacker) || RN_Common_Infected(attacker) || RN_Common_Zombie(attackerEntity)) return true;
    if (attackerEntity <= MaxClients || !IsValidEntity(attackerEntity)) return false;
    char classname[32];
    GetEntityClassname(attackerEntity, classname, sizeof(classname));
    return StrEqual(classname, "insect_swarm") || StrEqual(classname, "spitter_projectile");
}

/** 基准XP乘当前难度倍率后原子结算，记录倍率与实际经验；首个有效击杀补判开局。 */
void RN_XP_Grant(int xp, int attacker, const char[] source)
{
    RN_Clock_Departure();
    char difficulty[32];
    float rate = RN_XP_Rate(difficulty, sizeof(difficulty));
    float awarded = float(xp) * rate;
    int count = RN_Common_SurvivorCount();
    int oldLevel = g_Run_Level;
    float need = RN_Team_Need();
    if (!RN_Team_Gain(awarded, count)) return;
    if (g_Team_RoundKills < RN_MAX_INT) g_Team_RoundKills++;
    if (RN_Config_Int(RN_CVAR_DEBUG) != 0)
        LogMessage("[rogue-next] XP source=%s killer=%d base=%d difficulty=%s rate=%.3f xp=%.3f survivors=%d need=%.2f level=%d->%d progress=%.4f elapsed=%.2f tier=%d",
            source, attacker, xp, difficulty, rate, awarded, count, need, oldLevel, g_Run_Level,
            g_Run_Progress, RN_Clock_Elapsed(), g_Clock_Tier);
}

/** 玩家死亡先标记本生命，经验与生还者死亡奖励使用不同判定。 */
void RN_XP_PlayerDeath(int victim, int attacker, int attackerEntity)
{
    if (!RN_Config_Enabled() || !RN_Common_Client(victim)) return;
    if (g_XP_ClientSerial[victim] != GetClientSerial(victim) ||
        g_XP_ClientLife[victim] != g_Common_Life[victim] || g_XP_DeathSeen[victim]) return;
    g_XP_DeathSeen[victim] = true;
    if (RN_Common_Survivor(victim))
    {
        if (RN_XP_DeathRewardEligible(victim, attacker, attackerEntity)) RN_Apply_Death(victim);
        return;
    }
    if (!RN_Common_Infected(victim) || !RN_XP_EligibleKiller(attacker) ||
        GetEntProp(victim, Prop_Send, "m_isGhost") != 0) return;
    int zombieClass = g_XP_BirthClass[victim];
    if (zombieClass >= 1 && zombieClass <= 6)
        RN_XP_Grant(RN_XP_Value(zombieClass - 1), attacker, g_XP_Names[zombieClass - 1]);
    else if (zombieClass == 8)
        RN_XP_Grant(RN_XP_Value(7), attacker, g_XP_Names[7]);
}

/** 女巫死亡按EntRef每图去重，不把普通感染者或索引复用误判为女巫。 */
void RN_XP_WitchDeath(int entity, int attacker)
{
    if (!RN_XP_EligibleKiller(attacker)) return;
    int ref;
    char key[16];
    if (entity > MaxClients && IsValidEntity(entity))
    {
        char classname[32];
        GetEntityClassname(entity, classname, sizeof(classname));
        if (!StrEqual(classname, "witch")) return;
        ref = EntIndexToEntRef(entity);
    }
    else
    {
        IntToString(entity, key, sizeof(key));
        if (!g_XP_WitchBirth.GetValue(key, ref)) return;
    }
    IntToString(ref, key, sizeof(key));
    int ignored;
    if (g_XP_WitchDeaths.GetValue(key, ignored)) return;
    g_XP_WitchDeaths.SetValue(key, 1);
    RN_XP_Grant(RN_XP_Value(6), attacker, g_XP_Names[6]);
}

/** 每图清理实体去重缓存；跨图保留经验配置与团队进度。 */
void RN_XP_Clear()
{
    g_XP_WitchBirth.Clear();
    g_XP_WitchDeaths.Clear();
    for (int client = 1; client <= MaxClients; client++)
    {
        g_XP_ClientSerial[client] = 0;
        g_XP_ClientLife[client] = 0;
        g_XP_DeathSeen[client] = false;
        g_XP_BirthClass[client] = 0;
    }
}

