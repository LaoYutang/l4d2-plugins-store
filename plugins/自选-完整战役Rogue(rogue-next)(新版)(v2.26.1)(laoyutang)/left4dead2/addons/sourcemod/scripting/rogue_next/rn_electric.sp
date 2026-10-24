#if defined _rn_electric_included
 #endinput
#endif
#define _rn_electric_included

/** 每人一条有界电链；原点与火焰载荷不依赖首目标继续存活或持有灼烧。 */
enum struct RN_ElectricChain
{
    int id;
    int ownerSerial;
    int ownerLife;
    int run;
    int map;
    int used;
    int jumps;
    float damage;
    float decay;
    bool thunder;
    int targetBranch;
    float radius;
    float interval;
    float origin[3];
    RN_FXRecord last;
    int refs[RN_ELECTRIC_MAX_JUMPS + 1];
    int serials[RN_ELECTRIC_MAX_JUMPS + 1];
    int lives[RN_ELECTRIC_MAX_JUMPS + 1];
    bool carriesFire;
    RN_BurnRecord fire;
}
RN_ElectricChain g_Electric_Chains[MAXPLAYERS + 1];
Handle g_Electric_Timers[MAXPLAYERS + 1];
float g_Electric_NextUse[MAXPLAYERS + 1];
int g_Electric_NextID;
int g_Electric_Sprite;

/** 延迟触发仍复核当前职业资格，不能在改选剑客或狙神后沿用旧元素任务。 */
bool RN_Electric_ProfessionAllowed(int client)
{
    PlayerProfile profile;
    return RN_Profile_Get(g_Profile_Index[client], profile) && !RN_Profession_NoElements(profile);
}

/** 结束本玩家电链；保留已消费的触发冷却，不改变已经传播的灼烧。 */
void RN_Electric_Stop(int client)
{
    if (client < 1 || client > MaxClients) return;
    g_Electric_Chains[client].id = 0;
    delete g_Electric_Timers[client];
}

/** 玩家离线、死亡、转队或BOT接管清理自己拥有的电链与短期冷却。 */
void RN_Electric_Forget(int entity)
{
    if (entity < 1 || entity > MaxClients) return;
    int serial = RN_Common_Client(entity) ? GetClientSerial(entity) : 0;
    for (int client = 1; client <= MaxClients; client++)
        if (serial != 0 && g_Electric_Chains[client].fire.ownerSerial == serial)
            g_Electric_Chains[client].carriesFire = false;
    RN_Electric_Stop(entity);
    g_Electric_NextUse[entity] = 0.0;
}

/** 换图、重开、配置热改、关停与卸载撤销全部延迟电链。 */
void RN_Electric_Clear()
{
    for (int client = 1; client <= MaxClients; client++) RN_Electric_Forget(client);
}

/** 原版光束无需下载，所有电弧只绘制于两个敌人的身体之间。 */
void RN_Electric_MapStart()
{
    RN_Electric_Clear();
    g_Electric_Sprite = PrecacheModel("sprites/laserbeam.vmt", true);
}

/** 每次SDK前后核对电链代次、会话、生命及战役地图，不继承旧拥有者。 */
bool RN_Electric_Valid(int client, int id)
{
    return client > 0 && client <= MaxClients && id > 0 && g_Electric_Chains[client].id == id
        && RN_Config_Enabled() && RN_Config_Int(RN_CVAR_ELECTRIC_ENABLE) != 0
        && RN_Common_Survivor(client) && !IsFakeClient(client) && IsPlayerAlive(client)
        && RN_Electric_ProfessionAllowed(client)
        && GetClientSerial(client) == g_Electric_Chains[client].ownerSerial
        && g_Common_Life[client] == g_Electric_Chains[client].ownerLife
        && g_Run_Epoch == g_Electric_Chains[client].run && g_Run_MapEpoch == g_Electric_Chains[client].map;
}

/** 同一目标生命只受本链一次伤害；客户端复活、重连及NPC复用均用完整身份。 */
bool RN_Electric_Visited(RN_ElectricChain chain, int entity)
{
    int ref = EntIndexToEntRef(entity);
    int serial = RN_Common_Client(entity) ? GetClientSerial(entity) : 0;
    int life = serial != 0 ? g_Common_Life[entity] : 0;
    for (int i = 0; i < chain.used; i++)
        if (chain.refs[i] == ref && chain.serials[i] == serial && chain.lives[i] == life) return true;
    return false;
}

