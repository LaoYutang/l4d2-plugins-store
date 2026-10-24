#if defined _rn_melee_included
 #endinput
#endif
#define _rn_melee_included

enum struct MeleeWrite
{
    int ref;
    int entity;
    int client;
    int serial;
    int life;
    int epoch;
    int mapEpoch;
    int token;
    float started;
    float baseNext;
    float ownedNext;
    float baseRate;
    float ownedRate;
}

ArrayList g_Melee_Writes;
MeleeWrite g_Melee_Pending[MAXPLAYERS + 1];
int g_Melee_EventToken[MAXPLAYERS + 1];

#include "rn_melee_heal.sp"
#include "rn_sword_wave.sp"
#include "rn_sword_damage.sp"
#include "rn_sword_collision.sp"

/** 记录按武器EntRef持有，不以可能复用的实体索引作为所有权证明。 */
void RN_Melee_Init()
{
    g_Melee_Writes = new ArrayList(sizeof(MeleeWrite));
}

/** 比較原样保留的float写入，仅撤销仍属于自己的字段。 */
void RN_Melee_Restore(MeleeWrite record)
{
    int weapon = EntRefToEntIndex(record.ref);
    if (weapon <= MaxClients || !IsValidEntity(weapon)) return;
    if (HasEntProp(weapon, Prop_Send, "m_flNextPrimaryAttack") &&
        GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack") == record.ownedNext)
        SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", record.baseNext);
    if (HasEntProp(weapon, Prop_Send, "m_flPlaybackRate") &&
        GetEntPropFloat(weapon, Prop_Send, "m_flPlaybackRate") == record.ownedRate)
        SetEntPropFloat(weapon, Prop_Send, "m_flPlaybackRate", record.baseRate);
}

/** 丢枪或销毁只移除对应武器；销毁事件不读取失效对象。 */
void RN_Melee_ForgetEntity(int entity, bool restore = true)
{
    if (g_Melee_Writes == null) return;
    MeleeWrite record;
    for (int i = g_Melee_Writes.Length - 1; i >= 0; i--)
    {
        g_Melee_Writes.GetArray(i, record, sizeof(record));
        if (record.entity != entity) continue;
        if (restore) RN_Melee_Restore(record);
        g_Melee_Writes.Erase(i);
    }
    for (int client = 1; client <= MaxClients; client++)
    {
        if (g_Melee_Pending[client].entity == entity) g_Melee_Pending[client].serial = 0;
    }
    RN_Leech_ForgetEntity(entity);
    RN_Sword_ForgetEntity(entity);
}

/** 会话结束、换武器或生命变化先清捕获，再恢复该玩家的有效写入。 */
void RN_Melee_StopClient(int client)
{
    if (client < 1 || client > MaxClients || g_Melee_Writes == null) return;
    g_Melee_Pending[client].serial = 0;
    RN_Leech_Stop(client);
    RN_Sword_StopClient(client);
    MeleeWrite record;
    for (int i = g_Melee_Writes.Length - 1; i >= 0; i--)
    {
        g_Melee_Writes.GetArray(i, record, sizeof(record));
        if (record.client != client) continue;
        RN_Melee_Restore(record);
        g_Melee_Writes.Erase(i);
    }
}

/** 重置、换图、热改和卸载统一恢复；不注册逐帧或周期攻速任务。 */
void RN_Melee_Clear()
{
    for (int client = 1; client <= MaxClients; client++) RN_Melee_StopClient(client);
    g_Sword_NextUpdate = 0.0;
}

/** 真人剑客与骑士捕获普通近战；骑士只观察挥击，不修改攻速或发射剑气。 */
int RN_Melee_Weapon(int client)
{
    if (!RN_Config_Enabled() || !RN_Common_Survivor(client) || IsFakeClient(client) ||
        !IsPlayerAlive(client) || RN_Common_Incapacitated(client) || RN_Common_Controlled(client)) return -1;
    PlayerProfile profile;
    if (!RN_Profile_Get(g_Profile_Index[client], profile) || (RN_Profession_MeleeFactor(profile) <= 1.0
        && !RN_Profession_Sword(profile) && !RN_Profession_Is(profile, RN_PROFESSION_KNIGHT))) return -1;
    if (L4D_IsPlayerStaggering(client)) return -1;
    int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (!RN_Common_Melee(weapon) || !HasEntProp(weapon, Prop_Send, "m_hOwnerEntity") ||
        GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity") != client ||
        !HasEntProp(weapon, Prop_Send, "m_flNextPrimaryAttack") ||
        !HasEntProp(weapon, Prop_Send, "m_flPlaybackRate")) return -1;
    return weapon;
}

/** 先到的真实事件和同帧detour共用挥击身份，避免给同一刀生成第二个编号。 */
public Action L4D_OnStartMeleeSwing(int client, bool boolean)
{
    if (client < 1 || client > MaxClients) return Plugin_Continue;
    int weapon = RN_Melee_Weapon(client);
    if (weapon > MaxClients && g_Melee_EventToken[client] != 0
        && g_Melee_EventToken[client] == g_Leech_Current[client].token
        && g_Leech_Current[client].identity.started == GetGameTime()
        && RN_Leech_Valid(client, g_Leech_Current[client], false))
    {
        g_Melee_Pending[client] = g_Leech_Current[client].identity;
        return Plugin_Continue;
    }
    g_Melee_EventToken[client] = 0;
    RN_Leech_Finish(client, false);
    g_Melee_Pending[client].serial = 0;
    if (weapon <= MaxClients) return Plugin_Continue;
    RN_Melee_Capture(client, weapon);
    return Plugin_Continue;
}

/** 引擎bool并非主攻击标记，两种取值共用同一个完整武器身份快照。 */
void RN_Melee_Capture(int client, int weapon)
{
    MeleeWrite capture;
    capture.ref = EntIndexToEntRef(weapon);
    capture.entity = weapon;
    capture.client = client;
    capture.serial = GetClientSerial(client);
    capture.life = g_Common_Life[client];
    capture.epoch = g_Run_Epoch;
    capture.mapEpoch = g_Run_MapEpoch;
    capture.started = GetGameTime();
    capture.baseNext = GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack");
    g_Melee_Pending[client] = capture;
    RN_Leech_Pre(client, capture);
}

/** post确认引擎推进了正间隔后只除一次倍率，失败尝试与重复回调不累乘。 */
public void L4D_OnStartMeleeSwing_Post(int client, bool boolean)
{
    if (client < 1 || client > MaxClients) return;
    MeleeWrite capture;
    capture = g_Melee_Pending[client];
    g_Melee_Pending[client].serial = 0;
    if (capture.serial == 0) return;
    if (!RN_Common_Client(client) ||
        capture.serial != GetClientSerial(client) || capture.life != g_Common_Life[client] ||
        capture.epoch != g_Run_Epoch || capture.mapEpoch != g_Run_MapEpoch) { RN_Leech_Finish(client, false); return; }
    int weapon = RN_Melee_Weapon(client);
    if (weapon <= MaxClients || EntIndexToEntRef(weapon) != capture.ref) { RN_Leech_Finish(client, false); return; }
    float now = GetGameTime();
    float next = GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack");
    if (!RN_Math_Finite(next) || !RN_Math_Finite(capture.baseNext)) { RN_Leech_Finish(client, false); return; }
    if (next <= now || next <= capture.baseNext)
    {
        RequestFrame(RN_Melee_PendingFrame, g_Leech_Candidate[client].token);
        return;
    }
    RN_Leech_Finish(client, true, next);
    RN_Melee_Apply(capture, next, capture.started, g_Leech_Current[client].token);
    RN_Sword_SyncSwing(client, g_Leech_Current[client].token);
}

/** 下一帧确认迟到的截止时间；真实weapon_fire可提前确认同一候选账本。 */
public void RN_Melee_PendingFrame(any token)
{
    if (token == 0) return;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (g_Leech_Candidate[client].token != token) continue;
        MeleeWrite capture;
        capture = g_Leech_Candidate[client].identity;
        int weapon = RN_Melee_Weapon(client);
        if (!RN_Leech_Valid(client, g_Leech_Candidate[client], false) || weapon <= MaxClients)
            { RN_Leech_Finish(client, false); return; }
        float next = GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack");
        bool accepted = RN_Math_Finite(next) && next > capture.started && next > capture.baseNext;
        RN_Leech_Finish(client, accepted, next);
        if (accepted) RN_Melee_Apply(capture, next, capture.started, token);
        if (accepted) RN_Sword_SyncSwing(client, token);
        return;
    }
}

