#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <dhooks>
#include <left4dhooks>
#include <l4d2_ems_hud>

// ============================================================================
// 插件信息
// ============================================================================
#define PLUGIN_VERSION "1.0.1"

public Plugin myinfo =
{
  name        = "lyt_ems_hud",
  author      = "豆瓣酱な, Miuwiki, Harry, laoyutang, 十裡冬",
  description = "EMS HUD - 信息面板 + 排行榜 + 击杀列表",
  version     = PLUGIN_VERSION,
  url         = "N/A"


}

// ============================================================================
// 常量定义
// ============================================================================

// 排行榜最大显示行数 (不含标题)
#define RANKING_MAX_ROWS 15
#define RANKING_HUD_Y        0.085
#define RANKING_ROW_HEIGHT   0.021

// 击杀列表相关
#define KILL_HUD_BASE    9    // 击杀列表起始槽位 (HUD_MID_BOX)
#define KILL_INFO_MAX    6    // 击杀列表最大显示条数
#define KILL_FADE_TIME   7.0  // 击杀信息消退时间(秒)

// 击杀列表HUD位置
#define KILL_HUD_X       0.60
#define KILL_HUD_Y       0.09
#define KILL_HUD_WIDTH   0.39
#define KILL_HUD_HEIGHT  0.04

// 对抗模式列表
static const char g_sModeVersus[][] = { "versus", "teamversus", "scavenge", "teamscavenge", "community3", "community6", "mutation11", "mutation12", "mutation13", "mutation15", "mutation18", "mutation19" };

// 单人模式列表
static const char g_sModeSingle[][] = {
  "mutation1", "mutation17"
};

// 难度名称
static const char g_sDifficultyName[][] = { "简单", "普通", "高级", "专家" };
static const char g_sDifficultyCode[][] = { "Easy", "Normal", "Hard", "Impossible" };

// 星期名称
static const char g_sWeekName[][]       = { "一", "二", "三", "四", "五", "六", "日" };

// 排行榜列标题 (特感、丧尸、友伤、名字)
static const char g_sRankTitle[][]      = { "特感", "丧尸", "友伤", "名字" };

// 排行榜列对应的HUD槽位 (前3列为数字列, 最后为名字列)
static const int  g_iRankSlots[]        = { HUD_LEFT_BOT, HUD_MID_TOP, HUD_MID_BOT, HUD_RIGHT_TOP };

// 名字列溢出时使用的第二个槽位
#define HUD_NAME_EXTRA HUD_FAR_RIGHT

// 排行榜各列X坐标
static const float g_fRankCoord[]  = { 0.00, 0.055, 0.110, 0.160 };

// ============================================================================
// 击杀图标
// ============================================================================
static const char  g_sKillType[][] = {
  "■■‖:::::::>",    // 0  近战
  "/̵͇̿̿/'̿'̿ ̿ ̿̿ ̿̿ ̿̿",       // 1  手枪
  "⌐╤═─",           // 2  冲锋枪
  "︻╦╦═─",         // 3  步枪
  "▄︻═══∶∷",       // 4  霰弹枪
  "︻╦̵̵͇̿̿̿̿╤───",        // 5  狙击枪
  "☆BOMB☆",         // 6  爆炸物
  "__∫∫∫∫__",       // 7  火焰
  "▄︻╤■══一",      // 8  M60
  "︻■■■■ ●",       // 9  榴弹发射器
  "(●｀・ω・)=Ｏ",  // 10 推/铲
  "↼■╦══",          // 11 固定机枪
  "X_X",            // 12 世界/地图伤害
  "*皿*彡",         // 13 被特感击杀
  "→‖",             // 14 穿墙
  "→⊙",             // 15 爆头
  "(°ω°)彡",        // 16 被女巫击杀
  "☠",              // 17 被普通感染者击杀
  "<ʖ͡=::::::⊃",     // 18 电锯
  "v X_X",          // 19 坠落死亡
  "SYSTEM X_X",     // 20 系统处死
  "→☠"              // 21 未知武器
};

// ============================================================================
// 全局变量
// ============================================================================

// 地图与回合状态
bool      g_bMapRunTime;        // 地图是否已运行
bool      g_bShowHUD;           // 回合结束标记(结束后不显示排行榜)
bool      g_bSwitchHud = true;  // HUD总开关

// 玩家数据
int       g_iKillSpecial[MAXPLAYERS + 1];  // 击杀特感数
int       g_iKillZombie[MAXPLAYERS + 1];   // 击杀普通感染者数
int       g_iDmgFriendly[MAXPLAYERS + 1];  // 友伤输出

// 统计
int       g_iPlayerNum;  // 当前连接的真人玩家数

// 章节信息(由定时器每秒更新)
int       g_iMaxChapters;
int       g_iCurrentChapter;
float     g_fMapMaxFlow;

// HUD定时器
Handle    g_hTimerHUD;

// ============================================================================
// 击杀列表相关变量
// ============================================================================
ArrayList g_hKillInfoList;        // 击杀信息ArrayList
Handle    g_hKillFadeTimer;       // 击杀信息消退定时器
StringMap g_smWeaponName;         // 武器名称->图标映射
StringMap g_smSpecialWeapons;     // 不需要穿墙/爆头提示的武器
StringMap g_smIgnoreWallWeapons;  // 不需要穿墙检测的武器

// ============================================================================
// DHooks
// ============================================================================

/**
 * 加载gamedata并挂钩HibernationUpdate
 */
void      LoadGameCFG()
{
  GameData hGameData = new GameData("l4d2_emshud_info");
  if (!hGameData)
    SetFailState("无法加载 'l4d2_emshud_info.txt' gamedata.");

  DHookSetup hDetour = DHookCreateFromConf(hGameData, "HibernationUpdate");
  CloseHandle(hGameData);

  if (!hDetour || !DHookEnableDetour(hDetour, true, OnHibernationUpdate))
    SetFailState("无法挂钩 HibernationUpdate");
}