/** 雷电允许回到旧敌人，但本次不能选当前节点；普通链保持完整身份去重。 */
void RN_Electric_Consider(RN_ElectricChain chain, int entity, int &result, float &best)
{
    if (!RN_Burn_Living(entity)) return;
    if (chain.thunder ? RN_FX_Resolve(chain.last) == entity : RN_Electric_Visited(chain, entity)) return;
    float origin[3];
    RN_Element_Origin(entity, origin);
    float distance = GetVectorDistance(chain.origin, origin, true);
    if (distance > best || (result != 0 && distance == best) || !RN_Element_Visible(chain.origin, origin)) return;
    best = distance;
    result = entity;
}

/** 每跳只枚举玩家及两类感染者，避免对全实体容量反复调用属性native。 */
int RN_Electric_Nearest(RN_ElectricChain chain)
{
    if (chain.radius <= 0.0) return 0;
    int result;
    float best = chain.radius * chain.radius;
    for (int client = 1; client <= MaxClients; client++) RN_Electric_Consider(chain, client, result, best);
    static const char classes[][] = {"infected", "witch"};
    for (int i = 0; i < sizeof(classes); i++)
    {
        int entity = -1;
        while ((entity = FindEntityByClassname(entity, classes[i])) != -1)
            RN_Electric_Consider(chain, entity, result, best);
    }
    return result;
}

/** 复用验证插件的蓝白细电弧与火花，有限寿命，不存在枪口到首目标光束。 */
void RN_Electric_Draw(const float from[3], const float to[3])
{
    if (g_Electric_Sprite <= 0) return;
    float start[3], end[3];
    for (int i = 0; i < 3; i++) { start[i] = from[i]; end[i] = to[i]; }
    start[2] += 36.0;
    end[2] += 36.0;
    int blue[4] = {35, 135, 255, 230}, white[4] = {190, 225, 255, 255};
    TE_SetupBeamPoints(start, end, g_Electric_Sprite, 0, 0, 0, 0.20, 4.0, 2.0, 0, 12.0, blue, 10);
    TE_SendToAll();
    TE_SetupBeamPoints(start, end, g_Electric_Sprite, 0, 0, 0, 0.20, 1.2, 0.6, 0, 8.0, white, 10);
    TE_SendToAll();
    float direction[3] = {0.0, 0.0, 1.0};
    TE_SetupSparks(end, direction, 2, 1);
    TE_SendToAll();
}

/** 只为仍有正伤害与弹射预算的当前链排下一跳，句柄由玩家槽位明确持有。 */
void RN_Electric_Schedule(int client, int id)
{
    if (!RN_Electric_Valid(client, id))
    {
        if (g_Electric_Chains[client].id == id) RN_Electric_Stop(client);
        return;
    }
    if (g_Electric_Chains[client].used > g_Electric_Chains[client].jumps
        || g_Electric_Chains[client].radius <= 0.0
        || RN_Branch_ElectricDamage(g_Electric_Chains[client].damage, g_Electric_Chains[client].used,
            g_Electric_Chains[client].thunder, g_Electric_Chains[client].decay) <= 0.0)
    { RN_Electric_Stop(client); return; }
    DataPack pack;
    g_Electric_Timers[client] = CreateDataTimer(g_Electric_Chains[client].interval, RN_Electric_OnTimer, pack, TIMER_FLAG_NO_MAPCHANGE);
    pack.WriteCell(client);
    pack.WriteCell(id);
}

