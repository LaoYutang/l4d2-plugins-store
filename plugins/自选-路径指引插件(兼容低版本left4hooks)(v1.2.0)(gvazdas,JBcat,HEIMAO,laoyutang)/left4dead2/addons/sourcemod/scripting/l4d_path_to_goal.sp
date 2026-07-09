#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define DEBUG              0
#define TEAM_SURVIVOR      2
#define VMT_LASERBEAM      "sprites/laserbeam.vmt"

#define GROUND_OFFSET      16.0
#define UNDERWATER_EXTRA   16.0
#define DEATH_OFFSET       48.0
#define WATERLEVEL_SHALLOW 1
#define WATERLEVEL_WAIST   2

#define PLUGIN_NAME        "l4d_path_to_goal"
#define PLUGIN_VERSION     "1.2.0"
#define PLUGIN_AUTHOR      "gvazdas,JBcat,HEIMAO,laoyutang"
#define PLUGIN_DESCRIPTION "基于导航网格的自动路径指引指示器（持续刷新版）"
#define PLUGIN_LINK        "https://github.com/gvazdas/l4d2_zombie_master"

ConVar
  g_hCvarEnable,
  g_hCvarMax,
  g_hCvarMPGameMode,
  g_hCvarContinuous;  // 新增：持续刷新开关

bool
  g_bEnable,
  g_bGuideReady,
  g_bMapStarted,
  g_bNavStarted,
  g_bGamemodeGuidable,
  g_bNoPath,
  g_bLastTabState[MAXPLAYERS + 1];
float
  g_fLastTabTime[MAXPLAYERS + 1];

int
  g_iLaserSprite,
  g_iMaxDraw;

ArrayList
  g_FlowCache,
  g_GuideCells;

PlayerCooldown
       g_PlayerCooldown[MAXPLAYERS + 1];

// 持续刷新定时器句柄
Handle g_hContinuousTimer[MAXPLAYERS + 1];
Handle g_hSDK_CNavArea_IsBlocked = null;

enum struct Cell
{
  float   flow;
  Address navArea;
  float   center[3];
}

enum struct PlayerCooldown
{
  float tGame;
  float duration;
}

public Plugin myinfo =
{
  name        = PLUGIN_NAME,
  version     = PLUGIN_VERSION,
  author      = PLUGIN_AUTHOR,
  description = PLUGIN_DESCRIPTION,
  url         = PLUGIN_LINK,
};

