#if defined _rn_notify_included
 #endinput
#endif
#define _rn_notify_included

/** 首次启动时钟只公告一次，等待阶段不累计难度时间。 */
void RN_Notify_Started()
{
    PrintToChatAll("\x04[rogue]\x01已出门，时间难度开始计时。");
}

/** 升级公告只接收调用方快照，不反向读取经验/难度模块。 */
void RN_Notify_Upgrade(int level, float progress, int gained, int basicChoices)
{
    PrintToChatAll("\x04[rogue]\x01 团队提升%d级，当前%d级 %.1f%%；每人基础选择+%d。",
        gained, level, progress, basicChoices);
}

/** 玩家提示并更新档案提醒截止时间；不改变选项和资源账本。 */
void RN_Notify_Pending(int client, bool force = false)
{
    if (!RN_Common_Survivor(client) || IsFakeClient(client) || !RN_Config_Enabled()) return;
    PlayerProfile profile;
    if (!RN_Profile_Get(g_Profile_Index[client], profile)) return;
    int total, pending;
    if (!RN_Profile_Budget(profile, total, pending) || pending <= 0) return;
    float now = GetTickedTime();
    if (!force && (RN_Config_Int(RN_CVAR_REMIND_ENABLE) == 0 || now < profile.nextRemindAt)) return;
    profile.nextRemindAt = now + RN_Config_Float(RN_CVAR_REMIND_INTERVAL);
    RN_Profile_Save(g_Profile_Index[client], profile);
    PrintToChat(client, "\x04[rogue]\x01 待选%d次，ROLL %d；输入 !ba 选卡，!buff 查看。",
        pending, profile.rollLeft);
}

/** 对本轮在线真人提示，不提示旁观与BOT，不自动弹菜单。 */
void RN_Notify_AllPending(bool force = true)
{
    for (int client = 1; client <= MaxClients; client++) RN_Notify_Pending(client, force);
}

/** 显示正常配置下的阶段变更；公告开关由调用方决定。 */
void RN_Notify_Tier(int tier, float elapsed)
{
    PrintToChatAll("\x04[rogue]\x01 有效时间%.1f分钟，难度档位%d。", elapsed/60.0, tier);
}

/** 选卡完成时统一显示特殊卡名称；实际效果已经原子提交。 */
void RN_Notify_Selected(int client, int buff)
{
    char name[64];
    RN_Buff_Name(buff, name, sizeof(name));
    PrintToChat(client, "\x04[rogue]\x01 获得：%s。", name);
}

/** 数据或奖励链拒绝时告知玩家，避免静默扣资源。 */
void RN_Notify_Rejected(int client)
{
    if (RN_Common_Client(client)) PrintToChat(client, "\x04[rogue]\x01 此次结算未通过验证，资源已保留；详情见服务器日志。");
}
