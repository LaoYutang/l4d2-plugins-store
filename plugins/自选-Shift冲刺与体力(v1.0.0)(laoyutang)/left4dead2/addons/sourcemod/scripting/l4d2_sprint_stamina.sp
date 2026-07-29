#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "v1.0.0"
#define TEAM_SURVIVOR  2
#define STAMINA_TICK   0.10
#define SPEED_EPSILON  0.0005
#define MOVE_EPSILON   0.01

enum SprintState
{
  SprintState_Ready = 0,
  SprintState_Sprinting,
  SprintState_Exhausted
};

public Plugin myinfo =
{
  name        = "L4D2 Sprint Stamina",
  author      = "laoyutang",
  description = "将 IN_SPEED 接管为可配置的冲刺键，并为每名玩家提供独立体力。",
  version     = PLUGIN_VERSION,
  url         = ""
};

ConVar      g_cvEnable;
ConVar      g_cvMultiplier;
ConVar      g_cvStaminaMax;
ConVar      g_cvStaminaDrain;
ConVar      g_cvStaminaRecover;
ConVar      g_cvRecoverDelay;
ConVar      g_cvRestartRatio;
ConVar      g_cvNoticeCooldown;
ConVar      g_cvChatNotify;

bool        g_bEnabled;
bool        g_bChatNotify;
float       g_fMultiplier;
float       g_fStaminaMax;
float       g_fStaminaDrain;
float       g_fStaminaRecover;
float       g_fRecoverDelay;
float       g_fRestartRatio;
float       g_fNoticeCooldown;

SprintState g_eState[MAXPLAYERS + 1];
float       g_fStamina[MAXPLAYERS + 1];
float       g_fRecoverAt[MAXPLAYERS + 1];
float       g_fLastUpdate[MAXPLAYERS + 1];
float       g_fLastStartNotice[MAXPLAYERS + 1];
bool        g_bShiftHeld[MAXPLAYERS + 1];
bool        g_bSpentStamina[MAXPLAYERS + 1];
bool        g_bNeedsSpawnReset[MAXPLAYERS + 1];

bool        g_bOwnsSpeed[MAXPLAYERS + 1];
float       g_fBaseSpeed[MAXPLAYERS + 1];
float       g_fAppliedSpeed[MAXPLAYERS + 1];

Handle      g_hStaminaTimer;

public void OnPluginStart()
{
  if (GetEngineVersion() != Engine_Left4Dead2)
  {
    SetFailState("本插件仅支持 Left 4 Dead 2。");
  }

  g_cvEnable         = CreateConVar("l4d2_sprint_enable", "1", "启用或禁用 Shift 冲刺与体力系统。", FCVAR_NOTIFY, true, 0.0, true, 1.0);
  g_cvMultiplier     = CreateConVar("l4d2_sprint_multiplier", "2.0", "冲刺时应用于玩家当前移动倍率的额外倍率。", FCVAR_NOTIFY, true, 1.0, true, 10.0);
  g_cvStaminaMax     = CreateConVar("l4d2_sprint_stamina_max", "100.0", "每名玩家的体力上限。", FCVAR_NOTIFY, true, 1.0);
  g_cvStaminaDrain   = CreateConVar("l4d2_sprint_stamina_drain", "20.0", "冲刺时每秒消耗的体力。", FCVAR_NOTIFY, true, 0.0);
  g_cvStaminaRecover = CreateConVar("l4d2_sprint_stamina_recover", "20.0", "超过恢复延迟后每秒恢复的体力。", FCVAR_NOTIFY, true, 0.0);
  g_cvRecoverDelay   = CreateConVar("l4d2_sprint_recover_delay", "1.0", "停止冲刺后开始恢复体力前的等待秒数。", FCVAR_NOTIFY, true, 0.0);
  g_cvRestartRatio   = CreateConVar("l4d2_sprint_restart_ratio", "0.20", "脱离体力耗尽状态所需达到的体力上限比例。", FCVAR_NOTIFY, true, 0.0, true, 1.0);
  g_cvNoticeCooldown = CreateConVar("l4d2_sprint_notice_cooldown", "1.0", "每名玩家两次开始冲刺聊天提示之间的最小间隔秒数。", FCVAR_NOTIFY, true, 0.0);
  g_cvChatNotify     = CreateConVar("l4d2_sprint_chat_notify", "1", "是否向玩家私聊显示开始冲刺、体力耗尽和体力回满提示。", FCVAR_NOTIFY, true, 0.0, true, 1.0);

  g_cvEnable.AddChangeHook(ConVarChanged);
  g_cvMultiplier.AddChangeHook(ConVarChanged);
  g_cvStaminaMax.AddChangeHook(ConVarChanged);
  g_cvStaminaDrain.AddChangeHook(ConVarChanged);
  g_cvStaminaRecover.AddChangeHook(ConVarChanged);
  g_cvRecoverDelay.AddChangeHook(ConVarChanged);
  g_cvRestartRatio.AddChangeHook(ConVarChanged);
  g_cvNoticeCooldown.AddChangeHook(ConVarChanged);
  g_cvChatNotify.AddChangeHook(ConVarChanged);

  HookEvent("round_start", Event_RoundStart);
  HookEvent("round_end", Event_RoundEnd);
  HookEvent("player_spawn", Event_PlayerSpawn);
  HookEvent("player_death", Event_PlayerDeath);
  HookEvent("player_incapacitated", Event_PlayerRestricted);
  HookEvent("player_ledge_grab", Event_PlayerRestricted);
  HookEvent("player_bot_replace", Event_PlayerBotReplace);
  HookEvent("bot_player_replace", Event_BotPlayerReplace);

  RefreshConVars();
  AutoExecConfig(true, "l4d2_sprint_stamina");

  float now = GetGameTime();
  for (int client = 1; client <= MaxClients; client++)
  {
    ResetClientState(client, now, false);
  }

  g_hStaminaTimer = CreateTimer(STAMINA_TICK, Timer_Stamina, _, TIMER_REPEAT);
}

