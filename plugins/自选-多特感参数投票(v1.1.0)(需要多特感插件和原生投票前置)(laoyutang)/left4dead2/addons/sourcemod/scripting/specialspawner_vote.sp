/*
 * Special Spawner Vote
 *
 * v1.1.0
 * - 数量投票改为base/increase缩放参数，支持一次提交两个数字。
 * - 移除max/group/wave投票目标。
 *
 * v1.0.0
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

enum PendingLimitAction
{
  PendingLimit_None,
  PendingLimit_Reset,
  PendingLimit_Class,
  PendingLimit_Base,
  PendingLimit_Increase,
  PendingLimit_Scale
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

PendingVoteType    g_ePendingVoteType;

PendingLimitAction g_ePendingLimitAction;

char               g_sPendingLimitTarget[16];

int
  g_iPendingLimit,
  g_iPendingBaseLimit;

float
  g_fPendingIncrease,
  g_fPendingTimerMin,
  g_fPendingTimerMax;

bool g_bPendingTimerRange;

public Plugin myinfo =
{
  name        = "Special Spawner Vote",
  author      = "laoyutang",
  description = "Adds native votes for the Special Spawner timer and limit commands",
  version     = "1.1.0",
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

  PendingLimitAction action;
  char               target[16];
  int                limit;
  int                baseLimit;
  float              increase;
  switch (ParseLimitArguments(args, action, target, sizeof target, limit, baseLimit, increase))
  {
    case ParseResult_Valid:
      StartLimitVote(client, action, target, limit, baseLimit, increase);
    case ParseResult_InvalidValue:
      ReplyToCommand(client, "[SS投票] 参数无效：base需为1-32整数，increase需为0.0-32.0，各职业上限需为0-32整数。");
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
  bool  range;
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

ArgumentParseResult ParseLimitArguments(int args, PendingLimitAction &action, char[] target, int targetLength, int &limit, int &baseLimit, float &increase)
{
  action    = PendingLimit_None;
  target[0] = '\0';
  limit     = 0;
  baseLimit = 0;
  increase  = 0.0;

  char arg[16];
  if (args == 1)
  {
    GetCmdArg(1, arg, sizeof arg);
    if (strcmp(arg, "reset", false) == 0)
    {
      action = PendingLimit_Reset;
      return ParseResult_Valid;
    }

    return ParseResult_UnknownTarget;
  }

  if (args != 2)
    return ParseResult_InvalidSyntax;

  GetCmdArg(1, arg, sizeof arg);
  if (strcmp(arg, "base", false) == 0)
  {
    if (!GetCmdArgIntEx(2, baseLimit) || baseLimit < 1 || baseLimit > 32)
      return ParseResult_InvalidValue;

    action = PendingLimit_Base;
    return ParseResult_Valid;
  }

  if (strcmp(arg, "increase", false) == 0)
  {
    if (!GetCmdArgFloatEx(2, increase) || increase < 0.0 || increase > 32.0)
      return ParseResult_InvalidValue;

    action = PendingLimit_Increase;
    return ParseResult_Valid;
  }

  if (GetCmdArgIntEx(1, baseLimit))
  {
    if (baseLimit < 1 || baseLimit > 32 || !GetCmdArgFloatEx(2, increase) || increase < 0.0 || increase > 32.0)
      return ParseResult_InvalidValue;

    action = PendingLimit_Scale;
    return ParseResult_Valid;
  }

  if (strcmp(arg, "all", false) == 0)
    strcopy(target, targetLength, "all");
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

  if (target[0] == '\0')
    return ParseResult_UnknownTarget;

  if (!GetCmdArgIntEx(2, limit) || limit < 0 || limit > 32)
    return ParseResult_InvalidValue;

  action = PendingLimit_Class;
  return ParseResult_Valid;
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
  ReplyToCommand(client, "\x04!limitvote/sm_limitvote \x05<base> <increase>");
  ReplyToCommand(client, "\x04!limitvote/sm_limitvote \x05base <1-32> | increase <0.0-32.0>");
  ReplyToCommand(client, "\x04!limitvote/sm_limitvote \x05<class> <0-32>");
  ReplyToCommand(client, "\x05<class> \x01[ all | smoker | boomer | hunter | spitter | jockey | charger ]");
}

void ShowTimerVoteUsage(int client)
{
  ReplyToCommand(client, "[SS投票] timervote <constant> || timervote <min> <max>");
}

void StartLimitVote(int client, PendingLimitAction action, const char[] target, int limit, int baseLimit, float increase)
{
  if (!CanStartNativeVote(client))
    return;

  g_ePendingVoteType    = PendingVote_Limit;
  g_ePendingLimitAction = action;
  g_iPendingLimit       = limit;
  g_iPendingBaseLimit   = baseLimit;
  g_fPendingIncrease    = increase;
  strcopy(g_sPendingLimitTarget, sizeof g_sPendingLimitTarget, target);

  char title[128];
  if (action == PendingLimit_Reset)
    Format(title, sizeof title, "发起投票: 重置各类特感数量上限?");
  else if (action == PendingLimit_Base)
    Format(title, sizeof title, "投票: 基础特感数设为 %d?", baseLimit);
  else if (action == PendingLimit_Increase)
    Format(title, sizeof title, "投票: 每增加1名玩家, 特感增量 %.2f?", increase);
  else if (action == PendingLimit_Scale)
    Format(title, sizeof title, "投票: 基础%d特, 每多1人+%.2f特?", baseLimit, increase);
  else if (strcmp(target, "all") == 0)
    Format(title, sizeof title, "发起投票: 所有特感职业上限设为 %d?", limit);
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
    switch (g_ePendingLimitAction)
    {
      case PendingLimit_Reset:
        ServerCommand("sm_limit reset");
      case PendingLimit_Class:
        ServerCommand("sm_limit %s %d", g_sPendingLimitTarget, g_iPendingLimit);
      case PendingLimit_Base:
        ServerCommand("sm_limit base %d", g_iPendingBaseLimit);
      case PendingLimit_Increase:
        ServerCommand("sm_limit increase %f", g_fPendingIncrease);
      case PendingLimit_Scale:
        ServerCommand("sm_limit %d %f", g_iPendingBaseLimit, g_fPendingIncrease);
    }
  }

  ServerExecute();
}

void ResetPendingVote()
{
  g_ePendingVoteType       = PendingVote_None;
  g_ePendingLimitAction    = PendingLimit_None;
  g_sPendingLimitTarget[0] = '\0';
  g_iPendingLimit          = 0;
  g_iPendingBaseLimit      = 0;
  g_fPendingIncrease       = 0.0;
  g_fPendingTimerMin       = 0.0;
  g_fPendingTimerMax       = 0.0;
  g_bPendingTimerRange     = false;
}