/**
 * 服务器进入休眠状态时重置标记
 */
public MRESReturn OnHibernationUpdate(DHookParam hParams)
{
  if (!DHookGetParam(hParams, 1))
    return MRES_Ignored;

  g_bMapRunTime = false;
  return MRES_Handled;
}

// ============================================================================
// 插件生命周期
// ============================================================================
public void OnPluginStart()
{
  LoadGameCFG();

  // 注册事件
  HookEvent("round_start", Event_RoundStart);
  HookEvent("round_end", Event_RoundEnd);
  HookEvent("player_hurt", Event_PlayerHurt);
  HookEvent("player_death", Event_PlayerDeath);
  HookEvent("player_death", Event_PlayerDeathKillList_Pre, EventHookMode_Pre);
  HookEvent("player_death", Event_PlayerDeathKillList_Post);

  // 管理员指令：开关HUD
  RegConsoleCmd("sm_hud", Command_SwitchHud, "开启或关闭所有HUD");

  // 初始化击杀列表
  g_hKillInfoList = new ArrayList(ByteCountToCells(128));
  InitWeaponNameMap();
}

public void OnMapStart()
{
  EnableHUD();
  g_iPlayerNum = 0;

  // 重置击杀列表
  delete g_hKillInfoList;
  g_hKillInfoList = new ArrayList(ByteCountToCells(128));
  delete g_hKillFadeTimer;
}

public void OnMapEnd()
{
  delete g_hKillInfoList;
  g_hKillInfoList = new ArrayList(ByteCountToCells(128));
  delete g_hKillFadeTimer;
}

public void OnConfigsExecuted()
{
  if (!g_bMapRunTime)
    g_bMapRunTime = true;
}

public void OnClientConnected(int client)
{
  g_iKillSpecial[client] = 0;
  g_iKillZombie[client]  = 0;
  g_iDmgFriendly[client] = 0;

  if (!IsFakeClient(client))
    g_iPlayerNum++;
}

public void OnClientDisconnect(int client)
{
  g_iKillSpecial[client] = 0;
  g_iKillZombie[client]  = 0;
  g_iDmgFriendly[client] = 0;

  if (!IsFakeClient(client))
    g_iPlayerNum--;
}

// ============================================================================
// 回合事件
// ============================================================================

/**
 * 回合开始：重置数据并创建HUD定时器
 */
public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
  g_bShowHUD = false;

  // 重置玩家数据
  for (int i = 1; i <= MaxClients; i++)
  {
    g_iKillSpecial[i] = 0;
    g_iKillZombie[i]  = 0;
    g_iDmgFriendly[i] = 0;
  }

  // 重置击杀列表HUD
  for (int slot = KILL_HUD_BASE; slot < MAX_SIZE_HUD; slot++)
    RemoveHUD(slot);

  delete g_hKillInfoList;
  g_hKillInfoList = new ArrayList(ByteCountToCells(128));
  delete g_hKillFadeTimer;

  // 创建1秒定时器刷新HUD
  CreateTimerIfNeeded();
}

/**
 * 回合结束：标记并清理排行榜
 */
public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
  g_bShowHUD = true;
  RemoveRankingHUD();
}

// ============================================================================
// 玩家数据收集事件
// ============================================================================

/**
 * 玩家受伤事件：记录友伤
 */
public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
  int client   = GetClientOfUserId(event.GetInt("userid"));
  int attacker = GetClientOfUserId(event.GetInt("attacker"));
  int iDmg     = event.GetInt("dmg_health");

  if (!IsValidClient(client) || GetClientTeam(client) != 2)
    return;
  if (!IsValidClient(attacker) || GetClientTeam(attacker) != 2)
    return;

  // 友伤：攻击者是生还者攻击了另一个生还者
  int realAttacker = GetRealPlayer(attacker);
  g_iDmgFriendly[realAttacker] += iDmg;
}

/**
 * 玩家死亡事件：记录击杀特感/丧尸
 */
public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
  int client   = GetClientOfUserId(event.GetInt("userid"));
  int attacker = GetClientOfUserId(event.GetInt("attacker"));

  if (!IsValidClient(attacker) || GetClientTeam(attacker) != 2)
    return;

  int  realAttacker = GetRealPlayer(attacker);

  // 检查是否击杀了普通感染者
  char classname[32];
  int  entity = GetEventInt(event, "entityid");
  if (IsValidEdict(entity))
  {
    GetEdictClassname(entity, classname, sizeof(classname));
    if (strcmp(classname, "infected") == 0)
    {
      g_iKillZombie[realAttacker]++;
      return;
    }
  }

  // 检查是否击杀了特感
  if (IsValidClient(client) && GetClientTeam(client) == 3)
    g_iKillSpecial[realAttacker]++;
}

// ============================================================================
// 击杀列表事件 (来自cs_kill_hud)
// ============================================================================

/**
 * 死亡事件前钩：阻止原版击杀信息红字
 */
public void Event_PlayerDeathKillList_Pre(Event event, const char[] name, bool dontBroadcast)
{
  event.BroadcastDisabled = true;
}

/**
 * 死亡事件后钩：构建击杀信息文本并加入列表
 */
