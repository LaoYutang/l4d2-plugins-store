#if defined _rn_hud_stats_included
 #endinput
#endif
#define _rn_hud_stats_included

ArrayList g_HUD_SpecialTotals;

/** 特感战役累计按稳定档案下标保存，不使用客户端槽位或修改BUFF档案。 */
void RN_HUDStats_Init()
{
    g_HUD_SpecialTotals = new ArrayList();
}

/** 死亡路由完成生命去重后原子入账；HUD与伤害统计开关不影响这份共用累计。 */
bool RN_HUDStats_Award(int attacker)
{
    if (!RN_Config_Enabled() || !RN_Common_ActiveRun() ||
        !RN_Common_Survivor(attacker) || IsFakeClient(attacker)) return false;
    int index = g_Profile_Index[attacker];
    if (index < 0 || index >= g_Profile_Records.Length) return false;
    int count;
    if (!RN_Math_Add(RN_HUDStats_Read(index), 1, count))
    {
        LogError("[rogue-next] 特感累计超出整数容量：profile=%d。", index);
        return false;
    }
    PlayerProfile profile;
    if (!RN_Profile_Get(index, profile) || !RN_Profile_Validate(profile, count))
    {
        LogError("[rogue-next] 特感入账令职业属性不可表达：profile=%d；保留累计及血量。", index);
        return false;
    }
    while (g_HUD_SpecialTotals.Length <= index) g_HUD_SpecialTotals.Push(0);
    g_HUD_SpecialTotals.Set(index, count);
    return true;
}

/** 无击杀的新档案显示0；读取不创建统计条目。 */
int RN_HUDStats_Read(int index)
{
    return g_HUD_SpecialTotals != null && index >= 0 && index < g_HUD_SpecialTotals.Length
        ? g_HUD_SpecialTotals.Get(index) : 0;
}

/** 仅完整清档归零，换章、死亡、托管和稳定SteamID重连均保留。 */
void RN_HUDStats_Clear()
{
    if (g_HUD_SpecialTotals != null) g_HUD_SpecialTotals.Clear();
}
