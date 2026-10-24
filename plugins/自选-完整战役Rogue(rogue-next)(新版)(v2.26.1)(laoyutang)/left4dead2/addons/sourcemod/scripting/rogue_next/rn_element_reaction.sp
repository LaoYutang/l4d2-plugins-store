#if defined _rn_element_reaction_included
 #endinput
#endif
#define _rn_element_reaction_included

int g_Element_Sprite;

/** 初始化无句柄的命中任务队列；取消后已排队的帧回调安全空返。 */
void RN_Element_Init()
{
    g_Element_Hits = new ArrayList(sizeof(RN_ElementHit));
    g_Element_Captures = new ArrayList(sizeof(RN_ElementHit));
    RN_ElementShot_Clear();
}

/** 每图准备原版爆炸素材，临时实体只显示视觉/声音，不自带伤害。 */
void RN_Element_MapStart()
{
    RN_Knight_Clear();
    g_Element_Captures.Clear();
    RN_ElementShot_Clear();
    RN_Explosive_Clear();
    g_FX_NPCDeaths.Clear();
    g_Element_Sprite = PrecacheModel("sprites/zerogxplode.spr", true);
    RN_Electric_MapStart();
}

/** 按单调ID查询队列，合并命中和旧帧回调共用；已取消任务安全空返。 */
int RN_Element_Find(int id)
{
    if (id < 1 || g_Element_Hits == null) return -1;
    RN_ElementHit hit;
    for (int i = 0; i < g_Element_Hits.Length; i++)
    {
        g_Element_Hits.GetArray(i, hit, sizeof(hit));
        if (hit.id == id) return i;
    }
    return -1;
}

/** 生命周期清理仅取消本玩家未结算的枪械聚合，开枪边界保留上一枪任务。 */
void RN_Element_CancelShots(int client)
{
    if (g_Element_Hits == null || !RN_Common_Client(client)) return;
    int serial = GetClientSerial(client);
    RN_ElementHit hit;
    for (int i = g_Element_Hits.Length - 1; i >= 0; i--)
    {
        g_Element_Hits.GetArray(i, hit, sizeof(hit));
        if (hit.ownerSerial == serial && hit.shotKey[0] != '\0') g_Element_Hits.Erase(i);
    }
}

/** 电开关关闭时清除排队命中的电分量，保留同次仍有效的火冰机会。 */
void RN_Element_CancelElectric()
{
    RN_Element_CancelElectricIn(g_Element_Captures);
    RN_Element_CancelElectricIn(g_Element_Hits);
}

/** 捕获与已确认队列同时清电，开关重新启用不能恢复旧机会。 */
void RN_Element_CancelElectricIn(ArrayList records)
{
    RN_ElementHit hit;
    for (int i = 0; i < records.Length; i++)
    {
        records.GetArray(i, hit, sizeof(hit));
        hit.electric = false;
        hit.electricChance = 0.0;
        hit.electricDamage = 0.0;
        hit.electricJumps = 0;
        records.SetArray(i, hit, sizeof(hit));
    }
}

/** 有效正伤害与弹片观察共用资格；持续火、尸体和自身爆炸不进入元素。 */
bool RN_Element_Eligible(int victim, int attacker, float damage, int type)
{
    return RN_Config_Enabled() && damage > 0.0 && RN_Math_Finite(damage)
        && !RN_Burn_Internal(victim, attacker) && !RN_Combat_ContinuousFire(type)
        && RN_Burn_Living(victim) && RN_Common_Survivor(attacker) && IsPlayerAlive(attacker);
}

