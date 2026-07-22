/*
 * Special Spawner v2.1.0
 *
 * v2.1.0
 * - 新增可配置的基准人数，特感总上限由基准人数、基础上限和每人增量直接计算。
 * - 移除总上限中间 ConVar 和每波数量参数，每个刷新周期按总上限缺口补满队列。
 *
 * v2.0.0
 * - 将整波同步生成改为分帧队列生成，每 0.1 秒最多生成一只特感。
 * - 排队任务计入总数量和职业数量预留，防止跨周期突破配置上限。
 * - 每个任务连续失败三次后移至队尾，并使用无方向偏好重新尝试。
 * - 客户端槽位已满时暂停生成，不执行找位，也不消耗任务失败次数。
 * - 修复闲置特感补位计时器未保存句柄的问题，并增加零权重保护。
 */

#pragma tabsize 1
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define DEBUG     0
#define BENCHMARK 0
#if BENCHMARK
  #include <profiler>
Profiler g_profiler;
#endif

#define SI_SMOKER               0
#define SI_BOOMER               1
#define SI_HUNTER               2
#define SI_SPITTER              3
#define SI_JOCKEY               4
#define SI_CHARGER              5
#define SI_MAX_SIZE             6

#define SPAWN_QUEUE_INTERVAL    0.1
#define SPAWN_TASK_MAX_ATTEMPTS 3

enum
{
  SPAWN_TASK_CLASS,
  SPAWN_TASK_ATTEMPTS,
  SPAWN_TASK_RELAXED,
  SPAWN_TASK_SIZE
}

#define SPAWN_NO_PREFERENCE                  -1
#define SPAWN_ANYWHERE                       0
#define SPAWN_BEHIND_SURVIVORS               1
#define SPAWN_NEAR_IT_VICTIM                 2
#define SPAWN_SPECIALS_IN_FRONT_OF_SURVIVORS 3
#define SPAWN_SPECIALS_ANYWHERE              4
#define SPAWN_FAR_AWAY_FROM_SURVIVORS        5
#define SPAWN_ABOVE_SURVIVORS                6
#define SPAWN_IN_FRONT_OF_SURVIVORS          7
#define SPAWN_VERSUS_FINALE_DISTANCE         8
#define SPAWN_LARGE_VOLUME                   9
#define SPAWN_NEAR_POSITION                  10

Handle
  g_hSpawnTimer,
  g_hRetryTimer,
  g_hUpdateTimer,
  g_hSuicideTimer,
  g_hQueueTimer;

ArrayList g_aSpawnQueue;

ConVar
  g_cSpawnLimits[SI_MAX_SIZE],
  g_cSpawnWeights[SI_MAX_SIZE],
  g_cScaleWeights,
  g_cSpawnTimeMode,
  g_cSpawnTimeMin,
  g_cSpawnTimeMax,
  g_cBasePlayers,
  g_cBaseLimit,
  g_cExtraLimit,
  g_cTankStatusAction,
  g_cTankStatusLimits,
  g_cTankStatusWeights,
  g_cSuicideTime,
  g_cRushDistance,
  g_cSpawnRangeMin,
  g_cSpawnRangeMax,
  g_cFirstSpawnTime,
  g_cSpawnRange,
  g_cDiscardRange,
  g_cSafeSpawnRange;

float
  g_fSpawnTimeMin,
  g_fSpawnTimeMax,
  g_fExtraLimit,
  g_fSuicideTime,
  g_fRushDistance,
  g_fFirstSpawnTime,
  g_fSpawnTimes[MAXPLAYERS + 1],
  g_fActionTimes[MAXPLAYERS + 1];

static const char
  g_sZombieClass[SI_MAX_SIZE][] = {
    "smoker",
    "boomer",
    "hunter",
    "spitter",
    "jockey",
    "charger"
  };

int
  g_iSILimit,
  g_iDirection,
  g_iSpawnLimits[SI_MAX_SIZE],
  g_iSpawnWeights[SI_MAX_SIZE],
  g_iSpawnTimeMode,
  g_iTankStatusAction,
  g_iSpawnLimitsCache[SI_MAX_SIZE] = {
    -1,
    -1,
    -1,
    -1,
    -1,
    -1
  },
  g_iSpawnWeightsCache[SI_MAX_SIZE] = { -1, -1, -1, -1, -1, -1 }, g_iTankStatusLimits[SI_MAX_SIZE] = { -1, -1, -1, -1, -1, -1 }, g_iTankStatusWeights[SI_MAX_SIZE] = { -1, -1, -1, -1, -1, -1 }, g_iSpawnCounts[SI_MAX_SIZE], g_iBasePlayers, g_iBaseLimit, g_iCurrentClass = -1;

bool
  g_bLateLoad,
  g_bConfigsLoaded,
  g_bSuppressScaleUpdate,
  g_bInSpawnTime,
  g_bScaleWeights,
  g_bLeftSafeArea,
  g_bFinaleStarted;

public Plugin myinfo =
{
  name        = "Special Spawner",
  author      = "Tordecybombo, breezy, laoyutang",
  description = "Provides customisable special infected spawing beyond vanilla coop limits",
  version     = "2.1.0",
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
  g_bLateLoad = late;
  return APLRes_Success;
}