public void Event_PlayerDeathKillList_Post(Event event, const char[] name, bool dontBroadcast)
{
  int  victim            = GetClientOfUserId(event.GetInt("userid"));
  bool bIsVictimPlayer   = IsValidClient(victim);

  int  attacker          = GetClientOfUserId(event.GetInt("attacker"));
  bool bIsAttackerPlayer = IsValidClient(attacker);

  int  entityid          = event.GetInt("entityid");
  bool headshot          = event.GetBool("headshot");
  int  damagetype        = event.GetInt("type");

  // 获取受害者名称
  char victim_name[64];
  if (bIsVictimPlayer)
  {
    FormatBotName(victim, victim_name, sizeof(victim_name));
  }
  else
  {
    if (IsWitch(entityid))
      strcopy(victim_name, sizeof(victim_name), "Witch");
    else
      return;
  }

  char killinfo[128];

  // 非玩家攻击者（世界、女巫、普感等）击杀玩家
  if (!bIsAttackerPlayer)
  {
    if (!bIsVictimPlayer)
      return;

    int attackid = event.GetInt("attackerentid");
    if (IsWitch(attackid))
      FormatEx(killinfo, sizeof(killinfo), "    %s  %s", g_sKillType[16], victim_name);
    else if (IsCommonInfected(attackid))
      FormatEx(killinfo, sizeof(killinfo), "    %s  %s", g_sKillType[17], victim_name);
    else if (damagetype & DMG_BURN)
      FormatEx(killinfo, sizeof(killinfo), "    %s  %s", g_sKillType[7], victim_name);
    else if (damagetype & DMG_FALL)
      FormatEx(killinfo, sizeof(killinfo), "    %s  %s", g_sKillType[19], victim_name);
    else if (damagetype & DMG_BLAST)
      FormatEx(killinfo, sizeof(killinfo), "    %s  %s", g_sKillType[6], victim_name);
    else
      FormatEx(killinfo, sizeof(killinfo), "    %s  %s", g_sKillType[12], victim_name);

    PushKillInfo(killinfo);
    return;
  }

  int victimTeam   = bIsVictimPlayer ? GetClientTeam(victim) : 0;
  int attackerTeam = bIsAttackerPlayer ? GetClientTeam(attacker) : 0;

  // 自杀判断
  if (bIsAttackerPlayer && bIsVictimPlayer && attacker == victim)
  {
    if (victimTeam == 2 || victimTeam == 3)
    {
      if (damagetype == (DMG_PREVENT_PHYSICS_FORCE + DMG_NEVERGIB))
      {
        FormatEx(killinfo, sizeof(killinfo), "    %s  %s", g_sKillType[20], victim_name);
        PushKillInfo(killinfo);
        return;
      }
      // 特感坠落自杀
      if (victimTeam == 3 && (damagetype & DMG_FALL))
      {
        FormatEx(killinfo, sizeof(killinfo), "    %s  %s", g_sKillType[19], victim_name);
        PushKillInfo(killinfo);
        return;
      }
    }
  }

  // 特感击杀人类 或 特感击杀特感
  if (bIsAttackerPlayer && attackerTeam == 3 && bIsVictimPlayer)
  {
    char attacker_name[64];
    FormatBotName(attacker, attacker_name, sizeof(attacker_name));
    FormatEx(killinfo, sizeof(killinfo), "%s  %s  %s", attacker_name, g_sKillType[13], victim_name);
    PushKillInfo(killinfo);
    return;
  }

  // 世界/地图伤害击杀
  char sWeapon[64];
  event.GetString("weapon", sWeapon, sizeof(sWeapon));

  if (strncmp(sWeapon, "world", 5, false) == 0 || strncmp(sWeapon, "trigger_hurt", 12, false) == 0)
  {
    FormatEx(killinfo, sizeof(killinfo), "    %s  %s", g_sKillType[12], victim_name);
    PushKillInfo(killinfo);
    return;
  }

  if (!bIsAttackerPlayer)
    return;

  // 获取武器图标
  char sWeaponIcon[64];
  if (!g_smWeaponName.GetString(sWeapon, sWeaponIcon, sizeof(sWeaponIcon)))
    FormatEx(sWeaponIcon, sizeof(sWeaponIcon), "%s", g_sKillType[21]);

  // 不需要穿墙和爆头提示的特殊武器
  if (g_smSpecialWeapons.ContainsKey(sWeaponIcon))
  {
    FormatEx(killinfo, sizeof(killinfo), "%N  %s  %s", attacker, sWeaponIcon, victim_name);
  }
  else
  {
    bool behindWall = false;
    if (!g_smIgnoreWallWeapons.ContainsKey(sWeaponIcon))
    {
      if (bIsVictimPlayer)
        behindWall = IsPlayerKilledBehindWall(attacker, victim);
      else
        behindWall = IsEntityKilledBehindWall(attacker, entityid);
    }

    if (headshot && behindWall)
      FormatEx(killinfo, sizeof(killinfo), "%N  %s %s %s  %s", attacker, g_sKillType[14], g_sKillType[15], sWeaponIcon, victim_name);
    else if (headshot)
      FormatEx(killinfo, sizeof(killinfo), "%N  %s %s  %s", attacker, g_sKillType[15], sWeaponIcon, victim_name);
    else if (behindWall)
      FormatEx(killinfo, sizeof(killinfo), "%N  %s %s  %s", attacker, g_sKillType[14], sWeaponIcon, victim_name);
    else
      FormatEx(killinfo, sizeof(killinfo), "%N  %s  %s", attacker, sWeaponIcon, victim_name);
  }

  PushKillInfo(killinfo);
}

// ============================================================================
// 指令处理
// ============================================================================

/**
 * 管理员开关HUD指令
 */
public Action Command_SwitchHud(int client, int args)
{
  if (!IsAdminClient(client))
  {
    ReplyToCommand(client, "\x04[提示]\x05你无权使用该指令.");
    return Plugin_Handled;
  }

  if (g_bSwitchHud)
  {
    g_bSwitchHud = false;
    delete g_hTimerHUD;
    RequestFrame(OnFrameRemoveAllHUD);
    ReplyToCommand(client, "\x04[提示]\x03已关闭\x05所有\x04HUD\x05显示.");
  }
  else
  {
    g_bSwitchHud = true;
    delete g_hTimerHUD;
    g_hTimerHUD = CreateTimer(1.0, Timer_RefreshHUD, _, TIMER_REPEAT);
    ReplyToCommand(client, "\x04[提示]\x03已开启\x05所有\x04HUD\x05显示.");
  }

  return Plugin_Handled;
}

