#if defined _rn_grenade_included
 #endinput
#endif
#define _rn_grenade_included

#define RN_GRENADE_PROJECTILES 128
#define RN_GRENADE_GROUPS 32
#define RN_GRENADE_EDICTS 2049
#define RN_GRENADE_IDLE_TIMEOUT 30.0

/** 榴弹归属绑定会话、生命、战役、地图与职业选择身份，不绑定武器持有状态。 */
enum struct RN_GrenadeContext
{
    int serial;
    int life;
    int run;
    int map;
    int profile;
    int professionVersion;
    int branch;
    float sourceFactor;
    float initialDamage;
    float peaceDamage;
}

/** 同一发射的分支只共用生命周期；碰撞预算独立保存在每颗弹上。 */
enum struct RN_GrenadeGroup
{
    int id;
    int impacts;
    int active;
    float lastImpact;
}

/** 子弹继承父弹已用次数及最近前进方向，不重置累计碰撞。 */
enum struct RN_GrenadeProjectile
{
    int ref;
    int group;
    int groupId;
    int bornTick;
    int used;
    float heading;
    float position[3];
    float velocity[3];
}

RN_GrenadeContext g_Grenade_Owners[RN_GRENADE_GROUPS];
RN_GrenadeGroup g_Grenade_Groups[RN_GRENADE_GROUPS];
RN_GrenadeProjectile g_Grenade_Projectiles[RN_GRENADE_PROJECTILES];
int g_Grenade_ManagedRef[RN_GRENADE_EDICTS];
int g_Grenade_EntitySlot[RN_GRENADE_EDICTS];
int g_Grenade_NextId, g_Grenade_Active;
int g_Grenade_SpawnGroup = -1;
int g_Grenade_SpawnGroupId, g_Grenade_SpawnUsed;
bool g_Grenade_Creating;
RN_GrenadeContext g_Grenade_SpawnContext;
float g_Grenade_LastFrame;
ConVar g_Grenade_Gravity;

#include "rn_grenade_physics.sp"
#include "rn_grenade_blast.sp"

/** 使用游戏重力，帧调度复用Rogue既有OnGameFrame入口。 */
void RN_Grenade_Init()
{
    g_Grenade_Gravity = FindConVar("sv_gravity");
    g_Grenade_LastFrame = GetGameTime();
}

/** BOT使用基础榴弹；真人能力只从自己的有效档案读取。 */
bool RN_Grenade_Enabled(int client)
{
    return RN_Config_Enabled() && RN_Config_Int(RN_CVAR_GRENADE_ENABLE) != 0 && RN_Common_Survivor(client);
}

/** 创建native前捕获身份；取消期间产生的子弹也必须先拦原生爆炸再清理。 */
void RN_Grenade_Capture(int client, RN_GrenadeContext context)
{
    context.serial = GetClientSerial(client);
    context.life = g_Common_Life[client];
    context.run = g_Run_Epoch;
    context.map = g_Run_MapEpoch;
    context.profile = IsFakeClient(client) ? -1 : g_Profile_Index[client];
    PlayerProfile profile;
    if (RN_Profile_Get(context.profile, profile))
    {
        context.professionVersion = profile.professionVersion;
        context.branch = RN_Branch_Active(profile, profile.branch) ? profile.branch : RN_BRANCH_NONE;
    }
    context.sourceFactor = RN_Branch_SourceFactor(client);
    context.initialDamage = RN_Config_Float(RN_CVAR_GRENADE_DAMAGE);
    context.peaceDamage = 0.0;
    if (RN_Branch_Active(profile, RN_BRANCH_PEACE) && !RN_Magician_PeaceDamage(profile, context.peaceDamage))
        context.peaceDamage = -1.0;
}