/** 每颗实际命中弹片保留一次机会；仅观察，不改伤害或产生元素任务。 */
public void RN_Element_OnTrace(int victim, int attacker, int inflictor, float damage,
                               int type, int ammotype, int hitbox, int hitgroup)
{
    if (!RN_Element_Eligible(victim, attacker, damage, type)) return;
    char key[48];
    int id = RN_ElementShot_Pending(victim, attacker, inflictor, -1, type, key, sizeof(key));
    if (key[0] == '\0' || id < 0) return;
    int count = RN_ElementShot_Trace(attacker, key), index = RN_Element_Find(id);
    if (index < 0) return;
    RN_ElementHit hit;
    g_Element_Hits.GetArray(index, hit, sizeof(hit));
    hit.traceHits = count;
    g_Element_Hits.SetArray(index, hit, sizeof(hit));
}

/** 枪械将同枪同目标的机会合并一项；非枪械保留原有逐次概率与元素处理。 */
public void RN_Element_OnDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype,
                                   int weapon, const float force[3], const float position[3])
{
    if (RN_Burn_Internal(victim, attacker) || RN_Combat_ContinuousFire(damagetype)) return;
    RN_ElementHit hit;
    bool captured = RN_Element_TakeCapture(victim, attacker, hit);
    if (damage <= 0.0 || !RN_Math_Finite(damage)) return;
    if (captured)
    {
        if (RN_Element_Owner(hit) == 0 || (!hit.deadAnchor && RN_FX_Resolve(hit.target) != victim)) return;
        if (!hit.deadAnchor && !RN_Burn_Living(victim)) hit.deadAnchor = true;
    }
    else if (!RN_Element_Eligible(victim, attacker, damage, damagetype)) return;
    char key[48];
    int pending;
    if (captured)
    {
        strcopy(key, sizeof(key), hit.shotKey);
        if (key[0] != '\0' && g_ElementShot_Targets[attacker] != null) g_ElementShot_Targets[attacker].GetValue(key, pending);
    }
    else pending = RN_ElementShot_Pending(victim, attacker, inflictor, weapon, damagetype, key, sizeof(key));
    if (pending < 0) return;
    if (pending > 0)
    {
        int index = RN_Element_Find(pending);
        if (index < 0) return;
        g_Element_Hits.GetArray(index, hit, sizeof(hit));
        if (hit.postHits < RN_MAX_INT) hit.postHits++;
        hit.traceHits = RN_ElementShot_Count(attacker, key);
        g_Element_Hits.SetArray(index, hit, sizeof(hit));
        return;
    }
    if (!captured && !RN_Element_Snapshot(victim, attacker, hit, inflictor, weapon, damagetype))
    { RN_ElementShot_Record(attacker, key, -1); return; }
    strcopy(hit.shotKey, sizeof(hit.shotKey), key);
    if (key[0] != '\0')
    {
        if (hit.fireChance <= 0.0 && hit.freezeChance <= 0.0 && hit.electricChance <= 0.0)
        { RN_ElementShot_Record(attacker, key, -1); return; }
        hit.postHits = 1;
        hit.traceHits = RN_ElementShot_Count(attacker, key);
    }
    else
    {
        hit.fire = RN_Combat_Percent(hit.fireChance);
        hit.electric = RN_Combat_Percent(hit.electricChance);
        hit.freeze = RN_Combat_Percent(hit.freezeChance);
        if (!hit.fire && !hit.freeze && !hit.electric) return;
    }
    if (!captured) hit.id = RN_Element_ID();
    g_Element_Hits.PushArray(hit, sizeof(hit));
    RN_ElementShot_Record(attacker, key, hit.id);
    RequestFrame(RN_Element_OnFrame, hit.id);
}

/** 命中机会取真实弹片数与SDK回调数较大者，避免合并丢机会或二者重复计算。 */
void RN_Element_RollShot(RN_ElementHit hit)
{
    int trials = hit.traceHits > hit.postHits ? hit.traceHits : hit.postHits;
    for (int i = 0; i < trials; i++)
    {
        if (!hit.fire) hit.fire = RN_Combat_Percent(hit.fireChance);
        if (!hit.electric) hit.electric = RN_Combat_Percent(hit.electricChance);
        if (!hit.freeze) hit.freeze = RN_Combat_Percent(hit.freezeChance);
        if ((hit.fire || hit.fireChance <= 0.0) && (hit.freeze || hit.freezeChance <= 0.0)
            && (hit.electric || hit.electricChance <= 0.0)) break;
    }
}

