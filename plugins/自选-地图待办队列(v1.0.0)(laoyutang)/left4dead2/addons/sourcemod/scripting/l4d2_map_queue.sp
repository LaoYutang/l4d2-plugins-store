#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <l4d2_nativevote>
#include <l4d2_source_keyvalues>

#define PLUGIN_NAME             "L4D2 Map Queue"
#define PLUGIN_AUTHOR           "laoyutang"
#define PLUGIN_VERSION          "1.0.0"
#define PLUGIN_DESCRIPTION      "Persistent campaign queue with votes and automatic finale changes"

#define DATA_FILE               "data/l4d2_map_queue.txt"
#define MAP_NAME_LENGTH         128
#define MISSION_ID_LENGTH       64
#define DISPLAY_NAME_LENGTH     128
#define OPERATION_ARGS_LENGTH   512
#define DATA_VERSION            1
#define LIST_SCHEMA_VERSION     1

enum QueueState
{
	QueueState_Stopped = 0,
	QueueState_Armed,
	QueueState_Running,
	QueueState_Delay
};

enum QueueOperation
{
	QueueOperation_None = 0,
	QueueOperation_Add,
	QueueOperation_AddFront,
	QueueOperation_Remove,
	QueueOperation_Clear,
	QueueOperation_Run,
	QueueOperation_RunAfter,
	QueueOperation_Skip
};

enum struct MapEntry
{
	char map[MAP_NAME_LENGTH];
	char mission[MISSION_ID_LENGTH];
	char missionName[DISPLAY_NAME_LENGTH];
	char chapterName[DISPLAY_NAME_LENGTH];
	bool official;
	bool ambiguous;
	bool installed;
}

enum struct MissionEntry
{
	char mission[MISSION_ID_LENGTH];
	char missionName[DISPLAY_NAME_LENGTH];
	bool official;
}

enum struct QueueSnapshot
{
	ArrayList queue;
	MapEntry active;
	bool hasActive;
	QueueState state;
}

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = ""
};

Address g_pMatchExtL4D;
Handle g_hSDKGetAllMissions;

ArrayList g_Queue;
ArrayList g_Catalog;
ArrayList g_Missions;
StringMap g_MapIndex;

MapEntry g_Active;
bool g_HasActive;
QueueState g_State = QueueState_Stopped;

ConVar g_cvEnable;
ConVar g_cvChangeDelay;
ConVar g_cvVoteTime;
ConVar g_cvGameMode;

Handle g_hAdvanceTimer;
Handle g_hSwitchTimer;

bool g_FinaleHandled;
bool g_IgnoreFinaleUntilMapStart;
bool g_ShuttingDown;

char g_GameMode[64];
char g_DataPath[PLATFORM_MAX_PATH];
char g_TempPath[PLATFORM_MAX_PATH];
char g_BackupPath[PLATFORM_MAX_PATH];

int g_MenuType[MAXPLAYERS + 1];
char g_MenuMission[MAXPLAYERS + 1][MISSION_ID_LENGTH];

ConVar g_cvMapChangerType;
ConVar g_cvMapChangerFailures;
bool g_MapChangerHooksInstalled;
bool g_MapChangerTakenOver;
bool g_InternalMapChangerChange;
char g_SavedMapChangerType[32];
char g_SavedMapChangerFailures[32];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int errorLength)
{
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, errorLength, "L4D2 Map Queue only supports Left 4 Dead 2");
		return APLRes_SilentFailure;
	}

	RegPluginLibrary("l4d2_map_queue");
	return APLRes_Success;
}

