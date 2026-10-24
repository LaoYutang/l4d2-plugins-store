#if defined _rn_burn_included
 #endinput
#endif
#define _rn_burn_included

/** 一份灼烧一个账本；身份、时间及倍率均在点燃时快照。 */
enum struct RN_BurnRecord
{
    RN_FXRecord target;
    int ownerSerial;
    int ownerLife;
    int version;
    int flameRef;
    int targetBranch;
    float dps;
    float payloadDps;
    float duration;
    float end;
    float last;
    float carry;
    float debugAt;
}
ArrayList g_Burn_Records;
Handle g_Burn_Timer;
int g_Burn_Version;
int g_Burn_DamageRef;
int g_Burn_DamageOwner;
char g_Burn_Log[PLATFORM_MAX_PATH];

/** 初始化活跃账本及低频游戏时间调度；服务跨图保留，效果不跨图。 */
void RN_Burn_Init()
{
    g_Burn_Records = new ArrayList(sizeof(RN_BurnRecord));
    BuildPath(Path_SM, g_Burn_Log, sizeof(g_Burn_Log), "logs/rogue_next_elements.log");
    g_Burn_Timer = CreateTimer(0.25, RN_Burn_OnTick, _, TIMER_REPEAT);
}

/** 排除死亡、幽灵与Tank死亡动画，NPC共用实血、生命属性及正式死亡记录。 */
bool RN_Burn_Living(int entity)
{
    if (RN_Common_Infected(entity))
        return IsPlayerAlive(entity) && GetEntProp(entity, Prop_Send, "m_isGhost") == 0
            && (!RN_Common_Tank(entity) || !RN_Common_Incapacitated(entity));
    return RN_FX_NPCLiving(entity);
}

/** 使用serial与生命校验伤害拥有者，死亡/转队不继续归因旧火焰。 */
int RN_Burn_Owner(RN_BurnRecord record)
{
    int client = GetClientFromSerial(record.ownerSerial);
    return RN_Common_Survivor(client) && IsPlayerAlive(client) && g_Common_Life[client] == record.ownerLife ? client : 0;
}

/** 根据稳定实体引用定位账本；SDK回调后必须重新查找，不能保留数组索引。 */
int RN_Burn_Find(int ref)
{
    RN_BurnRecord record;
    for (int i = 0; i < g_Burn_Records.Length; i++)
    {
        g_Burn_Records.GetArray(i, record, sizeof(record));
        if (record.target.ref == ref) return i;
    }
    return -1;
}

/** 返回仍有时间、目标与拥有者均有效的一份余额。 */
bool RN_Burn_Get(int entity, RN_BurnRecord record)
{
    int index = RN_Burn_Find(EntIndexToEntRef(entity));
    if (index < 0) return false;
    g_Burn_Records.GetArray(index, record, sizeof(record));
    return RN_FX_Resolve(record.target) == entity && RN_Burn_Living(entity)
        && RN_Burn_Owner(record) > 0 && record.end > GetTickedTime();
}

/** 精确识别当前自身伤害调用；不屏蔽其他目标或普通爆炸武器的伤害。 */
bool RN_Burn_Internal(int victim, int attacker)
{
    return g_Burn_DamageRef != 0 && EntIndexToEntRef(victim) == g_Burn_DamageRef
        && RN_Common_Client(attacker) && GetClientSerial(attacker) == g_Burn_DamageOwner;
}

/** 仅给本次点燃产生的实体火焰补上归属，不抢其他玩家或地图火焰的击杀。 */
int RN_Burn_NativeOwner(int entity, int attacker, int inflictor)
{
    if (RN_Common_Survivor(attacker)) return attacker;
    RN_BurnRecord record;
    if (!RN_Burn_Get(entity, record) || record.flameRef == 0) return attacker;
    int flame = EntRefToEntIndex(record.flameRef);
    return flame > MaxClients && IsValidEntity(flame) && (inflictor == flame || attacker == flame)
        ? RN_Burn_Owner(record) : attacker;
}

/** 正常tick日志每个目标每秒至多一对，爆炸只在一次消费时逐目标记录。 */
bool RN_Burn_DebugDamage(int entity, bool explosion)
{
    if (RN_Config_Int(RN_CVAR_DEBUG) == 0) return false;
    if (explosion) return true;
    int index = RN_Burn_Find(EntIndexToEntRef(entity));
    if (index < 0) return true;
    RN_BurnRecord record;
    g_Burn_Records.GetArray(index, record, sizeof(record));
    if (GetTickedTime() < record.debugAt) return false;
    record.debugAt = GetTickedTime() + 1.0;
    g_Burn_Records.SetArray(index, record, sizeof(record));
    return true;
}

