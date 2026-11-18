#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
//原作者版本号v1.0.3
#define PLUGIN_VERSION 				"1.1.0"
#define INFECTED_NAMES 				6
#define WITCH_LEN 					32
#define GAUGE_RECENT_SECONDS		2.0
#define CVAR_FLAGS 					FCVAR_NOTIFY
#define CVAR_FLAGS_PLUGIN_VERSION 	FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_SPONLY

public Plugin myinfo =
{
	name 		= "[L4D1 AND L4D2] Infected HP",
	author 		= "NiCo-op, Edited By Ernecio (Satanael), laoyutang",
	description = "L4D Infected HP",
	version 	= PLUGIN_VERSION,
	url 		= "http://nico-op.forjp.net/"
};

ConVar hPluginEnable;
ConVar hPluginTank;
ConVar hBarLEN;
ConVar hCharHealth;
ConVar hCharDamage;
ConVar hShowType;
ConVar hShowNum;
ConVar hTank;
ConVar hWitch;
ConVar hInfected[INFECTED_NAMES];

bool TankkillFinaleVehicleLeaving;

int witchCUR = 0;
int witchMAX[WITCH_LEN];
int witchHP[WITCH_LEN];
int witchID[WITCH_LEN];
int nCharLength;
int nShowType;
int nShowNum;
int nShowTank;
int nShowWitch;
int nShowFlag[INFECTED_NAMES];

char sCharHealth[8] = "#";
char sCharDamage[8] = "=";

// 只有最近击中此坦克、已获血条的真人会收到一次回复刷新。刷新本身不续期。
enum struct GaugeView
{
	int viewerSerial;
	int target;
	int targetSerial;
	int targetRef;
	int channel;
	float until;
}
GaugeView g_LastGauge[MAXPLAYERS + 1];

char sClassName[][] = 
{
	"boome",
	"hunter",
	"smoker",
	"jockey",
	"spitter",
	"charger"
};

public void OnPluginStart()
{
	CreateConVar("l4d2_infectedhp_version", PLUGIN_VERSION, "特感血条插件的版本.", CVAR_FLAGS_PLUGIN_VERSION );
	hPluginEnable 	= CreateConVar("l4d2_infectedhp", 				"1", 		"启用插件? 0=禁用, 1=启用.", CVAR_FLAGS);
	hPluginTank		= CreateConVar("l4d2_infectedhp_a",				"1",		"启用坦克卡死提示? 0=禁用, 1=聊天窗, 2=屏幕中下+聊天窗, 3=屏幕中下.", CVAR_FLAGS);
	hBarLEN 		= CreateConVar("l4d2_infectedhp_bar", 			"70", 		"生命条长度，默认70格。", CVAR_FLAGS);
	hCharHealth 	= CreateConVar("l4d2_infectedhp_health", 		"|", 		"设置血量符号.", CVAR_FLAGS );
	hCharDamage 	= CreateConVar("l4d2_infectedhp_damage", 		" ", 		"设置去血符号.", CVAR_FLAGS );
	hShowType 		= CreateConVar("l4d2_infectedhp_type", 			"0", 		"设置血条的显示位置和类型. 0=屏幕中心 1=屏幕中下.", CVAR_FLAGS);
	hShowNum 		= CreateConVar("l4d2_infectedhp_num", 			"1", 		"启用血量数字显示? 0=禁用, 1=启用.", CVAR_FLAGS);
	hTank 			= CreateConVar("l4d2_infectedhp_tank", 			"1", 		"启用坦克血条显示? 0=禁用, 1=启用.", CVAR_FLAGS);
	hWitch 			= CreateConVar("l4d2_infectedhp_witch", 		"1", 		"启用女巫血条显示? 0=禁用, 1=启用.", CVAR_FLAGS);
	hInfected[0] 	= CreateConVar("l4d2_infectedhp_zmykey_boomer", "1", 		"启用 boomer 血条显示? 0=禁用, 1=启用.", CVAR_FLAGS);
	
	char bar[64];
	char buffers[64];
	for(int i = 1; i < INFECTED_NAMES; i ++)
	{
		Format(buffers, sizeof(buffers), "l4d2_infectedhp_zmykey_%s", sClassName[i]);
		Format(bar, sizeof(bar), "启用特感 %s 生命血条显示? 0=禁用, 1=启用.", sClassName[i]);
		hInfected[i] = CreateConVar(buffers,"1", bar, CVAR_FLAGS);
	}

	HookEvent("round_start", 	OnRoundStart, 	 EventHookMode_Post);
	HookEvent("player_hurt", 	OnPlayerHurt);
	HookEvent("witch_spawn", 	OnWitchSpawn);
	HookEvent("witch_killed", 	OnWitchKilled);
	HookEvent("infected_hurt", 	OnWitchHurt);
	HookEvent("player_spawn", 	OnInfectedSpawn, EventHookMode_Post);
	HookEvent("player_death", 	OnInfectedDeath, EventHookMode_Pre);
	
	HookEvent("round_start",	Event_RoundStart);//回合开始.
	HookEvent("round_end",		Event_RoundEnd);//回合结束.
	HookEvent("finale_vehicle_leaving", Event_FinaleVehicleLeaving, EventHookMode_Pre);//救援离开.
//	HookEvent("tank_spawn", 	OnInfectedSpawn);
//	HookEvent("tank_killed", 	OnInfectedDeath, EventHookMode_Pre);

	AutoExecConfig(true, "l4d2_infected_hp");
}

