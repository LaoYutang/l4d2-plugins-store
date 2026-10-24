#if defined _rn_weapons_included
 #endinput
#endif
#define _rn_weapons_included

// 前18种共用普通枪械判定/射速；末尾榴弹发射器仅参与换弹。
static const char g_Weapons_Names[19][] = {
  "weapon_pumpshotgun",
  "weapon_shotgun_chrome",
  "weapon_smg",
  "weapon_smg_silenced",
  "weapon_smg_mp5",
  "weapon_autoshotgun",
  "weapon_shotgun_spas",
  "weapon_rifle",
  "weapon_rifle_ak47",
  "weapon_rifle_desert",
  "weapon_rifle_sg552",
  "weapon_rifle_m60",
  "weapon_hunting_rifle",
  "weapon_sniper_military",
  "weapon_sniper_scout",
  "weapon_sniper_awp",
  "weapon_pistol",
  "weapon_pistol_magnum",
  "weapon_grenade_launcher"
};

float g_Weapons_ReloadBase[sizeof(g_Weapons_Names)];
float g_Weapons_CycleBase[18];
bool g_Weapons_Captured;

/** 固定枪械表共用实体分类；职业不把近战、电锯或榴弹发射器视为普通枪伤。 */
int RN_Weapons_Index(int entity)
{
    if (entity <= MaxClients || !IsValidEntity(entity)) return -1;
    char classname[64];
    GetEntityClassname(entity, classname, sizeof(classname));
    for (int i = 0; i < sizeof(g_Weapons_CycleBase); i++)
        if (StrEqual(classname, g_Weapons_Names[i])) return i;
    return -1;
}

// 前18项保留旧插件实测值；榴弹动画换弹3.6秒，不含开火后0.5秒等待。
// 脚本未提供正时长时，不能直接乘成0.001秒。
static const float g_Weapons_ReloadDefault[sizeof(g_Weapons_Names)] = {
    1.13, 1.13, 2.36, 2.30, 3.03, 1.10, 1.23, 2.20, 2.57,
    3.36, 3.23, 2.43, 3.16, 3.37, 2.93, 3.73, 2.06, 2.06, 3.6
};
static const float g_Weapons_CycleDefault[18] = {
    0.5, 0.5, 0.0625, 0.0625, 0.075, 0.15, 0.15, 0.0875, 0.13,
    0.07, 0.0825, 0.11, 0.25, 0.25, 0.9, 1.05, 0.175, 0.3
};

/** 按原目录读取类名，供专用武器后端使用同一份分类。 */
void RN_Weapons_Name(int index, char[] output, int length)
{
    strcopy(output, length, g_Weapons_Names[index]);
}

/** 正部署值优先，非正哨兵使用既有正常时长；各后端共用。 */
float RN_Weapons_NormalBase(int index, bool reload)
{
    float raw = reload ? g_Weapons_ReloadBase[index] : g_Weapons_CycleBase[index];
    return raw > 0.0 ? raw : (reload ? g_Weapons_ReloadDefault[index] : g_Weapons_CycleDefault[index]);
}

/** 每图只捕获原始部署值一次；保留动画哨兵，不能把自身输出再当基线。 */
void RN_Weapons_Capture()
{
    if (g_Weapons_Captured) return;
    int reloadDefaults, cycleDefaults;
    for (int i = 0; i < sizeof(g_Weapons_ReloadBase); i++)
    {
        g_Weapons_ReloadBase[i] = L4D2_GetFloatWeaponAttribute(g_Weapons_Names[i], L4D2FWA_ReloadDuration);
        if (g_Weapons_ReloadBase[i] <= 0.0) reloadDefaults++;
    }
    for (int i = 0; i < sizeof(g_Weapons_CycleBase); i++)
    {
        g_Weapons_CycleBase[i] = L4D2_GetFloatWeaponAttribute(g_Weapons_Names[i], L4D2FWA_CycleTime);
        if (g_Weapons_CycleBase[i] <= 0.0) cycleDefaults++;
    }
    g_Weapons_Captured = true;
    if (reloadDefaults > 0 || cycleDefaults > 0)
        LogMessage("[rogue-next] 武器时长基线：换弹%d项、射击%d项使用正常时长回退；无加成/清理仍保留原始脚本值。",
            reloadDefaults, cycleDefaults);
}

/** 汇总在线队伍2真人档案；override用于提交前验证候选档案。 */
bool RN_Weapons_Totals(int overrideIndex, PlayerProfile proposed, int &reload, int &cycle)
{
    reload = 0; cycle = 0;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!RN_Common_Survivor(client) || IsFakeClient(client)) continue;
        int index = g_Profile_Index[client];
        PlayerProfile profile;
        if (index == overrideIndex && overrideIndex >= 0) profile = proposed;
        else if (!RN_Profile_Get(index, profile)) continue;
        int nextReload, nextCycle;
        if (!RN_Math_Add(reload, profile.buff[PLAYBUFF_RELOADSPEED], nextReload) ||
            !RN_Math_Add(cycle, profile.buff[PLAYBUFF_FIRERATE], nextCycle)) return false;
        reload = nextReload; cycle = nextCycle;
    }
    return true;
}

