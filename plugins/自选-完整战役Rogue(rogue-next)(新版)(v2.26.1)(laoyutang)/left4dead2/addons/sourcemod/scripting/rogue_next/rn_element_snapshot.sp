#if defined _rn_element_snapshot_included
 #endinput
#endif
#define _rn_element_snapshot_included

/** 命中事实与实体效果分离；死亡后只使用固定原点和火焰载荷，不访问尸体。 */
enum struct RN_ElementHit
{
    int id;
    RN_FXRecord target;
    int ownerSerial;
    int ownerLife;
    char shotKey[48];
    int traceHits;
    int postHits;
    float fireChance;
    float freezeChance;
    float electricChance;
    bool fire;
    bool freeze;
    bool electric;
    float electricDamage;
    int electricJumps;
    bool thunder;
    int targetBranch;
    float dps;
    float fireDuration;
    float freezeDuration;
    float origin[3];
    bool frozen;
    bool deadAnchor;
    bool hasBurn;
    RN_BurnRecord burn;
}
ArrayList g_Element_Hits;
ArrayList g_Element_Captures;
int g_Element_NextID;

/** 同步扣血前保存属性、身份、原点和余火；不抽概率或创建元素伤害。 */
bool RN_Element_Snapshot(int victim, int attacker, RN_ElementHit hit,
    int inflictor = -1, int weapon = -1, int type = 0)
{
    PlayerProfile profile;
    RN_Combat_Profile(attacker, profile);
    hit.fireDuration = RN_Branch_FireDuration(profile);
    hit.freezeDuration = RN_Config_Float(RN_CVAR_FREEZEDURATION_SURV);
    hit.fireChance = hit.fireDuration > 0.0 ? RN_Stats_Get(profile, RN_STAT_IGNITE) : 0.0;
    hit.freezeChance = hit.freezeDuration > 0.0 ? RN_Stats_Get(profile, RN_STAT_FREEZE) : 0.0;
    hit.electricChance = RN_Stats_Get(profile, RN_STAT_ELECTRIC_CHANCE);
    if (hit.fireChance <= 0.0 && hit.freezeChance <= 0.0 && hit.electricChance <= 0.0) return false;
    float sourceFactor = RN_Branch_AttackFactor(attacker, inflictor, weapon, type, true);
    hit.electricDamage = RN_Stats_Get(profile, RN_STAT_ELECTRIC_DAMAGE) * sourceFactor;
    hit.electricJumps = RN_Stats_ElectricJumps(profile);
    hit.thunder = RN_Branch_Active(profile, RN_BRANCH_THUNDER);
    hit.targetBranch = RN_Branch_Get(attacker);
    hit.dps = RN_Stats_Get(profile, RN_STAT_BURN_DPS) * sourceFactor;
    float maximum = hit.dps * hit.fireDuration * (hit.targetBranch == RN_BRANCH_DEATH ? 2.0 : 1.0);
    if (!RN_Math_Finite(maximum) || maximum >= RN_INT_FLOAT_LIMIT) return false;
    RN_FX_Identity(victim, hit.target);
    hit.ownerSerial = GetClientSerial(attacker);
    hit.ownerLife = g_Common_Life[attacker];
    RN_Element_Origin(victim, hit.origin);
    for (int i = 0; i < 3; i++) if (!RN_Math_Finite(hit.origin[i])) return false;
    hit.frozen = RN_FX_Frozen(victim);
    hit.hasBurn = RN_Burn_Get(victim, hit.burn);
    return true;
}

/** 帧任务与同步捕获共享单调ID，清档不复用ID以免旧回调命中新任务。 */
int RN_Element_ID()
{
    if (g_Element_NextID == RN_MAX_INT) { SetFailState("元素命中代次耗尽，请重载Rogue。"); return 0; }
    return ++g_Element_NextID;
}

/** 未收到有效伤害post的捕获在下一帧丢弃，不把被拦截攻击兑现为元素。 */
public void RN_Element_ExpireCapture(any id)
{
    if (g_Element_Captures == null) return;
    RN_ElementHit hit;
    for (int i = g_Element_Captures.Length - 1; i >= 0; i--)
    {
        g_Element_Captures.GetArray(i, hit, sizeof(hit));
        if (hit.id == id) { g_Element_Captures.Erase(i); return; }
    }
}