public void OnPluginStart()
{
  RegConsoleCmd("path_to_goal", CmdRequestGuide);
  RegConsoleCmd("pathtogoal", CmdRequestGuide);
  RegConsoleCmd("wheretogo", CmdRequestGuide);
  RegConsoleCmd("imlost", CmdRequestGuide);
  RegConsoleCmd("guide", CmdRequestGuide);
  RegConsoleCmd("ptg", CmdRequestGuide);
  RegAdminCmd("l4d_path_to_goal_recalculate", CmdRecalculate, ADMFLAG_ROOT);

  // 持续刷新命令
  RegConsoleCmd("gp_cont", CmdToggleContinuous);

  SetupNavAreaIsBlocked();

  g_hCvarEnable     = CreateConVar("l4d_path_to_goal_enable", "1", "1=开启 0=关闭", FCVAR_NOTIFY, true, 0.0, true, 1.0);
  g_hCvarMax        = CreateConVar("l4d_path_to_goal_max", "32", "最大绘制路径数", FCVAR_NOTIFY, true, 1.0, true, 1000.0);
  g_hCvarContinuous = CreateConVar("gp_continuous", "0", "持续刷新路径 (0=关闭 1=开启)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
  AutoExecConfig(true, PLUGIN_NAME);

  g_hCvarEnable.AddChangeHook(ConVarChanged_Cvars);
  g_hCvarMax.AddChangeHook(ConVarChanged_Cvars);
  g_hCvarContinuous.AddChangeHook(ConVarChanged_Cvars);
  g_hCvarMPGameMode = FindConVar("mp_gamemode");
  g_hCvarMPGameMode.AddChangeHook(ConVarGameMode);
  CheckGuidable();
  GetCvars();
  g_bNavStarted = true;
  HookEvent("round_start_post_nav", evtPostNav, EventHookMode_PostNoCopy);
}

void GetCvars()
{
  g_iMaxDraw     = GetConVarInt(g_hCvarMax);
  bool newEnable = GetConVarBool(g_hCvarEnable);
  if (g_bEnable != newEnable)
  {
    g_bEnable = newEnable;
    if (g_bEnable && !g_bGuideReady && !g_bNoPath)
      Guide_Prep();
    else if (!g_bEnable && g_bGuideReady)
      Guide_Cleanup();
  }
}

bool IsValidClient(int client, bool replayCheck = true)
{
  if (client < 1 || client > MaxClients)
    return false;
  if (!IsClientInGame(client))
    return false;
  if (replayCheck && (IsClientSourceTV(client) || IsClientReplay(client)))
    return false;
  return true;
}

bool PosUnderwater(const float pos[3])
{
  float top[3], bottom[3];
  bottom = pos;
  top    = pos;
  top[2] += 64.0;
  TR_TraceRay(top, bottom, MASK_WATER, RayType_EndPoint);
  return TR_DidHit();
}

bool TwoposVisible(float pos1[3], float pos2[3], bool worldOnly = true)
{
  if (worldOnly)
    TR_TraceRayFilter(pos1, pos2, MASK_SOLID, RayType_EndPoint, TraceFilterWorld);
  else
    TR_TraceRayFilter(pos1, pos2, MASK_SOLID, RayType_EndPoint, TraceFilterNoClients);
  return !TR_DidHit();
}

bool TraceFilterWorld(int entity, int mask)
{
  return entity == 0;
}

bool TraceFilterNoClients(int entity, int mask)
{
  return !IsValidClient(entity);
}

bool CellVisible(int idx, float pos[3], bool worldOnly = true)
{
  Cell cell;
  g_GuideCells.GetArray(idx, cell, sizeof(cell));
  return TwoposVisible(pos, cell.center, worldOnly);
}

void DrawBeam(int client, float start[3], float end[3], float duration, int color[4] = { 100, 200, 100, 100 })
{
  if (g_iLaserSprite == 0)
    return;
  TE_SetupBeamPoints(start, end, g_iLaserSprite, 0, 0, 0, duration, 1.0, 1.0, 1, 0.0, color, 0);
  TE_SendToClient(client);
}

bool IsCooldown(int client)
{
  if (g_PlayerCooldown[client].duration <= 0.0)
    return false;
  return (g_PlayerCooldown[client].tGame + g_PlayerCooldown[client].duration) > GetGameTime();
}

void SetCooldown(int client, float duration)
{
  if (duration <= 0.0)
    return;
  g_PlayerCooldown[client].tGame    = GetGameTime();
  g_PlayerCooldown[client].duration = duration;
}

void ResetCooldown(int client = -1)
{
  if (client > 0)
  {
    g_PlayerCooldown[client].tGame    = 0.0;
    g_PlayerCooldown[client].duration = 0.0;
    return;
  }
  for (int i = 1; i <= MaxClients; i++)
  {
    g_PlayerCooldown[i].tGame    = 0.0;
    g_PlayerCooldown[i].duration = 0.0;
  }
}

void CheckGuidable()
{
  g_bGamemodeGuidable = !L4D_IsSurvivalMode();
  if (g_bGamemodeGuidable && GetEngineVersion() == Engine_Left4Dead2)
    g_bGamemodeGuidable = !L4D2_IsScavengeMode();
  if (!g_bMapStarted || !g_bNavStarted)
    return;
  if (!g_bGuideReady && g_bGamemodeGuidable && g_bEnable && !g_bNoPath)
    Guide_Prep();
  else if (g_bGuideReady && !g_bGamemodeGuidable)
    Guide_Cleanup();
}

void SetupNavAreaIsBlocked()
{
  GameData hGameData = new GameData("l4d_path_to_goal");
  if (hGameData == null)
    SetFailState("Failed to load gamedata: l4d_path_to_goal.txt");

  StartPrepSDKCall(SDKCall_Raw);
  if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CNavArea::IsBlocked"))
  {
    delete hGameData;
    SetFailState("Failed to find signature: CNavArea::IsBlocked");
  }

  PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
  PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
  PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);

  g_hSDK_CNavArea_IsBlocked = EndPrepSDKCall();
  delete hGameData;

  if (g_hSDK_CNavArea_IsBlocked == null)
    SetFailState("Failed to create SDKCall: CNavArea::IsBlocked");
}

