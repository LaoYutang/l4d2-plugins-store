#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define PLUGIN_VERSION "1.4.0"

#define TEAM_SURVIVOR 2

// Delay before recounting, so the game has settled after the triggering event.
#define DIFFICULTY_DELAY 3.0

public Plugin myinfo =
{
	name = "[L4D, L4D2] Common Infected Regulator",
	author = "chinagreenelvis, laoyutang",
	description = "Decrease or increase infected numbers based on number of living survivors",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net"
};

ConVar g_cvRegulator;
ConVar g_cvCommons;
ConVar g_cvCommonsPerPlayer;
ConVar g_cvCommonsBackground;
ConVar g_cvCommonsBackgroundPerPlayer;
ConVar g_cvMegamob;
ConVar g_cvMegamobPerPlayer;
ConVar g_cvMobMin;
ConVar g_cvMobMinPerPlayer;
ConVar g_cvMobMax;
ConVar g_cvMobMaxPerPlayer;

ConVar g_cvCommonLimit;
ConVar g_cvBackgroundLimit;
ConVar g_cvMegaMobSize;
ConVar g_cvMobMinNotify;
ConVar g_cvMobSpawnMin;
ConVar g_cvMobSpawnMax;

bool g_bEnabled;
bool g_bSetPending;
bool g_bCheckPending;

public void OnPluginStart()
{
	g_cvRegulator = CreateConVar("commonregulator", "1", "Allow common infected regulation? 1: Yes, 0: No", FCVAR_SPONLY|FCVAR_NOTIFY);
	g_cvCommons = CreateConVar("commonregulator_commons", "30", "Common infected limit for four or fewer players", FCVAR_SPONLY|FCVAR_NOTIFY);
	g_cvCommonsPerPlayer = CreateConVar("commonregulator_commons_perplayer", "8", "Additional common infected limit per survivor above four", FCVAR_SPONLY|FCVAR_NOTIFY);
	g_cvCommonsBackground = CreateConVar("commonregulator_commons_background", "20", "Background number of common infected for four or fewer players", FCVAR_SPONLY|FCVAR_NOTIFY);
	g_cvCommonsBackgroundPerPlayer = CreateConVar("commonregulator_commons_background_perplayer", "5", "Additional background number of common infected per survivor above four", FCVAR_SPONLY|FCVAR_NOTIFY);
	g_cvMegamob = CreateConVar("commonregulator_megamob", "50", "Mega-mob size for four or fewer players", FCVAR_SPONLY|FCVAR_NOTIFY);
	g_cvMegamobPerPlayer = CreateConVar("commonregulator_megamob_perplayer", "13", "Additional mega-mob size per survivor above four", FCVAR_SPONLY|FCVAR_NOTIFY);
	g_cvMobMin = CreateConVar("commonregulator_mobmin", "10", "Minimum mob spawn size for four or fewer players", FCVAR_SPONLY|FCVAR_NOTIFY);
	g_cvMobMinPerPlayer = CreateConVar("commonregulator_mobmin_perplayer", "3", "Additional minimum mob spawn size per survivor above four", FCVAR_SPONLY|FCVAR_NOTIFY);
	g_cvMobMax = CreateConVar("commonregulator_mobmax", "30", "Maximum mob spawn size for four or fewer players", FCVAR_SPONLY|FCVAR_NOTIFY);
	g_cvMobMaxPerPlayer = CreateConVar("commonregulator_mobmax_perplayer", "8", "Additional maximum mob spawn size per survivor above four", FCVAR_SPONLY|FCVAR_NOTIFY);

	AutoExecConfig(true, "cge_l4d2_commonregulator");

	CacheEngineConVars();

	HookEvent("player_first_spawn", Event_PlayerFirstSpawn);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("survivor_rescued", Event_SurvivorRescued);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("mission_lost", Event_MissionLost);
}

public void OnMapEnd()
{
	g_bEnabled = false;
	g_bSetPending = false;
	g_bCheckPending = false;
}

public void Event_PlayerFirstSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (IsRealClient(GetClientOfUserId(event.GetInt("userid"))))
	{
		RequestDifficultySet();
	}
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (!IsRealClient(GetClientOfUserId(event.GetInt("userid"))))
	{
		return;
	}

	if (g_bEnabled)
	{
		RequestDifficultyCheck();
	}
	else
	{
		RequestDifficultySet();
	}
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (g_bEnabled)
	{
		RequestDifficultyCheck();
	}
}

public void Event_SurvivorRescued(Event event, const char[] name, bool dontBroadcast)
{
	if (g_bEnabled)
	{
		RequestDifficultyCheck();
	}
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	if (g_bEnabled)
	{
		RequestDifficultyCheck();
	}
}