public void OnPluginStart()
{
  g_aSpawnQueue               = new ArrayList(SPAWN_TASK_SIZE);

  g_cSpawnLimits[SI_SMOKER]   = CreateConVar("ss_smoker_limit", "2", "同时存在的最大smoker数量", _, true, 0.0, true, 32.0);
  g_cSpawnLimits[SI_BOOMER]   = CreateConVar("ss_boomer_limit", "2", "同时存在的最大boomer数量", _, true, 0.0, true, 32.0);
  g_cSpawnLimits[SI_HUNTER]   = CreateConVar("ss_hunter_limit", "4", "同时存在的最大hunter数量", _, true, 0.0, true, 32.0);
  g_cSpawnLimits[SI_SPITTER]  = CreateConVar("ss_spitter_limit", "2", "同时存在的最大spitter数量", _, true, 0.0, true, 32.0);
  g_cSpawnLimits[SI_JOCKEY]   = CreateConVar("ss_jockey_limit", "4", "同时存在的最大jockey数量", _, true, 0.0, true, 32.0);
  g_cSpawnLimits[SI_CHARGER]  = CreateConVar("ss_charger_limit", "4", "同时存在的最大charger数量", _, true, 0.0, true, 32.0);

  g_cSpawnWeights[SI_SMOKER]  = CreateConVar("ss_smoker_weight", "100", "smoker产生比重", _, true, 0.0);
  g_cSpawnWeights[SI_BOOMER]  = CreateConVar("ss_boomer_weight", "200", "boomer产生比重", _, true, 0.0);
  g_cSpawnWeights[SI_HUNTER]  = CreateConVar("ss_hunter_weight", "100", "hunter产生比重", _, true, 0.0);
  g_cSpawnWeights[SI_SPITTER] = CreateConVar("ss_spitter_weight", "200", "spitter产生比重", _, true, 0.0);
  g_cSpawnWeights[SI_JOCKEY]  = CreateConVar("ss_jockey_weight", "100", "jockey产生比重", _, true, 0.0);
  g_cSpawnWeights[SI_CHARGER] = CreateConVar("ss_charger_weight", "100", "charger产生比重", _, true, 0.0);
  g_cScaleWeights             = CreateConVar("ss_scale_weights", "1", "缩放相应特感的产生比重 [0 = 关闭 | 1 = 开启](开启后,总比重越大的越容易先刷出来, 动态控制特感刷出顺序)", _, true, 0.0, true, 1.0);
  g_cSpawnTimeMin             = CreateConVar("ss_time_min", "10.0", "特感的最小产生时间", _, true, 0.1);
  g_cSpawnTimeMax             = CreateConVar("ss_time_max", "15.0", "特感的最大产生时间", _, true, 1.0);
  g_cSpawnTimeMode            = CreateConVar("ss_time_mode", "1", "特感的刷新时间模式[0 = 随机 | 1 = 递增(杀的越快刷的越快) | 2 = 递减(杀的越慢刷的越快)]", _, true, 0.0, true, 2.0);

  g_cBasePlayers              = CreateConVar("ss_base_players", "4", "基准幸存者人数, 不超过该人数时使用ss_base_limit", _, true, 1.0, true, 32.0);
  g_cBaseLimit                = CreateConVar("ss_base_limit", "4", "幸存者人数不超过ss_base_players时的特感总上限", _, true, 1.0, true, 32.0);
  g_cExtraLimit               = CreateConVar("ss_extra_limit", "1.0", "超过基准人数后, 每增加1名幸存者增加的特感上限, 可为小数", _, true, 0.0, true, 32.0);
  g_cTankStatusAction         = CreateConVar("ss_tankstatus_action", "1", "坦克产生后是否对当前刷特参数进行修改, 坦克死完后恢复?[0 = 忽略(保持原有的刷特状态) | 1 = 自定义]", _, true, 0.0, true, 1.0);
  g_cTankStatusLimits         = CreateConVar("ss_tankstatus_limits", "2;1;4;1;4;4", "坦克产生后每种特感数量的自定义参数");
  g_cTankStatusWeights        = CreateConVar("ss_tankstatus_weights", "100;400;100;200;100;100", "坦克产生后每种特感比重的自定义参数");
  g_cSuicideTime              = CreateConVar("ss_suicide_time", "25.0", "特感自动处死时间", _, true, 1.0);
  g_cRushDistance             = CreateConVar("ss_rush_distance", "1500.0", "路程超过多少算跑图(最前面的玩家路程减去最后面的玩家路程, 忽略倒地玩家)", _, true, 0.0);

  g_cSpawnRangeMin            = CreateConVar("ss_spawnrange_min", "100.0", "特感最小生成距离", _, true, 0.0);
  g_cSpawnRangeMax            = CreateConVar("ss_spawnrange_max", "1500.0", "特感最大生成距离", _, true, 0.0);

  g_cFirstSpawnTime           = CreateConVar("ss_first_time", "0.0", "玩家离开安全区域后第一波特感的刷新时间", _, true, 0.0);

  g_cSpawnRange               = FindConVar("z_spawn_range");
  g_cDiscardRange             = FindConVar("z_discard_range");
  g_cSafeSpawnRange           = FindConVar("z_safe_spawn_range");

  for (int i; i < SI_MAX_SIZE; i++)
  {
    g_cSpawnLimits[i].AddChangeHook(CvarChanged_Limits);
    g_cSpawnWeights[i].AddChangeHook(CvarChanged_General);
  }

  g_cSpawnTimeMin.AddChangeHook(CvarChanged_Times);
  g_cSpawnTimeMax.AddChangeHook(CvarChanged_Times);
  g_cSpawnTimeMode.AddChangeHook(CvarChanged_Times);

  g_cScaleWeights.AddChangeHook(CvarChanged_General);
  g_cBasePlayers.AddChangeHook(CvarChanged_General);
  g_cBaseLimit.AddChangeHook(CvarChanged_General);
  g_cExtraLimit.AddChangeHook(CvarChanged_General);
  g_cSuicideTime.AddChangeHook(CvarChanged_General);
  g_cRushDistance.AddChangeHook(CvarChanged_General);
  g_cFirstSpawnTime.AddChangeHook(CvarChanged_General);

  g_cTankStatusAction.AddChangeHook(CvarChanged_TankStatus);
  g_cTankStatusLimits.AddChangeHook(CvarChanged_TankCustom);
  g_cTankStatusWeights.AddChangeHook(CvarChanged_TankCustom);

  AutoExecConfig(true, "specialspawner");  //生成指定文件名的CFG.

  HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
  HookEvent("finale_vehicle_leaving", Event_RoundEnd, EventHookMode_PostNoCopy);
  HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
  HookEvent("player_hurt", Event_PlayerHurt);
  HookEvent("player_team", Event_PlayerTeam);
  HookEvent("player_spawn", Event_PlayerSpawn);
  HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);

  RegAdminCmd("sm_weight", cmdSetWeight, ADMFLAG_RCON, "设置特感生成比重");
  RegAdminCmd("sm_limit", cmdSetLimit, ADMFLAG_RCON, "设置特感生成数量");
  RegAdminCmd("sm_timer", cmdSetTimer, ADMFLAG_RCON, "设置特感生成时间");

  RegAdminCmd("sm_resetspawn", cmdResetSpawn, ADMFLAG_RCON, "处死所有特感并重新开始生成计时");
  RegAdminCmd("sm_forcetimer", cmdForceTimer, ADMFLAG_RCON, "开始生成计时");
  RegAdminCmd("sm_type", cmdType, ADMFLAG_ROOT, "随机轮换模式");

  HookEntityOutput("trigger_finale", "FinaleStart", OnFinaleStart);
}

public void OnPluginEnd()
{
  ClearSpawnQueue();
  delete g_aSpawnQueue;
  TweakSettings(true);
}

