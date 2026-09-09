#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION             "1.0.1"
#define PLUGIN_CONFIG              "l4d2_witch_kill_chain"

#define TEAM_SURVIVOR              2
#define MAX_ENTITY_INDEX           2048

#define MIN_RANDOM_INTERVAL        2.0
#define MAX_CONFIG_INTERVAL        13.0
#define BURN_TIME_MARGIN           0.1
#define MIN_TIMER_INTERVAL         0.1

ConVar g_cvEnable;
ConVar g_cvInterval;
ConVar g_cvRandom;
ConVar g_cvBurnTime;

bool g_bEnabled;
bool g_bRandom;
bool g_bUnsafeIntervalWarned;
float g_fInterval;

Handle g_hRetargetTimer[MAX_ENTITY_INDEX + 1];
int g_iCurrentTargetSerial[MAX_ENTITY_INDEX + 1];
bool g_bActive[MAX_ENTITY_INDEX + 1];
bool g_bApplyingFakeBurn[MAX_ENTITY_INDEX + 1];
bool g_bThinkCleanupHooked[MAX_ENTITY_INDEX + 1];

public Plugin myinfo =
{
	name = "危险女人(witch善变连杀)",
	author = "laoyutang",
	description = "惊扰后的 Witch 定时或击倒后改追最近的活动生还者",
	version = PLUGIN_VERSION,
	url = "N/A"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int errMax)
{
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, errMax, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar(
		"l4d2_witch_kill_chain_version",
		PLUGIN_VERSION,
		"危险女人(witch善变连杀) 插件版本.",
		FCVAR_NOTIFY | FCVAR_DONTRECORD
	);

	g_cvEnable = CreateConVar(
		"l4d2_witch_kill_chain_enable",
		"1",
		"是否启用危险女人(witch善变连杀). 0=禁用, 1=启用.",
		FCVAR_NOTIFY,
		true,
		0.0,
		true,
		1.0
	);

	g_cvInterval = CreateConVar(
		"l4d2_witch_kill_chain_interval",
		"6.0",
		"Witch 换目标的固定间隔或随机上限（秒）.",
		FCVAR_NOTIFY,
		true,
		MIN_RANDOM_INTERVAL,
		true,
		MAX_CONFIG_INTERVAL
	);

	g_cvRandom = CreateConVar(
		"l4d2_witch_kill_chain_random",
		"1",
		"换目标间隔模式. 0=固定间隔, 1=在2秒到有效上限之间每轮重新随机.",
		FCVAR_NOTIFY,
		true,
		0.0,
		true,
		1.0
	);

	g_cvBurnTime = FindConVar("z_witch_burn_time");
	if (g_cvBurnTime == null)
	{
		SetFailState("Unable to find ConVar 'z_witch_burn_time'.");
		return;
	}

	g_cvEnable.AddChangeHook(ConVarChanged_Settings);
	g_cvInterval.AddChangeHook(ConVarChanged_Settings);
	g_cvRandom.AddChangeHook(ConVarChanged_Settings);
	g_cvBurnTime.AddChangeHook(ConVarChanged_Settings);

	HookEvent("witch_spawn", Event_WitchSpawn);
	HookEvent("witch_harasser_set", Event_WitchHarasserSet);
	HookEvent("witch_killed", Event_WitchKilled);
	HookEvent("player_incapacitated", Event_PlayerIncapacitated);
	HookEvent("player_death", Event_PlayerDeath);

	HookEvent("round_start", Event_ResetAll, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_ResetAll, EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_ResetAll, EventHookMode_PostNoCopy);
	HookEvent("mission_lost", Event_ResetAll, EventHookMode_PostNoCopy);
	HookEvent("finale_vehicle_leaving", Event_ResetAll, EventHookMode_PostNoCopy);

	ReadSettings();
	AutoExecConfig(true, PLUGIN_CONFIG);
}

public void OnConfigsExecuted()
{
	ReadSettings();
}

public void OnMapEnd()
{
	ResetAllWitches();
}

public void OnPluginEnd()
{
	ResetAllWitches();
}

public void OnEntityDestroyed(int entity)
{
	if (!IsTrackableEntityIndex(entity))
	{
		return;
	}

	if (g_bActive[entity]
		|| g_hRetargetTimer[entity] != null
		|| g_bApplyingFakeBurn[entity]
		|| g_bThinkCleanupHooked[entity])
	{
		ResetWitchState(entity, false);
	}
}

public void ConVarChanged_Settings(ConVar convar, const char[] oldValue, const char[] newValue)
{
	bool wasEnabled = g_bEnabled;
	ReadSettings();

	if (!g_bEnabled)
	{
		CancelAllRetargetTimers();
		return;
	}

	if (!wasEnabled || convar == g_cvInterval || convar == g_cvRandom || convar == g_cvBurnTime)
	{
		RefreshAndRearmActiveWitches();
	}
}

