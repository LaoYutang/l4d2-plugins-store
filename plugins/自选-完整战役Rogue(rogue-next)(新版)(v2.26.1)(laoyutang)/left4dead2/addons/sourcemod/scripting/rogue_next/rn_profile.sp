#if defined _rn_profile_included
 #endinput
#endif
#define _rn_profile_included

enum struct ProfileSpeedSync
{
    int serial;
    int life;
    int epoch;
    int mapEpoch;
    int profileIndex;
    float until;
}

enum struct ProfileHealthSync
{
    int serial;
    int life;
    int epoch;
    int mapEpoch;
    int profileIndex;
    int checksLeft;
    float until;
}

ProfileHealthSync g_Profile_HealthSync[MAXPLAYERS + 1];

ArrayList g_Profile_Records;
StringMap g_Profile_Id2Index;
int g_Profile_Index[MAXPLAYERS + 1];
int g_Profile_BaseMax[MAXPLAYERS + 1];
int g_Profile_OwnedMax[MAXPLAYERS + 1];
float g_Profile_BaseSpeed[MAXPLAYERS + 1];
float g_Profile_OwnedSpeed[MAXPLAYERS + 1];
bool g_Profile_Healing[MAXPLAYERS + 1];
bool g_Profile_DeferredStats[MAXPLAYERS + 1];
ProfileSpeedSync g_Profile_SpeedSync[MAXPLAYERS + 1];
ConVar g_Profile_HealLimits[2];
int g_Profile_HealLimitBase[2];
bool g_Profile_HealLimitsOwned;
bool g_Profile_Unloading;

/** 初始化档案容器；客户端映射必须显式初始化为-1而非默认0。 */
void RN_Profile_Init()
{
    g_Profile_Records = new ArrayList(sizeof(PlayerProfile));
    g_Profile_Id2Index = new StringMap();
    for (int client = 0; client <= MAXPLAYERS; client++) g_Profile_Index[client] = -1;
    g_Profile_HealLimits[0] = FindConVar("pain_pills_health_threshold");
    g_Profile_HealLimits[1] = FindConVar("first_aid_kit_max_heal");
    for (int i = 0; i < 2; i++)
        if (g_Profile_HealLimits[i] != null) g_Profile_HealLimitBase[i] = g_Profile_HealLimits[i].IntValue;
}

/** 按档案下标读取副本；调用方修改后只能提交一次。 */
bool RN_Profile_Get(int index, PlayerProfile profile)
{
    if (index < 0 || index >= g_Profile_Records.Length) return false;
    g_Profile_Records.GetArray(index, profile, sizeof(profile));
    return true;
}

/** 提交经过验证的完整副本，防止嵌套效果分别覆盖旧数据。 */
void RN_Profile_Save(int index, PlayerProfile profile)
{
    if (index >= 0 && index < g_Profile_Records.Length)
        g_Profile_Records.SetArray(index, profile, sizeof(profile));
}

/** 计算历史应得与待选；级别使用共享战役上下文而非客户端个人等级。 */
bool RN_Profile_Budget(PlayerProfile profile, int &total, int &pending)
{
    return RN_Math_Budget(g_Run_InitialChoices, g_Run_ChoicesPerLevel, g_Run_Level,
        profile.bonusChoices, profile.usedChoices, total, pending);
}