public void OnPluginStart()
{
	InitMissionSDK();

	g_Queue = new ArrayList(sizeof(MapEntry));
	g_Catalog = new ArrayList(sizeof(MapEntry));
	g_Missions = new ArrayList(sizeof(MissionEntry));
	g_MapIndex = new StringMap();

	BuildPath(Path_SM, g_DataPath, sizeof(g_DataPath), DATA_FILE);
	FormatEx(g_TempPath, sizeof(g_TempPath), "%s.tmp", g_DataPath);
	FormatEx(g_BackupPath, sizeof(g_BackupPath), "%s.bak", g_DataPath);

	LoadTranslations("missions.phrases");
	LoadTranslations("chapters.phrases");

	CreateConVar("l4d2_map_queue_version", PLUGIN_VERSION, "L4D2 Map Queue version.", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_cvEnable = CreateConVar("l4d2_map_queue_enable", "1", "Enable the L4D2 map queue.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvChangeDelay = CreateConVar("l4d2_map_queue_change_delay", "3.0", "Seconds to wait after a campaign finale before loading the next queue entry.", FCVAR_NOTIFY, true, 0.0, true, 60.0);
	g_cvVoteTime = CreateConVar("l4d2_map_queue_vote_time", "20", "Duration of map queue votes in seconds.", FCVAR_NOTIFY, true, 5.0, true, 60.0);
	g_cvEnable.AddChangeHook(Cvar_EnableChanged);

	g_cvGameMode = FindConVar("mp_gamemode");
	if (g_cvGameMode != null)
	{
		g_cvGameMode.AddChangeHook(Cvar_GameModeChanged);
		g_cvGameMode.GetString(g_GameMode, sizeof(g_GameMode));
	}

	RegConsoleCmd("sm_mq", Command_MapQueue, "sm_mq <status|add|addfront|list|remove|clear|run|runafter|skip>");

	HookEvent("finale_win", Event_FinaleWin, EventHookMode_Pre);
	HookEvent("finale_vehicle_leaving", Event_FinaleVehicleLeaving, EventHookMode_Pre);

	AutoExecConfig(true, "l4d2_map_queue");

	RebuildCatalog();
	LoadQueueState();
}

public void OnAllPluginsLoaded()
{
	RefreshMapChangerConVars();
	SyncMapChangerControl();
}

public void OnPluginEnd()
{
	g_ShuttingDown = true;
	CancelAllTimers();

	if (g_Queue != null)
	{
		RequeueActiveInMemory();
		g_State = QueueState_Stopped;
		SaveQueueState();
	}

	ReleaseMapChangerControl();
}

public void OnLibraryAdded(const char[] name)
{
	if (strcmp(name, "map_changer") == 0)
		RequestFrame(Frame_RefreshMapChanger);
}

public void OnLibraryRemoved(const char[] name)
{
	if (strcmp(name, "map_changer") != 0)
		return;

	ReleaseMapChangerControl();
	RemoveMapChangerHooks();
}

public void OnConfigsExecuted()
{
	RefreshGameMode();
	RebuildCatalog();
	SyncMapChangerControl();
}

public void OnMapStart()
{
	g_FinaleHandled = false;
	g_IgnoreFinaleUntilMapStart = false;
	RefreshGameMode();
	RebuildCatalog();
	if (IsAutomationActive() && !IsSupportedMode())
		StopAndRequeueActive("当前模式不属于合作战役，地图待办已停止。");
	RefreshMapChangerConVars();
	SyncMapChangerControl();
}

public void OnMapEnd()
{
	delete g_hSwitchTimer;

	if (g_State == QueueState_Delay && g_hAdvanceTimer != null)
	{
		delete g_hAdvanceTimer;
		g_State = QueueState_Armed;
		if (!SaveQueueState())
			LogError("Failed to persist the queue after an external map change during the delay window.");
	}
}

public void OnClientDisconnect(int client)
{
	if (!IsFakeClient(client))
	{
		g_MenuMission[client][0] = '\0';
		RequestFrame(Frame_CheckForEmptyServer);
	}
}

void Frame_CheckForEmptyServer(any data)
{
	if (!g_ShuttingDown && IsAutomationActive() && CountHumanPlayers() == 0)
		StopForEmptyServer();
}

void Frame_RefreshMapChanger(any data)
{
	RefreshMapChangerConVars();
	SyncMapChangerControl();
}

void Frame_CheckGameMode(any data)
{
	if (!g_ShuttingDown && IsAutomationActive() && !IsSupportedMode())
		StopAndRequeueActive("当前模式不属于合作战役，地图待办已停止。");
}

Action Command_MapQueue(int client, int args)
{
	if (client > 0 && (!IsClientInGame(client) || IsFakeClient(client)))
		return Plugin_Handled;

	if (args == 0)
	{
		ShowStatus(client);
		return Plugin_Handled;
	}

	char subcommand[32];
	GetCmdArg(1, subcommand, sizeof(subcommand));

	if (StrEqual(subcommand, "status", false))
	{
		if (args != 1)
			ReplyToCommand(client, "[MapQueue] 用法: sm_mq status");
		else
			ShowStatus(client);
		return Plugin_Handled;
	}

	if (StrEqual(subcommand, "list", false))
	{
		if (args != 1)
			ReplyToCommand(client, "[MapQueue] 用法: sm_mq list");
		else
			ShowQueue(client);
		return Plugin_Handled;
	}

	if (StrEqual(subcommand, "add", false) && args == 1)
	{
		if (client == 0)
			ReplyToCommand(client, "[MapQueue] 用法: sm_mq add <地图代码 ...>");
		else if (!g_cvEnable.BoolValue)
			ReplyToCommand(client, "[MapQueue] 插件当前未启用。");
		else
			ShowMapTypeMenu(client);
		return Plugin_Handled;
	}

	QueueOperation operation = ParseOperation(subcommand);
	if (operation == QueueOperation_None)
	{
		PrintUsage(client);
		return Plugin_Handled;
	}

	if (!ValidateCommandArgumentCount(client, operation, args))
		return Plugin_Handled;

	char operationArgs[OPERATION_ARGS_LENGTH];
	if (!BuildOperationArgs(2, args, operationArgs, sizeof(operationArgs)))
	{
		ReplyToCommand(client, "[MapQueue] 参数过长。");
		return Plugin_Handled;
	}

	SubmitOperation(client, operation, operationArgs);
	return Plugin_Handled;
}

QueueOperation ParseOperation(const char[] subcommand)
{
	if (StrEqual(subcommand, "add", false))
		return QueueOperation_Add;
	if (StrEqual(subcommand, "addfront", false))
		return QueueOperation_AddFront;
	if (StrEqual(subcommand, "remove", false))
		return QueueOperation_Remove;
	if (StrEqual(subcommand, "clear", false))
		return QueueOperation_Clear;
	if (StrEqual(subcommand, "run", false))
		return QueueOperation_Run;
	if (StrEqual(subcommand, "runafter", false))
		return QueueOperation_RunAfter;
	if (StrEqual(subcommand, "skip", false))
		return QueueOperation_Skip;
	return QueueOperation_None;
}

bool ValidateCommandArgumentCount(int client, QueueOperation operation, int args)
{
	switch (operation)
	{
		case QueueOperation_Add:
		{
			if (args >= 2)
				return true;
			ReplyToCommand(client, "[MapQueue] 用法: sm_mq add <地图代码 ...>");
		}
		case QueueOperation_AddFront:
		{
			if (args >= 2)
				return true;
			ReplyToCommand(client, "[MapQueue] 用法: sm_mq addfront <地图代码 ...>");
		}
		case QueueOperation_Remove:
		{
			if (args == 2)
				return true;
			ReplyToCommand(client, "[MapQueue] 用法: sm_mq remove <地图代码>");
		}
		default:
		{
			if (args == 1)
				return true;
			ReplyToCommand(client, "[MapQueue] 此子指令不接受参数。");
		}
	}
	return false;
}

bool BuildOperationArgs(int firstArg, int lastArg, char[] output, int outputLength)
{
	output[0] = '\0';
	char value[MAP_NAME_LENGTH];

	for (int i = firstArg; i <= lastArg; i++)
	{
		GetCmdArg(i, value, sizeof(value));
		int needed = strlen(output) + strlen(value) + (output[0] ? 2 : 1);
		if (needed > outputLength)
			return false;

		if (output[0])
			StrCat(output, outputLength, " ");
		StrCat(output, outputLength, value);
	}

	return true;
}

void PrintUsage(int client)
{
	ReplyToCommand(client, "[MapQueue] sm_mq <status|add|addfront|list|remove|clear|run|runafter|skip>");
}

void ShowStatus(int client)
{
	char activeMap[MAP_NAME_LENGTH];
	char stateName[16];
	strcopy(activeMap, sizeof(activeMap), g_HasActive ? g_Active.map : "-");
	GetQueueStateName(g_State, stateName, sizeof(stateName));
	ReplyToCommand(client, "[MapQueue] enabled=%d supported=%d state=%s active=%s pending=%d",
		g_cvEnable.BoolValue ? 1 : 0,
		IsSupportedMode() ? 1 : 0,
		stateName,
		activeMap,
		g_Queue.Length);
}

void ShowQueue(int client)
{
	if (client == 0)
	{
		ShowQueueMachine(client);
		return;
	}

	char stateName[16];
	GetQueueStateName(g_State, stateName, sizeof(stateName));
	ReplyToCommand(client, "[MapQueue] 状态: %s；待执行: %d", stateName, g_Queue.Length);

	if (g_HasActive)
	{
		char display[320];
		FormatEntryDisplay(g_Active, client, display, sizeof(display));
		ReplyToCommand(client, "[MapQueue] [执行中] %s", display);
	}

	MapEntry entry;
	for (int i = 0; i < g_Queue.Length; i++)
	{
		g_Queue.GetArray(i, entry);
		char display[320];
		FormatEntryDisplay(entry, client, display, sizeof(display));
		ReplyToCommand(client, "[MapQueue] %d. %s", i + 1, display);
	}

	if (!g_HasActive && g_Queue.Length == 0)
		ReplyToCommand(client, "[MapQueue] 列表为空。");
}

void ShowQueueMachine(int client)
{
	char stateName[16];
	GetQueueStateName(g_State, stateName, sizeof(stateName));

	int activeCount = g_HasActive ? 1 : 0;
	int itemCount = activeCount + g_Queue.Length;
	ReplyToCommand(client,
		"MQ_LIST {\"record\":\"begin\",\"schema\":%d,\"state\":\"%s\",\"active_count\":%d,\"pending_count\":%d,\"item_count\":%d}",
		LIST_SCHEMA_VERSION,
		stateName,
		activeCount,
		g_Queue.Length,
		itemCount);

	int index;
	if (g_HasActive)
		PrintQueueMachineItem(client, g_Active, index++, true);

	MapEntry entry;
	for (int i = 0; i < g_Queue.Length; i++)
	{
		g_Queue.GetArray(i, entry);
		PrintQueueMachineItem(client, entry, index++, false);
	}

	ReplyToCommand(client,
		"MQ_LIST {\"record\":\"end\",\"schema\":%d,\"item_count\":%d}",
		LIST_SCHEMA_VERSION,
		index);
}

void PrintQueueMachineItem(int client, MapEntry entry, int index, bool active)
{
	char missionName[DISPLAY_NAME_LENGTH];
	char chapterName[DISPLAY_NAME_LENGTH];
	FormatMapEntryMissionName(entry, client, missionName, sizeof(missionName));
	FormatChapterName(entry, client, chapterName, sizeof(chapterName));

	char mapJson[MAP_NAME_LENGTH * 6 + 1];
	char missionJson[MISSION_ID_LENGTH * 6 + 1];
	char missionNameJson[DISPLAY_NAME_LENGTH * 6 + 1];
	char chapterNameJson[DISPLAY_NAME_LENGTH * 6 + 1];
	EscapeJsonString(entry.map, mapJson, sizeof(mapJson));
	EscapeJsonString(entry.mission, missionJson, sizeof(missionJson));
	EscapeJsonString(missionName, missionNameJson, sizeof(missionNameJson));
	EscapeJsonString(chapterName, chapterNameJson, sizeof(chapterNameJson));

	ReplyToCommand(client,
		"MQ_LIST {\"record\":\"item\",\"schema\":%d,\"index\":%d,\"active\":%s,\"map\":\"%s\",\"mission\":\"%s\",\"mission_name\":\"%s\",\"chapter_name\":\"%s\",\"official\":%s}",
		LIST_SCHEMA_VERSION,
		index,
		active ? "true" : "false",
		mapJson,
		missionJson,
		missionNameJson,
		chapterNameJson,
		entry.official ? "true" : "false");
}

void EscapeJsonString(const char[] input, char[] output, int outputLength)
{
	int written;
	output[0] = '\0';

	for (int i = 0; input[i]; i++)
	{
		int value = input[i] & 0xFF;
		char escaped[7];

		switch (value)
		{
			case '"': strcopy(escaped, sizeof(escaped), "\\\"");
			case '\\': strcopy(escaped, sizeof(escaped), "\\\\");
			case 8: strcopy(escaped, sizeof(escaped), "\\b");
			case 9: strcopy(escaped, sizeof(escaped), "\\t");
			case 10: strcopy(escaped, sizeof(escaped), "\\n");
			case 12: strcopy(escaped, sizeof(escaped), "\\f");
			case 13: strcopy(escaped, sizeof(escaped), "\\r");
			default:
			{
				if (value >= 0x20)
				{
					if (written + 1 >= outputLength)
					{
						output[written] = '\0';
						return;
					}
					output[written++] = input[i];
					continue;
				}
				FormatEx(escaped, sizeof(escaped), "\\u%04X", value);
			}
		}

		int escapedLength = strlen(escaped);
		if (written + escapedLength >= outputLength)
			break;

		for (int j = 0; j < escapedLength; j++)
			output[written++] = escaped[j];
	}

	output[written] = '\0';
}

void SubmitOperation(int client, QueueOperation operation, const char[] operationArgs)
{
	if (client == 0 || CheckCommandAccess(client, "sm_mq_admin", ADMFLAG_CHANGEMAP, true))
	{
		char result[256];
		ExecuteOperation(operation, operationArgs, result, sizeof(result));
		ReplyToCommand(client, "[MapQueue] %s", result);
		return;
	}

	char error[256];
	if (!ValidateOperation(operation, operationArgs, error, sizeof(error)))
	{
		ReplyToCommand(client, "[MapQueue] %s", error);
		return;
	}

	StartOperationVote(client, operation, operationArgs);
}

bool ValidateOperation(QueueOperation operation, const char[] operationArgs, char[] error, int errorLength)
{
	if (!g_cvEnable.BoolValue)
	{
		strcopy(error, errorLength, "插件当前未启用。");
		return false;
	}

	switch (operation)
	{
		case QueueOperation_Add, QueueOperation_AddFront:
		{
			ArrayList entries = new ArrayList(sizeof(MapEntry));
			bool valid = ResolveMapArguments(operationArgs, entries, error, errorLength);
			delete entries;
			return valid;
		}
		case QueueOperation_Remove:
		{
			if (CountPendingMap(operationArgs) == 0)
			{
				FormatEx(error, errorLength, "待执行列表中没有地图 %s。", operationArgs);
				return false;
			}
		}
		case QueueOperation_Clear:
		{
			if (!g_HasActive && g_Queue.Length == 0 && g_State == QueueState_Stopped)
			{
				strcopy(error, errorLength, "列表已经为空。");
				return false;
			}
		}
		case QueueOperation_Run:
		{
			if (g_State == QueueState_Running || g_State == QueueState_Delay)
			{
				strcopy(error, errorLength, "队列正在执行。");
				return false;
			}
			if (g_Queue.Length == 0)
			{
				strcopy(error, errorLength, "待执行列表为空。");
				return false;
			}
			if (!CanStartAutomation(error, errorLength))
				return false;

			MapEntry resolved;
			if (!ResolvePendingHead(resolved, error, errorLength))
				return false;
		}
		case QueueOperation_RunAfter:
		{
			if (g_State != QueueState_Stopped)
			{
				strcopy(error, errorLength, "队列已经在执行或等待。");
				return false;
			}
			if (g_Queue.Length == 0)
			{
				strcopy(error, errorLength, "待执行列表为空。");
				return false;
			}
			if (!CanStartAutomation(error, errorLength))
				return false;
		}
		case QueueOperation_Skip:
		{
			if (!g_HasActive && g_Queue.Length == 0)
			{
				strcopy(error, errorLength, "没有可以跳过的地图。");
				return false;
			}
		}
	}

	error[0] = '\0';
	return true;
}

bool CanStartAutomation(char[] error, int errorLength)
{
	if (!IsSupportedMode())
	{
		strcopy(error, errorLength, "当前不是合作、写实或合作类突变模式。");
		return false;
	}
	if (CountHumanPlayers() == 0)
	{
		strcopy(error, errorLength, "服务器内没有真人玩家，不能启动队列。");
		return false;
	}
	return true;
}

void StartOperationVote(int client, QueueOperation operation, const char[] operationArgs)
{
	if (!L4D2NativeVote_IsAllowNewVote())
	{
		ReplyToCommand(client, "[MapQueue] 当前已有投票正在进行。");
		return;
	}

	int clients[MAXPLAYERS];
	int count;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
			clients[count++] = i;
	}

	if (count == 0)
	{
		ReplyToCommand(client, "[MapQueue] 没有可参与投票的玩家。");
		return;
	}

	L4D2NativeVote vote = L4D2NativeVote(OperationVoteHandler);
	vote.Initiator = client;
	vote.Value = view_as<int>(operation);
	vote.SetInfo("%s", operationArgs);
	char title[64];
	GetOperationVoteTitle(operation, title, sizeof(title));
	vote.SetDisplayText("%s", title);

	if (!vote.DisplayVote(clients, count, g_cvVoteTime.IntValue))
		ReplyToCommand(client, "[MapQueue] 无法发起投票。");
}

void OperationVoteHandler(L4D2NativeVote vote, VoteAction action, int param1, int param2)
{
	if (action == VoteAction_Start)
	{
		if (param1 > 0 && IsClientInGame(param1))
		{
			char title[64];
			GetOperationVoteTitle(view_as<QueueOperation>(vote.Value), title, sizeof(title));
			PrintToChatAll("\x04[地图待办]\x01 %N 发起投票：%s", param1, title);
		}
		return;
	}

	if (action != VoteAction_End)
		return;

	if (vote.YesCount <= vote.NoCount)
	{
		vote.SetFail();
		return;
	}

	char operationArgs[OPERATION_ARGS_LENGTH];
	vote.GetInfo(operationArgs, sizeof(operationArgs));

	char result[256];
	if (ExecuteOperation(view_as<QueueOperation>(vote.Value), operationArgs, result, sizeof(result)))
	{
		vote.SetPass("%s", result);
		PrintToChatAll("\x04[地图待办]\x01 %s", result);
	}
	else
	{
		vote.SetFail();
		if (vote.Initiator > 0 && IsClientInGame(vote.Initiator))
			PrintToChat(vote.Initiator, "\x04[地图待办]\x01 %s", result);
	}
}

void GetOperationVoteTitle(QueueOperation operation, char[] output, int outputLength)
{
	switch (operation)
	{
		case QueueOperation_Add: strcopy(output, outputLength, "添加地图到队尾");
		case QueueOperation_AddFront: strcopy(output, outputLength, "添加地图到队首");
		case QueueOperation_Remove: strcopy(output, outputLength, "删除待办地图");
		case QueueOperation_Clear: strcopy(output, outputLength, "清空地图待办");
		case QueueOperation_Run: strcopy(output, outputLength, "立即执行地图待办");
		case QueueOperation_RunAfter: strcopy(output, outputLength, "本战役通关后执行待办");
		case QueueOperation_Skip: strcopy(output, outputLength, "跳过当前待办地图");
		default: strcopy(output, outputLength, "修改地图待办");
	}
}

bool ExecuteOperation(QueueOperation operation, const char[] operationArgs, char[] result, int resultLength)
{
	char error[256];
	if (!ValidateOperation(operation, operationArgs, error, sizeof(error)))
	{
		strcopy(result, resultLength, error);
		return false;
	}

	switch (operation)
	{
		case QueueOperation_Add:
			return ExecuteAdd(operationArgs, false, result, resultLength);
		case QueueOperation_AddFront:
			return ExecuteAdd(operationArgs, true, result, resultLength);
		case QueueOperation_Remove:
			return ExecuteRemove(operationArgs, result, resultLength);
		case QueueOperation_Clear:
			return ExecuteClear(result, resultLength);
		case QueueOperation_Run:
			return ExecuteRun(result, resultLength);
		case QueueOperation_RunAfter:
			return ExecuteRunAfter(result, resultLength);
		case QueueOperation_Skip:
			return ExecuteSkip(result, resultLength);
	}

	strcopy(result, resultLength, "未知操作。");
	return false;
}

bool ExecuteAdd(const char[] args, bool front, char[] result, int resultLength)
{
	ArrayList entries = new ArrayList(sizeof(MapEntry));
	char error[256];
	if (!ResolveMapArguments(args, entries, error, sizeof(error)))
	{
		strcopy(result, resultLength, error);
		delete entries;
		return false;
	}

	QueueSnapshot snapshot;
	TakeQueueSnapshot(snapshot);

	MapEntry entry;
	if (front)
	{
		for (int i = entries.Length - 1; i >= 0; i--)
		{
			entries.GetArray(i, entry);
			PrependQueueEntry(entry);
		}
	}
	else
	{
		for (int i = 0; i < entries.Length; i++)
		{
			entries.GetArray(i, entry);
			g_Queue.PushArray(entry);
		}
	}

	int added = entries.Length;
	delete entries;

	if (!CommitQueueMutation(snapshot, result, resultLength))
		return false;

	FormatEx(result, resultLength, "已添加 %d 个地图到队%s。", added, front ? "首" : "尾");
	return true;
}

bool ExecuteRemove(const char[] map, char[] result, int resultLength)
{
	QueueSnapshot snapshot;
	TakeQueueSnapshot(snapshot);

	int removed;
	MapEntry entry;
	for (int i = g_Queue.Length - 1; i >= 0; i--)
	{
		g_Queue.GetArray(i, entry);
		if (StrEqual(entry.map, map, false))
		{
			g_Queue.Erase(i);
			removed++;
		}
	}

	if (g_Queue.Length == 0 && (g_State == QueueState_Armed || g_State == QueueState_Delay))
		g_State = QueueState_Stopped;

	if (!CommitQueueMutation(snapshot, result, resultLength))
		return false;

	if (g_State == QueueState_Stopped)
	{
		delete g_hAdvanceTimer;
		g_IgnoreFinaleUntilMapStart = false;
		SyncMapChangerControl();
	}

	FormatEx(result, resultLength, "已删除地图 %s 的全部 %d 个待执行项。", map, removed);
	return true;
}

bool ExecuteClear(char[] result, int resultLength)
{
	QueueSnapshot snapshot;
	TakeQueueSnapshot(snapshot);

	g_Queue.Clear();
	g_HasActive = false;
	ClearMapEntry(g_Active);
	g_State = QueueState_Stopped;

	if (!CommitQueueMutation(snapshot, result, resultLength))
		return false;

	CancelAllTimers();
	g_IgnoreFinaleUntilMapStart = false;
	SyncMapChangerControl();
	strcopy(result, resultLength, "已清空地图待办并停止执行。");
	return true;
}

bool ExecuteRun(char[] result, int resultLength)
{
	MapEntry resolved;
	char error[256];
	if (!ResolvePendingHead(resolved, error, sizeof(error)))
	{
		strcopy(result, resultLength, error);
		return false;
	}

	QueueSnapshot snapshot;
	TakeQueueSnapshot(snapshot);
	g_Queue.Erase(0);
	CopyMapEntry(resolved, g_Active);
	g_HasActive = true;
	g_State = QueueState_Running;

	if (!CommitQueueMutation(snapshot, result, resultLength))
		return false;

	CancelAllTimers();
	g_IgnoreFinaleUntilMapStart = true;
	g_FinaleHandled = false;
	SyncMapChangerControl();
	ScheduleActiveMapSwitch();
	FormatEx(result, resultLength, "队列已启动，正在切换至 %s。", g_Active.map);
	return true;
}

bool ExecuteRunAfter(char[] result, int resultLength)
{
	QueueSnapshot snapshot;
	TakeQueueSnapshot(snapshot);
	g_State = QueueState_Armed;

	if (!CommitQueueMutation(snapshot, result, resultLength))
		return false;

	g_IgnoreFinaleUntilMapStart = false;
	g_FinaleHandled = false;
	SyncMapChangerControl();
	strcopy(result, resultLength, "队列已等待，将在当前战役通关后执行。");
	return true;
}

bool ExecuteSkip(char[] result, int resultLength)
{
	QueueSnapshot snapshot;
	TakeQueueSnapshot(snapshot);

	char skipped[MAP_NAME_LENGTH];
	bool startNext;
	bool nextInvalid;

	if (g_State == QueueState_Running && g_HasActive)
	{
		strcopy(skipped, sizeof(skipped), g_Active.map);
		g_HasActive = false;
		ClearMapEntry(g_Active);
		if (g_Queue.Length > 0)
			startNext = PrepareNextActive(nextInvalid);
		else
			g_State = QueueState_Stopped;
	}
	else
	{
		MapEntry entry;
		g_Queue.GetArray(0, entry);
		strcopy(skipped, sizeof(skipped), entry.map);
		g_Queue.Erase(0);

		if (g_State == QueueState_Delay)
		{
			if (g_Queue.Length > 0)
				startNext = PrepareNextActive(nextInvalid);
			else
				g_State = QueueState_Stopped;
		}
		else if (g_State == QueueState_Armed && g_Queue.Length == 0)
		{
			g_State = QueueState_Stopped;
		}
	}

	if (!CommitQueueMutation(snapshot, result, resultLength))
		return false;

	CancelAllTimers();
	if (startNext)
	{
		g_IgnoreFinaleUntilMapStart = true;
		g_FinaleHandled = false;
		SyncMapChangerControl();
		ScheduleActiveMapSwitch();
		FormatEx(result, resultLength, "已跳过 %s，正在切换至 %s。", skipped, g_Active.map);
	}
	else if (nextInvalid)
	{
		g_IgnoreFinaleUntilMapStart = false;
		SyncMapChangerControl();
		FormatEx(result, resultLength, "已跳过 %s；下一项无效，队列已停止并保留该项。", skipped);
	}
	else
	{
		if (g_State != QueueState_Running)
			g_IgnoreFinaleUntilMapStart = false;
		SyncMapChangerControl();
		FormatEx(result, resultLength, "已跳过 %s。", skipped);
	}
	return true;
}

bool PrepareNextActive(bool &invalid)
{
	invalid = false;
	MapEntry resolved;
	char error[256];
	if (!ResolvePendingHead(resolved, error, sizeof(error)))
	{
		invalid = true;
		g_State = QueueState_Stopped;
		return false;
	}

	g_Queue.Erase(0);
	CopyMapEntry(resolved, g_Active);
	g_HasActive = true;
	g_State = QueueState_Running;
	return true;
}

void ScheduleActiveMapSwitch()
{
	delete g_hSwitchTimer;
	g_hSwitchTimer = CreateTimer(0.1, Timer_SwitchToActiveMap);
}

Action Timer_SwitchToActiveMap(Handle timer)
{
	g_hSwitchTimer = null;
	if (g_State != QueueState_Running || !g_HasActive)
		return Plugin_Stop;

	if (CountHumanPlayers() == 0)
	{
		StopForEmptyServer();
		return Plugin_Stop;
	}

	RebuildCatalog();
	MapEntry resolved;
	char error[256];
	if (!ResolveMapEntry(g_Active.map, resolved, error, sizeof(error)))
	{
		LogError("Cannot switch to active queue map '%s': %s", g_Active.map, error);
		StopAndRequeueActive("执行项已经失效，队列已停止。");
		return Plugin_Stop;
	}

	CopyMapEntry(resolved, g_Active);
	PrintToChatAll("\x04[地图待办]\x01 正在进入：%s", g_Active.map);
	ForceChangeLevel(g_Active.map, "L4D2 map queue");
	return Plugin_Stop;
}

Action Event_FinaleWin(Event event, const char[] name, bool dontBroadcast)
{
	TryCompleteCampaign();
	return Plugin_Continue;
}

Action Event_FinaleVehicleLeaving(Event event, const char[] name, bool dontBroadcast)
{
	TryCompleteCampaign();
	return Plugin_Continue;
}

void TryCompleteCampaign()
{
	if (!g_cvEnable.BoolValue || g_FinaleHandled || g_IgnoreFinaleUntilMapStart || !IsAutomationActive())
		return;
	if (!IsSupportedMode() || !L4D_IsMissionFinalMap())
		return;
	if (g_State != QueueState_Running && g_State != QueueState_Armed)
		return;

	g_FinaleHandled = true;

	QueueSnapshot snapshot;
	TakeQueueSnapshot(snapshot);

	if (g_State == QueueState_Running)
	{
		g_HasActive = false;
		ClearMapEntry(g_Active);
	}

	g_State = g_Queue.Length > 0 ? QueueState_Delay : QueueState_Stopped;

	char error[256];
	if (!CommitQueueMutation(snapshot, error, sizeof(error)))
	{
		LogError("Unable to persist campaign completion: %s", error);
		RequeueActiveInMemory();
		g_State = QueueState_Stopped;
		CancelAllTimers();
		SyncMapChangerControl();
		return;
	}

	if (g_State == QueueState_Stopped)
	{
		SyncMapChangerControl();
		PrintToChatAll("\x04[地图待办]\x01 队列已全部完成。");
		return;
	}

	SyncMapChangerControl();
	float delay = g_cvChangeDelay.FloatValue;
	if (delay < 0.1)
		delay = 0.1;
	delete g_hAdvanceTimer;
	g_hAdvanceTimer = CreateTimer(delay, Timer_StartNextQueueItem);
	PrintToChatAll("\x04[地图待办]\x01 战役已完成，%.1f 秒后进入下一项。", delay);
}

Action Timer_StartNextQueueItem(Handle timer)
{
	g_hAdvanceTimer = null;
	if (g_State != QueueState_Delay)
		return Plugin_Stop;

	if (CountHumanPlayers() == 0)
	{
		StopForEmptyServer();
		return Plugin_Stop;
	}

	MapEntry resolved;
	char error[256];
	if (!ResolvePendingHead(resolved, error, sizeof(error)))
	{
		g_State = QueueState_Stopped;
		g_IgnoreFinaleUntilMapStart = false;
		SaveQueueState();
		SyncMapChangerControl();
		LogError("Cannot advance map queue: %s", error);
		PrintToChatAll("\x04[地图待办]\x01 %s 队列已停止。", error);
		return Plugin_Stop;
	}

	QueueSnapshot snapshot;
	TakeQueueSnapshot(snapshot);
	g_Queue.Erase(0);
	CopyMapEntry(resolved, g_Active);
	g_HasActive = true;
	g_State = QueueState_Running;

	if (!CommitQueueMutation(snapshot, error, sizeof(error)))
	{
		LogError("Cannot persist the next queue item: %s", error);
		g_State = QueueState_Stopped;
		g_IgnoreFinaleUntilMapStart = false;
		SyncMapChangerControl();
		return Plugin_Stop;
	}

	g_IgnoreFinaleUntilMapStart = true;
	ScheduleActiveMapSwitch();
	return Plugin_Stop;
}

void StopForEmptyServer()
{
	StopAndRequeueActive("服务器已空，地图待办停止；未完成项已放回队首。");
}

void StopAndRequeueActive(const char[] reason)
{
	QueueSnapshot snapshot;
	TakeQueueSnapshot(snapshot);
	RequeueActiveInMemory();
	g_State = QueueState_Stopped;

	char error[256];
	if (!CommitQueueMutation(snapshot, error, sizeof(error)))
	{
		LogError("Failed to persist stopped queue state: %s", error);
		RequeueActiveInMemory();
		g_State = QueueState_Stopped;
	}

	CancelAllTimers();
	g_IgnoreFinaleUntilMapStart = false;
	SyncMapChangerControl();
	if (CountHumanPlayers() > 0)
		PrintToChatAll("\x04[地图待办]\x01 %s", reason);
}

void RequeueActiveInMemory()
{
	if (!g_HasActive)
		return;

	PrependQueueEntry(g_Active);
	g_HasActive = false;
	ClearMapEntry(g_Active);
}

void CancelAllTimers()
{
	delete g_hAdvanceTimer;
	delete g_hSwitchTimer;
}

bool IsAutomationActive()
{
	return g_State != QueueState_Stopped;
}

bool IsSupportedMode()
{
	return L4D_GetGameModeType() == GAMEMODE_COOP;
}

int CountHumanPlayers()
{
	int count;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
			count++;
	}
	return count;
}

