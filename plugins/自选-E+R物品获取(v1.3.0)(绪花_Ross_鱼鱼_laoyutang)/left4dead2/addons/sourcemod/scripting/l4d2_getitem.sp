#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <colors>

#define NAME 			"L4D2 Item acquisition Plugin | L4D2物品获取插件"				//定义插件名字
#define AUTHOR 			"绪花✧(≖ ◡ ≖✿) | Ross | 鱼鱼 | laoyutang"					//定义作者
#define DESCRIPTION 	"L4D2 Item acquisition Plugin | L4D2物品获取插件"				//定义插件描述
#define VERSION 		"1.3.0"															//定义插件版本
#define URL 			"https://steamcommunity.com/profiles/76561198100717207/"		//定义作者联系地址

#define IsValidPlayer(%1)	(%1 && IsClientInGame(%1) && GetClientTeam(%1) == 2 && IsPlayerAlive(%1))//&& !IsFakeClient(%1)


public Plugin myinfo =
{
	name			=	NAME,
	author			=	AUTHOR,
	description		=	DESCRIPTION,
	version			=	VERSION,
	url				=	URL
};

ConVar cmeleedefault, cinitialgundefault, csafearea, cAdvancedGunOpen;
ConVar cItemDefault[18];

// 默认配置仅在本次插件加载后应用一次；管理员临时开关跨地图保留。
bool g_bDefaultsLoaded;

float fTimel;

bool
		bmeleedefault,
		binitialgundefault,
		bsafearea,
		MenuAdvancedGunOpen,
		MenuThrowableOpen[18];

static const char
	g_sMeleeModels[][] = {
		"models/weapons/melee/v_fireaxe.mdl",
		"models/weapons/melee/w_fireaxe.mdl",
		"models/weapons/melee/v_frying_pan.mdl",
		"models/weapons/melee/w_frying_pan.mdl",
		"models/weapons/melee/v_machete.mdl",
		"models/weapons/melee/w_machete.mdl",
		"models/weapons/melee/v_bat.mdl",
		"models/weapons/melee/w_bat.mdl",
		"models/weapons/melee/v_crowbar.mdl",
		"models/weapons/melee/w_crowbar.mdl",
		"models/weapons/melee/v_cricket_bat.mdl",
		"models/weapons/melee/w_cricket_bat.mdl",
		"models/weapons/melee/v_tonfa.mdl",
		"models/weapons/melee/w_tonfa.mdl",
		"models/weapons/melee/v_katana.mdl",
		"models/weapons/melee/w_katana.mdl",
		"models/weapons/melee/v_electric_guitar.mdl",
		"models/weapons/melee/w_electric_guitar.mdl",
		"models/v_models/v_knife_t.mdl",
		"models/w_models/weapons/w_knife_t.mdl",
		"models/weapons/melee/v_golfclub.mdl",
		"models/weapons/melee/w_golfclub.mdl",
		"models/weapons/melee/v_shovel.mdl",
		"models/weapons/melee/w_shovel.mdl",
		"models/weapons/melee/v_pitchfork.mdl",
		"models/weapons/melee/w_pitchfork.mdl",
		"models/weapons/melee/v_riotshield.mdl",
		"models/weapons/melee/w_riotshield.mdl"
	};

static const char
	g_sWeaponName[4][18][] =
	{
		{//slot 0()
			"katana",
			"fireaxe",
			"machete",
			"knife",
			"pistol",
			"pistol_magnum",
			"chainsaw",
			"frying_pan",
			"baseball_bat",
			"crowbar",
			"cricket_bat",
			"tonfa",
			"electric_guitar",
			"golfclub",
			"shovel",
			"pitchfork",
			"riotshield",
			""
		},
		{//slot 1()
			"pumpshotgun",
			"shotgun_chrome",
			"smg",
			"smg_silenced",
			"smg_mp5",
			"ammo",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
		},
		{//slot 2()
			"autoshotgun",
			"shotgun_spas",
			"hunting_rifle",
			"sniper_military",
			"rifle",
			"rifle_desert",
			"rifle_ak47",
			"rifle_sg552",
			"sniper_scout",
			"sniper_awp",
			"rifle_m60",
			"grenade_launcher",
			"",
			"",
			"",
			"",
			"",
			"",
		},
		{//slot 3()
			"first_aid_kit",
			"defibrillator",
			"pain_pills",
			"adrenaline",
			"molotov",
			"pipe_bomb",
			"vomitjar",
			"upgradepack_incendiary",
			"upgradepack_explosive",
			"gascan",
			"propanetank",
			"oxygentank",
			"fireworkcrate",
			"cola_bottles",
			"gnome",
			"incendiary_ammo",
			"explosive_ammo",
			"laser_sight",
		},
	};