void TweakSettings(bool restore)
{
  if (!restore)
  {
    FindConVar("z_max_player_zombies").SetBounds(ConVarBound_Upper, true, float(MaxClients));
    FindConVar("z_max_player_zombies").SetFloat(float(MaxClients));
    FindConVar("z_minion_limit").SetInt(MaxClients);
    FindConVar("survival_max_specials").SetInt(MaxClients);

    FindConVar("z_smoker_limit").SetInt(0);
    FindConVar("z_boomer_limit").SetInt(0);
    FindConVar("z_hunter_limit").SetInt(0);
    FindConVar("z_spitter_limit").SetInt(0);
    FindConVar("z_jockey_limit").SetInt(0);
    FindConVar("z_charger_limit").SetInt(0);

    FindConVar("survival_max_smokers").SetInt(0);
    FindConVar("survival_max_boomers").SetInt(0);
    FindConVar("survival_max_hunters").SetInt(0);
    FindConVar("survival_max_spitters").SetInt(0);
    FindConVar("survival_max_jockeys").SetInt(0);
    FindConVar("survival_max_chargers").SetInt(0);

    g_cSpawnRange.SetInt(g_cSpawnRangeMax.IntValue);
    g_cDiscardRange.SetInt(g_cSpawnRange.IntValue + 500);
    g_cSafeSpawnRange.SetInt(g_cSpawnRangeMin.IntValue);
  }
  else {
    // FindConVar("z_max_player_zombies").RestoreDefault();
    FindConVar("z_minion_limit").RestoreDefault();
    FindConVar("survival_max_specials").RestoreDefault();

    FindConVar("z_smoker_limit").RestoreDefault();
    FindConVar("z_boomer_limit").RestoreDefault();
    FindConVar("z_hunter_limit").RestoreDefault();
    FindConVar("z_spitter_limit").RestoreDefault();
    FindConVar("z_jockey_limit").RestoreDefault();
    FindConVar("z_charger_limit").RestoreDefault();

    FindConVar("survival_max_smokers").RestoreDefault();
    FindConVar("survival_max_boomers").RestoreDefault();
    FindConVar("survival_max_hunters").RestoreDefault();
    FindConVar("survival_max_spitters").RestoreDefault();
    FindConVar("survival_max_jockeys").RestoreDefault();
    FindConVar("survival_max_chargers").RestoreDefault();

    g_cSpawnRange.RestoreDefault();
    g_cDiscardRange.RestoreDefault();
    g_cSafeSpawnRange.RestoreDefault();
  }
}

void OnFinaleStart(const char[] output, int caller, int activator, float delay)
{
  g_bFinaleStarted = L4D_IsMissionFinalMap();
}

public Action L4D_OnGetScriptValueInt(const char[] key, int &retVal)
{
  if (!g_bInSpawnTime)
    return Plugin_Continue;

  if (!strcmp(key, "PreferredSpecialDirection", false))
  {
    retVal = g_iDirection;
    return Plugin_Handled;
  }

  if (!strcmp(key, "MaxSpecials", false) || !strcmp(key, "cm_MaxSpecials", false))
  {
    retVal = g_iSILimit;
    return Plugin_Handled;
  }

  return Plugin_Continue;
}

public void L4D_OnFirstSurvivorLeftSafeArea_Post(int client)
{
  if (g_bLeftSafeArea)
    return;

  g_bLeftSafeArea = true;

  if (g_iCurrentClass >= SI_MAX_SIZE)
  {
    PrintToChatAll("\x03当前轮换\x01: \n");
    PrintToChatAll("\x01[\x05%s\x01]\x04模式\x01", g_sZombieClass[g_iCurrentClass - SI_MAX_SIZE]);
  }
  else if (g_iCurrentClass > -1)
    PrintToChatAll("\x01[\x05%s\x01]\x04模式\x01", g_sZombieClass[g_iCurrentClass]);

  StartCustomSpawnTimer(g_fFirstSpawnTime);
  delete g_hSuicideTimer;
  g_hSuicideTimer = CreateTimer(2.5, tmrForceSuicide, _, TIMER_REPEAT);
}

Action tmrForceSuicide(Handle timer)
{
  static int i;
  static int class;
  static int   victim;
  static float time;

  time = GetEngineTime();
  for (i = 1; i <= MaxClients; i++)
  {
    if (!IsClientInGame(i) || !IsFakeClient(i) || GetClientTeam(i) != 3 || !IsPlayerAlive(i))
      continue;

    class = GetEntProp(i, Prop_Send, "m_zombieClass");
    if (class < 1 || class > SI_MAX_SIZE)
      continue;

    if (GetEntProp(i, Prop_Send, "m_hasVisibleThreats"))
    {
      g_fActionTimes[i] = time;
      continue;
    }

    victim = GetSurVictim(i, class);
    if (victim > 0)
    {
      if (GetEntProp(victim, Prop_Send, "m_isIncapacitated"))
        KillInactiveSI(i);
      else
        g_fActionTimes[i] = time;
    }
    else if (time - g_fActionTimes[i] > g_fSuicideTime)
      KillInactiveSI(i);
  }

  return Plugin_Continue;
}

void KillInactiveSI(int client)
{
#if DEBUG
  PrintToServer("[SS] Kill inactive SI -> %N", client);
#endif
  ForcePlayerSuicide(client);

  if (!g_hRetryTimer)
    g_hRetryTimer = CreateTimer(1.0, tmrRetrySpawn, _, TIMER_FLAG_NO_MAPCHANGE);
}

int GetSurVictim(int client, int class)
{
  switch (class)
  {
    case 1:
      return GetEntPropEnt(client, Prop_Send, "m_tongueVictim");

    case 3:
      return GetEntPropEnt(client, Prop_Send, "m_pounceVictim");

    case 5:
      return GetEntPropEnt(client, Prop_Send, "m_jockeyVictim");

    case 6:
    {
      class = GetEntPropEnt(client, Prop_Send, "m_pummelVictim");
      if (class > 0)
        return class;

      class = GetEntPropEnt(client, Prop_Send, "m_carryVictim");
      if (class > 0)
        return class;
    }
  }

  return -1;
}