/** 死亡后的在飞弹保持归属，新生命、离队、托管及完整清档立即使旧身份失效。 */
int RN_Grenade_Resolve(RN_GrenadeContext context)
{
    int client = GetClientFromSerial(context.serial);
    if (!RN_Grenade_Enabled(client) || g_Common_Life[client] != context.life ||
        g_Run_Epoch != context.run || g_Run_MapEpoch != context.map) return 0;
    if (IsFakeClient(client)) return context.profile == -1 ? client : 0;
    PlayerProfile profile;
    return g_Profile_Index[client] == context.profile && RN_Profile_Get(context.profile, profile) &&
        profile.professionVersion == context.professionVersion ? client : 0;
}

/** 逐次SDK操作前解析完整归属，不能把旧射击归给同槽新玩家。 */
int RN_Grenade_Owner(int group)
{
    return group >= 0 && group < RN_GRENADE_GROUPS && g_Grenade_Groups[group].id != 0
        ? RN_Grenade_Resolve(g_Grenade_Owners[group]) : 0;
}

/** 查看与战斗使用同一个弹跳合计；次数热改作用于仍在飞行的各分支。 */
int RN_Grenade_Limit(int group)
{
    int owner = RN_Grenade_Owner(group);
    if (owner == 0) return 0;
    PlayerProfile profile;
    RN_Combat_Profile(owner, profile);
    profile.branch = g_Grenade_Owners[group].branch;
    return 1 + RN_Magician_Bounces(profile);
}

/** 受控弹的源状态倍率固定于发射；返回0表示普通伤害入口应自行取当前状态。 */
float RN_Grenade_SourceFactor(int inflictor)
{
    if (!RN_Grenade_Managed(inflictor)) return 0.0;
    int slot = g_Grenade_EntitySlot[inflictor];
    if (slot < 0 || slot >= RN_GRENADE_PROJECTILES) return 0.0;
    int group = g_Grenade_Projectiles[slot].group;
    if (g_Grenade_Groups[group].id != g_Grenade_Projectiles[slot].groupId) return 0.0;
    return g_Grenade_Owners[group].sourceFactor;
}

/** 目标条件仍逐次读取满血，但转职资格固定于首发，不追授旧弹新的夺命能力。 */
int RN_Grenade_TargetBranch(int inflictor)
{
    if (!RN_Grenade_Managed(inflictor)) return -1;
    int slot = g_Grenade_EntitySlot[inflictor];
    if (slot < 0 || slot >= RN_GRENADE_PROJECTILES) return -1;
    int group = g_Grenade_Projectiles[slot].group;
    if (g_Grenade_Groups[group].id != g_Grenade_Projectiles[slot].groupId) return -1;
    return g_Grenade_Owners[group].branch;
}

/** 只供榴弹派生元素继承本次分支倍率；首爆和逐跳直击已含该变化，不再乘。 */
float RN_Grenade_DerivedFactor(int inflictor)
{
    if (!RN_Grenade_Managed(inflictor) || RN_Config_Int(RN_CVAR_PROFESSION_ENABLE) == 0) return 1.0;
    int slot = g_Grenade_EntitySlot[inflictor];
    if (slot < 0 || slot >= RN_GRENADE_PROJECTILES) return 1.0;
    int group = g_Grenade_Projectiles[slot].group;
    if (g_Grenade_Groups[group].id != g_Grenade_Projectiles[slot].groupId) return 1.0;
    if (g_Grenade_Owners[group].branch == RN_BRANCH_CHAOS)
    {
        int hop = g_Grenade_Projectiles[slot].used > 0 ? g_Grenade_Projectiles[slot].used - 1 : 0;
        return RN_Branch_ChaosDamage(1.0, hop);
    }
    if (g_Grenade_Owners[group].branch == RN_BRANCH_PEACE && g_Grenade_Owners[group].initialDamage > 0.0)
        return g_Grenade_Owners[group].peaceDamage / g_Grenade_Owners[group].initialDamage;
    return 1.0;
}