// ============================================================================
// HUD 定时器
// ============================================================================

/**
 * 如果定时器不存在则创建
 */
void CreateTimerIfNeeded()
{
  if (g_hTimerHUD == null)
    g_hTimerHUD = CreateTimer(1.0, Timer_RefreshHUD, _, TIMER_REPEAT);
}

/**
 * 每秒执行：刷新所有HUD内容
 */
public Action Timer_RefreshHUD(Handle timer)
{
  // 更新全局数据
  g_iMaxChapters    = L4D_GetMaxChapters();
  g_iCurrentChapter = L4D_GetCurrentChapter();
  g_fMapMaxFlow     = L4D2Direct_GetMapMaxFlowDistance();

  if (!g_bSwitchHud)
    return Plugin_Continue;

  // 先清除再重绘
  RemoveInfoHUD();
  RemoveRankingHUD();

  // 显示各模块
  ShowInfoHUD();
  ShowTimeHUD();
  ShowRankingHUD();

  return Plugin_Continue;
}

/**
 * 延迟一帧清除所有HUD
 */
void OnFrameRemoveAllHUD()
{
  RemoveInfoHUD();
  RemoveRankingHUD();
  RemoveKillListHUD();
}

// ============================================================================
// 模块1：左上信息栏 (HUD_LEFT_TOP)
// 格式: [玩家数/最大数][章节/总章节][路程%][难度]
// ============================================================================

/**
 * 显示左上角服务器信息
 */
void ShowInfoHUD()
{
  int  iPlayers     = g_iPlayerNum;
  int  iMaxPlayers  = GetMaxPlayers();
  int  iChapter     = g_iCurrentChapter;
  int  iMaxChapters = g_iMaxChapters;
  int  iDistance    = GetGameDistance();
  char sDifficulty[16];
  GetGameDifficultyName(sDifficulty, sizeof(sDifficulty));

  char sInfo[128];
  FormatEx(sInfo, sizeof(sInfo), "玩家:[%d/%d]地图:[%d/%d]路程:[%d%%]难度:[%s]",
           iPlayers, iPlayers > iMaxPlayers ? iPlayers : iMaxPlayers,
           iChapter, iMaxChapters,
           iDistance,
           sDifficulty);

  HUDSetLayoutSafe(HUD_LEFT_TOP, HUD_FLAG_ALIGN_LEFT | HUD_FLAG_NOBG | HUD_FLAG_TEXT, sInfo);
  HUDPlace(HUD_LEFT_TOP, 0.00, 0.00, 0.50, 0.03);
}

/**
 * 清除信息栏HUD
 */
void RemoveInfoHUD()
{
  if (HUDSlotIsUsed(HUD_LEFT_TOP))
    RemoveHUD(HUD_LEFT_TOP);
  if (HUDSlotIsUsed(HUD_RIGHT_BOT))
    RemoveHUD(HUD_RIGHT_BOT);
}

// ============================================================================
// 模块2：右上时间显示 (HUD_RIGHT_BOT)
// ============================================================================

/**
 * 显示服务器时间
 */
void ShowTimeHUD()
{
  char sDate[32], sTime[32], sWeek[16], sInfo[128];
  FormatTime(sDate, sizeof(sDate), "%Y-%m-%d");
  FormatTime(sTime, sizeof(sTime), "%H:%M:%S");
  FormatEx(sWeek, sizeof(sWeek), "星期%s", GetWeekName());
  FormatEx(sInfo, sizeof(sInfo), "%s %s %s   ", sDate, sTime, sWeek);

  HUDSetLayoutSafe(HUD_RIGHT_BOT, HUD_FLAG_ALIGN_RIGHT | HUD_FLAG_NOBG | HUD_FLAG_TEXT, sInfo);
  HUDPlace(HUD_RIGHT_BOT, 0.00, 0.00, 1.0, 0.03);
}

// ============================================================================
// 模块3：排行榜 (HUD_LEFT_BOT, HUD_MID_TOP, HUD_MID_BOT, HUD_RIGHT_TOP)
// 保留列：特感、丧尸、友伤、名字
// ============================================================================

/**
 * 显示击杀排行榜
 */