/** 读取实际位置；距离使用原点，遮挡射线另抬高到身体位置。 */
void RN_Element_Origin(int entity, float origin[3])
{
    if (entity <= MaxClients) GetClientAbsOrigin(entity, origin);
    else GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
}

/** 仅实体墙/门/固体物体遮挡，不让玩家或感染者挡住范围爆炸。 */
public bool RN_Element_WallFilter(int entity, int contentsMask, any data)
{
    return entity == 0 || (!RN_Common_Client(entity) && !RN_Common_Zombie(entity));
}

/** 身体高度检查固体遮挡，射线句柄始终释放。 */
bool RN_Element_Visible(const float origin[3], const float destination[3])
{
    float start[3], end[3];
    for (int i = 0; i < 3; i++) { start[i] = origin[i]; end[i] = destination[i]; }
    start[2] += 36.0;
    end[2] += 36.0;
    Handle trace = TR_TraceRayFilterEx(start, end, MASK_SOLID, RayType_EndPoint, RN_Element_WallFilter);
    bool visible = !TR_StartSolid(trace) && TR_GetFraction(trace) >= 1.0;
    delete trace;
    return visible;
}

/** 原点燃者爆炸加成与暴击各一次，中心/周边先乘后取整；消费先于SDK。 */
bool RN_Element_Explode(int entity, int trigger)
{
    RN_BurnRecord burn;
    if (!RN_Burn_Get(entity, burn)) return false;
    float origin[3];
    RN_Element_Origin(entity, origin);
    return RN_Element_Blast(entity, trigger, burn, origin);
}

/** 仅记录范围内可见的存活感染者，保留中心不过墙及完整目标身份。 */
void RN_Element_BlastTarget(ArrayList targets, int candidate, int center, const float origin[3], float radius)
{
    if (!RN_Burn_Living(candidate)) return;
    float position[3];
    RN_Element_Origin(candidate, position);
    if (GetVectorDistance(origin, position, true) > radius * radius) return;
    if (candidate != center && !RN_Element_Visible(origin, position)) return;
    RN_FXRecord target;
    RN_FX_Identity(candidate, target);
    targets.PushArray(target, sizeof(target));
}

