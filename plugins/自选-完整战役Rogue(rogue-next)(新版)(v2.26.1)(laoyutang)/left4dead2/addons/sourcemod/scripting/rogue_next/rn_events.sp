#if defined _rn_events_included
 #endinput
#endif
#define _rn_events_included

float g_Events_LastBirth[MAXPLAYERS + 1];
bool g_Events_RoundStarted;
bool g_Events_RoundEnded;
int g_Events_RestartEpoch;
int g_Events_RestartMapEpoch;

/** 完整清档取消尚未提交的原地重开；保留当前地图已开始回合的事实。 */
void RN_Events_CancelRestart()
{
    g_Events_RoundEnded = false;
    g_Events_RestartEpoch = 0;
    g_Events_RestartMapEpoch = 0;
}

/** 每次真实换图重置回合边界，下一章节的首次生成不能当作原地重开。 */
void RN_Events_ResetMap()
{
    RN_Events_CancelRestart();
    g_Events_RoundStarted = false;
}

/** 原地重开只在同一战役/地图代次与禁止结算阶段内提交一次。 */
bool RN_Events_RestartPending()
{
    return g_Events_RestartEpoch != 0 && g_Events_RestartEpoch == g_Run_Epoch &&
        g_Events_RestartMapEpoch == g_Run_MapEpoch && g_Run_Phase == RN_RESTARTING &&
        !g_Run_HasCampaign;
}

/** 原地重开先使旧任务失效并清档，实体重建期间不允许重新绑定旧属性。 */
void RN_Events_PrepareRestart(const char[] source)
{
    if (!g_Main_Initialized || !g_Run_MapReady || !g_Run_HasCampaign ||
        (!RN_Common_ActiveRun() && g_Run_Phase != RN_TRANSITION)) return;
    LogMessage("[rogue-next] ROUND_RESTART_PREPARE source=%s run=%d mapEpoch=%d map=%s level=%d profiles=%d",
        source, g_Run_Epoch, g_Run_MapEpoch, g_Run_Map, g_Run_Level, g_Profile_Records.Length);
    RN_Main_Clear(RN_RESTARTING);
    RN_Clock_MapStart();
    g_Run_MapReady = false;
    g_Events_RestartEpoch = g_Run_Epoch;
    g_Events_RestartMapEpoch = g_Run_MapEpoch;
}

/** 已开始的同图回合再次重建实体即为重开；首次生成及正常下一章保留。 */
public void RN_Events_RoundPreEntity(Event event, const char[] name, bool dontBroadcast)
{
    if (g_Events_RoundStarted) RN_Events_PrepareRestart(name);
}

/** 回合结束只登记边界；兼容缺少pre事件的重开，不抢正常过关或失败换图。 */
public void RN_Events_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_Main_Initialized || !g_Run_MapReady || !g_Run_HasCampaign) return;
    g_Events_RoundStarted = true;
    g_Events_RoundEnded = true;
}

/** 客户端钩子幂等安装，热加载与跨图补绑定共用。 */
void RN_Main_HookClient(int client)
{
    SDKUnhook(client, SDKHook_OnTakeDamage, RN_Combat_OnDamage);
    SDKHook(client, SDKHook_OnTakeDamage, RN_Combat_OnDamage);
    SDKUnhook(client, SDKHook_OnTakeDamagePost, RN_Element_OnDamagePost);
    SDKHook(client, SDKHook_OnTakeDamagePost, RN_Element_OnDamagePost);
    SDKUnhook(client, SDKHook_TraceAttackPost, RN_Element_OnTrace);
    SDKHook(client, SDKHook_TraceAttackPost, RN_Element_OnTrace);
    SDKUnhook(client, SDKHook_OnTakeDamagePost, RN_Explosive_OnDamagePost);
    SDKHook(client, SDKHook_OnTakeDamagePost, RN_Explosive_OnDamagePost);
    RN_Damage_Hook(client);
    RN_Knight_Hook(client);
    SDKUnhook(client, SDKHook_WeaponSwitchPost, RN_Melee_OnSwitch);
    SDKHook(client, SDKHook_WeaponSwitchPost, RN_Melee_OnSwitch);
    SDKUnhook(client, SDKHook_WeaponDropPost, RN_Melee_OnDrop);
    SDKHook(client, SDKHook_WeaponDropPost, RN_Melee_OnDrop);
    SDKUnhook(client, SDKHook_WeaponDropPost, RN_BranchSoldier_OnDrop);
    SDKHook(client, SDKHook_WeaponDropPost, RN_BranchSoldier_OnDrop);
    SDKUnhook(client, SDKHook_WeaponEquipPost, RN_Melee_OnEquip);
    SDKHook(client, SDKHook_WeaponEquipPost, RN_Melee_OnEquip);
}

