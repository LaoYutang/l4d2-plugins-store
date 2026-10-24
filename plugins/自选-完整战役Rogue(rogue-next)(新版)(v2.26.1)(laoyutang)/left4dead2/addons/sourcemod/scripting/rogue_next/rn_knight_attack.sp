#if defined _rn_knight_attack_included
 #endinput
#endif
#define _rn_knight_attack_included

/** 一枪一目标的独立附伤；射线与伤害回调只取较大次数，不重复相加。 */
enum struct RN_KnightAttack
{
    int id;
    RN_KnightIdentity owner;
    RN_FXRecord target;
    int weapon;
    int swing;
    bool accepted;
    int traces;
    int posts;
    int rejected;
    float damage;
}
enum struct RN_KnightAttackCapture
{
    RN_FXRecord target;
    int id;
    int health;
    int spent;
}
ArrayList g_Knight_Attacks;
ArrayList g_Knight_AttackCaptures;
StringMap g_Knight_ShotTargets[MAXPLAYERS + 1];
StringMap g_Knight_MeleeTargets[MAXPLAYERS + 1];
int g_Knight_ShotTick[MAXPLAYERS + 1];
int g_Knight_SwingToken[MAXPLAYERS + 1];
int g_Knight_AttackID;

/** 射击容器完全独立于元素概率和元素任务完成状态。 */
void RN_Knight_AttackInit()
{
    delete g_Knight_Attacks;
    delete g_Knight_AttackCaptures;
    g_Knight_Attacks = new ArrayList(sizeof(RN_KnightAttack));
    g_Knight_AttackCaptures = new ArrayList(sizeof(RN_KnightAttackCapture));
}

/** 生命周期结束释放命中键，旧帧由拥有者代次校验拒绝。 */
void RN_Knight_AttackForget(int client)
{
    delete g_Knight_ShotTargets[client];
    delete g_Knight_MeleeTargets[client];
    g_Knight_ShotTick[client] = -1;
    g_Knight_SwingToken[client] = 0;
}

/** 真正开枪只划分新一枪，不撤销上一枪已经确认的附伤。 */
public void RN_Knight_OnFire(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client < 1 || client > MaxClients) return;
    if (g_Knight_ShotTargets[client] != null) g_Knight_ShotTargets[client].Clear();
    g_Knight_ShotTick[client] = -1;
}

/** 按不复用ID定位本帧短队列，旧回调不能误完成新的同目标攻击。 */
int RN_Knight_AttackFind(int id)
{
    if (id <= 0 || g_Knight_Attacks == null) return -1;
    RN_KnightAttack hit;
    for (int i = 0; i < g_Knight_Attacks.Length; i++)
    {
        g_Knight_Attacks.GetArray(i, hit, sizeof(hit));
        if (hit.id == id) return i;
    }
    return -1;
}

/** 普通近战必须属于真实挥击，尚待确认的候选在下一帧前由post决定成功。 */
int RN_Knight_AttackSwing(int client, int weapon, bool &accepted)
{
    if (RN_Leech_Valid(client, g_Leech_Candidate[client], false)
        && g_Leech_Candidate[client].identity.entity == weapon)
    {
        accepted = false;
        return g_Leech_Candidate[client].token;
    }
    if (RN_Leech_Valid(client, g_Leech_Current[client]) && g_Leech_Current[client].identity.entity == weapon)
    {
        accepted = true;
        return g_Leech_Current[client].token;
    }
    return 0;
}

