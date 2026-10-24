#if defined _rn_damage_capture_included
 #endinput
#endif
#define _rn_damage_capture_included

/** SDK Alive调用的短期账本；子调用消耗的血量不能再次记给父调用。 */
enum struct RN_DamageHit
{
    int victim;
    int ref;
    int serial;
    int life;
    int attacker;
    int ownerSerial;
    int ownerLife;
    int profile;
    int run;
    int map;
    int health;
    int spent;
    bool positive;
    bool killed;
    bool tank;
}
ArrayList g_Damage_Hits;

/** 队列只保存同步引擎调用，没有定时器、帧任务或逐目标历史记录。 */
void RN_Damage_CaptureInit()
{
    g_Damage_Hits = new ArrayList(sizeof(RN_DamageHit));
}

/** 换图、清档或停用立即丢弃未结算采集，永久累计由独立模块管理。 */
void RN_Damage_CaptureClear()
{
    if (g_Damage_Hits != null) g_Damage_Hits.Clear();
}

/** 只监听已有感染者实体，不修改伤害参数或创建新的伤害调用。 */
void RN_Damage_Hook(int entity)
{
    SDKUnhook(entity, SDKHook_OnTakeDamageAlive, RN_Damage_OnAlive);
    SDKHook(entity, SDKHook_OnTakeDamageAlive, RN_Damage_OnAlive);
    SDKUnhook(entity, SDKHook_OnTakeDamageAlivePost, RN_Damage_OnAlivePost);
    SDKHook(entity, SDKHook_OnTakeDamageAlivePost, RN_Damage_OnAlivePost);
}

/** 实体与客户端生命均匹配才读取结算后血量，索引复用不是原命中。 */
bool RN_Damage_Same(RN_DamageHit hit)
{
    return IsValidEntity(hit.victim) && EntIndexToEntRef(hit.victim) == hit.ref &&
        (hit.victim > MaxClients || (RN_Common_Client(hit.victim) &&
            GetClientSerial(hit.victim) == hit.serial && g_Common_Life[hit.victim] == hit.life));
}

/** 读取实际剩余血量；死亡事件、死亡标志和Tank死亡动画均视为生命结束。 */
bool RN_Damage_Ended(RN_DamageHit hit)
{
    if (hit.killed) return true;
    if (hit.victim <= MaxClients)
        return !IsPlayerAlive(hit.victim) || (hit.tank && GetEntProp(hit.victim, Prop_Send, "m_isIncapacitated") != 0);
    return HasEntProp(hit.victim, Prop_Data, "m_lifeState") && GetEntProp(hit.victim, Prop_Data, "m_lifeState") != 0;
}

/** 从每个父账本扣子调用实血变化，包含未归属的世界/BOT伤害。 */
void RN_Damage_Propagate(RN_DamageHit hit, int spent)
{
    if (spent <= 0) return;
    RN_DamageHit parent;
    for (int index = g_Damage_Hits.Length - 1; index >= 0; index--)
    {
        g_Damage_Hits.GetArray(index, parent, sizeof(parent));
        if (parent.ref != hit.ref || parent.serial != hit.serial || parent.life != hit.life ||
            parent.run != hit.run || parent.map != hit.map) continue;
        parent.spent = spent >= parent.health - parent.spent ? parent.health : parent.spent + spent;
        g_Damage_Hits.SetArray(index, parent, sizeof(parent));
        return;
    }
}

/** 只提交本次调用实际消耗且未被子调用记账的血量，失效身份不能向新玩家转移。 */
void RN_Damage_Finish(RN_DamageHit hit, bool applied, bool removed = false)
{
    if (hit.run != g_Run_Epoch || hit.map != g_Run_MapEpoch || !RN_Config_Enabled() ||
        RN_Config_Int(RN_CVAR_DAMAGE_STATS_ENABLE) == 0) return;
    if ((!removed && !RN_Damage_Same(hit)) || (removed && !hit.killed)) return;
    int remaining = removed || RN_Damage_Ended(hit) ? 0 : GetEntProp(hit.victim, Prop_Data, "m_iHealth");
    if (remaining < 0) remaining = 0;
    int lost = hit.health > remaining ? hit.health - remaining : 0;
    RN_Damage_Propagate(hit, lost);
    int amount = lost > hit.spent ? lost - hit.spent : 0;
    if (!applied || !hit.positive || amount <= 0 || hit.profile < 0 ||
        !RN_Common_Survivor(hit.attacker) || IsFakeClient(hit.attacker) ||
        GetClientSerial(hit.attacker) != hit.ownerSerial || g_Common_Life[hit.attacker] != hit.ownerLife ||
        g_Profile_Index[hit.attacker] != hit.profile) return;
    RN_Damage_Award(hit.profile, amount);
}