/** 新生命先恢复/移除旧效果再增加life；出生与档案授权不要求固定先后。 */
void RN_Main_ClientBirth(int client)
{
    if (!RN_Common_Client(client)) return;
    RN_Branch_ResetClient(client);
    RN_Combat_ProtectionClear(client);
    RN_Melee_StopClient(client);
    RN_Charger_Forget(client);
    RN_Element_Forget(client);
    RN_Grenade_Forget(client);
    RN_Scaling_Retire(client);
    if (g_Common_Life[client] == RN_MAX_INT) { SetFailState("客户端生命代次耗尽，请重载插件。"); return; }
    g_Common_Life[client]++;
    RN_Disaster_ClientBirth(client);
    g_Events_LastBirth[client] = GetTickedTime();
    RN_XP_Birth(client);
    if (!IsFakeClient(client) && IsClientAuthorized(client)) RN_Profile_Bind(client);
    RN_Sword_BranchReset(client);
    RN_Profile_Recalc(client);
    RN_Scaling_Birth(client);
    RN_ProfessionWeapon_TryReturn(client);
}

/** 已连接真人出现即可恢复空服时钟，不等待其加载完成或加入生还者。 */
public void OnClientConnected(int client)
{
    RN_ProfessionWeapon_Stop(client);
    if (g_Main_Initialized) RN_Clock_UpdatePause();
}

/** 玩家进入游戏安装钩子；BOT不建立个人档案。 */
public void OnClientPutInServer(int client)
{
    if (!g_Main_Initialized) return;
    RN_Branch_ResetClient(client);
    RN_ElementShot_ResetClient(client);
    RN_Main_HookClient(client);
    RN_Melee_StopClient(client);
    RN_Menu_Close(client);
    RN_Clock_UpdatePause();
}

/** Steam授权成功后恢复档案；若已出生立即应用本人属性。 */
public void OnClientPostAdminCheck(int client)
{
    if (!g_Main_Initialized || IsFakeClient(client)) return;
    RN_Profile_Bind(client);
    RN_Sword_BranchReset(client);
    RN_Menu_JoinTip(client);
    RN_Notify_Pending(client, true);
    RN_Weapons_Refresh();
    RN_Clock_UpdatePause();
    RN_Disaster_NotifyClient(client);
    RN_ProfessionWeapon_TryReturn(client);
}

/** 断线先释放会话效果再解绑；长期档案和缓存选项保留。 */
public void OnClientDisconnect(int client)
{
    if (!g_Main_Initialized) return;
    RN_Branch_ResetClient(client);
    RN_ProfessionWeapon_Stop(client);
    RN_Clock_UpdatePause(client);
    RN_Melee_StopClient(client);
    RN_Charger_Forget(client);
    RN_Menu_Close(client);
    RN_Element_Forget(client);
    RN_Scaling_Forget(client);
    RN_Profile_Disconnect(client);
    g_Events_LastBirth[client] = -1.0;
    RN_Weapons_Refresh();
}

/** player_spawn增加生命轮次；重复通知保留life去重，仍登记移速/血上限恢复。 */
public void RN_Events_Spawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!RN_Common_Client(client)) return;
    int zombieClass = RN_Common_Infected(client) ? GetEntProp(client, Prop_Send, "m_zombieClass") : 0;
    if (g_XP_ClientSerial[client] == GetClientSerial(client) && !g_XP_DeathSeen[client] &&
        g_XP_BirthClass[client] == zombieClass && GetTickedTime() - g_Events_LastBirth[client] < 0.1)
    {
        RN_Profile_SpeedQueue(client);
        RN_Profile_HealthQueue(client);
        return;
    }
    RN_Main_HookClient(client);
    RN_Main_ClientBirth(client);
    RN_Weapons_Refresh();
    RN_Notify_Pending(client, true);
}

