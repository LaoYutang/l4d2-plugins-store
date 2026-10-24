#if defined _rn_element_shots_included
 #endinput
#endif
#define _rn_element_shots_included

/** 当前射击身份；真实弹片数与已排队任务分别登记，目标身份含EntRef/生命。 */
enum struct RN_ElementShot
{
    int serial;
    int life;
    int runEpoch;
    int mapEpoch;
    int tick;
}
RN_ElementShot g_ElementShot_State[MAXPLAYERS + 1];
StringMap g_ElementShot_Targets[MAXPLAYERS + 1];
StringMap g_ElementShot_Traces[MAXPLAYERS + 1];

/** 开枪清当前登记并复用容器；生命周期结束释放两个容器的所有权。 */
void RN_ElementShot_ResetClient(int client, bool release = true)
{
    if (client < 1 || client > MaxClients) return;
    if (release)
    {
        RN_Element_CancelShots(client);
        delete g_ElementShot_Targets[client];
        delete g_ElementShot_Traces[client];
    }
    else
    {
        if (g_ElementShot_Targets[client] != null) g_ElementShot_Targets[client].Clear();
        if (g_ElementShot_Traces[client] != null) g_ElementShot_Traces[client].Clear();
    }
    g_ElementShot_State[client].serial = 0;
}

/** 清档、关停、跨图与卸载释放短期记录，不修改成长或已经生成的伤害。 */
void RN_ElementShot_Clear()
{
    for (int client = 1; client <= MaxClients; client++) RN_ElementShot_ResetClient(client);
}

/** 正式开枪事件划分每枪；不取消上一枪已经排队的有效元素命中。 */
public void RN_ElementShot_OnFire(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (RN_Common_Survivor(client) && IsPlayerAlive(client)) RN_ElementShot_ResetClient(client, false);
}

/** 获取每枪目标键和任务ID；非枪械键为空，已完成为-1，未入队为0。 */
int RN_ElementShot_Pending(int victim, int attacker, int inflictor, int weapon, int type,
                           char[] key, int maxlength)
{
    key[0] = '\0';
    int source = RN_Profession_GunSource(attacker, inflictor, weapon, type);
    if (RN_Weapons_Index(source) < 0) return 0;
    int serial = GetClientSerial(attacker), life = g_Common_Life[attacker];
    int tick = GetGameTickCount(), weaponRef = EntIndexToEntRef(source);
    RN_ElementShot state;
    state = g_ElementShot_State[attacker];
    if (state.serial != serial || state.life != life || state.runEpoch != g_Run_Epoch ||
        state.mapEpoch != g_Run_MapEpoch || state.tick != tick)
    {
        RN_ElementShot_ResetClient(attacker, false);
        if (g_ElementShot_Targets[attacker] == null) g_ElementShot_Targets[attacker] = new StringMap();
        state.serial = serial;
        state.life = life;
        state.runEpoch = g_Run_Epoch;
        state.mapEpoch = g_Run_MapEpoch;
        state.tick = tick;
        g_ElementShot_State[attacker] = state;
    }
    int targetLife = RN_Common_Client(victim) ? g_Common_Life[victim] : 0;
    FormatEx(key, maxlength, "%d:%d:%d", weaponRef, EntIndexToEntRef(victim), targetLife);
    int id;
    g_ElementShot_Targets[attacker].GetValue(key, id);
    return id;
}

/** 只登记有效枪械任务；近战等原有逐次命中路径不进入射击登记。 */
void RN_ElementShot_Record(int attacker, const char[] key, int id)
{
    if (key[0] != '\0') g_ElementShot_Targets[attacker].SetValue(key, id);
}

/** 读取真实命中弹片数；未收到TraceAttack时由实际伤害回调次数兼容。 */
int RN_ElementShot_Count(int attacker, const char[] key)
{
    int count;
    if (g_ElementShot_Traces[attacker] != null) g_ElementShot_Traces[attacker].GetValue(key, count);
    return count;
}

/** TraceAttack只累计机会；必须随后有实际正伤害回调才允许入队。 */
int RN_ElementShot_Trace(int attacker, const char[] key)
{
    if (g_ElementShot_Traces[attacker] == null) g_ElementShot_Traces[attacker] = new StringMap();
    int count = RN_ElementShot_Count(attacker, key);
    if (count < RN_MAX_INT) g_ElementShot_Traces[attacker].SetValue(key, ++count);
    return count;
}

/** 旧帧任务只能完成自己的ID，不能把下一枪或新生命的同键任务标成完成。 */
void RN_ElementShot_Complete(int ownerSerial, const char[] key, int id)
{
    int owner = GetClientFromSerial(ownerSerial), current;
    if (key[0] == '\0' || owner < 1 || g_ElementShot_Targets[owner] == null) return;
    if (g_ElementShot_Targets[owner].GetValue(key, current) && current == id)
        g_ElementShot_Targets[owner].SetValue(key, -1);
}