void ShowRankingHUD()
{
  // 回合结束后或没有幸存者时不显示
  if (g_bShowHUD || GetSurvivorCount() <= 0)
    return;

  // 收集玩家数据: [0]=client, [1]=击杀特感, [2]=击杀丧尸, [3]=友伤输出
  int assister_count;
  int[][] data = new int[MaxClients][4];

  for (int i = 1; i <= MaxClients; i++)
  {
    if (!IsClientInGame(i) || GetClientTeam(i) != 2)
      continue;

    int real                = GetRealPlayer(i);
    data[assister_count][0] = real;
    data[assister_count][1] = ClampValue(g_iKillSpecial[real]);
    data[assister_count][2] = ClampValue(g_iKillZombie[real]);
    data[assister_count][3] = ClampValue(g_iDmgFriendly[real]);
    assister_count++;
  }

  if (assister_count <= 0)
    return;

  // 按击杀特感数降序排列
  SortCustom2D(data, assister_count, SortByKillDesc);

  // 限制最大行数
  if (assister_count > RANKING_MAX_ROWS)
    assister_count = RANKING_MAX_ROWS;

  // totalRows = 数据行数 + 1(标题行), 与原脚本的ranking_count一致
  int totalRows   = assister_count + 1;
  int maxStrLen   = 128;

  // 构建4列数据: 特感、丧尸、友伤、名字
  char[][][] sCol = new char[4][totalRows][maxStrLen];

  // 标题行
  for (int c = 0; c < 4; c++)
    strcopy(sCol[c][0], maxStrLen, g_sRankTitle[c]);

  int dataRows   = assister_count;
  int iSlotSplit = RoundToCeil(float(dataRows) / 2.0);
  int rowsPart1  = 1 + iSlotSplit;
  int rowsPart2  = totalRows - rowsPart1;

  int titleBytes = strlen(g_sRankTitle[3]);
  int nameLen1   = 32;
  int nameLen2   = 32;

  if (iSlotSplit > 0)
  {
    int overhead1 = titleBytes + (rowsPart1 - 1);
    int avail1    = 127 - overhead1;
    if (avail1 < 0) avail1 = 0;
    nameLen1 = RoundToFloor(float(avail1) / float(iSlotSplit));
  }

  if (rowsPart2 > 0)
  {
    int overhead2 = rowsPart1 + (rowsPart2 - 1);
    int avail2    = 127 - overhead2;
    if (avail2 < 0) avail2 = 0;
    nameLen2 = RoundToFloor(float(avail2) / float(rowsPart2));
  }

  int nameMinLen = nameLen1;
  if (nameLen2 < nameMinLen) nameMinLen = nameLen2;
  if (nameMinLen > 32) nameMinLen = 32;
  if (nameMinLen < 8) nameMinLen = 8;

  // 数据行
  for (int x = 0; x < assister_count; x++)
  {
    int row    = x + 1;
    int client = data[x][0];

    if (!IsValidClient(client))
      continue;

    IntToString(data[x][1], sCol[0][row], maxStrLen);
    IntToString(data[x][2], sCol[1][row], maxStrLen);
    IntToString(data[x][3], sCol[2][row], maxStrLen);

    // 获取玩家名字(处理闲置)并按动态长度截断
    char sName[64];
    GetPlayerDisplayName(client, sName, sizeof(sName));
    SafeTruncateUTF8(sName, nameMinLen, sCol[3][row], maxStrLen);
  }

  // 数字列右对齐(前3列)
  for (int c = 0; c < 3; c++)
    AlignColumnRight(sCol[c], totalRows, maxStrLen);

  // 合并各列为换行分隔的字符串并显示
  float fPosY   = RANKING_HUD_Y;
  float fHeight = RANKING_ROW_HEIGHT * totalRows;

  // 显示前3列(特感、丧尸、友伤)
  for (int c = 0; c < 3; c++)
  {
    char sLine[256];
    ImplodeColumnStrings(sCol[c], totalRows, maxStrLen, sLine, sizeof(sLine));
    HUDSetLayoutSafe(g_iRankSlots[c], HUD_FLAG_ALIGN_LEFT | HUD_FLAG_NOBG | HUD_FLAG_TEAM_SURVIVORS | HUD_FLAG_TEXT, sLine);
    HUDPlace(g_iRankSlots[c], g_fRankCoord[c], fPosY, 1.0, fHeight);
  }

  // 显示名字列(第4列): 行数少时单槽位, 行数多时拆分为双槽位
  ShowNameColumn(sCol[3], totalRows, maxStrLen, fPosY, fHeight);
}

/**
 * 显示名字列：当人数较少时使用单槽位，人数较多时拆分为双槽位防止128字节溢出
 * @param nameCol    名字列字符串数组(包含标题行)
 * @param totalRows  总行数(含标题)
 * @param maxStrLen  单个字符串最大长度
 * @param fPosY      HUD Y坐标
 * @param fHeight    HUD 高度
 */
void ShowNameColumn(char[][] nameCol, int totalRows, int maxStrLen, float fPosY, float fHeight)
{
  int  dataRows   = totalRows - 1;                       // 不含标题的数据行数
  int  iSlotSplit = RoundToCeil(float(dataRows) / 2.0);  // 第一个槽位承载的数据行数(不含标题)

  // 先合并完整的名字列文本，检查是否需要双槽位
  char sFullName[256];
  ImplodeColumnStrings(nameCol, totalRows, maxStrLen, sFullName, sizeof(sFullName));

  float fNameX   = g_fRankCoord[3];  // 名字列X坐标
  int   hudFlags = HUD_FLAG_ALIGN_LEFT | HUD_FLAG_NOBG | HUD_FLAG_TEAM_SURVIVORS | HUD_FLAG_TEXT;

  if (strlen(sFullName) <= 127)
  {
    // 单槽位足够容纳所有名字
    HUDSetLayoutSafe(HUD_RIGHT_TOP, hudFlags, sFullName);
    HUDPlace(HUD_RIGHT_TOP, fNameX, fPosY, 1.0, fHeight);
    if (HUDSlotIsUsed(HUD_NAME_EXTRA))
      RemoveHUD(HUD_NAME_EXTRA);
  }
  else
  {
    // 双槽位拆分: 两个数组都保持totalRows行, 不负责的行用空格占位
    // 与原始emshud_info脚本一致, 保证两个槽位行数相同, 避免对齐错位
    char[][] sPart1 = new char[totalRows][maxStrLen];
    char[][] sPart2 = new char[totalRows][maxStrLen];

    for (int i = 0; i < totalRows; i++)
    {
      if (i <= iSlotSplit)
      {
        // 前半段(标题行 + 前iSlotSplit行数据): 第一个槽位显示, 第二个槽位占位
        strcopy(sPart1[i], maxStrLen, nameCol[i]);
        strcopy(sPart2[i], maxStrLen, " ");
      }
      else
      {
        // 后半段(剩余数据行): 第一个槽位占位, 第二个槽位显示
        strcopy(sPart1[i], maxStrLen, " ");
        strcopy(sPart2[i], maxStrLen, nameCol[i]);
      }
    }

    char sName1[256], sName2[256];
    ImplodeColumnStrings(sPart1, totalRows, maxStrLen, sName1, sizeof(sName1));
    ImplodeColumnStrings(sPart2, totalRows, maxStrLen, sName2, sizeof(sName2));

    HUDSetLayoutSafe(HUD_RIGHT_TOP, hudFlags, sName1);
    HUDPlace(HUD_RIGHT_TOP, fNameX, fPosY, 1.0, fHeight);

    HUDSetLayoutSafe(HUD_NAME_EXTRA, hudFlags, sName2);
    HUDPlace(HUD_NAME_EXTRA, fNameX, fPosY, 1.0, fHeight);
  }
}