/** 稳定SteamID命中旧档；授权失败仅创建会话隔离身份。 */
int RN_Profile_Bind(int client)
{
    if (!RN_Common_Client(client) || IsFakeClient(client) || !g_Run_HasCampaign ||
        (g_Run_Phase != RN_WAITING && g_Run_Phase != RN_RUNNING && g_Run_Phase != RN_TRANSITION)) return -1;
    if (g_Profile_Index[client] >= 0)
    {
        RN_Profile_HealthQueue(client);
        RN_Branch_Remind(client);
        return g_Profile_Index[client];
    }
    char id[40];
    bool stable = GetClientAuthId(client, AuthId_SteamID64, id, sizeof(id), true);
    if (!stable)
    {
        FormatEx(id, sizeof(id), "session:%d", GetClientSerial(client));
        LogError("[rogue-next] %N没有有效SteamID64，使用会话隔离身份；不能保证重连恢复。", client);
    }
    int index;
    PlayerProfile profile;
    if (g_Profile_Id2Index.GetValue(id, index))
    {
        for (int other = 1; other <= MaxClients; other++)
            if (other != client && RN_Common_Client(other) && g_Profile_Index[other] == index)
            {
                LogError("[rogue-next] 重复身份%s，保留原会话绑定。", id);
                return -1;
            }
        RN_Profile_Get(index, profile);
    }
    else
    {
        strcopy(profile.id, sizeof(profile.id), id);
        profile.stableIdentity = stable;
        profile.rollLeft = g_Run_InitialRolls;
        index = g_Profile_Records.PushArray(profile, sizeof(profile));
        g_Profile_Id2Index.SetValue(id, index);
    }
    GetClientName(client, profile.name, sizeof(profile.name));
    g_Profile_Index[client] = index;
    RN_Profile_Save(index, profile);
    RN_Profile_Recalc(client);
    RN_ProfessionWeapon_Bound(client, index, profile);
    RN_Branch_Remind(client);
    return index;
}

/** 战斗读取层数：BOT、旁观、无绑定及关闭状态统一为0。 */
int RN_Profile_Buff(int client, int buff)
{
    if (!RN_Config_Enabled() || !RN_Common_Survivor(client) || IsFakeClient(client) ||
        buff <= PLAYBUFF_NULL || buff >= MAXBUFFENUM) return 0;
    PlayerProfile profile;
    return RN_Profile_Get(g_Profile_Index[client], profile) ? profile.buff[buff] : 0;
}

/** 计算新增上限，使用浮点中间值检查整型可表达范围。 */
bool RN_Profile_HealthBonus(PlayerProfile profile, int &bonus, int level = -1)
{
    float value = float(profile.buff[PLAYBUFF_MAXHEALTH]) * RN_Config_Float(RN_CVAR_ADDMAXHEALTH_SURV)
        + float(profile.buff[PLAYBUFF_IMMOVABLE]) * RN_Config_Float(RN_CVAR_IMMOVABLE_MAXHEALTH_SURV)
        + float(profile.buff[PLAYBUFF_YIJIANSANLIAN]) * RN_Config_Float(RN_CVAR_YIJIANSANLIAN_MAXHEALTH_SURV)
        + RN_Knight_Health(profile, level);
    if (!RN_Math_Finite(value) || value < 0.0 || value >= RN_INT_FLOAT_LIMIT) return false;
    bonus = RoundToZero(value);
    return true;
}

/** 记录自身修改前的基线；跨图若引擎保留了旧贡献，不把旧贡献再次当基线。 */
void RN_Profile_CaptureBase(int client)
{
    int currentMax = GetEntProp(client, Prop_Data, "m_iMaxHealth");
    float speed = GetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue");
    if (g_Profile_OwnedMax[client] == 0 || currentMax != g_Profile_OwnedMax[client])
        g_Profile_BaseMax[client] = currentMax > 0 ? currentMax : 100;
    if (g_Profile_OwnedSpeed[client] == 0.0 || FloatAbs(speed - g_Profile_OwnedSpeed[client]) > 0.0001)
        g_Profile_BaseSpeed[client] = RN_Math_Finite(speed) && speed > 0.0 ? speed : 1.0;
}