bool PTG_NavArea_IsBlocked(Address area, int team, bool affectsFlow)
{
  if (area == Address_Null)
    return true;
  if (g_hSDK_CNavArea_IsBlocked == null)
    SetFailState("SDKCall unavailable: CNavArea::IsBlocked");
  return view_as<bool>(SDKCall(g_hSDK_CNavArea_IsBlocked, area, team, affectsFlow));
}

int SortFlow(int idx1, int idx2, Handle array, Handle hndl)
{
  float f1 = view_as<ArrayList>(array).Get(idx1, 0);
  float f2 = view_as<ArrayList>(array).Get(idx2, 0);
  if (f1 > f2) return 1;
  if (f1 < f2) return -1;
  return 0;
}

bool CollectCells(ArrayList allCells, float maxFlow)
{
  ArrayList allAreas = new ArrayList();
  L4D_GetAllNavAreas(allAreas);
  if (allAreas.Length <= 1)
  {
    delete allAreas;
    return false;
  }

  float pos[3];
  Cell  cell;
  for (int i = 0; i < allAreas.Length; i++)
  {
    Address nav = allAreas.Get(i);
    if (!nav)
      continue;
    if (!(L4D_GetNavArea_SpawnAttributes(nav) & NAV_SPAWN_ESCAPE_ROUTE))
      continue;
    if (PTG_NavArea_IsBlocked(nav, TEAM_SURVIVOR, true) || PTG_NavArea_IsBlocked(nav, TEAM_SURVIVOR, false))
      continue;
    float flow = L4D2Direct_GetTerrorNavAreaFlow(nav);
    if (flow < 0.0 || flow > maxFlow)
      continue;
    bool dup = false;
    for (int j = 0; j < allCells.Length; j++)
    {
      Cell tempCell;
      allCells.GetArray(j, tempCell, sizeof(tempCell));
      if (FloatAbs(tempCell.flow - flow) <= 0.001)
      {
        dup = true;
        break;
      }
    }
    if (dup)
      continue;
    L4D_GetNavAreaCenter(nav, pos);
    pos[2] += GROUND_OFFSET;
    if (PosUnderwater(pos))
    {
      pos[2] += UNDERWATER_EXTRA;
      if (PosUnderwater(pos))
      {
        pos[2] += UNDERWATER_EXTRA;
        if (PosUnderwater(pos))
          continue;
      }
    }
    cell.navArea = nav;
    cell.center  = pos;
    cell.flow    = flow;
    allCells.PushArray(cell);
  }
  delete allAreas;
  return (allCells.Length > 1);
}

void MergeCells(ArrayList src, ArrayList dst)
{
  src.SortCustom(SortFlow);
  Cell cell;
  src.GetArray(0, cell, sizeof(cell));
  dst.PushArray(cell);
  for (int i = 1; i < src.Length; i++)
  {
    src.GetArray(i, cell, sizeof(cell));
    Cell prev;
    dst.GetArray(dst.Length - 1, prev, sizeof(prev));
    if (TwoposVisible(cell.center, prev.center))
      dst.PushArray(cell);
    else
    {
      Cell mid;
      mid.flow    = (prev.flow + cell.flow) * 0.5;
      mid.navArea = prev.navArea;
      for (int k = 0; k < 3; k++)
        mid.center[k] = (prev.center[k] + cell.center[k]) * 0.5;
      dst.PushArray(mid);
      dst.PushArray(cell);
    }
  }
}

void OptimizeCells(ArrayList cells)
{
  if (cells.Length <= 2)
    return;
  int i = 1;
  while (i < cells.Length - 1)
  {
    Cell prev, cur, next;
    cells.GetArray(i - 1, prev, sizeof(prev));
    cells.GetArray(i, cur, sizeof(cur));
    cells.GetArray(i + 1, next, sizeof(next));
    if (TwoposVisible(prev.center, cur.center) && TwoposVisible(prev.center, next.center) && TwoposVisible(cur.center, next.center))
    {
      cells.Erase(i);
      continue;
    }
    i++;
  }
}