/**
 * 清除排行榜HUD(包括名字列的额外槽位)
 */
void RemoveRankingHUD()
{
  for (int c = 0; c < sizeof(g_iRankSlots); c++)
    if (HUDSlotIsUsed(g_iRankSlots[c]))
      RemoveHUD(g_iRankSlots[c]);

  // 清除名字列双槽位的第二个槽位
  if (HUDSlotIsUsed(HUD_NAME_EXTRA))
    RemoveHUD(HUD_NAME_EXTRA);
}

/**
 * 排序回调：按击杀特感数降序
 */
int SortByKillDesc(int[] elem1, int[] elem2, const int[][] array, Handle hndl)
{
  if (elem1[1] > elem2[1]) return -1;
  if (elem2[1] > elem1[1]) return 1;
  return 0;
}

// ============================================================================
// 模块4：击杀列表 (HUD_MID_BOX ~ HUD_SCORE_4, 共6个槽位)
// ============================================================================

/**
 * 将新的击杀信息推入列表并刷新HUD
 */
void PushKillInfo(const char[] info)
{
  g_hKillInfoList.PushString(info);

  // 如果超过最大数量，移除最早的一条
  if (g_hKillInfoList.Length > KILL_INFO_MAX)
    g_hKillInfoList.Erase(0);

  // 刷新击杀列表HUD显示
  RefreshKillListHUD();

  // 重置消退定时器
  delete g_hKillFadeTimer;
  g_hKillFadeTimer = CreateTimer(KILL_FADE_TIME, Timer_KillFade, _, TIMER_REPEAT);
}

/**
 * 消退定时器：每次移除最早的一条信息
 */
public Action Timer_KillFade(Handle timer)
{
  if (g_hKillInfoList.Length == 0)
  {
    g_hKillFadeTimer = null;
    return Plugin_Stop;
  }

  g_hKillInfoList.Erase(0);
  RefreshKillListHUD();

  return Plugin_Continue;
}

/**
 * 刷新击杀列表HUD：将ArrayList中的内容写入对应槽位
 */
void RefreshKillListHUD()
{
  int  idx;
  char sInfo[128];

  // 显示现有的击杀信息
  for (idx = 0; idx < KILL_INFO_MAX && idx < g_hKillInfoList.Length; idx++)
  {
    int slot = idx + KILL_HUD_BASE;
    g_hKillInfoList.GetString(idx, sInfo, sizeof(sInfo));

    int flags = HUD_FLAG_TEXT | HUD_FLAG_ALIGN_RIGHT | HUD_FLAG_NOBG;
    HUDSetLayoutSafe(slot, flags, sInfo);
    HUDPlace(slot, KILL_HUD_X, KILL_HUD_Y + idx * KILL_HUD_HEIGHT, KILL_HUD_WIDTH, KILL_HUD_HEIGHT);
  }

  // 清除多余的槽位
  while (idx < KILL_INFO_MAX)
  {
    RemoveHUD(idx + KILL_HUD_BASE);
    idx++;
  }
}

/**
 * 清除所有击杀列表HUD槽位
 */
void RemoveKillListHUD()
{
  for (int i = 0; i < KILL_INFO_MAX; i++)
    RemoveHUD(i + KILL_HUD_BASE);
}

// ============================================================================
// 工具函数 - 数据获取
// ============================================================================

/**
 * 获取游戏当前路程百分比
 */
int GetGameDistance()
{
  int   client;
  float highestFlow;
  client      = L4D_GetHighestFlowSurvivor();
  highestFlow = (client != -1) ? L4D2Direct_GetFlowDistance(client) : L4D2_GetFurthestSurvivorFlow();

  if (highestFlow > 0.0 && g_fMapMaxFlow > 0.0)
    highestFlow = highestFlow / g_fMapMaxFlow * 100.0;
  else
    highestFlow = 0.0;

  int result = RoundToCeil(highestFlow);
  return result < 0 ? 0 : result;
}

/**
 * 获取难度名称
 */
void GetGameDifficultyName(char[] buffer, int maxlen)
{
  char sDifficulty[32];
  GetConVarString(FindConVar("z_Difficulty"), sDifficulty, sizeof(sDifficulty));

  for (int i = 0; i < sizeof(g_sDifficultyCode); i++)
  {
    if (strcmp(g_sDifficultyCode[i], sDifficulty, false) == 0)
    {
      strcopy(buffer, maxlen, g_sDifficultyName[i]);
      return;
    }
  }
  strcopy(buffer, maxlen, sDifficulty);
}

/**
 * 获取最大玩家数
 */
int GetMaxPlayers()
{
  ConVar hMaxPlayers = FindConVar("sv_maxplayers");
  if (hMaxPlayers != null)
  {
    int val = hMaxPlayers.IntValue;
    if (val > 0)
      return val;
  }

  // 根据游戏模式返回默认值
  char sMode[32];
  GetConVarString(FindConVar("mp_gamemode"), sMode, sizeof(sMode));

  for (int i = 0; i < sizeof(g_sModeVersus); i++)
    if (strcmp(sMode, g_sModeVersus[i]) == 0)
      return 8;

  for (int i = 0; i < sizeof(g_sModeSingle); i++)
    if (strcmp(sMode, g_sModeSingle[i]) == 0)
      return 1;

  return 4;
}

/**
 * 获取当前星期名称
 */