Action cmdSetLimit(int client, int args)
{
  if (args == 1)
  {
    char arg[16];
    GetCmdArg(1, arg, sizeof arg);
    if (strcmp(arg, "reset", false) == 0)
    {
      ResetLimits();
      ReplyToCommand(client, "[SS] Spawn Limits reset to default values");
      return Plugin_Handled;
    }

    ShowLimitUsage(client);
    return Plugin_Handled;
  }

  if (args != 2)
  {
    ShowLimitUsage(client);
    return Plugin_Handled;
  }

  char arg[16];
  GetCmdArg(1, arg, sizeof arg);

  int baseLimit;
  if (strcmp(arg, "base", false) == 0)
  {
    if (!GetCmdArgIntEx(2, baseLimit) || baseLimit < 1 || baseLimit > 32)
    {
      ReplyToCommand(client, "[SS] Base limit must be an integer between 1 and 32");
      return Plugin_Handled;
    }

    g_bSuppressScaleUpdate = true;
    g_cBaseLimit.IntValue  = baseLimit;
    g_bSuppressScaleUpdate = false;
    GetCvars_General();
    SetSpawnCount();
    return Plugin_Handled;
  }

  float increase;
  if (strcmp(arg, "increase", false) == 0)
  {
    if (!GetCmdArgFloatEx(2, increase) || increase < 0.0 || increase > 32.0)
    {
      ReplyToCommand(client, "[SS] Per-player increase must be between 0.0 and 32.0");
      return Plugin_Handled;
    }

    g_bSuppressScaleUpdate   = true;
    g_cExtraLimit.FloatValue = increase;
    g_bSuppressScaleUpdate   = false;
    GetCvars_General();
    SetSpawnCount();
    return Plugin_Handled;
  }

  if (GetCmdArgIntEx(1, baseLimit))
  {
    if (baseLimit < 1 || baseLimit > 32 || !GetCmdArgFloatEx(2, increase) || increase < 0.0 || increase > 32.0)
    {
      ReplyToCommand(client, "[SS] Usage: sm_limit <base: 1-32> <increase: 0.0-32.0>");
      return Plugin_Handled;
    }

    g_bSuppressScaleUpdate   = true;
    g_cBaseLimit.IntValue    = baseLimit;
    g_cExtraLimit.FloatValue = increase;
    g_bSuppressScaleUpdate   = false;
    GetCvars_General();
    SetSpawnCount();
    return Plugin_Handled;
  }

  int limit;
  if (!GetCmdArgIntEx(2, limit) || limit < 0 || limit > 32)
  {
    ReplyToCommand(client, "[SS] Class limit must be an integer between 0 and 32");
    return Plugin_Handled;
  }

  if (strcmp(arg, "all", false) == 0)
  {
    for (int i; i < SI_MAX_SIZE; i++)
      g_cSpawnLimits[i].IntValue = limit;

    PrintToChatAll("\x01[SS] All SI limits have been set to \x05%d", limit);
    return Plugin_Handled;
  }

  for (int i; i < SI_MAX_SIZE; i++)
  {
    if (strcmp(g_sZombieClass[i], arg, false) == 0)
    {
      g_cSpawnLimits[i].IntValue = limit;
      PrintToChatAll("\x01[SS] \x04%s \x01limit set to \x05%i", arg, limit);
      return Plugin_Handled;
    }
  }

  ShowLimitUsage(client);

  return Plugin_Handled;
}

void ShowLimitUsage(int client)
{
  ReplyToCommand(client, "\x04!limit/sm_limit \x05reset");
  ReplyToCommand(client, "\x04!limit/sm_limit \x05<base> <increase>");
  ReplyToCommand(client, "\x04!limit/sm_limit \x05base <1-32> | increase <0.0-32.0>");
  ReplyToCommand(client, "\x04!limit/sm_limit \x05<class> <0-32>");
  ReplyToCommand(client, "\x05<class> \x01[ all | smoker | boomer | hunter | spitter | jockey | charger ]");
}

Action cmdSetWeight(int client, int args)
{
  if (args == 1)
  {
    char arg[16];
    GetCmdArg(1, arg, sizeof arg);
    if (strcmp(arg, "reset", false) == 0)
    {
      ResetWeights();
      ReplyToCommand(client, "[SS] Spawn weights reset to default values");
    }
  }
  else if (args == 2) {
    if (GetCmdArgInt(2) < 0)
    {
      ReplyToCommand(client, "weight value >= 0");
      return Plugin_Handled;
    }
    else {
      char arg[16];
      GetCmdArg(1, arg, sizeof arg);
      int iWeight = GetCmdArgInt(2);
      if (strcmp(arg, "all", false) == 0)
      {
        for (int i; i < SI_MAX_SIZE; i++)
          g_cSpawnWeights[i].IntValue = iWeight;

        ReplyToCommand(client, "\x01[SS] -> \x04All spawn weights \x01set to \x05%d", iWeight);
      }
      else {
        for (int i; i < SI_MAX_SIZE; i++)
        {
          if (strcmp(arg, g_sZombieClass[i], false) == 0)
          {
            g_cSpawnWeights[i].IntValue = iWeight;
            ReplyToCommand(client, "\x01[SS] \x04%s \x01weight set to \x05%d", g_sZombieClass[i], iWeight);
          }
        }
      }
    }
  }
  else
  {
    ReplyToCommand(client, "\x04!weight/sm_weight \x05<class> <value>");
    ReplyToCommand(client, "\x05<class> \x01[ reset | all | smoker | boomer | hunter | spitter | jockey | charger ]");
    ReplyToCommand(client, "\x05value \x01[ >= 0 ]");
  }

  return Plugin_Handled;
}

Action cmdSetTimer(int client, int args)
{
  if (args == 1)
  {
    float time = GetCmdArgFloat(1);
    if (time < 0.1)
      time = 0.1;

    g_cSpawnTimeMin.FloatValue = time;
    g_cSpawnTimeMax.FloatValue = time;
    ReplyToCommand(client, "\x01[SS] Spawn timer set to constant \x05%.1f \x01seconds", time);
  }
  else if (args == 2) {
    float min = GetCmdArgFloat(1);
    float max = GetCmdArgFloat(2);
    if (min > 0.1 && max > 1.0 && max > min)
    {
      g_cSpawnTimeMin.FloatValue = min;
      g_cSpawnTimeMax.FloatValue = max;
      ReplyToCommand(client, "\x01[SS] Spawn timer will be between \x05%.1f \x01and \x05%.1f \x01seconds", min, max);
    }
    else
      ReplyToCommand(client, "[SS] Max(>= 1.0) spawn time must greater than min(>= 0.1) spawn time");
  }
  else
    ReplyToCommand(client, "[SS] timer <constant> || timer <min> <max>");

  return Plugin_Handled;
}