public void Event_WitchSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int witch = event.GetInt("witchid");
	if (!IsTrackableEntityIndex(witch))
	{
		return;
	}

	ResetWitchState(witch, true);
}

public void Event_WitchHarasserSet(Event event, const char[] name, bool dontBroadcast)
{
	int witch = event.GetInt("witchid");
	if (!IsValidWitch(witch) || g_bApplyingFakeBurn[witch])
	{
		return;
	}

	int target = GetClientOfUserId(event.GetInt("userid"));
	g_bActive[witch] = true;

	if (IsSurvivor(target))
	{
		g_iCurrentTargetSerial[witch] = GetClientSerial(target);
	}

	if (g_bEnabled && g_hRetargetTimer[witch] == null)
	{
		ArmRetargetTimer(witch);
	}
}

public void Event_WitchKilled(Event event, const char[] name, bool dontBroadcast)
{
	int witch = event.GetInt("witchid");
	if (IsTrackableEntityIndex(witch))
	{
		ResetWitchState(witch, true);
	}
}

public void Event_PlayerIncapacitated(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int witch = event.GetInt("attackerentid");

	if (!IsValidWitch(witch) || !IsSurvivor(victim))
	{
		return;
	}

	// 此事件本身足以证明 Witch 已进入攻击状态，也可兼容插件中途加载后首次击倒。
	g_bActive[witch] = true;
	if (g_iCurrentTargetSerial[witch] == 0)
	{
		g_iCurrentTargetSerial[witch] = GetClientSerial(victim);
	}

	if (g_bEnabled)
	{
		RetargetImmediately(witch);
	}
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int witch = event.GetInt("attackerentid");

	if (!IsValidWitch(witch) || !g_bActive[witch] || !IsSurvivor(victim))
	{
		return;
	}

	// 已经在击倒事件中换过目标时，当前目标序列号不会再等于这个死者。
	if (g_iCurrentTargetSerial[witch] != GetClientSerial(victim))
	{
		return;
	}

	if (g_bEnabled)
	{
		RetargetImmediately(witch);
	}
}

public void Event_ResetAll(Event event, const char[] name, bool dontBroadcast)
{
	ResetAllWitches();
}

public Action Timer_Retarget(Handle timer, DataPack pack)
{
	pack.Reset();
	int slot = pack.ReadCell();
	int witchRef = pack.ReadCell();

	if (IsTrackableEntityIndex(slot) && g_hRetargetTimer[slot] == timer)
	{
		g_hRetargetTimer[slot] = null;
	}

	int witch = EntRefToEntIndex(witchRef);
	if (witch == INVALID_ENT_REFERENCE
		|| witch != slot
		|| !g_bEnabled
		|| !g_bActive[slot]
		|| !IsValidWitch(witch))
	{
		return Plugin_Stop;
	}

	RetargetOrRefresh(witch);

	if (g_bEnabled && g_bActive[witch] && IsValidWitch(witch))
	{
		ArmRetargetTimer(witch);
	}

	return Plugin_Stop;
}

public void OnWitchThinkPost(int witch)
{
	if (!IsTrackableEntityIndex(witch))
	{
		return;
	}

	if (g_bThinkCleanupHooked[witch])
	{
		SDKUnhook(witch, SDKHook_ThinkPost, OnWitchThinkPost);
		g_bThinkCleanupHooked[witch] = false;
	}

	if (IsValidWitch(witch))
	{
		ClearVisibleFire(witch);
	}
}

void ReadSettings()
{
	g_bEnabled = g_cvEnable.BoolValue;
	g_bRandom = g_cvRandom.BoolValue;
	g_fInterval = g_cvInterval.FloatValue;

	if (g_fInterval < MIN_RANDOM_INTERVAL)
	{
		g_fInterval = MIN_RANDOM_INTERVAL;
	}
	else if (g_fInterval > MAX_CONFIG_INTERVAL)
	{
		g_fInterval = MAX_CONFIG_INTERVAL;
	}
}

void RetargetImmediately(int witch)
{
	CancelRetargetTimer(witch);
	RetargetOrRefresh(witch);

	if (g_bEnabled && g_bActive[witch] && IsValidWitch(witch))
	{
		ArmRetargetTimer(witch);
	}
}

bool RetargetOrRefresh(int witch)
{
	int currentTarget = GetTrackedTarget(witch);
	int target = FindNearestActiveSurvivor(witch, currentTarget);

	// 只有当前目标仍然有效且场上无人可换时，才重新伪点燃当前目标。
	if (target == 0 && IsActiveSurvivor(currentTarget))
	{
		target = currentTarget;
	}

	if (target == 0)
	{
		return false;
	}

	return ApplyFakeBurnTarget(witch, target);
}

