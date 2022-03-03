/*
*	Scavenge Score Fix - Gascan Pouring
*	Copyright (C) 2021 Silvers
*
*	This program is free software: you can redistribute it and/or modify
*	it under the terms of the GNU General Public License as published by
*	the Free Software Foundation, either version 3 of the License, or
*	(at your option) any later version.
*
*	This program is distributed in the hope that it will be useful,
*	but WITHOUT ANY WARRANTY; without even the implied warranty of
*	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*	GNU General Public License for more details.
*
*	You should have received a copy of the GNU General Public License
*	along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/



#define PLUGIN_VERSION 		"2.4"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D2] Scavenge Score Fix - Gascan Pouring
*	Author	:	SilverShot
*	Descrp	:	Fixes the score and gascan pour count from increasing when plugins use the 'point_prop_use_target' entity. Also respawns gascans when used for something other than a Scavenge event.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=187686
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

2.4 (07-Oct-2021)
	- Fixed not detecting Scavenge gascans the game respawns. Thanks to "a2121858" for reporting.

2.3 (06-Oct-2021)
	- Added cvar "l4d2_scavenge_score_respawn" to set the timer until a Scavenge gascan is respawned.
	- Now creates a cvar config saved as "l4d2_scavenge_score".
	- Now respawns Scavenge event gascans when poured for something other than the Scavenge event.
	- GameData file updated.

2.2 (03-Oct-2021)
	- Added a delay to detect "point_prop_use_target" entities. Thanks to "a2121858" for reporting.

2.1 (25-Feb-2021)
	- Fixed a mistake that would have broken the plugin if multiple 'point_prop_use_target' entities existed on the map.

2.0 (25-Feb-2021)
	- Completely changed the blocking method. Now requires DHooks to properly block the call and prevent score bugs.
	- Thanks to "Lux" for help with this method.

1.3 (10-May-2020)
	- Various changes to tidy up code.

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
#include <dhooks>

#define RANGE_MAX				30.0	// Maximum range for Scavenge gascans to match with their spawner
#define MAX_NOZZLES				16		// Maximum nozzles on the map
#define DEBUGGING				0

#define CVAR_FLAGS				FCVAR_NOTIFY
#define GAMEDATA				"l4d2_scavenge_score_fix"

int g_iCountNozzles, g_iLateLoad, g_iPlayerSpawn, g_iRoundStart, g_iNozzles[MAX_NOZZLES];
int g_iScavenge[2048];
// bool g_bWatchSpawn;
float g_fCvarRespawn;
ConVar g_hCvarRespawn;



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D2] Scavenge Score Fix - Gascan Pouring",
	author = "SilverShot",
	description = "Fixes the score and gascan pour count from increasing when plugins use the 'point_prop_use_target' entity. Also respawns gascans when used for something other than a Scavenge event.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=187686"
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
	// ====================
	// DETOUR
	// ====================
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	if( FileExists(sPath) == false ) SetFailState("\n==========\nMissing required file: \"%s\".\nRead installation instructions again.\n==========", sPath);

	Handle hGameData = LoadGameConfigFile(GAMEDATA);
	if( hGameData == null ) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	Handle hDetour = DHookCreateFromConf(hGameData, "CGasCan::OnActionComplete");

	if( !hDetour )
		SetFailState("Failed to find \"CGasCan::OnActionComplete\" signature.");

	if( !DHookEnableDetour(hDetour, false, OnActionComplete) )
		SetFailState("Failed to detour \"CGasCan::OnActionComplete\".");

	delete hDetour;
	delete hGameData;



	// ====================
	// CVAR / EVENTS
	// ====================
	g_hCvarRespawn = CreateConVar(	"l4d2_scavenge_score_respawn",		"20.0",				"0.0=Off. Any other value is number of seconds until respawning a gascan when used for something other than a Scavenge pour event.", CVAR_FLAGS);
	CreateConVar(					"l4d2_scavenge_score_fix",			PLUGIN_VERSION,		"Gascan Pour Fix plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true, "l4d2_scavenge_score");

	g_hCvarRespawn.AddChangeHook(ConVarChanged_Cvars);

	HookEvent("round_end",			Event_RoundEnd,		EventHookMode_PostNoCopy);
	HookEvent("round_start",		Event_RoundStart,	EventHookMode_PostNoCopy);
	HookEvent("player_spawn",		Event_PlayerSpawn,	EventHookMode_PostNoCopy);

	g_fCvarRespawn = g_hCvarRespawn.FloatValue;

	if( g_iLateLoad )
	{
		FindPropUseTarget();

		if( g_fCvarRespawn )
		{
			FindScavengeGas();
		}
	}
}

public void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	g_fCvarRespawn = g_hCvarRespawn.FloatValue;
	if( g_fCvarRespawn )
	{
		FindScavengeGas();
	}
}



// ====================================================================================================
// DETOUR
// ====================================================================================================
public MRESReturn OnActionComplete(int pThis, Handle hReturn, Handle hParams)
{
	int entity = DHookGetParam(hParams, 2);
	entity = EntIndexToEntRef(entity);

	// Do we have to block?
	for( int i = 0; i < MAX_NOZZLES; i++ )
	{
		if( g_iNozzles[i] && EntRefToEntIndex(g_iNozzles[i]) != INVALID_ENT_REFERENCE )
		{
			// Pouring into scavenge target? Allow
			for( int x = 0; x < MAX_NOZZLES; x++ )
			{
				if( g_iNozzles[x] == entity )
				{
					#if DEBUGGING
					PrintToChatAll("SSF: GCasCan Scavenge: Allowed");
					#endif

					return MRES_Ignored;
				}
			}
		}
	}

	// ====================
	// BLOCK
	// ====================
	int client = DHookGetParam(hParams, 1);

	#if DEBUGGING
	PrintToChatAll("SSF: GCasCan Scavenge: Blocked");
	#endif

	// Respawn gascan
	if( g_fCvarRespawn )
	{
		#if DEBUGGING
		PrintToChatAll("SSF: Check TimerRespawn %d", pThis);
		#endif

		if( g_iScavenge[pThis] && EntRefToEntIndex(g_iScavenge[pThis]) != INVALID_ENT_REFERENCE )
		{
			#if DEBUGGING
			PrintToChatAll("SSF: Start TimerRespawn %d", pThis);
			#endif

			CreateTimer(g_fCvarRespawn, TimerRespawn, g_iScavenge[pThis]);
		}
	}

	// Fire event
	Event hEvent = CreateEvent("gascan_pour_completed", true);
	if( hEvent != null )
	{
		hEvent.SetInt("userid", GetClientUserId(client));
		hEvent.Fire();
	}

	// Fire output
	FireEntityOutput(entity, "OnUseFinished", client);

	// Block call
	DHookSetReturn(hReturn, 0);
	return MRES_Supercede;
}



// ====================================================================================================
// FIND point_prop_use_target
// ====================================================================================================
public void OnMapEnd()
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iPlayerSpawn == 1 && g_iRoundStart == 0 )
		CreateTimer(5.0, TimerStart, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iRoundStart = 1;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iPlayerSpawn == 0 && g_iRoundStart == 1 )
		CreateTimer(5.0, TimerStart, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iPlayerSpawn = 1;
}

public Action TimerStart(Handle timer)
{
	FindPropUseTarget();

	if( g_fCvarRespawn )
	{
		FindScavengeGas();
	}
}

void FindPropUseTarget()
{
	g_iCountNozzles = 0;

	for( int i = 0; i < MAX_NOZZLES; i++ )
		g_iNozzles[i] = 0;

	int entity = -1;
	while( g_iCountNozzles < MAX_NOZZLES && (entity = FindEntityByClassname(entity, "point_prop_use_target")) != INVALID_ENT_REFERENCE )
	{
		g_iNozzles[g_iCountNozzles++] = EntIndexToEntRef(entity);

		#if DEBUGGING
		PrintToChatAll("SSF: Found %d == %d", g_iCountNozzles, entity);
		#endif
	}
}



// ====================================================================================================
// Match Scavenge spawners with Gascans
// ====================================================================================================
public void OnEntityCreated(int entity, const char[] classname)
{
	// if( g_bWatchSpawn && strcmp(classname, "weapon_gascan") == 0 )
	if( strcmp(classname, "weapon_gascan") == 0 )
	{
		CreateTimer(0.1, DelayedSpawn, EntIndexToEntRef(entity));
		// g_bWatchSpawn = false;
	}
}

// Delay before finding matching spawner. Next frame required for getting vPos, but too early because the gascan takes time to fall into position so it would be near enough to spawner
public Action DelayedSpawn(Handle timer, int entity)
{
	entity = EntRefToEntIndex(entity);

	if( entity != INVALID_ENT_REFERENCE )
	{
		FindScavengeGas(entity);
	}
}

public Action TimerRespawn(Handle timer, any entity)
{
	entity = EntRefToEntIndex(entity);

	#if DEBUGGING
	PrintToChatAll("SSF: TimerRespawn %d", entity);
	#endif

	if( entity != INVALID_ENT_REFERENCE )
	{
		#if DEBUGGING
		PrintToChatAll("SSF: Do TimerRespawn %d", entity);
		#endif

		// g_bWatchSpawn = true;
		AcceptEntityInput(entity, "SpawnItem");
		// g_bWatchSpawn = false;
	}
}

void FindScavengeGas(int target = 0)
{
	#if DEBUGGING
	int counter;
	PrintToChatAll("SSF: FindScavengeGas %d", target);
	#endif

	float vPos[3], vVec[3];

	int entity = -1;
	int gascan = -1;
	float dist = 99999.9;
	float range;
	int matched;

	// Find matching spawner for given entity
	if( target && EntRefToEntIndex(target) == INVALID_ENT_REFERENCE ) return;

	if( target )
	{
		GetEntPropVector(target, Prop_Send, "m_vecOrigin", vVec);
	}
	while( (entity = FindEntityByClassname(entity, "weapon_scavenge_item_spawn")) != INVALID_ENT_REFERENCE )
	{
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vPos);

		// Find spawner for specific gascan
		if( target )
		{
			range = GetVectorDistance(vPos, vVec);

			if( range < dist )
			{
				dist = range;
				matched = entity;
			}
		}
		// Search through all and match
		else
		{
			gascan = -1;
			dist = 99999.9;

			while( (gascan = FindEntityByClassname(gascan, "weapon_gascan")) != INVALID_ENT_REFERENCE )
			{
				int skin = GetEntProp(gascan, Prop_Send, "m_nSkin");
				if( skin )
				{
					GetEntPropVector(gascan, Prop_Send, "m_vecOrigin", vVec);
					range = GetVectorDistance(vPos, vVec);

					if( range < dist )
					{
						dist = range;
						matched = gascan;
					}
				}
			}

			// All
			if( matched && dist <= RANGE_MAX )
			{
				#if DEBUGGING
				counter++;
				PrintToChatAll("SSF: MATCHED %d == %d", matched, entity);
				#endif

				g_iScavenge[matched] = EntIndexToEntRef(entity);
				matched = 0;
			}
		}
	}

	#if DEBUGGING
	PrintToChatAll("SSF: MATCHED %d", counter);
	#endif

	// Specific
	if( target && matched && dist <= RANGE_MAX )
	{
		#if DEBUGGING
		PrintToChatAll("SSF: MATCHED TARGET %d == %d", target, matched);
		#endif

		g_iScavenge[target] = EntIndexToEntRef(matched);
	}
}



// ====================================================================================================
// OLD METHOD - LEFT HERE FOR DEMONSTRATION PURPOSES - NO LONGER WORKS
// ====================================================================================================
/*
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
	url = "https://forums.alliedmods.net/showthread.php?t=187686"
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
	while( g_iCountNozzles < MAX_NOZZLES && (entity = FindEntityByClassname(entity, "point_prop_use_target")) != INVALID_ENT_REFERENCE )
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
// */