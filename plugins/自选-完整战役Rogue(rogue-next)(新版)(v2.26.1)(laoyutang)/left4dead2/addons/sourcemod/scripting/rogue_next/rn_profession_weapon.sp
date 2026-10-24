#if defined _rn_profession_weapon_included
 #endinput
#endif
#define _rn_profession_weapon_included

/** 首次选择与重连/复活补发共用完整身份，SDK回调后须核对同一玩家和战役。 */
enum struct RN_ProfessionWeaponContext
{
    int serial;
    int life;
    int epoch;
    int mapEpoch;
    int profileIndex;
    int professionVersion;
    int profession;
    bool resupply;
}

enum struct RN_ProfessionWeaponReturn
{
    RN_ProfessionWeaponContext origin;
    RN_ProfessionWeaponContext request;
    bool afterDeath;
    int token;
}

ArrayList g_ProfessionWeapon_Sessions;
RN_ProfessionWeaponReturn g_ProfessionWeapon_Return[MAXPLAYERS + 1];
int g_ProfessionWeapon_Token;

/** 每档案只记最近连接serial，正常过图保留它以区分真正重连。 */
void RN_ProfessionWeapon_Init()
{
    g_ProfessionWeapon_Sessions = new ArrayList();
    RN_ProfessionWeapon_Clear();
}

/** 断线、换图或消费资格后使该玩家的所有旧帧立即失效。 */
void RN_ProfessionWeapon_Stop(int client)
{
    if (client < 1 || client > MAXPLAYERS) return;
    g_ProfessionWeapon_Return[client].origin.serial = 0;
    g_ProfessionWeapon_Return[client].token = 0;
}

/** 正常换图取消出生任务但保留连接记录；只有完整清档才归零最近连接。 */
void RN_ProfessionWeapon_Clear(bool sessions = false)
{
    for (int client = 1; client <= MAXPLAYERS; client++) RN_ProfessionWeapon_Stop(client);
    if (sessions && g_ProfessionWeapon_Sessions != null) g_ProfessionWeapon_Sessions.Clear();
}

/** 稳定档案的新serial才登记重连，首次加入和同连接跨图不领取补发。 */
void RN_ProfessionWeapon_Bound(int client, int index, PlayerProfile profile)
{
    if (g_ProfessionWeapon_Sessions == null || index < 0) return;
    while (g_ProfessionWeapon_Sessions.Length <= index) g_ProfessionWeapon_Sessions.Push(0);
    int previous = g_ProfessionWeapon_Sessions.Get(index), serial = GetClientSerial(client);
    g_ProfessionWeapon_Sessions.Set(index, serial);
    if (previous != 0 && previous != serial && profile.stableIdentity &&
        (profile.profession == RN_PROFESSION_SNIPER || profile.profession == RN_PROFESSION_MAGICIAN))
    {
        RN_ProfessionWeapon_Capture(client, profile, g_ProfessionWeapon_Return[client].origin);
        g_ProfessionWeapon_Return[client].afterDeath = false;
        g_ProfessionWeapon_Return[client].token = 0;
        RN_ProfessionWeapon_TryReturn(client);
    }
}

/** 正式死亡已通过生命去重后登记，必须等下一条生命才能申请补发。 */
void RN_ProfessionWeapon_Death(int client)
{
    if (!RN_Common_ActiveRun() || !RN_Common_Survivor(client) || IsFakeClient(client)) return;
    PlayerProfile profile;
    if (!RN_Profile_Get(g_Profile_Index[client], profile) ||
        (profile.profession != RN_PROFESSION_SNIPER && profile.profession != RN_PROFESSION_MAGICIAN)) return;
    RN_ProfessionWeapon_Capture(client, profile, g_ProfessionWeapon_Return[client].origin);
    g_ProfessionWeapon_Return[client].afterDeath = true;
    g_ProfessionWeapon_Return[client].token = 0;
}

