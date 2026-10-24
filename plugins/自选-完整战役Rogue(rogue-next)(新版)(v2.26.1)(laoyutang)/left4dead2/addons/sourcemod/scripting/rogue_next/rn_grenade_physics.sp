#if defined _rn_grenade_physics_included
 #endinput
#endif
#define _rn_grenade_physics_included

/** 地面、墙、顶、门和实物参与碰撞；人物与其他弹体不作为碰撞表面。 */
public bool RN_Grenade_WorldFilter(int entity, int mask, any data)
{
    if (entity == 0) return true;
    if (entity <= MaxClients || RN_Grenade_Managed(entity)) return false;
    char classname[64];
    GetEntityClassname(entity, classname, sizeof(classname));
    return !StrEqual(classname, "infected") && !StrEqual(classname, "witch") &&
        !StrEqual(classname, "grenade_launcher_projectile");
}

/** 插件重力与小步 hull 扫掠；与引爆回调次数无关。 */
void RN_Grenade_Advance(int slot, float elapsed)
{
    float gravity = g_Grenade_Gravity != null ? g_Grenade_Gravity.FloatValue : 800.0;
    while (elapsed > 0.00001 && g_Grenade_Projectiles[slot].ref != 0)
    {
        float step = elapsed > 0.02 ? 0.02 : elapsed;
        elapsed -= step;
        g_Grenade_Projectiles[slot].velocity[2] -= gravity * step;
        RN_Grenade_MoveStep(slot, step);
    }
    if (g_Grenade_Projectiles[slot].ref == 0) return;
    int entity = EntRefToEntIndex(g_Grenade_Projectiles[slot].ref);
    if (entity <= MaxClients || !RN_Grenade_Managed(entity)) return;
    float angles[3];
    GetVectorAngles(g_Grenade_Projectiles[slot].velocity, angles);
    TeleportEntity(entity, g_Grenade_Projectiles[slot].position, angles, NULL_VECTOR);
}

/** 保留碰撞后的剩余时间；最多四次接触后丢弃本小步余量，避免卡角死循环。 */
void RN_Grenade_MoveStep(int slot, float step)
{
    static const float mins[3] = {-2.0, -2.0, -2.0};
    static const float maxs[3] = {2.0, 2.0, 2.0};
    for (int contact = 0; contact < 4 && step > 0.00001; contact++)
    {
        float end[3];
        for (int axis = 0; axis < 3; axis++)
            end[axis] = g_Grenade_Projectiles[slot].position[axis] + g_Grenade_Projectiles[slot].velocity[axis] * step;
        Handle trace = TR_TraceHullFilterEx(g_Grenade_Projectiles[slot].position, end, mins, maxs, MASK_SOLID, RN_Grenade_WorldFilter);
        bool stuck = TR_StartSolid(trace) || TR_AllSolid(trace);
        bool hit = TR_DidHit(trace);
        float fraction = TR_GetFraction(trace);
        float normal[3];
        if (hit && !stuck)
        {
            TR_GetEndPosition(g_Grenade_Projectiles[slot].position, trace);
            TR_GetPlaneNormal(trace, normal);
        }
        delete trace;
        if (stuck) { RN_Grenade_Remove(slot); return; }
        if (!hit)
        {
            for (int axis = 0; axis < 3; axis++) g_Grenade_Projectiles[slot].position[axis] = end[axis];
            return;
        }
        for (int axis = 0; axis < 3; axis++) g_Grenade_Projectiles[slot].position[axis] += normal[axis] * 0.5;
        float incoming = GetVectorDotProduct(g_Grenade_Projectiles[slot].velocity, normal);
        if (incoming < -0.01)
        {
            if (!RN_Grenade_Impact(slot)) return;
            if (normal[2] >= 0.55 && g_Grenade_Projectiles[slot].velocity[2] <= 0.0)
            {
                g_Grenade_Projectiles[slot].velocity[0] *= RN_Config_Float(RN_CVAR_GRENADE_RETENTION);
                g_Grenade_Projectiles[slot].velocity[1] *= RN_Config_Float(RN_CVAR_GRENADE_RETENTION);
                g_Grenade_Projectiles[slot].velocity[2] = RN_Config_Float(RN_CVAR_GRENADE_BOUNCE_SPEED);
                // 高速撞斜坡后也必须离开接触面，不能向坡内继续移动并重复计数。
                float exiting = GetVectorDotProduct(g_Grenade_Projectiles[slot].velocity, normal);
                float minimum = RN_Config_Float(RN_CVAR_GRENADE_BOUNCE_SPEED) * normal[2];
                if (exiting < minimum)
                    for (int axis = 0; axis < 3; axis++)
                        g_Grenade_Projectiles[slot].velocity[axis] += (minimum - exiting) * normal[axis];
            }
            else
            {
                for (int axis = 0; axis < 3; axis++)
                    g_Grenade_Projectiles[slot].velocity[axis] -= 1.8 * incoming * normal[axis];
            }
            // 分裂围绕弹跳后的水平前进方向；原生重复 Touch/Think 不参与计数。
            RN_Grenade_UpdateHeading(slot);
            RN_Grenade_Split(slot, normal);
        }
        step *= 1.0 - fraction;
        if (g_Grenade_Projectiles[slot].ref == 0) return;
    }
}

