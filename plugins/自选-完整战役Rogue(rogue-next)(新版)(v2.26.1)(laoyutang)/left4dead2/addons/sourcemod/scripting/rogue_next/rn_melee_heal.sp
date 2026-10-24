#if defined _rn_melee_heal_included
 #endinput
#endif
#define _rn_melee_heal_included

enum struct RN_LeechSwing
{
    MeleeWrite identity;
    int token;
    float end;
}

RN_LeechSwing g_Leech_Current[MAXPLAYERS + 1];
RN_LeechSwing g_Leech_Candidate[MAXPLAYERS + 1];
int g_Leech_Token;

/** 只保留攻速与剑气共用的挥击身份；嗜血狂战由特感死亡路由结算。 */
void RN_Leech_Stop(int client)
{
    g_Melee_EventToken[client] = 0;
    g_Leech_Current[client].token = 0;
    g_Leech_Candidate[client].token = 0;
}

/** 丢弃和销毁清除该武器的挥击身份，保留别的玩家和武器。 */
void RN_Leech_ForgetEntity(int entity)
{
    for (int client = 1; client <= MaxClients; client++)
        if (g_Leech_Current[client].identity.entity == entity || g_Leech_Candidate[client].identity.entity == entity)
            RN_Leech_Stop(client);
}

/** 捕获新尝试；失败尝试保留上一成功挥击供攻速与剑气校验。 */
void RN_Leech_Pre(int client, MeleeWrite capture)
{
    RN_LeechSwing candidate;
    candidate.identity = capture;
    if (g_Leech_Token == RN_MAX_INT) { RN_Profession_Warn("挥击编号"); return; }
    candidate.token = ++g_Leech_Token;
    g_Leech_Candidate[client] = candidate;
    RN_Sword_Pre(client, candidate.token, capture);
}

/** 核对武器、会话、生命、地图和战役，迟到回调不影响新挥击。 */
bool RN_Leech_Valid(int client, RN_LeechSwing swing, bool accepted = true)
{
    if (swing.token == 0 || !RN_Common_Client(client) ||
        swing.identity.serial != GetClientSerial(client) || swing.identity.life != g_Common_Life[client] ||
        swing.identity.epoch != g_Run_Epoch || swing.identity.mapEpoch != g_Run_MapEpoch) return false;
    int weapon = RN_Melee_Weapon(client);
    return weapon > MaxClients && EntIndexToEntRef(weapon) == swing.identity.ref
        && (!accepted || GetGameTime() <= swing.end);
}

/** 引擎确认成功才提交挥击身份，并交由剑气完成同一编号的发射。 */
void RN_Leech_Finish(int client, bool accepted, float end = 0.0)
{
    RN_LeechSwing candidate;
    candidate = g_Leech_Candidate[client];
    g_Leech_Candidate[client].token = 0;
    if (candidate.token == 0) return;
    bool valid = RN_Leech_Valid(client, candidate, false);
    if (accepted && valid)
    {
        candidate.end = end;
        g_Leech_Current[client] = candidate;
    }
    RN_Sword_Finish(candidate.token, accepted && valid);
    RN_Knight_SwingFinished(candidate.token, accepted && valid);
}
