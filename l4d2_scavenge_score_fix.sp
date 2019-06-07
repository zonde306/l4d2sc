#define PLUGIN_VERSION 		"1.2"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D2] Scavenge Score Fix - Gascan Pouring
*	Author	:	SilverShot
*	Descrp	:	Fixes the score / gascan pour count from increasing when plugins use the 'point_prop_use_target' entity.
*	Link	:	http://forums.alliedmods.net/showthread.php?t=187686
*	Plugins	:	http://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.2 (05-May-2018)
	- Converted plugin source to the latest syntax utilizing methodmaps. Requires SourceMod 1.8 or newer.

1.1 (10-Aug-2013)
	- Fixed a rare bug which could crash the server.

1.0 (16-Jun-2012)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define MAX_NOZZLES 16

int g_iCountNozzles, g_iLateLoad, g_iPlayerSpawn, g_iPrevented, g_iRoundStart, g_iNozzles[MAX_NOZZLES], g_iPouring[MAXPLAYERS+1];



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D2] Scavenge Score Fix - Gascan Pouring",
	author = "SilverShot",
	description = "Fixes the score / gascan generator pour count from increasing when plugins use the 'point_prop_use_target' entity.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=187686"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}

	g_iLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("l4d2_scavenge_score_fix",		PLUGIN_VERSION,		"Gascan Pour Fix plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	HookEvent("round_end",					Event_RoundEnd,		EventHookMode_PostNoCopy);
	HookEvent("round_start",				Event_RoundStart,	EventHookMode_PostNoCopy);
	HookEvent("player_spawn",				Event_PlayerSpawn,	EventHookMode_PostNoCopy);
	HookEvent("gascan_pour_completed",		Event_PourGasDone,	EventHookMode_Pre);

	if( g_iLateLoad )
		FindPropUseTarget();
}

public void OnMapEnd()
{
	for( int i = 1; i <= MaxClients; i++ )
		g_iPouring[i] = 0;
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for( int i = 1; i <= MaxClients; i++ )
		g_iPouring[i] = 0;
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iPlayerSpawn == 1 && g_iRoundStart == 0 )
		FindPropUseTarget();
	g_iRoundStart = 1;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iPlayerSpawn == 0 && g_iRoundStart == 1 )
		FindPropUseTarget();
	g_iPlayerSpawn = 1;
}

void FindPropUseTarget()
{
	g_iPrevented = 0;
	g_iCountNozzles = 0;

	for( int i = 1; i <= MaxClients; i++ )
		g_iPouring[i] = 0;

	for( int i = 0; i < MAX_NOZZLES; i++ )
		g_iNozzles[i] = 0;

	int entity = -1;
	while( g_iCountNozzles < MAX_NOZZLES && (entity = FindEntityByClassname(entity, "point_prop_use_target")) != -1 )
	{
		g_iNozzles[g_iCountNozzles++] = EntIndexToEntRef(entity);
		HookSingleEntityOutput(entity, "OnUseStarted", OnUseStarted);
		HookSingleEntityOutput(entity, "OnUseCancelled", OnUseCancelled);
	}
}

public void OnUseStarted(const char[] output, int caller, int activator, float delay)
{
	int weapon = GetEntPropEnt(caller, Prop_Send, "m_useActionOwner");
	if( weapon > 0 && IsValidEntity(weapon) )
	{
		int client = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
		if( client > 0 && client <= MaxClients )
			g_iPouring[client] = EntIndexToEntRef(caller);
	}
}

public void OnUseCancelled(const char[] output, int caller, int activator, float delay)
{
	caller = EntIndexToEntRef(caller);

	for( int i = 1; i <= MaxClients; i++ )
	{
		if( g_iPouring[i] == caller )
		{
			g_iPouring[i] = 0;
			break;
		}
	}
}

public Action Event_PourGasDone(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iCountNozzles == 0 )
	{
		return Plugin_Continue;
	}

	int client = GetClientOfUserId(event.GetInt("userid"));

	// Allow, legit pouring
	if( g_iPouring[client] != 0 )
	{
		if( g_iPrevented )
		{
			int left = GameRules_GetProp("m_nScavengeItemsRemaining");
			GameRules_SetProp("m_nScavengeItemsRemaining", left + g_iPrevented, 0, 0, true);
		}

		g_iPouring[client] = 0;
		return Plugin_Continue;
	}

	// Do we have to block?
	bool valid;
	for( int i = 0; i < MAX_NOZZLES; i++ )
	{
		if( IsValidEntRef(g_iNozzles[i]) )
		{
			valid = true;
			break;
		}
	}

	// No
	if( valid == false )
	{
		return Plugin_Continue;
	}

	// Yes, prevent score bugs.
	int flip = GameRules_GetProp("m_bAreTeamsFlipped");
	int done = GameRules_GetProp("m_iScavengeTeamScore", 4, flip);
	if( done > 0 )
	{
		g_iPrevented++;
		int left = GameRules_GetProp("m_nScavengeItemsRemaining");
		if( left > 0 )
		{
			float time = GameRules_GetPropFloat("m_flAccumulatedTime");
			GameRules_SetProp("m_iScavengeTeamScore", done - 1, 4, flip, false);
			GameRules_SetProp("m_nScavengeItemsRemaining", left + g_iPrevented, 4, 0, true);
			GameRules_SetPropFloat("m_flAccumulatedTime", time - 20.0);
		}

		return Plugin_Handled;
	}

	return Plugin_Continue;
}

bool IsValidEntRef(int entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		return true;
	return false;
}