/** 先消费本分支次数再执行伤害；末次碰撞只结束当前弹体。 */
bool RN_Grenade_Impact(int slot)
{
    int group = g_Grenade_Projectiles[slot].group, id = g_Grenade_Projectiles[slot].groupId;
    int reference = g_Grenade_Projectiles[slot].ref;
    if (g_Grenade_Groups[group].id != id || RN_Grenade_Owner(group) == 0) { RN_Grenade_Remove(slot); return false; }
    if (g_Grenade_Projectiles[slot].used >= RN_Grenade_Limit(group)) { RN_Grenade_Remove(slot); return false; }
    g_Grenade_Projectiles[slot].used++;
    g_Grenade_Groups[group].impacts++;
    g_Grenade_Groups[group].lastImpact = GetGameTime();
    int used = g_Grenade_Projectiles[slot].used;
    PlayerProfile profile;
    RN_Combat_Profile(RN_Grenade_Owner(group), profile);
    int targets = RN_Grenade_Blast(slot);
    if ((RN_Config_Int(RN_CVAR_DEBUG) != 0))
        LogMessage("[Rogue] GRENADE HIT group=%d ref=%d used=%d/%d damage=%.1f radius=%.1f targets=%d", id, reference, used, RN_Grenade_Limit(group), RN_Grenade_GroupDamage(group, used - 1), RN_Magician_Radius(profile), targets);
    if (g_Grenade_Projectiles[slot].ref != reference || g_Grenade_Groups[group].id != id) return false;
    if (g_Grenade_Projectiles[slot].used >= RN_Grenade_Limit(group)) { RN_Grenade_Remove(slot); return false; }
    return true;
}

/** 保存最近的水平前进方向；直上直下时沿用发射方向，不随玩家转头改变。 */
void RN_Grenade_UpdateHeading(int slot)
{
    float x = g_Grenade_Projectiles[slot].velocity[0], y = g_Grenade_Projectiles[slot].velocity[1];
    if (x * x + y * y > 0.0001) g_Grenade_Projectiles[slot].heading = ArcTangent2(y, x);
}

/** 每100%必多1发，余数只抽一次；子弹继承已用次数，在总夹角内朝前展开。 */
void RN_Grenade_Split(int slot, const float normal[3])
{
    int group = g_Grenade_Projectiles[slot].group;
    int id = g_Grenade_Projectiles[slot].groupId, reference = g_Grenade_Projectiles[slot].ref;
    int used = g_Grenade_Projectiles[slot].used;
    PlayerProfile profile;
    RN_Combat_Profile(RN_Grenade_Owner(group), profile);
    float chance = RN_Magician_SplitChance(profile);
    int available = RN_GRENADE_PROJECTILES - g_Grenade_Active;
    if (used >= RN_Grenade_Limit(group) || available <= 0 || chance <= 0.0 || !RN_Math_Finite(chance)) return;
    // 先按可用槽位限制，避免将极大的合法百分比转换为溢出的整数。
    int extra = available;
    if (chance < float(available) * 100.0)
    {
        extra = RoundToFloor(chance / 100.0);
        // 在百分点域求余数，保证120%的20%边界不受1.2减1的舍入影响。
        float remainder = (chance - float(extra) * 100.0) / 100.0;
        if (remainder > 0.0 && GetRandomFloat(0.0, 1.0) < remainder) extra++;
    }
    if (extra <= 0) return;
    RN_Grenade_UpdateHeading(slot);
    float heading = g_Grenade_Projectiles[slot].heading, spread = DegToRad(RN_Config_Float(RN_CVAR_GRENADE_SPLIT_ANGLE));
    float speed = RN_Config_Float(RN_CVAR_GRENADE_SPLIT_SPEED), upward = RN_Config_Float(RN_CVAR_GRENADE_BOUNCE_SPEED);
    float position[3], angles[3], velocity[3];
    for (int axis = 0; axis < 3; axis++) position[axis] = g_Grenade_Projectiles[slot].position[axis];
    int created;
    for (int i = 0; i <= extra; i++)
    {
        if (g_Grenade_Projectiles[slot].ref != reference || g_Grenade_Groups[group].id != id || !RN_Grenade_Enabled(RN_Grenade_Owner(group)) || used >= RN_Grenade_Limit(group)) break;
        float angle = heading + spread * (float(i) / float(extra) - 0.5);
        velocity[0] = Cosine(angle) * speed;
        velocity[1] = Sine(angle) * speed;
        velocity[2] = upward;
        // 墙壁或顶面分裂时，调整方向以向外弹跳。
        float incoming = GetVectorDotProduct(velocity, normal);
        if (incoming < 0.0)
            for (int axis = 0; axis < 3; axis++) velocity[axis] -= 2.0 * incoming * normal[axis];
        if (i == 0)
        {
            for (int axis = 0; axis < 3; axis++) g_Grenade_Projectiles[slot].velocity[axis] = velocity[axis];
            RN_Grenade_UpdateHeading(slot);
            continue;
        }
        if (g_Grenade_Active >= RN_GRENADE_PROJECTILES) break;
        int owner = RN_Grenade_Owner(group);
        if (owner == 0) break;
        GetVectorAngles(velocity, angles);
        int entity = RN_Grenade_Create(owner, position, angles, velocity, group, used);
        if (entity > MaxClients && RN_Grenade_Managed(entity) && g_Grenade_EntitySlot[entity] >= 0) created++;
    }
    if ((RN_Config_Int(RN_CVAR_DEBUG) != 0) && g_Grenade_Groups[group].id == id)
        LogMessage("[Rogue] GRENADE SPLIT group=%d ref=%d new=%d active=%d used=%d remaining=%d angle=%.1f", id, reference, created, g_Grenade_Groups[group].active, used, RN_Grenade_Limit(group) - used, RadToDeg(spread));
}