void GetQueueStateName(QueueState state, char[] output, int outputLength)
{
	switch (state)
	{
		case QueueState_Stopped: strcopy(output, outputLength, "stopped");
		case QueueState_Armed: strcopy(output, outputLength, "armed");
		case QueueState_Running: strcopy(output, outputLength, "running");
		case QueueState_Delay: strcopy(output, outputLength, "delay");
		default: strcopy(output, outputLength, "unknown");
	}
}

void Cvar_EnableChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!convar.BoolValue && IsAutomationActive())
		StopAndRequeueActive("插件已禁用，地图待办停止。");
}

void Cvar_GameModeChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	strcopy(g_GameMode, sizeof(g_GameMode), newValue);
	RebuildCatalog();
	RequestFrame(Frame_CheckGameMode);
}

void RefreshGameMode()
{
	if (g_cvGameMode != null)
		g_cvGameMode.GetString(g_GameMode, sizeof(g_GameMode));
}

void InitMissionSDK()
{
	GameData gameData = new GameData("l4d2_map_queue");
	if (gameData == null)
		SetFailState("Failed to load gamedata/l4d2_map_queue.txt");

	g_pMatchExtL4D = gameData.GetAddress("g_pMatchExtL4D");
	if (g_pMatchExtL4D == Address_Null)
		SetFailState("Failed to find g_pMatchExtL4D");

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetVirtual(0);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetAllMissions = EndPrepSDKCall();
	if (g_hSDKGetAllMissions == null)
		SetFailState("Failed to create MatchExtL4D::GetAllMissions SDKCall");

	delete gameData;
}