/** 出生/绑定/接管后的短窗口复用一秒调度，只登记当前真人自己的移速贡献。 */
void RN_Profile_SpeedQueue(int client)
{
    if (client < 1 || client > MaxClients) return;
    g_Profile_SpeedSync[client].serial = 0;
    PlayerProfile profile;
    if (!RN_Common_ActiveRun() || !RN_Config_Enabled() || !RN_Common_Survivor(client) ||
        !IsPlayerAlive(client) || RN_Common_Incapacitated(client) || g_Profile_OwnedSpeed[client] <= 0.0) return;
    bool hasProfile = !IsFakeClient(client) && RN_Profile_Get(g_Profile_Index[client], profile);
    float personal = hasProfile ? RN_Stats_Get(profile, RN_STAT_MOVE) : 1.0;
    if (FloatAbs(RN_Disaster_MoveFactor(personal) - 1.0) < 0.0001) return;
    g_Profile_SpeedSync[client].serial = GetClientSerial(client);
    g_Profile_SpeedSync[client].life = g_Common_Life[client];
    g_Profile_SpeedSync[client].epoch = g_Run_Epoch;
    g_Profile_SpeedSync[client].mapEpoch = g_Run_MapEpoch;
    g_Profile_SpeedSync[client].profileIndex = g_Profile_Index[client];
    g_Profile_SpeedSync[client].until = GetTickedTime() + 3.0;
}

/** 仅补回短窗口内掉回默认/原基线的移速；不改血量，不强盖外部非默认速度。 */
void RN_Profile_SpeedTick(int client)
{
    ProfileSpeedSync pending;
    pending = g_Profile_SpeedSync[client];
    if (pending.serial == 0) return;
    if (!RN_Common_ActiveRun() || !RN_Config_Enabled() || GetTickedTime() > pending.until ||
        !RN_Common_Survivor(client) || !IsPlayerAlive(client) ||
        GetClientSerial(client) != pending.serial || g_Common_Life[client] != pending.life ||
        g_Run_Epoch != pending.epoch || g_Run_MapEpoch != pending.mapEpoch ||
        g_Profile_Index[client] != pending.profileIndex)
    {
        g_Profile_SpeedSync[client].serial = 0;
        return;
    }
    if (RN_Common_Incapacitated(client) || RN_Common_Controlled(client)) return;
    PlayerProfile profile;
    bool hasProfile = !IsFakeClient(client) && RN_Profile_Get(pending.profileIndex, profile);
    if (!hasProfile && (!RN_Disaster_Active() || g_Disaster_Type != RN_DISASTER_MUD))
    {
        g_Profile_SpeedSync[client].serial = 0;
        return;
    }
    float current = GetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue");
    if (FloatAbs(current - g_Profile_OwnedSpeed[client]) < 0.0001) return;
    float base = g_Profile_BaseSpeed[client];
    if (!RN_Math_Finite(current) || current <= 0.0 ||
        (FloatAbs(current - 1.0) > 0.0001 && FloatAbs(current - base) > 0.0001))
    {
        g_Profile_SpeedSync[client].serial = 0;
        if (RN_Config_Int(RN_CVAR_DEBUG) != 0)
            LogMessage("[rogue-next] MOVE_SYNC_EXTERNAL client=%d serial=%d life=%d run=%d mapEpoch=%d current=%.4f base=%.4f owned=%.4f",
                client, pending.serial, pending.life, pending.epoch, pending.mapEpoch,
                current, base, g_Profile_OwnedSpeed[client]);
        return;
    }
    float speed = current * RN_Disaster_MoveFactor(hasProfile ? RN_Stats_Get(profile, RN_STAT_MOVE) : 1.0);
    if (!RN_Math_Finite(speed) || speed <= 0.0) return;
    g_Profile_BaseSpeed[client] = current;
    SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", speed);
    g_Profile_OwnedSpeed[client] = speed;
    if (RN_Config_Int(RN_CVAR_DEBUG) != 0)
        LogMessage("[rogue-next] MOVE_SYNC_RESTORE client=%d serial=%d life=%d run=%d mapEpoch=%d profile=%d current=%.4f previous_base=%.4f base=%.4f applied=%.4f",
            client, pending.serial, pending.life, pending.epoch, pending.mapEpoch,
            pending.profileIndex, current, base, g_Profile_BaseSpeed[client], speed);
}

