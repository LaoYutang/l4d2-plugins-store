#if defined _rn_events_included
 #endinput
#endif
#define _rn_events_included

float g_Events_LastBirth[MAXPLAYERS + 1];

/** 客户端钩子幂等安装，热加载与跨图补绑定共用。 */
void RN_Main_HookClient(int client)
{
    SDKUnhook(client, SDKHook_OnTakeDamage, RN_Combat_OnDamage);
    SDKHook(client, SDKHook_OnTakeDamage, RN_Combat_OnDamage);
}

/** 新生命先恢复/移除旧效果再增加life；出生与档案授权不要求固定先后。 */
void RN_Main_ClientBirth(int client)
{
    if (!RN_Common_Client(client)) return;
    RN_FX_Forget(client);
    RN_Scaling_Retire(client);
    if (g_Common_Life[client] == RN_MAX_INT) { SetFailState("客户端生命代次耗尽，请重载插件。"); return; }
    g_Common_Life[client]++;
    g_Events_LastBirth[client] = GetTickedTime();
    RN_XP_Birth(client);
    if (!IsFakeClient(client) && IsClientAuthorized(client)) RN_Profile_Bind(client);
    RN_Profile_Recalc(client);
    RN_Scaling_Birth(client);
}

/** 已连接真人出现即可恢复空服时钟，不等待其加载完成或加入生还者。 */
public void OnClientConnected(int client)
{
    if (g_Main_Initialized) RN_Clock_UpdatePause();
}

/** 玩家进入游戏安装钩子；BOT不建立个人档案。 */
public void OnClientPutInServer(int client)
{
    if (!g_Main_Initialized) return;
    RN_Main_HookClient(client);
    RN_Menu_Disconnect(client);
    RN_Clock_UpdatePause();
}

/** Steam授权成功后恢复档案；若已出生立即应用本人属性。 */
public void OnClientPostAdminCheck(int client)
{
    if (!g_Main_Initialized || IsFakeClient(client)) return;
    RN_Profile_Bind(client);
    RN_Menu_JoinTip(client);
    RN_Notify_Pending(client, true);
    RN_Weapons_Refresh();
    RN_Clock_UpdatePause();
}

/** 断线先释放会话效果再解绑；长期档案和缓存选项保留。 */
public void OnClientDisconnect(int client)
{
    if (!g_Main_Initialized) return;
    RN_Clock_UpdatePause(client);
    RN_Menu_Disconnect(client);
    RN_FX_Forget(client);
    RN_Scaling_Forget(client);
    RN_Profile_Disconnect(client);
    g_Events_LastBirth[client] = -1.0;
    RN_Weapons_Refresh();
}

/** player_spawn增加生命轮次；同tick重复通知不得复乘出生属性。 */
public void RN_Events_Spawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!RN_Common_Client(client)) return;
    int zombieClass = RN_Common_Infected(client) ? GetEntProp(client, Prop_Send, "m_zombieClass") : 0;
    if (g_XP_ClientSerial[client] == GetClientSerial(client) && !g_XP_DeathSeen[client] &&
        g_XP_BirthClass[client] == zombieClass && GetTickedTime() - g_Events_LastBirth[client] < 0.1) return;
    RN_Main_HookClient(client);
    RN_Main_ClientBirth(client);
    RN_Weapons_Refresh();
    RN_Notify_Pending(client, true);
}

/** 回合开始只清实体/生命与本轮统计；成长和预算保持。 */
public void RN_Events_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    RN_Menu_Clear();
    RN_FX_Clear();
    RN_Scaling_Clear();
    RN_Team_RoundStart();
    for (int client = 1; client <= MaxClients; client++)
        if (RN_Common_Client(client)) RN_Main_ClientBirth(client);
    RN_Weapons_Refresh();
}

/** 普通玩家与SI死亡路由；来源模块独立完成两种收益的归因/去重。 */
public void RN_Events_Death(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    RN_XP_PlayerDeath(victim, attacker, event.GetInt("attackerentid"));
    RN_Menu_Close(victim > 0 ? victim : 0);
    RN_FX_Forget(victim);
    if (victim > 0) g_Profile_Healing[victim] = false;
}