/** 保持有界伤害及零物理推力，允许其他插件伤害钩子但跳过自身二次加成。 */
void RN_Burn_Damage(int entity, int owner, float damage, bool explosion = false,
    RN_AddedDamage source = RN_ADDED_ELEMENT, int targetBranch = -1)
{
    if (source == RN_ADDED_ELEMENT) damage *= RN_Disaster_DamageFactor(true);
    if (source != RN_ADDED_SETTLED_PHYSICAL)
        damage *= RN_Branch_TargetFactor(owner, entity, targetBranch);
    if (!RN_Config_Enabled() || !RN_Burn_Living(entity) || !RN_Common_Survivor(owner)
        || !IsPlayerAlive(owner) || damage <= 0.0) return;
    if (!RN_Math_Finite(damage) || damage >= RN_INT_FLOAT_LIMIT)
    {
        LogToFileEx(g_Burn_Log, "[Rogue] rejected_damage target=%d owner=%d amount=%.3f", entity, owner, damage);
        return;
    }
    int previousRef = g_Burn_DamageRef, previousOwner = g_Burn_DamageOwner;
    g_Burn_DamageRef = EntIndexToEntRef(entity);
    g_Burn_DamageOwner = GetClientSerial(owner);
    bool logging = RN_Burn_DebugDamage(entity, explosion);
    if (logging)
        LogToFileEx(g_Burn_Log, "[Rogue] damage_before ref=%d owner=%d amount=%.3f blast=%d", g_Burn_DamageRef, g_Burn_DamageOwner, damage, explosion);
    // 额外伤害不携带BURN/BLAST，避免原版Tank烧死计时与再次点燃；来源靠作用域识别。
    SDKHooks_TakeDamage(entity, owner, owner, damage,
        DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE, -1, NULL_VECTOR, NULL_VECTOR, false);
    if (logging)
        LogToFileEx(g_Burn_Log, "[Rogue] damage_after ref=%d owner=%d blast=%d", g_Burn_DamageRef, g_Burn_DamageOwner, explosion);
    g_Burn_DamageRef = previousRef;
    g_Burn_DamageOwner = previousOwner;
}

/** 先注销账本，再撤销火焰；清理SDK回调无法重复消费记录。 */
void RN_Burn_Remove(int ref, bool restore = true)
{
    int index = RN_Burn_Find(ref);
    if (index < 0) return;
    RN_BurnRecord record;
    g_Burn_Records.GetArray(index, record, sizeof(record));
    g_Burn_Records.Erase(index);
    int entity = restore ? RN_FX_Resolve(record.target, true) : -1;
    if (entity > 0) RN_FX_Extinguish(entity);
    else
    {
        int fxIndex = RN_FX_Find(ref);
        RN_FXRecord effect;
        if (fxIndex >= 0)
        {
            g_FX_Records.GetArray(fxIndex, effect, sizeof(effect));
            if (effect.serial == record.target.serial && effect.life == record.target.life
                && effect.runEpoch == record.target.runEpoch && effect.mapEpoch == record.target.mapEpoch)
                RN_FX_Remove(fxIndex, false);
        }
    }
}

/** 时间差先入账再扣血；保留不足1点的小数，末段仅舍入一次。 */
bool RN_Burn_Settle(int ref, float now)
{
    int index = RN_Burn_Find(ref);
    if (index < 0) return false;
    RN_BurnRecord record;
    g_Burn_Records.GetArray(index, record, sizeof(record));
    int entity = RN_FX_Resolve(record.target), owner = RN_Burn_Owner(record);
    if (!RN_Config_Enabled() || entity < 1 || !RN_Burn_Living(entity) || owner == 0)
    {
        if (RN_Config_Enabled())
            LogToFileEx(g_Burn_Log, "[Rogue] invalid_identity ref=%d version=%d owner=%d life=%d", ref, record.version, record.ownerSerial, record.ownerLife);
        RN_Burn_Remove(ref);
        return false;
    }
    float stop = now < record.end ? now : record.end;
    if (stop < record.last) return true;
    float accrued = record.carry + record.dps * (stop - record.last);
    if (!RN_Math_Finite(accrued) || accrued >= RN_INT_FLOAT_LIMIT)
    {
        LogToFileEx(g_Burn_Log, "[Rogue] invalid_balance ref=%d version=%d", ref, record.version);
        RN_Burn_Remove(ref);
        return false;
    }
    float payable = float(stop >= record.end ? RoundToNearest(accrued) : RoundToFloor(accrued));
    record.carry = accrued - payable;
    record.last = stop;
    g_Burn_Records.SetArray(index, record, sizeof(record));
    RN_Burn_Damage(entity, owner, payable, false, RN_ADDED_ELEMENT, record.targetBranch);
    index = RN_Burn_Find(ref);
    if (index < 0) return false;
    RN_BurnRecord current;
    g_Burn_Records.GetArray(index, current, sizeof(current));
    return current.version == record.version && RN_FX_Resolve(current.target) == entity
        && RN_Burn_Living(entity) && RN_Burn_Owner(current) > 0;
}