void RebuildCatalog()
{
	if (g_Catalog == null || g_Missions == null || g_MapIndex == null || g_hSDKGetAllMissions == null)
		return;

	g_Catalog.Clear();
	g_Missions.Clear();
	g_MapIndex.Clear();

	SourceKeyValues root = SDKCall(g_hSDKGetAllMissions, g_pMatchExtL4D);
	if (root.IsNull())
		return;
	bool includeCurrentMode = IsSupportedMode()
		&& g_GameMode[0]
		&& !StrEqual(g_GameMode, "coop", false)
		&& !StrEqual(g_GameMode, "realism", false);

	for (SourceKeyValues mission = root.GetFirstTrueSubKey(); !mission.IsNull(); mission = mission.GetNextTrueSubKey())
	{
		MissionEntry missionEntry;
		mission.GetName(missionEntry.mission, sizeof(missionEntry.mission));
		if (IsExcludedMission(missionEntry.mission))
			continue;

		mission.GetString("DisplayTitle", missionEntry.missionName, sizeof(missionEntry.missionName), missionEntry.mission);
		missionEntry.official = mission.GetInt("builtin") != 0;

		if (includeCurrentMode)
			AddMissionModeToCatalog(mission, missionEntry, g_GameMode);
		AddMissionModeToCatalog(mission, missionEntry, "coop");
		AddMissionModeToCatalog(mission, missionEntry, "realism");
	}
}

