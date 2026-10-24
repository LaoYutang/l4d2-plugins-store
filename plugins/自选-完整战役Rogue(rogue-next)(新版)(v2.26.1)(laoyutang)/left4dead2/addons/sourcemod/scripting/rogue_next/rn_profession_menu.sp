#if defined _rn_profession_menu_included
 #endinput
#endif
#define _rn_profession_menu_included

Menu g_ProfessionMenu_Open[MAXPLAYERS + 1];

/** 职业关闭只取消职业选框，保留已选职业及已有BUFF候选。 */
void RN_ProfessionMenu_ConfigApplied()
{
    RN_BranchMenu_ConfigApplied();
    if (RN_Config_Int(RN_CVAR_PROFESSION_ENABLE) != 0) return;
    for (int client = 1; client <= MaxClients; client++)
        if (g_ProfessionMenu_Open[client] != null && g_Menu_Open[client] == g_ProfessionMenu_Open[client])
            RN_Menu_Close(client);
}

/** 整数百分比省略无意义的小数，小数保留原显示精度，不改变配置效果。 */
void RN_ProfessionMenu_PercentText(float value, char[] text, int maxlength)
{
    RN_Math_NumberText(value, text, maxlength, 1, true);
}

/** 骑士仅展示确认的三句文案；隐藏规则不额外写入选择提示或职业详情。 */
void RN_ProfessionMenu_KnightLine(PlayerProfile profile, int line, char[] text, int maxlength)
{
    char number[64];
    switch (line)
    {
        case 0:
        {
            RN_ProfessionMenu_PercentText(RN_Knight_AttackRatio(profile) * 100.0, number, sizeof(number));
            FormatEx(text, maxlength, "攻击附加自身最大生命 %s%% 的伤害。", number);
        }
        case 1: FormatEx(text, maxlength, "累计 %d 次有效受伤触发「受难爆发」。", RN_Knight_Hits(profile));
        case 2:
        {
            RN_Math_NumberText(RN_Config_Float(RN_CVAR_KNIGHT_BURST_RADIUS), number, sizeof(number), 1, true);
            FormatEx(text, maxlength, "「受难爆发」基础半径为 %s。", number);
        }
    }
}

/** 确认和查看共用简短特性说明；返回该特性是否在当前显示精度下有效。 */
bool RN_ProfessionMenu_Description(PlayerProfile profile, char[] text, int maxlength)
{
    char percent[64];
    float value;
    text[0] = '\0';
    switch (profile.profession)
    {
        case RN_PROFESSION_KNIGHT:
        {
            RN_ProfessionMenu_KnightLine(profile, 0, text, maxlength);
            return true;
        }
        case RN_PROFESSION_GUNSLINGER:
        {
            value = RN_Profession_GunRate(profile)*100.0;
            RN_ProfessionMenu_PercentText(value, percent, sizeof(percent));
            FormatEx(text, maxlength, "每级枪械伤害+%s%%", percent);
            return value >= 0.05;
        }
        case RN_PROFESSION_BLADEMASTER:
        {
            value = (RN_Profession_MeleeFactor(profile)-1.0)*100.0;
            bool immune = RN_Profession_DisarmImmune(profile);
            RN_ProfessionMenu_PercentText(value, percent, sizeof(percent));
            if (value >= 0.05) FormatEx(text, maxlength, "近战攻速+%s%%", percent);
            int hits = RN_Profession_SwordHits(profile);
            if (hits > 0)
            {
                char sword[48];
                FormatEx(sword, sizeof(sword), "%s剑气命中%d敌", text[0] != '\0' ? " " : "", hits);
                StrCat(text, maxlength, sword);
            }
            if (immune) StrCat(text, maxlength, text[0] != '\0' ? " 抗缴械" : "抗缴械");
            return value >= 0.05 || hits > 0 || immune;
        }
        case RN_PROFESSION_ELEMENTALIST:
        {
            value = RN_Profession_ElementFactor(profile);
            RN_Math_NumberText(value, percent, sizeof(percent), 2);
            FormatEx(text, maxlength, "元素概率x%s", percent);
            return value - 1.0 >= 0.005;
        }
        case RN_PROFESSION_SNIPER:
        {
            value = RN_Profession_SniperRate(profile)*100.0;
            RN_ProfessionMenu_PercentText(value, percent, sizeof(percent));
            FormatEx(text, maxlength, "狙击每100单位增伤%s%%", percent);
            return value >= 0.05 && g_Profession_SniperCapSquared > 0.0;
        }
        case RN_PROFESSION_REAPER:
        {
            char penalty[64];
            value = RN_Reaper_DamageRate(profile)*100.0;
            RN_ProfessionMenu_PercentText(value, percent, sizeof(percent));
            float incoming = RN_Reaper_PenaltyRate(profile)*100.0;
            RN_ProfessionMenu_PercentText(incoming, penalty, sizeof(penalty));
            FormatEx(text, maxlength, "每杀伤害+%s%% 减伤-%s%%", percent, penalty);
            return value >= 0.05 || incoming >= 0.05;
        }
        case RN_PROFESSION_MAGICIAN:
        {
            if (RN_Config_Int(RN_CVAR_GRENADE_ENABLE) == 0)
            {
                strcopy(text, maxlength, "榴弹机制已停用");
                return true;
            }
            value = RN_Config_Float(RN_CVAR_MAGICIAN_SPLIT_CHANCE);
            RN_ProfessionMenu_PercentText(value, percent, sizeof(percent));
            FormatEx(text, maxlength, "榴弹弹跳次数+%d 分裂%s%%", RN_Config_Int(RN_CVAR_MAGICIAN_BOUNCES), percent);
            return RN_Config_Int(RN_CVAR_MAGICIAN_BOUNCES) > 0 || value >= 0.05;
        }
    }
    return false;
}