static const char
	g_sItemName[4][18][] =
	{
		{//slot 0()
			"武士刀",
			"消防斧",
			"砍刀",
			"小刀",
			"手枪",
			"马格南",
			"电锯",
			"平底锅",
			"棒球棒",
			"撬棍",
			"板球棒",
			"警棍",
			"吉他",
			"高尔夫",
			"铲子",
			"草叉",
			"防爆盾",
			"",
		},
		{//slot 1()
			"木喷",
			"铁喷",
			"UZI微冲",
			"消音微冲",
			"MP5",
			"备弹",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
		},
		{//slot 2()
			"一代连喷",
			"二代连喷",
			"木狙",
			"军狙",
			"M16",
			"SCAR",
			"AK47",
			"SG552",
			"鸟狙",
			"AWP",
			"M60",
			"榴弹发射器",
			"",
			"",
			"",
			"",
			"",
			"",
		},
		{//slot 3()
			"医疗包",
			"除颤仪",
			"止痛药",
			"肾上腺素",
			"燃烧瓶",
			"土制炸弹",
			"胆汁瓶",
			"燃烧弹药包",
			"高爆弹药包",
			"汽油桶",
			"煤气罐",
			"氧气瓶",
			"烟花箱",
			"可乐瓶",
			"圣诞老人",
			"燃烧弹药",
			"高爆弹药",
			"激光瞄准器",
		},
	};

