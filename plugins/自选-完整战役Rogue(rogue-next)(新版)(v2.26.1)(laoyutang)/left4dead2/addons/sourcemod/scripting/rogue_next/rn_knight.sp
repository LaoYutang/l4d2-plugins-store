#if defined _rn_knight_included
 #endinput
#endif
#define _rn_knight_included

/** 待结算能力绑定完整玩家身份，清理代次使同生命的旧任务也立即失效。 */
enum struct RN_KnightIdentity
{
    int serial;
    int life;
    int run;
    int map;
    int profile;
    int version;
    int generation;
}
enum struct RN_KnightState
{
    RN_KnightIdentity owner;
    int hits;
    float nextCount;
    float healUntil;
    float healPaidThrough;
    float healNext;
    float healCarry;
}
RN_KnightState g_Knight_State[MAXPLAYERS + 1];
int g_Knight_Generation[MAXPLAYERS + 1];

#include "rn_knight_config.sp"
#include "rn_knight_attack.sp"
#include "rn_knight_hurt.sp"

/** 能力仅属于当前站立的真人骑士；被控但未倒地仍可反应。 */
bool RN_Knight_Current(int client, PlayerProfile profile)
{
    return RN_Config_Enabled() && RN_Common_Survivor(client) && !IsFakeClient(client)
        && IsPlayerAlive(client) && !RN_Common_Incapacitated(client)
        && RN_Profile_Get(g_Profile_Index[client], profile) && RN_Profession_Is(profile, RN_PROFESSION_KNIGHT);
}

/** 创建固定拥有者身份，不在异步任务里重新认领当前槽位。 */
void RN_Knight_Capture(int client, PlayerProfile profile, RN_KnightIdentity owner)
{
    owner.serial = GetClientSerial(client);
    owner.life = g_Common_Life[client];
    owner.run = g_Run_Epoch;
    owner.map = g_Run_MapEpoch;
    owner.profile = g_Profile_Index[client];
    owner.version = profile.professionVersion;
    owner.generation = g_Knight_Generation[client];
}

/** 身份、职业开关及站立状态全部一致才执行下一帧伤害或治疗。 */
int RN_Knight_Owner(RN_KnightIdentity owner)
{
    int client = GetClientFromSerial(owner.serial);
    PlayerProfile profile;
    if (client < 1 || !RN_Knight_Current(client, profile) || owner.life != g_Common_Life[client]
        || owner.run != g_Run_Epoch || owner.map != g_Run_MapEpoch || owner.profile != g_Profile_Index[client]
        || owner.version != profile.professionVersion || owner.generation != g_Knight_Generation[client]) return 0;
    return client;
}

/** 候选等级用于升级原子验证；未选择或停用职业贡献为零。 */
float RN_Knight_Health(PlayerProfile profile, int level = -1)
{
    if (!RN_Profession_Is(profile, RN_PROFESSION_KNIGHT)) return 0.0;
    return RN_Config_Float(RN_CVAR_KNIGHT_HEALTH_BONUS)
        + float(level < 0 ? g_Run_Level : level) * RN_Config_Float(RN_CVAR_KNIGHT_HEALTH_PER_LEVEL);
}

/** 生命附伤仅合并基础比例与血气方刚，不混入枪械、近战或暴击。 */
float RN_Knight_AttackRatio(PlayerProfile profile)
{
    return RN_Profession_Is(profile, RN_PROFESSION_KNIGHT) ? RN_Config_Float(RN_CVAR_KNIGHT_ATTACK_HP_RATIO)
        + RN_Profession_Value(profile, PLAYBUFF_BLOOD_VIGOR, RN_CVAR_BLOOD_VIGOR_HP_RATIO) : 0.0;
}

/** 附伤与爆发共用全伤及辛辣乘区。 */
float RN_Knight_Output(PlayerProfile profile)
{
    return RN_Stats_Get(profile, RN_STAT_DAMAGE) * (1.0 + float(profile.buff[PLAYBUFF_XINLATIANSAI]));
}

/** 普通命中的独立附伤在确认正伤害后使用此金额。 */
float RN_Knight_AttackDamage(PlayerProfile profile, int maximum)
{
    return float(maximum) * RN_Knight_AttackRatio(profile) * RN_Knight_Output(profile);
}

/** 爆发伤害再乘派大星；不受元素、暴击或武器专属倍率影响。 */
float RN_Knight_BurstDamage(PlayerProfile profile, int maximum)
{
    return (RN_Config_Float(RN_CVAR_KNIGHT_BURST_BASE_DAMAGE)
        + float(maximum) * RN_Config_Float(RN_CVAR_KNIGHT_BURST_HP_RATIO))
        * RN_Knight_Output(profile) * RN_Stats_Get(profile, RN_STAT_EXPLOSION_DAMAGE);
}

