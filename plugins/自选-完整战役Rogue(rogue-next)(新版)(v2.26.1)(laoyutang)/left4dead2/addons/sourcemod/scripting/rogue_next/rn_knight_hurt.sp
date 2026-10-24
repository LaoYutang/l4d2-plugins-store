#if defined _rn_knight_hurt_included
 #endinput
#endif
#define _rn_knight_hurt_included

/** 同步受伤栈保存扣血前状态，父调用扣除嵌套子调用已消耗的生命。 */
enum struct RN_KnightHurt
{
    int client;
    RN_KnightIdentity owner;
    int neverFallUsed;
    float time;
    float health;
    float spent;
    bool eligible;
}
enum struct RN_KnightBlast
{
    int id;
    RN_KnightIdentity owner;
    float origin[3];
    float damage;
    float radius;
}
ArrayList g_Knight_Hurts;
ArrayList g_Knight_Blasts;
int g_Knight_BlastID;
ConVar g_Knight_TempDecay;

/** 受伤账本独立于排行开关；原生临时血衰减率仅用于排除自然流失。 */
void RN_Knight_HurtInit()
{
    delete g_Knight_Hurts;
    delete g_Knight_Blasts;
    g_Knight_Hurts = new ArrayList(sizeof(RN_KnightHurt));
    g_Knight_Blasts = new ArrayList(sizeof(RN_KnightBlast));
    g_Knight_TempDecay = FindConVar("pain_pills_decay_rate");
}

/** 同一次引擎调用的临时血统一在捕获时刻计算，时间推进本身不算受伤。 */
float RN_Knight_Temporary(int client, float at)
{
    float buffer = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
    float elapsed = at - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime");
    float decay = g_Knight_TempDecay != null ? g_Knight_TempDecay.FloatValue : 0.27;
    if (elapsed > 0.0 && decay > 0.0) buffer -= elapsed * decay;
    return buffer > 0.0 ? buffer : 0.0;
}

/** 酸火不要求敌方归属；燃烧弹仍属于枪械友伤，其他环境扣血不接受。 */
bool RN_Knight_HurtSource(int attacker, int inflictor, int type)
{
    if ((type & (DMG_BULLET | DMG_BUCKSHOT)) != 0) return false;
    if (RN_Combat_ContinuousFire(type)) return true;
    if ((type & DMG_ACID) != 0) return true;
    // L4D2原生酸液使用能量束+辐射，可另带无物理推力标记；不依赖吐酸者存活。
    if ((type & ~DMG_PREVENT_PHYSICS_FORCE) == (DMG_ENERGYBEAM | DMG_RADIATION)) return true;
    if (inflictor > MaxClients && IsValidEntity(inflictor))
    {
        char classname[64];
        GetEntityClassname(inflictor, classname, sizeof(classname));
        if (StrEqual(classname, "insect_swarm") || StrEqual(classname, "spitter_projectile")) return true;
    }
    return RN_Common_Infected(attacker) || RN_Common_Zombie(attacker);
}

/** 在完整伤害入口捕获生还者血量，不能假定扣血一定发生在Alive子调用内。 */
public Action RN_Knight_HurtPre(int victim, int &attacker, int &inflictor, float &damage,
    int &type, int &weapon, float force[3], float position[3])
{
    PlayerProfile profile;
    if (g_Knight_Hurts == null || !RN_Knight_Current(victim, profile)) return Plugin_Continue;
    RN_KnightHurt hit;
    hit.client = victim;
    RN_Knight_Capture(victim, profile, hit.owner);
    hit.time = GetGameTime();
    hit.health = float(GetEntProp(victim, Prop_Data, "m_iHealth")) + RN_Knight_Temporary(victim, hit.time);
    hit.neverFallUsed = profile.neverFallUsed;
    hit.eligible = damage > 0.0 && RN_Math_Finite(damage)
        && (RN_Knight_HurtSource(attacker, inflictor, type)
            || RN_BranchKnight_TransferredHurt(victim, attacker, inflictor, type, weapon))
        && !RN_Combat_Protected(victim) && !RN_Burn_Internal(victim, attacker);
    g_Knight_Hurts.PushArray(hit, sizeof(hit));
    return Plugin_Continue;
}