void AddMissionModeToCatalog(SourceKeyValues mission, MissionEntry missionEntry, const char[] mode)
{
	char path[128];
	FormatEx(path, sizeof(path), "modes/%s", mode);
	SourceKeyValues chapters = mission.FindKey(path);
	if (chapters.IsNull())
		return;

	for (SourceKeyValues chapter = chapters.GetFirstTrueSubKey(); !chapter.IsNull(); chapter = chapter.GetNextTrueSubKey())
	{
		MapEntry entry;
		chapter.GetString("Map", entry.map, sizeof(entry.map), "");
		if (!entry.map[0] || FindCharInString(entry.map, '/') != -1)
			continue;

		strcopy(entry.mission, sizeof(entry.mission), missionEntry.mission);
		strcopy(entry.missionName, sizeof(entry.missionName), missionEntry.missionName);
		chapter.GetString("DisplayName", entry.chapterName, sizeof(entry.chapterName), entry.map);
		entry.official = missionEntry.official;
		entry.ambiguous = false;
		entry.installed = IsMapInstalled(entry.map);
		AddCatalogEntry(entry, missionEntry);
	}
}

void AddCatalogEntry(MapEntry entry, MissionEntry missionEntry)
{
	char key[MAP_NAME_LENGTH];
	strcopy(key, sizeof(key), entry.map);
	StringToLower(key);

	int existingIndex;
	if (g_MapIndex.GetValue(key, existingIndex))
	{
		if (existingIndex < 0)
			return;

		MapEntry existing;
		g_Catalog.GetArray(existingIndex, existing);
		if (StrEqual(existing.mission, entry.mission, false))
			return;

		existing.ambiguous = true;
		g_Catalog.SetArray(existingIndex, existing);
		g_MapIndex.SetValue(key, -1, true);
		return;
	}

	int index = g_Catalog.PushArray(entry);
	g_MapIndex.SetValue(key, index, true);

	if (FindMissionIndex(missionEntry.mission) == -1)
		g_Missions.PushArray(missionEntry);
}