public void OnConfigsExecuted()
{
	GetConfig();
}

void GetConfig()
{
	char bufA[8];
	char bufB[8];
	hCharHealth.GetString( bufA, sizeof( bufA ) );
	hCharDamage.GetString( bufB, sizeof( bufB ) );
	nCharLength = strlen(bufA);
	if(!nCharLength || nCharLength != strlen(bufB))
	{
		nCharLength = 1;
		sCharHealth[0] = '#';
		sCharHealth[1] = '\0';
		sCharDamage[0] = '=';
		sCharDamage[1] = '\0';
	}
	else
	{
		strcopy(sCharHealth, sizeof(sCharHealth), bufA);
		strcopy(sCharDamage, sizeof(sCharDamage), bufB);
	}

	nShowType = hShowType.BoolValue;
	nShowNum = hShowNum.BoolValue;
	nShowTank = hTank.BoolValue;
	nShowWitch = hWitch.BoolValue;
	for(int i = 0; i < INFECTED_NAMES; i ++)
	{
		nShowFlag[i] = GetConVarBool(hInfected[i]);
	}
}

void ShowHealthGauge(int client, int maxBAR, int maxHP, int nowHP, char[] clName)
{
	int percent = RoundToCeil((float(nowHP) / float(maxHP)) * float(maxBAR));
	int i; 
	int length = maxBAR * nCharLength + 2;
	static char showBAR[256];
	
	showBAR[0] = '\0';
	for(i = 0; i < percent && i < maxBAR; i ++) StrCat(showBAR, length, sCharHealth);
	for(; i < maxBAR; i ++) 					StrCat(showBAR, length, sCharDamage);

	if(nShowType)
	{
		if(!nShowNum) 	PrintHintText(client, "HP: |-%s-|  %s", showBAR, clName);
		else 			PrintHintText(client, "HP: |-%s-|  [%d / %d]  %s", showBAR, nowHP, maxHP, clName);
	}
	else
	{
		if(!nShowNum) 	PrintCenterText(client, "HP: |-%s-|  %s", showBAR, clName);
		else 			PrintCenterText(client, "HP: |-%s-|  [%d / %d]  %s", showBAR, nowHP, maxHP, clName);
	}
}

public void OnRoundStart(Event event, const char[] sName, bool bDontBroadcast)
{
	ClearGaugeViews();
	nShowTank = 0;
	nShowWitch = 0;
	witchCUR = 0;
	for(int i = 0; i < WITCH_LEN; i ++)
	{
		witchMAX[i] = -1;
		witchHP[i] = -1;
		witchID[i] = -1;

	}
}

public void OnInfectedSpawn(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	if (client > 0) ClearGaugeViews(client);
	GetConfig();
}

// 控制槽可在同一连接上复用，出生和死亡也必须抹去旧生命的记录。
void ClearGaugeViews(int client = 0)
{
	for (int viewer = 1; viewer <= MaxClients; viewer++)
	{
		if (!client || viewer == client || g_LastGauge[viewer].target == client) g_LastGauge[viewer].target = 0;
	}
}

public void OnClientDisconnect(int client)
{
	ClearGaugeViews(client);
}

//地图结束.
public void OnMapEnd()
{
	ClearGaugeViews();
	TankkillFinaleVehicleLeaving = false;
}