/** 出生和授权先后均可接入；每个当前生命只排一个帧，不扫描或定时追补。 */
void RN_ProfessionWeapon_TryReturn(int client)
{
    if (client < 1 || client > MaxClients || g_ProfessionWeapon_Return[client].origin.serial == 0) return;
    RN_ProfessionWeaponReturn pending;
    pending = g_ProfessionWeapon_Return[client];
    PlayerProfile profile;
    if (!RN_Common_Client(client) || IsFakeClient(client) || GetClientSerial(client) != pending.origin.serial ||
        g_Run_Epoch != pending.origin.epoch || g_Run_MapEpoch != pending.origin.mapEpoch ||
        g_Profile_Index[client] != pending.origin.profileIndex || !RN_Profile_Get(g_Profile_Index[client], profile) ||
        profile.profession != pending.origin.profession || profile.professionVersion != pending.origin.professionVersion)
    {
        RN_ProfessionWeapon_Stop(client);
        return;
    }
    if (pending.afterDeath && g_Common_Life[client] <= pending.origin.life) return;
    if (!RN_Common_ActiveRun() || !g_Run_MapReady || !RN_Common_Survivor(client) || !IsPlayerAlive(client)) return;
    RN_ProfessionWeaponContext context;
    RN_ProfessionWeapon_Capture(client, profile, context);
    context.resupply = true;
    if (!RN_ProfessionWeapon_Enabled(context) || !RN_ProfessionWeapon_Matches(client, context))
    {
        RN_ProfessionWeapon_Stop(client);
        return;
    }
    if (pending.token != 0 && pending.request.life == context.life) return;
    if (g_ProfessionWeapon_Token == RN_MAX_INT)
    {
        RN_ProfessionWeapon_Stop(client);
        LogError("[Rogue] 职业补发编号耗尽，取消本次补发。");
        return;
    }
    g_ProfessionWeapon_Return[client].request = context;
    g_ProfessionWeapon_Return[client].token = ++g_ProfessionWeapon_Token;
    RequestFrame(RN_ProfessionWeapon_ReturnFrame, g_ProfessionWeapon_Token);
}

/** 下一帧先消费资格再调用赠枪事务，重复生成及SDK重入不能多领或补弹。 */
public void RN_ProfessionWeapon_ReturnFrame(any token)
{
    if (token == 0) return;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (g_ProfessionWeapon_Return[client].token != token) continue;
        RN_ProfessionWeaponContext context;
        context = g_ProfessionWeapon_Return[client].request;
        RN_ProfessionWeapon_Stop(client);
        RN_ProfessionWeapon_Give(client, context);
        return;
    }
}