/** 同图重开提交零档案；普通首轮和重复通知只重建实体/生命及本轮统计。 */
public void RN_Events_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    if (g_Events_RoundEnded) RN_Events_PrepareRestart(name);
    if (RN_Events_RestartPending())
    {
        char mission[128], first[PLATFORM_MAX_PATH];
        strcopy(mission, sizeof(mission), g_Run_Mission);
        strcopy(first, sizeof(first), g_Run_FirstMap);
        RN_Main_Begin(mission, first, g_Run_Chapter, true);
        LogMessage("[rogue-next] ROUND_RESTART_COMMIT run=%d mapEpoch=%d map=%s level=%d profiles=%d",
            g_Run_Epoch, g_Run_MapEpoch, g_Run_Map, g_Run_Level, g_Profile_Records.Length);
        PrintToChatAll("\x04[Rogue]\x01回合已重新开始，旧加成与成长已清空。");
    }
    g_Events_RoundStarted = true;
    g_Events_RoundEnded = false;
    RN_Melee_Clear();
    RN_Charger_Clear();
    RN_Menu_Clear();
    RN_Element_Clear();
    RN_Scaling_Clear();
    RN_Team_RoundStart();
    for (int client = 1; client <= MaxClients; client++)
        if (RN_Common_Client(client)) RN_Main_ClientBirth(client);
    RN_Weapons_Refresh();
}

/** 玩家、SI及兼容NPC死亡路由；来源模块独立完成两种收益的归因/去重。 */
public void RN_Events_Death(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    RN_Branch_ResetClient(victim);
    int target = victim;
    if (target == 0 && RN_Common_Zombie(event.GetInt("entityid"))) target = event.GetInt("entityid");
    RN_Damage_MarkDeath(target);
    RN_Combat_ProtectionClear(victim);
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    RN_Melee_StopClient(victim);
    RN_Charger_Forget(victim);
    char weapon[64];
    event.GetString("weapon", weapon, sizeof(weapon));
    RN_XP_PlayerDeath(victim, attacker, event.GetInt("attackerentid"), weapon);
    RN_Menu_Close(victim > 0 ? victim : 0);
    RN_Element_Death(target);
    if (victim > 0)
    {
        g_Profile_Healing[victim] = false;
        g_Profile_SpeedSync[victim].serial = 0;
        g_Profile_HealthSync[victim].serial = 0;
    }
}

/** 女巫事件的userid是击杀者，witchid是目标实体索引。 */
public void RN_Events_WitchDeath(Event event, const char[] name, bool dontBroadcast)
{
    RN_Damage_MarkDeath(event.GetInt("witchid"));
    RN_Element_Death(event.GetInt("witchid"));
    RN_XP_WitchDeath(event.GetInt("witchid"), GetClientOfUserId(event.GetInt("userid")));
}

/** 离开起点安全区启动一次；玩家后来回屋不停止时钟。 */
public void RN_Events_LeftSafe(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (RN_Common_Survivor(client)) RN_Clock_Departure();
}

/** 仅识别实际起点checkpoint门；普通门与终点门不启动。 */
public void RN_Events_Door(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!RN_Common_Survivor(client) ||
        GetFeatureStatus(FeatureType_Native, "L4D_GetCheckpointFirst") != FeatureStatus_Available) return;
    int door = event.GetInt("checkpoint");
    if (door > MaxClients && door == L4D_GetCheckpointFirst()) RN_Clock_Departure(false);
}

/** Left4DHooks实际出门通知是事件之外的兼容入口。 */
public void L4D_OnFirstSurvivorLeftSafeArea_Post(int client)
{
    if (g_Main_Initialized && RN_Common_Survivor(client)) RN_Clock_Departure();
}

