#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <dhooks>

// The exact grenade Explode detour signature and callback shape are based on
// Left4DHooks 1.159 by Silvers: https://github.com/SilvDev/Left4DHooks

#define PLUGIN_VERSION "1.0.0"
#define GAMEDATA_FILE "l4d2_grenade_teleport"
#define DETOUR_NAME "GrenadeTeleport::CGrenadeLauncher_Projectile::Explode"

#define TEAM_SURVIVOR 2
#define SEARCH_DIRECTION_COUNT 8

#define TRACE_START_HEIGHT 32.0
#define GROUND_OFFSET 1.0
#define MIN_GROUND_NORMAL_Z 0.7

static const float SEARCH_RADII[] =
{
	24.0,
	48.0,
	72.0,
	96.0
};

static const float SURVIVOR_MINS[3] = {-16.0, -16.0, 0.0};
static const float SURVIVOR_MAXS[3] = {16.0, 16.0, 72.0};

public Plugin myinfo =
{
	name = "[L4D2] Grenade Teleport",
	author = "laoyutang",
	description = "Teleports human Survivors to a safe position near their grenade launcher explosion.",
	version = PLUGIN_VERSION,
	url = ""
};

ConVar g_cvEnable;
ConVar g_cvMaxDrop;
ConVar g_cvDebug;

DynamicDetour g_hGrenadeExplodeDetour;
bool g_bGrenadeExplodeDetourEnabled;

public void OnPluginStart()
{
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		SetFailState("This plugin only supports Left 4 Dead 2.");
	}

	g_cvEnable = CreateConVar(
		"l4d2_grenade_teleport_enable",
		"1",
		"Enable grenade launcher explosion teleporting.",
		0,
		true,
		0.0,
		true,
		1.0
	);

	g_cvMaxDrop = CreateConVar(
		"l4d2_grenade_teleport_max_drop",
		"512.0",
		"Maximum vertical distance below an explosion to search for ground.",
		0,
		true,
		32.0,
		true,
		4096.0
	);

	g_cvDebug = CreateConVar(
		"l4d2_grenade_teleport_debug",
		"0",
		"Log grenade teleport decisions to the SourceMod log.",
		0,
		true,
		0.0,
		true,
		1.0
	);

	AutoExecConfig(true, GAMEDATA_FILE);
	SetupGrenadeExplodeDetour();
}

public void OnPluginEnd()
{
	if (g_hGrenadeExplodeDetour != null)
	{
		if (g_bGrenadeExplodeDetourEnabled)
		{
			g_hGrenadeExplodeDetour.Disable(Hook_Post, Detour_GrenadeExplode_Post);
		}

		delete g_hGrenadeExplodeDetour;
	}
}

void SetupGrenadeExplodeDetour()
{
	GameData gameData = new GameData(GAMEDATA_FILE);
	if (gameData == null)
	{
		SetFailState("Unable to load required gamedata file: %s.txt", GAMEDATA_FILE);
	}

	g_hGrenadeExplodeDetour = DynamicDetour.FromConf(gameData, DETOUR_NAME);
	delete gameData;

	if (g_hGrenadeExplodeDetour == null)
	{
		SetFailState("Unable to create detour: %s", DETOUR_NAME);
	}

	if (!g_hGrenadeExplodeDetour.Enable(Hook_Post, Detour_GrenadeExplode_Post))
	{
		SetFailState("Unable to enable post detour: %s", DETOUR_NAME);
	}

	g_bGrenadeExplodeDetourEnabled = true;
}

MRESReturn Detour_GrenadeExplode_Post(int projectile, DHookReturn hReturn, DHookParam hParams)
{
	if (!g_cvEnable.BoolValue)
	{
		return MRES_Ignored;
	}

	if (projectile <= MaxClients || !IsValidEntity(projectile))
	{
		DebugLog("Ignored explosion callback with invalid projectile entity %d.", projectile);
		return MRES_Ignored;
	}

	int client = GetEntPropEnt(projectile, Prop_Send, "m_hThrower");
	if (!IsEligibleSurvivor(client))
	{
		DebugLog("Ignored grenade %d because thrower %d is not an eligible human Survivor.", projectile, client);
		return MRES_Ignored;
	}

	float impact[3];
	GetEntPropVector(projectile, Prop_Send, "m_vecOrigin", impact);

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteFloatArray(impact, sizeof impact);
	RequestFrame(Frame_TeleportToImpact, pack);

	DebugLog(
		"Queued grenade %d from client %N at impact %.1f %.1f %.1f.",
		projectile,
		client,
		impact[0],
		impact[1],
		impact[2]
	);

	return MRES_Ignored;
}

void Frame_TeleportToImpact(any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();

	int userId = pack.ReadCell();
	float impact[3];
	pack.ReadFloatArray(impact, sizeof impact);
	delete pack;

	if (!g_cvEnable.BoolValue)
	{
		DebugLog("Cancelled queued teleport for userid %d because the plugin was disabled.", userId);
		return;
	}

	int client = GetClientOfUserId(userId);
	if (!IsEligibleSurvivor(client))
	{
		DebugLog("Cancelled queued teleport for userid %d because the Survivor is no longer eligible.", userId);
		return;
	}

	float destination[3];
	int candidatesTested;
	if (!FindSafePosition(client, impact, destination, candidatesTested))
	{
		DebugLog(
			"No safe destination for client %N near impact %.1f %.1f %.1f after %d candidates.",
			client,
			impact[0],
			impact[1],
			impact[2],
			candidatesTested
		);
		return;
	}

	float zeroVelocity[3] = {0.0, 0.0, 0.0};
	TeleportEntity(client, destination, NULL_VECTOR, zeroVelocity);

	if (HasEntProp(client, Prop_Send, "m_flFallVelocity"))
	{
		SetEntPropFloat(client, Prop_Send, "m_flFallVelocity", 0.0);
	}

	DebugLog(
		"Teleported client %N to %.1f %.1f %.1f after testing %d candidates.",
		client,
		destination[0],
		destination[1],
		destination[2],
		candidatesTested
	);
}