public void OnPluginStart()
{
	RegAdminCmd("sm_getitem", Command_Item, ADMFLAG_GENERIC, "物品获取");

	cmeleedefault		= CreateConVar("l4d2_meleedefault", "1", "默认是否开启副武器菜单（0：关闭，1：开启；重启服务器或重载插件后生效）", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cinitialgundefault	= CreateConVar("l4d2_initialgundefault", "1", "默认是否开启小枪菜单（0：关闭，1：开启；重启服务器或重载插件后生效）", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	csafearea			= CreateConVar("l4d2_safearea", "1", "默认是否仅限安全区域内获取（0：允许安全区域外，1：仅安全区域内；重启服务器或重载插件后生效）", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cAdvancedGunOpen	= CreateConVar("l4d2_AdvancedGunOpen", "0", "默认是否开启大枪菜单（0：关闭，1：开启；重启服务器或重载插件后生效）", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	char name[64], description[192];
	for (int i = 0; i < sizeof cItemDefault; i++)
	{
		FormatEx(name, sizeof name, "l4d2_getitem_allow_%s", g_sWeaponName[3][i]);
		FormatEx(description, sizeof description, "默认是否允许获取%s（0：关闭，1：开启；重启服务器或重载插件后生效）", g_sItemName[3][i]);
		cItemDefault[i] = CreateConVar(name, "0", description, FCVAR_NOTIFY, true, 0.0, true, 1.0);
	}
	AutoExecConfig(true, "l4d2_getitem");
}

public void OnMapStart() {
	int i;
	for (; i < sizeof g_sMeleeModels; i++) {
		if (!IsModelPrecached(g_sMeleeModels[i]))
			PrecacheModel(g_sMeleeModels[i], true);
	}
}

public void OnConfigsExecuted()
{
	if (g_bDefaultsLoaded)
		return;

	bmeleedefault			=	cmeleedefault.BoolValue;
	binitialgundefault		=	cinitialgundefault.BoolValue;
	bsafearea				=	csafearea.BoolValue;
	MenuAdvancedGunOpen		=	cAdvancedGunOpen.BoolValue;
	for (int i = 0; i < sizeof MenuThrowableOpen; i++)
		MenuThrowableOpen[i] = cItemDefault[i].BoolValue;
	g_bDefaultsLoaded = true;
}

// 获取时复核当前状态，关闭菜单或物品后已经打开的旧菜单也不能继续发放。
bool CanGetItem(int client, bool enabled)
{
	if (!IsValidPlayer(client))
		return false;
	if (!g_bDefaultsLoaded)
	{
		PrintToChat(client, "\x05[提示] \x03物品获取配置尚未加载，请稍后再试");
		return false;
	}
	if (!enabled)
	{
		PrintToChat(client, "\x05[提示] \x03此菜单或物品已被关闭");
		return false;
	}
	if (bsafearea && !IsClientInSafeArea(client))
	{
		PrintToChat(client, "\x05[提示] \x03请在\x04 安全区域内 \x03使用E+R功能");
		return false;
	}
	return true;
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	CPrintToChat(client, "{blue}❀ {green}您已离开安全区域.");
	return Plugin_Continue;
}

public void OnClientPutInServer(int client)
{
	if(!IsFakeClient(client))
	{
		CreateTimer(1.1, ServerInfo, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
}

Action ServerInfo(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (g_bDefaultsLoaded && client && IsClientInGame(client) && GetClientTeam(client) == 2)
	{
		if((bsafearea && IsClientInSafeArea(client)) || !bsafearea)
			CPrintToChat(client, "{olive}[提示]{default}同时按住{blue} E和R键 {default}可获取 {blue}枪械和近战");
	}
	return Plugin_Stop;
}

public Action Command_Item(int client, int args)
{
	if (client && IsClientInGame(client))
		IsChooseItem(client);
	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if (!g_bDefaultsLoaded)
		return Plugin_Continue;

	if (buttons & (IN_RELOAD | IN_USE) == (IN_RELOAD | IN_USE))
	{
		if(IsValidPlayer(client))
		{
			if((bsafearea && IsClientInSafeArea(client)) || !bsafearea || iGetClientImmunityLevel(client) > 49)
			{
				IsChooseItem(client);
				if(buttons == (IN_RELOAD | IN_USE))
					buttons &= ~IN_USE;
			}
			else
			{
				if (GetEngineTime() - fTimel >= 2)
				{
					PrintToChat(client, "\x05[提示] \x03请在\x04 安全区域内 \x03使用E+R功能");
					fTimel = GetEngineTime();
				}
			}
		}
	}
	return Plugin_Continue;
}

void IsChooseItem(int client)
{
	if (!g_bDefaultsLoaded)
	{
		PrintToChat(client, "\x05[提示] \x03物品获取配置尚未加载，请稍后再试");
		return;
	}

	Menu menu = new Menu(Menu_HandlerFunction);
	SetMenuTitle(menu, "总菜单\n———————————————");
	menu.AddItem("a", bmeleedefault ? "副武器          ✿启用" : "副武器          ❀禁用");
	menu.AddItem("b", binitialgundefault ? "小枪            ✿启用" : "小枪            ❀禁用");
	menu.AddItem("c", MenuAdvancedGunOpen ? "大枪            ✿启用" : "大枪            ❀禁用");
	menu.AddItem("d", ItemCount() ? "物品            ✿启用" : "物品            ❀禁用");

	if (iGetClientImmunityLevel(client) > 49)
		menu.AddItem("e", "管理员菜单");
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int Menu_HandlerFunction(Menu menu, MenuAction action, int client, int itemNum)
{
	switch(action)
	{
		case MenuAction_End:
			delete menu;
		case MenuAction_Select:
		{
			char sItem[2];
			if(menu.GetItem(itemNum, sItem, sizeof(sItem)))
			{
				switch(sItem[0])
				{
					case 'a':
						if(bmeleedefault)
							MenuGetMelee(client);
					case 'b':
						if(binitialgundefault)
							MenuGetInitialGun(client);
					case 'c':
						if(MenuAdvancedGunOpen)
							MenuGetAdvancedGun(client);
					case 'd':
						if (ItemCount() > 0)
							MenuGetThrowable(client);
					case 'e':
							Menuadmin(client);
				}
			}
		}
	}
	return 0;
}

void MenuGetMelee(int client) {
	Menu menu = new Menu(iMelees_MenuHandler);
	menu.SetTitle("副武器\n—————");
	for (int i = 0; i < 17; i++)
	{
		menu.AddItem(g_sWeaponName[0][i], g_sItemName[0][i]);
	}
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int iMelees_MenuHandler(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (param2 >= 0 && param2 < 17 && CanGetItem(client, bmeleedefault))
			{
				int weaponid = GetPlayerWeaponSlot(client, 1);
				if (IsValidEntity(weaponid))
				{
					char classname[32];
					GetEntPropString(weaponid, Prop_Data, "m_ModelName", classname, sizeof(classname));
					if(StrContains(classname, g_sWeaponName[0][param2], true) == -1 || StrContains(classname, "pistol", true) !=-1)
					{
						char line[32];
						FormatEx(line, sizeof line, "give %s", g_sWeaponName[0][param2]);
						vCheatCommand(client, line);
						CPrintToChatAll( "{blue}❀ {green}%N {default}获取了 {blue}%s", client, g_sItemName[0][param2]);
					}
					else
						return 0;
				}
				else
				{
					char line[32];
					FormatEx(line, sizeof line, "give %s", g_sWeaponName[0][param2]);
					vCheatCommand(client, line);
					CPrintToChatAll( "{blue}❀ {green}%N {default}获取了 {blue}%s", client, g_sItemName[0][param2]);
				}
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				IsChooseItem(client);
		}
		case MenuAction_End:
			delete menu;
	}
	return 0;
}

void MenuGetInitialGun(int client)
{
	Menu menu = new Menu(iInitialGun_MenuHandler);
	menu.SetTitle("小枪\n——————");
	for (int i = 0; i < 6; i++)
	{
		menu.AddItem(g_sWeaponName[1][i], g_sItemName[1][i]);
	}
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int iInitialGun_MenuHandler(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (param2 >= 0 && param2 < 6 && CanGetItem(client, binitialgundefault))
			{
				int weaponid = GetPlayerWeaponSlot(client, 0);
				if (IsValidEntity(weaponid))
				{
					char classname[32];
					GetEntityClassname(weaponid, classname, sizeof(classname));
					if(StrContains(classname, g_sWeaponName[1][param2], true) != -1)
						return 0;
					else
					{
						char line[32];
						FormatEx(line, sizeof line, "give %s", g_sWeaponName[1][param2]);
						vCheatCommand(client, line);
						CPrintToChatAll( "{blue}❀ {green}%N {default}获取了 {blue}%s", client, g_sItemName[1][param2]);
					}
				}
				else
				{
					char line[32];
					FormatEx(line, sizeof line, "give %s", g_sWeaponName[1][param2]);
					vCheatCommand(client, line);
					CPrintToChatAll( "{blue}❀ {green}%N {default}获取了 {blue}%s", client, g_sItemName[1][param2]);
				}
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				IsChooseItem(client);
		}
		case MenuAction_End:
			delete menu;
	}
	return 0;
}

void MenuGetAdvancedGun(int client)
{
	Menu menu = new Menu(iAdvancedGun_MenuHandler);
	menu.SetTitle("大枪\n—————");
	for (int i = 0; i < 12; i++)
	{
		menu.AddItem(g_sWeaponName[2][i], g_sItemName[2][i]);
	}
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int iAdvancedGun_MenuHandler(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (param2 >= 0 && param2 < 12 && CanGetItem(client, MenuAdvancedGunOpen))
			{
				int weaponid = GetPlayerWeaponSlot(client, 0);
				if (IsValidEntity(weaponid))
				{
					char classname[32];
					GetEntityClassname(weaponid, classname, sizeof(classname));
					if(StrContains(classname, g_sWeaponName[2][param2], true) != -1)
						return 0;
					else
					{
						char line[32];
						FormatEx(line, sizeof line, "give %s", g_sWeaponName[2][param2]);
						vCheatCommand(client, line);
						CPrintToChatAll( "{blue}❀ {green}%N {default}获取了 {blue}%s", client, g_sItemName[2][param2]);
					}
				}
				else
				{
					char line[32];
					FormatEx(line, sizeof line, "give %s", g_sWeaponName[2][param2]);
					vCheatCommand(client, line);
					CPrintToChatAll( "{blue}❀ {green}%N {default}获取了 {blue}%s", client, g_sItemName[2][param2]);
				}
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				IsChooseItem(client);
		}
		case MenuAction_End:
			delete menu;
}
	return 0;
}

void MenuGetThrowable(int client)
{
	Menu menu = new Menu(iThrowable_MenuHandler);
	menu.SetTitle("物品\n—————");
	char string[4];
	for (int i = 0; i < 18; i++)
	{
		if(MenuThrowableOpen[i])
		{
			IntToString(i, string, sizeof(string));
			menu.AddItem(string, g_sItemName[3][i]);
		}
	}
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int iThrowable_MenuHandler(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char line[32];
			if (!menu.GetItem(param2, line, sizeof(line)))
				return 0;
			int num = StringToInt(line);
			if (num < 0 || num >= sizeof MenuThrowableOpen)
				return 0;
			if (CanGetItem(client, MenuThrowableOpen[num]))
			{
				if (num < 15)
					FormatEx(line, sizeof line, "give %s", g_sWeaponName[3][num]);
				else
					FormatEx(line, sizeof line, "upgrade_add %s", g_sWeaponName[3][num]);
				vCheatCommand(client, line);
				CPrintToChatAll( "{blue}❀ {green}%N {default}获取了 {blue}%s", client, g_sItemName[3][num]);
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				IsChooseItem(client);
		}
		case MenuAction_End:
			delete menu;
	}
	return 0;
}

void Menuadmin(int client)
{
	Menu menu = new Menu(iadmin_MenuHandler);
	menu.SetTitle("管理员菜单");
	char line[32];
	menu.AddItem("e", bmeleedefault ? "关闭副武器菜单" : "开启副武器菜单");
	menu.AddItem("f", binitialgundefault ? "关闭小枪菜单" : "开启小枪菜单");
	menu.AddItem("g", MenuAdvancedGunOpen ? "关闭大枪菜单" : "开启大枪菜单");
	FormatEx(line, sizeof(line), "道具菜单(%d)", ItemCount());
	menu.AddItem("h", line);
	menu.AddItem("i", bsafearea ? "允许安全区域外使用" : "禁止安全区域外使用");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int iadmin_MenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch(action)
	{
		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack)
				IsChooseItem(client);
		}
		case MenuAction_End:
			delete menu;
		case MenuAction_Select:
		{
			char sItem[2];
			if(menu.GetItem(itemNum, sItem, sizeof(sItem)))
			{
			switch(sItem[0])
				{
					case 'e':
					{
						bmeleedefault = !bmeleedefault;
						CPrintToChatAll( bmeleedefault ? "{blue}<管理员> {green}%N {default}开启了{blue}副武器{default}菜单" : "{blue}<管理员> {green}%N {default}关闭了{blue}副武器{default}菜单", client);
					}
					case 'f':
					{
						binitialgundefault = !binitialgundefault;
						CPrintToChatAll( binitialgundefault ? "{blue}<管理员> {green}%N {default}开启了{blue}小枪{default}菜单" : "{blue}<管理员> {green}%N {default}关闭了{blue}小枪{default}菜单", client);
					}
					case 'g':
					{
						MenuAdvancedGunOpen = !MenuAdvancedGunOpen;
						CPrintToChatAll( MenuAdvancedGunOpen ? "{blue}<管理员> {green}%N {default}开启了{blue}大枪{default}菜单" : "{blue}<管理员> {green}%N {default}关闭了{blue}大枪{default}菜单", client);
					}
					case 'h':
					{
						MenuItemAllow(client,0);
						// CPrintToChatAll( ItemCount ? "{blue}<管理员> {green}%N {default}开启了{blue}物品{default}菜单" : "{blue}<管理员> {green}%N {default}关闭了{blue}物品{default}菜单", client);
					}
					case 'i':
					{
						bsafearea = !bsafearea;
						CPrintToChatAll( bsafearea ? "{blue}<管理员> {green}%N {default}已禁止安全区域外使用{blue}E+R{default}功能" : "{blue}<管理员> {green}%N {default}已允许安全区域外使用{blue}E+R{default}功能", client);
					}
				}
			}
		}
	}
	return 0;
}

void MenuItemAllow(int client, int num)
{
	char line[32];
	Menu menu = new Menu(iItemAllow_MenuHandler);
	SetMenuTitle(menu, "已选择(%d)", ItemCount());
	for (int i = 0; i < 18; i++)
	{
		char string[4];
		IntToString(i, string, sizeof(string));
		if(MenuThrowableOpen[i])
		{
			FormatEx(line, sizeof(line), "%s	❀", g_sItemName[3][i]);
			menu.AddItem(string, line);
		}
		else
			menu.AddItem(string, g_sItemName[3][i]);
	}
	menu.ExitBackButton = true;
	menu.DisplayAt(client, num, MENU_TIME_FOREVER);
}

int iItemAllow_MenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch(action)
	{
		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack)
				Menuadmin(client);
		}
		case MenuAction_End:
			delete menu;
		case MenuAction_Select:
		{
			char line[32];
			if (!menu.GetItem(itemNum, line, sizeof(line)))
				return 0;
			int num = StringToInt(line);
			if (num < 0 || num >= sizeof MenuThrowableOpen)
				return 0;
			MenuThrowableOpen[num] = !MenuThrowableOpen[num];
			if(num<=6)
				MenuItemAllow(client, 0);
			else if(num<=13)
				MenuItemAllow(client, 7);
			else
				MenuItemAllow(client, 14);
		}
	}
	return 0;
}

void vCheatCommand(int client, const char[] sCommand) {
	if (!client || !IsClientInGame(client))
		return;

	char sCmd[32];
	if (SplitString(sCommand, " ", sCmd, sizeof sCmd) == -1)
		strcopy(sCmd, sizeof sCmd, sCommand);

	int iFlagBits, iCmdFlags;
	iFlagBits = GetUserFlagBits(client);
	iCmdFlags = GetCommandFlags(sCmd);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	SetCommandFlags(sCmd, iCmdFlags & ~FCVAR_CHEAT);
	FakeClientCommand(client, sCommand);
	SetUserFlagBits(client, iFlagBits);
	SetCommandFlags(sCmd, iCmdFlags);

	if (strcmp(sCmd, "give") == 0) {
		if (strcmp(sCommand[5], "ammo") == 0)
			vReloadAmmo(client);
	}
}

void vReloadAmmo(int client) {
	int weapon = GetPlayerWeaponSlot(client, 0);
	if (weapon <= MaxClients || !IsValidEntity(weapon))
		return;

	int m_iPrimaryAmmoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
	if (m_iPrimaryAmmoType == -1)
		return;

	char sWeapon[32];
	GetEntityClassname(weapon, sWeapon, sizeof sWeapon);
	if (strcmp(sWeapon[7], "grenade_launcher") == 0) {
		static ConVar hAmmoGrenadelau;
		if (hAmmoGrenadelau == null)
			hAmmoGrenadelau = FindConVar("ammo_grenadelauncher_max");

		SetEntProp(client, Prop_Send, "m_iAmmo", hAmmoGrenadelau.IntValue, _, m_iPrimaryAmmoType);
	}
}

int iGetClientImmunityLevel(int client) {

	char sSteamID[32];
	GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof sSteamID);
	AdminId admin = FindAdminByIdentity(AUTHMETHOD_STEAM, sSteamID);
	if (admin == INVALID_ADMIN_ID)
		return -999;
	return admin.ImmunityLevel;
}

//代码来自"https://steamcommunity.com/id/ChengChiHou/"
stock bool IsClientInSafeArea(int client)
{
	int nav = L4D_GetLastKnownArea(client);
	if(!nav)
		return false;
	int iAttr = L4D_GetNavArea_SpawnAttributes(view_as<Address>(nav));
	bool bInStartPoint = !!(iAttr & 0x80);
	bool bInCheckPoint = !!(iAttr & 0x800);
	if(!bInStartPoint && !bInCheckPoint)
		return false;
	return true;
}

int ItemCount()
{
	int count;
	for (int i; i < 18; i++)
	{
		if(MenuThrowableOpen[i])
			count++;
	}
	return count;
}
