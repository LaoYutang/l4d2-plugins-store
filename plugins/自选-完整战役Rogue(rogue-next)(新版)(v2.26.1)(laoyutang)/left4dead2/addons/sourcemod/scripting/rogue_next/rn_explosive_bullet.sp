#if defined _rn_explosive_bullet_included
 #endinput
#endif
#define _rn_explosive_bullet_included

/** 成功命中的爆炸固定位置与伤害，主目标死亡/销毁不使爆炸丢失。 */
enum struct RN_ExplosiveHit
{
    int id;
    int centerRef;
    int ownerSerial;
    int ownerLife;
    int profileIndex;
    int run;
    int map;
    float origin[3];
    float damage;
    float radius;
}
ArrayList g_Explosive_Hits;
int g_Explosive_NextID;

/** 初始化一次性帧任务；队列本身不创建定时器或引擎爆炸伤害实体。 */
void RN_Explosive_Init()
{
    g_Explosive_Hits = new ArrayList(sizeof(RN_ExplosiveHit));
}

/** 清档/停用取消未兑现命中，已有RequestFrame安全空返。 */
void RN_Explosive_Clear()
{
    if (g_Explosive_Hits != null) g_Explosive_Hits.Clear();
}

/** 只取消该会话拥有的任务，命中目标死亡不能误取消已确认的爆炸。 */
void RN_Explosive_Forget(int client)
{
    if (g_Explosive_Hits == null || !RN_Common_Client(client)) return;
    int serial = GetClientSerial(client);
    RN_ExplosiveHit hit;
    for (int i = g_Explosive_Hits.Length - 1; i >= 0; i--)
    {
        g_Explosive_Hits.GetArray(i, hit, sizeof(hit));
        if (hit.ownerSerial == serial) g_Explosive_Hits.Erase(i);
    }
}

/** 逐个SDK调用前复核会话/生命/档案和职业，不让旧队列影响接管者。 */
int RN_Explosive_Owner(RN_ExplosiveHit hit)
{
    int client = GetClientFromSerial(hit.ownerSerial);
    if (!RN_Config_Enabled() || hit.run != g_Run_Epoch || hit.map != g_Run_MapEpoch ||
        !RN_Common_Survivor(client) || IsFakeClient(client) || !IsPlayerAlive(client) ||
        g_Common_Life[client] != hit.ownerLife || g_Profile_Index[client] != hit.profileIndex ||
        RN_Config_Float(RN_CVAR_EXPLOSIVE_BULLET_RADIUS) <= 0.0) return 0;
    PlayerProfile profile;
    return RN_Profile_Get(hit.profileIndex, profile) && RN_Stats_Get(profile, RN_STAT_EXPLOSIVE_BULLET) > 0.0 ? client : 0;
}