/** 有效职业特性始终置顶；士兵枪伤并入共享属性合计，狙击能力仍显示独立倍率。 */
void RN_ProfessionMenu_Details(Menu menu, PlayerProfile profile)
{
    if (profile.profession == RN_PROFESSION_SNIPER && RN_Config_Int(RN_CVAR_PROFESSION_ENABLE) == 0)
        RN_Menu_Detail(menu, "职业限制：无冰火电、无免控");
    if (profile.profession == RN_PROFESSION_BLADEMASTER && RN_Config_Int(RN_CVAR_PROFESSION_ENABLE) == 0)
        RN_Menu_Detail(menu, "职业限制：无冰火电");
    if (profile.profession == RN_PROFESSION_NONE || RN_Config_Int(RN_CVAR_PROFESSION_ENABLE) == 0) return;
    char description[128];
    if (profile.profession == RN_PROFESSION_KNIGHT)
    {
        for (int line = 0; line < 3; line++)
        {
            RN_ProfessionMenu_KnightLine(profile, line, description, sizeof(description));
            RN_Menu_Detail(menu, "%s", description);
        }
    }
    else if (RN_ProfessionMenu_Description(profile, description, sizeof(description)))
        RN_Menu_Detail(menu, "职业特性：%s", description);
    if (RN_Config_Int(RN_CVAR_GRENADE_ENABLE) != 0 && RN_Profession_Is(profile, RN_PROFESSION_ELEMENTALIST) &&
        RN_Profession_Value(profile, PLAYBUFF_ART, RN_CVAR_ART_EXPLOSION_RADIUS_BONUS) > 0.0)
        RN_Menu_Number(menu, "榴弹爆炸：半径%s", RN_Magician_Radius(profile), 0);
    if (RN_Profession_Is(profile, RN_PROFESSION_REAPER))
    {
        RN_Menu_Detail(menu, "累计特感击杀：%d", RN_Reaper_Kills(profile));
        RN_Menu_Percentage(menu, "契约惩罚削减", (1.0 - RN_Reaper_Remaining(profile))*100.0);
        int soul = RN_Reaper_Heal(profile);
        if (soul > 0) RN_Menu_Detail(menu, "灵魂汲取：+%d实血/特感", soul);
    }
    if (RN_Config_Int(RN_CVAR_GRENADE_ENABLE) != 0 && RN_Profession_Is(profile, RN_PROFESSION_MAGICIAN))
    {
        char damage[64], radius[64], chance[64];
        float grenade = RN_Grenade_Damage(0);
        if (RN_Branch_Active(profile, RN_BRANCH_PEACE)) RN_Magician_PeaceDamage(profile, grenade);
        RN_Math_NumberText(grenade, damage, sizeof(damage), 1, true);
        RN_Math_NumberText(RN_Magician_Radius(profile), radius, sizeof(radius), 1, true);
        RN_ProfessionMenu_PercentText(RN_Magician_SplitChance(profile), chance, sizeof(chance));
        RN_Menu_Detail(menu, "榴弹基础伤害：%s 爆炸范围：%s", damage, radius);
        float decay = RN_Config_Float(RN_CVAR_GRENADE_BOUNCE_DAMAGE_DECAY);
        if (RN_Branch_Active(profile, RN_BRANCH_CHAOS)) RN_Menu_Detail(menu, "榴弹弹跳伤害：每次增加初始20%%");
        else if (decay > 0.0 && !RN_Branch_Active(profile, RN_BRANCH_PEACE))
        {
            char percent[64];
            RN_ProfessionMenu_PercentText(decay * 100.0, percent, sizeof(percent));
            RN_Menu_Detail(menu, "榴弹弹跳伤害：每次降低%s%%", percent);
        }
        int balance;
        RN_Magician_Balance(profile, balance);
        if (balance < 0) RN_Menu_Detail(menu, "榴弹弹跳次数：0次（预存%d）", balance);
        else RN_Menu_Detail(menu, "榴弹弹跳次数：%d次", RN_Magician_Bounces(profile));
        RN_Menu_Detail(menu, "榴弹分裂概率：%s%%", chance);
        RN_Menu_Detail(menu, "每100%%分裂多1发，余数概率再多1发");
    }
    if (RN_Profession_Sword(profile))
    {
        char distance[64], ratio[64];
        RN_Math_NumberText(RN_Profession_SwordRange(profile), distance, sizeof(distance), 1, true);
        RN_Math_NumberText(RN_Profession_SwordDamageFactor(profile)*100.0, ratio, sizeof(ratio), 1, true);
        RN_Menu_Detail(menu, "剑气距离：%s码", distance);
        RN_Menu_Detail(menu, "剑气伤害：%s%%近战，可暴击", ratio);
    }
    if (profile.profession == RN_PROFESSION_BLADEMASTER) RN_Menu_Detail(menu, "职业限制：无冰火电");
    if (profile.profession == RN_PROFESSION_SNIPER) RN_Menu_Detail(menu, "职业限制：无冰火电、无免控");
    int heal = RN_Profession_BerserkerHeal(profile);
    if (heal > 0) RN_Menu_Detail(menu, "特感击杀回血：+%d实血/杀", heal);
    RN_Menu_Percentage(menu, "狙击伤害（独立）", (RN_Profession_SniperPower(profile) - 1.0)*100.0);
    float explosive = RN_Stats_Percent(RN_Stats_Get(profile, RN_STAT_EXPLOSIVE_BULLET), true);
    float radius = RN_Stats_ExplosionRadius(profile, RN_Config_Float(RN_CVAR_EXPLOSIVE_BULLET_RADIUS));
    if (explosive > 0.0 && radius > 0.0)
    {
        char chance[64], range[64];
        RN_Math_NumberText(explosive, chance, sizeof(chance), 0);
        RN_Math_NumberText(radius, range, sizeof(range), 0);
        RN_Menu_Detail(menu, "爆裂子弹：%s%% 半径%s", chance, range);
        float factor = RN_Stats_Get(profile, RN_STAT_EXPLOSION_DAMAGE);
        if (factor > 1.0005) RN_Menu_Number(menu, "爆炸伤害：周边子弹伤害乘%s倍", factor, 2);
        else RN_Menu_Detail(menu, "爆炸伤害：周边完整子弹伤害");
    }
}