int FindMissionIndex(const char[] mission)
{
	MissionEntry entry;
	for (int i = 0; i < g_Missions.Length; i++)
	{
		g_Missions.GetArray(i, entry);
		if (StrEqual(entry.mission, mission, false))
			return i;
	}
	return -1;
}

bool IsExcludedMission(const char[] mission)
{
	return StrEqual(mission, "credits", false)
		|| StrEqual(mission, "HoldoutChallenge", false)
		|| StrEqual(mission, "HoldoutTraining", false)
		|| StrEqual(mission, "parishdash", false)
		|| StrEqual(mission, "shootzones", false);
}

bool ResolveMapArguments(const char[] args, ArrayList entries, char[] error, int errorLength)
{
	RebuildCatalog();

	int offset;
	char token[MAP_NAME_LENGTH];
	while (args[offset])
	{
		int consumed = BreakString(args[offset], token, sizeof(token));
		if (!token[0])
			break;

		MapEntry entry;
		if (!ResolveMapEntry(token, entry, error, errorLength))
			return false;
		entries.PushArray(entry);

		if (consumed == -1)
			break;
		offset += consumed;
	}

	if (entries.Length == 0)
	{
		strcopy(error, errorLength, "没有提供地图代码。");
		return false;
	}
	return true;
}

bool ResolvePendingHead(MapEntry resolved, char[] error, int errorLength)
{
	if (g_Queue.Length == 0)
	{
		strcopy(error, errorLength, "待执行列表为空。");
		return false;
	}

	RebuildCatalog();
	MapEntry entry;
	g_Queue.GetArray(0, entry);
	return ResolveMapEntry(entry.map, resolved, error, errorLength);
}

bool ResolveMapEntry(const char[] map, MapEntry entry, char[] error, int errorLength)
{
	char key[MAP_NAME_LENGTH];
	strcopy(key, sizeof(key), map);
	TrimString(key);
	StringToLower(key);

	int index;
	if (!g_MapIndex.GetValue(key, index))
	{
		FormatEx(error, errorLength, "地图 %s 不属于可识别的合作战役。", map);
		return false;
	}
	if (index < 0)
	{
		FormatEx(error, errorLength, "地图 %s 同时属于多个战役，无法确定战役。", map);
		return false;
	}

	g_Catalog.GetArray(index, entry);
	char found[MAP_NAME_LENGTH];
	if (FindMap(entry.map, found, sizeof(found)) != FindMap_Found)
	{
		FormatEx(error, errorLength, "地图 %s 的 BSP 不存在。", entry.map);
		return false;
	}
	return true;
}

bool IsMapInstalled(const char[] map)
{
	char found[MAP_NAME_LENGTH];
	return FindMap(map, found, sizeof(found)) == FindMap_Found;
}

int CountPendingMap(const char[] map)
{
	int count;
	MapEntry entry;
	for (int i = 0; i < g_Queue.Length; i++)
	{
		g_Queue.GetArray(i, entry);
		if (StrEqual(entry.map, map, false))
			count++;
	}
	return count;
}