/** 先比较触底所需层数再乘整数，极大层数也不会溢出。 */
int RN_Knight_Hits(PlayerProfile profile)
{
    int base = RN_Config_Int(RN_CVAR_KNIGHT_BURST_HITS);
    int minimum = RN_Config_Int(RN_CVAR_KNIGHT_BURST_MIN_HITS);
    int step = RN_Config_Int(RN_CVAR_LAST_STRAW_HITS_REDUCTION);
    if (step <= 0 || !RN_Profession_Is(profile, RN_PROFESSION_KNIGHT)) return base;
    int span = base - minimum;
    if (profile.buff[PLAYBUFF_LAST_STRAW] > span / step) return minimum;
    int result = base - profile.buff[PLAYBUFF_LAST_STRAW] * step;
    return result < minimum ? minimum : result;
}

/** 艺术先加范围，再乘派大星，封顶只属于受难爆发。 */
float RN_Knight_Radius(PlayerProfile profile)
{
    float cap = RN_Config_Float(RN_CVAR_KNIGHT_BURST_RADIUS_CAP);
    float base = RN_Config_Float(RN_CVAR_KNIGHT_BURST_RADIUS)
        + RN_Profession_Value(profile, PLAYBUFF_ART, RN_CVAR_ART_EXPLOSION_RADIUS_BONUS);
    if (base <= 0.0 || cap <= 0.0) return 0.0;
    float factor = RN_Stats_Get(profile, RN_STAT_EXPLOSION_RADIUS);
    return base >= cap || factor >= cap / base ? cap : base * factor;
}

/** 治疗比例同类加算而无玩法封顶，实际写血前按缺失实血钳制。 */
float RN_Knight_HealRatio(PlayerProfile profile)
{
    return RN_Profession_Value(profile, PLAYBUFF_PAIN_PLEASURE, RN_CVAR_PAIN_PLEASURE_HEAL_RATIO);
}

/** 已获卡的合计属性放在通用统计区，不扩充职业的三句短说明。 */
void RN_Knight_CardDetails(Menu menu, PlayerProfile profile)
{
    if (!RN_Profession_Is(profile, RN_PROFESSION_KNIGHT)) return;
    float heal = RN_Knight_HealRatio(profile);
    if (heal > 0.0)
    {
        char ratio[64], duration[64];
        RN_Math_NumberText(heal * 100.0, ratio, sizeof(ratio), 2, true);
        RN_Math_NumberText(RN_Config_Float(RN_CVAR_PAIN_PLEASURE_DURATION), duration, sizeof(duration), 2, true);
        RN_Menu_Detail(menu, "痛并快乐：受伤后%s秒，每秒回血%s%%上限", duration, ratio);
    }
    float radius = RN_Profession_Value(profile, PLAYBUFF_ART, RN_CVAR_ART_EXPLOSION_RADIUS_BONUS);
    if (radius > 0.0) RN_Menu_Number(menu, "艺术：爆炸基础半径+%s", radius);
}

/** 档案及实际实体基线的组合验证，拒绝无限数和无法交给引擎的伤害。 */
bool RN_Knight_Validate(PlayerProfile profile, int maximum)
{
    if (!RN_Profession_Is(profile, RN_PROFESSION_KNIGHT)) return true;
    float attack = RN_Knight_AttackDamage(profile, maximum), burst = RN_Knight_BurstDamage(profile, maximum);
    return RN_Math_Finite(attack) && attack < RN_INT_FLOAT_LIMIT && RN_Math_Finite(burst)
        && burst < RN_INT_FLOAT_LIMIT && RN_Math_Finite(RN_Knight_AttackRatio(profile) * 100.0)
        && RN_Math_Finite(float(maximum) * RN_Knight_HealRatio(profile))
        && RN_Math_Finite(RN_Knight_HealRatio(profile) * 100.0);
}

/** 容器在安装伤害钩子之前初始化，不依赖元素或排行开关。 */
void RN_Knight_Init()
{
    RN_Knight_Clear();
    RN_Knight_AttackInit();
    RN_Knight_HurtInit();
}

/** 个体生命周期结束释放短期射击记录并取消旧能力。 */
void RN_Knight_Forget(int client)
{
    if (client < 1 || client > MaxClients) return;
    RN_KnightState empty;
    g_Knight_State[client] = empty;
    if (g_Knight_Generation[client] == RN_MAX_INT) { SetFailState("骑士能力代次耗尽，请重载插件。"); return; }
    g_Knight_Generation[client]++;
    RN_Knight_AttackForget(client);
}