char[] GetWeekName()
{
  char sWeek[8];
  FormatTime(sWeek, sizeof(sWeek), "%u");
  return g_sWeekName[StringToInt(sWeek) - 1];
}

/**
 * 获取在场生还者数量
 */
int GetSurvivorCount()
{
  int count = 0;
  for (int i = 1; i <= MaxClients; i++)
    if (IsClientInGame(i) && GetClientTeam(i) == 2)
      count++;
  return count;
}

// ============================================================================
// 工具函数 - 玩家辅助
// ============================================================================

/**
 * 获取真实玩家索引(处理闲置Bot)
 * 如果是Bot且有闲置的真人玩家，返回真人玩家索引
 */
int GetRealPlayer(int client)
{
  int idle = GetIdlePlayerOfBot(client);
  return (idle != 0) ? idle : client;
}

/**
 * 获取Bot对应的闲置玩家
 */
int GetIdlePlayerOfBot(int client)
{
  if (!HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
    return 0;
  return GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
}

/**
 * 获取闲置玩家对应的Bot
 */
int GetBotOfIdlePlayer(int client)
{
  for (int i = 1; i <= MaxClients; i++)
    if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 2 && GetIdlePlayerOfBot(i) == client)
      return i;
  return 0;
}

/**
 * 获取玩家显示名称(闲置玩家显示"闲置:名字")
 */
void GetPlayerDisplayName(int client, char[] buffer, int maxlen)
{
  int bot = GetBotOfIdlePlayer(client);
  if (bot != 0)
    FormatEx(buffer, maxlen, "闲置:%N", client);
  else
    GetClientName(client, buffer, maxlen);

  // 移除换行符
  ReplaceString(buffer, maxlen, "\n", "");
  ReplaceString(buffer, maxlen, "\r", "");
}

/**
 * 格式化Bot/玩家名字(用于击杀列表)
 * 去掉Bot名字中括号前缀
 */
void FormatBotName(int client, char[] buffer, int maxlen)
{
  if (IsFakeClient(client))
  {
    FormatEx(buffer, maxlen, "%N", client);
    int idx = StrContains(buffer, ")");
    if (idx != -1)
      FormatEx(buffer, maxlen, "%s", buffer[idx + 1]);
  }
  else
  {
    FormatEx(buffer, maxlen, "%N", client);
  }
}

/**
 * 判断是否为管理员
 */
bool IsAdminClient(int client)
{
  return (GetUserFlagBits(client) & ADMFLAG_ROOT) != 0;
}

/**
 * 判断玩家有效
 */
bool IsValidClient(int client)
{
  return client > 0 && client <= MaxClients && IsClientInGame(client);
}

/**
 * 限制数值在0~9999之间
 */
int ClampValue(int value)
{
  if (value < 0) return 0;
  if (value > 9999) return 9999;
  return value;
}

// ============================================================================
// 工具函数 - 字符串处理
// ============================================================================

/**
 * UTF-8安全截断字符串(防止多字节字符被截断导致乱码)
 */
void SafeTruncateUTF8(const char[] src, int maxBytes, char[] dest, int destLen)
{
  int len    = 0;
  int i      = 0;
  int srcLen = strlen(src);

  while (i < srcLen)
  {
    int charSize;
    if ((src[i] & 0x80) == 0)
      charSize = 1;
    else if ((src[i] & 0xE0) == 0xC0)
      charSize = 2;
    else if ((src[i] & 0xF0) == 0xE0)
      charSize = 3;
    else if ((src[i] & 0xF8) == 0xF0)
      charSize = 4;
    else
      charSize = 1;  // 非法字节视为单字节

    if (len + charSize > maxBytes)
      break;

    len += charSize;
    i += charSize;
  }

  // 复制截断后的结果
  if (len >= destLen)
    len = destLen - 1;

  for (int j = 0; j < len; j++)
    dest[j] = src[j];
  dest[len] = '\0';
}

void HUDSetLayoutSafe(int slot, int flags, const char[] text)
{
  char safe[128];
  SafeTruncateUTF8(text, 127, safe, sizeof(safe));
  HUDSetLayout(slot, flags, "%s", safe);
}

/**
 * 数字列右对齐：计算最大宽度后在前面补空格
 */
void AlignColumnRight(char[][] col, int rows, int maxStrLen)
{
  // 找到最大字符串长度(从第1行开始，跳过标题)
  int maxWidth = 0;
  for (int i = 1; i < rows; i++)
  {
    int len = strlen(col[i]);
    if (len > maxWidth)
      maxWidth = len;
  }

  // 补空格对齐
  for (int i = 1; i < rows; i++)
  {
    int pad = maxWidth - strlen(col[i]);
    if (pad > 0)
    {
      char temp[128];
      strcopy(temp, sizeof(temp), col[i]);
      col[i][0] = '\0';
      for (int p = 0; p < pad; p++)
        StrCat(col[i], maxStrLen, " ");
      StrCat(col[i], maxStrLen, temp);
    }
  }
}

/**
 * 将字符串数组用换行符合并
 */
void ImplodeColumnStrings(char[][] parts, int count, int partLen, char[] buffer, int bufferLen)
{
  buffer[0] = '\0';
  for (int i = 0; i < count; i++)
  {
    if (i > 0)
      StrCat(buffer, bufferLen, "\n");
    StrCat(buffer, bufferLen, parts[i]);
  }
}

// ============================================================================
// 工具函数 - 击杀列表辅助
// ============================================================================

/**
 * 判断实体是否为女巫
 */
bool IsWitch(int entity)
{
  if (entity > 0 && IsValidEntity(entity))
  {
    char cls[64];
    GetEntityClassname(entity, cls, sizeof(cls));
    return strcmp(cls, "witch", false) == 0;
  }
  return false;
}

/**
 * 判断实体是否为普通感染者
 */
