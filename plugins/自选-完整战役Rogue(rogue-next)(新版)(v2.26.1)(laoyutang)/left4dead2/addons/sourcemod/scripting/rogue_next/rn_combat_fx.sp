#if defined _rn_combat_fx_included
 #endinput
#endif
#define _rn_combat_fx_included

/** 短期实体效果；动态容器避免固定实体索引上限和槽位复用。 */
enum struct RN_FXRecord
{
    int ref;
    int entityIndex; // 仅用于销毁时取消；实际访问始终验证EntRef和生命。
    int serial;
    int life;
    int runEpoch;
    int mapEpoch;
    Handle freezeTimer;
    Handle fireTimer;
    float freezeEnd;
    int flag;
    int flagsAdded;
    MoveType moveType;
    bool moveOwned;
    bool hasGlow;
    int glowType;
    int glowColor;
}
ArrayList g_FX_Records;
StringMap g_FX_NPCDeaths;
char g_FX_Log[PLATFORM_MAX_PATH];

/** 初始化本插件拥有的冻结/灭火资源登记表。 */
void RN_FX_Init()
{
    g_FX_Records = new ArrayList(sizeof(RN_FXRecord));
    g_FX_NPCDeaths = new StringMap();
    BuildPath(Path_SM, g_FX_Log, sizeof(g_FX_Log), "logs/rogue_next_elements.log");
}

/** NPC尸体可能保留正血量；实体引用、生命属性及死亡事件共同判定存活。 */
bool RN_FX_NPCLiving(int entity)
{
    if (!RN_Common_Zombie(entity) || GetEntProp(entity, Prop_Data, "m_iHealth") <= 0) return false;
    if (HasEntProp(entity, Prop_Data, "m_lifeState") && GetEntProp(entity, Prop_Data, "m_lifeState") != 0) return false;
    char key[16];
    IntToString(entity, key, sizeof(key));
    int ref;
    return !g_FX_NPCDeaths.GetValue(key, ref) || ref != EntIndexToEntRef(entity);
}

/** 按当前EntRef记录正式NPC死亡，效果清理或关停不能让正血尸体重新成为目标。 */
void RN_FX_NPCDeath(int entity)
{
    if (!RN_Common_Zombie(entity)) return;
    int ref = EntIndexToEntRef(entity);
    char key[16];
    IntToString(entity, key, sizeof(key));
    g_FX_NPCDeaths.SetValue(key, ref);
    int index = RN_FX_Find(ref);
    if (index >= 0)
    {
        RN_FXRecord record;
        g_FX_Records.GetArray(index, record, sizeof(record));
        RN_FX_LogStep("death_cleanup", record);
    }
}

/** 仅真实出生或实体销毁注销死亡槽位，不读取销毁对象的任何属性。 */
void RN_FX_NPCForget(int entity)
{
    if (entity <= MaxClients) return;
    char key[16];
    IntToString(entity, key, sizeof(key));
    g_FX_NPCDeaths.Remove(key);
}

/** 状态SDK前后仅记录身份快照；详细开关关闭时不产生高频正常日志。 */
void RN_FX_LogStep(const char[] step, RN_FXRecord record)
{
    if (RN_Config_Int(RN_CVAR_DEBUG) != 0)
        LogToFileEx(g_FX_Log, "[Rogue] %s ref=%d serial=%d life=%d run=%d map=%d",
            step, record.ref, record.serial, record.life, record.runEpoch, record.mapEpoch);
}

/** 查找同一实体引用的资源记录。 */
int RN_FX_Find(int ref)
{
    RN_FXRecord record;
    for (int i = 0; i < g_FX_Records.Length; i++)
    {
        g_FX_Records.GetArray(i, record, sizeof(record));
        if (record.ref == ref) return i;
    }
    return -1;
}

/** 验证实体、战役、地图和客户端生命；旧timer永远不触碰新占槽实体。 */
int RN_FX_Resolve(RN_FXRecord record, bool cleaning = false)
{
    if (!cleaning && (record.runEpoch != g_Run_Epoch || record.mapEpoch != g_Run_MapEpoch)) return -1;
    int entity = EntRefToEntIndex(record.ref);
    if (entity < 1 || !IsValidEntity(entity)) return -1;
    if (record.serial != 0 &&
        (!RN_Common_Client(entity) || GetClientSerial(entity) != record.serial ||
         g_Common_Life[entity] != record.life)) return -1;
    return entity;
}

/** 捕获身份快照；调用SDK前后使用同一份身份，不能重新绑定旧槽位。 */
void RN_FX_Identity(int entity, RN_FXRecord record)
{
    record.ref = EntIndexToEntRef(entity);
    record.entityIndex = entity;
    record.runEpoch = g_Run_Epoch;
    record.mapEpoch = g_Run_MapEpoch;
    if (entity <= MaxClients)
    {
        record.serial = GetClientSerial(entity);
        record.life = g_Common_Life[entity];
    }
}