public void OnPluginEnd()
{
  RestoreAllOwnedSpeeds();

  if (g_hStaminaTimer != null)
  {
    delete g_hStaminaTimer;
    g_hStaminaTimer = null;
  }
}

public void OnMapStart()
{
  RestoreAllOwnedSpeeds();

  float now = GetGameTime();
  for (int client = 1; client <= MaxClients; client++)
  {
    ResetClientState(client, now, false);
  }
}

public void OnMapEnd()
{
  float now = GetGameTime();

  for (int client = 1; client <= MaxClients; client++)
  {
    RestoreOwnedSpeed(client);

    if (g_eState[client] == SprintState_Sprinting)
    {
      g_eState[client]     = SprintState_Ready;
      g_fRecoverAt[client] = now + g_fRecoverDelay;
    }

    g_bShiftHeld[client]  = false;
    g_fLastUpdate[client] = now;
  }
}

public void OnClientPutInServer(int client)
{
  ResetClientState(client, GetGameTime(), true);
}

public void OnClientDisconnect(int client)
{
  RestoreOwnedSpeed(client);
  ResetClientState(client, GetGameTime(), false);
}

public void OnConfigsExecuted()
{
  RefreshConVars();

  float now = GetGameTime();
  for (int client = 1; client <= MaxClients; client++)
  {
    g_fLastUpdate[client] = now;
  }
}

public Action OnPlayerRunCmd(
  int   client,
  int  &buttons,
  int  &impulse,
  float vel[3],
  float angles[3],
  int  &weapon)
{
  if (!IsRealClient(client))
  {
    return Plugin_Continue;
  }

  bool isSurvivor = GetClientTeam(client) == TEAM_SURVIVOR;
  bool shiftHeld  = (buttons & IN_SPEED) != 0;
  bool buttonsChanged;

  if (g_bEnabled && isSurvivor && shiftHeld)
  {
    // 即使当前无法冲刺也要移除 IN_SPEED，确保 Shift 不会退回到
    // 游戏原版的慢走行为。
    buttons &= ~IN_SPEED;
    buttonsChanged = true;
  }

  if (!isSurvivor)
  {
    if (g_eState[client] == SprintState_Sprinting)
    {
      StopSprinting(client, GetGameTime());
    }

    g_bShiftHeld[client] = false;
    return buttonsChanged ? Plugin_Changed : Plugin_Continue;
  }

  g_bShiftHeld[client] = shiftHeld;

  if (!g_bEnabled)
  {
    return buttonsChanged ? Plugin_Changed : Plugin_Continue;
  }

  float now = GetGameTime();

  if (!g_bNeedsSpawnReset[client])
  {
    UpdateStamina(client, now);
  }

  if (!IsPlayerAlive(client))
  {
    if (g_eState[client] == SprintState_Sprinting)
    {
      StopSprinting(client, now);
    }

    return buttonsChanged ? Plugin_Changed : Plugin_Continue;
  }

  if (g_eState[client] == SprintState_Exhausted)
  {
    TryLeaveExhaustedState(client);
    return buttonsChanged ? Plugin_Changed : Plugin_Continue;
  }

  bool hasMoveInput =
    FloatAbs(vel[0]) > MOVE_EPSILON
    || FloatAbs(vel[1]) > MOVE_EPSILON
    || (buttons & (IN_FORWARD | IN_BACK | IN_MOVELEFT | IN_MOVERIGHT)) != 0;

  bool wantsSprint =
    shiftHeld
    && hasMoveInput
    && g_fStamina[client] > 0.0
    && IsSprintEligible(client);

  if (wantsSprint)
  {
    if (g_eState[client] == SprintState_Ready)
    {
      StartSprinting(client, now);
    }
    else if (g_eState[client] == SprintState_Sprinting)
    {
      ReconcileSprintSpeed(client);
    }
  }
  else if (g_eState[client] == SprintState_Sprinting)
  {
    StopSprinting(client, now);
  }

  return buttonsChanged ? Plugin_Changed : Plugin_Continue;
}

