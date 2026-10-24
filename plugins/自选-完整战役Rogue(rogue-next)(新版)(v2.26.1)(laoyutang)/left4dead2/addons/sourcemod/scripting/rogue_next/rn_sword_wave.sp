#if defined _rn_sword_wave_included
 #endinput
#endif
#define _rn_sword_wave_included

#define RN_SWORD_LIMIT 64
#define RN_SWORD_CONTACT_LIMIT 128
#define RN_SWORD_SEGMENTS 6
#define RN_SWORD_INTERVAL 0.05
#define RN_SWORD_BEAM_LIFETIME 0.10
#define RN_SWORD_MIN_INTERVAL 0.20

enum struct RN_SwordContact
{
    int ref;
    int life;
    int serial;
    float impact[3];
}

enum struct RN_SwordWave
{
    MeleeWrite identity;
    int token;
    int profile;
    int professionVersion;
    int branchVersion;
    int branchStyle;
    int maxHits;
    int hitCount;
    bool accepted;
    bool finished;
    bool waiting;
    float started;
    float origin[3];
    float launch[3];
    float direction[3];
    float right[3];
    float remaining;
    float speed;
    float halfWidth;
    float damage;
    float critChance;
    float critMultiplier;
    float updated;
    StringMap seen;
    StringMap blocked;
    ArrayList contacts;
}

RN_SwordWave g_Sword_Waves[RN_SWORD_LIMIT];
int g_Sword_Active, g_Sword_Beam;
float g_Sword_NextUpdate, g_Sword_NextFire[MAXPLAYERS + 1];

enum struct RN_SwordBranchState
{
    int serial;
    int life;
    int epoch;
    int mapEpoch;
    int profile;
    int professionVersion;
    int branchVersion;
    int branch;
    int token;
    int attacks;
    float lastSwing;
}

RN_SwordBranchState g_Sword_BranchState[MAXPLAYERS + 1];

/** 分支身份或明确生命周期重置时记录蓄势起点，不改变已经发出的剑气。 */
void RN_Sword_BranchReset(int client)
{
    if (client < 1 || client > MaxClients) return;
    RN_SwordBranchState state;
    state.lastSwing = GetGameTime();
    if (RN_Common_Client(client))
    {
        state.serial = GetClientSerial(client);
        state.life = g_Common_Life[client];
        state.epoch = g_Run_Epoch;
        state.mapEpoch = g_Run_MapEpoch;
        state.profile = g_Profile_Index[client];
        PlayerProfile profile;
        if (RN_Profile_Get(state.profile, profile))
        {
            state.professionVersion = profile.professionVersion;
            state.branchVersion = profile.branchVersion;
            state.branch = RN_Branch_Get(client);
        }
    }
    g_Sword_BranchState[client] = state;
}

/** 完整清档与地图生命周期可独立清除分支进度，不借切枪清理推定策略。 */
void RN_Sword_BranchClear()
{
    for (int client = 1; client <= MaxClients; client++) RN_Sword_BranchReset(client);
}

/** 只按已确认的真实出刀提交一次；槽满或剑气未生成不把三刀改成三次发射。 */
int RN_Sword_BranchAttack(int client, int token, MeleeWrite capture, PlayerProfile profile)
{
    int branch;
    if (RN_Branch_Active(profile, RN_BRANCH_IAI)) branch = RN_BRANCH_IAI;
    else if (RN_Branch_Active(profile, RN_BRANCH_SWORDMASTER)) branch = RN_BRANCH_SWORDMASTER;
    else return 0;
    RN_SwordBranchState state;
    state = g_Sword_BranchState[client];
    if (state.serial != capture.serial || state.life != capture.life || state.epoch != capture.epoch
        || state.mapEpoch != capture.mapEpoch || state.profile != g_Profile_Index[client]
        || state.professionVersion != profile.professionVersion || state.branchVersion != profile.branchVersion
        || state.branch != branch)
    {
        RN_Sword_BranchReset(client);
        state = g_Sword_BranchState[client];
    }
    if (token == 0 || state.token == token) return 0;
    int style;
    if (branch == RN_BRANCH_IAI && capture.started - state.lastSwing >= 2.0) style = branch;
    if (branch == RN_BRANCH_SWORDMASTER)
    {
        if (++state.attacks == 3) { state.attacks = 0; style = branch; }
    }
    state.token = token;
    state.lastSwing = capture.started;
    g_Sword_BranchState[client] = state;
    return style;
}