/** 重算始终处理零层；无实际新获得的上限效果时不奖励实血。 */
void RN_Profile_Recalc(int client)
{
    if (!RN_Common_Survivor(client) || !IsPlayerAlive(client)) return;
    if (RN_Common_Incapacitated(client))
    {
        g_Profile_SpeedSync[client].serial = 0;
        g_Profile_HealthSync[client].serial = 0;
        g_Profile_DeferredStats[client] = true;
        g_Profile_Healing[client] = false;
        return;
    }
    RN_Profile_CaptureBase(client);
    PlayerProfile profile;
    bool hasProfile = !IsFakeClient(client) && RN_Profile_Get(g_Profile_Index[client], profile);
    int bonus, maximum;
    if (!hasProfile || !RN_Config_Enabled()) bonus = 0;
    else if (!RN_Profile_HealthBonus(profile, bonus)) return;
    if (!RN_Math_Add(g_Profile_BaseMax[client], bonus, maximum)) return;
    float factor = 1.0;
    if (hasProfile && RN_Config_Enabled())
        factor = RN_Stats_Get(profile, RN_STAT_MOVE);
    float speed = g_Profile_BaseSpeed[client] * RN_Disaster_MoveFactor(factor);
    if (!RN_Math_Finite(speed) || speed <= 0.0) return;
    int health = GetEntProp(client, Prop_Data, "m_iHealth");
    SetEntProp(client, Prop_Data, "m_iMaxHealth", maximum);
    SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", speed);
    g_Profile_OwnedMax[client] = maximum;
    g_Profile_OwnedSpeed[client] = speed;
    if (health > maximum) SetEntProp(client, Prop_Data, "m_iHealth", maximum);
    g_Profile_DeferredStats[client] = false;
    g_Profile_Healing[client] = hasProfile && RN_Config_Enabled() &&
        (profile.buff[PLAYBUFF_HEALING] > 0 || profile.buff[PLAYBUFF_TIANXINGJIAN] > 0 ||
         profile.buff[PLAYBUFF_YIJIANSANLIAN] > 0);
    if (hasProfile && RN_Config_Enabled() && profile.deferredHealthBonus > 0)
    {
        int reward = profile.deferredHealthBonus;
        profile.deferredHealthBonus = 0;
        RN_Profile_Save(g_Profile_Index[client], profile);
        RN_Profile_RewardHealth(client, reward);
    }
    RN_Profile_SpeedQueue(client);
    RN_Profile_HealthQueue(client);
}

/** 兑现正数实血奖励并钳制到当前上限；死亡、倒地或挂边时不写血量。 */
void RN_Profile_RewardHealth(int client, int amount)
{
    if (amount <= 0 || !RN_Common_Survivor(client) || !IsPlayerAlive(client) ||
        RN_Common_Incapacitated(client)) return;
    int current = GetEntProp(client, Prop_Data, "m_iHealth");
    int maximum = GetEntProp(client, Prop_Data, "m_iMaxHealth");
    int room = maximum - current;
    if (room > 0) SetEntProp(client, Prop_Data, "m_iHealth", current + (amount < room ? amount : room));
}

/** 真人托管时清BOT个人属性，保留真人档案与复活消耗。 */
void RN_Profile_HandoffToBot(int player, int bot)
{
    if (!RN_Common_Client(player)) return;
    RN_Knight_Forget(bot);
    g_Profile_Healing[player] = false;
    if (RN_Common_Survivor(bot))
    {
        g_Profile_BaseMax[bot] = g_Profile_BaseMax[player] > 0 ? g_Profile_BaseMax[player] : 100;
        g_Profile_BaseSpeed[bot] = g_Profile_BaseSpeed[player] > 0.0 ? g_Profile_BaseSpeed[player] : 1.0;
        g_Profile_OwnedMax[bot] = GetEntProp(bot, Prop_Data, "m_iMaxHealth");
        g_Profile_OwnedSpeed[bot] = GetEntPropFloat(bot, Prop_Send, "m_flLaggedMovementValue");
        RN_Profile_Recalc(bot);
    }
    RN_Profile_StopClient(player, true);
}