public Action Timer_Stamina(Handle timer)
{
  if (!g_bEnabled)
  {
    return Plugin_Continue;
  }

  float now = GetGameTime();

  for (int client = 1; client <= MaxClients; client++)
  {
    if (!IsRealClient(client) || g_bNeedsSpawnReset[client])
    {
      continue;
    }

    UpdateStamina(client, now);

    if (g_eState[client] != SprintState_Sprinting)
    {
      continue;
    }

    if (!IsSprintEligible(client))
    {
      StopSprinting(client, now);
      continue;
    }

    ReconcileSprintSpeed(client);
  }

  return Plugin_Continue;
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
  bool  wasEnabled = g_bEnabled;
  float oldMaximum = g_fStaminaMax;
  float now        = GetGameTime();

  if (convar == g_cvEnable && wasEnabled)
  {
    for (int client = 1; client <= MaxClients; client++)
    {
      if (IsRealClient(client) && !g_bNeedsSpawnReset[client])
      {
        UpdateStamina(client, now);
      }
    }
  }

  RefreshConVars();

  if (convar == g_cvEnable)
  {
    HandleEnableChange(wasEnabled, now);
    return;
  }

  if (convar == g_cvStaminaMax)
  {
    HandleMaximumChange(oldMaximum, now);
    return;
  }

  if (convar == g_cvMultiplier && g_bEnabled)
  {
    for (int client = 1; client <= MaxClients; client++)
    {
      if (g_eState[client] == SprintState_Sprinting)
      {
        ReconcileSprintSpeed(client);
      }
    }
  }
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
  float now = GetGameTime();

  for (int client = 1; client <= MaxClients; client++)
  {
    if (IsRealClient(client))
    {
      ResetClientState(client, now, false);
    }
    else
    {
      RestoreOwnedSpeed(client);
    }
  }
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
  float now = GetGameTime();

  for (int client = 1; client <= MaxClients; client++)
  {
    RestoreOwnedSpeed(client);

    if (g_eState[client] == SprintState_Sprinting)
    {
      g_eState[client]     = SprintState_Ready;
      g_fRecoverAt[client] = now + g_fRecoverDelay;
    }

    g_bShiftHeld[client]  = false;
    g_fLastUpdate[client] = now;
  }
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
  int client = GetClientOfUserId(event.GetInt("userid"));
  if (!IsRealClient(client) || GetClientTeam(client) != TEAM_SURVIVOR)
  {
    return;
  }

  float now = GetGameTime();

  if (g_bNeedsSpawnReset[client])
  {
    ResetClientState(client, now, false);
    return;
  }

  RestoreOwnedSpeed(client);
  if (g_eState[client] == SprintState_Sprinting)
  {
    g_eState[client]     = SprintState_Ready;
    g_fRecoverAt[client] = now + g_fRecoverDelay;
  }

  g_bShiftHeld[client]  = false;
  g_fLastUpdate[client] = now;
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
  int client = GetClientOfUserId(event.GetInt("userid"));
  if (!IsRealClient(client))
  {
    return;
  }

  RestoreOwnedSpeed(client);
  g_eState[client]           = SprintState_Ready;
  g_bShiftHeld[client]       = false;
  g_bSpentStamina[client]    = false;
  g_bNeedsSpawnReset[client] = true;
  g_fLastUpdate[client]      = GetGameTime();
}