/** 同源按新属性刷新，异源较弱者只续时；旧时间段先结算且不重复叠火。 */
bool RN_Burn_Start(int entity, int owner, float dps, float duration, bool spread = false,
    int targetBranch = -1, float spreadFactor = 1.0)
{
    float payloadDps = dps;
    if (!RN_Math_Finite(spreadFactor) || spreadFactor < 0.0) return false;
    dps *= spreadFactor;
    int branch = targetBranch < 0 ? RN_Branch_Get(owner) : targetBranch;
    float maximum = dps * duration * (branch == RN_BRANCH_DEATH ? 2.0 : 1.0);
    if (!RN_Config_Enabled() || !RN_Burn_Living(entity) || !RN_Common_Survivor(owner) || !IsPlayerAlive(owner)
        || duration <= 0.0 || duration >= RN_INT_FLOAT_LIMIT || dps < 0.0 || !RN_Math_Finite(dps * duration)
        || dps * duration >= RN_INT_FLOAT_LIMIT || !RN_Math_Finite(maximum) || maximum >= RN_INT_FLOAT_LIMIT) return false;
    RN_FXRecord identity;
    RN_FX_Identity(entity, identity);
    int ref = identity.ref, ownerSerial = GetClientSerial(owner), ownerLife = g_Common_Life[owner];
    float now = GetTickedTime();
    int index = RN_Burn_Find(ref);
    RN_BurnRecord existing;
    if (spread && index >= 0 && RN_Burn_Get(entity, existing) && existing.dps > dps) return true;
    if (index >= 0 && !RN_Burn_Settle(ref, now))
    {
        RN_Burn_Remove(ref);
    }
    if (RN_FX_Resolve(identity) != entity || !RN_Burn_Living(entity) || !RN_Common_Survivor(owner)
        || !IsPlayerAlive(owner) || GetClientSerial(owner) != ownerSerial || g_Common_Life[owner] != ownerLife) return false;
    index = RN_Burn_Find(ref);
    RN_BurnRecord record;
    if (index >= 0) g_Burn_Records.GetArray(index, record, sizeof(record));
    else
    {
        record.target = identity;
    }
    if (record.end <= now) record.carry = 0.0;
    if (index < 0 || record.ownerSerial == GetClientSerial(owner) || dps > record.dps
        || (spread && dps == record.dps) || record.end <= now)
    {
        record.ownerSerial = GetClientSerial(owner);
        record.ownerLife = g_Common_Life[owner];
        record.dps = dps;
        record.payloadDps = payloadDps;
        record.targetBranch = branch;
    }
    if (g_Burn_Version == RN_MAX_INT) { SetFailState("灼烧代次耗尽，请重载Rogue。"); return false; }
    record.version = ++g_Burn_Version;
    record.last = now;
    record.duration = duration;
    record.end = now + duration;
    if (index < 0) g_Burn_Records.PushArray(record, sizeof(record));
    else g_Burn_Records.SetArray(index, record, sizeof(record));
    RN_FX_Fire(entity, duration);
    IgniteEntity(entity, duration);
    if (RN_FX_Resolve(identity) != entity || !RN_Burn_Living(entity) || !RN_Common_Survivor(owner)
        || !IsPlayerAlive(owner) || GetClientSerial(owner) != ownerSerial || g_Common_Life[owner] != ownerLife) return false;
    index = RN_Burn_Find(ref);
    RN_BurnRecord current;
    if (index < 0) return false;
    g_Burn_Records.GetArray(index, current, sizeof(current));
    if (current.version != record.version) return false;
    current.flameRef = 0;
    if (HasEntProp(entity, Prop_Send, "m_hEffectEntity"))
    {
        int flame = GetEntPropEnt(entity, Prop_Send, "m_hEffectEntity");
        char classname[32];
        if (flame > MaxClients && IsValidEntity(flame))
        {
            GetEntityClassname(flame, classname, sizeof(classname));
            if (StrEqual(classname, "entityflame")) current.flameRef = EntIndexToEntRef(flame);
        }
    }
    g_Burn_Records.SetArray(index, current, sizeof(current));
    if (RN_Config_Int(RN_CVAR_DEBUG) != 0)
        LogToFileEx(g_Burn_Log, "[Rogue] ignite ref=%d version=%d owner=%d dps=%.3f duration=%.3f", ref, record.version, record.ownerSerial, record.dps, duration);
    return RN_Burn_Owner(current) > 0;
}

