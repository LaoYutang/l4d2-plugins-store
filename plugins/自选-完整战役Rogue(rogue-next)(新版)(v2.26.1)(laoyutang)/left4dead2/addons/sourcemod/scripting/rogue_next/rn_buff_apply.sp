#if defined _rn_buff_apply_included
 #endinput
#endif
#define _rn_buff_apply_included

/** 将自动奖励加入有界队列；该队列不再次执行手选双生花。 */
bool RN_Apply_Queue(ArrayList queue, int buff)
{
    if (buff <= PLAYBUFF_NULL || buff >= MAXBUFFENUM || queue.Length >= RN_MAX_REWARD_STEPS) return false;
    queue.Push(buff);
    return true;
}

/** 从合法奖池抽取一次并记录实际奖项；通知延后至提交，自动链禁止D4与繁星。 */
bool RN_Apply_Random(ArrayList queue, int rarity = -1, ArrayList rewards = null,
                     RN_RewardSource source = RN_REWARD_NONE, int profession = RN_PROFESSION_NONE)
{
    int buff;
    if (!RN_Pool_Draw(buff, rarity, true, profession) || !RN_Apply_Queue(queue, buff)) return false;
    if (rewards != null && source != RN_REWARD_NONE)
    {
        int reward[2];
        reward[0] = view_as<int>(source);
        reward[1] = buff;
        rewards.PushArray(reward, sizeof(reward));
    }
    return true;
}

/** 只清持续效果，保留身份、历史额外预算与剩余ROLL。 */
void RN_Apply_ClearEffects(PlayerProfile profile)
{
    for (int buff = 0; buff < MAXBUFFENUM; buff++) profile.buff[buff] = 0;
    profile.neverFallUsed = 0;
    profile.healProgress = 0.0;
    profile.deferredHealthBonus = 0;
}

/** 激发按当前信念的最高档准备一次奖励，不累计发放低档奖励。 */
bool RN_Apply_Faith(PlayerProfile profile, ArrayList queue, ArrayList rewards = null)
{
    int faith;
    if (!RN_Math_Multiply(profile.buff[PLAYBUFF_YELI], 3, faith) ||
        !RN_Math_Add(faith, profile.buff[PLAYBUFF_JIFA], faith)) return false;
    int rarity = -1;
    if (faith >= RN_Config_Int(RN_CVAR_FAITH_LEGENDARY_THRESHOLD)) rarity = RARITY_LEGENDARY;
    else if (faith >= RN_Config_Int(RN_CVAR_FAITH_EPIC_THRESHOLD)) rarity = RARITY_EPIC;
    else if (faith >= RN_Config_Int(RN_CVAR_FAITH_RARE_THRESHOLD)) rarity = RARITY_RARE;
    return rarity < 0 || RN_Apply_Random(queue, rarity, rewards, RN_REWARD_FAITH, profile.profession);
}

/** 处理一次普通/资源效果；只改事务副本和奖励队列，不操作实体。 */
bool RN_Apply_One(PlayerProfile profile, int buff, ArrayList queue, ArrayList rewards = null)
{
    if (!RN_Buff_Allowed(buff, profile.profession)) return false;
    if (RN_Buff_Persistent(buff))
    {
        if (!RN_Math_Add(profile.buff[buff], 1, profile.buff[buff])) return false;
        if (buff == PLAYBUFF_JIFA && !RN_Apply_Faith(profile, queue, rewards)) return false;
        return true;
    }
    switch (buff)
    {
        case PLAYBUFF_DUOBAOXIANREN:
            return RN_Math_Add(profile.rollLeft, RN_Config_Int(RN_CVAR_DUOBAOXIANREN_ROLLBONUS_SURV), profile.rollLeft);
        case PLAYBUFF_SHILENBAODI:
            return RN_Math_Add(profile.rollLeft, RN_Config_Int(RN_CVAR_SHILENBAODI_ROLLBONUS_SURV), profile.rollLeft);
        case PLAYBUFF_ZAILAIYIPING:
            return RN_Math_Add(profile.bonusChoices, 1, profile.bonusChoices);
        case PLAYBUFF_HAIYOUSANBEI:
            return RN_Math_Add(profile.bonusChoices, 3, profile.bonusChoices);
        case PLAYBUFF_DIANREN:
        {
            for (int id = 1; id < MAXBUFFENUM; id++)
                if (RN_Buff_Rarity(id) == RARITY_COMMON && RN_Buff_Allowed(id, profile.profession) && !RN_Apply_Queue(queue, id)) return false;
            return true;
        }
    }
    return false;
}