void BuildFlowCache()
{
  delete g_FlowCache;
  if (g_GuideCells == null)
    return;
  g_FlowCache = new ArrayList();
  Cell cell;
  for (int i = 0; i < g_GuideCells.Length; i++)
  {
    g_GuideCells.GetArray(i, cell, sizeof(cell));
    g_FlowCache.Push(cell.flow);
  }
}

void Guide_Prep()
{
  if (!g_bEnable || !g_bGamemodeGuidable || !g_bMapStarted || !g_bNavStarted)
    return;
  if (g_bGuideReady || g_bNoPath)
    return;
#if DEBUG
  float t = GetEngineTime();
#endif
  float maxFlow = L4D2Direct_GetMapMaxFlowDistance();
  if (maxFlow <= 0.0)
    return;
  ArrayList rawCells = new ArrayList(sizeof(Cell));
  if (!CollectCells(rawCells, maxFlow))
  {
    delete rawCells;
    g_bNoPath = true;
    return;
  }
  ArrayList merged = new ArrayList(sizeof(Cell));
  MergeCells(rawCells, merged);
  delete rawCells;
  OptimizeCells(merged);
  delete g_GuideCells;
  g_GuideCells = merged;
  BuildFlowCache();
  g_bGuideReady = true;
  g_bNoPath     = (g_GuideCells.Length <= 1);
  if (g_bNoPath)
    Guide_Cleanup();
  ResetCooldown();
#if DEBUG
  LogMessage("Guide_Prep: cells=%d time=%.2fms", g_GuideCells.Length, (GetEngineTime() - t) * 1000.0);
#endif
}

void Guide_Cleanup()
{
  delete g_GuideCells;
  delete g_FlowCache;
  g_bGuideReady = false;
  g_bNoPath     = false;
}

int FindStartIndex(float playerFlow, const float playerPos[3])
{
  if (g_GuideCells == null)
    return -1;
  if (playerFlow > 0.0 && g_FlowCache != null)
  {
    int low = 0, high = g_GuideCells.Length - 1;
    while (low <= high)
    {
      int   mid     = (low + high) / 2;
      float flowMid = g_FlowCache.Get(mid);
      if (flowMid < playerFlow)
        low = mid + 1;
      else if (flowMid > playerFlow)
        high = mid - 1;
      else
        return mid;
    }
    if (low < g_GuideCells.Length)
      return low;
    return g_GuideCells.Length - 1;
  }
  int   best     = 0;
  float bestDist = -1.0;
  Cell  cell;
  for (int i = 0; i < g_GuideCells.Length; i++)
  {
    g_GuideCells.GetArray(i, cell, sizeof(cell));
    float dist = GetVectorDistance(playerPos, cell.center, true);
    if (bestDist < 0.0 || dist < bestDist)
    {
      bestDist = dist;
      best     = i;
    }
  }
  return best;
}

