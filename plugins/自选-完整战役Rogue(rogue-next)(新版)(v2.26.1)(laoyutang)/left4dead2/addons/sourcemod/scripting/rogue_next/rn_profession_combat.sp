#if defined _rn_profession_combat_included
 #endinput
#endif
#define _rn_profession_combat_included

/** SDK提供真实武器时只认该武器；缺失时仅对玩家直接弹丸命中兼容当前枪。 */
int RN_Profession_GunSource(int attacker, int inflictor, int weapon, int damagetype)
{
    if ((damagetype & (DMG_BULLET | DMG_BUCKSHOT)) == 0 ||
        (damagetype & (DMG_BLAST | DMG_SLASH | DMG_CLUB)) != 0) return -1;
    int source = weapon;
    if (source <= MaxClients || !IsValidEntity(source))
    {
        source = inflictor;
        if (source <= MaxClients || !IsValidEntity(source))
        {
            if (inflictor != attacker || !RN_Common_Survivor(attacker)) return -1;
            source = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
        }
    }
    return source;
}

/** 职业与元素去重共用实际枪械来源；保留原有武器类别检查。 */
int RN_Profession_GunIndex(int attacker, int inflictor, int weapon, int damagetype)
{
    return RN_Weapons_Index(RN_Profession_GunSource(attacker, inflictor, weapon, damagetype));
}

/** 仅符合职业、目标、枪械和伤害类型的狙击命中读两次位置，不周期测距。 */
float RN_Profession_DamageFactor(PlayerProfile profile, int victim, int attacker,
                                 int inflictor, int weapon, int damagetype)
{
    if (!RN_Profession_Is(profile, RN_PROFESSION_SNIPER)) return 1.0;
    if (!RN_Config_Enabled() || !RN_Common_Survivor(attacker) || IsFakeClient(attacker) ||
        (!RN_Common_Infected(victim) && !RN_Common_Zombie(victim))) return 1.0;
    int index = RN_Profession_GunIndex(attacker, inflictor, weapon, damagetype);
    if (index < 0) return 1.0;
    if (index < 12 || index > 15) return 1.0;
    float power = RN_Profession_SniperPower(profile);
    if (g_Profession_SniperCapSquared <= 0.0 || RN_Profession_SniperRate(profile) <= 0.0) return power;
    float origin[3], target[3], squared;
    GetClientAbsOrigin(attacker, origin);
    if (RN_Common_Client(victim)) GetClientAbsOrigin(victim, target);
    else GetEntPropVector(victim, Prop_Data, "m_vecOrigin", target);
    for (int axis = 0; axis < 3; axis++)
    {
        float delta = target[axis] - origin[axis];
        squared += delta * delta;
    }
    return power * RN_Profession_SniperFactor(profile, squared);
}