/** 先登记命中再伤害；SDK后重新查链和双方身份，弱火不覆盖或续满强火。 */
void RN_Electric_Hit(int client, int id, int entity)
{
    if (!RN_Electric_Valid(client, id) || !RN_Burn_Living(entity)) return;
    RN_ElectricChain chain;
    chain = g_Electric_Chains[client];
    float damage = RN_Branch_ElectricDamage(chain.damage, chain.used, chain.thunder, chain.decay);
    if (!RN_Math_Finite(damage) || damage <= 0.0 || chain.used > chain.jumps || chain.used > RN_ELECTRIC_MAX_JUMPS)
    { RN_Electric_Stop(client); return; }
    RN_FXRecord target;
    RN_FX_Identity(entity, target);
    float origin[3];
    RN_Element_Origin(entity, origin);
    if (chain.used > 0) RN_Electric_Draw(chain.origin, origin);
    chain.refs[chain.used] = target.ref;
    chain.serials[chain.used] = target.serial;
    chain.lives[chain.used] = target.life;
    chain.used++;
    chain.last = target;
    for (int i = 0; i < 3; i++) chain.origin[i] = origin[i];
    g_Electric_Chains[client] = chain;
    if (RN_Config_Int(RN_CVAR_DEBUG) != 0)
        LogToFileEx(g_Burn_Log, "[Rogue] electric id=%d hop=%d ref=%d owner=%d damage=%.3f", id, chain.used - 1, target.ref, chain.ownerSerial, damage);
    RN_Burn_Damage(entity, client, damage, true, RN_ADDED_SETTLED_ELEMENT, chain.targetBranch);
    if (!RN_Electric_Valid(client, id))
    {
        if (g_Electric_Chains[client].id == id) RN_Electric_Stop(client);
        return;
    }
    if (chain.used > 1 && g_Electric_Chains[client].carriesFire && RN_Config_Int(RN_CVAR_ELECTRIC_FIRE_ENABLE) != 0
        && RN_FX_Resolve(target) == entity && RN_Burn_Living(entity))
    {
        int fireOwner = RN_Burn_Owner(chain.fire);
        float factor = chain.thunder ? RN_Branch_ElectricDamage(1.0, chain.used - 1, true, chain.decay)
            : (chain.fire.payloadDps > 0.0 ? chain.fire.dps / chain.fire.payloadDps : 1.0);
        if (fireOwner > 0) RN_Burn_Start(entity, fireOwner, chain.fire.payloadDps,
            chain.fire.duration, true, chain.fire.targetBranch, factor);
        else g_Electric_Chains[client].carriesFire = false;
    }
    RN_Electric_Schedule(client, id);
}

/** 定时器先解除槽位句柄，旧任务不能清除新链；前节点死亡仍用最后命中位置。 */
public Action RN_Electric_OnTimer(Handle timer, DataPack pack)
{
    pack.Reset();
    int client = pack.ReadCell(), id = pack.ReadCell();
    if (client < 1 || client > MaxClients || timer != g_Electric_Timers[client]
        || g_Electric_Chains[client].id != id) return Plugin_Stop;
    g_Electric_Timers[client] = null;
    if (!RN_Electric_Valid(client, id))
    {
        if (g_Electric_Chains[client].id == id) RN_Electric_Stop(client);
        return Plugin_Stop;
    }
    RN_ElectricChain chain;
    chain = g_Electric_Chains[client];
    int last = RN_FX_Resolve(chain.last);
    if (last > 0 && RN_Burn_Living(last)) RN_Element_Origin(last, chain.origin);
    g_Electric_Chains[client] = chain;
    int target = RN_Electric_Nearest(chain);
    if (target > 0) RN_Electric_Hit(client, id, target);
    else RN_Electric_Stop(client);
    return Plugin_Stop;
}

