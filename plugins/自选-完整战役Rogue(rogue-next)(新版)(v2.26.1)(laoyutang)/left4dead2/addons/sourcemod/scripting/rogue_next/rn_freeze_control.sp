#if defined _rn_freeze_control_included
 #endinput
#endif
#define _rn_freeze_control_included

int g_Freeze_Ref[MAXPLAYERS + 1];
int g_Freeze_Serial[MAXPLAYERS + 1];
int g_Freeze_Life[MAXPLAYERS + 1];
int g_Freeze_Run[MAXPLAYERS + 1];
int g_Freeze_Map[MAXPLAYERS + 1];

/** 守护属于一份完整生命快照；旧记录不能移除同槽位的新冻结守护。 */
bool RN_Freeze_Owns(RN_FXRecord record)
{
    int client = record.entityIndex;
    return client > 0 && client <= MaxClients && g_Freeze_Ref[client] == record.ref &&
        g_Freeze_Serial[client] == record.serial && g_Freeze_Life[client] == record.life &&
        g_Freeze_Run[client] == record.runEpoch && g_Freeze_Map[client] == record.mapEpoch;
}

/** 先注销绑定，再只在原客户端实体仍存在时解绑；失效对象不读写属性。 */
void RN_Freeze_Detach(RN_FXRecord record)
{
    if (!RN_Freeze_Owns(record)) return;
    int client = record.entityIndex;
    g_Freeze_Ref[client] = g_Freeze_Serial[client] = g_Freeze_Life[client] = 0;
    g_Freeze_Run[client] = g_Freeze_Map[client] = 0;
    if (!RN_Common_Client(client) || GetClientSerial(client) != record.serial ||
        EntIndexToEntRef(client) != record.ref) return;
    SDKUnhook(client, SDKHook_PreThinkPost, RN_Freeze_OnThink);
    SDKUnhook(client, SDKHook_PostThinkPost, RN_Freeze_OnThink);
}

/** 独立注销客户端现有绑定，不能依赖可能已经删除的效果记录。 */
void RN_Freeze_DetachClient(int client)
{
    RN_FXRecord record;
    record.entityIndex = client;
    record.ref = g_Freeze_Ref[client];
    record.serial = g_Freeze_Serial[client];
    record.life = g_Freeze_Life[client];
    record.runEpoch = g_Freeze_Run[client];
    record.mapEpoch = g_Freeze_Map[client];
    RN_Freeze_Detach(record);
}

/** 仅冰冻中的感染者注册Think守护；续冻不增加重复钩子。 */
void RN_Freeze_Bind(RN_FXRecord record, int client)
{
    if (RN_Freeze_Owns(record)) return;
    if (g_Freeze_Ref[client] != 0) RN_Freeze_DetachClient(client);
    g_Freeze_Ref[client] = record.ref;
    g_Freeze_Serial[client] = record.serial;
    g_Freeze_Life[client] = record.life;
    g_Freeze_Run[client] = record.runEpoch;
    g_Freeze_Map[client] = record.mapEpoch;
    SDKHook(client, SDKHook_PreThinkPost, RN_Freeze_OnThink);
    SDKHook(client, SDKHook_PostThinkPost, RN_Freeze_OnThink);
}

/** 全部输入/Think检查共用登记，普通玩家在空绑定处立即返回。 */
bool RN_Freeze_Current(int client, RN_FXRecord record)
{
    if (client < 1 || client > MaxClients || g_Freeze_Ref[client] == 0) return false;
    int index = RN_FX_Find(g_Freeze_Ref[client]);
    if (index >= 0)
    {
        g_FX_Records.GetArray(index, record, sizeof(record));
        if (RN_Config_Enabled() && RN_Freeze_Owns(record) && RN_FX_Resolve(record) == client &&
            RN_Common_Infected(client) && IsPlayerAlive(client) && record.freezeTimer != null)
            return record.freezeEnd > GetTickedTime();
    }
    RN_Freeze_DetachClient(client);
    return false;
}

/** 清速度而不改位置或恢复旧动量；SDK传送放最后，避免重入后继续写实体。 */
void RN_Freeze_Lock(RN_FXRecord record, int client)
{
    int flags = GetEntityFlags(client);
    if ((flags & record.flag) != record.flag) SetEntityFlags(client, flags | record.flag);
    if (GetEntityMoveType(client) != MOVETYPE_NONE) SetEntityMoveType(client, MOVETYPE_NONE);
    float velocity[3], stopped[3];
    GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);
    if (velocity[0] != 0.0 || velocity[1] != 0.0 || velocity[2] != 0.0)
        TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, stopped);
}

/** SDK重入后同时验证生命、阵营、运行边界和效果登记是否仍然有效。 */
bool RN_Freeze_Valid(RN_FXRecord record, int client)
{
    return RN_Config_Enabled() && RN_FX_Resolve(record) == client && RN_Common_Infected(client) &&
        IsPlayerAlive(client) && RN_FX_Find(record.ref) >= 0;
}

/** 清理每次冰冻的特感动作；已有骑乘仅在双方关系匹配时解除。 */
bool RN_Freeze_Cleanup(int client, RN_FXRecord record)
{
    if (GetEntProp(client, Prop_Send, "m_zombieClass") == 5 &&
        HasEntProp(client, Prop_Send, "m_jockeyVictim"))
    {
        int victim = GetEntPropEnt(client, Prop_Send, "m_jockeyVictim");
        if (RN_Common_Survivor(victim) && IsPlayerAlive(victim) &&
            GetEntPropEnt(victim, Prop_Send, "m_jockeyAttacker") == client)
        {
            if (GetFeatureStatus(FeatureType_Native, "L4D2_Jockey_EndRide") == FeatureStatus_Available)
            {
                RN_FX_LogStep("before_freeze_endride", record);
                L4D2_Jockey_EndRide(victim, client);
                RN_FX_LogStep("after_freeze_endride", record);
            }
            else LogError("[rogue-next] 缺少L4D2_Jockey_EndRide，骑乘冰冻使用通用动作清理：client=%d。", client);
            if (!RN_Freeze_Valid(record, client)) return false;
        }
    }
    RN_FX_LogStep("before_freeze_cleanup", record);
    L4D_CleanupPlayerState(client);
    RN_FX_LogStep("after_freeze_cleanup", record);
    return RN_Freeze_Valid(record, client);
}

/** AI可能在Think中重新写入跳跃/冲锋速度，只对仍有效的冰冻对象补限制。 */
public void RN_Freeze_OnThink(int client)
{
    RN_FXRecord record;
    if (RN_Freeze_Current(client, record)) RN_Freeze_Lock(record, client);
}

/** 冻结期间阻止移动、跳跃和攻击输入，视角继续由客户端控制。 */
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3],
    int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
    RN_Branch_Command(client, buttons);
    RN_FXRecord record;
    if (!RN_Freeze_Current(client, record)) return Plugin_Continue;
    buttons = 0;
    vel[0] = vel[1] = vel[2] = 0.0;
    return Plugin_Changed;
}