/** 成功提交后向本人解释实际参数，不把具体数值放入职业选框。 */
void RN_ProfessionMenu_Notify(int client, PlayerProfile profile)
{
    char name[64], description[128];
    RN_Profession_Name(profile.profession, name, sizeof(name));
    if (profile.profession == RN_PROFESSION_KNIGHT)
    {
        PrintToChat(client, "\x04[Rogue]\x01已选择%s。", name);
        for (int line = 0; line < 3; line++)
        {
            RN_ProfessionMenu_KnightLine(profile, line, description, sizeof(description));
            PrintToChat(client, "\x04[Rogue]\x01%s", description);
        }
        return;
    }
    RN_ProfessionMenu_Description(profile, description, sizeof(description));
    if (description[0] != '\0')
        PrintToChat(client, "\x04[Rogue]\x01已选择%s：%s。", name, description);
}

/** 独立菜单令牌校验战役、地图、会话、档案和职业版本，失败不写档案。 */
int RN_ProfessionMenu_Reason(Menu menu, int client, int item, PlayerProfile profile, int &profession)
{
    int reason = RN_Menu_EligibilityReason(client);
    if (reason == RN_MENU_NO_CHOICES && RN_Profile_Get(g_Profile_Index[client], profile) &&
        RN_Branch_NeedsProfession(profile)) reason = RN_MENU_ALLOWED;
    if (reason != RN_MENU_ALLOWED) return reason;
    if (RN_Config_Int(RN_CVAR_PROFESSION_ENABLE) == 0) return RN_MENU_PROFESSION_DISABLED;
    if (menu == null || g_Menu_Open[client] != menu || g_ProfessionMenu_Open[client] != menu) return RN_MENU_OLD_MENU;
    if (!RN_Profile_Get(g_Profile_Index[client], profile)) return RN_MENU_PROFILE;
    if (profile.profession != RN_PROFESSION_NONE) return RN_MENU_PROFESSION_CHOSEN;
    char info[128], parts[7][16];
    if (!menu.GetItem(item, info, sizeof(info)) || ExplodeString(info, ":", parts, sizeof(parts), sizeof(parts[])) != 7 ||
        !StrEqual(parts[0], "p")) return RN_MENU_ITEM;
    int values[6];
    for (int i = 0; i < sizeof(values); i++)
        if (!RN_Common_ParseUnsigned(parts[i+1], values[i])) return RN_MENU_ITEM;
    if (values[0] != g_Run_Epoch) return RN_MENU_OLD_RUN;
    if (values[1] != g_Run_MapEpoch) return RN_MENU_OLD_MAP;
    if (values[2] != GetClientSerial(client) || values[3] != g_Profile_Index[client]) return RN_MENU_OLD_SESSION;
    if (values[4] != profile.professionVersion) return RN_MENU_OLD_PROFESSION;
    profession = values[5];
    return profession > RN_PROFESSION_NONE && profession < RN_PROFESSION_COUNT ? RN_MENU_ALLOWED : RN_MENU_ITEM;
}

