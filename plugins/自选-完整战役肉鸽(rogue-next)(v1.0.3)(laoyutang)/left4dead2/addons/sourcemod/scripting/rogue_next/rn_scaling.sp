#if defined _rn_scaling_included
 #endinput
#endif
#define _rn_scaling_included

/** 出生快照；开启/关闭恢复该生命原本快照，不按新档位反复缩放。 */
enum struct RN_ScaleRecord
{
    int ref;
    int serial;
    int life;
    int baseMax;
    int ownedMax;
    bool hasMax;
    float baseSpeed;
    float ownedSpeed;
    float hpFactor;
    float speedFactor;
    bool applied;
}
ArrayList g_Scaling_Records;

/** 初始化按EntRef登记的出生属性缓存。 */
void RN_Scaling_Init()
{
    g_Scaling_Records = new ArrayList(sizeof(RN_ScaleRecord));
}

/** 总开关与难度开关共同控制出生属性及实时伤害。 */
bool RN_Scaling_Enabled()
{
    return RN_Config_Enabled() && RN_Config_Int(RN_CVAR_SCALING_ENABLE) != 0;
}

/** 实时承伤倍率读取当前档位，已有实体不因此修改HP/移速。 */
float RN_Scaling_DamageFactor()
{
    return RN_Scaling_Enabled() ? 1.0 + float(RN_Clock_CurrentTier())*RN_Config_Float(RN_CVAR_DMG_PER_TIER) : 1.0;
}

/** 在缓存中定位当前实体；同一生命重复出生通知保持幂等。 */
int RN_Scaling_Find(int ref)
{
    RN_ScaleRecord record;
    for (int i = 0; i < g_Scaling_Records.Length; i++)
    {
        g_Scaling_Records.GetArray(i, record, sizeof(record));
        if (record.ref == ref) return i;
    }
    return -1;
}

/** 校验当前对象仍是记录的客户端生命或普通实体。 */
int RN_Scaling_Resolve(RN_ScaleRecord record)
{
    int entity = EntRefToEntIndex(record.ref);
    if (entity < 1 || !IsValidEntity(entity)) return -1;
    if (record.serial != 0 &&
        (!RN_Common_Infected(entity) || GetClientSerial(entity) != record.serial ||
         g_Common_Life[entity] != record.life)) return -1;
    return entity;
}

/** 写出生倍率或恢复基线；当前HP比例保持不变，不免费补满血。 */
bool RN_Scaling_Apply(RN_ScaleRecord record, bool enable)
{
    int entity = RN_Scaling_Resolve(record);
    if (entity < 1 || enable == record.applied) return true;
    float maximum = enable ? float(record.baseMax) * record.hpFactor : float(record.baseMax);
    float speed = enable ? record.baseSpeed * record.speedFactor : record.baseSpeed;
    if (!RN_Math_Finite(maximum) || maximum < 1.0 || maximum >= RN_INT_FLOAT_LIMIT ||
        !RN_Math_Finite(speed) || speed <= 0.0) return false;
    int nextMax = RoundToNearest(maximum);
    int current = GetEntProp(entity, Prop_Data, "m_iHealth");
    int previousMax = record.applied ? record.ownedMax : record.baseMax;
    // 其他插件改了max时保留其可见HP比例，避免使用陈旧的分母。
    if (record.hasMax)
    {
        int actual = GetEntProp(entity, Prop_Data, "m_iMaxHealth");
        if (actual > 0) previousMax = actual;
        SetEntProp(entity, Prop_Data, "m_iMaxHealth", nextMax);
    }
    if (current > 0 && previousMax > 0)
    {
        float ratio = float(current) / float(previousMax);
        if (ratio > 1.0) ratio = 1.0;
        int nextHealth = RoundToNearest(float(nextMax) * ratio);
        SetEntProp(entity, Prop_Data, "m_iHealth", nextHealth > 0 ? nextHealth : 1);
    }
    if (record.serial != 0)
        SetEntPropFloat(entity, Prop_Send, "m_flLaggedMovementValue", speed);
    record.ownedMax = nextMax;
    record.ownedSpeed = speed;
    record.applied = enable;
    return true;
}