void RequestGuide(int client, float duration = 5.0, bool backward = false, bool joinClient = true, bool ignoreCooldown = false)
{
  if (!g_bEnable || !g_bGamemodeGuidable || duration <= 0.0 || g_iLaserSprite == 0)
    return;
  if (!IsValidClient(client) || IsFakeClient(client))
    return;
  if (!g_bGuideReady)
  {
    if (g_bNoPath)
      return;
    Guide_Prep();
    if (!g_bGuideReady)
      return;
  }
  if (!ignoreCooldown && IsCooldown(client))
    return;
  float eyePos[3], startPos[3];
  GetClientEyePosition(client, eyePos);
  float flow = 0.0;
  if (IsPlayerAlive(client))
  {
    flow = L4D2Direct_GetFlowDistance(client);
    GetClientAbsOrigin(client, startPos);
    startPos[2] += GROUND_OFFSET;
    int water = GetEntProp(client, Prop_Send, "m_nWaterLevel");
    if (water == WATERLEVEL_SHALLOW)
      startPos[2] += UNDERWATER_EXTRA;
    else if (water == WATERLEVEL_WAIST)
      startPos[2] += UNDERWATER_EXTRA * 2;
  }
  else
  {
    startPos = eyePos;
    startPos[2] -= DEATH_OFFSET;
    if (PosUnderwater(startPos))
      startPos[2] += UNDERWATER_EXTRA * 2;
  }
  int idx = FindStartIndex(flow, startPos);
  if (idx < 0 || idx >= g_GuideCells.Length)
    return;
  if (joinClient)
  {
    if (idx + 1 < g_GuideCells.Length && CellVisible(idx + 1, startPos))
      idx++;
    else if (idx > 0 && !CellVisible(idx, startPos) && CellVisible(idx - 1, startPos))
      idx--;
  }
  Cell cur;
  g_GuideCells.GetArray(idx, cur, sizeof(cur));
  int drawn = 0;
  if (joinClient)
  {
    DrawBeam(client, startPos, cur.center, duration);
    drawn++;
  }
  int   forwardIdx = idx, backIdx = idx;
  float forwardPos[3], backPos[3];
  forwardPos = cur.center;
  backPos    = cur.center;
  bool stop  = false;
  while (!stop)
  {
    stop = true;
    if (forwardIdx + 1 < g_GuideCells.Length)
    {
      forwardIdx++;
      g_GuideCells.GetArray(forwardIdx, cur, sizeof(cur));
      DrawBeam(client, forwardPos, cur.center, duration);
      forwardPos = cur.center;
      stop       = false;
      drawn++;
      if (drawn >= g_iMaxDraw)
        break;
    }
    if (backward && backIdx > 0)
    {
      backIdx--;
      g_GuideCells.GetArray(backIdx, cur, sizeof(cur));
      int red[4] = { 200, 100, 100, 100 };
      DrawBeam(client, backPos, cur.center, duration, red);
      backPos = cur.center;
      stop    = false;
      drawn++;
      if (drawn >= g_iMaxDraw)
        break;
    }
  }
  if (drawn > 0 && !ignoreCooldown)
    SetCooldown(client, duration);
}

// 持续刷新定时器回调
Action Timer_ContinuousRefresh(Handle timer, int userid)
{
  int client = GetClientOfUserId(userid);
  if (client <= 0 || !IsClientInGame(client))
  {
    g_hContinuousTimer[client] = null;
    return Plugin_Stop;
  }
  if (!g_bEnable || !g_bGuideReady)
  {
    return Plugin_Continue;
  }
  // 忽略冷却，直接绘制，持续时间设为1.5秒
  RequestGuide(client, 1.5, false, true, true);
  return Plugin_Continue;
}

void StartContinuous(int client)
{
  if (g_hContinuousTimer[client] != null)
    return;
  // 每1.0秒刷新一次，光束持续1.5秒，无缝衔接
  g_hContinuousTimer[client] = CreateTimer(1.0, Timer_ContinuousRefresh, GetClientUserId(client), TIMER_REPEAT);
  ReplyToCommand(client, "[GP] 持续路径刷新已开启");
}

void StopContinuous(int client)
{
  if (g_hContinuousTimer[client] != null)
  {
    KillTimer(g_hContinuousTimer[client]);
    g_hContinuousTimer[client] = null;
  }
  ReplyToCommand(client, "[GP] 持续路径刷新已关闭");
}

public Action CmdToggleContinuous(int client, int args)
{
  if (!IsValidClient(client))
    return Plugin_Handled;
  if (g_hContinuousTimer[client] != null)
    StopContinuous(client);
  else
    StartContinuous(client);
  return Plugin_Handled;
}

void ConVarChanged_Cvars(ConVar convar, const char[] oldVal, const char[] newVal)
{
  GetCvars();
}

void evtPostNav(Event event, const char[] name, bool dontBroadcast)
{
  g_bNavStarted = true;
  Guide_Prep();
}

void ConVarGameMode(ConVar convar, const char[] oldVal, const char[] newVal)
{
  RequestFrame(CheckGuidable);
}