/** 当前武器命中捕获固定附伤金额；零概率元素、其他附伤和持续火不参与。 */
int RN_Knight_AttackPending(int victim, int attacker, int inflictor, int weapon, float damage, int type)
{
    PlayerProfile profile;
    if (damage < 0.0 || !RN_Math_Finite(damage) || !RN_Knight_Current(attacker, profile)
        || !RN_Burn_Living(victim) || RN_Burn_Internal(victim, attacker)
        || RN_Sword_Internal(victim, attacker, inflictor, weapon, type)) return 0;
    int source = RN_Profession_GunSource(attacker, inflictor, weapon, type), swing;
    bool accepted = true;
    StringMap targets;
    if (RN_Weapons_Index(source) >= 0)
    {
        int tick = GetGameTickCount();
        if (g_Knight_ShotTargets[attacker] == null) g_Knight_ShotTargets[attacker] = new StringMap();
        if (g_Knight_ShotTick[attacker] != tick)
        {
            g_Knight_ShotTargets[attacker].Clear();
            g_Knight_ShotTick[attacker] = tick;
        }
        targets = g_Knight_ShotTargets[attacker];
    }
    else
    {
        // 推击可能携带当前近战武器字段，只有武器实体自身造成的普通挥击才接受。
        source = inflictor;
        if ((type & (DMG_BULLET | DMG_BUCKSHOT | DMG_BLAST | DMG_BURN | DMG_SLOWBURN)) != 0
            || (type & (DMG_SLASH | DMG_CLUB)) == 0 || !RN_Common_Melee(source)) return 0;
        swing = RN_Knight_AttackSwing(attacker, source, accepted);
        if (swing == 0) return 0;
        if (g_Knight_MeleeTargets[attacker] == null) g_Knight_MeleeTargets[attacker] = new StringMap();
        if (g_Knight_SwingToken[attacker] != swing)
        {
            g_Knight_MeleeTargets[attacker].Clear();
            g_Knight_SwingToken[attacker] = swing;
        }
        targets = g_Knight_MeleeTargets[attacker];
    }
    char key[64];
    FormatEx(key, sizeof(key), "%d:%d:%d", EntIndexToEntRef(source), EntIndexToEntRef(victim),
        RN_Common_Client(victim) ? g_Common_Life[victim] : 0);
    int id;
    if (targets.GetValue(key, id)) return id;
    if (g_Knight_AttackID == RN_MAX_INT) { RN_Profession_Warn("附伤编号"); return 0; }
    RN_KnightAttack hit;
    hit.id = ++g_Knight_AttackID;
    RN_Knight_Capture(attacker, profile, hit.owner);
    RN_FX_Identity(victim, hit.target);
    hit.weapon = EntIndexToEntRef(source);
    hit.swing = swing;
    hit.accepted = accepted;
    hit.damage = RN_Knight_AttackDamage(profile, GetEntProp(attacker, Prop_Data, "m_iMaxHealth"))
        * RN_Branch_SourceFactor(attacker);
    if (!RN_Math_Finite(hit.damage) || hit.damage < 0.0 || hit.damage >= RN_INT_FLOAT_LIMIT) return 0;
    targets.SetValue(key, hit.id);
    g_Knight_Attacks.PushArray(hit, sizeof(hit));
    RequestFrame(RN_Knight_AttackFrame, hit.id);
    return hit.id;
}

/** 真实TraceAttack记录弹丸数；仍须Alive回调确认目标实际掉血。 */
public void RN_Knight_OnTrace(int victim, int attacker, int inflictor, float damage,
    int type, int ammo, int hitbox, int hitgroup)
{
    if (damage <= 0.0) return;
    int index = RN_Knight_AttackFind(RN_Knight_AttackPending(victim, attacker, inflictor, -1, damage, type));
    if (index < 0) return;
    RN_KnightAttack hit;
    g_Knight_Attacks.GetArray(index, hit, sizeof(hit));
    if (hit.swing == 0 && hit.traces < RN_MAX_INT) hit.traces++;
    g_Knight_Attacks.SetArray(index, hit, sizeof(hit));
}

/** 记录真实扣血前状态；嵌套非骑士伤害同样入栈，避免父调用重复归属。 */
public Action RN_Knight_AttackAlive(int victim, int &attacker, int &inflictor, float &damage,
    int &type, int &weapon, float force[3], float position[3])
{
    if (g_Knight_AttackCaptures == null || !RN_Config_Enabled() || !RN_Burn_Living(victim)) return Plugin_Continue;
    int id = RN_Knight_AttackPending(victim, attacker, inflictor, weapon, damage, type);
    if (id == 0 && g_Knight_AttackCaptures.Length == 0) return Plugin_Continue;
    RN_KnightAttackCapture capture;
    RN_FX_Identity(victim, capture.target);
    capture.id = id;
    capture.health = GetEntProp(victim, Prop_Data, "m_iHealth");
    g_Knight_AttackCaptures.PushArray(capture, sizeof(capture));
    return Plugin_Continue;
}