/** 存活中心消费真实火账；死亡中心只消费本次快照，不读尸体或对尸体追加伤害。 */
bool RN_Element_Blast(int entity, int trigger, RN_BurnRecord burn, const float origin[3])
{
    if (RN_Config_Int(RN_CVAR_ELEMENT_EXPLOSION_ENABLE) == 0) return false;
    PlayerProfile triggerProfile;
    RN_Combat_Profile(trigger, triggerProfile);
    float radius = RN_Profession_ExplosionRadius(triggerProfile);
    if (radius <= 0.0) return false;
    float splashFactor = RN_Config_Float(RN_CVAR_ELEMENT_EXPLOSION_SPLASH_FACTOR);
    if (RN_Burn_Owner(burn) == 0 || burn.target.runEpoch != g_Run_Epoch || burn.target.mapEpoch != g_Run_MapEpoch
        || burn.end <= GetTickedTime()) return false;
    ArrayList targets = new ArrayList(sizeof(RN_FXRecord));
    for (int candidate = 1; candidate <= MaxClients; candidate++) RN_Element_BlastTarget(targets, candidate, entity, origin, radius);
    int infected = FindEntityByClassname(-1, "infected"), witch = FindEntityByClassname(-1, "witch");
    while (infected != -1 || witch != -1)
    {
        bool commonFirst = infected != -1 && (witch == -1 || infected < witch);
        int candidate = commonFirst ? infected : witch;
        RN_Element_BlastTarget(targets, candidate, entity, origin, radius);
        if (commonFirst) infected = FindEntityByClassname(infected, "infected");
        else witch = FindEntityByClassname(witch, "witch");
    }
    int owner = RN_Burn_Owner(burn);
    PlayerProfile ownerProfile;
    RN_Combat_Profile(owner, ownerProfile);
    bool critical = false;
    float criticalFactor = RN_Config_Int(RN_CVAR_ELEMENT_EXPLOSION_CRIT_ENABLE) != 0
        ? RN_Combat_CriticalFactor(ownerProfile, critical) : 1.0;
    float damageFactor = criticalFactor * RN_Stats_Get(ownerProfile, RN_STAT_EXPLOSION_DAMAGE);
    float targetBound = burn.targetBranch == RN_BRANCH_DEATH ? 2.0 : 1.0;
    float due, remaining;
    if (entity > 0)
    {
        if (!RN_Burn_Consume(entity, burn, due, remaining, damageFactor * targetBound)) { delete targets; return false; }
    }
    else
    {
        remaining = burn.dps * (burn.end - GetTickedTime());
        float total = remaining * damageFactor * targetBound;
        if (!RN_Math_Finite(remaining) || remaining < 0.0 || !RN_Math_Finite(damageFactor) || damageFactor < 0.0
            || !RN_Math_Finite(total) || total >= RN_INT_FLOAT_LIMIT) { delete targets; return false; }
    }
    float resistance = RN_Disaster_DamageFactor(true);
    float centerDamage = entity > 0 ? float(RoundToNearest((due + remaining) * damageFactor * resistance)) : 0.0;
    float splashDamage = float(RoundToNearest(remaining * splashFactor * damageFactor * resistance));
    if (RN_Config_Int(RN_CVAR_DEBUG) != 0)
        LogToFileEx(g_Burn_Log, "[Rogue] consume ref=%d version=%d owner=%d due=%.3f remaining=%.3f splash_factor=%.3f splash=%.0f radius=%.1f targets=%d critical=%d crit_factor=%.3f",
            burn.target.ref, burn.version, burn.ownerSerial, due, remaining, splashFactor, splashDamage, radius, targets.Length, critical, criticalFactor);
    if (entity > 0) RN_FX_Forget(entity);
    owner = RN_Burn_Owner(burn);
    if (entity > 0 && RN_Config_Enabled() && owner > 0 && RN_FX_Resolve(burn.target) == entity)
        RN_Burn_Damage(entity, owner, centerDamage, true, RN_ADDED_SETTLED_ELEMENT, burn.targetBranch);
    for (int i = 0; i < targets.Length; i++)
    {
        owner = RN_Burn_Owner(burn);
        if (!RN_Config_Enabled() || owner == 0 || g_Run_Epoch != burn.target.runEpoch || g_Run_MapEpoch != burn.target.mapEpoch) break;
        RN_FXRecord target;
        targets.GetArray(i, target, sizeof(target));
        if (target.ref == burn.target.ref) continue;
        int victim = RN_FX_Resolve(target);
        if (victim > 0) RN_Burn_Damage(victim, owner, splashDamage, true, RN_ADDED_SETTLED_ELEMENT, burn.targetBranch);
    }
    delete targets;
    if (RN_Config_Enabled() && g_Run_Epoch == burn.target.runEpoch && g_Run_MapEpoch == burn.target.mapEpoch && g_Element_Sprite > 0)
    {
        float visual[3];
        for (int axis = 0; axis < 3; axis++) visual[axis] = origin[axis];
        visual[2] += 30.0;
        TE_SetupExplosion(visual, g_Element_Sprite, 0.4, 15, 0, 0, 0);
        TE_SendToAll();
    }
    return true;
}

