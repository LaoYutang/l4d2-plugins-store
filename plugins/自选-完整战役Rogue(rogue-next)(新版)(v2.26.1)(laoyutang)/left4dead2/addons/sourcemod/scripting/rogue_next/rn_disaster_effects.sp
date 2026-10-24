#if defined _rn_disaster_effects_included
 #endinput
#endif
#define _rn_disaster_effects_included

#define RN_DISASTER_NPC_CVARS 4
static const char g_Disaster_NPCNames[][] = {
    "z_speed", "z_walk_speed", "z_witch_speed", "z_witch_speed_inured"
};
ConVar g_Disaster_NPCHandles[RN_DISASTER_NPC_CVARS];
float g_Disaster_NPCBase[RN_DISASTER_NPC_CVARS], g_Disaster_NPCOwned[RN_DISASTER_NPC_CVARS];
bool g_Disaster_NPCTouched[RN_DISASTER_NPC_CVARS], g_Disaster_NPCWriting;

/** 只捕获NPC已有速度参数；不写玩家属性或引入逐帧实体扫描。 */
void RN_Disaster_Init()
{
    for (int i = 0; i < RN_DISASTER_NPC_CVARS; i++)
    {
        g_Disaster_NPCHandles[i] = FindConVar(g_Disaster_NPCNames[i]);
        if (g_Disaster_NPCHandles[i] != null) g_Disaster_NPCHandles[i].AddChangeHook(RN_Disaster_NPCChanged);
        else LogError("[rogue-next] 季风缺少NPC速度参数%s，该灾害不参与抽取。", g_Disaster_NPCNames[i]);
    }
}

/** 全部NPC通道存在才允许抽取季风，不能只加速特感冒充全体。 */
bool RN_Disaster_NPCReady()
{
    for (int i = 0; i < RN_DISASTER_NPC_CVARS; i++)
    {
        if (g_Disaster_NPCHandles[i] == null) return false;
        float value = g_Disaster_NPCHandles[i].FloatValue;
        if (!RN_Math_Finite(value) || value < 0.0 || !RN_Math_Finite(value * 1.5)) return false;
    }
    return true;
}

/** 自己写入时不重捕获；外部覆盖后取消字段所有权，关停不得写回旧值。 */
public void RN_Disaster_NPCChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (g_Disaster_NPCWriting) return;
    for (int i = 0; i < RN_DISASTER_NPC_CVARS; i++)
        if (g_Disaster_NPCHandles[i] == convar && g_Disaster_NPCTouched[i])
            g_Disaster_NPCOwned[i] = -1.0;
}

/** 每章节一次基线乘算；撤销只恢复仍等于自己上次写入的字段。 */
void RN_Disaster_NPCSync(bool enable)
{
    g_Disaster_NPCWriting = true;
    for (int i = 0; i < RN_DISASTER_NPC_CVARS; i++)
    {
        ConVar cvar = g_Disaster_NPCHandles[i];
        if (cvar == null) continue;
        float current = cvar.FloatValue;
        if (enable)
        {
            if (g_Disaster_NPCTouched[i]) continue;
            float next = current * (1.0 + g_Disaster_Amount);
            if (!RN_Math_Finite(next) || next < 0.0) continue;
            g_Disaster_NPCBase[i] = current;
            g_Disaster_NPCOwned[i] = next;
            g_Disaster_NPCTouched[i] = true;
            cvar.SetFloat(next);
        }
        else if (g_Disaster_NPCTouched[i])
        {
            if (g_Disaster_NPCOwned[i] >= 0.0 && FloatAbs(current - g_Disaster_NPCOwned[i]) < 0.0001)
                cvar.SetFloat(g_Disaster_NPCBase[i]);
            g_Disaster_NPCTouched[i] = false;
            g_Disaster_NPCBase[i] = 0.0; g_Disaster_NPCOwned[i] = 0.0;
        }
    }
    g_Disaster_NPCWriting = false;
}

/** 季风只修改特感地面走跑查询；空中、冻结、幽灵及冲锋动作放行。 */
Action RN_Disaster_InfectedSpeed(int client, float &speed, bool globalWalk = false)
{
    if (!RN_Disaster_Active() || g_Disaster_Type != RN_DISASTER_MONSOON ||
        !RN_Common_Infected(client) || !IsPlayerAlive(client) ||
        GetEntProp(client, Prop_Send, "m_isGhost") != 0 || RN_FX_Frozen(client) ||
        (GetEntityFlags(client) & FL_ONGROUND) == 0 || speed <= 0.0 || !RN_Math_Finite(speed)) return Plugin_Continue;
    int ability = GetEntPropEnt(client, Prop_Send, "m_customAbility");
    if (ability > MaxClients && IsValidEntity(ability) &&
        HasEntProp(ability, Prop_Send, "m_isCharging") && GetEntProp(ability, Prop_Send, "m_isCharging") != 0)
        return Plugin_Continue;
    // z_walk_speed同时是特感步行的引擎基线，已全局乘算时不能再乘一次。
    if (globalWalk && g_Disaster_NPCTouched[1] && g_Disaster_NPCOwned[1] >= 0.0 &&
        FloatAbs(g_Disaster_NPCHandles[1].FloatValue - g_Disaster_NPCOwned[1]) < 0.0001)
        return Plugin_Continue;
    float next = speed * (1.0 + g_Disaster_Amount);
    if (!RN_Math_Finite(next)) return Plugin_Continue;
    speed = next;
    return Plugin_Handled;
}