/** 后置只确认本层实际损失，正伤参数但未扣血的调用不能触发附伤。 */
public void RN_Knight_AttackAlivePost(int victim, int attacker, int inflictor, float damage, int type)
{
    if (g_Knight_AttackCaptures == null) return;
    RN_KnightAttackCapture capture;
    for (int i = g_Knight_AttackCaptures.Length - 1; i >= 0; i--)
    {
        g_Knight_AttackCaptures.GetArray(i, capture, sizeof(capture));
        if (capture.target.entityIndex != victim) continue;
        g_Knight_AttackCaptures.Erase(i);
        if (RN_FX_Resolve(capture.target) != victim) return;
        int health = GetEntProp(victim, Prop_Data, "m_iHealth");
        if (health < 0) health = 0;
        int lost = capture.health > health ? capture.health - health : 0;
        RN_KnightAttackCapture parent;
        for (int j = i - 1; j >= 0; j--)
        {
            g_Knight_AttackCaptures.GetArray(j, parent, sizeof(parent));
            if (parent.target.ref != capture.target.ref) continue;
            parent.spent = lost >= parent.health - parent.spent ? parent.health : parent.spent + lost;
            g_Knight_AttackCaptures.SetArray(j, parent, sizeof(parent));
            break;
        }
        int index = RN_Knight_AttackFind(capture.id);
        if (index < 0) return;
        RN_KnightAttack hit;
        g_Knight_Attacks.GetArray(index, hit, sizeof(hit));
        if (damage <= 0.0 || !RN_Math_Finite(damage) || lost <= capture.spent)
        {
            if (hit.rejected < RN_MAX_INT) hit.rejected++;
        }
        else if (hit.posts < RN_MAX_INT) hit.posts++;
        g_Knight_Attacks.SetArray(index, hit, sizeof(hit));
        return;
    }
}

/** 挥击完成只更新同一候选编号，失败挥击不能留下有效附伤。 */
void RN_Knight_SwingFinished(int token, bool accepted)
{
    if (token == 0 || g_Knight_Attacks == null) return;
    RN_KnightAttack hit;
    for (int i = 0; i < g_Knight_Attacks.Length; i++)
    {
        g_Knight_Attacks.GetArray(i, hit, sizeof(hit));
        if (hit.swing != token) continue;
        hit.accepted = accepted;
        g_Knight_Attacks.SetArray(i, hit, sizeof(hit));
    }
}

/** 先出队再执行SDK；主伤害致死、身份失效和无实际扣血均不补伤。 */
public void RN_Knight_AttackFrame(any id)
{
    int index = RN_Knight_AttackFind(id);
    if (index < 0) return;
    RN_KnightAttack hit;
    g_Knight_Attacks.GetArray(index, hit, sizeof(hit));
    g_Knight_Attacks.Erase(index);
    int owner = RN_Knight_Owner(hit.owner), victim = RN_FX_Resolve(hit.target);
    if (owner == 0 || victim < 1 || !RN_Burn_Living(victim) || hit.posts == 0 || !hit.accepted) return;
    int traces = hit.traces > hit.rejected ? hit.traces - hit.rejected : 0;
    int count = hit.swing != 0 ? 1 : (traces > hit.posts ? traces : hit.posts);
    float amount = hit.damage * float(count) * RN_Disaster_DamageFactor(false);
    if (!RN_Math_Finite(amount) || amount >= RN_INT_FLOAT_LIMIT) { RN_Profession_Warn("生命附伤"); return; }
    RN_Burn_Damage(victim, owner, amount, true, RN_ADDED_SETTLED_PHYSICAL);
}

/** SDK钩子幂等安装；生还者只采集受伤，感染者只采集武器附伤。 */
void RN_Knight_Hook(int entity)
{
    SDKUnhook(entity, SDKHook_OnTakeDamageAlive, RN_Knight_AttackAlive);
    SDKHook(entity, SDKHook_OnTakeDamageAlive, RN_Knight_AttackAlive);
    SDKUnhook(entity, SDKHook_OnTakeDamageAlivePost, RN_Knight_AttackAlivePost);
    SDKHook(entity, SDKHook_OnTakeDamageAlivePost, RN_Knight_AttackAlivePost);
    SDKUnhook(entity, SDKHook_TraceAttackPost, RN_Knight_OnTrace);
    SDKHook(entity, SDKHook_TraceAttackPost, RN_Knight_OnTrace);
    if (entity > MaxClients) return;
    SDKUnhook(entity, SDKHook_OnTakeDamage, RN_Knight_HurtPre);
    SDKHook(entity, SDKHook_OnTakeDamage, RN_Knight_HurtPre);
    SDKUnhook(entity, SDKHook_OnTakeDamagePost, RN_Knight_HurtPost);
    SDKHook(entity, SDKHook_OnTakeDamagePost, RN_Knight_HurtPost);
}
