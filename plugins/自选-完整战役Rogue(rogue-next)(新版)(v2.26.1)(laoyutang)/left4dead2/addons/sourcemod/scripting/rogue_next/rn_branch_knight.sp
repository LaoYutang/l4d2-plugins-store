#if defined _rn_branch_knight_included
 #endinput
#endif
#define _rn_branch_knight_included

/** 圣光属于已命中队友的当前生命，不随断线、换图或清档继承。 */
enum struct RN_BranchHoly
{
    int serial;
    int life;
    int run;
    int map;
    float until;
}

/** 仅同步SDK重放期间有效；原始来源和接收者身份均不能由槽位猜测。 */
enum struct RN_BranchTransfer
{
    int serial;
    int life;
    int run;
    int map;
    int attacker;
    int inflictor;
    int type;
    int weapon;
    bool claimed;
}
RN_BranchHoly g_BranchKnight_Holy[MAXPLAYERS + 1];
RN_BranchTransfer g_BranchKnight_Transfer;

/** 清除单人的友军增益；不改档案中锁定的转职身份。 */
void RN_BranchKnight_Forget(int client)
{
    if (client < 1 || client > MaxClients) return;
    RN_BranchHoly empty;
    g_BranchKnight_Holy[client] = empty;
}

/** 清档或地图结束释放短期状态；同步伤害作用域由调用者逐层还原。 */
void RN_BranchKnight_Clear()
{
    for (int client = 1; client <= MaxClients; client++) RN_BranchKnight_Forget(client);
}

/** 返回被命中队友的独立倍率，多次命中只延时，不增加倍率。 */
float RN_BranchKnight_HolyFactor(int client)
{
    if (client < 1 || client > MaxClients || g_BranchKnight_Holy[client].until <= 0.0) return 1.0;
    if (!RN_Config_Enabled() || RN_Config_Int(RN_CVAR_PROFESSION_ENABLE) == 0
        || !RN_Common_Survivor(client) || !IsPlayerAlive(client)
        || RN_Common_Incapacitated(client) || g_BranchKnight_Holy[client].serial != GetClientSerial(client)
        || g_BranchKnight_Holy[client].life != g_Common_Life[client]
        || g_BranchKnight_Holy[client].run != g_Run_Epoch
        || g_BranchKnight_Holy[client].map != g_Run_MapEpoch
        || GetTickedTime() >= g_BranchKnight_Holy[client].until)
    {
        RN_BranchKnight_Forget(client);
        return 1.0;
    }
    return 1.5;
}

/** 只接受普通枪械弹丸或普通近战；燃烧弹的直接弹丸仍是枪械命中。 */
bool RN_BranchKnight_HolyAttack(int attacker, int inflictor, int weapon, int type)
{
    if ((type & DMG_BLAST) != 0 || RN_Combat_ContinuousFire(type)) return false;
    int source = RN_Profession_GunSource(attacker, inflictor, weapon, type);
    if (RN_Weapons_Index(source) >= 0) return true;
    return (type & (DMG_SLASH | DMG_CLUB)) != 0 && RN_Common_Melee(inflictor)
        && GetPlayerWeaponSlot(attacker, 1) == inflictor;
}

/** 等额使用完整OnTakeDamage入口输入；不从最终友伤除倍率反推原伤。 */
bool RN_BranchKnight_Holy(int victim, int attacker, int inflictor, float amount, int type,
    int weapon)
{
    if (!RN_Common_Survivor(victim) || !IsPlayerAlive(victim) || RN_Common_Incapacitated(victim)
        || victim == attacker || RN_Branch_Get(attacker) != RN_BRANCH_HOLY
        || !RN_BranchKnight_HolyAttack(attacker, inflictor, weapon, type)
        || amount <= 0.0 || !RN_Math_Finite(amount)) return false;
    int health = GetEntProp(victim, Prop_Data, "m_iHealth");
    int maximum = GetEntProp(victim, Prop_Data, "m_iMaxHealth");
    int room = maximum > health ? maximum - health : 0;
    // 先与缺失血量比较，避免将极大原始伤害转为整数时溢出。
    int healing = amount >= float(room) ? room : RoundToFloor(amount + 0.0001);
    if (healing > 0) RN_Profile_RewardHealth(victim, healing);
    g_BranchKnight_Holy[victim].serial = GetClientSerial(victim);
    g_BranchKnight_Holy[victim].life = g_Common_Life[victim];
    g_BranchKnight_Holy[victim].run = g_Run_Epoch;
    g_BranchKnight_Holy[victim].map = g_Run_MapEpoch;
    g_BranchKnight_Holy[victim].until = GetTickedTime() + 3.0;
    return true;
}

/** 精确匹配当前同步转移，不能把其他目标或已经换生命的事件当作重放。 */
bool RN_BranchKnight_TransferMatches(int victim, int attacker, int inflictor, int type, int weapon)
{
    return g_BranchKnight_Transfer.serial != 0 && RN_Common_Survivor(victim)
        && GetClientSerial(victim) == g_BranchKnight_Transfer.serial
        && g_Common_Life[victim] == g_BranchKnight_Transfer.life
        && g_Run_Epoch == g_BranchKnight_Transfer.run && g_Run_MapEpoch == g_BranchKnight_Transfer.map
        && attacker == g_BranchKnight_Transfer.attacker && inflictor == g_BranchKnight_Transfer.inflictor
        && type == g_BranchKnight_Transfer.type && weapon == g_BranchKnight_Transfer.weapon;
}