/** 真人接管前使用BOT的原始基线，不继承BOT或前任的个人账本。 */
void RN_Profile_Takeover(int bot, int player)
{
    if (!RN_Common_Client(player)) return;
    RN_Knight_Forget(player);
    RN_Knight_Forget(bot);
    if (RN_Common_Client(bot))
    {
        g_Profile_BaseMax[player] = g_Profile_BaseMax[bot] > 0 ? g_Profile_BaseMax[bot] : 100;
        g_Profile_BaseSpeed[player] = g_Profile_BaseSpeed[bot] > 0.0 ? g_Profile_BaseSpeed[bot] : 1.0;
        g_Profile_OwnedMax[player] = GetEntProp(player, Prop_Data, "m_iMaxHealth");
        g_Profile_OwnedSpeed[player] = GetEntPropFloat(player, Prop_Send, "m_flLaggedMovementValue");
        g_Profile_Healing[bot] = false;
    }
    RN_Profile_Bind(player);
    RN_Profile_Recalc(player);
}

/** 一秒调度补齐短时移速/血上限并执行原回血；校验不补发健康奖励。 */
void RN_Profile_Tick()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        RN_Profile_SpeedTick(client);
        RN_Profile_HealthTick(client);
        if (!RN_Common_Survivor(client) || !IsPlayerAlive(client)) continue;
        if (g_Profile_DeferredStats[client] && !RN_Common_Incapacitated(client)) RN_Profile_Recalc(client);
        if (!RN_Config_Enabled()) continue;
        if (IsFakeClient(client)) continue;
        if (!g_Profile_Healing[client] || RN_Common_Incapacitated(client)) continue;
        PlayerProfile profile;
        if (!RN_Profile_Get(g_Profile_Index[client], profile)) continue;
        float rate = RN_Stats_Get(profile, RN_STAT_HEAL);
        float next = profile.healProgress + rate;
        if (!RN_Math_Finite(next) || next >= RN_INT_FLOAT_LIMIT) continue;
        int heal = RoundToFloor(next);
        profile.healProgress = next - float(heal);
        RN_Profile_Save(g_Profile_Index[client], profile);
        RN_Profile_RewardHealth(client, heal);
    }
}

/** 停止会话效果；地图正常结束可以不改即将销毁实体的健康值。 */
void RN_Profile_StopClient(int client, bool restore)
{
    if (client < 1 || client > MaxClients) return;
    RN_Knight_Forget(client);
    g_Profile_SpeedSync[client].serial = 0;
    g_Profile_HealthSync[client].serial = 0;
    RN_Combat_ProtectionClear(client);
    RN_Explosive_Forget(client);
    RN_Grenade_Forget(client);
    g_Profile_Healing[client] = false;
    g_Profile_DeferredStats[client] = false;
    if (!restore || !RN_Common_Client(client)) return;
    bool incapacitated = RN_Common_Survivor(client) && RN_Common_Incapacitated(client);
    if (incapacitated && !g_Profile_Unloading)
    {
        g_Profile_DeferredStats[client] = true;
        return;
    }
    if (g_Profile_OwnedSpeed[client] > 0.0 &&
        FloatAbs(GetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue") - g_Profile_OwnedSpeed[client]) < 0.0001)
        SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", g_Profile_BaseSpeed[client]);
    if (g_Profile_OwnedMax[client] > 0 && GetEntProp(client, Prop_Data, "m_iMaxHealth") == g_Profile_OwnedMax[client])
    {
        int maximum = g_Profile_BaseMax[client];
        SetEntProp(client, Prop_Data, "m_iMaxHealth", maximum);
        int health = GetEntProp(client, Prop_Data, "m_iHealth");
        if (!incapacitated && health > maximum) SetEntProp(client, Prop_Data, "m_iHealth", maximum);
    }
    g_Profile_OwnedMax[client] = 0;
    g_Profile_OwnedSpeed[client] = 0.0;
}

/** 断线释放映射，保留离线档案；原客户端基线不会泄漏到新占槽者。 */
void RN_Profile_Disconnect(int client)
{
    if (client < 1 || client > MaxClients) return;
    RN_Profile_StopClient(client, true);
    g_Profile_Index[client] = -1;
    g_Profile_BaseMax[client] = 0;
    g_Profile_BaseSpeed[client] = 0.0;
    // 倒地断线时StopClient会延后实体恢复；实体即将销毁，不能把该标记和贡献传给新会话。
    g_Profile_OwnedMax[client] = 0;
    g_Profile_OwnedSpeed[client] = 0.0;
    g_Profile_DeferredStats[client] = false;
}

/** 正常过渡销毁会话运行态，档案与选项完整保留。 */
void RN_Profile_EndMap()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        RN_Profile_StopClient(client, false);
        g_Profile_Index[client] = -1;
    }
}