/** 仅当前成功挥击可应用一次加速，旧剑气的迟到回调不能再次缩短新刀间隔。 */
void RN_Melee_Apply(MeleeWrite capture, float next, float now, int token)
{
    int client = capture.client;
    int weapon = RN_Melee_Weapon(client);
    if (token == 0 || weapon <= MaxClients || EntIndexToEntRef(weapon) != capture.ref
        || token != g_Leech_Current[client].token || !RN_Leech_Valid(client, g_Leech_Current[client], false)) return;
    PlayerProfile profile;
    RN_Profile_Get(g_Profile_Index[client], profile);
    float factor = RN_Profession_MeleeFactor(profile);
    if (factor <= 1.0) return;
    float rate = GetEntPropFloat(weapon, Prop_Send, "m_flPlaybackRate");
    int found = -1;
    MeleeWrite previous;
    for (int i = 0; i < g_Melee_Writes.Length; i++)
    {
        g_Melee_Writes.GetArray(i, previous, sizeof(previous));
        if (previous.ref != capture.ref) continue;
        if (previous.token == token) return;
        found = i;
        if (previous.serial == capture.serial && previous.life == capture.life &&
            previous.epoch == capture.epoch && previous.mapEpoch == capture.mapEpoch && rate == previous.ownedRate)
            rate = previous.baseRate;
        break;
    }
    capture.baseNext = next;
    capture.token = token;
    capture.ownedNext = now + (next - now) / factor;
    capture.baseRate = rate;
    capture.ownedRate = rate * factor;
    if (!RN_Math_Finite(capture.ownedNext) || capture.ownedNext <= now ||
        !RN_Math_Finite(capture.ownedRate) || capture.ownedRate <= 0.0)
    {
        RN_Profession_Warn("近战间隔/动画");
        return;
    }
    if (found < 0) g_Melee_Writes.PushArray(capture, sizeof(capture));
    else g_Melee_Writes.SetArray(found, capture, sizeof(capture));
    SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", capture.ownedNext);
    SetEntPropFloat(weapon, Prop_Send, "m_flPlaybackRate", capture.ownedRate);
}

/** 被其他插件阻止的挥击丢弃pre捕获，不对未成功攻击写入属性。 */
public void L4D_OnStartMeleeSwing_PostHandled(int client, bool boolean)
{
    if (client > 0 && client <= MaxClients)
    {
        g_Melee_Pending[client].serial = 0;
        RN_Leech_Finish(client, false);
    }
}

/** 换出武器及时恢复旧武器，个人加成不随实体流入其他玩家。 */
public void RN_Melee_OnSwitch(int client, int weapon) { RN_Melee_StopClient(client); }

/** 掉落武器撤销仍由本插件持有的字段，外部已修改的值保留。 */
public void RN_Melee_OnDrop(int client, int weapon) { RN_Melee_ForgetEntity(weapon); }

/** 新拥有者拾取时清除旧拥有者登记，实际能力等待新拥有者成功挥击。 */
public void RN_Melee_OnEquip(int client, int weapon) { RN_Melee_ForgetEntity(weapon); }
