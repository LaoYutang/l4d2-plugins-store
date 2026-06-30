#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>

#define PLUGIN_VERSION "1.1"
#define TEAM_SURVIVOR 2

ConVar g_cvEnable;
ConVar g_cvRatio;
ConVar g_cvMaxHealth;
ConVar g_cvNotify;
ConVar g_cvAllowIncapVictim;

bool  g_bEnable;
float g_fRatio;
int   g_iMaxHealth;
bool  g_bNotify;
bool  g_bAllowIncapVictim;

public Plugin myinfo =
{
	name        = "[L4D2] Friendly Fire Lifesteal",
	author      = "laoyutang",
	description = "友伤按比例给攻击者回血.",
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
	g_cvEnable    = CreateConVar("l4d2_ff_lifesteal_enable", "1", "是否启用友伤汲血 (0=关闭, 1=开启).", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvRatio     = CreateConVar("l4d2_ff_lifesteal_ratio", "1.0", "攻击者回血比例，回血量=友伤伤害*比例 (1.0=100%).", FCVAR_NOTIFY, true, 0.0, true, 10.0);
	g_cvMaxHealth = CreateConVar("l4d2_ff_lifesteal_max_health", "100", "攻击者回血后的实血上限.", FCVAR_NOTIFY, true, 1.0, true, 1000.0);
	g_cvNotify    = CreateConVar("l4d2_ff_lifesteal_notify", "1", "触发友伤汲血时是否提示攻击者 (0=关闭, 1=开启).", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvAllowIncapVictim = CreateConVar("l4d2_ff_lifesteal_allow_incap_victim", "0", "是否允许从倒地或挂边队友身上触发友伤汲血 (0=关闭, 1=开启).", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	g_cvEnable.AddChangeHook(ConVarChanged);
	g_cvRatio.AddChangeHook(ConVarChanged);
	g_cvMaxHealth.AddChangeHook(ConVarChanged);
	g_cvNotify.AddChangeHook(ConVarChanged);
	g_cvAllowIncapVictim.AddChangeHook(ConVarChanged);

	GetCvars();
	AutoExecConfig(true, "l4d2_ff_lifesteal");

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
	g_bEnable    = g_cvEnable.BoolValue;
	g_fRatio     = g_cvRatio.FloatValue;
	g_iMaxHealth = g_cvMaxHealth.IntValue;
	g_bNotify    = g_cvNotify.BoolValue;
	g_bAllowIncapVictim = g_cvAllowIncapVictim.BoolValue;
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
	if (!g_bEnable || g_fRatio <= 0.0 || damage <= 0.0)
		return Plugin_Continue;

	if (!IsValidSurvivor(victim) || !IsValidSurvivor(attacker))
		return Plugin_Continue;

	if (victim == attacker)
		return Plugin_Continue;

	if (!IsStandingSurvivor(attacker))
		return Plugin_Continue;

	if (!IsAllowedVictimState(victim))
		return Plugin_Continue;

	int healAmount = RoundToNearest(damage * g_fRatio);
	if (healAmount <= 0)
		return Plugin_Continue;

	int actualHeal = 0;
	AddRealHealth(attacker, healAmount, g_iMaxHealth, actualHeal);

	if (g_bNotify && actualHeal > 0)
	{
		PrintToChat(attacker, "\x04[友伤汲血]\x01 你对 \x03%N\x01 的友伤为你恢复了 \x05%d\x01 点血量.", victim, actualHeal);
	}

	return Plugin_Continue;
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

	if (IsSurvivorIncapacitatedOrHanging(client))
		return false;

	return true;
}

bool IsAllowedVictimState(int client)
{
	if (!IsPlayerAlive(client))
		return false;

	if (g_bAllowIncapVictim)
		return true;

	return !IsSurvivorIncapacitatedOrHanging(client);
}

bool IsSurvivorIncapacitatedOrHanging(int client)
{
	if (GetEntProp(client, Prop_Send, "m_isIncapacitated") != 0)
		return true;

	if (GetEntProp(client, Prop_Send, "m_isHangingFromLedge") != 0)
		return true;

	return false;
}