/** Alive前保存实血；零伤、BOT和世界的嵌套子调用也须配对，避免归给外层真人。 */
public Action RN_Damage_OnAlive(int victim, int &attacker, int &inflictor, float &damage,
    int &type, int &weapon, float force[3], float position[3])
{
    if (!RN_Config_Enabled() || RN_Config_Int(RN_CVAR_DAMAGE_STATS_ENABLE) == 0 ||
        !RN_Common_ActiveRun() || !RN_Burn_Living(victim)) return Plugin_Continue;
    RN_DamageHit hit;
    hit.victim = victim;
    hit.ref = EntIndexToEntRef(victim);
    if (victim <= MaxClients)
    {
        hit.serial = GetClientSerial(victim); hit.life = g_Common_Life[victim];
        hit.tank = RN_Common_Tank(victim);
    }
    else if (RN_Damage_Ended(hit)) return Plugin_Continue;
    hit.health = GetEntProp(victim, Prop_Data, "m_iHealth");
    if (hit.health <= 0) return Plugin_Continue;
    hit.attacker = attacker;
    hit.profile = -1;
    if (RN_Common_Survivor(attacker) && !IsFakeClient(attacker))
    {
        hit.ownerSerial = GetClientSerial(attacker); hit.ownerLife = g_Common_Life[attacker];
        hit.profile = g_Profile_Index[attacker];
    }
    hit.run = g_Run_Epoch; hit.map = g_Run_MapEpoch;
    hit.positive = damage > 0.0 && RN_Math_Finite(damage);
    g_Damage_Hits.PushArray(hit, sizeof(hit));
    return Plugin_Continue;
}

/** Alive post不依赖目标仍活着；匹配最内层同目标调用，并在提交前先移除记录。 */
public void RN_Damage_OnAlivePost(int victim, int attacker, int inflictor, float damage, int type)
{
    if (g_Damage_Hits == null) return;
    RN_DamageHit hit;
    for (int index = g_Damage_Hits.Length - 1; index >= 0; index--)
    {
        g_Damage_Hits.GetArray(index, hit, sizeof(hit));
        if (hit.victim != victim) continue;
        g_Damage_Hits.Erase(index);
        RN_Damage_Finish(hit, attacker == hit.attacker && damage > 0.0 && RN_Math_Finite(damage));
        return;
    }
}

/** 正式死亡事件标记同步命中，涵盖NPC断头但实血尚未归零的特殊死亡。 */
void RN_Damage_MarkDeath(int entity)
{
    if (g_Damage_Hits == null) return;
    RN_DamageHit hit;
    for (int index = g_Damage_Hits.Length - 1; index >= 0; index--)
    {
        g_Damage_Hits.GetArray(index, hit, sizeof(hit));
        if (hit.victim != entity || !RN_Damage_Same(hit)) continue;
        hit.killed = true;
        g_Damage_Hits.SetArray(index, hit, sizeof(hit));
    }
}

/** 过关边界可发生在死亡回调内，已确认结束生命的命中先兑现一次。 */
void RN_Damage_FlushDeaths()
{
    RN_DamageHit hit;
    for (int index = g_Damage_Hits.Length - 1; index >= 0; index--)
    {
        g_Damage_Hits.GetArray(index, hit, sizeof(hit));
        if (!RN_Damage_Same(hit) || !RN_Damage_Ended(hit)) continue;
        g_Damage_Hits.Erase(index);
        RN_Damage_Finish(hit, true);
    }
}

/** 实体销毁时结束短期账本；明确死亡才记剩余血量，普通移除不伪造输出。 */
void RN_Damage_Destroyed(int entity)
{
    if (g_Damage_Hits == null) return;
    RN_DamageHit hit;
    for (int index = g_Damage_Hits.Length - 1; index >= 0; index--)
    {
        g_Damage_Hits.GetArray(index, hit, sizeof(hit));
        if (hit.victim != entity) continue;
        g_Damage_Hits.Erase(index);
        RN_Damage_Finish(hit, true, true);
    }
}