/** 任务先出队，固定火、电、冰顺序；电链先捕获火焰，冰最后消费并爆炸。 */
public void RN_Element_OnFrame(any id)
{
    int index = RN_Element_Find(id);
    if (index < 0) return;
    RN_ElementHit hit;
    g_Element_Hits.GetArray(index, hit, sizeof(hit));
    g_Element_Hits.Erase(index);
    RN_ElementShot_Complete(hit.ownerSerial, hit.shotKey, hit.id);
    int owner = RN_Element_Owner(hit);
    if (owner == 0) return;
    int victim = RN_FX_Resolve(hit.target);
    if (!hit.deadAnchor && victim < 1) return;
    if (hit.shotKey[0] != '\0') RN_Element_RollShot(hit);
    if (RN_Config_Int(RN_CVAR_DEBUG) != 0)
        LogToFileEx(g_Burn_Log, "[Rogue] element_result id=%d ref=%d traces=%d posts=%d fire=%d electric=%d ice=%d dead=%d", hit.id, hit.target.ref, hit.traceHits, hit.postHits, hit.fire, hit.electric, hit.freeze, hit.deadAnchor);
    if (!hit.fire && !hit.freeze && !hit.electric) return;
    bool living = !hit.deadAnchor && victim > 0 && RN_Burn_Living(victim);
    bool frozen = living ? RN_FX_Frozen(victim) : hit.frozen;
    if (living)
    {
        RN_Element_Origin(victim, hit.origin);
        bool ignited = !hit.fire || RN_Burn_Start(victim, owner, hit.dps, hit.fireDuration, false, hit.targetBranch);
        if (RN_Element_Owner(hit) == 0) return;
        living = RN_FX_Resolve(hit.target) == victim && RN_Burn_Living(victim);
        if (!ignited && living) return;
        if (living) hit.hasBurn = RN_Burn_Get(victim, hit.burn);
    }
    if (!living) RN_Element_DeadFire(hit, owner);
    if (hit.electric)
    {
        if (living) RN_Electric_Start(victim, owner, hit.electricDamage, hit.electricJumps, hit.thunder, hit.targetBranch);
        else RN_Electric_StartDead(hit, owner);
    }
    if (RN_Element_Owner(hit) == 0) return;
    living = living && RN_FX_Resolve(hit.target) == victim && RN_Burn_Living(victim);
    if (hit.freeze || (hit.fire && frozen))
    {
        if (living && RN_Element_Explode(victim, owner)) return;
        if (!living && hit.hasBurn) RN_Element_Blast(0, owner, hit.burn, hit.origin);
    }
    if (hit.freeze && living)
        RN_FX_Freeze(victim, hit.freezeDuration);
}

/** 正式死亡保留命中事实，再登记NPC生命结束并恢复当前对象的冻结与颜色。 */
void RN_Element_Death(int entity)
{
    if (entity < 1) return;
    RN_Element_MarkDead(g_Element_Captures, entity);
    RN_Element_MarkDead(g_Element_Hits, entity);
    RN_FX_NPCDeath(entity);
    RN_Element_Forget(entity);
}

/** 个体清理覆盖目标与拥有者；死亡目标的命中事实保留，不保留其实体状态。 */
void RN_Element_Forget(int entity, bool restore = true)
{
    if (entity < 1) return;
    RN_Knight_Forget(entity);
    RN_ElementShot_ResetClient(entity);
    RN_Electric_Forget(entity);
    RN_Explosive_Forget(entity);
    RN_Burn_Forget(entity, restore);
    RN_FX_Forget(entity, restore);
    int ref = EntIndexToEntRef(entity);
    int serial = RN_Common_Client(entity) ? GetClientSerial(entity) : 0;
    RN_Element_ForgetRecords(g_Element_Hits, entity, ref, serial);
    RN_Element_ForgetRecords(g_Element_Captures, entity, ref, serial);
}

/** 清档/关闭/换图先取消命中与灼烧，再恢复自身冻结和发光。 */
void RN_Element_Clear()
{
    RN_Knight_Clear();
    RN_ElementShot_Clear();
    RN_Explosive_Clear();
    g_Element_Hits.Clear();
    g_Element_Captures.Clear();
    RN_Electric_Clear();
    RN_Burn_Clear();
    RN_FX_Clear();
}