/** 原生燃烧升级不叠到受控弹，普通元素BUFF仍由Rogue伤害流程处理。 */
public Action L4D2_GrenadeLauncherProjectile_Pre(int client, float position[3], float angles[3], float velocity[3], float rotation[3], bool &incendiary)
{
    if (RN_Grenade_Enabled(client) && incendiary) { incendiary = false; return Plugin_Changed; }
    return Plugin_Continue;
}

/** 普通武器回调接管新弹，分裂native返回路径另行确认，不依赖回调必到。 */
public void L4D2_GrenadeLauncherProjectile_Post(int client, int projectile, const float position[3], const float angles[3], const float velocity[3], const float rotation[3], bool incendiary)
{
    if (!g_Grenade_Creating && !RN_Grenade_Enabled(client)) return;
    RN_GrenadeContext context;
    if (g_Grenade_Creating) context = g_Grenade_SpawnContext;
    else RN_Grenade_Capture(client, context);
    RN_Grenade_Adopt(projectile, position, velocity, context,
        g_Grenade_Creating ? g_Grenade_SpawnGroup : -1, g_Grenade_SpawnGroupId, g_Grenade_SpawnUsed);
}

/** 接管失败只清已经认领的榴弹，创建调用结束后再安全移除。 */
bool RN_Grenade_CreateFailed(int entity, const char[] reason)
{
    LogError("[Rogue] GRENADE_ADOPT_FAIL entity=%d reason=%s", entity, reason);
    if (RN_Grenade_Managed(entity)) RequestFrame(RN_Grenade_DiscardFrame, g_Grenade_ManagedRef[entity]);
    return false;
}