/** 独立倍率只写当前剑气，宽度同时供可见弧线与实际扫掠使用，名额保持原值。 */
bool RN_Sword_BranchApply(RN_SwordWave wave, int style)
{
    if (wave.branchStyle != 0) return true;
    if (style != RN_BRANCH_IAI && style != RN_BRANCH_SWORDMASTER) return true;
    float damage = wave.damage * (style == RN_BRANCH_IAI ? 2.5 : 1.5);
    float width = wave.halfWidth * 2.0;
    if (!RN_Math_Finite(damage) || !RN_Math_Finite(damage * wave.critMultiplier)
        || !RN_Math_Finite(width)) return false;
    wave.damage = damage;
    wave.halfWidth = width;
    wave.branchStyle = style;
    return true;
}

/** 成功挥刀包含挥空；从正式挥击账本查身份，剑气槽满仍按同刀编号提交进度。 */
int RN_Sword_BranchConfirm(int token)
{
    if (token == 0) return 0;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (g_Leech_Current[client].token != token || !RN_Leech_Valid(client, g_Leech_Current[client], false)) continue;
        PlayerProfile profile;
        if (!RN_Profile_Get(g_Profile_Index[client], profile)) return 0;
        return RN_Sword_BranchAttack(client, token, g_Leech_Current[client].identity, profile);
    }
    return 0;
}

/** 释放前先失效编号，SDK回调重入或复用槽位不能继续旧剑气。 */
void RN_Sword_Stop(int slot)
{
    if (g_Sword_Waves[slot].token == 0) return;
    g_Sword_Waves[slot].token = 0;
    g_Sword_Active--;
    delete g_Sword_Waves[slot].seen;
    delete g_Sword_Waves[slot].blocked;
    delete g_Sword_Waves[slot].contacts;
}

/** 与近战生命周期共用清理，失效武器不再读取实体属性。 */
void RN_Sword_StopClient(int client)
{
    g_Sword_NextFire[client] = 0.0;
    for (int slot = 0; slot < RN_SWORD_LIMIT; slot++)
        if (g_Sword_Waves[slot].token != 0 && g_Sword_Waves[slot].identity.client == client)
            RN_Sword_Stop(slot);
}

/** 即使上一刀挥击上下文已结束，仍清除由该武器发出的飞行剑气。 */
void RN_Sword_ForgetEntity(int entity)
{
    for (int slot = 0; slot < RN_SWORD_LIMIT; slot++)
        if (g_Sword_Waves[slot].token != 0 && g_Sword_Waves[slot].identity.entity == entity)
            RN_Sword_Stop(slot);
}

/** 地图开始只预缓存游戏自带细光束，不创建实体或下载自定义素材。 */
void RN_Sword_MapStart()
{
    g_Sword_Beam = PrecacheModel("sprites/laserbeam.vmt", true);
    g_Sword_NextUpdate = 0.0;
}

/** 编号查找仅用于挥击回调；没有活跃剑气时直接退出。 */
int RN_Sword_Find(int token)
{
    if (token == 0 || g_Sword_Active == 0) return -1;
    for (int slot = 0; slot < RN_SWORD_LIMIT; slot++)
        if (g_Sword_Waves[slot].token == token) return slot;
    return -1;
}

/** 每次SDK前后核对完整身份；已发出的剑气不会因随后踉跄而重发。 */
bool RN_Sword_Valid(int slot, int token)
{
    if (token == 0 || g_Sword_Waves[slot].token != token || !RN_Config_Enabled() || !g_Run_MapReady) return false;
    RN_SwordWave wave;
    wave = g_Sword_Waves[slot];
    int client = wave.identity.client;
    if (!RN_Common_Survivor(client) || IsFakeClient(client) || !IsPlayerAlive(client)
        || RN_Common_Incapacitated(client) || GetClientSerial(client) != wave.identity.serial
        || g_Common_Life[client] != wave.identity.life || g_Run_Epoch != wave.identity.epoch
        || g_Run_MapEpoch != wave.identity.mapEpoch || g_Profile_Index[client] != wave.profile) return false;
    PlayerProfile profile;
    if (!RN_Profile_Get(wave.profile, profile) || profile.professionVersion != wave.professionVersion
        || profile.branchVersion != wave.branchVersion
        || !RN_Profession_Sword(profile)) return false;
    int weapon = EntRefToEntIndex(wave.identity.ref);
    return RN_Common_Melee(weapon) && GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity") == client
        && GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon") == weapon;
}

