/*
 * Special Spawner Vote v1.0.0
 *
 * 为 Special Spawner 的 timer 和 limit 管理命令提供原生投票入口。
 * 投票通过后由服务器控制台执行原命令，不直接修改 Special Spawner 的 ConVar。
 */

#pragma tabsize 1
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <l4d2_nativevote>

#define VOTE_DURATION 20
#define SI_MAX_SIZE   6

enum ArgumentParseResult
{
  ParseResult_Valid,
  ParseResult_InvalidValue,
  ParseResult_InvalidSyntax,
  ParseResult_UnknownTarget
}

enum PendingVoteType
{
  PendingVote_None,
  PendingVote_Timer,
  PendingVote_Limit
}

static const char
  g_sZombieClass[SI_MAX_SIZE][] = {
    "smoker",
    "boomer",
    "hunter",
    "spitter",
    "jockey",
    "charger"
  };

PendingVoteType g_ePendingVoteType;

char g_sPendingLimitTarget[16];

int g_iPendingLimit;

float
  g_fPendingTimerMin,
  g_fPendingTimerMax;

bool
  g_bPendingLimitReset,
  g_bPendingTimerRange;

public Plugin myinfo =
{
  name        = "Special Spawner Vote",
  author      = "laoyutang",
  description = "Adds native votes for the Special Spawner timer and limit commands",
  version     = "1.0.0",
};

public void OnPluginStart()
{
  RegConsoleCmd("sm_limitvote", cmdVoteLimit, "发起设置特感生成数量的投票");
  RegConsoleCmd("sm_timervote", cmdVoteTimer, "发起设置特感生成时间的投票");
}

Action cmdVoteLimit(int client, int args)
{
  if (!IsValidVoteInitiator(client))
    return Plugin_Handled;

  if (!CommandExists("sm_limit"))
  {
    ReplyToCommand(client, "[SS投票] Special Spawner 未加载，无法发起数量投票。");
    return Plugin_Handled;
  }

  char target[16];
  int limit;
  bool reset;
  switch (ParseLimitArguments(args, target, sizeof target, limit, reset))
  {
    case ParseResult_Valid:
      StartLimitVote(client, target, limit, reset);
    case ParseResult_InvalidValue:
      ReplyToCommand(client, "[SS投票] Limit value must be >= 0");
    case ParseResult_InvalidSyntax, ParseResult_UnknownTarget:
      ShowLimitVoteUsage(client);
  }

  return Plugin_Handled;
}

Action cmdVoteTimer(int client, int args)
{
  if (!IsValidVoteInitiator(client))
    return Plugin_Handled;

  if (!CommandExists("sm_timer"))
  {
    ReplyToCommand(client, "[SS投票] Special Spawner 未加载，无法发起时间投票。");
    return Plugin_Handled;
  }

  float min;
  float max;
  bool range;
  switch (ParseTimerArguments(args, min, max, range))
  {
    case ParseResult_Valid:
      StartTimerVote(client, min, max, range);
    case ParseResult_InvalidValue:
      ReplyToCommand(client, "[SS投票] Max(>= 1.0) spawn time must greater than min(>= 0.1) spawn time");
    case ParseResult_InvalidSyntax:
      ShowTimerVoteUsage(client);
  }

  return Plugin_Handled;
}

bool IsValidVoteInitiator(int client)
{
  if (client <= 0 || client > MaxClients)
  {
    ReplyToCommand(client, "[SS投票] 请在游戏中使用此命令。");
    return false;
  }

  if (!IsClientInGame(client) || IsFakeClient(client))
  {
    ReplyToCommand(client, "[SS投票] 只有在服真人玩家可以发起投票。");
    return false;
  }

  return true;
}

ArgumentParseResult ParseLimitArguments(int args, char[] target, int targetLength, int &limit, bool &reset)
{
  target[0] = '\0';
  limit     = 0;
  reset     = false;

  char arg[16];
  if (args == 1)
  {
    GetCmdArg(1, arg, sizeof arg);
    if (strcmp(arg, "reset", false) == 0)
    {
      strcopy(target, targetLength, "reset");
      reset = true;
      return ParseResult_Valid;
    }

    return ParseResult_UnknownTarget;
  }

  if (args != 2)
    return ParseResult_InvalidSyntax;

  limit = GetCmdArgInt(2);
  if (limit < 0)
    return ParseResult_InvalidValue;

  GetCmdArg(1, arg, sizeof arg);
  if (strcmp(arg, "all", false) == 0)
    strcopy(target, targetLength, "all");
  else if (strcmp(arg, "max", false) == 0)
    strcopy(target, targetLength, "max");
  else if (strcmp(arg, "group", false) == 0)
    strcopy(target, targetLength, "group");
  else if (strcmp(arg, "wave", false) == 0)
    strcopy(target, targetLength, "wave");
  else
  {
    for (int i; i < SI_MAX_SIZE; i++)
    {
      if (strcmp(arg, g_sZombieClass[i], false) == 0)
      {
        strcopy(target, targetLength, g_sZombieClass[i]);
        break;
      }
    }
  }

  return target[0] == '\0' ? ParseResult_UnknownTarget : ParseResult_Valid;
}

ArgumentParseResult ParseTimerArguments(int args, float &min, float &max, bool &range)
{
  min   = 0.0;
  max   = 0.0;
  range = false;

  if (args == 1)
  {
    min = GetCmdArgFloat(1);
    if (min < 0.1)
      min = 0.1;

    max = min;
    return ParseResult_Valid;
  }

  if (args != 2)
    return ParseResult_InvalidSyntax;

  min   = GetCmdArgFloat(1);
  max   = GetCmdArgFloat(2);
  range = true;
  return min > 0.1 && max > 1.0 && max > min ? ParseResult_Valid : ParseResult_InvalidValue;
}

