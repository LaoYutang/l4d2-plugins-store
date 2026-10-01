#if defined _rn_weapons_included
 #endinput
#endif
#define _rn_weapons_included

static const char g_Weapons_Names[18][] = {
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
  "weapon_pistol_magnum"
};

int g_Weapons_ClipBase[18];
float g_Weapons_ReloadBase[18];
float g_Weapons_CycleBase[18];
bool g_Weapons_Captured;

/** 在游戏武器脚本可用时读取部署基线，不硬编码/累乘上次贡献。 */
void RN_Weapons_Capture()
{
    for (int i = 0; i < 18; i++)
    {
        g_Weapons_ClipBase[i] = L4D2_GetIntWeaponAttribute(g_Weapons_Names[i], L4D2IWA_ClipSize);
        g_Weapons_ReloadBase[i] = L4D2_GetFloatWeaponAttribute(g_Weapons_Names[i], L4D2FWA_ReloadDuration);
        g_Weapons_CycleBase[i] = L4D2_GetFloatWeaponAttribute(g_Weapons_Names[i], L4D2FWA_CycleTime);
    }
    g_Weapons_Captured = true;
}

/** 汇总在线队伍2真人档案；override用于提交前验证候选档案。 */
bool RN_Weapons_Totals(int overrideIndex, PlayerProfile proposed, int &magazine, int &reload, int &cycle)
{
    magazine = 0; reload = 0; cycle = 0;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!RN_Common_Survivor(client) || IsFakeClient(client)) continue;
        int index = g_Profile_Index[client];
        PlayerProfile profile;
        if (index == overrideIndex && overrideIndex >= 0) profile = proposed;
        else if (!RN_Profile_Get(index, profile)) continue;
        int a, b, c;
        if (!RN_Math_Add(magazine, profile.buff[PLAYBUFF_MAGAZINE], a) ||
            !RN_Math_Add(reload, profile.buff[PLAYBUFF_RELOADSPEED], b) ||
            !RN_Math_Add(cycle, profile.buff[PLAYBUFF_FIRERATE], c)) return false;
        magazine = a; reload = b; cycle = c;
    }
    return true;
}

/** 对所有武器准备结果后再写入，clip上界与浮点异常不能部分提交。 */
bool RN_Weapons_Compute(int magazine, int reload, int cycle, int clips[18], float durations[18], float cycles[18])
{
    if (!g_Weapons_Captured) return true;
    float magFactor = 1.0 + float(magazine)*RN_Config_Float(RN_CVAR_MAGAZINEMULTIPLE_SURV);
    float reloadFactor = 1.0 - float(reload)*RN_Config_Float(RN_CVAR_RELOADSPEEDMULTIPLE_SURV);
    float cycleFactor = 1.0 - float(cycle)*RN_Config_Float(RN_CVAR_FIRERATEMULTIPLE_SURV);
    if (!RN_Math_Finite(magFactor) || !RN_Math_Finite(reloadFactor) || !RN_Math_Finite(cycleFactor)) return false;
    for (int i = 0; i < 18; i++)
    {
        float clip = float(g_Weapons_ClipBase[i])*magFactor;
        float duration = g_Weapons_ReloadBase[i]*reloadFactor;
        float interval = g_Weapons_CycleBase[i]*cycleFactor;
        if (!RN_Math_Finite(clip) || !RN_Math_Finite(duration) || !RN_Math_Finite(interval) ||
            clip < 0.0 || clip >= RN_INT_FLOAT_LIMIT) return false;
        clips[i] = RoundToNearest(clip);
        durations[i] = duration < 0.001 ? 0.001 : duration;
        cycles[i] = interval < 0.001 ? 0.001 : interval;
    }
    return true;
}

/** 获卡/配置重算前验证武器结果，尚未创建游戏武器时仅验证账本汇总。 */
bool RN_Weapons_Validate(int overrideIndex, PlayerProfile proposed)
{
    int magazine, reload, cycle, clips[18];
    float durations[18], cycles[18];
    return RN_Weapons_Totals(overrideIndex, proposed, magazine, reload, cycle) &&
        RN_Weapons_Compute(magazine, reload, cycle, clips, durations, cycles);
}

/** 已提交档案后刷新全队贡献，死者留队者计入，BOT受益但不贡献层数。 */
void RN_Weapons_Refresh()
{
    if (!g_Weapons_Captured) return;
    if (!RN_Config_Enabled()) { RN_Weapons_Restore(); return; }
    PlayerProfile empty;
    int magazine, reload, cycle, clips[18];
    float durations[18], cycles[18];
    if (!RN_Weapons_Totals(-1, empty, magazine, reload, cycle) ||
        !RN_Weapons_Compute(magazine, reload, cycle, clips, durations, cycles))
    {
        LogError("[rogue-next] 团队武器结果无法表达，保留最后一次合法武器属性。");
        return;
    }
    for (int i = 0; i < 18; i++)
    {
        L4D2_SetIntWeaponAttribute(g_Weapons_Names[i], L4D2IWA_ClipSize, clips[i]);
        L4D2_SetFloatWeaponAttribute(g_Weapons_Names[i], L4D2FWA_ReloadDuration, durations[i]);
        L4D2_SetFloatWeaponAttribute(g_Weapons_Names[i], L4D2FWA_CycleTime, cycles[i]);
    }
}

/** 完整清理或地图结束恢复自身基线，不依赖档案是否已经被清空。 */
void RN_Weapons_Restore()
{
    if (!g_Weapons_Captured) return;
    for (int i = 0; i < 18; i++)
    {
        L4D2_SetIntWeaponAttribute(g_Weapons_Names[i], L4D2IWA_ClipSize, g_Weapons_ClipBase[i]);
        L4D2_SetFloatWeaponAttribute(g_Weapons_Names[i], L4D2FWA_ReloadDuration, g_Weapons_ReloadBase[i]);
        L4D2_SetFloatWeaponAttribute(g_Weapons_Names[i], L4D2FWA_CycleTime, g_Weapons_CycleBase[i]);
    }
}
