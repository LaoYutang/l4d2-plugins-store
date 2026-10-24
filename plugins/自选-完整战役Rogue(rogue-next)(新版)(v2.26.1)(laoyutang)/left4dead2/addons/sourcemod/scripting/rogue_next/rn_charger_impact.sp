#if defined _rn_charger_impact_included
 #endinput
#endif
#define _rn_charger_impact_included

/** 无source的撞击回调只使用同引擎帧来源，不能借用半秒控制缓存泛化踉跄免疫。 */
enum struct RN_ChargerImpactContext
{
    int attacker;
    int victim;
    int attackerSerial;
    int attackerLife;
    int attackerReset;
    int victimSerial;
    int victimLife;
    int victimReset;
    int run;
    int map;
    int tick;
}

RN_ChargerImpactContext g_ChargerImpact_Area;
RN_ChargerImpactContext g_ChargerImpact_Direct[MAXPLAYERS + 1];

/** 撞墙范围踉跄无source，直接撞飞/撞墙有双方；保存引擎帧及双方身份。 */
void RN_ChargerImpact_Record(int attacker, int victim = 0)
{
    if (!RN_Config_Enabled() || !RN_Charger_Alive(attacker)) return;
    if (victim != 0 && (!RN_Common_Survivor(victim) || !IsPlayerAlive(victim))) return;
    RN_ChargerImpactContext context;
    context.attacker = attacker;
    context.victim = victim;
    context.attackerSerial = GetClientSerial(attacker);
    context.attackerLife = g_Common_Life[attacker];
    context.attackerReset = g_Charger_ResetVersion[attacker];
    context.run = g_Run_Epoch;
    context.map = g_Run_MapEpoch;
    context.tick = GetGameTickCount();
    if (victim == 0) g_ChargerImpact_Area = context;
    else
    {
        context.victimSerial = GetClientSerial(victim);
        context.victimLife = g_Common_Life[victim];
        context.victimReset = g_Charger_ResetVersion[victim];
        g_ChargerImpact_Direct[victim] = context;
    }
}

/** 同一帧、战役、地图和生命才接受匿名动作来源；显式阵营/存活同样核对。 */
bool RN_ChargerImpact_Valid(RN_ChargerImpactContext context, int victim)
{
    return RN_Config_Enabled() && context.attacker != 0 && context.tick == GetGameTickCount() &&
        context.run == g_Run_Epoch && context.map == g_Run_MapEpoch && RN_Charger_Alive(context.attacker) &&
        RN_Common_Survivor(victim) && IsPlayerAlive(victim) &&
        context.attackerSerial == GetClientSerial(context.attacker) && context.attackerLife == g_Common_Life[context.attacker] &&
        context.attackerReset == g_Charger_ResetVersion[context.attacker] &&
        (context.victim == 0 || (context.victim == victim && context.victimSerial == GetClientSerial(victim) &&
            context.victimLife == g_Common_Life[victim] && context.victimReset == g_Charger_ResetVersion[victim]));
}

/** 明确双方的撞击优先；没有当前帧来源时放行，不能影响其他踉跄。 */
int RN_ChargerImpact_Source(int victim)
{
    if (!RN_Common_Survivor(victim)) return 0;
    if (RN_ChargerImpact_Valid(g_ChargerImpact_Direct[victim], victim)) return g_ChargerImpact_Direct[victim].attacker;
    return RN_ChargerImpact_Valid(g_ChargerImpact_Area, victim) ? g_ChargerImpact_Area.attacker : 0;
}

/** DHooks在CCharge::ImpactStagger前通知，随后的匿名踉跄在同一引擎帧内发生。 */
public void L4D2_OnChargerImpact(int attacker)
{
    RN_ChargerImpactContext empty;
    g_ChargerImpact_Area = empty;
    // 新的范围撞击紧接自己的匿名回调，不借用同帧前一只牛的直接撞击来源。
    for (int victim = 1; victim <= MaxClients; victim++) g_ChargerImpact_Direct[victim] = empty;
    RN_ChargerImpact_Record(attacker);
    if (RN_Config_Int(RN_CVAR_DEBUG) != 0) RN_Charger_Log("impact_context", attacker, 0, 0);
}

/** 撞飞与抓取共用同一次成功/失败判定；pre仅阻止并登记延后处理。 */
public Action L4D2_OnThrowImpactedSurvivor(int attacker, int victim)
{
    RN_ChargerImpact_Record(attacker, victim);
    return RN_Charger_Control(victim, attacker, 4);
}

/** Charger源或当前帧已识别的匿名撞击才参与免控，Tank/其他源照常放行。 */
public Action L4D2_OnStagger(int victim, int source)
{
    int attacker = source > 0 ? source : RN_ChargerImpact_Source(victim);
    return RN_Charger_Control(victim, attacker, 8);
}

/** 只阻止牛造成的倒地动画；Tank石头与Hunter扑倒不借用牛判定。 */
public Action L4D_OnKnockedDown(int victim, int reason)
{
    if (reason != KNOCKDOWN_CHARGER) return Plugin_Continue;
    return RN_Charger_Control(victim, RN_ChargerImpact_Source(victim), 16);
}

/** 撞墙与首下拍地也是独立动作；同样沿用已有判定，不改两个布尔参数。 */
public Action L4D2_OnSlammedSurvivor(int victim, int attacker, bool &wallSlam, bool &deadlyCharge)
{
    RN_ChargerImpact_Record(attacker, victim);
    return RN_Charger_Control(victim, attacker, 32);
}
