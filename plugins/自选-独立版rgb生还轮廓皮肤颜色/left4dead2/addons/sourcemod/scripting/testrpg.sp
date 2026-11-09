#pragma newdecls required
/**/
#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>
#include <admin>
#undef REQUIRE_PLUGIN

#define PLUGIN_VERSION "1.0-RGB"

// Memory storage for player data (No Database)
enum struct PlayerStruct{
	int GlowType;
	int SkinType;
	bool Check;
}
PlayerStruct player[MAXPLAYERS + 1];

bool g_bEnableGlow = true;
bool g_bGodFrameSystemAvailable = false;

public Plugin myinfo =
{
	name = "生还者RGB皮肤光圈 (Lite)",
	author = "Modified by AI",
	description = "免费的生还者皮肤与轮廓设定",
	version = PLUGIN_VERSION,
	url = ""
}

public void OnAllPluginsLoaded()
{
    g_bGodFrameSystemAvailable = LibraryExists("l4d2_godframes_control_merge");
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "l4d2_godframes_control_merge")) { g_bGodFrameSystemAvailable = true; }
}

public void OnLibraryRemoved(const char[] name)
{
    if (StrEqual(name, "l4d2_godframes_control_merge")) { g_bGodFrameSystemAvailable = false; }
}

public void OnPluginStart()
{
    // Register the main command
    RegConsoleCmd("sm_rgb", Command_RGB, "打开皮肤和轮廓菜单");

    // Hooks
    HookEvent("player_spawn", 	Event_Player_Spawn, 			EventHookMode_Pre);
    HookEvent("player_team", 	Event_PlayerTeam, 	            EventHookMode_Post);
    // Note: We do not hook player_death to clear variables, ensuring colors persist on respawn
}

public void OnClientDisconnect(int client)
{
    if (client > 0 && client <= MaxClients)
    {
        // Reset variables when player leaves so the ID isn't dirty for next user
        DisableGlow(client);
        DisableSkin(client);
        player[client].GlowType = 0;
        player[client].SkinType = 0;
        player[client].Check = false;
    }
}

// God frame compatibility from source
public void L4D2_GodFrameRenderChange(int client){
	if(g_bGodFrameSystemAvailable && player[client].SkinType){
		GetSkin(client, player[client].SkinType, false);
	}
}

// ---------------------------------------------------------
// Command & Main Menu
// ---------------------------------------------------------