Action CmdRequestGuide(int client, int args)
{
  if (!g_bEnable || !g_bMapStarted || !g_bGamemodeGuidable)
    return Plugin_Continue;
  float duration = 5.0;
  bool  backward = (GetClientTeam(client) != TEAM_SURVIVOR);
  if (args > 0)
  {
    char arg[16];
    GetCmdArg(1, arg, sizeof(arg));
    if (StringToFloatEx(arg, duration) == 0)
    {
      if (strcmp(arg, "backward") == 0)
        backward = true;
    }
    if (args > 1)
    {
      GetCmdArg(2, arg, sizeof(arg));
      float f;
      if (StringToFloatEx(arg, f) != 0)
        duration = f;
      else if (strcmp(arg, "backward") == 0)
        backward = true;
    }
  }
  RequestGuide(client, duration, backward);
  return Plugin_Continue;
}

Action CmdRecalculate(int client, int args)
{
  if (!g_bEnable || !g_bMapStarted || !g_bNavStarted || !g_bGamemodeGuidable)
    return Plugin_Continue;
  Guide_Cleanup();
  Guide_Prep();
  return Plugin_Continue;
}

public void OnMapStart()
{
  g_iLaserSprite = PrecacheModel(VMT_LASERBEAM, true);
  RequestFrame(MapStarted);
}

void MapStarted()
{
  g_bMapStarted = true;
  if (g_bNavStarted && !g_bGuideReady && g_bEnable && !g_bNoPath)
    Guide_Prep();
}

public void OnMapEnd()
{
  g_bMapStarted = false;
  g_bNavStarted = false;
  // 清理所有持续刷新定时器
  for (int i = 1; i <= MaxClients; i++)
  {
    if (g_hContinuousTimer[i] != null)
    {
      KillTimer(g_hContinuousTimer[i]);
      g_hContinuousTimer[i] = null;
    }
  }
  Guide_Cleanup();
}

public void OnPluginEnd()
{
  Guide_Cleanup();
}

public void OnClientPutInServer(int client)
{
  if (!IsValidClient(client) || IsFakeClient(client))
    return;
  ResetCooldown(client);
  g_bLastTabState[client] = false;
  g_fLastTabTime[client]  = 0.0;
  StopContinuous(client);
}

public void OnClientDisconnect(int client)
{
  ResetCooldown(client);
  g_bLastTabState[client] = false;
  g_fLastTabTime[client]  = 0.0;
  StopContinuous(client);
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
  if (!g_bEnable || !g_bMapStarted || !g_bGamemodeGuidable)
    return;
  if (!IsValidClient(client) || IsFakeClient(client))
    return;
  bool nowTab = (buttons & IN_SCORE) != 0;
  if (nowTab && !g_bLastTabState[client])
  {
    g_fLastTabTime[client] = GetGameTime();
  }
  else if (nowTab && g_bLastTabState[client] && g_fLastTabTime[client] > 0.0 && !IsCooldown(client))
  {
    float currentTime = GetGameTime();
    if (currentTime - g_fLastTabTime[client] >= 1.0)
    {
      RequestGuide(client, 5.0, false, true);
      g_fLastTabTime[client] = 0.0;
    }
  }
  else if (!nowTab && g_bLastTabState[client])
  {
    g_fLastTabTime[client] = 0.0;
  }
  g_bLastTabState[client] = nowTab;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
  CreateNative("L4D_Path_To_Goal", Native_RequestGuide);
  return APLRes_Success;
}

int Native_RequestGuide(Handle plugin, int numParams)
{
  if (!g_bEnable)
    return 0;
  int   client   = (numParams > 0) ? GetNativeCell(1) : -1;
  float duration = (numParams > 1) ? view_as<float>(GetNativeCell(2)) : 5.0;
  bool  backward = (numParams > 2) ? view_as<bool>(GetNativeCell(3)) : false;
  bool  join     = (numParams > 3) ? view_as<bool>(GetNativeCell(4)) : true;
  if (client != -1 && (!IsValidClient(client) || IsFakeClient(client)))
    return 0;
  if (duration <= 0.0)
    return 0;
  RequestGuide(client, duration, backward, join);
  return 0;
}