void ShowMapTypeMenu(int client)
{
	RebuildCatalog();
	Menu menu = new Menu(MapTypeMenuHandler);
	menu.SetTitle("地图待办：选择地图类型");
	menu.AddItem("official", "官方战役", HasVisibleMapType(true) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	menu.AddItem("custom", "三方战役", HasVisibleMapType(false) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	menu.Display(client, MENU_TIME_FOREVER);
}

int MapTypeMenuHandler(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		char info[16];
		menu.GetItem(item, info, sizeof(info));
		g_MenuType[client] = StrEqual(info, "official") ? 1 : 0;
		ShowMissionMenu(client);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}

void ShowMissionMenu(int client)
{
	Menu menu = new Menu(MissionMenuHandler);
	menu.SetTitle(g_MenuType[client] ? "地图待办：选择官方战役" : "地图待办：选择三方战役");

	MissionEntry mission;
	char display[DISPLAY_NAME_LENGTH + MISSION_ID_LENGTH + 8];
	for (int i = 0; i < g_Missions.Length; i++)
	{
		g_Missions.GetArray(i, mission);
		if (mission.official != view_as<bool>(g_MenuType[client]) || !HasVisibleMission(mission.mission))
			continue;

		FormatMissionName(mission, client, display, sizeof(display));
		menu.AddItem(mission.mission, display);
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int MissionMenuHandler(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		menu.GetItem(item, g_MenuMission[client], sizeof(g_MenuMission[]));
		ShowChapterMenu(client);
	}
	else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
	{
		ShowMapTypeMenu(client);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}

void ShowChapterMenu(int client)
{
	Menu menu = new Menu(ChapterMenuHandler);

	char missionName[DISPLAY_NAME_LENGTH];
	GetMissionDisplayById(g_MenuMission[client], client, missionName, sizeof(missionName));
	menu.SetTitle("地图待办：%s - 选择章节", missionName);

	MapEntry entry;
	char chapter[DISPLAY_NAME_LENGTH];
	char display[DISPLAY_NAME_LENGTH + MAP_NAME_LENGTH + 8];
	for (int i = 0; i < g_Catalog.Length; i++)
	{
		g_Catalog.GetArray(i, entry);
		if (entry.ambiguous || !entry.installed || !StrEqual(entry.mission, g_MenuMission[client], false))
			continue;

		FormatChapterName(entry, client, chapter, sizeof(chapter));
		FormatEx(display, sizeof(display), "%s (%s)", chapter, entry.map);
		menu.AddItem(entry.map, display);
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int ChapterMenuHandler(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		char map[MAP_NAME_LENGTH];
		menu.GetItem(item, map, sizeof(map));
		SubmitOperation(client, QueueOperation_Add, map);
	}
	else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
	{
		ShowMissionMenu(client);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}

bool HasVisibleMapType(bool official)
{
	MissionEntry mission;
	for (int i = 0; i < g_Missions.Length; i++)
	{
		g_Missions.GetArray(i, mission);
		if (mission.official == official && HasVisibleMission(mission.mission))
			return true;
	}
	return false;
}

bool HasVisibleMission(const char[] mission)
{
	MapEntry entry;
	for (int i = 0; i < g_Catalog.Length; i++)
	{
		g_Catalog.GetArray(i, entry);
		if (!entry.ambiguous && entry.installed && StrEqual(entry.mission, mission, false))
			return true;
	}
	return false;
}

void FormatEntryDisplay(MapEntry entry, int client, char[] output, int outputLength)
{
	char mission[DISPLAY_NAME_LENGTH];
	char chapter[DISPLAY_NAME_LENGTH];
	FormatMapEntryMissionName(entry, client, mission, sizeof(mission));
	FormatChapterName(entry, client, chapter, sizeof(chapter));
	FormatEx(output, outputLength, "%s / %s (%s)", mission, chapter, entry.map);
}

void FormatMapEntryMissionName(MapEntry entry, int client, char[] output, int outputLength)
{
	if (TranslationPhraseExists(entry.mission))
		Format(output, outputLength, "%T", entry.mission, client);
	else if (entry.missionName[0] && entry.missionName[0] != '#')
		strcopy(output, outputLength, entry.missionName);
	else
		strcopy(output, outputLength, entry.mission);
}

void FormatMissionName(MissionEntry entry, int client, char[] output, int outputLength)
{
	if (TranslationPhraseExists(entry.mission))
		Format(output, outputLength, "%T", entry.mission, client);
	else if (entry.missionName[0] && entry.missionName[0] != '#')
		strcopy(output, outputLength, entry.missionName);
	else
		strcopy(output, outputLength, entry.mission);
}

void GetMissionDisplayById(const char[] missionId, int client, char[] output, int outputLength)
{
	int index = FindMissionIndex(missionId);
	if (index == -1)
	{
		strcopy(output, outputLength, missionId);
		return;
	}

	MissionEntry mission;
	g_Missions.GetArray(index, mission);
	FormatMissionName(mission, client, output, outputLength);
}

void FormatChapterName(MapEntry entry, int client, char[] output, int outputLength)
{
	if (TranslationPhraseExists(entry.map))
		Format(output, outputLength, "%T", entry.map, client);
	else if (entry.chapterName[0] && entry.chapterName[0] != '#')
		strcopy(output, outputLength, entry.chapterName);
	else
		strcopy(output, outputLength, entry.map);
}

void TakeQueueSnapshot(QueueSnapshot snapshot)
{
	snapshot.queue = g_Queue.Clone();
	CopyMapEntry(g_Active, snapshot.active);
	snapshot.hasActive = g_HasActive;
	snapshot.state = g_State;
}

bool CommitQueueMutation(QueueSnapshot snapshot, char[] error, int errorLength)
{
	if (SaveQueueState())
	{
		delete snapshot.queue;
		return true;
	}

	delete g_Queue;
	g_Queue = snapshot.queue;
	snapshot.queue = null;
	CopyMapEntry(snapshot.active, g_Active);
	g_HasActive = snapshot.hasActive;
	g_State = snapshot.state;
	strcopy(error, errorLength, "无法写入持久化文件，操作已回滚。");
	return false;
}

void PrependQueueEntry(MapEntry entry)
{
	int index = g_Queue.PushArray(entry);
	for (int i = index; i > 0; i--)
		g_Queue.SwapAt(i, i - 1);
}

void CopyMapEntry(MapEntry source, MapEntry target)
{
	strcopy(target.map, sizeof(target.map), source.map);
	strcopy(target.mission, sizeof(target.mission), source.mission);
	strcopy(target.missionName, sizeof(target.missionName), source.missionName);
	strcopy(target.chapterName, sizeof(target.chapterName), source.chapterName);
	target.official = source.official;
	target.ambiguous = source.ambiguous;
	target.installed = source.installed;
}

void ClearMapEntry(MapEntry entry)
{
	entry.map[0] = '\0';
	entry.mission[0] = '\0';
	entry.missionName[0] = '\0';
	entry.chapterName[0] = '\0';
	entry.official = false;
	entry.ambiguous = false;
	entry.installed = false;
}

bool SaveQueueState()
{
	KeyValues kv = new KeyValues("MapQueue");
	kv.SetNum("version", DATA_VERSION);
	char stateName[16];
	GetQueueStateName(g_State, stateName, sizeof(stateName));
	kv.SetString("state", stateName);

	if (g_HasActive)
	{
		kv.JumpToKey("active", true);
		WriteEntryToKeyValues(kv, g_Active);
		kv.GoBack();
	}

	kv.JumpToKey("queue", true);
	MapEntry entry;
	char key[16];
	for (int i = 0; i < g_Queue.Length; i++)
	{
		g_Queue.GetArray(i, entry);
		FormatEx(key, sizeof(key), "%06d", i);
		kv.JumpToKey(key, true);
		WriteEntryToKeyValues(kv, entry);
		kv.GoBack();
	}
	kv.Rewind();

	if (FileExists(g_TempPath) && !DeleteFile(g_TempPath))
	{
		delete kv;
		LogError("Cannot remove stale map queue temp file: %s", g_TempPath);
		return false;
	}

	bool exported = kv.ExportToFile(g_TempPath);
	delete kv;
	if (!exported)
	{
		LogError("Cannot export map queue temp file: %s", g_TempPath);
		return false;
	}

	if (!ReplaceDataFile())
	{
		DeleteFile(g_TempPath);
		return false;
	}
	return true;
}

bool ReplaceDataFile()
{
	bool hadOriginal = FileExists(g_DataPath);
	bool hasBackup = FileExists(g_BackupPath);
	if (hadOriginal)
	{
		if (hasBackup && !DeleteFile(g_BackupPath))
		{
			LogError("Cannot remove stale map queue backup: %s", g_BackupPath);
			return false;
		}
		if (!RenameFile(g_BackupPath, g_DataPath))
		{
			LogError("Cannot move map queue data file to backup: %s", g_DataPath);
			return false;
		}
		hasBackup = true;
	}

	if (!RenameFile(g_DataPath, g_TempPath))
	{
		LogError("Cannot move map queue temp file into place: %s", g_DataPath);
		if (hasBackup && !FileExists(g_DataPath) && !RenameFile(g_DataPath, g_BackupPath))
			LogError("Cannot restore map queue backup: %s", g_BackupPath);
		return false;
	}

	if (FileExists(g_BackupPath) && !DeleteFile(g_BackupPath))
		LogError("Cannot remove map queue backup after replacement: %s", g_BackupPath);
	return true;
}

void WriteEntryToKeyValues(KeyValues kv, MapEntry entry)
{
	kv.SetString("map", entry.map);
	kv.SetString("mission", entry.mission);
	kv.SetString("mission_name", entry.missionName);
	kv.SetString("chapter_name", entry.chapterName);
	kv.SetNum("official", entry.official ? 1 : 0);
}

void LoadQueueState()
{
	g_Queue.Clear();
	g_HasActive = false;
	ClearMapEntry(g_Active);
	g_State = QueueState_Stopped;

	bool loadedBackup;
	if (!LoadQueueFile(g_DataPath))
	{
		if (!LoadQueueFile(g_BackupPath))
			return;
		loadedBackup = true;
	}

	if (g_HasActive)
		RequeueActiveInMemory();
	g_State = QueueState_Stopped;

	if (loadedBackup && FileExists(g_DataPath) && !DeleteFile(g_DataPath))
	{
		LogError("Recovered map queue backup but cannot remove the invalid primary data file.");
		return;
	}

	if (!SaveQueueState())
		LogError("Loaded map queue state but failed to normalize the recovery file.");
}

bool LoadQueueFile(const char[] path)
{
	if (!FileExists(path))
		return false;

	KeyValues kv = new KeyValues("MapQueue");
	if (!kv.ImportFromFile(path))
	{
		delete kv;
		LogError("Cannot parse map queue data file: %s", path);
		return false;
	}

	if (kv.JumpToKey("active"))
	{
		MapEntry active;
		if (ReadEntryFromKeyValues(kv, active))
		{
			CopyMapEntry(active, g_Active);
			g_HasActive = true;
		}
		kv.Rewind();
	}

	if (kv.JumpToKey("queue"))
	{
		if (kv.GotoFirstSubKey())
		{
			do
			{
				MapEntry entry;
				if (ReadEntryFromKeyValues(kv, entry))
					g_Queue.PushArray(entry);
			}
			while (kv.GotoNextKey());
		}
	}

	delete kv;
	return true;
}

bool ReadEntryFromKeyValues(KeyValues kv, MapEntry entry)
{
	ClearMapEntry(entry);
	kv.GetString("map", entry.map, sizeof(entry.map));
	if (!entry.map[0])
		return false;

	kv.GetString("mission", entry.mission, sizeof(entry.mission));
	kv.GetString("mission_name", entry.missionName, sizeof(entry.missionName));
	kv.GetString("chapter_name", entry.chapterName, sizeof(entry.chapterName));
	entry.official = kv.GetNum("official") != 0;
	return true;
}

void RefreshMapChangerConVars()
{
	if (!LibraryExists("map_changer"))
		return;

	ConVar type = FindConVar("mapchanger_finale_change_type");
	ConVar failures = FindConVar("mapchanger_finale_failure_count");
	if (type == null || failures == null)
		return;

	if (!g_MapChangerHooksInstalled || type != g_cvMapChangerType || failures != g_cvMapChangerFailures)
	{
		RemoveMapChangerHooks();
		g_cvMapChangerType = type;
		g_cvMapChangerFailures = failures;
		g_cvMapChangerType.AddChangeHook(Cvar_MapChangerChanged);
		g_cvMapChangerFailures.AddChangeHook(Cvar_MapChangerChanged);
		g_MapChangerHooksInstalled = true;
	}
}

void RemoveMapChangerHooks()
{
	if (g_MapChangerHooksInstalled)
	{
		if (g_cvMapChangerType != null)
			g_cvMapChangerType.RemoveChangeHook(Cvar_MapChangerChanged);
		if (g_cvMapChangerFailures != null)
			g_cvMapChangerFailures.RemoveChangeHook(Cvar_MapChangerChanged);
	}
	g_MapChangerHooksInstalled = false;
	g_cvMapChangerType = null;
	g_cvMapChangerFailures = null;
}

void SyncMapChangerControl()
{
	if (IsAutomationActive() && g_cvEnable.BoolValue)
		AcquireMapChangerControl();
	else
		ReleaseMapChangerControl();
}

void AcquireMapChangerControl()
{
	if (g_MapChangerTakenOver)
		return;

	RefreshMapChangerConVars();
	if (g_cvMapChangerType == null || g_cvMapChangerFailures == null)
		return;

	g_cvMapChangerType.GetString(g_SavedMapChangerType, sizeof(g_SavedMapChangerType));
	g_cvMapChangerFailures.GetString(g_SavedMapChangerFailures, sizeof(g_SavedMapChangerFailures));
	g_MapChangerTakenOver = true;
	g_InternalMapChangerChange = true;
	g_cvMapChangerType.SetString("0");
	g_cvMapChangerFailures.SetString("0");
	g_InternalMapChangerChange = false;
}

void ReleaseMapChangerControl()
{
	if (!g_MapChangerTakenOver)
		return;

	g_InternalMapChangerChange = true;
	if (g_cvMapChangerType != null)
		g_cvMapChangerType.SetString(g_SavedMapChangerType);
	if (g_cvMapChangerFailures != null)
		g_cvMapChangerFailures.SetString(g_SavedMapChangerFailures);
	g_InternalMapChangerChange = false;
	g_MapChangerTakenOver = false;
}

void Cvar_MapChangerChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!g_MapChangerTakenOver || g_InternalMapChangerChange)
		return;

	if (convar == g_cvMapChangerType)
		strcopy(g_SavedMapChangerType, sizeof(g_SavedMapChangerType), newValue);
	else if (convar == g_cvMapChangerFailures)
		strcopy(g_SavedMapChangerFailures, sizeof(g_SavedMapChangerFailures), newValue);

	g_InternalMapChangerChange = true;
	convar.SetString("0");
	g_InternalMapChangerChange = false;
}

void StringToLower(char[] value)
{
	for (int i = 0; value[i]; i++)
		value[i] = CharToLower(value[i]);
}
