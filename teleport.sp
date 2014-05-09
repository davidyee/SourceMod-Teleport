/**
 * Teleporter V1.0
 * By David Y.
 * Some code adapted from bobobagan's Player Respawn plugin V1.5 at
 * https://forums.alliedmods.net/showthread.php?t=108708
 *
 * Teleports the player to the admin's current location.
 */
 
#pragma semicolon 1
 
#include <sourcemod>
#include <sdktools>
#include <cstrike>
 
// from https://wiki.alliedmods.net/Admin_Menu_%28SourceMod_Scripting%29
/* Make the admin menu plugin optional */
#undef REQUIRE_PLUGIN
#include <adminmenu>

 /* Keep track of the top menu */
new Handle:hAdminMenu = INVALID_HANDLE;

public Plugin:myinfo =
{
	name = "Teleporter",
	author = "David",
	description = "Teleports players to the admin's current location",
	version = "1.0",
	url = ""
}

public OnPluginStart() {
	RegAdminCmd("sm_teleport", Command_Teleport, ADMFLAG_SLAY, "sm_teleport <#userid|name>");
	
	/* See if the menu plugin is already ready */
	new Handle:topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != INVALID_HANDLE))
	{
		/* If so, manually fire the callback */
		OnAdminMenuReady(topmenu);
	}
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
	/* Block us from being called twice */
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

		/* Re-draw the menu if they're still valid */
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
	
	new String:arg[65];
	GetCmdArg(1, arg, sizeof(arg));

	/* Try and find a matching player */
	new target = FindTarget(client, arg);
	if (target == -1)
	{
		/* FindTarget() automatically replies with the 
		 * failure reason.
		 */
		return Plugin_Handled;
	}
	
	TeleportPlayer(client, target);

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