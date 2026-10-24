#if defined _rn_profile_health_included
 #endinput
#endif
#define _rn_profile_health_included

/** 有效个人上限重算后登记3秒/最多3次校验；不为BOT或零加成登记。 */
void RN_Profile_HealthQueue(int client)
{
    if (client < 1 || client > MaxClients) return;
    g_Profile_HealthSync[client].serial = 0;
    PlayerProfile profile;
    int bonus, maximum;
    if (!RN_Common_ActiveRun() || !RN_Config_Enabled() || !RN_Common_Survivor(client) ||
        !IsClientConnected(client) || IsFakeClient(client) || !IsPlayerAlive(client) ||
        RN_Common_Incapacitated(client) || !RN_Profile_Get(g_Profile_Index[client], profile) ||
        !RN_Profile_HealthBonus(profile, bonus) || bonus <= 0 || g_Profile_BaseMax[client] <= 0 ||
        !RN_Math_Add(g_Profile_BaseMax[client], bonus, maximum) || maximum != g_Profile_OwnedMax[client]) return;
    g_Profile_HealthSync[client].serial = GetClientSerial(client);
    g_Profile_HealthSync[client].life = g_Common_Life[client];
    g_Profile_HealthSync[client].epoch = g_Run_Epoch;
    g_Profile_HealthSync[client].mapEpoch = g_Run_MapEpoch;
    g_Profile_HealthSync[client].profileIndex = g_Profile_Index[client];
    g_Profile_HealthSync[client].checksLeft = 3;
    g_Profile_HealthSync[client].until = GetTickedTime() + 3.0;
}

/** 仅补回原基线上的本人上限；不重算全部属性、不写实血或消费健康奖励。 */
void RN_Profile_HealthTick(int client)
{
    ProfileHealthSync pending;
    pending = g_Profile_HealthSync[client];
    if (pending.serial == 0) return;
    if (!RN_Common_ActiveRun() || !RN_Config_Enabled() || GetTickedTime() > pending.until ||
        pending.checksLeft <= 0 || !RN_Common_Survivor(client) || !IsClientConnected(client) ||
        IsFakeClient(client) || !IsPlayerAlive(client) || GetClientSerial(client) != pending.serial ||
        g_Common_Life[client] != pending.life || g_Run_Epoch != pending.epoch ||
        g_Run_MapEpoch != pending.mapEpoch || g_Profile_Index[client] != pending.profileIndex)
    {
        g_Profile_HealthSync[client].serial = 0;
        return;
    }
    g_Profile_HealthSync[client].checksLeft--;
    if (g_Profile_HealthSync[client].checksLeft == 0) g_Profile_HealthSync[client].serial = 0;
    if (RN_Common_Incapacitated(client) || RN_Common_Controlled(client)) return;
    PlayerProfile profile;
    int bonus, maximum;
    if (!RN_Profile_Get(pending.profileIndex, profile) || !RN_Profile_HealthBonus(profile, bonus) ||
        bonus <= 0 || g_Profile_BaseMax[client] <= 0 ||
        !RN_Math_Add(g_Profile_BaseMax[client], bonus, maximum) || maximum != g_Profile_OwnedMax[client])
    {
        g_Profile_HealthSync[client].serial = 0;
        return;
    }
    int current = GetEntProp(client, Prop_Data, "m_iMaxHealth");
    if (current == maximum) return;
    if (current != g_Profile_BaseMax[client])
    {
        g_Profile_HealthSync[client].serial = 0;
        if (RN_Config_Int(RN_CVAR_DEBUG) != 0)
            LogMessage("[rogue-next] HEALTH_SYNC_EXTERNAL client=%d serial=%d life=%d run=%d mapEpoch=%d current=%d base=%d owned=%d",
                client, pending.serial, pending.life, pending.epoch, pending.mapEpoch,
                current, g_Profile_BaseMax[client], g_Profile_OwnedMax[client]);
        return;
    }
    SetEntProp(client, Prop_Data, "m_iMaxHealth", maximum);
    if (RN_Config_Int(RN_CVAR_DEBUG) != 0)
        LogMessage("[rogue-next] HEALTH_SYNC_RESTORE client=%d serial=%d life=%d run=%d mapEpoch=%d profile=%d current=%d base=%d applied=%d",
            client, pending.serial, pending.life, pending.epoch, pending.mapEpoch,
            pending.profileIndex, current, g_Profile_BaseMax[client], maximum);
}