void Event_PlayerRestricted(Event event, const char[] name, bool dontBroadcast)
{
  int client = GetClientOfUserId(event.GetInt("userid"));
  if (!IsRealClient(client) || g_eState[client] != SprintState_Sprinting)
  {
    return;
  }

  float now = GetGameTime();
  UpdateStamina(client, now);

  if (g_eState[client] == SprintState_Sprinting)
  {
    StopSprinting(client, now);
  }
}

void Event_PlayerBotReplace(Event event, const char[] name, bool dontBroadcast)
{
  int player = GetClientOfUserId(event.GetInt("player"));
  int bot    = GetClientOfUserId(event.GetInt("bot"));

  if (!IsRealClient(player))
  {
    return;
  }

  bool  hadOwnedSpeed   = g_bOwnsSpeed[player];
  float previousBase    = g_fBaseSpeed[player];
  float previousApplied = g_fAppliedSpeed[player];
  float now             = GetGameTime();

  if (g_eState[player] == SprintState_Sprinting)
  {
    UpdateStamina(player, now);

    if (g_eState[player] == SprintState_Sprinting)
    {
      StopSprinting(player, now);
    }
  }
  else
  {
    RestoreOwnedSpeed(player);
  }

  g_bShiftHeld[player]       = false;
  g_bNeedsSpawnReset[player] = false;
  g_fLastUpdate[player]      = now;

  if (!hadOwnedSpeed || !IsValidClient(bot))
  {
    return;
  }

  RestoreTransferredSpeed(bot, previousApplied, previousBase);

  DataPack pack = new DataPack();
  pack.WriteCell(GetClientUserId(bot));
  pack.WriteFloat(previousApplied);
  pack.WriteFloat(previousBase);
  RequestFrame(Frame_RestoreTransferredSpeed, pack);
}

void Event_BotPlayerReplace(Event event, const char[] name, bool dontBroadcast)
{
  int player = GetClientOfUserId(event.GetInt("player"));
  if (!IsRealClient(player))
  {
    return;
  }

  float now = GetGameTime();
  RestoreOwnedSpeed(player);

  if (g_eState[player] == SprintState_Sprinting)
  {
    g_eState[player]     = SprintState_Ready;
    g_fRecoverAt[player] = now + g_fRecoverDelay;
  }

  g_bShiftHeld[player]       = false;
  g_bNeedsSpawnReset[player] = false;
  g_fLastUpdate[player]      = now;
}

void Frame_RestoreTransferredSpeed(any data)
{
  DataPack pack = view_as<DataPack>(data);
  pack.Reset();

  int   bot             = GetClientOfUserId(pack.ReadCell());
  float previousApplied = pack.ReadFloat();
  float previousBase    = pack.ReadFloat();
  delete pack;

  if (IsValidClient(bot))
  {
    RestoreTransferredSpeed(bot, previousApplied, previousBase);
  }
}

void StartSprinting(int client, float now)
{
  if (!HasEntProp(client, Prop_Send, "m_flLaggedMovementValue"))
  {
    return;
  }

  float currentSpeed      = GetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue");
  float sprintSpeed       = currentSpeed * g_fMultiplier;

  g_fBaseSpeed[client]    = currentSpeed;
  g_fAppliedSpeed[client] = sprintSpeed;
  g_bOwnsSpeed[client]    = true;
  g_eState[client]        = SprintState_Sprinting;
  g_fLastUpdate[client]   = now;

  SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", sprintSpeed);
  NotifySprintStart(client, now);
}

void StopSprinting(int client, float now)
{
  RestoreOwnedSpeed(client);

  if (g_eState[client] == SprintState_Sprinting)
  {
    g_eState[client]     = SprintState_Ready;
    g_fRecoverAt[client] = now + g_fRecoverDelay;
  }

  g_fLastUpdate[client] = now;
}

void EnterExhaustedState(int client, float now)
{
  RestoreOwnedSpeed(client);
  g_eState[client]        = SprintState_Exhausted;
  g_fStamina[client]      = 0.0;
  g_fRecoverAt[client]    = now + g_fRecoverDelay;
  g_fLastUpdate[client]   = now;
  g_bSpentStamina[client] = true;

  if (g_bChatNotify && IsRealClient(client))
  {
    PrintToChat(client, "\x04[冲刺]\x01 体力已耗尽，请松开冲刺键并恢复体力。");
  }
}