/** 保留验证版幂等接管和原生拦截；孩子继承组身份与已发生的碰撞次数。 */
bool RN_Grenade_Adopt(int projectile, const float position[3], const float velocity[3], RN_GrenadeContext context,
    int group = -1, int groupId = 0, int used = 0)
{
    if (projectile <= MaxClients || projectile >= RN_GRENADE_EDICTS || !IsValidEntity(projectile))
        return RN_Grenade_CreateFailed(projectile, "invalid_projectile");
    char classname[64];
    GetEntityClassname(projectile, classname, sizeof(classname));
    if (!StrEqual(classname, "grenade_launcher_projectile")) return RN_Grenade_CreateFailed(projectile, "wrong_entity_class");
    if (RN_Grenade_Managed(projectile))
    {
        int existing = g_Grenade_EntitySlot[projectile];
        return existing >= 0 && g_Grenade_Projectiles[existing].ref == g_Grenade_ManagedRef[projectile];
    }
    int reference = EntIndexToEntRef(projectile);
    g_Grenade_ManagedRef[projectile] = reference;
    g_Grenade_EntitySlot[projectile] = -1;
    SetEntityMoveType(projectile, MOVETYPE_NONE);
    TeleportEntity(projectile, NULL_VECTOR, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
    RN_Grenade_ZeroNativeDamage(projectile);
    bool think = SDKHookEx(projectile, SDKHook_Think, RN_Grenade_BlockThink);
    bool touch = SDKHookEx(projectile, SDKHook_Touch, RN_Grenade_BlockTouch);
    bool startTouch = SDKHookEx(projectile, SDKHook_StartTouch, RN_Grenade_BlockTouch);
    int client = RN_Grenade_Resolve(context);
    if (client == 0 || (group >= 0 && (group >= RN_GRENADE_GROUPS || groupId == 0 ||
        g_Grenade_Groups[group].id != groupId || used >= RN_Grenade_Limit(group))))
        return RN_Grenade_CreateFailed(projectile, "creation_cancelled");
    if (context.branch == RN_BRANCH_PEACE && context.peaceDamage < 0.0)
        return RN_Grenade_CreateFailed(projectile, "peace_damage_overflow");
    if (!think) return RN_Grenade_CreateFailed(projectile, "hook_think_failed");
    if (!touch) return RN_Grenade_CreateFailed(projectile, "hook_touch_failed");
    if (!startTouch) return RN_Grenade_CreateFailed(projectile, "hook_starttouch_failed");
    int slot = -1;
    for (int i = 0; i < RN_GRENADE_PROJECTILES; i++)
        if (g_Grenade_Projectiles[i].ref == 0) { slot = i; break; }
    if (slot < 0) return RN_Grenade_CreateFailed(projectile, "projectile_capacity");
    if (group < 0)
    {
        for (int i = 0; i < RN_GRENADE_GROUPS; i++)
            if (g_Grenade_Groups[i].id == 0) { group = i; break; }
        if (group >= 0)
        {
            if (g_Grenade_NextId == RN_MAX_INT) return RN_Grenade_CreateFailed(projectile, "id_exhausted");
            g_Grenade_Groups[group].id = ++g_Grenade_NextId;
            g_Grenade_Groups[group].impacts = 0;
            g_Grenade_Groups[group].active = 0;
            g_Grenade_Groups[group].lastImpact = GetGameTime();
            g_Grenade_Owners[group] = context;
        }
    }
    if (group < 0) return RN_Grenade_CreateFailed(projectile, "group_capacity");
    g_Grenade_EntitySlot[projectile] = slot;
    g_Grenade_Projectiles[slot].ref = reference;
    g_Grenade_Projectiles[slot].group = group;
    g_Grenade_Projectiles[slot].groupId = g_Grenade_Groups[group].id;
    g_Grenade_Projectiles[slot].bornTick = GetGameTickCount();
    g_Grenade_Projectiles[slot].used = used;
    float eyeAngles[3];
    GetClientEyeAngles(client, eyeAngles);
    g_Grenade_Projectiles[slot].heading = DegToRad(eyeAngles[1]);
    for (int axis = 0; axis < 3; axis++)
    {
        g_Grenade_Projectiles[slot].position[axis] = position[axis];
        g_Grenade_Projectiles[slot].velocity[axis] = velocity[axis];
    }
    RN_Grenade_UpdateHeading(slot);
    g_Grenade_Groups[group].active++;
    g_Grenade_Active++;
    return true;
}

/** native返回后直接确认接管；同时有创建回调时保留已有速度、次数和hooks。 */
int RN_Grenade_Create(int client, const float position[3], const float angles[3], const float velocity[3], int group = -1, int used = 0)
{
    if (!RN_Grenade_Enabled(client)) return -1;
    bool previousCreating = g_Grenade_Creating;
    int previousGroup = g_Grenade_SpawnGroup, previousId = g_Grenade_SpawnGroupId, previousUsed = g_Grenade_SpawnUsed;
    RN_GrenadeContext previousContext, context;
    previousContext = g_Grenade_SpawnContext;
    if (group >= 0) context = g_Grenade_Owners[group];
    else RN_Grenade_Capture(client, context);
    int id = group >= 0 ? g_Grenade_Groups[group].id : 0;
    g_Grenade_Creating = true;
    g_Grenade_SpawnGroup = group;
    g_Grenade_SpawnGroupId = id;
    g_Grenade_SpawnUsed = used;
    g_Grenade_SpawnContext = context;
    float rotation[3];
    int entity = L4D2_GrenadeLauncherPrj(client, position, angles, velocity, rotation, false);
    g_Grenade_Creating = previousCreating;
    g_Grenade_SpawnGroup = previousGroup;
    g_Grenade_SpawnGroupId = previousId;
    g_Grenade_SpawnUsed = previousUsed;
    g_Grenade_SpawnContext = previousContext;
    float actualPosition[3], actualVelocity[3];
    actualPosition = position;
    actualVelocity = velocity;
    if (!RN_Grenade_Managed(entity) && entity > MaxClients && entity < RN_GRENADE_EDICTS && IsValidEntity(entity))
    {
        char classname[64];
        GetEntityClassname(entity, classname, sizeof(classname));
        if (StrEqual(classname, "grenade_launcher_projectile"))
        {
            GetEntPropVector(entity, Prop_Send, "m_vecOrigin", actualPosition);
            if (HasEntProp(entity, Prop_Data, "m_vecAbsVelocity"))
                GetEntPropVector(entity, Prop_Data, "m_vecAbsVelocity", actualVelocity);
        }
    }
    RN_Grenade_Adopt(entity, actualPosition, actualVelocity, context, group, id, used);
    return entity;
}

/** 存在的原生伤害与半径归零，核心保护仍是Think/Touch及引爆拦截。 */
void RN_Grenade_ZeroNativeDamage(int entity)
{
    static const char fields[][] = {"m_flDamage", "m_DmgRadius"};
    for (int i = 0; i < sizeof(fields); i++)
    {
        if (HasEntProp(entity, Prop_Send, fields[i])) SetEntPropFloat(entity, Prop_Send, fields[i], 0.0);
        else if (HasEntProp(entity, Prop_Data, fields[i])) SetEntPropFloat(entity, Prop_Data, fields[i], 0.0);
    }
}

/** EntRef校验防止同槽位后来创建的实体被旧回调操作。 */
bool RN_Grenade_Managed(int entity)
{
    return entity > MaxClients && entity < RN_GRENADE_EDICTS && g_Grenade_ManagedRef[entity] != 0 &&
        IsValidEntity(entity) && EntIndexToEntRef(entity) == g_Grenade_ManagedRef[entity];
}

/** 飞行、定时器和直接命中均不能产生残留原生爆炸。 */
public Action L4D2_GrenadeLauncher_Detonate(int entity, int client)
{
    return RN_Grenade_Managed(entity) ? Plugin_Handled : Plugin_Continue;
}

/** 受控弹只由插件帧推进，不执行原生引信。 */
public Action RN_Grenade_BlockThink(int entity) { return RN_Grenade_Managed(entity) ? Plugin_Handled : Plugin_Continue; }

/** 弹体穿过人物，地形碰撞由插件扫掠产生一次爆炸。 */
public Action RN_Grenade_BlockTouch(int entity, int other) { return RN_Grenade_Managed(entity) ? Plugin_Handled : Plugin_Continue; }

/** 接管失败的弹体下一帧安全移除，创建native仍可正常返回。 */
public void RN_Grenade_DiscardFrame(any reference)
{
    int entity = EntRefToEntIndex(reference);
    if (entity > MaxClients && RN_Grenade_Managed(entity)) RemoveEntity(entity);
}

/** 外部销毁仅注销账本，不读取已失效的实体属性。 */
void RN_Grenade_Destroyed(int entity)
{
    if (entity <= MaxClients || entity >= RN_GRENADE_EDICTS || g_Grenade_ManagedRef[entity] == 0) return;
    int slot = g_Grenade_EntitySlot[entity];
    if (slot >= 0 && g_Grenade_Projectiles[slot].ref == g_Grenade_ManagedRef[entity]) RN_Grenade_Unregister(slot);
    g_Grenade_ManagedRef[entity] = 0;
    g_Grenade_EntitySlot[entity] = -1;
}

/** 一个分支结束不扣其他分支的次数，只更新相同组身份的活动计数。 */
void RN_Grenade_Unregister(int slot)
{
    int group = g_Grenade_Projectiles[slot].group;
    if (g_Grenade_Projectiles[slot].ref == 0) return;
    if (g_Grenade_Groups[group].id == g_Grenade_Projectiles[slot].groupId)
    {
        g_Grenade_Groups[group].active--;
        if (g_Grenade_Groups[group].active == 0) g_Grenade_Groups[group].id = 0;
    }
    g_Grenade_Projectiles[slot].ref = 0;
    g_Grenade_Active--;
}

/** 先注销再删除，不在销毁回调重复扣数。 */
void RN_Grenade_Remove(int slot)
{
    int entity = EntRefToEntIndex(g_Grenade_Projectiles[slot].ref);
    RN_Grenade_Unregister(slot);
    if (entity > MaxClients && RN_Grenade_Managed(entity)) RemoveEntity(entity);
}

/** 生命周期取消清整组，取消不补爆炸。 */
void RN_Grenade_StopGroup(int group)
{
    int id = g_Grenade_Groups[group].id;
    if (id == 0) return;
    g_Grenade_Groups[group].id = 0;
    g_Grenade_Groups[group].active = 0;
    for (int slot = 0; slot < RN_GRENADE_PROJECTILES; slot++)
        if (g_Grenade_Projectiles[slot].ref != 0 && g_Grenade_Projectiles[slot].groupId == id) RN_Grenade_Remove(slot);
}

/** 停用、清档、换图和卸载移除受控弹，不改其他投掷物。 */
void RN_Grenade_Clear()
{
    for (int group = 0; group < RN_GRENADE_GROUPS; group++) RN_Grenade_StopGroup(group);
    for (int entity = MaxClients + 1; entity < RN_GRENADE_EDICTS; entity++)
        if (RN_Grenade_Managed(entity)) RemoveEntity(entity);
}

/** 出生、断线、托管和离队清理当前会话，不删除个人BUFF层数。 */
void RN_Grenade_Forget(int client)
{
    if (!RN_Common_Client(client)) return;
    int serial = GetClientSerial(client);
    for (int group = 0; group < RN_GRENADE_GROUPS; group++)
        if (g_Grenade_Groups[group].id != 0 && g_Grenade_Owners[group].serial == serial) RN_Grenade_StopGroup(group);
}

/** 热改只清已达到新上限的分支；提高次数不恢复已经结束的弹。 */
void RN_Grenade_ConfigApplied()
{
    if (!RN_Config_Enabled() || RN_Config_Int(RN_CVAR_GRENADE_ENABLE) == 0) { RN_Grenade_Clear(); return; }
    for (int slot = 0; slot < RN_GRENADE_PROJECTILES; slot++)
        if (g_Grenade_Projectiles[slot].ref != 0 &&
            g_Grenade_Projectiles[slot].used >= RN_Grenade_Limit(g_Grenade_Projectiles[slot].group)) RN_Grenade_Remove(slot);
}

/** 不推进同帧新分裂弹；空闲无查询，低帧率最多推进0.1秒避免穿地。 */
void RN_Grenade_Frame()
{
    float now = GetGameTime(), elapsed = now - g_Grenade_LastFrame;
    g_Grenade_LastFrame = now;
    if (g_Grenade_Active == 0) return;
    if (!RN_Config_Enabled() || RN_Config_Int(RN_CVAR_GRENADE_ENABLE) == 0) { RN_Grenade_Clear(); return; }
    if (elapsed <= 0.0) return;
    if (elapsed > 0.10) elapsed = 0.10;
    int tick = GetGameTickCount();
    for (int group = 0; group < RN_GRENADE_GROUPS; group++)
        if (g_Grenade_Groups[group].id != 0 && (RN_Grenade_Owner(group) == 0 ||
            now - g_Grenade_Groups[group].lastImpact >= RN_GRENADE_IDLE_TIMEOUT)) RN_Grenade_StopGroup(group);
    for (int slot = 0; slot < RN_GRENADE_PROJECTILES; slot++)
    {
        if (g_Grenade_Projectiles[slot].ref == 0 || g_Grenade_Projectiles[slot].bornTick == tick) continue;
        if (g_Grenade_Projectiles[slot].used >= RN_Grenade_Limit(g_Grenade_Projectiles[slot].group))
            { RN_Grenade_Remove(slot); continue; }
        int entity = EntRefToEntIndex(g_Grenade_Projectiles[slot].ref);
        if (entity <= MaxClients || !RN_Grenade_Managed(entity)) { RN_Grenade_Unregister(slot); continue; }
        RN_Grenade_Advance(slot, elapsed);
    }
}