/** 顺序模拟整条奖励链；4096步是防递归工作量保护，失败整笔不提交。 */
bool RN_Apply_Drain(PlayerProfile profile, ArrayList queue, ArrayList rewards = null, ArrayList applied = null)
{
    for (int cursor = 0; cursor < queue.Length; cursor++)
    {
        int buff = queue.Get(cursor);
        if (!RN_Apply_One(profile, buff, queue, rewards)) return false;
        if (applied != null) applied.Push(buff);
    }
    return true;
}

/** D4兑换历史预算；繁星按旧累计重配并扣本次1次选择，双生花不能复制两者。 */
bool RN_Apply_PrepareChoice(PlayerProfile original, int selected, PlayerProfile result, ArrayList rewards = null,
                            ArrayList applied = null)
{
    if (!RN_Buff_Allowed(selected, original.profession)) return false;
    result = original;
    int total, pending;
    if (!RN_Profile_Budget(original, total, pending) || pending <= 0 ||
        !RN_Math_Add(result.usedChoices, 1, result.usedChoices)) return false;
    ArrayList queue = new ArrayList();
    bool valid = true;
    if (selected == PLAYBUFF_YUXI || selected == PLAYBUFF_FANXING)
    {
        if (applied != null) applied.Push(selected);
        RN_Apply_ClearEffects(result);
        result.usedChoices = total;
        if (selected == PLAYBUFF_FANXING)
        {
            int granted, added;
            valid = RN_Math_GrowChoices(total, RN_Config_Int(RN_CVAR_FANXING_PERCENT),
                RN_Config_Int(RN_CVAR_FANXING_CHOICES), granted, added) &&
                RN_Math_Add(result.bonusChoices, added, result.bonusChoices);
            result.usedChoices = 1;
        }
        else
        {
            if (total > RN_MAX_REWARD_STEPS) valid = false;
            for (int i = 0; valid && i < total; i++) valid = RN_Apply_Random(queue, -1, rewards, RN_REWARD_D4, original.profession);
        }
    }
    else
    {
        int copies = 1;
        if (selected != PLAYBUFF_SHUANGSHENGHUA)
            valid = RN_Math_Add(copies, original.buff[PLAYBUFF_SHUANGSHENGHUA], copies);
        if (copies > RN_MAX_REWARD_STEPS) valid = false;
        for (int i = 0; valid && i < copies; i++) valid = RN_Apply_Queue(queue, selected);
    }
    if (valid) valid = RN_Apply_Drain(result, queue, rewards, applied);
    delete queue;
    return valid;
}

/** 获血只按最终净上限增加；死亡/倒地奖励保存在档案并在可站立时兑现一次。 */
bool RN_Apply_PrepareHealth(PlayerProfile original, PlayerProfile result)
{
    int oldBonus, newBonus;
    if (!RN_Profile_HealthBonus(original, oldBonus) || !RN_Profile_HealthBonus(result, newBonus)) return false;
    int reward = newBonus > oldBonus ? newBonus - oldBonus : 0;
    return RN_Math_Add(result.deferredHealthBonus, reward, result.deferredHealthBonus);
}