//回合结束.
public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	ClearGaugeViews();
	TankkillFinaleVehicleLeaving = false;
}

//回合开始.
public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	TankkillFinaleVehicleLeaving = false;
}

//救援离开时.
public void Event_FinaleVehicleLeaving(Event event, const char[] name, bool dontBroadcast)
{
	TankkillFinaleVehicleLeaving = true;
}

public void OnInfectedDeath(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	if (client > 0) ClearGaugeViews(client);
	if ( !hPluginEnable.BoolValue ) return;

	int attacker = GetClientOfUserId(hEvent.GetInt("attacker"));
	
	if( client > 0 && IsClientConnected(client) && IsClientInGame(client) && GetClientTeam(client) == 3 )
	{
		char clName1[128];
		FormatEx(clName1, sizeof(clName1), "%N", client);
		SplitString(clName1, "Tank", clName1, sizeof(clName1));

		int HLZClass = GetEntProp(client, Prop_Send, "m_zombieClass");
		if (HLZClass == 8 && nShowTank)
		{
			int max = MaxClients;
			
			if (TankkillFinaleVehicleLeaving)
				return;
			
			if(attacker == client)
			{
				if(GetConVarInt(hPluginTank) != 0)
				{
					for(int i=1; i<=max; i++)
					{
						if(IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) != 3)
						{
							if(GetConVarInt(hPluginTank) == 1 || GetConVarInt(hPluginTank) == 2)
							{
								PrintToChat(i, "\x04[提示]\x05感染者\x03坦克%s\x05突然失去了梦想,自杀身亡.", clName1);//聊天窗提示.
							}
							if(GetConVarInt(hPluginTank) == 2 || GetConVarInt(hPluginTank) == 3)
							{
								if (nShowType) g_LastGauge[i].target = 0;
								PrintHintText(i, "[提示]感染者 坦克%s 突然失去了梦想,自杀身亡.", clName1);//屏幕中下提示.
							}
						}
					}
				}
			}
			else
			{
				for(int i=1; i<=max; i++)
				{
					if(IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) != 3)
					{
						if (nShowType) g_LastGauge[i].target = 0;
						PrintHintText(i, "++ 坦克%s已死亡 ++", clName1);
					}
				}
			}
		}
	}
}

public void OnPlayerHurt( Event hEvent, const char[] sName, bool bDontBroadcast)
{
	if(!GetConVarBool(hPluginEnable)) return;
	
	int attacker = GetClientOfUserId(hEvent.GetInt("attacker"));
	if(!attacker || !IsClientConnected(attacker) || !IsClientInGame(attacker) || GetClientTeam(attacker) != 2) return;
	
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	if(!client || !IsClientConnected(client) || !IsClientInGame(client) || !IsPlayerAlive(client) || GetClientTeam(client) != 3) return;
	g_LastGauge[attacker].target = 0;

	char class[128];
	GetClientModel(client, class, sizeof(class));
	int match = 0;
	for(int i = 0; i < INFECTED_NAMES; i ++){
		if(nShowFlag[i] && StrContains(class, sClassName[i], false) != -1){
			match = 1;
			break;
		}
	}
	
	if(!match && (!nShowTank || (nShowTank && StrContains(class, "tank", false) == -1 && StrContains(class, "hulk", false) == -1))) return;
	if (!match && !IsFakeClient(attacker) && IsPlayerAlive(attacker))
	{
		g_LastGauge[attacker].viewerSerial = GetClientSerial(attacker);
		g_LastGauge[attacker].target = client;
		g_LastGauge[attacker].targetSerial = GetClientSerial(client);
		g_LastGauge[attacker].targetRef = EntIndexToEntRef(client);
		g_LastGauge[attacker].channel = nShowType;
		g_LastGauge[attacker].until = GetGameTime() + GAUGE_RECENT_SECONDS;
	}
	ShowPlayerGauge(attacker, client);
}

void ShowPlayerGauge(int attacker, int client)
{
	int maxBAR = hBarLEN.IntValue;
	int nowHP = GetEntProp(client, Prop_Data, "m_iHealth");
	int maxHP = GetEntProp(client, Prop_Data, "m_iMaxHealth");

	// 每次受伤都读当前实体。回复、缩放及控制者接管后，旧生命的最低血量没有参考价值。
	if(nowHP < 0) nowHP = 0;
	if(maxHP < nowHP) maxHP = nowHP;
	if(maxHP < 1) maxHP = 1;

	char clName[MAX_NAME_LENGTH];
	GetClientName(client, clName, sizeof(clName));
	ShowHealthGauge(attacker, maxBAR, maxHP, nowHP, clName);
}

