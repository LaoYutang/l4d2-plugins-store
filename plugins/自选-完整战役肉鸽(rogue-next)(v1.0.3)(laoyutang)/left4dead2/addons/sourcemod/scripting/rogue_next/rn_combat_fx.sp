#if defined _rn_combat_fx_included
 #endinput
#endif
#define _rn_combat_fx_included

/** 短期实体效果；动态容器避免固定实体索引上限和槽位复用。 */
enum struct RN_FXRecord
{
    int ref;
    int serial;
    int life;
    int runEpoch;
    int mapEpoch;
    Handle freezeTimer;
    Handle fireTimer;
    int flag;
    bool flagWasSet;
    bool hasGlow;
    int glowType;
    int glowColor;
}
ArrayList g_FX_Records;

/** 初始化本插件拥有的冻结/灭火资源登记表。 */
void RN_FX_Init()
{
    g_FX_Records = new ArrayList(sizeof(RN_FXRecord));
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

/** 返回已登记资源；首次登记捕获实体身份。 */
int RN_FX_Get(int entity, RN_FXRecord record)
{
    int ref = EntIndexToEntRef(entity);
    int index = RN_FX_Find(ref);
    if (index >= 0)
    {
        g_FX_Records.GetArray(index, record, sizeof(record));
        return index;
    }
    record.ref = ref;
    record.runEpoch = g_Run_Epoch;
    record.mapEpoch = g_Run_MapEpoch;
    if (entity <= MaxClients)
    {
        record.serial = GetClientSerial(entity);
        record.life = g_Common_Life[entity];
    }
    return g_FX_Records.PushArray(record, sizeof(record));
}

/** 仅恢复本插件新增的冻结标志和仍匹配本插件的发光值。 */
void RN_FX_Unfreeze(RN_FXRecord record, int entity)
{
    if (!record.flagWasSet) SetEntityFlags(entity, GetEntityFlags(entity) & ~record.flag);
    if (record.hasGlow && GetEntProp(entity, Prop_Send, "m_iGlowType") == 3 &&
        GetEntProp(entity, Prop_Send, "m_glowColorOverride") == (43 | (131 << 8) | (163 << 16)))
    {
        SetEntProp(entity, Prop_Send, "m_iGlowType", record.glowType);
        SetEntProp(entity, Prop_Send, "m_glowColorOverride", record.glowColor);
    }
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
    if (freeze)
    {
        record.freezeTimer = null;
        if (entity > 0) RN_FX_Unfreeze(record, entity);
    }
    else
    {
        record.fireTimer = null;
        if (entity > 0) ExtinguishEntity(entity);
    }
    if (record.freezeTimer == null && record.fireTimer == null) g_FX_Records.Erase(index);
    else g_FX_Records.SetArray(index, record, sizeof(record));
    return Plugin_Stop;
}

/** 点燃由伤害类型触发，本接口登记可安全续时的灭火timer。 */
void RN_FX_Fire(int entity, float duration)
{
    if (duration <= 0.0 || (!RN_Common_Infected(entity) && !RN_Common_Zombie(entity))) return;
    RN_FXRecord record;
    int index = RN_FX_Get(entity, record);
    delete record.fireTimer;
    DataPack pack;
    record.fireTimer = CreateDataTimer(duration, RN_FX_OnExpire, pack);
    pack.WriteCell(record.ref);
    pack.WriteCell(0);
    g_FX_Records.SetArray(index, record, sizeof(record));
}

/** 施加旧版冰冻与颜色；重复命中只续时，不覆盖首次捕获的基线。 */
void RN_FX_Freeze(int entity, float duration)
{
    if (duration <= 0.0 || (!RN_Common_Infected(entity) && !RN_Common_Zombie(entity))) return;
    if (entity <= MaxClients && !IsPlayerAlive(entity)) return;
    RN_FXRecord record;
    int index = RN_FX_Get(entity, record);
    if (record.freezeTimer == null)
    {
        record.flag = entity <= MaxClients ? FL_ATCONTROLS : FL_FROZEN;
        record.flagWasSet = (GetEntityFlags(entity) & record.flag) != 0;
        record.hasGlow = HasEntProp(entity, Prop_Send, "m_iGlowType") &&
            HasEntProp(entity, Prop_Send, "m_glowColorOverride");
        if (record.hasGlow)
        {
            record.glowType = GetEntProp(entity, Prop_Send, "m_iGlowType");
            record.glowColor = GetEntProp(entity, Prop_Send, "m_glowColorOverride");
        }
        if (entity <= MaxClients) L4D_CleanupPlayerState(entity);
        SetEntityFlags(entity, GetEntityFlags(entity) | record.flag);
        if (record.hasGlow)
        {
            SetEntProp(entity, Prop_Send, "m_iGlowType", 3);
            SetEntProp(entity, Prop_Send, "m_glowColorOverride", 43 | (131 << 8) | (163 << 16));
        }
    }
    delete record.freezeTimer;
    DataPack pack;
    record.freezeTimer = CreateDataTimer(duration, RN_FX_OnExpire, pack);
    pack.WriteCell(record.ref);
    pack.WriteCell(1);
    g_FX_Records.SetArray(index, record, sizeof(record));
}

/** 删除一个登记项；restore=false用于实体已经死亡/销毁的路径。 */
void RN_FX_Remove(int index, bool restore)
{
    RN_FXRecord record;
    g_FX_Records.GetArray(index, record, sizeof(record));
    int entity = restore ? RN_FX_Resolve(record, true) : -1;
    if (entity > 0)
    {
        if (record.freezeTimer != null) RN_FX_Unfreeze(record, entity);
        if (record.fireTimer != null) ExtinguishEntity(entity);
    }
    delete record.freezeTimer;
    delete record.fireTimer;
    g_FX_Records.Erase(index);
}

/** 同图生命切换前清理旧效果；不能先改变life或epoch再试图恢复。 */
void RN_FX_Forget(int entity, bool restore = true)
{
    if (entity < 1 || !IsValidEntity(entity)) return;
    int index = RN_FX_Find(EntIndexToEntRef(entity));
    if (index >= 0) RN_FX_Remove(index, restore);
}

/** 地图结束、关停、清档统一调用；资源释放先于实体与档案清表。 */
void RN_FX_Clear()
{
    for (int i = g_FX_Records.Length - 1; i >= 0; i--) RN_FX_Remove(i, true);
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