/** 校验全部账本、个人属性及团队武器后原子提交，再执行可触发游戏事件的副作用。 */
bool RN_Apply_Commit(int client, PlayerProfile original, PlayerProfile result, bool clearOptions)
{
    int index = g_Profile_Index[client];
    if (!RN_Apply_PrepareHealth(original, result) || !RN_Profile_Validate(result) ||
        !RN_Profile_ValidateClient(client, result) ||
        !RN_Weapons_Validate(index, result)) return false;
    if (clearOptions)
    {
        if (!RN_Math_Add(result.optionVersion, 1, result.optionVersion)) return false;
        for (int i = 0; i < RN_OPTIONS; i++) result.optionBuff[i] = PLAYBUFF_NULL;
        result.optionStamp = 0.0;
    }
    RN_Profile_Save(index, result);
    RN_Profile_Recalc(client);
    RN_Knight_Reconcile(client);
    RN_Weapons_Refresh();
    return true;
}

/** 菜单验证通过后调用；失败不扣次数、不清选项、不发实体奖励。 */
bool RN_Apply_Choose(int client, int buff)
{
    if (!RN_Config_Enabled() || !RN_Common_Survivor(client) || IsFakeClient(client)) return false;
    PlayerProfile original, result;
    ArrayList rewards = new ArrayList(2);
    ArrayList applied = new ArrayList();
    if (!RN_Profile_Get(g_Profile_Index[client], original) ||
        !RN_Apply_PrepareChoice(original, buff, result, rewards, applied) ||
        !RN_Apply_Commit(client, original, result, true))
    {
        delete rewards;
        delete applied;
        LogError("[rogue-next] client=%d选卡事务被拒绝，buff=%d；未消费资源。", client, buff);
        RN_Notify_Rejected(client);
        return false;
    }
    if (buff == PLAYBUFF_YUXI || buff == PLAYBUFF_FANXING)
    {
        RN_Explosive_Forget(client);
        RN_Knight_Forget(client);
    }
    RN_Notify_Selected(client, buff);
    RN_Notify_Exchange(client, buff, original, result);
    RN_Notify_Applied(client, applied, rewards);
    RN_Notify_Rewards(client, rewards);
    delete rewards;
    delete applied;
    return true;
}

/** 有效死亡只调用一次；读取死亡前层数，奖励不消耗手选预算或再触发双生花。 */
bool RN_Apply_Death(int client)
{
    if (!RN_Config_Enabled() || !RN_Common_Survivor(client) || IsFakeClient(client)) return false;
    PlayerProfile original, result;
    if (!RN_Profile_Get(g_Profile_Index[client], original)) return false;
    result = original;
    int layers;
    if (!RN_Math_Add(original.buff[PLAYBUFF_BOZANG], original.buff[PLAYBUFF_FENGGUANGDAZANG], layers) ||
        layers > RN_MAX_REWARD_STEPS) return false;
    ArrayList queue = new ArrayList();
    ArrayList rewards = new ArrayList(2);
    ArrayList applied = new ArrayList();
    bool valid = true;
    int empty;
    for (int i = 0; valid && i < original.buff[PLAYBUFF_BOZANG]; i++)
        valid = RN_Apply_Random(queue, RARITY_COMMON, rewards, RN_REWARD_THIN, original.profession);
    for (int i = 0; valid && i < original.buff[PLAYBUFF_FENGGUANGDAZANG]; i++)
    {
        if (GetRandomInt(0, 1) == 1) valid = RN_Apply_Random(queue, RARITY_RARE, rewards, RN_REWARD_GRAND, original.profession);
        else empty++;
    }
    if (valid) valid = RN_Apply_Drain(result, queue, rewards, applied);
    delete queue;
    if (!valid || !RN_Apply_Commit(client, original, result, false))
    {
        delete rewards;
        delete applied;
        LogError("[rogue-next] client=%d死亡奖励事务被拒绝；档案保留。", client);
        return false;
    }
    RN_Notify_Applied(client, applied, rewards);
    RN_Notify_Rewards(client, rewards, empty);
    delete rewards;
    delete applied;
    return true;
}