// Rogue 的可选公开事件。仅在回复真实发生时读取目标，单独安装显血时仍照常按命中显示。
public void RN_OnTankHealthRestored(int tank)
{
	if (hPluginEnable == null || !hPluginEnable.BoolValue || !hTank.BoolValue || tank < 1 || tank > MaxClients ||
		!IsClientInGame(tank) || !IsPlayerAlive(tank) || GetClientTeam(tank) != 3 || GetEntProp(tank, Prop_Send, "m_zombieClass") != 8) return;
	int serial = GetClientSerial(tank), ref = EntIndexToEntRef(tank);
	float now = GetGameTime();
	for (int viewer = 1; viewer <= MaxClients; viewer++)
	{
		if (g_LastGauge[viewer].target != tank) continue;
		bool valid = g_LastGauge[viewer].targetSerial == serial && g_LastGauge[viewer].targetRef == ref &&
			now < g_LastGauge[viewer].until && g_LastGauge[viewer].channel == nShowType &&
			IsClientInGame(viewer) && GetClientSerial(viewer) == g_LastGauge[viewer].viewerSerial &&
			IsPlayerAlive(viewer) && GetClientTeam(viewer) == 2 && !IsFakeClient(viewer);
		// 一次真实命中只授权一次主动刷新，下一枪会按新的目标重建记录。
		g_LastGauge[viewer].target = 0;
		if (!valid) continue;
		if (!IsClientInGame(tank) || GetClientSerial(tank) != serial || EntIndexToEntRef(tank) != ref ||
			!IsPlayerAlive(tank) || GetClientTeam(tank) != 3 || GetEntProp(tank, Prop_Send, "m_isIncapacitated")) break;
		ShowPlayerGauge(viewer, tank);
	}
}

public void OnWitchSpawn( Event hEvent, const char[] sName, bool bDontBroadcast )
{
	GetConfig();

	int entity = hEvent.GetInt( "witchid" );
	witchID[witchCUR] = entity;
	RequestFrame(IsGetWitchID, entity);//为了避免可能出现的问题,这里延迟一帧获取血量.
}

void IsGetWitchID(int entity)
{
	int health = GetEntProp(entity, Prop_Data, "m_iMaxHealth");
	witchMAX[witchCUR] = health;
	witchHP[witchCUR] = health;
	witchCUR = (witchCUR + 1) % WITCH_LEN;
}

public void OnWitchKilled( Event hEvent, const char[] sName, bool bDontBroadcast)
{
	int entity = hEvent.GetInt( "witchid" );
	
	for(int i = 0; i < WITCH_LEN; i ++)
	{
		if(witchID[i] == entity)
		{
			witchMAX[i] = -1;
			witchHP[i] = -1;
			witchID[i] = -1;
			break;
		}
	}
}

public void OnWitchHurt( Event hEvent, const char[] sName, bool bDontBroadcast )
{
	if ( !nShowWitch || !GetConVarBool( hPluginEnable ) ) return;
	
	int attacker = GetClientOfUserId(hEvent.GetInt("attacker"));
	if(!attacker || !IsClientConnected(attacker) || !IsClientInGame(attacker) || GetClientTeam(attacker) != 2) return;

	int entity = hEvent.GetInt( "entityid" );
	for(int i = 0; i < WITCH_LEN; i ++)
	{
		if(witchID[i] == entity)
		{
			int damage = GetEventInt(hEvent, "amount");
			g_LastGauge[attacker].target = 0;
			int maxBAR = GetConVarInt(hBarLEN);
			int nowHP = witchHP[i] - damage;
			int maxHP = witchMAX[i];

			if(nowHP <= 0 || witchMAX[i] < 0) nowHP = 0;
			
			if(nowHP && nowHP > witchHP[i])	nowHP = witchHP[i];
			else							witchHP[i] = nowHP;
			
			if( maxHP < 1 )	maxHP = 1;
			
			char clName[64];
			if(i == 0) 	strcopy(clName, sizeof(clName), "Witch");
			else 		Format(clName, sizeof(clName), "(%d)Witch", i);
			
			ShowHealthGauge(attacker, maxBAR, maxHP, nowHP, clName);
		}
	}
}