bool IsCommonInfected(int entity)
{
  if (entity > 0 && IsValidEntity(entity))
  {
    char cls[64];
    GetEntityClassname(entity, cls, sizeof(cls));
    return StrEqual(cls, "infected");
  }
  return false;
}

/**
 * 判断玩家是否隔墙击杀了另一个玩家
 */
bool IsPlayerKilledBehindWall(int attacker, int victim)
{
  float vPosA[3], vPosV[3];
  GetClientEyePosition(attacker, vPosA);
  GetClientEyePosition(victim, vPosV);

  Handle hTrace = TR_TraceRayFilterEx(vPosA, vPosV, MASK_PLAYERSOLID, RayType_EndPoint, TraceFilter_NoPlayers, victim);
  bool   hit    = false;
  if (hTrace != null)
  {
    hit = TR_DidHit(hTrace);
    delete hTrace;
  }
  return hit;
}

/**
 * 判断玩家是否隔墙击杀了一个实体
 */
bool IsEntityKilledBehindWall(int attacker, int entity)
{
  float vOrigin[3], vAngles[3];
  GetClientEyePosition(attacker, vOrigin);
  GetClientEyeAngles(attacker, vAngles);

  Handle hTrace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceFilter_NoEntities);
  bool   behind = true;
  if (hTrace != null)
  {
    if (TR_DidHit(hTrace) && TR_GetEntityIndex(hTrace) == entity)
      behind = false;
    delete hTrace;
  }
  return behind;
}

/**
 * 射线过滤：忽略玩家
 */
bool TraceFilter_NoPlayers(int entity, int mask, any data)
{
  if (entity == data || (entity >= 1 && entity <= MaxClients))
    return false;
  return true;
}

/**
 * 射线过滤：忽略实体
 */
bool TraceFilter_NoEntities(int entity, int mask, any data)
{
  if (entity == data || (entity >= 1 && entity <= MaxClients))
    return false;
  return true;
}

// ============================================================================
// 武器名称映射初始化
// ============================================================================

/**
 * 初始化武器名称到击杀图标的映射
 */
void InitWeaponNameMap()
{
  g_smWeaponName = new StringMap();

  // 近战
  g_smWeaponName.SetString("melee", g_sKillType[0]);

  // 手枪
  g_smWeaponName.SetString("pistol", g_sKillType[1]);
  g_smWeaponName.SetString("pistol_magnum", g_sKillType[1]);
  g_smWeaponName.SetString("dual_pistols", g_sKillType[1]);

  // 冲锋枪
  g_smWeaponName.SetString("smg", g_sKillType[2]);
  g_smWeaponName.SetString("smg_silenced", g_sKillType[2]);
  g_smWeaponName.SetString("smg_mp5", g_sKillType[2]);

  // 步枪
  g_smWeaponName.SetString("rifle", g_sKillType[3]);
  g_smWeaponName.SetString("rifle_ak47", g_sKillType[3]);
  g_smWeaponName.SetString("rifle_sg552", g_sKillType[3]);
  g_smWeaponName.SetString("rifle_desert", g_sKillType[3]);

  // 霰弹枪
  g_smWeaponName.SetString("pumpshotgun", g_sKillType[4]);
  g_smWeaponName.SetString("shotgun_chrome", g_sKillType[4]);
  g_smWeaponName.SetString("autoshotgun", g_sKillType[4]);
  g_smWeaponName.SetString("shotgun_spas", g_sKillType[4]);

  // 狙击枪
  g_smWeaponName.SetString("hunting_rifle", g_sKillType[5]);
  g_smWeaponName.SetString("sniper_military", g_sKillType[5]);
  g_smWeaponName.SetString("sniper_scout", g_sKillType[5]);
  g_smWeaponName.SetString("sniper_awp", g_sKillType[5]);

  // 爆炸物
  g_smWeaponName.SetString("pipe_bomb", g_sKillType[6]);
  g_smWeaponName.SetString("env_explosion", g_sKillType[6]);

  // 火焰
  g_smWeaponName.SetString("inferno", g_sKillType[7]);
  g_smWeaponName.SetString("entityflame", g_sKillType[7]);

  // M60
  g_smWeaponName.SetString("rifle_m60", g_sKillType[8]);

  // 榴弹发射器
  g_smWeaponName.SetString("grenade_launcher_projectile", g_sKillType[9]);

  // 推/铲
  g_smWeaponName.SetString("boomer", g_sKillType[10]);
  g_smWeaponName.SetString("player", g_sKillType[10]);

  // 固定机枪
  g_smWeaponName.SetString("prop_minigun_l4d1", g_sKillType[11]);
  g_smWeaponName.SetString("prop_minigun", g_sKillType[11]);

  // 世界/地图
  g_smWeaponName.SetString("world", g_sKillType[12]);
  g_smWeaponName.SetString("worldspawn", g_sKillType[12]);
  g_smWeaponName.SetString("trigger_hurt", g_sKillType[12]);

  // 电锯
  g_smWeaponName.SetString("chainsaw", g_sKillType[18]);

  // 特殊武器(不需要穿墙和爆头提示)
  g_smSpecialWeapons = new StringMap();
  g_smSpecialWeapons.SetValue(g_sKillType[6], true);
  g_smSpecialWeapons.SetValue(g_sKillType[7], true);
  g_smSpecialWeapons.SetValue(g_sKillType[10], true);
  g_smSpecialWeapons.SetValue(g_sKillType[21], true);

  // 忽略穿墙检测的武器
  g_smIgnoreWallWeapons = new StringMap();
  g_smIgnoreWallWeapons.SetValue(g_sKillType[9], true);
  g_smIgnoreWallWeapons.SetValue(g_sKillType[0], true);
  g_smIgnoreWallWeapons.SetValue(g_sKillType[18], true);
  g_smIgnoreWallWeapons.SetValue(g_sKillType[21], true);
}