/** 完整伤害返回后核对实血/临时血；无效来源入栈排除嵌套归属，读档不计数。 */
public void RN_Knight_HurtPost(int victim, int attacker, int inflictor, float damage, int type)
{
    if (g_Knight_Hurts == null) return;
    RN_KnightHurt hit;
    for (int i = g_Knight_Hurts.Length - 1; i >= 0; i--)
    {
        g_Knight_Hurts.GetArray(i, hit, sizeof(hit));
        if (hit.client != victim) continue;
        g_Knight_Hurts.Erase(i);
        if (RN_Knight_Owner(hit.owner) != victim)
        {
            // 旧回调不能清理已经建立的新身份；同一身份倒地时才立即清空。
            if (RN_Common_Client(victim) && hit.owner.serial == GetClientSerial(victim) && hit.owner.life == g_Common_Life[victim]
                && hit.owner.generation == g_Knight_Generation[victim]) RN_Knight_Forget(victim);
            return;
        }
        float after = float(GetEntProp(victim, Prop_Data, "m_iHealth")) + RN_Knight_Temporary(victim, hit.time);
        float lost = hit.health > after ? hit.health - after : 0.0;
        RN_KnightHurt parent;
        for (int j = i - 1; j >= 0; j--)
        {
            g_Knight_Hurts.GetArray(j, parent, sizeof(parent));
            if (parent.client != victim || parent.owner.serial != hit.owner.serial
                || parent.owner.life != hit.owner.life || parent.owner.generation != hit.owner.generation) continue;
            parent.spent += lost;
            g_Knight_Hurts.SetArray(j, parent, sizeof(parent));
            break;
        }
        PlayerProfile profile;
        bool effective = hit.eligible && damage > 0.0 && RN_Math_Finite(damage) && lost > hit.spent
            && RN_Knight_Current(victim, profile) && profile.neverFallUsed == hit.neverFallUsed
            && !RN_Combat_Protected(victim);
        if (RN_Config_Int(RN_CVAR_DEBUG) != 0)
            LogMessage("[rogue-next] KNIGHT_HURT client=%d attacker=%d source=%d type=%d damage=%.3f before=%.3f after=%.3f nested=%.3f effective=%d",
                victim, attacker, inflictor, type, damage, hit.health, after, hit.spent, effective);
        if (!effective) return;
        RN_Knight_Hurt(victim, profile);
        if (RN_Config_Int(RN_CVAR_DEBUG) != 0)
            LogMessage("[rogue-next] KNIGHT_COUNTER client=%d hits=%d threshold=%d nextCount=%.3f healUntil=%.3f",
                victim, g_Knight_State[victim].hits, RN_Knight_Hits(profile),
                g_Knight_State[victim].nextCount, g_Knight_State[victim].healUntil);
        return;
    }
}

/** 每次有效掉血先刷新治疗；爆发后仍只按受伤计数间隔累计下一轮。 */
void RN_Knight_Hurt(int client, PlayerProfile profile)
{
    if (RN_Knight_Owner(g_Knight_State[client].owner) != client)
    {
        RN_KnightState empty;
        g_Knight_State[client] = empty;
        RN_Knight_Capture(client, profile, g_Knight_State[client].owner);
    }
    float now = GetTickedTime();
    if (RN_Knight_HealRatio(profile) > 0.0)
    {
        if (g_Knight_State[client].healUntil <= now)
        {
            // 两个治疗窗口之间的尾段保留到下一次调度，受伤回调本身不直接写血。
            if (g_Knight_State[client].healUntil > g_Knight_State[client].healPaidThrough)
                g_Knight_State[client].healCarry = RN_Knight_HealAmount(client, profile,
                    g_Knight_State[client].healUntil - g_Knight_State[client].healPaidThrough,
                    g_Knight_State[client].healCarry);
            g_Knight_State[client].healPaidThrough = now;
            if (g_Knight_State[client].healUntil <= 0.0) g_Knight_State[client].healNext = now + 1.0;
        }
        g_Knight_State[client].healUntil = now + RN_Config_Float(RN_CVAR_PAIN_PLEASURE_DURATION);
    }
    if (now < g_Knight_State[client].nextCount) return;
    g_Knight_State[client].nextCount = now + RN_Config_Float(RN_CVAR_KNIGHT_HIT_INTERVAL);
    if (++g_Knight_State[client].hits < RN_Knight_Hits(profile)) return;
    g_Knight_State[client].hits = 0;
    if (g_Knight_BlastID == RN_MAX_INT) { RN_Profession_Warn("爆发编号"); return; }
    RN_KnightBlast blast;
    blast.id = ++g_Knight_BlastID;
    blast.owner = g_Knight_State[client].owner;
    GetClientAbsOrigin(client, blast.origin);
    blast.damage = RN_Knight_BurstDamage(profile, GetEntProp(client, Prop_Data, "m_iMaxHealth"))
        * RN_Branch_SourceFactor(client) * RN_Disaster_DamageFactor(false);
    blast.radius = RN_Knight_Radius(profile);
    if (!RN_Math_Finite(blast.damage) || blast.damage >= RN_INT_FLOAT_LIMIT) { RN_Profession_Warn("受难爆发"); return; }
    g_Knight_Blasts.PushArray(blast, sizeof(blast));
    RequestFrame(RN_Knight_BlastFrame, blast.id);
}