/** pre建立剑气候选与输出快照，成功挥击确认后才允许飞行。 */
void RN_Sword_Pre(int client, int token, MeleeWrite capture)
{
    PlayerProfile profile;
    float now = GetGameTime();
    if (g_Sword_Beam <= 0 || !g_Run_MapReady || now < g_Sword_NextFire[client]
        || !RN_Profile_Get(g_Profile_Index[client], profile) || !RN_Profession_Sword(profile)) return;
    int slot = -1;
    for (int i = 0; i < RN_SWORD_LIMIT; i++)
        if (g_Sword_Waves[i].token == 0) { slot = i; break; }
    if (slot < 0) return;
    RN_SwordWave wave;
    wave.identity = capture;
    wave.token = token;
    wave.profile = g_Profile_Index[client];
    wave.professionVersion = profile.professionVersion;
    wave.branchVersion = profile.branchVersion;
    wave.maxHits = RN_Profession_SwordHits(profile);
    wave.started = now;
    wave.updated = now;
    wave.remaining = RN_Profession_SwordRange(profile);
    wave.speed = RN_Config_Float(RN_CVAR_SWORD_WAVE_SPEED);
    wave.halfWidth = RN_Config_Float(RN_CVAR_SWORD_WAVE_HALFWIDTH);
    wave.damage = RN_Combat_MeleeBase(profile) * RN_Profession_SwordDamageFactor(profile)
        * RN_Branch_SourceFactor(client);
    wave.critChance = RN_Stats_Get(profile, RN_STAT_CRIT_CHANCE);
    wave.critMultiplier = RN_Stats_Get(profile, RN_STAT_CRIT_MULTIPLIER);
    if (!RN_Math_Finite(wave.damage) || !RN_Math_Finite(wave.damage * wave.critMultiplier)) return;
    float angles[3], up[3];
    GetClientEyePosition(client, wave.origin);
    wave.launch = wave.origin;
    GetClientEyeAngles(client, angles);
    angles[2] = 0.0;
    GetAngleVectors(angles, wave.direction, wave.right, up);
    wave.seen = new StringMap();
    wave.blocked = new StringMap();
    wave.contacts = new ArrayList(sizeof(RN_SwordContact));
    g_Sword_Waves[slot] = wave;
    g_Sword_Active++;
}

/** 当前挥击独立同步发射冷却与截止时间，剑气已命中结束也不能丢失攻速确认。 */
void RN_Sword_SyncSwing(int client, int token)
{
    if (g_Leech_Current[client].token != token || !RN_Leech_Valid(client, g_Leech_Current[client], false)) return;
    int weapon = EntRefToEntIndex(g_Leech_Current[client].identity.ref);
    float next = GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack");
    float playerNext = GetEntPropFloat(client, Prop_Send, "m_flNextAttack");
    if (playerNext > next) next = playerNext;
    float minimum = g_Leech_Current[client].identity.started + RN_SWORD_MIN_INTERVAL;
    if (!RN_Math_Finite(next) || next < minimum) next = minimum;
    g_Sword_NextFire[client] = next;
    g_Leech_Current[client].end = next;
}

/** 成功挥击只发一次；失败或被其他插件拦截的候选立即释放。 */
void RN_Sword_Finish(int token, bool accepted)
{
    int style = accepted ? RN_Sword_BranchConfirm(token) : 0;
    int slot = RN_Sword_Find(token);
    if (slot < 0) return;
    if (!accepted || !RN_Sword_Valid(slot, token)) { RN_Sword_Stop(slot); return; }
    if (g_Sword_Waves[slot].accepted) return;
    if (!RN_Sword_BranchApply(g_Sword_Waves[slot], style))
    {
        RN_Profession_Warn("转职剑气伤害/宽度");
        RN_Sword_Stop(slot);
        return;
    }
    g_Sword_Waves[slot].accepted = true;
    g_Sword_Waves[slot].finished = RN_Sword_LaunchBlocked(g_Sword_Waves[slot]);
    RN_Sword_SyncSwing(g_Sword_Waves[slot].identity.client, token);
    RequestFrame(RN_Sword_AttackFrame, token);
}