/** 清档、跨图和关停取消所有待结算记录，已排队空回调不再持有句柄。 */
void RN_Knight_Clear()
{
    for (int client = 1; client <= MaxClients; client++) RN_Knight_Forget(client);
    if (g_Knight_Attacks != null) g_Knight_Attacks.Clear();
    if (g_Knight_AttackCaptures != null) g_Knight_AttackCaptures.Clear();
    if (g_Knight_Hurts != null) g_Knight_Hurts.Clear();
    if (g_Knight_Blasts != null) g_Knight_Blasts.Clear();
}

/** 获卡或热改只钳制门槛，不凭已有计数立即引爆。 */
void RN_Knight_Reconcile(int client)
{
    PlayerProfile profile;
    if (!RN_Knight_Current(client, profile)) { RN_Knight_Forget(client); return; }
    int maximum = RN_Knight_Hits(profile) - 1;
    if (g_Knight_State[client].hits > maximum) g_Knight_State[client].hits = maximum;
    if (RN_Knight_HealRatio(profile) <= 0.0)
    {
        g_Knight_State[client].healUntil = 0.0;
        g_Knight_State[client].healCarry = 0.0;
    }
}

/** 热改撤销延迟伤害和治疗窗口；保留有效计数及计数间隔，不产生免费爆发。 */
void RN_Knight_ConfigApplied()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        RN_KnightState previous;
        previous = g_Knight_State[client];
        bool valid = RN_Knight_Owner(previous.owner) == client;
        RN_Knight_Forget(client);
        PlayerProfile profile;
        if (!valid || !RN_Knight_Current(client, profile)) continue;
        RN_Knight_Capture(client, profile, g_Knight_State[client].owner);
        g_Knight_State[client].hits = previous.hits;
        g_Knight_State[client].nextCount = previous.nextCount;
        RN_Knight_Reconcile(client);
    }
    g_Knight_Attacks.Clear();
    g_Knight_AttackCaptures.Clear();
    g_Knight_Hurts.Clear();
    g_Knight_Blasts.Clear();
}

/** 复用一秒调度；完整窗口按实际持续时间结算，余数保留而满血不预存。 */
void RN_Knight_Tick()
{
    float now = GetTickedTime();
    for (int client = 1; client <= MaxClients; client++)
    {
        if (g_Knight_State[client].owner.serial == 0) continue;
        if (RN_Knight_Owner(g_Knight_State[client].owner) != client) { RN_Knight_Forget(client); continue; }
        if (g_Knight_State[client].healUntil <= 0.0 || now < g_Knight_State[client].healNext) continue;
        RN_Knight_HealDue(client, now);
    }
}

/** 先按缺失实血比较再乘时间，任意有限回复比例都不会因长窗口乘算溢出。 */
float RN_Knight_HealAmount(int client, PlayerProfile profile, float elapsed, float carry)
{
    int maximum = GetEntProp(client, Prop_Data, "m_iMaxHealth");
    float room = float(maximum - GetEntProp(client, Prop_Data, "m_iHealth"));
    if (room <= 0.0) return 0.0;
    if (carry >= room) return room;
    float rate = float(maximum) * RN_Knight_HealRatio(profile);
    if (elapsed <= 0.0 || rate <= 0.0) return carry;
    return rate >= (room - carry) / elapsed ? room : carry + rate * elapsed;
}

/** 到期尾段也结算一次，持续受伤只续时，避免每次受伤把下一跳往后推。 */
void RN_Knight_HealDue(int client, float now)
{
    PlayerProfile profile;
    if (!RN_Knight_Current(client, profile)) return;
    float end = g_Knight_State[client].healUntil;
    float through = now < end ? now : end;
    float elapsed = through - g_Knight_State[client].healPaidThrough;
    if (elapsed <= 0.0) return;
    int maximum = GetEntProp(client, Prop_Data, "m_iMaxHealth");
    int room = maximum - GetEntProp(client, Prop_Data, "m_iHealth");
    float amount = RN_Knight_HealAmount(client, profile, elapsed, g_Knight_State[client].healCarry);
    g_Knight_State[client].healPaidThrough = through;
    g_Knight_State[client].healNext = now + 1.0;
    if (!RN_Math_Finite(amount) || amount < 0.0) { RN_Knight_Forget(client); return; }
    // 浮点的0.02 x 5 x 500可能落在49.999996，只修正整数边缘的计算误差。
    int heal = room > 0 ? (amount >= float(room) ? room : RoundToFloor(amount + 0.0001)) : 0;
    g_Knight_State[client].healCarry = room <= 0 || amount >= float(room) ? 0.0 : amount - float(heal);
    if (g_Knight_State[client].healCarry < 0.0) g_Knight_State[client].healCarry = 0.0;
    RN_Profile_RewardHealth(client, heal);
    if (now >= end)
    {
        g_Knight_State[client].healUntil = 0.0;
    }
}