bool ApplyFakeBurnTarget(int witch, int target)
{
	if (!IsValidWitch(witch) || !IsActiveSurvivor(target))
	{
		return false;
	}

	int witchRef = EntIndexToEntRef(witch);
	int sequence = GetEntProp(witch, Prop_Send, "m_nSequence");

	ClearVisibleFire(witch);

	g_bApplyingFakeBurn[witch] = true;
	SDKHooks_TakeDamage(witch, target, target, 0.0, DMG_BURN);
	g_bApplyingFakeBurn[witch] = false;

	if (EntRefToEntIndex(witchRef) != witch || !IsValidWitch(witch))
	{
		return false;
	}

	SetEntProp(witch, Prop_Send, "m_nSequence", sequence);
	SetEntProp(witch, Prop_Send, "m_bIsBurning", 0);
	g_iCurrentTargetSerial[witch] = GetClientSerial(target);

	if (!g_bThinkCleanupHooked[witch])
	{
		SDKHook(witch, SDKHook_ThinkPost, OnWitchThinkPost);
		g_bThinkCleanupHooked[witch] = true;
	}

	return true;
}

void ClearVisibleFire(int witch)
{
	if (!IsValidWitch(witch))
	{
		return;
	}

	ExtinguishEntity(witch);
	SetEntProp(witch, Prop_Send, "m_bIsBurning", 0);

	int flame = GetEntPropEnt(witch, Prop_Send, "m_hEffectEntity");
	if (flame > MaxClients && IsValidEntity(flame))
	{
		AcceptEntityInput(flame, "Kill");
	}
}

int FindNearestActiveSurvivor(int witch, int excludedTarget)
{
	float witchOrigin[3];
	float targetOrigin[3];
	int candidates[MAXPLAYERS + 1];
	float distances[MAXPLAYERS + 1];
	int candidateCount;

	GetEntPropVector(witch, Prop_Send, "m_vecOrigin", witchOrigin);

	for (int client = 1; client <= MaxClients; client++)
	{
		if (client == excludedTarget || !IsActiveSurvivor(client))
		{
			continue;
		}

		GetClientAbsOrigin(client, targetOrigin);
		candidates[candidateCount] = client;
		distances[candidateCount] = GetVectorDistance(witchOrigin, targetOrigin, true);
		candidateCount++;
	}

	// 候选人数最多为 MaxClients，使用插入排序后可从最近者开始检测并尽早停止。
	for (int i = 1; i < candidateCount; i++)
	{
		int sortedClient = candidates[i];
		float sortedDistance = distances[i];
		int j = i - 1;

		while (j >= 0 && distances[j] > sortedDistance)
		{
			candidates[j + 1] = candidates[j];
			distances[j + 1] = distances[j];
			j--;
		}

		candidates[j + 1] = sortedClient;
		distances[j + 1] = sortedDistance;
	}

	for (int i = 0; i < candidateCount; i++)
	{
		if (IsVisibleToWitch(witch, candidates[i]))
		{
			return candidates[i];
		}
	}

	return 0;
}

bool IsVisibleToWitch(int witch, int target)
{
	float start[3];
	float end[3];

	GetEntPropVector(witch, Prop_Send, "m_vecOrigin", start);
	start[2] += 50.0;
	GetClientEyePosition(target, end);

	Handle trace = TR_TraceRayFilterEx(
		start,
		end,
		MASK_PLAYERSOLID,
		RayType_EndPoint,
		TraceFilter_Visibility,
		target
	);

	if (trace == null)
	{
		return false;
	}

	bool visible = !TR_DidHit(trace) || TR_GetEntityIndex(trace) == target;
	delete trace;
	return visible;
}

public bool TraceFilter_Visibility(int entity, int contentsMask, any target)
{
	if (entity == target)
	{
		return true;
	}

	if (entity >= 1 && entity <= MaxClients)
	{
		return false;
	}

	if (entity > MaxClients && IsValidEntity(entity))
	{
		char classname[16];
		GetEntityClassname(entity, classname, sizeof(classname));

		if (StrEqual(classname, "infected") || StrEqual(classname, "witch"))
		{
			return false;
		}
	}

	return true;
}

int GetTrackedTarget(int witch)
{
	if (!IsTrackableEntityIndex(witch) || g_iCurrentTargetSerial[witch] == 0)
	{
		return 0;
	}

	return GetClientFromSerial(g_iCurrentTargetSerial[witch]);
}