/** 下一帧按当前成功挥击确认攻速，与仍在飞行的剑气槽位无关，旧编号不能影响新刀。 */
public void RN_Sword_AttackFrame(any token)
{
    if (token == 0) return;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (g_Leech_Current[client].token != token) continue;
        if (g_Melee_EventToken[client] == token) g_Melee_EventToken[client] = 0;
        if (!RN_Leech_Valid(client, g_Leech_Current[client], false)) return;
        MeleeWrite capture;
        capture = g_Leech_Current[client].identity;
        int weapon = EntRefToEntIndex(capture.ref);
        float next = GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack");
        if (next > capture.started && next > capture.baseNext)
            RN_Melee_Apply(capture, next, capture.started, token);
        RN_Sword_SyncSwing(client, token);
        return;
    }
}

/** 真实近战事件为detour时序提供兜底，和post共用同刀编号及截止时间。 */
public void RN_Sword_OnFire(Event event, const char[] name, bool dontBroadcast)
{
    char weaponName[32];
    event.GetString("weapon", weaponName, sizeof(weaponName));
    if (!StrEqual(weaponName, "melee")) return;
    int client = GetClientOfUserId(event.GetInt("userid"));
    int weapon = RN_Melee_Weapon(client);
    if (weapon <= MaxClients || GetGameTime() < g_Sword_NextFire[client]) return;
    PlayerProfile profile;
    if (!RN_Profile_Get(g_Profile_Index[client], profile) || !RN_Profession_Sword(profile)) return;
    if (g_Leech_Candidate[client].token == 0)
    {
        RN_Melee_Capture(client, weapon);
        g_Melee_EventToken[client] = g_Leech_Candidate[client].token;
    }
    RN_Leech_Finish(client, true, GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack"));
}

/** 弧线与尾迹统一使用可传输的有限寿命；0.05秒会量化为永久光束，停止后不再重画。 */
void RN_Sword_Draw(RN_SwordWave wave, const float destination[3])
{
    int trail[4] = {10, 65, 130, 45};
    int color[4] = {20, 100, 180, 120};
    if (wave.branchStyle == RN_BRANCH_IAI)
    {
        trail[0] = 130; trail[1] = 15; trail[2] = 15; trail[3] = 60;
        color[0] = 230; color[1] = 35; color[2] = 35; color[3] = 180;
    }
    else if (wave.branchStyle == RN_BRANCH_SWORDMASTER)
    {
        trail[0] = 130; trail[1] = 95; trail[2] = 10; trail[3] = 60;
        color[0] = 245; color[1] = 205; color[2] = 35; color[3] = 180;
    }
    TE_SetupBeamPoints(wave.origin, destination, g_Sword_Beam, 0, 0, 0, RN_SWORD_BEAM_LIFETIME, 0.8, 0.4, 0, 0.0, trail, 0);
    TE_SendToAllInRange(destination, RangeType_Visibility);
    float previous[3], point[3];
    for (int segment = 0; segment <= RN_SWORD_SEGMENTS; segment++)
    {
        RN_Sword_ArcPoint(wave, destination, segment, point);
        if (segment > 0)
        {
            TE_SetupBeamPoints(previous, point, g_Sword_Beam, 0, 0, 0, RN_SWORD_BEAM_LIFETIME, 1.5, 1.5, 0, 0.0, color, 0);
            TE_SendToAllInRange(destination, RangeType_Visibility);
        }
        previous = point;
    }
}

/** 共用帧入口推进榴弹及最多64道20Hz剑气，空闲不做射线查询。 */
public void OnGameFrame()
{
    RN_Grenade_Frame();
    if (g_Sword_Active == 0) return;
    float now = GetGameTime();
    if (now < g_Sword_NextUpdate) return;
    g_Sword_NextUpdate = now + RN_SWORD_INTERVAL;
    for (int slot = 0; slot < RN_SWORD_LIMIT; slot++)
    {
        int token = g_Sword_Waves[slot].token;
        if (token == 0) continue;
        if (!RN_Sword_Valid(slot, token)) { RN_Sword_Stop(slot); continue; }
        if (!g_Sword_Waves[slot].accepted) continue;
        RN_Sword_Step(slot, now);
    }
}