void TryLeaveExhaustedState(int client)
{
  if (
    g_eState[client] == SprintState_Exhausted
    && !g_bShiftHeld[client]
    && g_fStamina[client] + SPEED_EPSILON >= g_fStaminaMax * g_fRestartRatio)
  {
    g_eState[client] = SprintState_Ready;
  }
}

void UpdateStamina(int client, float now)
{
  float previousUpdate  = g_fLastUpdate[client];
  g_fLastUpdate[client] = now;

  if (previousUpdate <= 0.0 || now <= previousUpdate)
  {
    TryLeaveExhaustedState(client);
    return;
  }

  if (g_eState[client] == SprintState_Sprinting)
  {
    float oldStamina = g_fStamina[client];
    g_fStamina[client] -= g_fStaminaDrain * (now - previousUpdate);

    if (g_fStamina[client] < oldStamina)
    {
      g_bSpentStamina[client] = true;
    }

    if (g_fStamina[client] <= 0.0)
    {
      EnterExhaustedState(client, now);
    }

    return;
  }

  if (g_fStamina[client] < g_fStaminaMax && now > g_fRecoverAt[client])
  {
    float recoveryStart = previousUpdate;
    if (recoveryStart < g_fRecoverAt[client])
    {
      recoveryStart = g_fRecoverAt[client];
    }

    if (now > recoveryStart)
    {
      float oldStamina = g_fStamina[client];
      g_fStamina[client] += g_fStaminaRecover * (now - recoveryStart);

      if (g_fStamina[client] >= g_fStaminaMax)
      {
        g_fStamina[client] = g_fStaminaMax;

        if (oldStamina < g_fStaminaMax && g_bSpentStamina[client])
        {
          g_bSpentStamina[client] = false;

          if (g_bChatNotify && IsRealClient(client))
          {
            PrintToChat(client, "\x04[冲刺]\x01 体力已完全恢复。");
          }
        }
      }
    }
  }

  TryLeaveExhaustedState(client);
}

void ReconcileSprintSpeed(int client)
{
  if (!g_bOwnsSpeed[client] || !IsValidClient(client))
  {
    return;
  }

  if (!HasEntProp(client, Prop_Send, "m_flLaggedMovementValue"))
  {
    g_bOwnsSpeed[client] = false;
    return;
  }

  float currentSpeed = GetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue");

  // 如果当前值不同于本插件上次写入的值，则视为游戏或其它插件写入的
  // 新基础倍率，再基于该值计算冲刺倍率。
  if (!FloatsNearlyEqual(currentSpeed, g_fAppliedSpeed[client]))
  {
    g_fBaseSpeed[client] = currentSpeed;
  }

  float sprintSpeed = g_fBaseSpeed[client] * g_fMultiplier;
  if (!FloatsNearlyEqual(currentSpeed, sprintSpeed))
  {
    SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", sprintSpeed);
  }

  g_fAppliedSpeed[client] = sprintSpeed;
}

void RestoreOwnedSpeed(int client)
{
  if (!g_bOwnsSpeed[client])
  {
    return;
  }

  if (IsValidClient(client) && HasEntProp(client, Prop_Send, "m_flLaggedMovementValue"))
  {
    float currentSpeed = GetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue");

    // 仅当属性仍是本插件上次写入的值时才恢复；
    // 之后由外部写入的值必须保留。
    if (FloatsNearlyEqual(currentSpeed, g_fAppliedSpeed[client]))
    {
      SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", g_fBaseSpeed[client]);
    }
  }

  g_bOwnsSpeed[client]    = false;
  g_fBaseSpeed[client]    = 0.0;
  g_fAppliedSpeed[client] = 0.0;
}

void RestoreTransferredSpeed(int client, float previousApplied, float previousBase)
{
  if (!IsValidClient(client) || !HasEntProp(client, Prop_Send, "m_flLaggedMovementValue"))
  {
    return;
  }

  float currentSpeed = GetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue");
  if (FloatsNearlyEqual(currentSpeed, previousApplied))
  {
    SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", previousBase);
  }
}

void RestoreAllOwnedSpeeds()
{
  for (int client = 1; client <= MaxClients; client++)
  {
    RestoreOwnedSpeed(client);
  }
}