/** 捕获一次出生基线；Tank额外倍率和人数均固定于该次出生。 */
void RN_Scaling_Birth(int entity)
{
    if (!RN_Common_ActiveRun() || (!RN_Common_Infected(entity) && !RN_Common_Zombie(entity))) return;
    if (entity <= MaxClients &&
        (!IsPlayerAlive(entity) || GetEntProp(entity, Prop_Send, "m_isGhost") != 0)) return;
    int ref = EntIndexToEntRef(entity);
    int index = RN_Scaling_Find(ref);
    RN_ScaleRecord record;
    if (index >= 0)
    {
        g_Scaling_Records.GetArray(index, record, sizeof(record));
        if (record.serial == 0 || record.life == g_Common_Life[entity]) return;
        // player_spawn标志新生命；旧生命缓存先释放，不能让倍率再次作用于自己的旧max。
        record.life = g_Common_Life[entity];
        RN_Scaling_Apply(record, false);
        g_Scaling_Records.Erase(index);
    }
    record.ref = ref;
    record.serial = 0;
    record.life = 0;
    record.applied = false;
    record.hasMax = HasEntProp(entity, Prop_Data, "m_iMaxHealth");
    record.baseMax = GetEntProp(entity, Prop_Data, record.hasMax ? "m_iMaxHealth" : "m_iHealth");
    // 部分普通感染者暴露max字段却不初始化；以出生实血建立有效基线。
    if (record.baseMax <= 0 && record.hasMax)
        record.baseMax = GetEntProp(entity, Prop_Data, "m_iHealth");
    if (record.baseMax <= 0) return;
    record.baseSpeed = 1.0;
    int tier = RN_Clock_CurrentTier();
    record.hpFactor = 1.0 + float(tier) * RN_Config_Float(RN_CVAR_HP_PER_TIER);
    record.speedFactor = 1.0;
    if (entity <= MaxClients)
    {
        record.serial = GetClientSerial(entity);
        record.life = g_Common_Life[entity];
        record.baseSpeed = GetEntPropFloat(entity, Prop_Send, "m_flLaggedMovementValue");
        if (RN_Common_Tank(entity))
        {
            record.hpFactor *= RN_Config_Float(RN_CVAR_TANK_HP_FACTOR);
            if (RN_Config_Int(RN_CVAR_TANK_COUNT_SCALING) != 0)
            {
                int count = RN_Common_SurvivorCount();
                record.hpFactor *= float(count > 0 ? count : 1) / 4.0;
            }
            record.speedFactor += float(tier) * RN_Config_Float(RN_CVAR_TANK_SPEED_PER_TIER);
        }
    }
    if (!RN_Scaling_Apply(record, RN_Scaling_Enabled()))
        LogError("[rogue-next] 实体%d出生倍率不可表达，保留原属性。", entity);
    g_Scaling_Records.PushArray(record, sizeof(record));
}

/** 配置开关同步已有实体；系数调整不改变该生命的出生快照。 */
void RN_Scaling_Sync()
{
    bool enable = RN_Scaling_Enabled();
    RN_ScaleRecord record;
    for (int i = g_Scaling_Records.Length - 1; i >= 0; i--)
    {
        g_Scaling_Records.GetArray(i, record, sizeof(record));
        if (RN_Scaling_Resolve(record) < 1) { g_Scaling_Records.Erase(i); continue; }
        if (RN_Scaling_Apply(record, enable)) g_Scaling_Records.SetArray(i, record, sizeof(record));
    }
}

/** 清档/卸载先按比例恢复仍存在的实体，再丢弃出生缓存。 */
void RN_Scaling_Clear(bool restore = true)
{
    RN_ScaleRecord record;
    if (restore)
        for (int i = 0; i < g_Scaling_Records.Length; i++)
        {
            g_Scaling_Records.GetArray(i, record, sizeof(record));
            RN_Scaling_Apply(record, false);
        }
    g_Scaling_Records.Clear();
}

/** 实体销毁无需操作属性，仅删除其缓存。 */
void RN_Scaling_Forget(int entity)
{
    if (entity < 1 || !IsValidEntity(entity)) return;
    int index = RN_Scaling_Find(EntIndexToEntRef(entity));
    if (index >= 0) g_Scaling_Records.Erase(index);
}

/** 新player_spawn前退役旧生命贡献；清旧效果时life仍需匹配。 */
void RN_Scaling_Retire(int client)
{
    if (!RN_Common_Client(client)) return;
    int index = RN_Scaling_Find(EntIndexToEntRef(client));
    if (index < 0) return;
    RN_ScaleRecord record;
    g_Scaling_Records.GetArray(index, record, sizeof(record));
    RN_Scaling_Apply(record, false);
    g_Scaling_Records.Erase(index);
}

