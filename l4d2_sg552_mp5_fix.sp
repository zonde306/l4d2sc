#pragma semicolon 1
#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.0"

public Plugin:myinfo = 
{
	name = "SG552和MP5换弹过慢修复",
	author = "McFlurry",
	description = "Fixes the reload time of SG552 and MP5",
	version = PLUGIN_VERSION,
	url = "N/A"
}

public OnPluginStart()
{
	decl String:game_name[64];
	GetGameFolderName(game_name, sizeof(game_name));
	if (!StrEqual(game_name, "left4dead2", false))
	{
		SetFailState("Plugin supports Left 4 Dead 2 only.");
	}
	CreateConVar("l4d2_sg552_mp5_fix_version", PLUGIN_VERSION, "Installed version of SG552 and MP5 Reload Fix on this server", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_REPLICATED);
	HookEvent("weapon_reload", Event_ReloadStart);
}

public Action:Event_ReloadStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	new userid = GetEventInt(event, "userid");
	new client = GetClientOfUserId(userid);
	new weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	new String:classname[256];
	GetEntityClassname(weapon, classname, sizeof(classname));
	if(StrContains(classname, "sg552", false) > -1 || StrContains(classname, "mp5", false) > -1)
	{
		new Float:nextattack;
		nextattack = GetEntPropFloat(client, Prop_Send, "m_flNextAttack");
		nextattack -= 0.6;
		SetEntPropFloat(client, Prop_Send, "m_flNextAttack", nextattack);
		SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", nextattack);
	}	
}