bool IsEligibleSurvivor(int client)
{
	if (
		client < 1
		|| client > MaxClients
		|| !IsClientInGame(client)
		|| IsFakeClient(client)
		|| GetClientTeam(client) != TEAM_SURVIVOR
		|| !IsPlayerAlive(client)
	)
	{
		return false;
	}

	if (
		GetEntProp(client, Prop_Send, "m_isIncapacitated") != 0
		|| GetEntProp(client, Prop_Send, "m_isHangingFromLedge") != 0
		|| GetEntProp(client, Prop_Send, "m_isFallingFromLedge") != 0
	)
	{
		return false;
	}

	if (
		GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0
		|| GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0
		|| GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0
		|| GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0
		|| GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0
	)
	{
		return false;
	}

	return GetEntityMoveType(client) != MOVETYPE_LADDER;
}

bool FindSafePosition(int client, const float impact[3], float destination[3], int &candidatesTested)
{
	candidatesTested = 0;

	float candidate[3];
	CopyVector(impact, candidate);
	candidatesTested++;

	if (IsSafeCandidate(client, candidate, destination))
	{
		return true;
	}

	for (int radiusIndex = 0; radiusIndex < sizeof SEARCH_RADII; radiusIndex++)
	{
		for (int direction = 0; direction < SEARCH_DIRECTION_COUNT; direction++)
		{
			float radians = DegToRad(float(direction) * (360.0 / float(SEARCH_DIRECTION_COUNT)));

			candidate[0] = impact[0] + Cosine(radians) * SEARCH_RADII[radiusIndex];
			candidate[1] = impact[1] + Sine(radians) * SEARCH_RADII[radiusIndex];
			candidate[2] = impact[2];
			candidatesTested++;

			if (IsSafeCandidate(client, candidate, destination))
			{
				return true;
			}
		}
	}

	return false;
}

bool IsSafeCandidate(int client, const float candidate[3], float destination[3])
{
	float traceStart[3];
	float traceEnd[3];
	CopyVector(candidate, traceStart);
	CopyVector(candidate, traceEnd);

	traceStart[2] += TRACE_START_HEIGHT;
	traceEnd[2] -= g_cvMaxDrop.FloatValue;

	if (TR_PointOutsideWorld(traceStart))
	{
		return false;
	}

	Handle groundTrace = TR_TraceRayFilterEx(
		traceStart,
		traceEnd,
		MASK_PLAYERSOLID,
		RayType_EndPoint,
		TraceFilter_Ground,
		client
	);

	if (groundTrace == null)
	{
		return false;
	}

	bool foundGround = TR_DidHit(groundTrace)
		&& !TR_StartSolid(groundTrace)
		&& !TR_AllSolid(groundTrace);

	float groundPosition[3];
	float groundNormal[3];
	if (foundGround)
	{
		TR_GetEndPosition(groundPosition, groundTrace);
		TR_GetPlaneNormal(groundTrace, groundNormal);
		foundGround = groundNormal[2] >= MIN_GROUND_NORMAL_Z;
	}

	delete groundTrace;

	if (!foundGround)
	{
		return false;
	}

	groundPosition[2] += GROUND_OFFSET;
	if (TR_PointOutsideWorld(groundPosition))
	{
		return false;
	}

	Handle hullTrace = TR_TraceHullFilterEx(
		groundPosition,
		groundPosition,
		SURVIVOR_MINS,
		SURVIVOR_MAXS,
		MASK_PLAYERSOLID,
		TraceFilter_Occupancy,
		client
	);

	if (hullTrace == null)
	{
		return false;
	}

	bool blocked = TR_DidHit(hullTrace)
		|| TR_StartSolid(hullTrace)
		|| TR_AllSolid(hullTrace);

	delete hullTrace;

	if (blocked)
	{
		return false;
	}

	CopyVector(groundPosition, destination);
	return true;
}

bool TraceFilter_Ground(int entity, int contentsMask, any data)
{
	int client = data;
	if (entity == client)
	{
		return false;
	}

	if (entity >= 1 && entity <= MaxClients)
	{
		return false;
	}

	if (entity <= 0)
	{
		return true;
	}

	if (!IsValidEntity(entity))
	{
		return true;
	}

	char classname[64];
	if (!GetEntityClassname(entity, classname, sizeof classname))
	{
		return true;
	}

	if (
		StrEqual(classname, "infected", false)
		|| StrEqual(classname, "witch", false)
		|| StrEqual(classname, "witch_bride", false)
		|| StrContains(classname, "_projectile", false) != -1
	)
	{
		return false;
	}

	return true;
}

bool TraceFilter_Occupancy(int entity, int contentsMask, any data)
{
	return entity != data;
}

void CopyVector(const float source[3], float destination[3])
{
	destination[0] = source[0];
	destination[1] = source[1];
	destination[2] = source[2];
}

void DebugLog(const char[] format, any ...)
{
	if (g_cvDebug == null || !g_cvDebug.BoolValue)
	{
		return;
	}

	char message[256];
	VFormat(message, sizeof message, format, 2);
	LogMessage("%s", message);
}
