#define PLUGIN_VERSION		"1.1"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Physics Push Fix
*	Author	:	SilverShot
*	Descrp	:	Prevents firework crates, gascans, oxygen and propane tanks being pushed when players walk into them.
*	Link	:	http://forums.alliedmods.net/showthread.php?t=184889
*	Plugins	:	http://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.1 (05-May-2018)
	- Converted plugin source to the latest syntax utilizing methodmaps. Requires SourceMod 1.8 or newer.

1.0 (10-May-2012)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

public Plugin myinfo =
{
	name = "修复走路推油桶",
	author = "SilverShot",
	description = "Prevents firework crates, gascans, oxygen and propane tanks being pushed when players walk into them.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=184889"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead && test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("l4d_physics_push_version", PLUGIN_VERSION, "Physics Push Fix plugin version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if( strcmp(classname, "prop_physics") == 0 || strcmp(classname, "physics_prop") == 0 )
		CreateTimer(0.0, tmrEntity, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
}

public Action tmrEntity(Handle timer, any entity)
{
	if( (entity = EntRefToEntIndex(entity)) != INVALID_ENT_REFERENCE && GetEntProp(entity, Prop_Send, "m_CollisionGroup") == 11 )
	{
		char sTemp[48];
		GetEntPropString(entity, Prop_Data, "m_ModelName", sTemp, sizeof(sTemp));

		if( strcmp(sTemp, "models/props_equipment/oxygentank01.mdl") == 0 || strcmp(sTemp, "models/props_junk/explosive_box001.mdl") == 0 || strcmp(sTemp, "models/props_junk/gascan001a.mdl") == 0 || strcmp(sTemp, "models/props_junk/propanecanister001a.mdl") == 0 )
			SetEntProp(entity, Prop_Send, "m_CollisionGroup", 0);
	}
}