/** 引擎奔跑最大速度仅乘一次季风，不写Tank原有时间快照。 */
public Action L4D_OnGetRunTopSpeed(int client, float &speed) { return RN_Disaster_InfectedSpeed(client, speed); }

/** 步行使用相同季风规则，保留技能动作和引擎原基线。 */
public Action L4D_OnGetWalkTopSpeed(int client, float &speed) { return RN_Disaster_InfectedSpeed(client, speed, true); }

/** 蹲走属于地面移动，不改变扑击或跳跃速度。 */
public Action L4D_OnGetCrouchTopSpeed(int client, float &speed) { return RN_Disaster_InfectedSpeed(client, speed); }

/** 只对实际分类的感染者承伤套用一次抗性，不猜测普通GENERIC来源。 */
float RN_Disaster_AttackFactor(int victim, int type, int inflictor = -1, int weapon = -1)
{
    if (!RN_Disaster_Active() || (!RN_Common_Infected(victim) && !RN_Common_Zombie(victim))) return 1.0;
    if ((type & (DMG_BULLET | DMG_BUCKSHOT | DMG_SLASH | DMG_CLUB | DMG_BLAST)) != 0)
        return RN_Disaster_DamageFactor(false);
    if ((type & (DMG_BURN | DMG_SLOWBURN)) != 0) return RN_Disaster_DamageFactor(true);
    int source = weapon > MaxClients && IsValidEntity(weapon) ? weapon : inflictor;
    if (source > MaxClients && IsValidEntity(source))
    {
        char classname[64]; GetEntityClassname(source, classname, sizeof(classname));
        if (StrEqual(classname, "weapon_melee") || StrEqual(classname, "weapon_chainsaw") ||
            StrEqual(classname, "weapon_grenade_launcher") || StrEqual(classname, "grenade_launcher_projectile") ||
            StrEqual(classname, "pipe_bomb_projectile") || RN_Weapons_Index(source) >= 0)
            return RN_Disaster_DamageFactor(false);
    }
    return 1.0;
}

/** 临时血先扣，实血最低1；小数留待下一笔，触底欠款作废。 */
void RN_Disaster_Drain(int client, float amount)
{
    int health = GetEntProp(client, Prop_Data, "m_iHealth");
    float temporary = L4D_GetTempHealth(client);
    if (health < 1 || !RN_Math_Finite(temporary) || temporary < 0.0 ||
        !RN_Math_Finite(amount) || amount < 0.0 || amount >= RN_INT_FLOAT_LIMIT)
    {
        g_Disaster_ClientCarry[client] = 0.0;
        LogError("[rogue-next] 天罚拒绝异常血量或金额 client=%d。", client);
        return;
    }
    float fromTemporary = temporary < amount ? temporary : amount;
    if (fromTemporary > 0.0) L4D_SetTempHealth(client, temporary - fromTemporary);
    float real = amount - fromTemporary;
    int loss = RoundToFloor(real);
    int available = health - 1;
    if (loss >= available)
    {
        loss = available;
        g_Disaster_ClientCarry[client] = 0.0;
    }
    else g_Disaster_ClientCarry[client] = real - float(loss);
    if (loss > 0) SetEntProp(client, Prop_Data, "m_iHealth", health - loss);
}

/** 复用一秒调度，出门满一秒才扣；无效状态、暂停或新身份不追补。 */
void RN_Disaster_Tick()
{
    float now = GetTickedTime();
    bool running = RN_Disaster_Active() && g_Disaster_Type == RN_DISASTER_PUNISHMENT &&
        g_Disaster_Departed && RN_Common_HasHuman() && !RN_Clock_ShouldPause();
    if (running && now - g_Disaster_DepartureAt < 1.0) return;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!RN_Common_Survivor(client) || !IsPlayerAlive(client) || RN_Common_Incapacitated(client) || !running)
        {
            RN_Disaster_ClientBirth(client);
            continue;
        }
        if (g_Disaster_ClientSerial[client] != GetClientSerial(client) ||
            g_Disaster_ClientLife[client] != g_Common_Life[client])
        {
            RN_Disaster_ClientBirth(client);
            continue;
        }
        float elapsed = now - g_Disaster_ClientLast[client];
        if (elapsed < 1.0) continue;
        if (!RN_Math_Finite(elapsed) || elapsed >= RN_INT_FLOAT_LIMIT)
        {
            RN_Disaster_ClientBirth(client);
            continue;
        }
        int seconds = RoundToFloor(elapsed);
        g_Disaster_ClientLast[client] += float(seconds);
        RN_Disaster_Drain(client, g_Disaster_ClientCarry[client] + g_Disaster_Amount * float(seconds));
    }
}