/** 所有起点共用冷却、当前职业、伤害和有界次数；死亡起点也占用正常冷却。 */
bool RN_Electric_Begin(int client, float damage, int jumps, RN_ElectricChain chain, bool thunder = false, int targetBranch = -1)
{
    if (!RN_Config_Enabled() || RN_Config_Int(RN_CVAR_ELECTRIC_ENABLE) == 0
        || !RN_Common_Survivor(client) || IsFakeClient(client) || !IsPlayerAlive(client)
        || !RN_Electric_ProfessionAllowed(client)
        || g_Electric_Chains[client].id != 0 || GetTickedTime() < g_Electric_NextUse[client]) return false;
    damage *= RN_Disaster_DamageFactor(true);
    if (damage <= 0.0 || !RN_Math_Finite(damage) || damage >= RN_INT_FLOAT_LIMIT) return false;
    float until = GetTickedTime() + RN_Config_Float(RN_CVAR_ELECTRIC_COOLDOWN);
    if (!RN_Math_Finite(until)) return false;
    if (g_Electric_NextID == RN_MAX_INT) { SetFailState("电链代次耗尽，请重载Rogue。"); return false; }
    chain.id = ++g_Electric_NextID;
    chain.ownerSerial = GetClientSerial(client);
    chain.ownerLife = g_Common_Life[client];
    chain.run = g_Run_Epoch;
    chain.map = g_Run_MapEpoch;
    chain.damage = damage;
    chain.jumps = jumps < 0 ? 0 : (jumps > RN_ELECTRIC_MAX_JUMPS ? RN_ELECTRIC_MAX_JUMPS : jumps);
    chain.decay = RN_Config_Float(RN_CVAR_ELECTRIC_DECAY);
    chain.thunder = thunder;
    chain.targetBranch = targetBranch < 0 ? RN_Branch_Get(client) : targetBranch;
    float lastDamage = RN_Branch_ElectricDamage(damage, chain.jumps, thunder, chain.decay);
    float maximum = lastDamage > damage ? lastDamage : damage;
    if (chain.targetBranch == RN_BRANCH_DEATH) maximum *= 2.0;
    if (!RN_Math_Finite(maximum) || maximum >= RN_INT_FLOAT_LIMIT) return false;
    chain.radius = RN_Config_Float(RN_CVAR_ELECTRIC_RADIUS);
    chain.interval = RN_Config_Float(RN_CVAR_ELECTRIC_INTERVAL);
    g_Electric_NextUse[client] = until;
    return true;
}

/** 火先完成后保存完整载荷，首击前固定全链倍率；冰随后爆炸不撤回已保存的火。 */
void RN_Electric_Start(int entity, int client, float damage, int jumps, bool thunder = false, int targetBranch = -1)
{
    if (!RN_Burn_Living(entity)) return;
    RN_ElectricChain chain;
    if (!RN_Electric_Begin(client, damage, jumps, chain, thunder, targetBranch)) return;
    if (RN_Burn_Get(entity, chain.fire)) RN_Electric_Carry(chain);
    g_Electric_Chains[client] = chain;
    RN_Electric_Hit(client, chain.id, entity);
}

/** 检查原点燃者和完整载荷；额外火伤不预乘电伤或元素抗性。 */
void RN_Electric_Carry(RN_ElectricChain chain)
{
    chain.carriesFire = RN_Config_Int(RN_CVAR_ELECTRIC_FIRE_ENABLE) != 0 && RN_Burn_Owner(chain.fire) > 0
        && chain.fire.duration > 0.0 && chain.fire.dps >= 0.0 && RN_Math_Finite(chain.fire.dps * chain.fire.duration)
        && chain.fire.payloadDps >= 0.0 && RN_Math_Finite(chain.fire.payloadDps)
        && chain.fire.dps * chain.fire.duration < RN_INT_FLOAT_LIMIT;
}

/** 致死命中保留敌人原点和首击名额；只排170/140等后续跳，不补伤尸体。 */
void RN_Electric_StartDead(RN_ElementHit hit, int client)
{
    RN_ElectricChain chain;
    if (!RN_Electric_Begin(client, hit.electricDamage, hit.electricJumps, chain, hit.thunder, hit.targetBranch)) return;
    chain.used = 1;
    chain.last = hit.target;
    chain.last.ref = INVALID_ENT_REFERENCE;
    chain.refs[0] = hit.target.ref;
    chain.serials[0] = hit.target.serial;
    chain.lives[0] = hit.target.life;
    for (int i = 0; i < 3; i++) chain.origin[i] = hit.origin[i];
    if (hit.hasBurn) { chain.fire = hit.burn; RN_Electric_Carry(chain); }
    g_Electric_Chains[client] = chain;
    if (RN_Config_Int(RN_CVAR_DEBUG) != 0)
        LogToFileEx(g_Burn_Log, "[Rogue] electric_dead id=%d ref=%d owner=%d damage=%.3f jumps=%d radius=%.1f", chain.id, hit.target.ref, chain.ownerSerial, chain.damage, chain.jumps, chain.radius);
    RN_Electric_Schedule(client, chain.id);
}