/** Combat每次入口只认领一次重放；同源嵌套的新伤害不能借用已消费标记。 */
bool RN_BranchKnight_ClaimTransfer(int victim, int attacker, int inflictor, int type, int weapon)
{
    if (g_BranchKnight_Transfer.claimed
        || !RN_BranchKnight_TransferMatches(victim, attacker, inflictor, type, weapon)) return false;
    g_BranchKnight_Transfer.claimed = true;
    return true;
}

/** 真实掉血账本可识别代受的环境或友伤，不伪造敌方／酸火来源。 */
bool RN_BranchKnight_TransferredHurt(int victim, int attacker, int inflictor, int type, int weapon)
{
    return g_BranchKnight_Transfer.claimed
        && RN_BranchKnight_TransferMatches(victim, attacker, inflictor, type, weapon);
}

/** 一笔份额独立走骑士自己的伤害入口，保留攻击者以维持Tank穿透等规则。 */
bool RN_BranchKnight_Replay(int victim, int attacker, int inflictor, float damage, int type, int weapon)
{
    if ((attacker != 0 && !IsValidEntity(attacker)) || (inflictor != 0 && !IsValidEntity(inflictor))
        || (weapon != -1 && !IsValidEntity(weapon))) return false;
    RN_BranchTransfer previous;
    previous = g_BranchKnight_Transfer;
    g_BranchKnight_Transfer.serial = GetClientSerial(victim);
    g_BranchKnight_Transfer.life = g_Common_Life[victim];
    g_BranchKnight_Transfer.run = g_Run_Epoch;
    g_BranchKnight_Transfer.map = g_Run_MapEpoch;
    g_BranchKnight_Transfer.attacker = attacker;
    g_BranchKnight_Transfer.inflictor = inflictor;
    g_BranchKnight_Transfer.type = type;
    g_BranchKnight_Transfer.weapon = weapon;
    g_BranchKnight_Transfer.claimed = false;
    SDKHooks_TakeDamage(victim, inflictor, attacker, damage, type, weapon, NULL_VECTOR, NULL_VECTOR, false);
    g_BranchKnight_Transfer = previous;
    return true;
}

/** 先固定200范围内的全部守护者；仅按距离判定，隔墙与骑士互保均生效。 */
bool RN_BranchKnight_Guard(int victim, int attacker, int inflictor, float &damage, int type,
    int weapon)
{
    if (!RN_Common_Survivor(victim) || !IsPlayerAlive(victim)) return false;
    if ((attacker != 0 && !IsValidEntity(attacker)) || (inflictor != 0 && !IsValidEntity(inflictor))
        || (weapon != -1 && !IsValidEntity(weapon))) return false;
    float origin[3], location[3];
    GetClientAbsOrigin(victim, origin);
    RN_KnightIdentity guardians[MAXPLAYERS + 1];
    int count;
    for (int client = 1; client <= MaxClients; client++)
    {
        PlayerProfile profile;
        if (client == victim || !RN_Knight_Current(client, profile)
            || !RN_Branch_Active(profile, RN_BRANCH_GUARDIAN)) continue;
        GetClientAbsOrigin(client, location);
        if (GetVectorDistance(origin, location, true) > 40000.0) continue;
        RN_Knight_Capture(client, profile, guardians[count]);
        count++;
    }
    if (count == 0) return false;
    int attackerRef = attacker > 0 ? EntIndexToEntRef(attacker) : attacker;
    int inflictorRef = inflictor > 0 ? EntIndexToEntRef(inflictor) : inflictor;
    int weaponRef = weapon > 0 ? EntIndexToEntRef(weapon) : weapon;
    float share = damage / float(count);
    int accepted;
    for (int i = 0; i < count; i++)
    {
        int client = RN_Knight_Owner(guardians[i]);
        if (client < 1 || RN_Branch_Get(client) != RN_BRANCH_GUARDIAN) continue;
        if ((attacker > 0 && EntRefToEntIndex(attackerRef) != attacker)
            || (inflictor > 0 && EntRefToEntIndex(inflictorRef) != inflictor)
            || (weapon > 0 && EntRefToEntIndex(weaponRef) != weapon)) break;
        if (RN_BranchKnight_Replay(client, attacker, inflictor, share, type, weapon)) accepted++;
    }
    if (accepted == 0) return false;
    // 同步SDK中途失效的份额保留在原受击者，不凭空销毁这笔原伤。
    damage = accepted == count ? 0.0 : share * float(count - accepted);
    return true;
}

/** 治疗转换优先于守护；重放只免于再转移，仍由Combat计算接收者自己的减伤。 */
Action RN_BranchKnight_OnDamage(int victim, int attacker, int inflictor, float &damage,
    int type, int weapon, bool transferred)
{
    if (transferred || !RN_Config_Enabled() || damage <= 0.0 || !RN_Math_Finite(damage)) return Plugin_Continue;
    if (RN_BranchKnight_Holy(victim, attacker, inflictor, damage, type, weapon))
    {
        damage = 0.0;
        return Plugin_Handled;
    }
    return RN_BranchKnight_Guard(victim, attacker, inflictor, damage, type, weapon)
        ? Plugin_Changed : Plugin_Continue;
}
