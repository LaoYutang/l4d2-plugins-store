#if defined _rn_notify_included
 #endinput
#endif
#define _rn_notify_included

/** 随机奖项的提示来源；仅作本次结算记录，不进入个人档案。 */
enum RN_RewardSource
{
    RN_REWARD_NONE = -1,
    RN_REWARD_THIN,
    RN_REWARD_GRAND,
    RN_REWARD_FAITH,
    RN_REWARD_D4,
    RN_REWARD_SOURCE_COUNT
}

/** 首次启动时钟只公告一次，等待阶段不累计难度时间。 */
void RN_Notify_Started()
{
    PrintToChatAll("\x04[Rogue]\x01已出门，时间难度开始计时。");
}

/** 升级公告只接收调用方快照，不反向读取经验/难度模块。 */
void RN_Notify_Upgrade(int level, float progress, int gained, int basicChoices)
{
    PrintToChatAll("\x04[Rogue]\x01 团队提升%d级，当前%d级 %.1f%%；每人基础选择+%d。",
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
    PrintToChat(client, "\x04[Rogue]\x01 待选%d次，ROLL %d；输入 !ba 选卡，!buff 查看。",
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
    PrintToChatAll("\x04[Rogue]\x01 有效时间%.1f分钟，难度档位%d。", elapsed/60.0, tier);
}

/** 选卡完成时统一显示特殊卡名称；实际效果已经原子提交。 */
void RN_Notify_Selected(int client, int buff)
{
    char name[64];
    RN_Buff_Name(buff, name, sizeof(name));
    PrintToChat(client, "\x04[Rogue]\x01 获得：%s。", name);
}

/** 公告名保留完整UTF-8字符，给卡名、次数与台词留足单行空间。 */
void RN_Notify_Name(int client, char[] name, int maxlength)
{
    char full[MAX_NAME_LENGTH];
    GetClientName(client, full, sizeof(full));
    RN_Common_ShortText(full, name, maxlength);
}

/** 四级卡与传说信念的全服台词；主体与长台词分行，不使用超长分隔线。 */
void RN_Notify_Public(int client, const char[] title, int count, const char[] first, const char[] second = "")
{
    if (!RN_Common_Client(client) || IsFakeClient(client) || count <= 0) return;
    char name[64], rarity[32];
    RN_Notify_Name(client, name, sizeof(name));
    RN_Buff_RarityText(RARITY_LEGENDARY, rarity, sizeof(rarity));
    PrintToChatAll("\x04[Rogue]\x03 @%s\x01 %s x%d [%s]。", name, title, count, rarity);
    PrintToChatAll("\x04[Rogue]\x01 %s", first);
    if (second[0] != '\0') PrintToChatAll("\x04[Rogue]\x01 %s", second);
}

/** 已提交的实际获卡与信念奖项决定公告；同笔同卡合并，不能用层数净差猜测。 */
void RN_Notify_Applied(int client, ArrayList applied, ArrayList rewards)
{
    if (!RN_Common_Client(client) || IsFakeClient(client)) return;
    int counts[MAXBUFFENUM];
    for (int i = 0; i < applied.Length; i++) counts[applied.Get(i)]++;
    for (int buff = 1; buff < MAXBUFFENUM; buff++)
    {
        if (counts[buff] == 0) continue;
        char name[64], title[96];
        RN_Buff_Name(buff, name, sizeof(name));
        FormatEx(title, sizeof(title), "获得%s", name);
        switch (buff)
        {
            case PLAYBUFF_POWANGFA:
                RN_Notify_Public(client, title, counts[buff], "骗人仔，你不要再出老千了！", "全剧终！");
            case PLAYBUFF_DAMOCLESSWORD:
                RN_Notify_Public(client, title, counts[buff], "达摩之剑高悬于顶！", "那么古尔丹，代价是什么？");
            case PLAYBUFF_SHUANGSHENGHUA:
                RN_Notify_Public(client, title, counts[buff], "我听见了双生花的回响！");
            case PLAYBUFF_SHENGSHENGBUXI:
                RN_Notify_Public(client, title, counts[buff], "我看到了生生不息的激荡！！！！", "那是一个骗子的伟大乐章！");
            case PLAYBUFF_XINLATIANSAI:
                RN_Notify_Public(client, title, counts[buff], "让世界感受痛苦吧！！！", "一袋米要扛几楼！一袋米要扛二楼！");
            case PLAYBUFF_ZHAOZAI:
                RN_Notify_Public(client, title, counts[buff], "请问谁能来救救我吗？", "他妈的...我的人生卡住了啊！");
            case PLAYBUFF_JIEWANGQUAN:
                RN_Notify_Public(client, title, counts[buff], "这是我最后的界王拳！");
            case PLAYBUFF_DIANREN:
                RN_Notify_Public(client, title, counts[buff], "话罢，天秋仔从口袋里掏出了几颗小零食！");
            case PLAYBUFF_FANXING:
                RN_Notify_Public(client, title, counts[buff], "命若繁星，望而不及");
            case PLAYBUFF_PATRICK:
                RN_Notify_Public(client, title, counts[buff], "艺术就是派大星！");
        }
    }
    int legendary;
    for (int i = 0; i < rewards.Length; i++)
        if (rewards.Get(i, 0) == RN_REWARD_FAITH && RN_Buff_Rarity(rewards.Get(i, 1)) == RARITY_LEGENDARY) legendary++;
    if (legendary > 0)
        RN_Notify_Public(client, "传说信念觉醒", legendary, "宗教？我们远比宗教更加宏伟", "我们拥有一个世界！");
}

/** 兑换完成只展示已提交的资源；繁星说明累计增量及扣本次选择后的实际待选。 */
void RN_Notify_Exchange(int client, int buff, PlayerProfile original, PlayerProfile result)
{
    if (buff != PLAYBUFF_YUXI && buff != PLAYBUFF_FANXING) return;
    int draws, pending, granted, unused;
    if (!RN_Profile_Budget(original, draws, unused) || !RN_Profile_Budget(result, granted, pending)) return;
    if (buff == PLAYBUFF_YUXI)
        PrintToChat(client, "\x04[Rogue]\x01 D4重置完成！已重抽%d次，待选%d次，ROLL %d。", draws, pending, result.rollLeft);
    else
        PrintToChat(client, "\x04[Rogue]\x01 繁星重配！已清空BUFF，原%d次，额外+%d次，待选%d次，ROLL %d。",
            draws, granted - draws, pending, result.rollLeft);
}

/** 重掷成功后报告服务器实际余额，失败调用方不发送。 */
void RN_Notify_Roll(int client, int remaining)
{
    PrintToChat(client, "\x04[Rogue]\x01 已重掷，剩余次数：%d。", remaining);
}

/** 最后一次读档明确提示耗尽，已消耗次数不会被提示改变。 */
void RN_Notify_NeverFall(int client, int remaining)
{
    if (remaining > 0) PrintToChat(client, "\x04[Rogue]\x01 读档战神生效，剩余%d次。", remaining);
    else PrintToChat(client, "\x04[Rogue]\x01 读档战神生效，次数已耗尽。");
}

/** 缴械的私聊与屏幕提示只发给被实际击落武器的真人。 */
void RN_Notify_Disarm(int client)
{
    if (!RN_Common_Client(client) || IsFakeClient(client)) return;
    PrintHintText(client, "[Rogue] 武器被Tank震掉了！");
    PrintToChat(client, "\x04[Rogue]\x01 Tank击落了你的近战武器。");
}

/** 风险动作完成后用动作前名字公告，SDK内死亡或断线不改变归属。 */
void RN_Notify_Risk(const char[] name, bool tank)
{
    if (tank) PrintToChatAll("\x04[Rogue]\x01 完了，全完了，\x03%s\x01被七黑贯穿丹田！", name);
    else PrintToChatAll("\x04[Rogue]\x03 %s\x01的达摩之剑掉落了！", name);
}

/** 任务失败按实际是否安排两秒重启给出结果。 */
void RN_Notify_Failed(bool restarting)
{
    if (restarting) PrintToChatAll("\x04[Rogue]\x01 战役失败，成长已清空；2秒后返回战役首图。");
    else PrintToChatAll("\x04[Rogue]\x01 战役失败，成长已清空；未安排自动重启。");
}

/** 有效重启执行前告知实际地图，错误目标或已取消任务不公告。 */
void RN_Notify_Restart(const char[] target)
{
    char shortMap[96];
    RN_Common_ShortText(target, shortMap, sizeof(shortMap));
    PrintToChatAll("\x04[Rogue]\x01 重启到战役首图：%s。", shortMap);
}

/** 成功结算后按来源合并实际抽取的奖项；短行私聊避免大量同名消息和截断。 */
void RN_Notify_Rewards(int client, ArrayList rewards, int empty = 0)
{
    if (!RN_Common_Client(client) || IsFakeClient(client)) return;
    static const char sources[][] = {"薄葬奖励", "风光大葬奖励", "激发奖励", "D4奖励"};
    for (int source = 0; source < view_as<int>(RN_REWARD_SOURCE_COUNT); source++)
    {
        int counts[MAXBUFFENUM];
        for (int i = 0; i < rewards.Length; i++)
            if (rewards.Get(i, 0) == source) counts[rewards.Get(i, 1)]++;
        char text[129];
        for (int buff = 1; buff < MAXBUFFENUM; buff++)
        {
            if (counts[buff] == 0) continue;
            char name[64], rarity[32], item[96];
            RN_Buff_Name(buff, name, sizeof(name));
            RN_Buff_RarityText(RN_Buff_Rarity(buff), rarity, sizeof(rarity));
            FormatEx(item, sizeof(item), "%s[%s]x%d", name, rarity, counts[buff]);
            if (text[0] != '\0' && strlen(text) + strlen(item) + strlen("、") >= sizeof(text))
            {
                PrintToChat(client, "\x04[Rogue]\x01 %s获得：%s。", sources[source], text);
                text[0] = '\0';
            }
            if (text[0] != '\0') StrCat(text, sizeof(text), "、");
            StrCat(text, sizeof(text), item);
        }
        if (text[0] != '\0')
            PrintToChat(client, "\x04[Rogue]\x01 %s获得：%s。", sources[source], text);
    }
    if (empty > 0)
        PrintToChat(client, "\x04[Rogue]\x01 风光大葬：倒爷（空奖）x%d。", empty);
}

/** 数据或奖励链拒绝时告知玩家，避免静默扣资源。 */
void RN_Notify_Rejected(int client)
{
    if (RN_Common_Client(client)) PrintToChat(client, "\x04[Rogue]\x01 此次结算未通过验证，资源已保留；详情见服务器日志。");
}