/** 女巫事件的userid是击杀者，witchid是目标实体索引。 */
public void RN_Events_WitchDeath(Event event, const char[] name, bool dontBroadcast)
{
    RN_XP_WitchDeath(event.GetInt("witchid"), GetClientOfUserId(event.GetInt("userid")));
}

/** SI命中后效果从事件取userid；不重复结算伤害数学。 */
public void RN_Events_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    RN_Combat_Hit(GetClientOfUserId(event.GetInt("userid")), GetClientOfUserId(event.GetInt("attacker")));
}

/** NPC命中后效果从entityid取实体引用。 */
public void RN_Events_InfectedHurt(Event event, const char[] name, bool dontBroadcast)
{
    RN_Combat_Hit(event.GetInt("entityid"), GetClientOfUserId(event.GetInt("attacker")));
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
    if (door > MaxClients && door == L4D_GetCheckpointFirst()) RN_Clock_Departure();
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
    if (player > 0) RN_Menu_Disconnect(player);
    RN_Profile_HandoffToBot(player, bot);
    RN_Weapons_Refresh();
}

/** 接管应用真人自己的档案，保留游戏生命状态与已有复活消耗。 */
public void RN_Events_BotPlayer(Event event, const char[] name, bool dontBroadcast)
{
    RN_Profile_Takeover(GetClientOfUserId(event.GetInt("bot")), GetClientOfUserId(event.GetInt("player")));
    RN_Weapons_Refresh();
}

/** 队伍变更即时撤销个人属性/菜单并刷新在线团队武器贡献。 */
public void RN_Events_Team(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!RN_Common_Client(client)) return;
    RN_Menu_Disconnect(client);
    if (GetClientTeam(client) != 2) RN_Profile_StopClient(client, true);
    else
    {
        if (!IsFakeClient(client) && IsClientAuthorized(client)) RN_Profile_Bind(client);
        RN_Profile_Recalc(client);
        RN_Notify_Pending(client, true);
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
    SDKHook(entity, SDKHook_OnTakeDamage, RN_Combat_OnDamage);
    RN_XP_WitchBirth(entity);
    RN_Scaling_Birth(entity);
}

/** 仅给普通感染者与女巫安装实体钩子，动态索引没有2048上限。 */
public void OnEntityCreated(int entity, const char[] classname)
{
    if (g_Main_Initialized && (StrEqual(classname, "infected") || StrEqual(classname, "witch")))
        SDKHook(entity, SDKHook_SpawnPost, RN_Events_NPCSpawn);
}

/** 清理销毁对象登记；女巫出生缓存保留供可能滞后的死亡事件查询。 */
public void OnEntityDestroyed(int entity)
{
    if (!g_Main_Initialized) return;
    RN_FX_Forget(entity, false);
    RN_Scaling_Forget(entity);
}

/** 登记实际需要的游戏事件，允许不同游戏构建缺少非核心兼容事件。 */
void RN_Events_Init()
{
    HookEvent("player_spawn", RN_Events_Spawn);
    HookEvent("round_start", RN_Events_RoundStart);
    HookEvent("player_death", RN_Events_Death);
    HookEvent("witch_killed", RN_Events_WitchDeath);
    HookEvent("player_hurt", RN_Events_PlayerHurt);
    HookEvent("infected_hurt", RN_Events_InfectedHurt);
    HookEvent("player_left_start_area", RN_Events_LeftSafe);
    HookEvent("door_open", RN_Events_Door);
    HookEvent("player_bot_replace", RN_Events_PlayerBot);
    HookEvent("bot_player_replace", RN_Events_BotPlayer);
    HookEvent("player_team", RN_Events_Team);
    HookEvent("revive_success", RN_Events_Standing);
    HookEventEx("player_ledge_release", RN_Events_Standing);
    HookEvent("map_transition", RN_Events_Transition);
    HookEvent("mission_lost", RN_Events_Failed);
    HookEvent("finale_win", RN_Events_Finished);
    HookEvent("finale_vehicle_leaving", RN_Events_Finished);
}