/** 范围枚举仅遍历玩家、普感和女巫；沿用可见性与完整目标身份。 */
void RN_Knight_BlastTargets(ArrayList targets, RN_KnightBlast blast)
{
    for (int client = 1; client <= MaxClients; client++)
        RN_Element_BlastTarget(targets, client, 0, blast.origin, blast.radius);
    int common = FindEntityByClassname(-1, "infected"), witch = FindEntityByClassname(-1, "witch");
    while (common != -1 || witch != -1)
    {
        bool first = common != -1 && (witch == -1 || common < witch);
        int candidate = first ? common : witch;
        RN_Element_BlastTarget(targets, candidate, 0, blast.origin, blast.radius);
        if (first) common = FindEntityByClassname(common, "infected");
        else witch = FindEntityByClassname(witch, "witch");
    }
}

/** 先消费队列再调用SDK；爆炸不会反复进入骑士附伤或元素链。 */
public void RN_Knight_BlastFrame(any id)
{
    RN_KnightBlast blast;
    int found = -1;
    for (int i = 0; i < g_Knight_Blasts.Length; i++)
    {
        g_Knight_Blasts.GetArray(i, blast, sizeof(blast));
        if (blast.id == id) { found = i; break; }
    }
    if (found < 0) return;
    g_Knight_Blasts.Erase(found);
    if (RN_Knight_Owner(blast.owner) == 0 || blast.radius <= 0.0) return;
    ArrayList targets = new ArrayList(sizeof(RN_FXRecord));
    RN_Knight_BlastTargets(targets, blast);
    if (RN_Config_Int(RN_CVAR_DEBUG) != 0)
        LogMessage("[rogue-next] KNIGHT_BURST client=%d targets=%d damage=%.3f radius=%.3f",
            RN_Knight_Owner(blast.owner), targets.Length, blast.damage, blast.radius);
    for (int i = 0; i < targets.Length; i++)
    {
        int owner = RN_Knight_Owner(blast.owner);
        if (owner == 0) break;
        RN_FXRecord target;
        targets.GetArray(i, target, sizeof(target));
        int victim = RN_FX_Resolve(target);
        if (victim > 0) RN_Burn_Damage(victim, owner, blast.damage, true, RN_ADDED_SETTLED_PHYSICAL);
    }
    delete targets;
    if (RN_Knight_Owner(blast.owner) != 0 && g_Element_Sprite > 0)
    {
        blast.origin[2] += 30.0;
        TE_SetupExplosion(blast.origin, g_Element_Sprite, blast.radius / 375.0, 15, 0, 0, 0);
        TE_SendToAll();
    }
}

/** 倒地和挂边立即清空；正常扶起不恢复先前的治疗、计数或待结算任务。 */
public void RN_Knight_OnDisabled(Event event, const char[] name, bool dontBroadcast)
{
    RN_Knight_Forget(GetClientOfUserId(event.GetInt("userid")));
}