void NotifySprintStart(int client, float now)
{
  if (
    !g_bChatNotify
    || now - g_fLastStartNotice[client] < g_fNoticeCooldown)
  {
    return;
  }

  g_fLastStartNotice[client] = now;
  PrintToChat(
    client,
    "\x04[冲刺]\x01 开始冲刺，当前体力：%d/%d",
    RoundToNearest(g_fStamina[client]),
    RoundToNearest(g_fStaminaMax));
}

bool IsSprintEligible(int client)
{
  if (
    !IsRealClient(client)
    || GetClientTeam(client) != TEAM_SURVIVOR
    || !IsPlayerAlive(client))
  {
    return false;
  }

  if (
    GetEntProp(client, Prop_Send, "m_isIncapacitated") != 0
    || GetEntProp(client, Prop_Send, "m_isHangingFromLedge") != 0
    || GetEntProp(client, Prop_Send, "m_isFallingFromLedge") != 0)
  {
    return false;
  }

  if (
    GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0
    || GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0
    || GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0
    || GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0
    || GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0)
  {
    return false;
  }

  int flags = GetEntityFlags(client);
  if ((flags & FL_FROZEN) != 0)
  {
    return false;
  }

  MoveType moveType = GetEntityMoveType(client);
  if (moveType == MOVETYPE_NONE || moveType == MOVETYPE_OBSERVER)
  {
    return false;
  }

  if (
    HasEntProp(client, Prop_Send, "m_staggerTimer")
    && GetGameTime() < GetEntPropFloat(client, Prop_Send, "m_staggerTimer", 1))
  {
    return false;
  }

  return true;
}

bool IsRealClient(int client)
{
  return (
    client > 0
    && client <= MaxClients
    && IsClientInGame(client)
    && !IsFakeClient(client));
}

bool IsValidClient(int client)
{
  return client > 0 && client <= MaxClients && IsClientInGame(client);
}

bool FloatsNearlyEqual(float first, float second)
{
  return FloatAbs(first - second) <= SPEED_EPSILON;
}

void ResetClientState(int client, float now, bool needsSpawnReset)
{
  RestoreOwnedSpeed(client);

  g_eState[client]           = SprintState_Ready;
  g_fStamina[client]         = g_fStaminaMax;
  g_fRecoverAt[client]       = now;
  g_fLastUpdate[client]      = now;
  g_fLastStartNotice[client] = -10000.0;
  g_bShiftHeld[client]       = false;
  g_bSpentStamina[client]    = false;
  g_bNeedsSpawnReset[client] = needsSpawnReset;
  g_bOwnsSpeed[client]       = false;
  g_fBaseSpeed[client]       = 0.0;
  g_fAppliedSpeed[client]    = 0.0;
}

void RefreshConVars()
{
  g_bEnabled        = g_cvEnable.BoolValue;
  g_fMultiplier     = g_cvMultiplier.FloatValue;
  g_fStaminaMax     = g_cvStaminaMax.FloatValue;
  g_fStaminaDrain   = g_cvStaminaDrain.FloatValue;
  g_fStaminaRecover = g_cvStaminaRecover.FloatValue;
  g_fRecoverDelay   = g_cvRecoverDelay.FloatValue;
  g_fRestartRatio   = g_cvRestartRatio.FloatValue;
  g_fNoticeCooldown = g_cvNoticeCooldown.FloatValue;
  g_bChatNotify     = g_cvChatNotify.BoolValue;
}

void HandleEnableChange(bool wasEnabled, float now)
{
  if (wasEnabled == g_bEnabled)
  {
    return;
  }

  for (int client = 1; client <= MaxClients; client++)
  {
    if (!g_bEnabled)
    {
      RestoreOwnedSpeed(client);

      if (g_eState[client] == SprintState_Sprinting)
      {
        g_eState[client]     = SprintState_Ready;
        g_fRecoverAt[client] = now + g_fRecoverDelay;
      }

      g_bShiftHeld[client] = false;
    }

    g_fLastUpdate[client] = now;
  }
}

void HandleMaximumChange(float oldMaximum, float now)
{
  for (int client = 1; client <= MaxClients; client++)
  {
    bool wasFull =
      oldMaximum > 0.0
      && g_fStamina[client] + SPEED_EPSILON >= oldMaximum;

    if (wasFull || g_fStamina[client] > g_fStaminaMax)
    {
      g_fStamina[client]      = g_fStaminaMax;
      g_bSpentStamina[client] = false;
    }

    if (g_fStamina[client] < 0.0)
    {
      g_fStamina[client] = 0.0;
    }

    g_fLastUpdate[client] = now;
    TryLeaveExhaustedState(client);
  }
}