/** 托管停止真人回血并清理BOT继承的实体属性，不搬运档案。 */
public void RN_Events_PlayerBot(Event event, const char[] name, bool dontBroadcast)
{
    int player = GetClientOfUserId(event.GetInt("player"));
    int bot = GetClientOfUserId(event.GetInt("bot"));
    RN_Branch_ResetClient(player);
    RN_Branch_ResetClient(bot);
    RN_ElementShot_ResetClient(player);
    RN_ElementShot_ResetClient(bot);
    RN_Melee_StopClient(player);
    RN_Melee_StopClient(bot);
    RN_Charger_Forget(player);
    RN_Charger_Forget(bot);
    if (player > 0) RN_Menu_Close(player);
    RN_Profile_HandoffToBot(player, bot);
    RN_Disaster_ClientBirth(player);
    RN_Disaster_ClientBirth(bot);
    RN_Weapons_Refresh();
}

/** 接管应用真人自己的档案，保留游戏生命状态与已有复活消耗。 */
public void RN_Events_BotPlayer(Event event, const char[] name, bool dontBroadcast)
{
    RN_ElementShot_ResetClient(GetClientOfUserId(event.GetInt("bot")));
    RN_ElementShot_ResetClient(GetClientOfUserId(event.GetInt("player")));
    RN_Melee_StopClient(GetClientOfUserId(event.GetInt("bot")));
    RN_Melee_StopClient(GetClientOfUserId(event.GetInt("player")));
    RN_Charger_Forget(GetClientOfUserId(event.GetInt("bot")));
    RN_Charger_Forget(GetClientOfUserId(event.GetInt("player")));
    RN_Profile_Takeover(GetClientOfUserId(event.GetInt("bot")), GetClientOfUserId(event.GetInt("player")));
    RN_Branch_ResetClient(GetClientOfUserId(event.GetInt("bot")));
    RN_Branch_ResetClient(GetClientOfUserId(event.GetInt("player")));
    RN_ProfessionWeapon_TryReturn(GetClientOfUserId(event.GetInt("player")));
    RN_Disaster_ClientBirth(GetClientOfUserId(event.GetInt("bot")));
    RN_Disaster_ClientBirth(GetClientOfUserId(event.GetInt("player")));
    RN_Disaster_NotifyClient(GetClientOfUserId(event.GetInt("player")));
    RN_Weapons_Refresh();
}

/** 队伍变更即时撤销个人属性/菜单并刷新在线团队武器贡献。 */
public void RN_Events_Team(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!RN_Common_Client(client)) return;
    RN_Element_Forget(client);
    RN_Branch_ResetClient(client);
    RN_Melee_StopClient(client);
    RN_Menu_Close(client);
    RN_Charger_Forget(client);
    if (GetClientTeam(client) != 2) RN_Profile_StopClient(client, true);
    else
    {
        if (!IsFakeClient(client) && IsClientAuthorized(client)) RN_Profile_Bind(client);
        RN_Profile_Recalc(client);
        RN_Notify_Pending(client, true);
        RN_Disaster_NotifyClient(client);
    }
    RN_Weapons_Refresh();
}

/** 起身/脱挂边后应用延迟属性；普通重算仍不赠送历史血量。 */
public void RN_Events_Standing(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("subject"));
    if (!RN_Common_Client(client)) client = GetClientOfUserId(event.GetInt("userid"));
    if (RN_Common_Survivor(client)) RN_Profile_Recalc(client);
}

/** 确认正常过关标记，后续地图才能延续同一战役。 */
public void RN_Events_Transition(Event event, const char[] name, bool dontBroadcast) { RN_Main_Transition(); }

/** 失败只建立一个受代次保护的首图重启任务。 */
public void RN_Events_Failed(Event event, const char[] name, bool dontBroadcast) { RN_Main_Failed(); }

/** 多个终局事件共用幂等收尾。 */
public void RN_Events_Finished(Event event, const char[] name, bool dontBroadcast) { RN_Main_Finished(); }

