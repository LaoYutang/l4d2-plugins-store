/*
 *    Fixes for gamebreaking bugs and stupid gameplay aspects
 *    Copyright (C) 2019  LuxLuma		acceliacat@gmail.com
 *
 *    This program is free software: you can redistribute it and/or modify
 *    it under the terms of the GNU General Public License as published by
 *    the Free Software Foundation, either version 3 of the License, or
 *    (at your option) any later version.
 *
 *    This program is distributed in the hope that it will be useful,
 *    but WITHOUT ANY WARRANTY; without even the implied warranty of
 *    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *    GNU General Public License for more details.
 *
 *    You should have received a copy of the GNU General Public License
 *    along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

// 原插件：[L4D2]Witch_Double_Start_Fix by Lux
// https://forums.alliedmods.net/showthread.php?p=2647014
//
// 修的问题：女巫处于游荡状态时被惊动，会把惊吓动画播两遍（原地尖叫两次），
// 中间还夹着待机动作，女巫因此醒得慢、出手晚。插件在女巫播放这段动画时把动画
// 周期直接置为结束，取消第二次惊吓，女巫随即进入追击/攻击。
//
// 支持地图运行中加载：开关生效后，场上已存在的女巫也会补挂 Think 钩子。

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION		"1.0"
#define STARTLE_SEQUENCE	30

bool g_bLateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if(GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2");
		return APLRes_SilentFailure;
	}

	g_bLateLoad = late;
	return APLRes_Success;
}

public Plugin myinfo =
{
	name = "[L4D2]Witch_Double_Start_Fix",
	author = "Lux",
	description = "Fixes witch when wandering playing startle twice by forcing the NextThink to end the startle.",
	version = PLUGIN_VERSION,
	url = "forums.alliedmods.net/showthread.php?p=2647014"
};

public void OnPluginStart()
{
	CreateConVar("witch_double_start_fix", PLUGIN_VERSION, "Witch double startle fix version", FCVAR_NONE|FCVAR_DONTRECORD);

	// 地图运行中切换开关加载本插件时，已存在的女巫也要挂上钩子。
	if(g_bLateLoad)
	{
		int iWitch = -1;
		while((iWitch = FindEntityByClassname(iWitch, "witch")) != -1)
		{
			SDKHook(iWitch, SDKHook_Think, OnThink);
		}
	}
}

public void OnEntityCreated(int iEntity, const char[] sClassname)
{
	if(sClassname[0] != 'w' || !StrEqual(sClassname, "witch", false))
		return;

	SDKHook(iEntity, SDKHook_Think, OnThink);
}

public void OnThink(int iWitch)
{
	if(GetEntProp(iWitch, Prop_Data, "m_iHealth") < 1)
		return;

	if(GetEntProp(iWitch, Prop_Send, "m_nSequence", 2) == STARTLE_SEQUENCE)
		SetEntPropFloat(iWitch, Prop_Send, "m_flCycle", 1.0);
}