/** 返回已登记资源；首次登记捕获实体身份。 */
int RN_FX_Get(int entity, RN_FXRecord record)
{
    int index = RN_FX_Find(EntIndexToEntRef(entity));
    if (index >= 0)
    {
        g_FX_Records.GetArray(index, record, sizeof(record));
        if (RN_FX_Resolve(record) == entity) return index;
        RN_FX_Remove(index, false);
        RN_FXRecord empty;
        record = empty;
    }
    RN_FX_Identity(entity, record);
    return g_FX_Records.PushArray(record, sizeof(record));
}

/** 仅恢复本插件新增的冻结标志、仍接管的移动类型和匹配的发光值。 */
void RN_FX_Unfreeze(RN_FXRecord record, int entity)
{
    RN_FX_LogStep("before_unfreeze", record);
    SetEntityFlags(entity, GetEntityFlags(entity) & ~record.flagsAdded);
    if (record.moveOwned && GetEntityMoveType(entity) == MOVETYPE_NONE)
        SetEntityMoveType(entity, record.moveType);
    if (record.hasGlow && GetEntProp(entity, Prop_Send, "m_iGlowType") == 3 &&
        GetEntProp(entity, Prop_Send, "m_glowColorOverride") == (43 | (131 << 8) | (163 << 16)))
    {
        SetEntProp(entity, Prop_Send, "m_iGlowType", record.glowType);
        SetEntProp(entity, Prop_Send, "m_glowColorOverride", record.glowColor);
    }
    RN_FX_LogStep("after_unfreeze", record);
}

/** 使用EntRef与timer句柄双重核对；续时后的旧回调不能结束新效果。 */
public Action RN_FX_OnExpire(Handle timer, DataPack pack)
{
    pack.Reset();
    int ref = pack.ReadCell();
    bool freeze = pack.ReadCell() != 0;
    int index = RN_FX_Find(ref);
    if (index < 0) return Plugin_Stop;
    RN_FXRecord record;
    g_FX_Records.GetArray(index, record, sizeof(record));
    if ((freeze ? record.freezeTimer : record.fireTimer) != timer) return Plugin_Stop;
    int entity = RN_FX_Resolve(record);
    if (freeze) record.freezeTimer = null;
    else record.fireTimer = null;
    if (record.freezeTimer == null && record.fireTimer == null) g_FX_Records.Erase(index);
    else g_FX_Records.SetArray(index, record, sizeof(record));
    if (freeze) RN_Freeze_Detach(record);
    if (entity > 0)
    {
        if (freeze) RN_FX_Unfreeze(record, entity);
        else
        {
            RN_FX_LogStep("before_extinguish", record);
            ExtinguishEntity(entity);
            RN_FX_LogStep("after_extinguish", record);
        }
    }
    return Plugin_Stop;
}

/** 为显式点燃登记可安全续时的灭火timer；该接口不追加原攻击火伤。 */
void RN_FX_Fire(int entity, float duration)
{
    if (duration <= 0.0 || (!RN_Common_Infected(entity) && !RN_Common_Zombie(entity))) return;
    if (entity > MaxClients && !RN_FX_NPCLiving(entity)) return;
    RN_FXRecord record;
    int index = RN_FX_Get(entity, record);
    delete record.fireTimer;
    DataPack pack;
    record.fireTimer = CreateDataTimer(duration, RN_FX_OnExpire, pack);
    pack.WriteCell(record.ref);
    pack.WriteCell(0);
    g_FX_Records.SetArray(index, record, sizeof(record));
}

/** 每次冰冻均清理动作并重施限制；续冻保留首次解除控制后的移动基线。 */
void RN_FX_Freeze(int entity, float duration)
{
    if (duration <= 0.0 || (!RN_Common_Infected(entity) && !RN_Common_Zombie(entity))) return;
    if (entity <= MaxClients && !IsPlayerAlive(entity)) return;
    if (entity > MaxClients && !RN_FX_NPCLiving(entity)) return;
    RN_FXRecord record;
    int index = RN_FX_Get(entity, record);
    bool first = record.freezeTimer == null;
    if (first)
    {
        record.flag = entity <= MaxClients ? (FL_ATCONTROLS | FL_FROZEN) : FL_FROZEN;
        record.flagsAdded = record.flag & ~GetEntityFlags(entity);
        record.hasGlow = HasEntProp(entity, Prop_Send, "m_iGlowType") &&
            HasEntProp(entity, Prop_Send, "m_glowColorOverride");
        if (record.hasGlow)
        {
            record.glowType = GetEntProp(entity, Prop_Send, "m_iGlowType");
            record.glowColor = GetEntProp(entity, Prop_Send, "m_glowColorOverride");
        }
    }
    if (entity <= MaxClients && !RN_Freeze_Cleanup(entity, record))
    {
        index = RN_FX_Find(record.ref);
        RN_FXRecord current;
        if (index >= 0)
        {
            g_FX_Records.GetArray(index, current, sizeof(current));
            if (current.serial == record.serial && current.life == record.life &&
                current.runEpoch == record.runEpoch && current.mapEpoch == record.mapEpoch)
                RN_FX_Remove(index, RN_FX_Resolve(record, true) == entity);
        }
        return;
    }
    index = RN_FX_Find(record.ref);
    if (index < 0 || RN_FX_Resolve(record) != entity) return;
    if (first && entity <= MaxClients)
    {
        record.moveType = GetEntityMoveType(entity);
        record.moveOwned = record.moveType != MOVETYPE_NONE;
    }
    SetEntityFlags(entity, GetEntityFlags(entity) | record.flag);
    if (record.hasGlow)
    {
        SetEntProp(entity, Prop_Send, "m_iGlowType", 3);
        SetEntProp(entity, Prop_Send, "m_glowColorOverride", 43 | (131 << 8) | (163 << 16));
    }
    delete record.freezeTimer;
    record.freezeEnd = GetTickedTime() + duration;
    DataPack pack;
    record.freezeTimer = CreateDataTimer(duration, RN_FX_OnExpire, pack);
    pack.WriteCell(record.ref);
    pack.WriteCell(1);
    g_FX_Records.SetArray(index, record, sizeof(record));
    if (entity <= MaxClients)
    {
        RN_Freeze_Bind(record, entity);
        RN_Freeze_Lock(record, entity);
    }
    RN_FX_LogStep("freeze", record);
}