public void Event_MissionLost(Event event, const char[] name, bool dontBroadcast)
{
	RequestDifficultySet();
}

void RequestDifficultySet()
{
	if (g_bSetPending)
	{
		return;
	}

	g_bSetPending = true;
	CreateTimer(DIFFICULTY_DELAY, Timer_DifficultySet, _, TIMER_FLAG_NO_MAPCHANGE);
}

void RequestDifficultyCheck()
{
	if (g_bCheckPending)
	{
		return;
	}

	g_bCheckPending = true;
	CreateTimer(DIFFICULTY_DELAY, Timer_DifficultyCheck, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_DifficultySet(Handle timer)
{
	g_bSetPending = false;

	if (!g_cvRegulator.BoolValue || !HasRealSurvivor())
	{
		return Plugin_Stop;
	}

	int survivors = CountSurvivors(false);
	if (survivors > 0)
	{
		ApplyDifficulty(survivors);
		g_bEnabled = true;
	}

	return Plugin_Stop;
}

public Action Timer_DifficultyCheck(Handle timer)
{
	g_bCheckPending = false;

	if (!g_bEnabled || !g_cvRegulator.BoolValue)
	{
		return Plugin_Stop;
	}

	int survivors = CountSurvivors(true);
	if (survivors > 0)
	{
		ApplyDifficulty(survivors);
	}

	return Plugin_Stop;
}

void ApplyDifficulty(int survivors)
{
	SetEngineValue(g_cvCommonLimit, ScaleForSurvivors(g_cvCommons.IntValue, g_cvCommonsPerPlayer.IntValue, survivors));
	SetEngineValue(g_cvBackgroundLimit, ScaleForSurvivors(g_cvCommonsBackground.IntValue, g_cvCommonsBackgroundPerPlayer.IntValue, survivors));
	SetEngineValue(g_cvMegaMobSize, ScaleForSurvivors(g_cvMegamob.IntValue, g_cvMegamobPerPlayer.IntValue, survivors));
	SetEngineValue(g_cvMobMinNotify, ScaleForSurvivors(g_cvMobMin.IntValue, g_cvMobMinPerPlayer.IntValue, survivors));
	SetEngineValue(g_cvMobSpawnMin, ScaleForSurvivors(g_cvMobMin.IntValue, g_cvMobMinPerPlayer.IntValue, survivors));
	SetEngineValue(g_cvMobSpawnMax, ScaleForSurvivors(g_cvMobMax.IntValue, g_cvMobMaxPerPlayer.IntValue, survivors));
}

// The configured value covers four or fewer survivors; every survivor above four
// adds the configured per-player amount. A negative per-player value counts as 0.
int ScaleForSurvivors(int baseValue, int perPlayer, int survivors)
{
	int extra = survivors - 4;
	if (extra < 0)
	{
		extra = 0;
	}

	if (perPlayer < 0)
	{
		perPlayer = 0;
	}

	int value = baseValue + extra * perPlayer;
	if (value < 0)
	{
		value = 0;
	}

	return value;
}

void SetEngineValue(ConVar cvar, int value)
{
	if (cvar != null)
	{
		cvar.SetInt(value);
	}
}

int CountSurvivors(bool aliveOnly)
{
	int count = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR)
		{
			continue;
		}

		if (aliveOnly && !IsPlayerAlive(i))
		{
			continue;
		}

		count++;
	}

	return count;
}

bool HasRealSurvivor()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsRealClient(i) && GetClientTeam(i) == TEAM_SURVIVOR)
		{
			return true;
		}
	}

	return false;
}

bool IsRealClient(int client)
{
	return client > 0
		&& IsClientConnected(client)
		&& IsClientInGame(client)
		&& !IsFakeClient(client);
}

void CacheEngineConVars()
{
	g_cvCommonLimit = FindEngineConVar("z_common_limit");
	g_cvBackgroundLimit = FindEngineConVar("z_background_limit");
	g_cvMegaMobSize = FindEngineConVar("z_mega_mob_size");
	g_cvMobMinNotify = FindEngineConVar("z_mob_min_notify_count");
	g_cvMobSpawnMin = FindEngineConVar("z_mob_spawn_min_size");
	g_cvMobSpawnMax = FindEngineConVar("z_mob_spawn_max_size");
}

ConVar FindEngineConVar(const char[] name)
{
	ConVar cvar = FindConVar(name);

	if (cvar == null)
	{
		LogError("ConVar \"%s\" not found, that value will not be regulated.", name);
	}

	return cvar;
}