/** 清表之前先停止效果；不能用ArrayList.Clear代替实体清理。 */
void RN_Profile_Clear()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        RN_Profile_StopClient(client, true);
        g_Profile_Index[client] = -1;
    }
    g_Profile_Records.Clear();
    g_Profile_Id2Index.Clear();
}

/** 对药品/医疗包的旧版全局阈值贡献做可恢复的修改。 */
void RN_Profile_HealLimits(bool enable)
{
    int value;
    if (enable && !RN_Math_Add(99, RN_Config_Int(RN_CVAR_ADDMAXHEALTH_SURV), value)) return;
    for (int i = 0; i < 2; i++)
        if (g_Profile_HealLimits[i] != null)
            g_Profile_HealLimits[i].SetInt(enable ? value : g_Profile_HealLimitBase[i]);
    g_Profile_HealLimitsOwned = enable;
}

/** 卸载时释放档案容器并恢复本插件修改的全局医疗阈值。 */
void RN_Profile_Destroy()
{
    RN_Profile_Clear();
    if (g_Profile_HealLimitsOwned) RN_Profile_HealLimits(false);
    delete g_Profile_Records;
    delete g_Profile_Id2Index;
}

/** 提交前验证整份档案的账本和衍生属性，不允许溢出后部分发奖。 */
bool RN_Profile_Validate(PlayerProfile profile, int kills = -1, int level = -1)
{
    if (profile.profession < 0 || profile.profession >= RN_PROFESSION_COUNT || profile.professionVersion < 0 || !RN_Branch_Valid(profile) ||
        !RN_Math_Finite(RN_Profession_GunBonus(profile)) || RN_Profession_BerserkerHeal(profile) < 0 ||
        !RN_Math_Finite(RN_Profession_GunRate(profile)) || RN_Reaper_Heal(profile) < 0 ||
        !RN_Math_Finite(RN_Reaper_Damage(profile, kills)) || !RN_Math_Finite(RN_Reaper_Penalty(profile, kills)) ||
        !RN_Math_Finite(RN_Stats_Get(profile, RN_STAT_INCOMING, kills)) ||
        !RN_Math_Finite(RN_Stats_Get(profile, RN_STAT_GUN_DAMAGE, kills)) ||
        !RN_Math_Finite(RN_Stats_Get(profile, RN_STAT_EXPLOSION_DAMAGE) * 100.0) ||
        !RN_Math_Finite(RN_Stats_Get(profile, RN_STAT_EXPLOSION_RADIUS) * 100.0) ||
        !RN_Math_Finite(RN_Profession_MeleeFactor(profile)) ||
        !RN_Math_Finite(RN_Profession_SniperRate(profile)) ||
        !RN_Math_Finite(RN_Profession_SniperPower(profile) * (1.0 + RN_Config_Float(RN_CVAR_SNIPER_MAX_DISTANCE)/100.0 * RN_Profession_SniperRate(profile))) ||
        !RN_Math_Finite(RN_Profession_Value(profile, PLAYBUFF_DUAL_ELEMENT, RN_CVAR_DUAL_ELEMENT_DAMAGE_REDUCTION)) ||
        !RN_Math_Finite(RN_Stats_Get(profile, RN_STAT_IGNITE)) ||
        !RN_Math_Finite(RN_Stats_Get(profile, RN_STAT_FREEZE)) ||
        !RN_Math_Finite(RN_Stats_Get(profile, RN_STAT_ELECTRIC_CHANCE)) ||
        !RN_Math_Finite(RN_Stats_Get(profile, RN_STAT_ELECTRIC_BONUS) * 100.0) ||
        !RN_Math_Finite(RN_Stats_Get(profile, RN_STAT_ELECTRIC_DAMAGE, kills)) ||
        RN_Stats_Get(profile, RN_STAT_ELECTRIC_DAMAGE, kills) >= RN_INT_FLOAT_LIMIT ||
        !RN_Math_Finite(RN_Stats_Get(profile, RN_STAT_CONTROL)) ||
        !RN_Math_Finite(RN_Stats_Get(profile, RN_STAT_EXPLOSIVE_BULLET)) || !RN_Magician_Validate(profile)) return false;
    int total, pending, health, capacity, faith;
    if (!RN_Profile_Budget(profile, total, pending) || !RN_Profile_HealthBonus(profile, health, level) ||
        !RN_Math_Add(health, 100, capacity) || !RN_Knight_Validate(profile, capacity) ||
        !RN_Math_Multiply(profile.buff[PLAYBUFF_NEVERFALL], RN_Config_Int(RN_CVAR_NEVERFALLNUM_SURV), capacity) ||
        !RN_Math_Multiply(profile.buff[PLAYBUFF_YELI], 3, faith) ||
        !RN_Math_Add(faith, profile.buff[PLAYBUFF_JIFA], faith)) return false;
    if (profile.rollLeft < 0 || profile.neverFallUsed < 0 || profile.deferredHealthBonus < 0) return false;
    for (int buff = 0; buff < MAXBUFFENUM; buff++)
        if (profile.buff[buff] < 0) return false;
    float movement = 1.0 + float(profile.buff[PLAYBUFF_MOVESPEED])*RN_Config_Float(RN_CVAR_MOVESPEEDMULTIPLE_SURV)
        + float(profile.buff[PLAYBUFF_LUOYANEBU])*RN_Config_Float(RN_CVAR_LUOYANEBU_MOVESPEEDMULTIPLE_SURV);
    float heal = RN_Stats_Get(profile, RN_STAT_HEAL);
    float luck = 1.0 + float(profile.buff[PLAYBUFF_QIANGYUN])*RN_Config_Float(RN_CVAR_QIANGYUN_PROBBONUS_SURV);
    float damage = 1.0 + RN_Reaper_Damage(profile, kills) + float(profile.buff[PLAYBUFF_CAUSEHARM])*RN_Config_Float(RN_CVAR_ADDMULTIPLE_SURV)
        + float(profile.buff[PLAYBUFF_PUTONGQUANPU])*RN_Config_Float(RN_CVAR_PUTONGQUANPU_ADDMULTIPLE_SURV)
        + float(profile.buff[PLAYBUFF_GLASSCANNON])*RN_Config_Float(RN_CVAR_GLASSCANNON_DAMAGE_SURV)
        + float(profile.buff[PLAYBUFF_YIJIANSANLIAN])*RN_Config_Float(RN_CVAR_YIJIANSANLIAN_DAMAGE_SURV);
    float critical = RN_Config_Float(RN_CVAR_CRIT_BASE_MULTIPLIER)
        + float(profile.buff[PLAYBUFF_JIANSHENG])*RN_Config_Float(RN_CVAR_JIANSHENG_CRITDAMAGE_SURV)
        + float(profile.buff[PLAYBUFF_HUANYINGCIKE])*RN_Config_Float(RN_CVAR_HUANYINGCIKE_CRITDAMAGE_SURV);
    float melee = RN_Config_Float(RN_CVAR_MELEE_BASE_DAMAGE) *
        (1.0 + float(profile.buff[PLAYBUFF_BAOTIANMA])*RN_Config_Float(RN_CVAR_BAOTIANMA_MELEEDAMAGE_SURV)
        + float(profile.buff[PLAYBUFF_SANDAOLIU])*RN_Config_Float(RN_CVAR_SANDAOLIU_MELEEDAMAGE_SURV)
        + float(profile.buff[PLAYBUFF_JIEWANGQUAN])*RN_Config_Float(RN_CVAR_JIEWANGQUAN_MELEEDAMAGE_SURV));
    float burn = RN_Stats_Get(profile, RN_STAT_BURN_DPS, kills);
    float burnTotal = burn * RN_Branch_FireDuration(profile);
    float explosion = burnTotal * (RN_Config_Int(RN_CVAR_ELEMENT_EXPLOSION_CRIT_ENABLE) != 0
        && RN_Stats_Get(profile, RN_STAT_CRIT_CHANCE) > 0.0 ? critical : 1.0)
        * RN_Stats_Get(profile, RN_STAT_EXPLOSION_DAMAGE);
    return RN_Math_Finite(burn) && burn < RN_INT_FLOAT_LIMIT && RN_Math_Finite(burnTotal)
        && burnTotal < RN_INT_FLOAT_LIMIT && RN_Math_Finite(explosion) && explosion < RN_INT_FLOAT_LIMIT
        && RN_Math_Finite(movement) && RN_Math_Finite(heal) && heal < RN_INT_FLOAT_LIMIT &&
        RN_Math_Finite(luck) && RN_Math_Finite(RN_Combat_MeleeBase(profile) * critical * RN_Profession_SwordDamageFactor(profile))
        && RN_Math_Finite(melee * (damage + RN_Profession_GunBonus(profile)
        + RN_Stats_Value(profile, PLAYBUFF_BIABIABIA, RN_CVAR_BIABIABIA_GUN_DAMAGE)) * critical *
        (1.0 + float(profile.buff[PLAYBUFF_XINLATIANSAI])) *
        RN_Profession_SniperPower(profile) * (1.0 + RN_Config_Float(RN_CVAR_SNIPER_MAX_DISTANCE)/100.0 * RN_Profession_SniperRate(profile))
        * RN_Stats_Get(profile, RN_STAT_EXPLOSION_DAMAGE));
}