public Action Command_RGB(int client, int args)
{
    if(IsValidClient(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2)
    {
        BuildRGBMenu(client);
    }
    else
    {
        ReplyToCommand(client, "\x04[RGB]\x03 只能在存活且为生还者时使用。");
    }
    return Plugin_Handled;
}

public void BuildRGBMenu(int client)
{
    Menu menu = new Menu(MenuHandler_RGB);
    menu.SetTitle("☆☆ 个性化外观设置 ☆☆\n—————————");
    
    menu.AddItem("glow", "生还者轮廓 (Glow)");
    menu.AddItem("skin", "生还者皮肤 (Skin)");
    
    menu.Display(client, 20);
}

public int MenuHandler_RGB(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        char info[32];
        menu.GetItem(param2, info, sizeof(info));
        
        if (StrEqual(info, "glow"))
            Survivor_glow(param1);
        else if (StrEqual(info, "skin"))
            Survivor_skin(param1);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

// ---------------------------------------------------------
// Glow Menu & Logic (Copied & Cleaned)
// ---------------------------------------------------------

public void Survivor_glow(int client)
{
	if( IsValidClient(client) )
	{
		Menu menu = new Menu(VIPAuraMenuHandler);
		menu.SetTitle("生还者轮廓\n——————————");
		menu.AddItem("option0", "关闭\n ", player[client].GlowType == 0 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
		
        // Valid for everyone now
        menu.AddItem("option1", "绿色", player[client].GlowType == 1 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        menu.AddItem("option2", "蓝色", player[client].GlowType == 2 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        menu.AddItem("option3", "藍紫色", player[client].GlowType == 3 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        menu.AddItem("option4", "青色", player[client].GlowType == 4 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        menu.AddItem("option5", "橘黄色", player[client].GlowType == 5 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        menu.AddItem("option6", "红色", player[client].GlowType == 6 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        menu.AddItem("option7", "灰色", player[client].GlowType == 7 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        menu.AddItem("option8", "黄色", player[client].GlowType == 8 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        menu.AddItem("option9", "酸橙色", player[client].GlowType == 9 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        menu.AddItem("option10", "栗色", player[client].GlowType == 10 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        menu.AddItem("option11", "藍綠色", player[client].GlowType == 11 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        menu.AddItem("option12", "粉红色", player[client].GlowType == 12 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        menu.AddItem("option13", "紫色", player[client].GlowType == 13 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        menu.AddItem("option14", "白色", player[client].GlowType == 14 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        menu.AddItem("option15", "金黄色", player[client].GlowType == 15 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        menu.AddItem("option16", "彩虹色", player[client].GlowType == 16 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        
        // Customized check removed or kept generic if desired, simplified here to standard 17
        menu.AddItem("option17", "定制轮廓", player[client].GlowType == 17 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

		menu.ExitButton = true;
        // Back button to main menu
        menu.ExitBackButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
	}
}

public int VIPAuraMenuHandler(Menu menu, MenuAction action, int param1, int param2) 
{
    switch (action) 
    {
        case MenuAction_End:
            delete menu;
        case MenuAction_Cancel:
            if(param2 == MenuCancel_ExitBack) BuildRGBMenu(param1);
        case MenuAction_Select: 
        {
            char option[64];
            menu.GetItem(param2, option, sizeof(option));
            char result[2][6];
            ExplodeString(option, "option", result, 2, 6);
            
            int id = StringToInt(result[1], 10);
            GetAura(param1, id);
			
            Survivor_glow( param1 );
        }
    }
    return 0;
}

void GetAura(int client, int id) 
{
    switch (id) 
    {
        case 0: 
        {    
            DisableGlow( client );
            player[client].GlowType = id;
            return;
        }
        case 1: 
        {
            SetEntProp(client, Prop_Send, "m_glowColorOverride", 0 + (255 * 256) + (0 * 65536));
            CPrintToChat(client, "\x05你 \x04将轮廓颜色改为\x01: \x04绿色 \x01!");
        }
        case 2: 
        {
            SetEntProp(client, Prop_Send, "m_glowColorOverride", 7 + (19 * 256) + (250 * 65536));
            CPrintToChat(client, "\x05你 \x04将轮廓颜色改为\x01: \x04蓝色 \x01!");
        }
        case 3: 
        {
            SetEntProp(client, Prop_Send, "m_glowColorOverride", 249 + (19 * 256) + (250 * 65536));
            CPrintToChat(client, "\x05你 \x04将轮廓颜色改为\x01: \x04蓝紫色 \x01!");
        }
        case 4: 
        {
            SetEntProp(client, Prop_Send, "m_glowColorOverride", 66 + (250 * 256) + (250 * 65536));
            CPrintToChat(client, "\x05你 \x04将轮廓颜色改为\x01: \x04青色 \x01!");
        }
        case 5: 
        {
            SetEntProp(client, Prop_Send, "m_glowColorOverride", 249 + (155 * 256) + (84 * 65536));
            CPrintToChat(client, "\x05你 \x04将轮廓颜色改为\x01: \x04橘黄色 \x01!");
        }
        case 6: 
        {
            SetEntProp(client, Prop_Send, "m_glowColorOverride", 255 + (0 * 256) + (0 * 65536));
            CPrintToChat(client, "\x05你 \x04将轮廓颜色改为\x01: \x04红色 \x01!");
        }
        case 7: 
        {
            SetEntProp(client, Prop_Send, "m_glowColorOverride", 50 + (50 * 256) + (50 * 65536));
            CPrintToChat(client, "\x05你 \x04将轮廓颜色改为\x01: \x04灰色 \x01!");
        }
        case 8: 
        {
            SetEntProp(client, Prop_Send, "m_glowColorOverride", 255 + (255 * 256) + (0 * 65536));
            CPrintToChat(client, "\x05你 \x04将轮廓颜色改为\x01: \x04黄色 \x01!");
        }
        case 9: 
        {
            SetEntProp(client, Prop_Send, "m_glowColorOverride", 128 + (255 * 256) + (0 * 65536));
            CPrintToChat(client, "\x05你 \x04将轮廓颜色改为\x01: \x04酸橙色 \x01!");
        }
        case 10: 
        {
            SetEntProp(client, Prop_Send, "m_glowColorOverride", 128 + (0 * 256) + (0 * 65536));
            CPrintToChat(client, "\x05你 \x04将轮廓颜色改为\x01: \x04栗色 \x01!");
        }
        case 11: 
        {
            SetEntProp(client, Prop_Send, "m_glowColorOverride", 0 + (128 * 256) + (128 * 65536));
            CPrintToChat(client, "\x05你 \x04将轮廓颜色改为\x01: \x04藍綠色 \x01!");
        }
        case 12:
        {
            SetEntProp(client, Prop_Send, "m_glowColorOverride", 255 + (0 * 256) + (150 * 65536));
            CPrintToChat(client, "\x05你 \x04将轮廓颜色改为\x01: \x04粉红色 \x01!");
        }
        case 13:
        {        
            SetEntProp(client, Prop_Send, "m_glowColorOverride", 155 + (0 * 256) + (255 * 65536));
            CPrintToChat(client, "\x05你 \x04将轮廓颜色改为\x01: \x04紫色 \x01!");
        }
        case 14: 
        {
            SetEntProp(client, Prop_Send, "m_glowColorOverride", -1 + (-1 * 256) + (-1 * 65536));
            CPrintToChat(client, "\x05你 \x04将轮廓颜色改为\x01: \x04白色 \x01!");
        }
        case 15: 
        {
            SetEntProp(client, Prop_Send, "m_glowColorOverride", 255 + (155 * 256) + (0 * 65536));
            CPrintToChat(client, "\x05你 \x04将轮廓颜色改为\x01: \x04金黄色 \x01!");
        }
        case 16: 
        {
            SDKHook(client, SDKHook_PreThink, RainbowPlayer);
            CPrintToChat(client, "\x05你 \x04将轮廓颜色改为\x01: \x04彩虹色 \x01!");
        }
		case 17:
		{
            SetEntProp(client, Prop_Send, "m_glowColorOverride", 255 + (69 * 256) + (0 * 65536));
            CPrintToChat(client, "\x05你 \x04将轮廓颜色改为您的\x01: \x04定制颜色轮廓 \x01!");
		}
    }

	if ((id >= 0 && id <= 15) || id >= 17)    {
        SetEntProp(client, Prop_Send, "m_iGlowType", 3);
        SetEntProp(client, Prop_Send, "m_nGlowRange", 99999);
        SetEntProp(client, Prop_Send, "m_nGlowRangeMin", 0);
		
        SDKUnhook(client, SDKHook_PreThink, RainbowPlayer);
    }
    
    player[client].GlowType = id;
}

void DisableGlow( int client )
{
	if( IsValidClient( client ))
	{		
		SetEntProp(client, Prop_Send, "m_glowColorOverride", 0);
		SetEntProp(client, Prop_Send, "m_iGlowType", 0);
		SDKUnhook(client, SDKHook_PreThink, RainbowPlayer);
	}
}

public Action RainbowPlayer(int client)
{
	if( IsValidClient( client ) != true || IsPlayerAlive(client) != true || GetClientTeam( client ) == 3 )
	{
		SDKUnhook(client, SDKHook_PreThink, RainbowPlayer);
        if( GetClientTeam( client ) == 3 )
		{
			SetEntProp(client, Prop_Send, "m_glowColorOverride", 0);
			SetEntProp(client, Prop_Send, "m_iGlowType", 0);
		}
		
		return Plugin_Handled;
    }
    
	SetEntProp(client, Prop_Send, "m_glowColorOverride", RoundToNearest(Cosine((GetGameTime() * 8.0) + client + 1) * 127.5 + 127.5) + (RoundToNearest(Cosine((GetGameTime() * 8.0) + client + 3) * 127.5 + 127.5) * 256) + (RoundToNearest(Cosine((GetGameTime() * 8.0) + client + 5) * 127.5 + 127.5) * 65536));
	SetEntProp(client, Prop_Send, "m_iGlowType", 3);
	SetEntProp(client, Prop_Send, "m_nGlowRange", 99999);
	SetEntProp(client, Prop_Send, "m_nGlowRangeMin", 0);
	return Plugin_Continue;
}

// ---------------------------------------------------------
// Skin Menu & Logic (Copied & Cleaned)
// ---------------------------------------------------------

public void Survivor_skin(int client)
{
	if( IsValidClient(client) )
	{
		Menu menu = new Menu(VIPSkinMenuHandler);
		menu.SetTitle("生还者皮肤颜色\n——————————");
		menu.AddItem("option0", "关闭\n ", player[client].SkinType == 0 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
		
        // Valid for everyone
        menu.AddItem("option1", "绿色", player[client].SkinType == 1 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        menu.AddItem("option2", "蓝色", player[client].SkinType == 2 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        menu.AddItem("option3", "藍紫色", player[client].SkinType == 3 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        menu.AddItem("option4", "青色", player[client].SkinType == 4 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        menu.AddItem("option5", "橘黄色", player[client].SkinType == 5 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        menu.AddItem("option6", "红色", player[client].SkinType == 6 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        menu.AddItem("option7", "灰色", player[client].SkinType == 7 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        menu.AddItem("option8", "黄色", player[client].SkinType == 8 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        menu.AddItem("option9", "酸橙色", player[client].SkinType == 9 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        menu.AddItem("option10", "栗色", player[client].SkinType == 10 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        menu.AddItem("option11", "藍綠色", player[client].SkinType == 11 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        menu.AddItem("option12", "粉红色", player[client].SkinType == 12 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        menu.AddItem("option13", "紫色", player[client].SkinType == 13 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        menu.AddItem("option14", "黑色", player[client].SkinType == 14 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        menu.AddItem("option15", "金黄色", player[client].SkinType == 15 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        menu.AddItem("option16", "透明色", player[client].SkinType == 16 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        menu.AddItem("option17", "定制皮肤", player[client].SkinType == 17 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        
		menu.ExitButton = true;
        menu.ExitBackButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
	}
}

public int VIPSkinMenuHandler(Menu menu, MenuAction action, int param1, int param2) 
{
    switch (action) 
    {
        case MenuAction_End:
            delete menu;
        case MenuAction_Cancel:
            if(param2 == MenuCancel_ExitBack) BuildRGBMenu(param1);
        case MenuAction_Select: 
        {
            char option[64];
            menu.GetItem(param2, option, sizeof(option));
            char result[2][6];
            ExplodeString(option, "option", result, 2, 6);
            
            GetSkin(param1, StringToInt(result[1], 10));
            
            Survivor_skin( param1 );
        }
    }
    return 0;
}

void GetSkin(int client, int id, bool broadcast = true) 
{
    switch (id) 
    {
        case 0: 
        {    
            DisableSkin( client );
            player[client].SkinType = id;
            if(broadcast)
            	PrintToChat(client, "\x05你关闭了生还者轮廓");
            return;
        }
        case 1: 
        {
            SetEntityRenderMode(client, RENDER_GLOW);
            SetEntityRenderColor(client, 0, 255, 0, 255);
            if(broadcast)
            	CPrintToChat(client, "\x05你 \x04将皮肤颜色改为\x01: \x04绿色 \x01!");
        }
        case 2: 
        {
            SetEntityRenderMode(client, RENDER_GLOW);
            SetEntityRenderColor(client, 7, 19, 250, 255);
            if(broadcast)
            	CPrintToChat(client, "\x05你 \x04将皮肤颜色改为\x01: \x04蓝色 \x01!");
        }
        case 3: 
        {
            SetEntityRenderMode(client, RENDER_GLOW);
            SetEntityRenderColor(client, 249, 19, 250, 255);
            if(broadcast)
            	CPrintToChat(client, "\x05你 \x04将皮肤颜色改为\x01: \x04蓝紫色 \x01!");
        }
        case 4: 
        {
            SetEntityRenderMode(client, RENDER_GLOW);
            SetEntityRenderColor(client, 66, 250, 250, 255);
            if(broadcast)
            	CPrintToChat(client, "\x05你 \x04将皮肤颜色改为\x01: \x04青色 \x01!");
        }
        case 5: 
        {
            SetEntityRenderMode(client, RENDER_GLOW);
            SetEntityRenderColor(client, 249, 155, 84, 255);
            if(broadcast)
            	CPrintToChat(client, "\x05你 \x04将皮肤颜色改为\x01: \x04橘黄色 \x01!");
        }
        case 6: 
        {
            SetEntityRenderMode(client, RENDER_GLOW);
            SetEntityRenderColor(client, 255, 0, 0, 255);
            if(broadcast)
            	CPrintToChat(client, "\x05你 \x04将皮肤颜色改为\x01: \x04红色 \x01!");
        }
        case 7: 
        {
            SetEntityRenderMode(client, RENDER_GLOW);
            SetEntityRenderColor(client, 50, 50, 50, 255);
            if(broadcast)
            	CPrintToChat(client, "\x05你 \x04将皮肤颜色改为\x01: \x04灰色 \x01!");
        }
        case 8: 
        {
            SetEntityRenderMode(client, RENDER_GLOW);
            SetEntityRenderColor(client, 255, 255, 0, 255);
            if(broadcast)
            	CPrintToChat(client, "\x05你 \x04将皮肤颜色改为\x01: \x04黄色 \x01!");
        }
        case 9: 
        {
            SetEntityRenderMode(client, RENDER_GLOW);
            SetEntityRenderColor(client, 128, 255, 0, 255);
            if(broadcast)
            	CPrintToChat(client, "\x05你 \x04将皮肤颜色改为\x01: \x04酸橙色 \x01!");
        }
        case 10: 
        {
            SetEntityRenderMode(client, RENDER_GLOW);
            SetEntityRenderColor(client, 128, 0, 0, 255);
            if(broadcast)
            	CPrintToChat(client, "\x05你 \x04将皮肤颜色改为\x01: \x04栗色 \x01!");
        }
        case 11: 
        {
            SetEntityRenderMode(client, RENDER_GLOW);
            SetEntityRenderColor(client, 0, 128, 128, 255);
            if(broadcast)
            	CPrintToChat(client, "\x05你 \x04将皮肤颜色改为\x01: \x04藍綠色 \x01!");
        }
        case 12:
        {
            SetEntityRenderMode(client, RENDER_GLOW);
            SetEntityRenderColor(client, 255, 0, 150, 255);
            if(broadcast)
            	CPrintToChat(client, "\x05你 \x04将皮肤颜色改为\x01: \x04粉红色 \x01!");
        }
        case 13:
        {        
            SetEntityRenderMode(client, RENDER_GLOW);
            SetEntityRenderColor(client, 155, 0, 255, 255);
            if(broadcast)
            	CPrintToChat(client, "\x05你 \x04将皮肤颜色改为\x01: \x04紫色 \x01!");
        }
        case 14: 
        {
            SetEntityRenderMode(client, RENDER_GLOW);
            SetEntityRenderColor(client, 0, 0, 0, 255);
            if(broadcast)
            	CPrintToChat(client, "\x05你 \x04将皮肤颜色改为\x01: \x04黑色 \x01!");
        }
        case 15: 
        {
            SetEntityRenderMode(client, RENDER_GLOW);
            SetEntityRenderColor(client, 255, 155, 0, 255);
            if(broadcast)
            	CPrintToChat(client, "\x05你 \x04将皮肤颜色改为\x01: \x04金黄色 \x01!");
        }
        case 16: 
        {
            SetEntityRenderMode(client, RENDER_GLOW);
            SetEntityRenderColor(client, 0, 0, 0, 30);
            if(broadcast)
            	CPrintToChat(client, "\x05你 \x04将皮肤颜色改为\x01: \x04透明色 \x01!");
        }
		case 17:
		{
            SetEntityRenderMode(client, RENDER_GLOW);
            SetEntityRenderColor(client, 139, 101, 8, 255);
            if(broadcast)
            	CPrintToChat(client, "\x05你 \x04将皮肤颜色改为\x01: \x04您的定制皮肤 \x01!");
        }
    }
    
    player[client].SkinType = id;
}

void DisableSkin( int client )
{
	if( IsValidClient( client ))
	{		
		SetEntityRenderMode(client, RENDER_NORMAL);
		SetEntityRenderColor(client, 255, 255, 255, 255);
	}
}

// ---------------------------------------------------------
// Event Handling & Persistence
// ---------------------------------------------------------

public void Event_Player_Spawn(Event hEvent, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId( hEvent.GetInt( "userid" ));
	if( client && IsClientInGame( client ) && !player[client].Check){
		player[client].Check = true;
		CreateTimer( 0.3, PlayerSpawnTimer, GetClientUserId( client ), TIMER_FLAG_NO_MAPCHANGE );
	}
}

stock bool IsPlayerGhost( int client )
{
	if( GetEntProp( client, Prop_Send, "m_isGhost", 1 ) ) 
		return true;
	return false;
} 

public Action PlayerSpawnTimer( Handle hTimer, any UserID )
{
	int client = GetClientOfUserId( UserID );
	if( client <= 0 || IsClientConnected( client ) != true )
		return Plugin_Handled;
        
	if( GetClientTeam( client ) == 2 && IsPlayerGhost( client ) != true )
	{
        // Re-apply settings from memory
		if(player[client].GlowType && g_bEnableGlow)
			GetAura(client, player[client].GlowType);
		
		if(player[client].SkinType)
			GetSkin(client, player[client].SkinType, false);
	}
	else if( GetClientTeam( client ) == 3 )
	{
		DisableGlow( client );
		DisableSkin( client );
	}
	player[client].Check = false;
	return Plugin_Continue;
}

public void Event_PlayerTeam(Event hEvent, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId (hEvent.GetInt("userid"));
	int iTeam = hEvent.GetInt("team");
    
	if( iTeam == 2 )
	{
		if(player[client].GlowType && g_bEnableGlow)
			GetAura(client,player[client].GlowType);
		if(player[client].SkinType)
			GetSkin(client, player[client].SkinType, false);
	}
	if( iTeam == 3 ) {
		DisableGlow( client );
		DisableSkin( client );
	}
}

public bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client));
}