/** 消费前快照原余额并核对爆炸加成及暴击后的上界，拒绝不注销余额。 */
bool RN_Burn_Consume(int entity, RN_BurnRecord record, float &due, float &remaining, float damageFactor = 1.0)
{
    if (!RN_Burn_Get(entity, record)) return false;
    float now = GetTickedTime();
    due = record.carry + record.dps * (now - record.last);
    remaining = record.dps * (record.end - now);
    float total = (due + remaining) * damageFactor;
    if (!RN_Math_Finite(due) || !RN_Math_Finite(remaining) || due < 0.0 || remaining < 0.0
        || !RN_Math_Finite(damageFactor) || damageFactor < 0.0 || !RN_Math_Finite(total) || total >= RN_INT_FLOAT_LIMIT)
    {
        LogToFileEx(g_Burn_Log, "[Rogue] rejected_consume ref=%d owner=%d due=%.3f remaining=%.3f factor=%.3f",
            record.target.ref, record.ownerSerial, due, remaining, damageFactor);
        return false;
    }
    int index = RN_Burn_Find(record.target.ref);
    g_Burn_Records.Erase(index);
    return true;
}

/** 生命/实体失效同时清理该目标以及该玩家拥有的全部灼烧。 */
void RN_Burn_Forget(int entity, bool restore = true)
{
    if (entity < 1) return;
    int ref = EntIndexToEntRef(entity);
    int serial = RN_Common_Client(entity) ? GetClientSerial(entity) : 0;
    ArrayList refs = new ArrayList();
    RN_BurnRecord record;
    for (int i = 0; i < g_Burn_Records.Length; i++)
    {
        g_Burn_Records.GetArray(i, record, sizeof(record));
        if (record.target.ref == ref || (!IsValidEntity(entity) && record.target.entityIndex == entity)
            || (serial > 0 && record.ownerSerial == serial)) refs.Push(record.target.ref);
    }
    for (int i = 0; i < refs.Length; i++) RN_Burn_Remove(refs.Get(i), IsValidEntity(entity) && refs.Get(i) == ref ? restore : true);
    delete refs;
}

/** 调度先快照引用；伤害可能同步死亡或清档，遍历不持有会变动的下标。 */
void RN_Burn_Tick()
{
    if (g_Burn_Records.Length == 0) return;
    ArrayList refs = new ArrayList();
    RN_BurnRecord record;
    for (int i = 0; i < g_Burn_Records.Length; i++)
    {
        g_Burn_Records.GetArray(i, record, sizeof(record));
        refs.Push(record.target.ref);
    }
    float now = GetTickedTime();
    for (int i = 0; i < refs.Length; i++)
    {
        int ref = refs.Get(i);
        if (!RN_Burn_Settle(ref, now)) { RN_Burn_Remove(ref); continue; }
        int index = RN_Burn_Find(ref);
        if (index < 0) continue;
        g_Burn_Records.GetArray(index, record, sizeof(record));
        if (now >= record.end) RN_Burn_Remove(ref);
    }
    delete refs;
}

/** 统一服务只处理当前活跃账本，不负责改变战役时间。 */
public Action RN_Burn_OnTick(Handle timer)
{
    if (timer != g_Burn_Timer) return Plugin_Stop;
    RN_Burn_Tick();
    return Plugin_Continue;
}

/** 清档/关闭先移除全部账本，灭火保留其他来源冻结。 */
void RN_Burn_Clear()
{
    RN_BurnRecord record;
    while (g_Burn_Records.Length > 0)
    {
        g_Burn_Records.GetArray(g_Burn_Records.Length - 1, record, sizeof(record));
        RN_Burn_Remove(record.target.ref);
    }
}