/** 使用完整SDK post武器与已结算伤害，只有四类狙的有效命中进行一次抽样。 */
public void RN_Explosive_OnDamagePost(int victim, int attacker, int inflictor, float damage,
    int damagetype, int weapon, const float force[3], const float position[3])
{
    if (!RN_Config_Enabled() || damage <= 0.0 || !RN_Math_Finite(damage) ||
        RN_Burn_Internal(victim, attacker) || !RN_Common_Survivor(attacker) ||
        IsFakeClient(attacker) || !IsPlayerAlive(attacker) ||
        (!RN_Common_Infected(victim) && !RN_Common_Zombie(victim))) return;
    PlayerProfile profile;
    RN_Combat_Profile(attacker, profile);
    float chance = RN_Stats_Get(profile, RN_STAT_EXPLOSIVE_BULLET);
    float radius = RN_Stats_ExplosionRadius(profile, RN_Config_Float(RN_CVAR_EXPLOSIVE_BULLET_RADIUS));
    if (chance <= 0.0 || radius <= 0.0) return;
    int index = RN_Profession_GunIndex(attacker, inflictor, weapon, damagetype);
    if (index < 12 || index > 15) return;
    if (RN_Common_Infected(victim) && GetEntProp(victim, Prop_Send, "m_isGhost") != 0) return;
    float explosionDamage = damage * RN_Stats_Get(profile, RN_STAT_EXPLOSION_DAMAGE);
    if (!RN_Math_Finite(explosionDamage) || explosionDamage >= RN_INT_FLOAT_LIMIT)
    {
        LogError("[rogue-next] 爆裂子弹伤害不可表达，未建立爆炸：victim=%d attacker=%d。", victim, attacker);
        return;
    }
    if (!RN_Combat_Percent(chance)) return;
    if (g_Explosive_NextID == RN_MAX_INT) { SetFailState("爆裂子弹代次耗尽，请重载Rogue。"); return; }
    RN_ExplosiveHit hit;
    hit.id = ++g_Explosive_NextID;
    hit.centerRef = EntIndexToEntRef(victim);
    hit.ownerSerial = GetClientSerial(attacker);
    hit.ownerLife = g_Common_Life[attacker];
    hit.profileIndex = g_Profile_Index[attacker];
    hit.run = g_Run_Epoch;
    hit.map = g_Run_MapEpoch;
    hit.damage = explosionDamage;
    hit.radius = radius;
    RN_Element_Origin(victim, hit.origin);
    for (int axis = 0; axis < 3; axis++)
        if (!RN_Math_Finite(hit.origin[axis])) return;
    g_Explosive_Hits.PushArray(hit, sizeof(hit));
    RequestFrame(RN_Explosive_OnFrame, hit.id);
}

/** 一次成功爆炸仅扫描一次；范围目标先固定身份，主目标与墙后目标排除。 */
public void RN_Explosive_OnFrame(any id)
{
    RN_ExplosiveHit hit;
    bool found;
    for (int i = 0; i < g_Explosive_Hits.Length; i++)
    {
        g_Explosive_Hits.GetArray(i, hit, sizeof(hit));
        if (hit.id != id) continue;
        g_Explosive_Hits.Erase(i);
        found = true;
        break;
    }
    if (!found || RN_Explosive_Owner(hit) == 0) return;
    ArrayList targets = new ArrayList(sizeof(RN_FXRecord));
    int maximum = GetMaxEntities();
    for (int candidate = 1; candidate < maximum; candidate++)
    {
        if (!RN_Burn_Living(candidate) || EntIndexToEntRef(candidate) == hit.centerRef) continue;
        float destination[3];
        RN_Element_Origin(candidate, destination);
        if (GetVectorDistance(hit.origin, destination, true) > hit.radius * hit.radius ||
            !RN_Element_Visible(hit.origin, destination)) continue;
        RN_FXRecord target;
        RN_FX_Identity(candidate, target);
        targets.PushArray(target, sizeof(target));
    }
    if (RN_Config_Int(RN_CVAR_DEBUG) != 0)
        LogToFileEx(g_Burn_Log, "[Rogue] explosive id=%d center=%d owner=%d damage=%.3f radius=%.1f targets=%d run=%d map=%d",
            hit.id, hit.centerRef, hit.ownerSerial, hit.damage, hit.radius, targets.Length, hit.run, hit.map);
    for (int i = 0; i < targets.Length; i++)
    {
        int owner = RN_Explosive_Owner(hit);
        if (owner == 0) break;
        RN_FXRecord target;
        targets.GetArray(i, target, sizeof(target));
        int victim = RN_FX_Resolve(target);
        // 复用已结算追加伤害的作用域：不二次增伤/暴击/抽元素，不产生连锁或物理推力。
        if (victim > 0) RN_Burn_Damage(victim, owner, hit.damage, true, RN_ADDED_SETTLED_PHYSICAL);
    }
    delete targets;
    if (RN_Explosive_Owner(hit) > 0 && g_Element_Sprite > 0)
    {
        hit.origin[2] += 30.0;
        TE_SetupExplosion(hit.origin, g_Element_Sprite, 0.4, 15, 0, 0, 0);
        TE_SendToAll();
    }
}