/** 团队武器倍率的唯一公式；查看与武器脚本修改共用。 */
bool RN_Weapons_Factors(int reload, int cycle, float &reloadFactor, float &cycleFactor)
{
    reloadFactor = 1.0 - float(reload)*RN_Config_Float(RN_CVAR_RELOADSPEEDMULTIPLE_SURV);
    cycleFactor = 1.0 - float(cycle)*RN_Config_Float(RN_CVAR_FIRERATEMULTIPLE_SURV);
    return RN_Math_Finite(reloadFactor) && RN_Math_Finite(cycleFactor);
}

/** 无有效加成保留原始哨兵；有加成用正时长或旧正常时长，异常不能部分提交。 */
bool RN_Weapons_Compute(int reload, int cycle, float durations[sizeof(g_Weapons_Names)], float cycles[sizeof(g_Weapons_CycleBase)])
{
    if (!g_Weapons_Captured) return true;
    float reloadFactor, cycleFactor;
    if (!RN_Weapons_Factors(reload, cycle, reloadFactor, cycleFactor)) return false;
    for (int i = 0; i < sizeof(g_Weapons_ReloadBase); i++)
    {
        float reloadBase = RN_Weapons_NormalBase(i, true);
        float duration = reloadFactor == 1.0 ? g_Weapons_ReloadBase[i] : reloadBase * reloadFactor;
        if (!RN_Math_Finite(g_Weapons_ReloadBase[i]) || !RN_Math_Finite(duration)) return false;
        durations[i] = reloadFactor != 1.0 && duration < 0.001 ? 0.001 : duration;
    }
    for (int i = 0; i < sizeof(g_Weapons_CycleBase); i++)
    {
        float cycleBase = RN_Weapons_NormalBase(i, false);
        float interval = cycleFactor == 1.0 ? g_Weapons_CycleBase[i] : cycleBase * cycleFactor;
        if (!RN_Math_Finite(g_Weapons_CycleBase[i]) || !RN_Math_Finite(interval)) return false;
        cycles[i] = cycleFactor != 1.0 && interval < 0.001 ? 0.001 : interval;
    }
    return RN_Shotgun_Validate(durations, cycles);
}

/** 获卡/配置重算前验证武器结果，尚未创建游戏武器时仅验证账本汇总。 */
bool RN_Weapons_Validate(int overrideIndex, PlayerProfile proposed)
{
    int reload, cycle;
    float durations[sizeof(g_Weapons_Names)], cycles[sizeof(g_Weapons_CycleBase)];
    return RN_Weapons_Totals(overrideIndex, proposed, reload, cycle) &&
        RN_Weapons_Compute(reload, cycle, durations, cycles);
}

/** 已提交档案后刷新全队贡献，死者留队者计入，BOT受益但不贡献层数。 */
void RN_Weapons_Refresh()
{
    if (!g_Weapons_Captured) return;
    if (!RN_Config_Enabled()) { RN_Weapons_Restore(); return; }
    PlayerProfile empty;
    int reload, cycle;
    float durations[sizeof(g_Weapons_Names)], cycles[sizeof(g_Weapons_CycleBase)];
    if (!RN_Weapons_Totals(-1, empty, reload, cycle) ||
        !RN_Weapons_Compute(reload, cycle, durations, cycles))
    {
        LogError("[rogue-next] 团队武器结果无法表达，保留最后一次合法武器属性。");
        return;
    }
    RN_Shotgun_Update(durations, cycles);
    for (int i = 0; i < sizeof(g_Weapons_ReloadBase); i++)
        if (!RN_Shotgun_Index(i)) L4D2_SetFloatWeaponAttribute(g_Weapons_Names[i], L4D2FWA_ReloadDuration, durations[i]);
    for (int i = 0; i < sizeof(g_Weapons_CycleBase); i++)
        if (!RN_Shotgun_Index(i)) L4D2_SetFloatWeaponAttribute(g_Weapons_Names[i], L4D2FWA_CycleTime, cycles[i]);
    if (RN_Config_Int(RN_CVAR_DEBUG) != 0)
        LogMessage("[rogue-next] 武器时长：reload=%d AWP raw=%.4f result=%.4f cycle=%d AWP raw=%.4f result=%.4f。",
            reload, g_Weapons_ReloadBase[15], durations[15], cycle, g_Weapons_CycleBase[15], cycles[15]);
}

/** 完整清理或地图结束恢复自身基线，不依赖档案是否已经被清空。 */
void RN_Weapons_Restore()
{
    RN_Shotgun_Clear();
    if (!g_Weapons_Captured) return;
    for (int i = 0; i < sizeof(g_Weapons_ReloadBase); i++)
        if (!RN_Shotgun_Index(i)) L4D2_SetFloatWeaponAttribute(g_Weapons_Names[i], L4D2FWA_ReloadDuration, g_Weapons_ReloadBase[i]);
    for (int i = 0; i < sizeof(g_Weapons_CycleBase); i++)
        if (!RN_Shotgun_Index(i)) L4D2_SetFloatWeaponAttribute(g_Weapons_Names[i], L4D2FWA_CycleTime, g_Weapons_CycleBase[i]);
}