/** NPC在DispatchSpawn之后捕获基线；创建时属性尚未就绪。 */
public void RN_Events_NPCSpawn(int entity)
{
    if (!RN_Common_Zombie(entity)) return;
    RN_FX_NPCForget(entity);
    SDKHook(entity, SDKHook_OnTakeDamage, RN_Combat_OnDamage);
    SDKHook(entity, SDKHook_OnTakeDamagePost, RN_Element_OnDamagePost);
    SDKHook(entity, SDKHook_TraceAttackPost, RN_Element_OnTrace);
    SDKHook(entity, SDKHook_OnTakeDamagePost, RN_Explosive_OnDamagePost);
    RN_Damage_Hook(entity);
    RN_Knight_Hook(entity);
    RN_XP_WitchBirth(entity);
    RN_Scaling_Birth(entity);
}

/** 普感/女巫保留原钩子；四喷按独立后端延迟登记，动态索引无2048上限。 */
public void OnEntityCreated(int entity, const char[] classname)
{
    if (g_Main_Initialized) RN_Shotgun_Created(entity, classname);
    if (g_Main_Initialized && (StrEqual(classname, "infected") || StrEqual(classname, "witch")))
        SDKHook(entity, SDKHook_SpawnPost, RN_Events_NPCSpawn);
}

/** 清理销毁对象登记；女巫出生缓存保留供可能滞后的死亡事件查询。 */
public void OnEntityDestroyed(int entity)
{
    if (!g_Main_Initialized) return;
    RN_Shotgun_Destroyed(entity);
    RN_Grenade_Destroyed(entity);
    RN_Damage_Destroyed(entity);
    RN_Melee_ForgetEntity(entity, false);
    RN_Element_Forget(entity, false);
    RN_FX_NPCForget(entity);
    RN_Scaling_Forget(entity);
}

/** 普感特殊致死可能保留正实血；补记生命结束，恢复自身冻结并取消元素。 */
public void RN_Events_InfectedDeath(Event event, const char[] name, bool dontBroadcast)
{
    RN_Damage_MarkDeath(event.GetInt("infected_id"));
    RN_Element_Death(event.GetInt("infected_id"));
}

/** 登记实际需要的游戏事件，允许不同游戏构建缺少非核心兼容事件。 */
void RN_Events_Init()
{
    HookEvent("weapon_fire", RN_ElementShot_OnFire, EventHookMode_Pre);
    HookEvent("weapon_fire", RN_BranchSoldier_OnFire, EventHookMode_Pre);
    HookEvent("weapon_reload", RN_BranchSoldier_OnReload, EventHookMode_Post);
    HookEvent("weapon_fire", RN_Knight_OnFire, EventHookMode_Pre);
    HookEvent("player_incapacitated", RN_Knight_OnDisabled);
    HookEvent("player_ledge_grab", RN_Knight_OnDisabled);
    HookEvent("weapon_fire", RN_Sword_OnFire, EventHookMode_Pre);
    HookEvent("player_spawn", RN_Events_Spawn);
    HookEventEx("round_start_pre_entity", RN_Events_RoundPreEntity);
    HookEvent("round_end", RN_Events_RoundEnd);
    HookEvent("round_start", RN_Events_RoundStart);
    HookEvent("player_death", RN_Events_Death);
    HookEvent("witch_killed", RN_Events_WitchDeath);
    HookEvent("infected_death", RN_Events_InfectedDeath);
    HookEvent("player_left_start_area", RN_Events_LeftSafe);
    HookEvent("door_open", RN_Events_Door);
    HookEvent("player_bot_replace", RN_Events_PlayerBot);
    HookEvent("bot_player_replace", RN_Events_BotPlayer);
    HookEvent("player_team", RN_Events_Team);
    HookEvent("charger_charge_start", RN_Charger_Event);
    HookEvent("charger_charge_end", RN_Charger_Event);
    HookEvent("charger_carry_end", RN_Charger_Event);
    HookEvent("charger_pummel_end", RN_Charger_Event);
    HookEvent("revive_success", RN_Events_Standing);
    HookEventEx("player_ledge_release", RN_Events_Standing);
    HookEvent("map_transition", RN_Events_Transition);
    HookEvent("mission_lost", RN_Events_Failed);
    HookEvent("finale_win", RN_Events_Finished);
    HookEvent("finale_vehicle_leaving", RN_Events_Finished);
}