/** 将候选个人属性与该实体实际基线合并校验，禁止先扣资源后发现写不下。 */
bool RN_Profile_ValidateClient(int client, PlayerProfile profile, int level = -1)
{
    if (!RN_Common_Survivor(client)) return true;
    int bonus, maximum;
    int base = g_Profile_BaseMax[client] > 0 ? g_Profile_BaseMax[client] : GetEntProp(client, Prop_Data, "m_iMaxHealth");
    if (!RN_Profile_HealthBonus(profile, bonus, level) || !RN_Math_Add(base, bonus, maximum)
        || !RN_Knight_Validate(profile, maximum)) return false;
    float factor = 1.0 + float(profile.buff[PLAYBUFF_MOVESPEED])*RN_Config_Float(RN_CVAR_MOVESPEEDMULTIPLE_SURV)
        + float(profile.buff[PLAYBUFF_LUOYANEBU])*RN_Config_Float(RN_CVAR_LUOYANEBU_MOVESPEEDMULTIPLE_SURV)
        - float(profile.buff[PLAYBUFF_IMMOVABLE])*RN_Config_Float(RN_CVAR_IMMOVABLE_MOVESPEEDREDUCTION_SURV);
    if (factor < 0.1) factor = 0.1;
    float speed = g_Profile_BaseSpeed[client] > 0.0 ? g_Profile_BaseSpeed[client] : 1.0;
    return RN_Math_Finite(factor * speed) && factor * speed > 0.0;
}
