#if defined _rn_sword_collision_included
 #endinput
#endif
#define _rn_sword_collision_included

/** 只有存活感染者可成为目标；队友、尸体、幽灵及垂死Tank直接穿过。 */
bool RN_Sword_Enemy(int entity)
{
    return RN_Burn_Living(entity) && (!RN_Common_Tank(entity) || !RN_Common_Incapacitated(entity));
}

/** 生还者拥有或父接的装备也穿过，避免队友手上武器挡住剑气。 */
bool RN_Sword_AllyAttachment(int entity)
{
    for (int depth = 0; depth < 4; depth++)
    {
        if (entity <= MaxClients) return RN_Common_Survivor(entity);
        if (!IsValidEntity(entity)) return false;
        if (HasEntProp(entity, Prop_Send, "m_hOwnerEntity")
            && RN_Common_Survivor(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"))) return true;
        if (HasEntProp(entity, Prop_Data, "m_hMoveParent")) entity = GetEntPropEnt(entity, Prop_Data, "m_hMoveParent");
        else return false;
    }
    return false;
}

/** 中心射线只与地图和实体障碍碰撞，所有角色以及生还者附件不挡墙检测。 */
public bool RN_Sword_WallFilter(int entity, int contentsMask, any data)
{
    if (entity == 0) return true;
    if (entity <= MaxClients || !IsValidEntity(entity) || RN_Sword_AllyAttachment(entity)) return false;
    char classname[32];
    GetEntityClassname(entity, classname, sizeof(classname));
    return !StrEqual(classname, "infected") && !StrEqual(classname, "witch");
}

/** 命中检测只查询敌人，一个弧段被挡不能排除同目标的其他露出部位。 */
public bool RN_Sword_EnemyFilter(int entity, int contentsMask, any query)
{
    if (!RN_Sword_Enemy(entity)) return false;
    int slot = query / RN_SWORD_SEGMENTS, segment = query % RN_SWORD_SEGMENTS;
    char key[64];
    RN_Sword_TargetKey(EntIndexToEntRef(entity), entity <= MaxClients ? g_Common_Life[entity] : 0,
        entity <= MaxClients ? GetClientSerial(entity) : 0, key, sizeof(key));
    int ignored;
    if (g_Sword_Waves[slot].seen.GetValue(key, ignored)) return false;
    char blocked[72];
    FormatEx(blocked, sizeof(blocked), "%s:%d", key, segment);
    return !g_Sword_Waves[slot].blocked.GetValue(blocked, ignored);
}

/** 绘制与命中扫掠使用完全相同的六段弧线。 */
void RN_Sword_ArcPoint(RN_SwordWave wave, const float origin[3], int segment, float point[3])
{
    float offset = 2.0 * float(segment) / float(RN_SWORD_SEGMENTS) - 1.0;
    float bend = wave.halfWidth * 0.5 * (1.0 - offset * offset);
    for (int axis = 0; axis < 3; axis++)
        point[axis] = origin[axis] + wave.right[axis] * offset * wave.halfWidth + wave.direction[axis] * bend;
}

/** 整段线的轴对齐扫掠包围盒加2单位容差，横向两端也能命中。 */
void RN_Sword_SegmentHull(RN_SwordWave wave, int segment, float center[3], float mins[3], float maxs[3])
{
    float start[3], end[3];
    RN_Sword_ArcPoint(wave, wave.origin, segment, start);
    RN_Sword_ArcPoint(wave, wave.origin, segment + 1, end);
    for (int axis = 0; axis < 3; axis++)
    {
        center[axis] = (start[axis] + end[axis]) * 0.5;
        maxs[axis] = FloatAbs(end[axis] - start[axis]) * 0.5 + 2.0;
        mins[axis] = -maxs[axis];
    }
}

/** 每条接触路径独立查询墙和门，所有角色及队友附件沿用免费穿过规则。 */
bool RN_Sword_PathClear(const float start[3], const float end[3])
{
    Handle trace = TR_TraceRayFilterEx(start, end, MASK_SHOT_HULL, RayType_EndPoint, RN_Sword_WallFilter);
    bool visible = !TR_DidHit(trace) && !TR_StartSolid(trace) && !TR_AllSolid(trace);
    delete trace;
    return visible;
}

/** 从扫掠接触选身体部位，按该部位的真实前进路线查挡，不能横向跨门板判定。 */
bool RN_Sword_Visible(RN_SwordWave wave, int target, float impact[3])
{
    float origin[3], mins[3], maxs[3], start[3], pathDistance;
    RN_Element_Origin(target, origin);
    GetEntPropVector(target, Prop_Send, "m_vecMins", mins);
    GetEntPropVector(target, Prop_Send, "m_vecMaxs", maxs);
    for (int axis = 0; axis < 3; axis++)
    {
        float low = origin[axis] + mins[axis], high = origin[axis] + maxs[axis];
        if (impact[axis] < low) impact[axis] = low;
        if (impact[axis] > high) impact[axis] = high;
        pathDistance += (impact[axis] - wave.launch[axis]) * wave.direction[axis];
    }
    if (pathDistance < 0.0) pathDistance = 0.0;
    for (int axis = 0; axis < 3; axis++) start[axis] = impact[axis] - wave.direction[axis] * pathDistance;
    return RN_Sword_PathClear(wave.launch, start) && RN_Sword_PathClear(start, impact);
}

/** 中央弧顶在视点前方，发射前补查这段距离，不能在薄墙另一侧生成剑气。 */
bool RN_Sword_LaunchBlocked(RN_SwordWave wave)
{
    float center[3];
    RN_Sword_ArcPoint(wave, wave.origin, RN_SWORD_SEGMENTS / 2, center);
    Handle trace = TR_TraceRayFilterEx(wave.origin, center, MASK_SHOT_HULL, RayType_EndPoint, RN_Sword_WallFilter);
    bool blocked = TR_DidHit(trace) || TR_StartSolid(trace) || TR_AllSolid(trace);
    delete trace;
    return blocked;
}

/** 按接触顺序截断本步飞行和绘制，并在当前更新内结算全部有效接触。 */
void RN_Sword_Step(int slot, float now)
{
    RN_Sword_Prune(slot, now);
    RN_SwordWave wave;
    wave = g_Sword_Waves[slot];
    if (!wave.finished && !wave.waiting)
    {
        float distance = wave.speed * (now - wave.updated);
        if (distance > wave.remaining) distance = wave.remaining;
        if (distance > 0.0)
        {
            g_Sword_Waves[slot].blocked.Clear();
            float destination[3];
            for (int axis = 0; axis < 3; axis++) destination[axis] = wave.origin[axis] + wave.direction[axis] * distance;
            float centerStart[3], centerEnd[3];
            RN_Sword_ArcPoint(wave, wave.origin, RN_SWORD_SEGMENTS / 2, centerStart);
            RN_Sword_ArcPoint(wave, destination, RN_SWORD_SEGMENTS / 2, centerEnd);
            Handle wall = TR_TraceRayFilterEx(centerStart, centerEnd, MASK_SHOT_HULL, RayType_EndPoint, RN_Sword_WallFilter);
            bool blocked = TR_DidHit(wall) || TR_StartSolid(wall) || TR_AllSolid(wall);
            float wallFraction = TR_StartSolid(wall) || TR_AllSolid(wall) ? 0.0 : TR_GetFraction(wall);
            delete wall;
            float travelFraction = wallFraction;
            bool exhausted;
            for (int attempt = 0; attempt < RN_SWORD_CONTACT_LIMIT; attempt++)
            {
                float fraction = 1.0, impact[3];
                int target = -1, hitSegment = -1;
                for (int segment = 0; segment < RN_SWORD_SEGMENTS; segment++)
                {
                    float start[3], end[3], mins[3], maxs[3];
                    RN_Sword_SegmentHull(wave, segment, start, mins, maxs);
                    for (int axis = 0; axis < 3; axis++) end[axis] = start[axis] + wave.direction[axis] * distance * wallFraction;
                    Handle trace = TR_TraceHullFilterEx(start, end, mins, maxs, CONTENTS_MONSTER | CONTENTS_HITBOX,
                        RN_Sword_EnemyFilter, slot * RN_SWORD_SEGMENTS + segment);
                    float part = TR_StartSolid(trace) || TR_AllSolid(trace) ? 0.0 : TR_GetFraction(trace);
                    if (TR_DidHit(trace) && (part < fraction || (part == fraction && target == -1)))
                    {
                        fraction = part;
                        target = TR_GetEntityIndex(trace);
                        hitSegment = segment;
                        TR_GetEndPosition(impact, trace);
                    }
                    delete trace;
                }
                if (!RN_Sword_Enemy(target)) break;
                bool visible = RN_Sword_Visible(wave, target, impact);
                RN_Sword_Contact(slot, target, impact, visible, hitSegment);
                if (g_Sword_Waves[slot].hitCount + g_Sword_Waves[slot].contacts.Length >= wave.maxHits)
                {
                    travelFraction = wallFraction * fraction;
                    exhausted = true;
                    break;
                }
                if (g_Sword_Waves[slot].contacts.Length >= RN_SWORD_CONTACT_LIMIT) break;
            }
            for (int axis = 0; axis < 3; axis++) destination[axis] = wave.origin[axis] + wave.direction[axis] * distance * travelFraction;
            g_Sword_Waves[slot].origin = destination;
            g_Sword_Waves[slot].remaining -= distance * travelFraction;
            g_Sword_Waves[slot].updated = now;
            g_Sword_Waves[slot].waiting = exhausted;
            g_Sword_Waves[slot].finished = (blocked && !exhausted) || g_Sword_Waves[slot].remaining <= 0.0;
            RN_Sword_Draw(wave, destination);
        }
    }
    RN_Sword_Resolve(slot, now);
}
