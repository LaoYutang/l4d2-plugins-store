#if defined _rn_grenade_blast_included
 #endinput
#endif
#define _rn_grenade_blast_included

/** 首次爆炸不衰减；各分支按已弹跳次数连乘，分裂沿用继承的次数。 */
float RN_Grenade_Damage(int bounces)
{
    float damage = RN_Config_Float(RN_CVAR_GRENADE_DAMAGE);
    if (bounces <= 0) return damage;
    return damage * Pow(1.0 - RN_Config_Float(RN_CVAR_GRENADE_BOUNCE_DAMAGE_DECAY), float(bounces));
}

/** 分支模式来自首发快照；和平预算只兑现一次，混乱保持初始伤害线性增长。 */
float RN_Grenade_GroupDamage(int group, int bounces)
{
    if (RN_Config_Int(RN_CVAR_PROFESSION_ENABLE) == 0) return RN_Grenade_Damage(bounces);
    switch (g_Grenade_Owners[group].branch)
    {
        case RN_BRANCH_PEACE: return bounces == 0 ? g_Grenade_Owners[group].peaceDamage : 0.0;
        case RN_BRANCH_CHAOS: return RN_Branch_ChaosDamage(RN_Config_Float(RN_CVAR_GRENADE_DAMAGE), bounces);
    }
    return RN_Grenade_Damage(bounces);
}

/** 榴弹是枪械伤害来源；只识别实际榴弹实体，不借当前手持武器猜来源。 */
bool RN_Grenade_Shot(int inflictor, int damagetype)
{
    if ((damagetype & DMG_BLAST) == 0 || inflictor <= MaxClients || !IsValidEntity(inflictor)) return false;
    char classname[64];
    GetEntityClassname(inflictor, classname, sizeof(classname));
    return StrEqual(classname, "grenade_launcher_projectile") || StrEqual(classname, "weapon_grenade_launcher");
}

/** 身体中心统一用于距离与遮挡检测，范围内固定伤害不随距离衰减。 */
void RN_Grenade_Center(int entity, float center[3])
{
    if (entity <= MaxClients) GetClientAbsOrigin(entity, center);
    else GetEntPropVector(entity, Prop_Send, "m_vecOrigin", center);
    float mins[3], maxs[3];
    GetEntPropVector(entity, Prop_Send, "m_vecMins", mins);
    GetEntPropVector(entity, Prop_Send, "m_vecMaxs", maxs);
    for (int axis = 0; axis < 3; axis++) center[axis] += (mins[axis] + maxs[axis]) * 0.5;
}

/** 按本分支已弹跳次数固定衰减伤害、共享艺术半径及目标生命，经过正式SDK钩子。 */
int RN_Grenade_Blast(int slot)
{
    int group = g_Grenade_Projectiles[slot].group, id = g_Grenade_Projectiles[slot].groupId;
    int inflictorRef = g_Grenade_Projectiles[slot].ref;
    int owner = RN_Grenade_Owner(group);
    if (owner == 0) return 0;
    PlayerProfile profile;
    RN_Combat_Profile(owner, profile);
    float damage = RN_Grenade_GroupDamage(group, g_Grenade_Projectiles[slot].used - 1), radius = RN_Magician_Radius(profile);
    if (!RN_Math_Finite(damage) || damage < 0.0 || damage >= RN_INT_FLOAT_LIMIT) return 0;
    float origin[3];
    for (int axis = 0; axis < 3; axis++) origin[axis] = g_Grenade_Projectiles[slot].position[axis];
    ArrayList targets = new ArrayList(sizeof(RN_FXRecord));
    if (damage > 0.0 && radius > 0.0)
    {
        int maximum = GetMaxEntities();
        for (int entity = 1; entity < maximum; entity++)
        {
            if (!RN_Burn_Living(entity)) continue;
            float center[3];
            RN_Grenade_Center(entity, center);
            if (GetVectorDistance(origin, center, true) > radius * radius) continue;
            Handle trace = TR_TraceRayFilterEx(origin, center, MASK_SOLID, RayType_EndPoint, RN_Grenade_WorldFilter);
            bool visible = !TR_StartSolid(trace) && !TR_AllSolid(trace) && TR_GetFraction(trace) >= 1.0;
            delete trace;
            if (!visible) continue;
            RN_FXRecord target;
            RN_FX_Identity(entity, target);
            targets.PushArray(target, sizeof(target));
        }
    }
    int hits;
    for (int i = 0; i < targets.Length; i++)
    {
        if (g_Grenade_Groups[group].id != id || g_Grenade_Projectiles[slot].ref != inflictorRef) break;
        owner = RN_Grenade_Owner(group);
        int inflictor = EntRefToEntIndex(inflictorRef);
        if (owner == 0 || !RN_Grenade_Managed(inflictor)) break;
        RN_FXRecord target;
        targets.GetArray(i, target, sizeof(target));
        int victim = RN_FX_Resolve(target);
        if (!RN_Burn_Living(victim)) continue;
        SDKHooks_TakeDamage(victim, inflictor, owner, damage, DMG_BLAST | DMG_PREVENT_PHYSICS_FORCE,
            -1, NULL_VECTOR, origin, false);
        hits++;
    }
    delete targets;
    if (g_Grenade_Groups[group].id == id && RN_Grenade_Owner(group) > 0 && g_Element_Sprite > 0)
    {
        origin[2] += 6.0;
        TE_SetupExplosion(origin, g_Element_Sprite, 0.6, 15, 0, 0, 0);
        TE_SendToAll();
    }
    return hits;
}