/** 原始正伤害进入Rogue枪伤计算前留证；内部副伤与持续火不生成捕获。 */
void RN_Element_Capture(int victim, int attacker, int inflictor, float damage, int type, int weapon)
{
    if (g_Element_Captures == null || !RN_Element_Eligible(victim, attacker, damage, type)) return;
    RN_ElementHit hit;
    if (RN_ElementShot_Pending(victim, attacker, inflictor, weapon, type, hit.shotKey, sizeof(hit.shotKey)) < 0) return;
    if (!RN_Element_Snapshot(victim, attacker, hit, inflictor, weapon, type))
    { RN_ElementShot_Record(attacker, hit.shotKey, -1); return; }
    hit.id = RN_Element_ID();
    g_Element_Captures.PushArray(hit, sizeof(hit));
    RequestFrame(RN_Element_ExpireCapture, hit.id);
}

/** 最内层同目标与拥有者配对；死亡清理保留捕获，只有正伤害post才能确认。 */
bool RN_Element_TakeCapture(int victim, int attacker, RN_ElementHit hit)
{
    if (g_Element_Captures == null || !RN_Common_Client(attacker)) return false;
    int serial = GetClientSerial(attacker);
    for (int i = g_Element_Captures.Length - 1; i >= 0; i--)
    {
        g_Element_Captures.GetArray(i, hit, sizeof(hit));
        if (hit.target.entityIndex != victim || hit.ownerSerial != serial) continue;
        g_Element_Captures.Erase(i);
        return true;
    }
    RN_ElementHit empty;
    hit = empty;
    return false;
}

/** 延迟兑现仍核对原玩家、生命、职业与地图；目标死亡不影响拥有者资格。 */
int RN_Element_Owner(RN_ElementHit hit)
{
    int owner = GetClientFromSerial(hit.ownerSerial);
    if (!RN_Config_Enabled() || hit.target.runEpoch != g_Run_Epoch || hit.target.mapEpoch != g_Run_MapEpoch
        || !RN_Common_Survivor(owner) || IsFakeClient(owner) || !IsPlayerAlive(owner)
        || g_Common_Life[owner] != hit.ownerLife || !RN_Electric_ProfessionAllowed(owner)) return 0;
    return owner;
}

/** 正式死亡只把当前目标标成固定原点，后续销毁或索引复用不能重绑效果。 */
void RN_Element_MarkDead(ArrayList records, int entity)
{
    RN_ElementHit hit;
    for (int i = 0; i < records.Length; i++)
    {
        records.GetArray(i, hit, sizeof(hit));
        if (hit.target.entityIndex != entity || RN_FX_Resolve(hit.target) != entity) continue;
        hit.deadAnchor = true;
        records.SetArray(i, hit, sizeof(hit));
    }
}

/** 拥有者失效始终撤销；目标仅死亡时保留已确认命中，普通移除仍撤销。 */
void RN_Element_ForgetRecords(ArrayList records, int entity, int ref, int serial)
{
    RN_ElementHit hit;
    for (int i = records.Length - 1; i >= 0; i--)
    {
        records.GetArray(i, hit, sizeof(hit));
        if ((serial > 0 && hit.ownerSerial == serial) || (!hit.deadAnchor &&
            (hit.target.ref == ref || (!IsValidEntity(entity) && hit.target.entityIndex == entity)))) records.Erase(i);
    }
}

/** 尸体上的新点燃只形成联动载荷；已有余火按原截止时间失效且保留强火归属。 */
void RN_Element_DeadFire(RN_ElementHit hit, int owner)
{
    float now = GetTickedTime();
    if (hit.hasBurn && (hit.burn.end <= now || RN_Burn_Owner(hit.burn) == 0)) hit.hasBurn = false;
    if (!hit.fire || hit.fireDuration <= 0.0) return;
    if (!hit.hasBurn || hit.burn.ownerSerial == hit.ownerSerial || hit.dps > hit.burn.dps)
    {
        hit.burn.target = hit.target;
        hit.burn.ownerSerial = GetClientSerial(owner);
        hit.burn.ownerLife = hit.ownerLife;
        hit.burn.dps = hit.dps;
        hit.burn.payloadDps = hit.dps;
        hit.burn.targetBranch = hit.targetBranch;
    }
    hit.burn.duration = hit.fireDuration;
    hit.burn.last = now;
    hit.burn.end = now + hit.fireDuration;
    hit.burn.carry = 0.0;
    hit.hasBurn = true;
    if (RN_Config_Int(RN_CVAR_DEBUG) != 0)
        LogToFileEx(g_Burn_Log, "[Rogue] ignite_snapshot ref=%d owner=%d dps=%.3f duration=%.3f", hit.target.ref, hit.burn.ownerSerial, hit.burn.dps, hit.burn.duration);
}