Action cmdResetSpawn(int client, int args)
{
  ClearSpawnQueue();

  for (int i = 1; i <= MaxClients; i++)
  {
    if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") != 8)
      ForcePlayerSuicide(i);
  }

  StartCustomSpawnTimer(g_fSpawnTimes[0]);
  ReplyToCommand(client, "[SS] Slayed all special infected. Spawn timer restarted. Next potential spawn in %.1f seconds.", g_fSpawnTimeMin);
  return Plugin_Handled;
}

Action cmdForceTimer(int client, int args)
{
  if (args < 1)
  {
    StartSpawnTimer();
    ReplyToCommand(client, "[SS] Spawn timer started manually.");
    return Plugin_Handled;
  }

  float time = GetCmdArgFloat(1);
  StartCustomSpawnTimer(time < 0.1 ? 0.1 : time);
  ReplyToCommand(client, "[SS] Spawn timer started manually. Next potential spawn in %.1f seconds.", time);
  return Plugin_Handled;
}

Action cmdType(int client, int args)
{
  if (args != 1)
  {
    ReplyToCommand(client, "\x04!type/sm_type \x05<class>.");
    ReplyToCommand(client, "\x05<type> \x01[ off | random | smoker | boomer | hunter | spitter | jockey | charger ]");
    return Plugin_Handled;
  }

  char arg[16];
  GetCmdArg(1, arg, sizeof arg);
  if (strcmp(arg, "off", false) == 0)
  {
    g_iCurrentClass = -1;
    ReplyToCommand(client, "已关闭单一特感模式");
    ResetLimits();
  }
  else if (strcmp(arg, "random", false) == 0) {
    PrintToChatAll("\x03当前轮换\x01: \n");
    PrintToChatAll("\x01[\x05%s\x01]\x04模式\x01", g_sZombieClass[SetRandomType()]);
  }
  else {
    int class = GetZombieClass(arg);
    if (class == -1)
    {
      ReplyToCommand(client, "\x04!type/sm_type \x05<class>.");
      ReplyToCommand(client, "\x05<type> \x01[ off | random | smoker | boomer | hunter | spitter | jockey | charger ]");
    }
    else if (class == g_iCurrentClass)
      ReplyToCommand(client, "目标特感类型与当前特感类型相同");
    else {
      SetSiType(class);
      PrintToChatAll("\x01[\x05%s\x01]\x04模式\x01", g_sZombieClass[class]);
    }
  }

  return Plugin_Handled;
}

int GetZombieClass(const char[] sClass)
{
  for (int i; i < SI_MAX_SIZE; i++)
  {
    if (strcmp(sClass, g_sZombieClass[i], false) == 0)
      return i;
  }
  return -1;
}

int SetRandomType()
{
  static int class;
  static int zombieClass[SI_MAX_SIZE] = { 0, 1, 2, 3, 4, 5 };

  class %= SI_MAX_SIZE;
  if (!class)
    SortIntegers(zombieClass, sizeof zombieClass, Sort_Random);

  SetSiType(zombieClass[class]);
  g_iCurrentClass += SI_MAX_SIZE;
  return zombieClass[class ++];
}

void SetSiType(int class)
{
  SaveConfiguration();
  for (int i; i < SI_MAX_SIZE; i++)
    g_cSpawnLimits[i].IntValue = i != class ? 0 : g_iSILimit;

  g_iCurrentClass = class;
}

public void OnAutoConfigsBuffered()
{
  g_bConfigsLoaded = false;
}

public void OnConfigsExecuted()
{
  GetCvars_Limits();
  GetCvars_General();
  GetCvars_Times();
  SetSpawnCount(false);
  GetCvars_TankStatus();
  GetCvars_TankCustom();
  TweakSettings(false);
  g_bConfigsLoaded = true;

  if (g_bLateLoad)
  {
    g_bLateLoad = false;
    if (L4D_HasAnySurvivorLeftSafeArea())
      L4D_OnFirstSurvivorLeftSafeArea_Post(0);
  }
}

void CvarChanged_Limits(ConVar convar, const char[] oldValue, const char[] newValue)
{
  GetCvars_Limits();
}

void GetCvars_Limits()
{
  for (int i; i < SI_MAX_SIZE; i++)
    g_iSpawnLimits[i] = g_cSpawnLimits[i].IntValue;
}

void CvarChanged_Times(ConVar convar, const char[] oldValue, const char[] newValue)
{
  GetCvars_Times();
}

void GetCvars_Times()
{
  g_fSpawnTimeMin  = g_cSpawnTimeMin.FloatValue;
  g_fSpawnTimeMax  = g_cSpawnTimeMax.FloatValue;
  g_iSpawnTimeMode = g_cSpawnTimeMode.IntValue;

  if (g_fSpawnTimeMin > g_fSpawnTimeMax)
    g_fSpawnTimeMin = g_fSpawnTimeMax;

  CalculateSpawnTimes();
}

void CalculateSpawnTimes()
{
  if (g_iSILimit <= 1 || g_iSpawnTimeMode <= 0)
  {
    for (int i; i <= MaxClients; i++)
      g_fSpawnTimes[i] = g_fSpawnTimeMax;

    return;
  }
  else {
    float unit = (g_fSpawnTimeMax - g_fSpawnTimeMin) / (g_iSILimit - 1);
    switch (g_iSpawnTimeMode)
    {
      case 1:
      {
        g_fSpawnTimes[0] = g_fSpawnTimeMin;
        for (int i = 1; i <= MaxClients; i++)
          g_fSpawnTimes[i] = i < g_iSILimit ? (g_fSpawnTimes[i - 1] + unit) : g_fSpawnTimeMax;
      }

      case 2:
      {
        g_fSpawnTimes[0] = g_fSpawnTimeMax;
        for (int i = 1; i <= MaxClients; i++)
          g_fSpawnTimes[i] = i < g_iSILimit ? (g_fSpawnTimes[i - 1] - unit) : g_fSpawnTimeMax;
      }
    }
  }
}

void CvarChanged_General(ConVar convar, const char[] oldValue, const char[] newValue)
{
  GetCvars_General();

  if (g_bConfigsLoaded && !g_bSuppressScaleUpdate && (convar == g_cBasePlayers || convar == g_cBaseLimit || convar == g_cExtraLimit))
    SetSpawnCount();
}

void GetCvars_General()
{
  g_bScaleWeights = g_cScaleWeights.BoolValue;

  for (int i; i < SI_MAX_SIZE; i++)
    g_iSpawnWeights[i] = g_cSpawnWeights[i].IntValue;

  g_iBasePlayers    = g_cBasePlayers.IntValue;
  g_iBaseLimit      = g_cBaseLimit.IntValue;
  g_fExtraLimit     = g_cExtraLimit.FloatValue;
  g_fSuicideTime    = g_cSuicideTime.FloatValue;
  g_fRushDistance   = g_cRushDistance.FloatValue;
  g_fFirstSpawnTime = g_cFirstSpawnTime.FloatValue;
}

