/**
 * Teleporter V1.0
 * By David Y.
 *
 * Teleports the player to the admin's current location.
 */
 
 #pragma semicolon 1
 
 #include <sourcemod>
 #include <sdktools>
 #include <cstrike>
 #include <adminmenu>
 
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
	
	ReplyToCommand(client, "[SM] You teleported %s!", target_name);
	ShowActivity2(client, "[SM] ", "Teleported %s to %s's location!", target_name, client_name);
	LogAction(client, target, "\"%L\" teleported \"%L\"", client, target);

	new Float:ModelAng[3], Float:ModelPos[3];
	GetClientEyeAngles(client, ModelAng);
	GetClientAbsOrigin(client, ModelPos);
	TeleportEntity(target, ModelPos, ModelAng, NULL_VECTOR);
}