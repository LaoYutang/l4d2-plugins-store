#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>

#define PLUGIN_VERSION "1.0.0"
#define TEAM_SURVIVOR 2

ConVar g_cvChance;
ConVar g_cvMaxHealth;
ConVar g_cvNotify;

float g_fChance;
int   g_iMaxHealth;
bool  g_bNotify;

public Plugin myinfo =
{
	name        = "[L4D2] Friendly Fire Heal",
	author      = "laoyutang",
	description = "友伤概率转换为队友回血.",
	version     = PLUGIN_VERSION,
	url         = ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "本插件仅支持 Left 4 Dead 2");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

public void OnPluginStart()
{
	g_cvChance    = CreateConVar("l4d2_ff_heal_chance", "50.0", "友伤转回血概率 (0-100).", FCVAR_NOTIFY, true, 0.0, true, 100.0);
	g_cvMaxHealth = CreateConVar("l4d2_ff_heal_max_health", "100", "友伤回血后的实血上限.", FCVAR_NOTIFY, true, 1.0, true, 1000.0);
	g_cvNotify    = CreateConVar("l4d2_ff_heal_notify", "1", "触发友伤回血时是否提示玩家 (0=关闭, 1=开启).", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	g_cvChance.AddChangeHook(ConVarChanged);
	g_cvMaxHealth.AddChangeHook(ConVarChanged);
	g_cvNotify.AddChangeHook(ConVarChanged);

	GetCvars();
	AutoExecConfig(true, "l4d2_ff_heal");

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
			OnClientPutInServer(i);
	}
}

public void OnConfigsExecuted()
{
	GetCvars();
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_fChance    = g_cvChance.FloatValue;
	g_iMaxHealth = g_cvMaxHealth.IntValue;
	g_bNotify    = g_cvNotify.BoolValue;
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientDisconnect(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (g_fChance <= 0.0 || damage <= 0.0)
		return Plugin_Continue;

	if (!IsValidSurvivor(victim) || !IsValidSurvivor(attacker))
		return Plugin_Continue;

	if (victim == attacker)
		return Plugin_Continue;

	if (!IsStandingSurvivor(victim) || !IsStandingSurvivor(attacker))
		return Plugin_Continue;

	if (g_fChance < 100.0 && GetRandomFloat(0.0, 100.0) >= g_fChance)
		return Plugin_Continue;

	int healAmount = RoundToNearest(damage);
	if (healAmount < 1)
		healAmount = 1;

	int actualHeal = 0;
	AddRealHealth(victim, healAmount, g_iMaxHealth, actualHeal);

	damage = 0.0;

	if (g_bNotify)
	{
		if (actualHeal > 0)
		{
			PrintToChat(attacker, "\x04[友伤回血]\x01 你对 \x03%N\x01 的友伤转化为 \x05%d\x01 点回血.", victim, actualHeal);
			PrintToChat(victim, "\x04[友伤回血]\x03 %N\x01 的友伤为你恢复了 \x05%d\x01 点血量.", attacker, actualHeal);
		}
		else
		{
			PrintToChat(attacker, "\x04[友伤回血]\x01 你对 \x03%N\x01 的友伤已被抵消，对方血量已达上限.", victim);
			PrintToChat(victim, "\x04[友伤回血]\x03 %N\x01 的友伤已被抵消，你的血量已达上限.", attacker);
		}
	}

	return Plugin_Changed;
}

bool AddRealHealth(int client, int amount, int maxHealth, int &actualHeal)
{
	actualHeal = 0;

	if (amount <= 0 || maxHealth <= 0)
		return false;

	int currentHealth = GetClientHealth(client);
	if (currentHealth >= maxHealth)
		return false;

	int newHealth = currentHealth + amount;
	if (newHealth > maxHealth)
		newHealth = maxHealth;

	actualHeal = newHealth - currentHealth;
	SetEntProp(client, Prop_Send, "m_iHealth", newHealth);
	return actualHeal > 0;
}

bool IsValidSurvivor(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR;
}

bool IsStandingSurvivor(int client)
{
	if (!IsPlayerAlive(client))
		return false;

	if (GetEntProp(client, Prop_Send, "m_isIncapacitated") != 0)
		return false;

	if (GetEntProp(client, Prop_Send, "m_isHangingFromLedge") != 0)
		return false;

	return true;
}