void CvarChanged_TankStatus(ConVar convar, const char[] oldValue, const char[] newValue)
{
  int last = g_iTankStatusAction;

  GetCvars_TankStatus();
  if (last != g_iTankStatusAction)
    TankStatusActoin(FindTank(-1));
}

void GetCvars_TankStatus()
{
  g_iTankStatusAction = g_cTankStatusAction.IntValue;
}

void CvarChanged_TankCustom(ConVar convar, const char[] oldValue, const char[] newValue)
{
  GetCvars_TankCustom();
}

void GetCvars_TankCustom()
{
  char temp[64];
  g_cTankStatusLimits.GetString(temp, sizeof temp);

  char buffers[SI_MAX_SIZE][8];
  ExplodeString(temp, ";", buffers, sizeof buffers, sizeof buffers[]);

  int i;
  int val;
  for (; i < SI_MAX_SIZE; i++)
  {
    if (buffers[i][0] == '\0')
    {
      g_iTankStatusLimits[i] = -1;
      continue;
    }

    if ((val = StringToInt(buffers[i])) < -1 || val > g_iSILimit)
    {
      g_iTankStatusLimits[i] = -1;
      buffers[i][0]          = '\0';
      continue;
    }

    g_iTankStatusLimits[i] = val;
    buffers[i][0]          = '\0';
  }

  g_cTankStatusWeights.GetString(temp, sizeof temp);
  ExplodeString(temp, ";", buffers, sizeof buffers, sizeof buffers[]);

  for (i = 0; i < SI_MAX_SIZE; i++)
  {
    if (buffers[i][0] == '\0' || (val = StringToInt(buffers[i])) < 0)
    {
      g_iTankStatusWeights[i] = -1;
      continue;
    }

    g_iTankStatusWeights[i] = val;
  }
}