/** 只提交职业及其版本；免费选择不消费次数、ROLL，也不重抽或覆盖缓存候选。 */
public int RN_ProfessionMenu_OnChoice(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        for (int client = 1; client <= MaxClients; client++)
        {
            if (g_ProfessionMenu_Open[client] == menu) g_ProfessionMenu_Open[client] = null;
            if (g_Menu_Open[client] == menu) g_Menu_Open[client] = null;
        }
        delete menu;
    }
    else if (action == MenuAction_Select)
    {
        PlayerProfile profile;
        int profession;
        int reason = RN_ProfessionMenu_Reason(menu, param1, param2, profile, profession);
        if (reason != RN_MENU_ALLOWED) { RN_Menu_Rejected(param1, reason); return 0; }
        PlayerProfile original;
        original = profile;
        if (!RN_Math_Add(profile.professionVersion, 1, profile.professionVersion))
        {
            RN_Menu_Rejected(param1, RN_MENU_VERSION);
            return 0;
        }
        profile.profession = profession;
        if (!RN_Apply_PrepareHealth(original, profile) || !RN_Profile_Validate(profile)
            || !RN_Profile_ValidateClient(param1, profile)) { RN_Menu_Rejected(param1, RN_MENU_BUDGET); return 0; }
        RN_Profile_Save(g_Profile_Index[param1], profile);
        if (profession == RN_PROFESSION_KNIGHT)
        {
            RN_Element_Forget(param1);
            RN_Profile_Recalc(param1);
        }
        if (profession == RN_PROFESSION_SNIPER || profession == RN_PROFESSION_MAGICIAN)
        {
            RN_ProfessionWeaponContext context;
            RN_ProfessionWeapon_Capture(param1, profile, context);
            if (profession == RN_PROFESSION_SNIPER) RN_Element_Forget(param1);
            RN_ProfessionWeapon_Give(param1, context);
            if (!RN_ProfessionWeapon_Matches(param1, context)) return 0;
        }
        RN_ProfessionMenu_Notify(param1, profile);
        RN_Menu_Next(param1);
    }
    return 0;
}

/** 仅在有待选次数的手动加点入口显示短职业菜单，不提前生成BUFF候选。 */
void RN_ProfessionMenu_Show(int client, PlayerProfile profile)
{
    static const char labels[][] = {
        "士兵（每级增加枪械伤害）", "剑客（近战攻速增加、挥出剑气）",
        "元素大师（更高的元素概率）", "狙神（狙击越远伤害越高）",
        "死神（击杀增加伤害与承伤）", "艺术家（榴弹弹跳与分裂）",
        "十字骑士（生命附伤、受难爆发）"
    };
    Menu menu = new Menu(RN_ProfessionMenu_OnChoice);
    menu.Pagination = 7;
    menu.SetTitle("Rogue 职业选择");
    for (int profession = 1; profession < RN_PROFESSION_COUNT; profession++)
    {
        char info[128];
        FormatEx(info, sizeof(info), "p:%d:%d:%d:%d:%d:%d", g_Run_Epoch, g_Run_MapEpoch,
            GetClientSerial(client), g_Profile_Index[client], profile.professionVersion, profession);
        menu.AddItem(info, labels[profession-1]);
    }
    g_ProfessionMenu_Open[client] = menu;
    g_Menu_Open[client] = menu;
    if (!menu.Display(client, 30))
    {
        g_ProfessionMenu_Open[client] = null;
        g_Menu_Open[client] = null;
        delete menu;
        RN_Menu_Rejected(client, RN_MENU_DISPLAY);
    }
}