/** 删除一个登记项；销毁/失效只注销，死亡但实体仍存在时恢复自身状态。 */
void RN_FX_Remove(int index, bool restore)
{
    RN_FXRecord record;
    g_FX_Records.GetArray(index, record, sizeof(record));
    g_FX_Records.Erase(index);
    int entity = restore ? RN_FX_Resolve(record, true) : -1;
    bool frozen = record.freezeTimer != null, burning = record.fireTimer != null;
    RN_Freeze_Detach(record);
    delete record.freezeTimer;
    delete record.fireTimer;
    if (entity > 0)
    {
        if (frozen) RN_FX_Unfreeze(record, entity);
        if (burning && RN_FX_Resolve(record, true) == entity)
        {
            RN_FX_LogStep("before_extinguish", record);
            ExtinguishEntity(entity);
            RN_FX_LogStep("after_extinguish", record);
        }
    }
}

/** 仅识别当前生命且未到期的自身冰冻，不把其他插件的冻结当联动。 */
bool RN_FX_Frozen(int entity)
{
    int index = RN_FX_Find(EntIndexToEntRef(entity));
    if (index < 0) return false;
    RN_FXRecord record;
    g_FX_Records.GetArray(index, record, sizeof(record));
    return RN_FX_Resolve(record) == entity && record.freezeTimer != null && record.freezeEnd > GetTickedTime();
}

/** 灼烧拥有者失效时只取消火焰，不消费队友的冰冻。 */
void RN_FX_Extinguish(int entity)
{
    int index = RN_FX_Find(EntIndexToEntRef(entity));
    if (index < 0) return;
    RN_FXRecord record;
    g_FX_Records.GetArray(index, record, sizeof(record));
    bool burning = record.fireTimer != null;
    delete record.fireTimer;
    if (record.freezeTimer == null) g_FX_Records.Erase(index);
    else g_FX_Records.SetArray(index, record, sizeof(record));
    if (burning && RN_FX_Resolve(record, true) == entity)
    {
        RN_FX_LogStep("before_extinguish", record);
        ExtinguishEntity(entity);
        RN_FX_LogStep("after_extinguish", record);
    }
}

/** 同图生命切换前清理旧效果；不能先改变life或epoch再试图恢复。 */
void RN_FX_Forget(int entity, bool restore = true)
{
    if (entity < 1) return;
    if (!IsValidEntity(entity))
    {
        RN_FXRecord record;
        for (int i = g_FX_Records.Length - 1; i >= 0; i--)
        {
            g_FX_Records.GetArray(i, record, sizeof(record));
            if (record.entityIndex == entity) RN_FX_Remove(i, false);
        }
        return;
    }
    int index = RN_FX_Find(EntIndexToEntRef(entity));
    if (index >= 0) RN_FX_Remove(index, restore);
}

/** 地图结束、关停、清档统一调用；资源释放先于实体与档案清表。 */
void RN_FX_Clear()
{
    while (g_FX_Records.Length > 0) RN_FX_Remove(g_FX_Records.Length - 1, true);
}

/** 读档战神解除当前控制者；账本必须在调用伤害前提交。 */
void RN_FX_ReleaseControl(int victim)
{
    static const char props[][] = {"m_tongueOwner", "m_pounceAttacker", "m_jockeyAttacker", "m_carryAttacker", "m_pummelAttacker"};
    int attacked[MAXPLAYERS + 1];
    for (int i = 0; i < sizeof(props); i++)
    {
        int attacker = GetEntPropEnt(victim, Prop_Send, props[i]);
        if (!RN_Common_Infected(attacker) || !IsPlayerAlive(attacker) || attacked[attacker]) continue;
        attacked[attacker] = 1;
        SDKHooks_TakeDamage(attacker, victim, victim, 999.0, DMG_GENERIC);
    }
}