public void OnClientDisconnect(int client)
{
  if (!client || !IsClientInGame(client) || GetClientTeam(client) != 3 || GetEntProp(client, Prop_Send, "m_zombieClass") != 8)
    return;

  CreateTimer(0.1, tmrTankDisconnect, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void OnMapEnd()
{
  g_bLeftSafeArea  = false;
  g_bFinaleStarted = false;

  EndSpawnTimer();
  ClearSpawnQueue();
  delete g_hSuicideTimer;
  TankStatusActoin(false);

  if (g_iCurrentClass >= SI_MAX_SIZE)
    SetRandomType();
  else if (g_iCurrentClass > -1)
    SetSiType(g_iCurrentClass);
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
  OnMapEnd();
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
  EndSpawnTimer();
  ClearSpawnQueue();
}

void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
  if (!g_bLeftSafeArea)
    return;

  g_fActionTimes[GetClientOfUserId(event.GetInt("userid"))]   = GetEngineTime();
  g_fActionTimes[GetClientOfUserId(event.GetInt("attacker"))] = GetEngineTime();
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
  int client = GetClientOfUserId(event.GetInt("userid"));
  if (!client || !IsClientInGame(client))
    return;

  if (event.GetInt("team") == 2 || event.GetInt("oldteam") == 2)
  {
    delete g_hUpdateTimer;
    g_hUpdateTimer = CreateTimer(2.0, tmrUpdate);
  }
}

Action tmrUpdate(Handle timer)
{
  g_hUpdateTimer = null;
  SetSpawnCount();
  return Plugin_Continue;
}

void SetSpawnCount(bool announce = true)
{
  int survivorCount;
  for (int i = 1; i <= MaxClients; i++)
  {
    if (IsClientInGame(i) && GetClientTeam(i) == 2)
      survivorCount++;
  }

  int extraPlayers = survivorCount - g_iBasePlayers;
  if (extraPlayers < 0)
    extraPlayers = 0;

  int limit = g_iBaseLimit + RoundToNearest(g_fExtraLimit * extraPlayers);
  if (limit < 1)
    limit = 1;
  else if (limit > 32)
    limit = 32;

  if (limit != g_iSILimit)
  {
    g_iSILimit = limit;
    CalculateSpawnTimes();
  }

  if (announce)
    PrintToChatAll("\x01[\x05%d特\x01] [\x03%.1f\x01~\x03%.1f\x01]\x04秒", g_iSILimit, g_fSpawnTimeMin, g_fSpawnTimeMax);
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
  int client = GetClientOfUserId(event.GetInt("userid"));
  if (!client || !IsClientInGame(client) || GetClientTeam(client) != 3)
    return;

  if (GetEntProp(client, Prop_Send, "m_zombieClass") != 8)
    g_fActionTimes[client] = GetEngineTime();
  else
    CreateTimer(0.1, tmrTankSpawn, event.GetInt("userid"), TIMER_FLAG_NO_MAPCHANGE);
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
  int client = GetClientOfUserId(event.GetInt("userid"));
  if (!client || !IsClientInGame(client) || GetClientTeam(client) != 3)
    return;

  static int class;
  class = GetEntProp(client, Prop_Send, "m_zombieClass");
  if (class == 8 && !FindTank(client))
    TankStatusActoin(false);

  if (class != 4 && IsFakeClient(client))
    RequestFrame(NextFrame_KickBot, event.GetInt("userid"));
}

Action tmrTankSpawn(Handle timer, int client)
{
  if (!(client = GetClientOfUserId(client)) || !IsClientInGame(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_zombieClass") != 8 || FindTank(client))
    return Plugin_Stop;

  int totalLimit;
  int totalWeight;
  for (int i; i < SI_MAX_SIZE; i++)
  {
    totalLimit += g_iSpawnLimits[i];
    totalWeight += g_iSpawnWeights[i];
  }

  if (totalLimit && totalWeight)
    TankStatusActoin(true);

  return Plugin_Continue;
}

void SaveConfiguration()
{
  for (int i; i < SI_MAX_SIZE; i++)
  {
    g_iSpawnLimitsCache[i]  = g_iSpawnLimits[i];
    g_iSpawnWeightsCache[i] = g_iSpawnWeights[i];
  }
}

void NextFrame_KickBot(any client)
{
  if ((client = GetClientOfUserId(client)) && IsClientInGame(client) && !IsClientInKickQueue(client) && IsFakeClient(client))
    KickClient(client);
}

bool FindTank(int client)
{
  for (int i = 1; i <= MaxClients; i++)
  {
    if (i != client && IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") == 8)
      return true;
  }
  return false;
}

Action tmrTankDisconnect(Handle timer)
{
  if (FindTank(-1))
    return Plugin_Stop;

  TankStatusActoin(false);
  return Plugin_Continue;
}

void TankStatusActoin(bool isTankAlive)
{
  static bool loaded;
  if (!isTankAlive)
  {
    if (loaded)
    {
      loaded = false;
      LoadCacheSpawnLimits();
      LoadCacheSpawnWeights();
    }
  }
  else {
    if (!loaded && g_iTankStatusAction)
    {
      loaded = true;
      for (int i; i < SI_MAX_SIZE; i++)
      {
        g_iSpawnLimitsCache[i]  = g_iSpawnLimits[i];
        g_iSpawnWeightsCache[i] = g_iSpawnWeights[i];
      }
      LoadCacheTankCustom();
    }
  }
}

void LoadCacheSpawnLimits()
{
  for (int i; i < SI_MAX_SIZE; i++)
  {
    if (g_iSpawnLimitsCache[i] != -1)
    {
      g_cSpawnLimits[i].IntValue = g_iSpawnLimitsCache[i];
      g_iSpawnLimitsCache[i]     = -1;
    }
  }
}

void LoadCacheSpawnWeights()
{
  for (int i; i < SI_MAX_SIZE; i++)
  {
    if (g_iSpawnWeightsCache[i] != -1)
    {
      g_cSpawnWeights[i].IntValue = g_iSpawnWeightsCache[i];
      g_iSpawnWeightsCache[i]     = -1;
    }
  }
}

void LoadCacheTankCustom()
{
  for (int i; i < SI_MAX_SIZE; i++)
  {
    if (g_iTankStatusLimits[i] != -1)
      g_cSpawnLimits[i].IntValue = g_iTankStatusLimits[i];

    if (g_iTankStatusWeights[i] != -1)
      g_cSpawnWeights[i].IntValue = g_iTankStatusWeights[i];
  }
}

void ResetLimits()
{
  for (int i; i < SI_MAX_SIZE; i++)
    g_cSpawnLimits[i].RestoreDefault();
}

void ResetWeights()
{
  for (int i; i < SI_MAX_SIZE; i++)
    g_cSpawnWeights[i].RestoreDefault();
}

void StartCustomSpawnTimer(float time)
{
  EndSpawnTimer();
  g_hSpawnTimer = CreateTimer(time, tmrSpawnSpecial);
}

void StartSpawnTimer()
{
  EndSpawnTimer();
  g_hSpawnTimer = CreateTimer(g_iSpawnTimeMode > 0 ? g_fSpawnTimes[GetTotalSI()] : Math_GetRandomFloat(g_fSpawnTimeMin, g_fSpawnTimeMax), tmrSpawnSpecial);
}

void EndSpawnTimer()
{
  delete g_hSpawnTimer;
  delete g_hRetryTimer;
}

Action tmrSpawnSpecial(Handle timer)
{
  g_hSpawnTimer = null;
  delete g_hRetryTimer;

  int totalSI = GetTotalSI();
  ExecuteSpawnQueue(totalSI);

  g_hSpawnTimer = CreateTimer(g_iSpawnTimeMode > 0 ? g_fSpawnTimes[totalSI] : Math_GetRandomFloat(g_fSpawnTimeMin, g_fSpawnTimeMax), tmrSpawnSpecial);
  return Plugin_Continue;
}

void ExecuteSpawnQueue(int totalSI)
{
  int queuedSI  = g_aSpawnQueue.Length;
  int allowedSI = g_iSILimit - totalSI - queuedSI;
  if (allowedSI <= 0)
    return;

  GetSITypeCount();

  // 排队任务视为已预留特感名额，防止后续刷新周期突破总上限和职业上限。
  for (int i; i < queuedSI; i++)
  {
    int queuedClass = g_aSpawnQueue.Get(i, SPAWN_TASK_CLASS);
    if (queuedClass >= 0 && queuedClass < SI_MAX_SIZE)
      g_iSpawnCounts[queuedClass]++;
  }

  int index;
  for (int i; i < allowedSI; i++)
  {
    index = GenerateIndex();
    if (index == -1)
      break;

    int task = g_aSpawnQueue.Push(index);
    g_aSpawnQueue.Set(task, 0, SPAWN_TASK_ATTEMPTS);
    g_aSpawnQueue.Set(task, 0, SPAWN_TASK_RELAXED);
    g_iSpawnCounts[index]++;
  }

  // 每个刷新周期将全局空缺全部加入队列，队列任务继续占用总数和职业名额预留。
  if (g_aSpawnQueue.Length)
    StartSpawnQueueTimer();
}

void StartSpawnQueueTimer()
{
  if (!g_hQueueTimer && g_aSpawnQueue.Length)
    g_hQueueTimer = CreateTimer(SPAWN_QUEUE_INTERVAL, tmrProcessSpawnQueue, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

void ClearSpawnQueue()
{
  delete g_hQueueTimer;
  if (g_aSpawnQueue)
    g_aSpawnQueue.Clear();
}

bool GetSpawnTarget(int &client, bool &rusher)
{
  bool  found;
  float flow;
  float firstFlow;
  float lastFlow;

  for (int i = 1; i <= MaxClients; i++)
  {
    if (!IsClientInGame(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i) || GetEntProp(i, Prop_Send, "m_isIncapacitated"))
      continue;

    flow = L4D2Direct_GetFlowDistance(i);
    if (!flow || flow == -9999.0)
      continue;

    if (!found)
    {
      found     = true;
      client    = i;
      firstFlow = flow;
      lastFlow  = flow;
      continue;
    }

    if (flow > firstFlow)
    {
      firstFlow = flow;
      client    = i;
    }

    if (flow < lastFlow)
      lastFlow = flow;
  }

  rusher = found && firstFlow - lastFlow > g_fRushDistance;
  return found;
}

void RotateSpawnTask(bool relaxDirection)
{
  int zombieClass = g_aSpawnQueue.Get(0, SPAWN_TASK_CLASS);
  int attempts    = g_aSpawnQueue.Get(0, SPAWN_TASK_ATTEMPTS);
  int relaxed     = g_aSpawnQueue.Get(0, SPAWN_TASK_RELAXED);

  g_aSpawnQueue.Erase(0);
  int task = g_aSpawnQueue.Push(zombieClass);
  g_aSpawnQueue.Set(task, attempts, SPAWN_TASK_ATTEMPTS);
  g_aSpawnQueue.Set(task, relaxDirection ? 1 : relaxed, SPAWN_TASK_RELAXED);
}

void MarkSpawnTaskFailed()
{
  int attempts = g_aSpawnQueue.Get(0, SPAWN_TASK_ATTEMPTS) + 1;
  if (attempts < SPAWN_TASK_MAX_ATTEMPTS)
  {
    g_aSpawnQueue.Set(0, attempts, SPAWN_TASK_ATTEMPTS);
    return;
  }

  // 每个任务在三个不同消费周期内各尝试一次。
  // 连续三次失败后移到队尾，避免一个职业长期阻塞整个队列。
  g_aSpawnQueue.Set(0, 0, SPAWN_TASK_ATTEMPTS);
  RotateSpawnTask(true);
}

Action tmrProcessSpawnQueue(Handle timer)
{
  if (!g_aSpawnQueue.Length)
  {
    g_hQueueTimer = null;
    return Plugin_Stop;
  }

  int classIndex = g_aSpawnQueue.Get(0, SPAWN_TASK_CLASS);
  if (classIndex < 0 || classIndex >= SI_MAX_SIZE || g_iSpawnLimits[classIndex] <= 0)
  {
    // 只有生成成功或任务因配置变化永久失效时，才从队列删除。
    g_aSpawnQueue.Erase(0);
    return Plugin_Continue;
  }

  int totalSI = GetTotalSI();
  if (totalSI >= g_iSILimit)
    return Plugin_Continue;

  GetSITypeCount();
  if (g_iSpawnCounts[classIndex] >= g_iSpawnLimits[classIndex])
  {
    RotateSpawnTask(false);
    return Plugin_Continue;
  }

  // 客户端槽位已满时生成必然失败。
  // 保留队首任务，不执行昂贵找位，也不消耗任务失败次数。
  if (GetClientCount(false) >= MaxClients)
    return Plugin_Continue;

  int  client;
  bool rusher;
  if (!GetSpawnTarget(client, rusher))
    return Plugin_Continue;

  bool relaxed = g_aSpawnQueue.Get(0, SPAWN_TASK_RELAXED) != 0;
  g_iDirection = g_bFinaleStarted ? SPAWN_NEAR_IT_VICTIM : (relaxed ? SPAWN_NO_PREFERENCE : (rusher ? SPAWN_IN_FRONT_OF_SURVIVORS : SPAWN_LARGE_VOLUME));

  int   zombie;
  float vPos[3];
  g_bInSpawnTime = true;
  bool found     = L4D_GetRandomPZSpawnPosition(client, classIndex + 1, 1, vPos);
  if (found)
  {
    vPos[2] += 5.0;
    zombie = L4D2_SpawnSpecial(classIndex + 1, vPos, NULL_VECTOR);
  }
  g_bInSpawnTime = false;

  if (zombie > 0)
  {
    SetEntProp(zombie, Prop_Send, "m_bDucked", 1);
    SetEntityFlags(zombie, GetEntityFlags(zombie) | FL_DUCKING);
    g_aSpawnQueue.Erase(0);

    if (!g_aSpawnQueue.Length)
    {
      g_hQueueTimer = null;
      return Plugin_Stop;
    }

    return Plugin_Continue;
  }

  if (GetClientCount(false) < MaxClients)
    MarkSpawnTaskFailed();

  return Plugin_Continue;
}

Action tmrRetrySpawn(Handle timer)
{
  g_hRetryTimer = null;
  ExecuteSpawnQueue(GetTotalSI());
  return Plugin_Stop;
}

int GetTotalSI()
{
  int count;
  for (int i = 1; i <= MaxClients; i++)
  {
    if (!IsClientInGame(i) || IsClientInKickQueue(i) || GetClientTeam(i) != 3)
      continue;

    if (IsPlayerAlive(i))
    {
      if (1 <= GetEntProp(i, Prop_Send, "m_zombieClass") <= 6)
        count++;
    }
    else if (IsFakeClient(i))
      KickClient(i);
  }
  return count;
}

void GetSITypeCount()
{
  int i;
  for (; i < SI_MAX_SIZE; i++)
    g_iSpawnCounts[i] = 0;

  for (i = 1; i <= MaxClients; i++)
  {
    if (!IsClientInGame(i) || IsClientInKickQueue(i) || GetClientTeam(i) != 3 || !IsPlayerAlive(i))
      continue;

    switch (GetEntProp(i, Prop_Send, "m_zombieClass"))
    {
      case 1:
        g_iSpawnCounts[SI_SMOKER]++;

      case 2:
        g_iSpawnCounts[SI_BOOMER]++;

      case 3:
        g_iSpawnCounts[SI_HUNTER]++;

      case 4:
        g_iSpawnCounts[SI_SPITTER]++;

      case 5:
        g_iSpawnCounts[SI_JOCKEY]++;

      case 6:
        g_iSpawnCounts[SI_CHARGER]++;
    }
  }
}

int GenerateIndex()
{
  static int   i;
  static int   totalWeight;
  static int   standardizedWeight;
  static int   tempWeights[SI_MAX_SIZE];
  static float unit;
  static float random;
  static float intervalEnds[SI_MAX_SIZE];

  totalWeight        = 0;
  standardizedWeight = 0;

  for (i = 0; i < SI_MAX_SIZE; i++)
  {
    tempWeights[i] = g_iSpawnCounts[i] < g_iSpawnLimits[i] ? (g_bScaleWeights ? ((g_iSpawnLimits[i] - g_iSpawnCounts[i]) * g_iSpawnWeights[i]) : g_iSpawnWeights[i]) : 0;
    totalWeight += tempWeights[i];
  }

  if (totalWeight <= 0)
    return -1;

  unit = 1.0 / totalWeight;
  for (i = 0; i < SI_MAX_SIZE; i++)
  {
    if (tempWeights[i] >= 0)
    {
      standardizedWeight += tempWeights[i];
      intervalEnds[i] = standardizedWeight * unit;
    }
  }

  random = Math_GetRandomFloat(0.0, 1.0);
  for (i = 0; i < SI_MAX_SIZE; i++)
  {
    if (tempWeights[i] > 0 && intervalEnds[i] >= random)
      return i;
  }

  return -1;
}

// https://github.com/bcserv/smlib/blob/transitional_syntax/scripting/include/smlib/math.inc
float Math_GetRandomFloat(float min, float max)
{
  return (GetURandomFloat() * (max - min)) + min;
}