void ShowLimitVoteUsage(int client)
{
  ReplyToCommand(client, "\x04!limitvote/sm_limitvote \x05reset");
  ReplyToCommand(client, "\x04!limitvote/sm_limitvote \x05<class> <limit>");
  ReplyToCommand(client, "\x05<class> \x01[ all | max | group/wave | smoker | boomer | hunter | spitter | jockey | charger ]");
  ReplyToCommand(client, "\x05<limit> \x01[ >= 0 ]");
}

void ShowTimerVoteUsage(int client)
{
  ReplyToCommand(client, "[SS投票] timervote <constant> || timervote <min> <max>");
}

void StartLimitVote(int client, const char[] target, int limit, bool reset)
{
  if (!CanStartNativeVote(client))
    return;

  g_ePendingVoteType  = PendingVote_Limit;
  g_iPendingLimit     = limit;
  g_bPendingLimitReset = reset;
  strcopy(g_sPendingLimitTarget, sizeof g_sPendingLimitTarget, target);

  char title[128];
  if (reset)
    Format(title, sizeof title, "发起投票: 重置各类特感数量上限?");
  else if (strcmp(target, "all") == 0)
    Format(title, sizeof title, "发起投票: 所有特感职业上限设为 %d?", limit);
  else if (strcmp(target, "max") == 0)
    Format(title, sizeof title, "发起投票: 特感总数上限设为 %d?", limit);
  else if (strcmp(target, "group") == 0 || strcmp(target, "wave") == 0)
    Format(title, sizeof title, "发起投票: 每波特感数量设为 %d?", limit);
  else
    Format(title, sizeof title, "发起投票: %s 上限设为 %d?", target, limit);

  DisplayPendingVote(client, title);
}

void StartTimerVote(int client, float min, float max, bool range)
{
  if (!CanStartNativeVote(client))
    return;

  g_ePendingVoteType   = PendingVote_Timer;
  g_fPendingTimerMin   = min;
  g_fPendingTimerMax   = max;
  g_bPendingTimerRange = range;

  char title[128];
  if (range)
    Format(title, sizeof title, "发起投票: 特感刷新时间设为 %.1f - %.1f 秒?", min, max);
  else
    Format(title, sizeof title, "发起投票: 特感刷新时间设为 %.1f 秒?", min);

  DisplayPendingVote(client, title);
}

bool CanStartNativeVote(int client)
{
  if (L4D2NativeVote_IsAllowNewVote())
    return true;

  ReplyToCommand(client, "[SS投票] 投票正在进行中，请稍后再试。");
  return false;
}

void DisplayPendingVote(int client, const char[] title)
{
  L4D2NativeVote vote = L4D2NativeVote(Handler_SpawnVote);
  vote.SetDisplayText(title);
  vote.Initiator = client;

  int[] clients  = new int[MaxClients];
  int numClients = 0;
  for (int i = 1; i <= MaxClients; i++)
  {
    if (IsClientInGame(i) && !IsFakeClient(i))
      clients[numClients++] = i;
  }

  if (!vote.DisplayVote(clients, numClients, VOTE_DURATION))
  {
    ResetPendingVote();
    ReplyToCommand(client, "[SS投票] 发起投票失败。");
  }
}

public void Handler_SpawnVote(L4D2NativeVote vote, VoteAction action, int param1, int param2)
{
  if (action != VoteAction_End)
    return;

  int yes = vote.YesCount;
  int no  = vote.NoCount;
  if (yes <= no)
  {
    vote.SetFail();
    PrintToChatAll("\x04[SS投票]\x01 投票失败 (Yes:%d, No:%d)。", yes, no);
    ResetPendingVote();
    return;
  }

  if (!PendingCommandExists())
  {
    vote.SetFail();
    PrintToChatAll("\x04[SS投票]\x01 Special Spawner 已卸载或命令不存在，设置未执行。");
    ResetPendingVote();
    return;
  }

  vote.SetPass("设置已应用 (Setting Applied)");
  ExecutePendingCommand();
  ResetPendingVote();
}

bool PendingCommandExists()
{
  if (g_ePendingVoteType == PendingVote_Timer)
    return CommandExists("sm_timer");

  if (g_ePendingVoteType == PendingVote_Limit)
    return CommandExists("sm_limit");

  return false;
}

void ExecutePendingCommand()
{
  if (g_ePendingVoteType == PendingVote_Timer)
  {
    if (g_bPendingTimerRange)
      ServerCommand("sm_timer %f %f", g_fPendingTimerMin, g_fPendingTimerMax);
    else
      ServerCommand("sm_timer %f", g_fPendingTimerMin);
  }
  else if (g_ePendingVoteType == PendingVote_Limit)
  {
    if (g_bPendingLimitReset)
      ServerCommand("sm_limit reset");
    else
      ServerCommand("sm_limit %s %d", g_sPendingLimitTarget, g_iPendingLimit);
  }

  ServerExecute();
}

void ResetPendingVote()
{
  g_ePendingVoteType        = PendingVote_None;
  g_sPendingLimitTarget[0]  = '\0';
  g_iPendingLimit           = 0;
  g_fPendingTimerMin        = 0.0;
  g_fPendingTimerMax        = 0.0;
  g_bPendingLimitReset      = false;
  g_bPendingTimerRange      = false;
}