bool IsActiveSurvivor(int client)
{
	if (!IsSurvivor(client) || !IsPlayerAlive(client))
	{
		return false;
	}

	if (GetEntProp(client, Prop_Send, "m_isIncapacitated") != 0
		|| GetEntProp(client, Prop_Send, "m_isHangingFromLedge") != 0
		|| GetEntProp(client, Prop_Send, "m_isFallingFromLedge") != 0)
	{
		return false;
	}

	return true;
}

bool IsSurvivor(int client)
{
	return client >= 1
		&& client <= MaxClients
		&& IsClientInGame(client)
		&& GetClientTeam(client) == TEAM_SURVIVOR;
}

bool IsValidWitch(int entity)
{
	if (!IsTrackableEntityIndex(entity) || !IsValidEntity(entity))
	{
		return false;
	}

	char classname[16];
	GetEntityClassname(entity, classname, sizeof(classname));
	if (!StrEqual(classname, "witch"))
	{
		return false;
	}

	return GetEntProp(entity, Prop_Data, "m_iHealth") > 0;
}

bool IsTrackableEntityIndex(int entity)
{
	return entity > MaxClients && entity <= MAX_ENTITY_INDEX;
}

void ArmRetargetTimer(int witch)
{
	CancelRetargetTimer(witch);

	float delay;
	if (!GetNextDelay(delay))
	{
		return;
	}

	DataPack pack;
	Handle timer = CreateDataTimer(delay, Timer_Retarget, pack, TIMER_FLAG_NO_MAPCHANGE);
	if (timer == null)
	{
		delete pack;
		LogError("Unable to create retarget timer for Witch entity %d.", witch);
		return;
	}

	pack.WriteCell(witch);
	pack.WriteCell(EntIndexToEntRef(witch));
	g_hRetargetTimer[witch] = timer;
}

bool GetNextDelay(float &delay)
{
	float burnTime = g_cvBurnTime.FloatValue;
	float safeBurnMaximum = burnTime - BURN_TIME_MARGIN;
	float effectiveMaximum = g_fInterval < safeBurnMaximum ? g_fInterval : safeBurnMaximum;

	if (effectiveMaximum < MIN_TIMER_INTERVAL)
	{
		if (!g_bUnsafeIntervalWarned)
		{
			LogError(
				"z_witch_burn_time %.3f is too short to schedule a safe retarget timer; Witch retarget cycling is paused.",
				burnTime
			);
			g_bUnsafeIntervalWarned = true;
		}

		return false;
	}

	g_bUnsafeIntervalWarned = false;

	if (g_bRandom && effectiveMaximum > MIN_RANDOM_INTERVAL)
	{
		delay = GetRandomFloat(MIN_RANDOM_INTERVAL, effectiveMaximum);
	}
	else
	{
		delay = effectiveMaximum;
	}

	return true;
}

void RefreshAndRearmActiveWitches()
{
	for (int witch = MaxClients + 1; witch <= MAX_ENTITY_INDEX; witch++)
	{
		if (!g_bActive[witch])
		{
			continue;
		}

		CancelRetargetTimer(witch);
		if (!IsValidWitch(witch))
		{
			ResetWitchState(witch, false);
			continue;
		}

		RetargetOrRefresh(witch);
		if (g_bActive[witch] && IsValidWitch(witch))
		{
			ArmRetargetTimer(witch);
		}
	}
}

void CancelRetargetTimer(int witch)
{
	if (IsTrackableEntityIndex(witch))
	{
		delete g_hRetargetTimer[witch];
	}
}

void CancelAllRetargetTimers()
{
	for (int witch = MaxClients + 1; witch <= MAX_ENTITY_INDEX; witch++)
	{
		delete g_hRetargetTimer[witch];
	}
}

void ResetWitchState(int witch, bool unhookThink)
{
	if (!IsTrackableEntityIndex(witch))
	{
		return;
	}

	delete g_hRetargetTimer[witch];

	if (unhookThink && g_bThinkCleanupHooked[witch] && IsValidEntity(witch))
	{
		SDKUnhook(witch, SDKHook_ThinkPost, OnWitchThinkPost);
	}

	g_iCurrentTargetSerial[witch] = 0;
	g_bActive[witch] = false;
	g_bApplyingFakeBurn[witch] = false;
	g_bThinkCleanupHooked[witch] = false;
}

void ResetAllWitches()
{
	for (int witch = MaxClients + 1; witch <= MAX_ENTITY_INDEX; witch++)
	{
		if (g_bActive[witch]
			|| g_hRetargetTimer[witch] != null
			|| g_bApplyingFakeBurn[witch]
			|| g_bThinkCleanupHooked[witch])
		{
			ResetWitchState(witch, true);
		}
	}
}
