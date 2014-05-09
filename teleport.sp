/**
 * Teleporter V1.0
 * By David Y.
 * Some menu code adapted from bobobagan's Player Respawn plugin V1.5 at
 * https://forums.alliedmods.net/showthread.php?t=108708
 * ProcessTargetString adapted from Thrawn2's forum post snippet at
 * https://forums.alliedmods.net/showpost.php?p=1265410&postcount=2
 * to enable @all support via chat messages
 * Other code adapted from Official AlliedMods Wiki pages:
 * Activities and Logging https://wiki.alliedmods.net/Introduction_to_SourceMod_Plugins
 * Admin Menu: https://wiki.alliedmods.net/Admin_Menu_%28SourceMod_Scripting%29
 *
 * Teleports the player to the admin's current location. Tested only with CS:GO.
 * You can teleport a player via the admin menu or in chat using: "!teleport <name>" or 
 * you can also teleport players using "!teleport @all".
 */
 
#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <cstrike>

// make the admin menu plugin optional
#undef REQUIRE_PLUGIN
#include <adminmenu>

// keep track of the top menu
new Handle:hAdminMenu = INVALID_HANDLE;

public Plugin:myinfo =
{
	name = "Teleporter",
	author = "David",
	description = "Teleports players to the admin's current location",
	version = "1.0",
	url = "http://www.sourcemod.net/"
}

public OnPluginStart() {
	RegAdminCmd("sm_teleport", Command_Teleport, ADMFLAG_SLAY, "sm_teleport <#userid|name>");
	
	// see if the menu plugin is already ready
	new Handle:topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != INVALID_HANDLE))
	{
		// if so, manually fire the callback
		OnAdminMenuReady(topmenu);
	}
	
	LoadTranslations("common.phrases");
}

public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "adminmenu"))
	{
		hAdminMenu = INVALID_HANDLE;
	}
}

public OnAdminMenuReady(Handle:topmenu)
{
	// block us from being called twice
	if (topmenu == hAdminMenu)
	{
		return;
	}
 
	hAdminMenu = topmenu;
 
	// add menu item
	new TopMenuObject:player_commands = FindTopMenuCategory(hAdminMenu, ADMINMENU_PLAYERCOMMANDS);

	if (player_commands != INVALID_TOPMENUOBJECT)
	{
		AddToTopMenu(hAdminMenu,
		"sm_teleport",
		TopMenuObject_Item,
		AdminMenu_Teleport,
		player_commands,
		"sm_teleport",
		ADMFLAG_SLAY);
	}
}

public AdminMenu_Teleport( Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength )
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Teleport Player");
	}
	else if( action == TopMenuAction_SelectOption)
	{
		DisplayPlayerMenu(param);
	}
}

DisplayPlayerMenu(client)
{
	new Handle:menu = CreateMenu(MenuHandler_Players);

	decl String:title[100];
	Format(title, sizeof(title), "Choose Player to Respawn:");
	SetMenuTitle(menu, title);
	SetMenuExitBackButton(menu, true);

	// only add alive players because we don't want to teleport dead players
	AddTargetsToMenu2(menu, client, COMMAND_FILTER_ALIVE);

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public MenuHandler_Players(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && hAdminMenu != INVALID_HANDLE)
		{
			DisplayTopMenu(hAdminMenu, param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		decl String:info[32];
		new userid, target;

		GetMenuItem(menu, param2, info, sizeof(info));
		userid = StringToInt(info);

		if ((target = GetClientOfUserId(userid)) == 0)
		{
			PrintToChat(param1, "[SM] %t", "Player no longer available");
		}
		else if (!CanUserTarget(param1, target))
		{
			PrintToChat(param1, "[SM] %t", "Unable to target");
		}
		else
		{
			new String:target_name[32];
			new String:param1_name[MAX_NAME_LENGTH];
			GetClientName(target, target_name, sizeof(target_name));
			GetClientName(param1, param1_name, sizeof(param1_name));

			TeleportPlayer(param1, target);
		}

		// re-draw the menu if they're still valid
		if (IsClientInGame(param1) && !IsClientInKickQueue(param1))
		{
			DisplayPlayerMenu(param1);
		}
	}
}

public Action:Command_Teleport(client, args) {
	if (args < 1)
		{
			ReplyToCommand(client, "[SM] Usage: sm_teleport <#userid|name>");
			return Plugin_Handled;
		}
	
	decl String:arg[32];
	GetCmdArg(1, arg, sizeof(arg));

    // process the targets
	decl String:strTargetName[MAX_TARGET_LENGTH];
	decl TargetList[MAXPLAYERS], TargetCount;
	decl bool:TargetTranslate;
	
	TargetCount = ProcessTargetString(
						arg, 
						client, 
						TargetList, 
						MAXPLAYERS, 
						COMMAND_FILTER_ALIVE, 
						strTargetName, 
						sizeof(strTargetName), 
						TargetTranslate);

	// if there are no players alive
	if (TargetCount <= COMMAND_TARGET_NONE)
    {
        ReplyToTargetError(client, TargetCount);
        return Plugin_Handled;
    }

    // apply to all targets
	for (new i = 0; i < TargetCount; i++)
    {
		new target = TargetList[i];
		if (IsClientInGame(target) ) { // add "&& !IsFakeClient(target)" to not teleport BOTS
			TeleportPlayer(client, target);
		}
    }
	
	return Plugin_Handled;
}

public TeleportPlayer(client, target)
{
	new String:target_name[MAX_NAME_LENGTH];
	new String:client_name[MAX_NAME_LENGTH];
	GetClientName(target, target_name, sizeof(target_name));
	GetClientName(client, client_name, sizeof(client_name));
	
	new Float:ModelAng[3], Float:ModelPos[3];
	GetClientEyeAngles(client, ModelAng);
	GetClientAbsOrigin(client, ModelPos);
	TeleportEntity(target, ModelPos, ModelAng, NULL_VECTOR);
	
	// ReplyToCommand(client, "[SM] You teleported %s!", target_name);
	ShowActivity2(client, "[SM] ", "Teleported %s to %s's location!", target_name, client_name);
	LogAction(client, target, "\"%L\" teleported \"%L\"", client, target);
}