/** 补发保留已有四类狙击枪或榴弹枪，包含零弹药武器，不借此补充弹药。 */
bool RN_ProfessionWeapon_Suitable(int client, RN_ProfessionWeaponContext context)
{
    int weapon = GetPlayerWeaponSlot(client, 0);
    if (weapon <= MaxClients || !IsValidEntity(weapon) ||
        GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity") != client) return false;
    if (context.profession == RN_PROFESSION_SNIPER)
    {
        int index = RN_Weapons_Index(weapon);
        return index >= 12 && index <= 15;
    }
    char classname[64];
    GetEntityClassname(weapon, classname, sizeof(classname));
    return context.profession == RN_PROFESSION_MAGICIAN && StrEqual(classname, "weapon_grenade_launcher");
}

/** 在清理旧元素或调用装备SDK前保存本次职业选择身份。 */
void RN_ProfessionWeapon_Capture(int client, PlayerProfile profile, RN_ProfessionWeaponContext context)
{
    context.serial = GetClientSerial(client);
    context.life = g_Common_Life[client];
    context.epoch = g_Run_Epoch;
    context.mapEpoch = g_Run_MapEpoch;
    context.profileIndex = g_Profile_Index[client];
    context.professionVersion = profile.professionVersion;
    context.profession = profile.profession;
    context.resupply = false;
}

/** 不因重连、出生、重开、换图或职业改变把赠枪和通知给另一会话。 */
bool RN_ProfessionWeapon_Matches(int client, RN_ProfessionWeaponContext context)
{
    if (!RN_Menu_Eligible(client, false) || RN_Config_Int(RN_CVAR_PROFESSION_ENABLE) == 0 ||
        GetClientSerial(client) != context.serial || g_Common_Life[client] != context.life ||
        g_Run_Epoch != context.epoch || g_Run_MapEpoch != context.mapEpoch ||
        g_Profile_Index[client] != context.profileIndex) return false;
    PlayerProfile current;
    return RN_Profile_Get(context.profileIndex, current) && current.profession == context.profession &&
        current.professionVersion == context.professionVersion;
}

/** 首次与补发共用对应开关，热开只影响之后的新触发。 */
bool RN_ProfessionWeapon_Enabled(RN_ProfessionWeaponContext context)
{
    if (context.profession == RN_PROFESSION_SNIPER) return RN_Config_Int(RN_CVAR_SNIPER_START_WEAPON) != 0;
    return context.profession == RN_PROFESSION_MAGICIAN && RN_Config_Int(RN_CVAR_MAGICIAN_START_WEAPON) != 0;
}

/** 赠枪提示与实体种类共用职业身份，保持原狙神提示。 */
void RN_ProfessionWeapon_Label(RN_ProfessionWeaponContext context, char[] label, int maxlength)
{
    strcopy(label, maxlength, context.profession == RN_PROFESSION_MAGICIAN ? "榴弹发射器" : "十五连（猎枪）");
}

/** 只清本次未被领取的新枪，失败时尽量把仍无人持有的原枪交还原会话。 */
void RN_ProfessionWeapon_Cancel(int client, RN_ProfessionWeaponContext context, int giftRef, int oldRef)
{
    int gift = EntRefToEntIndex(giftRef);
    if (gift > MaxClients && GetEntPropEnt(gift, Prop_Send, "m_hOwnerEntity") <= 0) RemoveEntity(gift);
    int old = EntRefToEntIndex(oldRef);
    if (old > MaxClients && RN_ProfessionWeapon_Matches(client, context) &&
        GetPlayerWeaponSlot(client, 0) == -1 && GetEntPropEnt(old, Prop_Send, "m_hOwnerEntity") <= 0)
        EquipPlayerWeapon(client, old);
}

/** 有效失败向本人说明对应领取原因，日志保留失败阶段，不开放重复领取。 */
void RN_ProfessionWeapon_Failed(int client, RN_ProfessionWeaponContext context, const char[] stage)
{
    char profession[64], label[64];
    RN_Profession_Name(context.profession, profession, sizeof(profession));
    RN_ProfessionWeapon_Label(context, label, sizeof(label));
    LogError("[Rogue] %s赠枪失败：%s，serial=%d run=%d map=%d。", profession, stage, context.serial, context.epoch, context.mapEpoch);
    if (RN_ProfessionWeapon_Matches(client, context))
    {
        if (context.resupply) PrintToChat(client, "\x04[Rogue]\x01%s补发失败，请联系管理员。", label);
        else PrintToChat(client, "\x04[Rogue]\x01%s已选择，但%s发放失败，请联系管理员。", profession, label);
    }
}

/** 首次或有效补发先生成主武器再掉落原枪；补发保留已有合适武器。 */
void RN_ProfessionWeapon_Give(int client, RN_ProfessionWeaponContext context)
{
    if (!RN_ProfessionWeapon_Enabled(context) || !RN_ProfessionWeapon_Matches(client, context)) return;
    if (context.resupply && RN_ProfessionWeapon_Suitable(client, context)) return;
    bool magician = context.profession == RN_PROFESSION_MAGICIAN;
    int gift = CreateEntityByName(magician ? "weapon_grenade_launcher" : "weapon_hunting_rifle");
    if (gift <= MaxClients) { RN_ProfessionWeapon_Failed(client, context, "create"); return; }
    int giftRef = EntIndexToEntRef(gift);
    bool spawned = DispatchSpawn(gift);
    gift = EntRefToEntIndex(giftRef);
    if (!spawned || gift <= MaxClients)
    {
        RN_ProfessionWeapon_Cancel(client, context, giftRef, INVALID_ENT_REFERENCE);
        RN_ProfessionWeapon_Failed(client, context, "spawn");
        return;
    }
    if (!RN_ProfessionWeapon_Matches(client, context) || !RN_ProfessionWeapon_Enabled(context) ||
        GetEntPropEnt(gift, Prop_Send, "m_hOwnerEntity") > 0 ||
        (context.resupply && RN_ProfessionWeapon_Suitable(client, context)))
    {
        RN_ProfessionWeapon_Cancel(client, context, giftRef, INVALID_ENT_REFERENCE);
        return;
    }
    int old = GetPlayerWeaponSlot(client, 0), oldRef = INVALID_ENT_REFERENCE;
    if (old > MaxClients && IsValidEntity(old))
    {
        oldRef = EntIndexToEntRef(old);
        SDKHooks_DropWeapon(client, old);
    }
    gift = EntRefToEntIndex(giftRef);
    if (!RN_ProfessionWeapon_Matches(client, context) || !RN_ProfessionWeapon_Enabled(context) ||
        gift <= MaxClients || GetEntPropEnt(gift, Prop_Send, "m_hOwnerEntity") > 0)
    {
        RN_ProfessionWeapon_Cancel(client, context, giftRef, oldRef);
        return;
    }
    if (GetPlayerWeaponSlot(client, 0) != -1)
    {
        RN_ProfessionWeapon_Cancel(client, context, giftRef, oldRef);
        RN_ProfessionWeapon_Failed(client, context, "drop");
        return;
    }
    EquipPlayerWeapon(client, gift);
    if (!RN_ProfessionWeapon_Matches(client, context))
    {
        RN_ProfessionWeapon_Cancel(client, context, giftRef, oldRef);
        return;
    }
    gift = EntRefToEntIndex(giftRef);
    if (gift <= MaxClients || GetPlayerWeaponSlot(client, 0) != gift || GetEntPropEnt(gift, Prop_Send, "m_hOwnerEntity") != client)
    {
        RN_ProfessionWeapon_Cancel(client, context, giftRef, oldRef);
        RN_ProfessionWeapon_Failed(client, context, "equip");
        return;
    }
    // 新枪弹夹沿用游戏脚本；备用弹药由引擎按对应武器的当前上限钳制。
    int ammoType = GetEntProp(gift, Prop_Send, "m_iPrimaryAmmoType");
    ConVar maximum = FindConVar(magician ? "ammo_grenadelauncher_max" : "ammo_huntingrifle_max");
    int reserve = maximum != null ? maximum.IntValue : (magician ? 30 : 150);
    if (ammoType >= 0 && reserve > 0) GivePlayerAmmo(client, reserve, ammoType, true);
    gift = EntRefToEntIndex(giftRef);
    if (gift > MaxClients && RN_ProfessionWeapon_Matches(client, context) && GetPlayerWeaponSlot(client, 0) == gift &&
        GetEntPropEnt(gift, Prop_Send, "m_hOwnerEntity") == client)
    {
        char label[64];
        RN_ProfessionWeapon_Label(context, label, sizeof(label));
        if (context.resupply && oldRef == INVALID_ENT_REFERENCE) PrintToChat(client, "\x04[Rogue]\x01已补发%s。", label);
        else if (context.resupply) PrintToChat(client, "\x04[Rogue]\x01已补发%s，原主武器掉落在地上。", label);
        else if (oldRef == INVALID_ENT_REFERENCE) PrintToChat(client, "\x04[Rogue]\x01已获得%s。", label);
        else PrintToChat(client, "\x04[Rogue]\x01已获得%s，原主武器掉落在地上。", label);
    }
}
