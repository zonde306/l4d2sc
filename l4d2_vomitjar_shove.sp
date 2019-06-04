#define PLUGIN_VERSION 		"1.4"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D2] Vomitjar Shove
*	Author	:	SilverShot
*	Descrp	:	Biles infected when shoved by players holding vomitjars.
*	Link	:	http://forums.alliedmods.net/showthread.php?t=188045
*	Plugins	:	http://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.4 (05-May-2018)
	- Converted plugin source to the latest syntax utilizing methodmaps. Requires SourceMod 1.8 or newer.

1.3.1 (24-Mar-2018)
	- Added a couple checks to prevent errors being logged - Thanks to "Crasher_3637" for reporting.
	- Fixed self-vomit effect disappearing after ~5 seconds.
	- Updated gamedata txt file.

1.3 (14-May-2017)
	- Added cvar "l4d2_vomitjar_shove_radius" - Distance to splash nearby survivors when the vomitjar breaks.
	- Added cvar "l4d2_vomitjar_shove_splash" - Chance out of 100 to splash self and nearby players when the vomitjar breaks.

1.2 (07-Aug-2013)
	- Fixed the cvar "l4d2_vomitjar_shove_punch" to work correctly.

1.1 (21-Jul-2013)
	- Added cvar "l4d2_vomitjar_shove_punch" to control how many hits a vomitjar can make before breaking.

1.0 (21-Jun-2012)
	- Initial release.

========================================================================================

	This plugin was made using source code from the following plugins.
	If I have used your code and not credited you, please let me know.

*	Thanks to "AtomicStryker" for "Bile the World" - Used SDK code and gamedata file to bile players.
	http://forums.alliedmods.net/showthread.php?t=132264

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define CVAR_FLAGS			FCVAR_NOTIFY
#define MAX_ENTS			64

Handle sdkOnVomitedUpon, sdkVomitInfected, sdkVomitSurvivor;
ConVar g_hCvarAllow, g_hCvarInfected, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarPunch, g_hCvarRadius, g_hCvarSplash;
int g_iCvarInfected, g_iCvarPunch, g_iCvarRadius, g_iCvarSplash, g_iPunches[MAX_ENTS][2];
bool g_bCvarAllow;



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D2] Vomitjar Shove",
	author = "SilverShot",
	description = "Biles infected when shoved by players holding vomitjars.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=188045"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	Handle hGameConf = LoadGameConfigFile("l4d2_vomitjar_shove");
	if( hGameConf == null )
	{
		SetFailState("Couldn't find the offsets and signatures file. Please, check that it is installed correctly.");
	}

	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "Infected_OnHitByVomitJar");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	sdkVomitInfected = EndPrepSDKCall();
	if( sdkVomitInfected == null )
	{
		SetFailState("Unable to find the \"Infected_OnHitByVomitJar\" signature, check the file version!");
	}

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CTerrorPlayer_OnHitByVomitJar");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	sdkVomitSurvivor = EndPrepSDKCall();
	if( sdkVomitSurvivor == null )
	{
		SetFailState("Unable to find the \"CTerrorPlayer_OnHitByVomitJar\" signature, check the file version!");
	}

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CTerrorPlayer_OnVomitedUpon");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	sdkOnVomitedUpon = EndPrepSDKCall();
	if( sdkOnVomitedUpon == null )
	{
		SetFailState("Unable to find the \"CTerrorPlayer_OnVomitedUpon\" signature, check the file version!");
	}


	g_hCvarAllow = CreateConVar(	"l4d2_vomitjar_shove_allow",			"1",			"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarModes = CreateConVar(	"l4d2_vomitjar_shove_modes",			"",				"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff = CreateConVar(	"l4d2_vomitjar_shove_modes_off",		"",				"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog = CreateConVar(	"l4d2_vomitjar_shove_modes_tog",		"0",			"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	g_hCvarPunch = CreateConVar(	"l4d2_vomitjar_shove_punch",			"5",			"0=Unlimited. How many times can a player hit zombies with the vomitjar before it breaks.", CVAR_FLAGS );
	g_hCvarRadius = CreateConVar(	"l4d2_vomitjar_shove_radius",			"50",			"0=Only the player holding the vomitjar. Distance to splash nearby survivors when the vomitjar breaks.", CVAR_FLAGS );
	g_hCvarSplash = CreateConVar(	"l4d2_vomitjar_shove_splash",			"10",			"Chance out of 100 to splash self and nearby players when the vomitjar breaks.", CVAR_FLAGS );
	g_hCvarInfected = CreateConVar(	"l4d2_vomitjar_shove_infected",			"511",			"1=Common, 2=Witch, 4=Smoker, 8=Boomer, 16=Hunter, 32=Spitter, 64=Jockey, 128=Charger, 256=Tank, 511=All.", CVAR_FLAGS );
	CreateConVar(					"l4d2_vomitjar_shove_version",			PLUGIN_VERSION,	"Vomitjar Shove plugin version.", CVAR_FLAGS|FCVAR_DONTRECORD);
	AutoExecConfig(true,			"l4d2_vomitjar_shove");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hCvarPunch.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarRadius.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarSplash.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarInfected.AddChangeHook(ConVarChanged_Cvars);
}



// ====================================================================================================
//					CVARS
// ====================================================================================================
public void OnConfigsExecuted()
{
	IsAllowed();
}

public void ConVarChanged_Allow(Handle convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
}

public void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_iCvarInfected = g_hCvarInfected.IntValue;
	g_iCvarPunch = g_hCvarPunch.IntValue;
	g_iCvarRadius = g_hCvarRadius.IntValue;
	g_iCvarSplash = g_hCvarSplash.IntValue;
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;
		HookEvent("entity_shoved", Event_EntityShoved);
		HookEvent("player_shoved", Event_PlayerShoved);
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;
		UnhookEvent("entity_shoved", Event_EntityShoved);
		UnhookEvent("player_shoved", Event_PlayerShoved);
	}
}

int g_iCurrentMode;
bool IsAllowedGameMode()
{
	if( g_hCvarMPGameMode == null )
		return false;

	int iCvarModesTog = g_hCvarModesTog.IntValue;
	if( iCvarModesTog != 0 )
	{
		g_iCurrentMode = 0;

		int entity = CreateEntityByName("info_gamemode");
		DispatchSpawn(entity);
		HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
		ActivateEntity(entity);
		AcceptEntityInput(entity, "PostSpawnActivate");
		AcceptEntityInput(entity, "Kill");

		if( g_iCurrentMode == 0 )
			return false;

		if( !(iCvarModesTog & g_iCurrentMode) )
			return false;
	}

	char sGameModes[64], sGameMode[64];
	g_hCvarMPGameMode.GetString(sGameMode, sizeof(sGameMode));
	Format(sGameMode, sizeof(sGameMode), ",%s,", sGameMode);

	g_hCvarModes.GetString(sGameModes, sizeof(sGameModes));
	if( strcmp(sGameModes, "") )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) == -1 )
			return false;
	}

	g_hCvarModesOff.GetString(sGameModes, sizeof(sGameModes));
	if( strcmp(sGameModes, "") )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) != -1 )
			return false;
	}

	return true;
}

public void OnGamemode(const char[] output, int caller, int activator, float delay)
{
	if( strcmp(output, "OnCoop") == 0 )
		g_iCurrentMode = 1;
	else if( strcmp(output, "OnSurvival") == 0 )
		g_iCurrentMode = 2;
	else if( strcmp(output, "OnVersus") == 0 )
		g_iCurrentMode = 4;
	else if( strcmp(output, "OnScavenge") == 0 )
		g_iCurrentMode = 8;
}



// ====================================================================================================
//					EVENTS
// ====================================================================================================
public void Event_EntityShoved(Event event, const char[] name, bool dontBroadcast)
{
	int infected = g_iCvarInfected & (1<<0);
	int witch = g_iCvarInfected & (1<<1);
	if( infected || witch )
	{
		int client = GetClientOfUserId(event.GetInt("attacker"));

		int weapon = CheckWeapon(client);
		if( weapon )
		{
			int target = event.GetInt("entityid");

			char sTemp[32];
			GetEdictClassname(target, sTemp, sizeof(sTemp));

			if( (infected && strcmp(sTemp, "infected") == 0 ) || (witch && strcmp(sTemp, "witch") == 0) )
			{
				HurtPlayer(target, client, false);
				DoRemove(client, weapon);
			}
		}
	}
}

public void Event_PlayerShoved(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("attacker"));
	int target = GetClientOfUserId(event.GetInt("userid"));

	if( GetClientTeam(target) == 3 )
	{
		int weapon = CheckWeapon(client);
		if( weapon )
		{
			int class = GetEntProp(target, Prop_Send, "m_zombieClass") + 1;
			if( class == 9 ) class = 8;
			if( g_iCvarInfected & (1 << class) )
			{
				HurtPlayer(target, client, true);
				DoRemove(client, weapon);
			}
		}
	}
}

void DoRemove(int client, int weapon)
{
	bool remove = false;

	if( g_iCvarPunch )
	{
		if( g_iCvarPunch == 1 )
		{
			remove = true;
		} else {
			int index = GetEnt(weapon);
			if( index == -1 )
			{
				SetEnt(weapon);
			} else {
				g_iPunches[index][1]++;
				int count = g_iPunches[index][1];

				if( count >= g_iCvarPunch )
				{
					remove = true;
					g_iPunches[index][0] = 0;
					g_iPunches[index][1] = 0;
				}
			}
		}
	}

	if( remove )
	{
		RemovePlayerItem(client, weapon);
		AcceptEntityInput(weapon, "Kill");

		if( g_iCvarSplash > 0 )
		{
			if( g_iCvarSplash >= GetRandomInt(1, 100) )
			{
				// nearby g_iCvarRadius
				float vPos[3];
				float vOur[3];

				GetClientAbsOrigin(client, vOur);

				for( int i = 1; i <= MaxClients; i++ )
				{
					if( IsClientInGame(i) && IsPlayerAlive(i) )
					{
						GetClientAbsOrigin(i, vPos);
						if( GetVectorDistance(vPos, vOur) <= g_iCvarRadius )
						{
							HurtPlayer(i, client, true);
						}
					}
				}
			}
		}
	}
}

void HurtPlayer(int target, int client, bool special)
{
	if( special )
	{
		if( GetClientTeam(target) == 2 )
			SDKCall(sdkOnVomitedUpon, target, false);
		else
			SDKCall(sdkVomitSurvivor, target, client, true);
	}
	else
		SDKCall(sdkVomitInfected, target, client, true);
}

int CheckWeapon(int client)
{
	if( client && IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2 )
	{
		int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if( weapon > 0 && IsValidEntity(weapon) )
		{
			char sTemp[32];
			GetEdictClassname(weapon, sTemp, sizeof(sTemp));
			if( strcmp(sTemp, "weapon_vomitjar") == 0 )
				return weapon;
		}
	}
	return 0;
}

int GetEnt(int entity)
{
	entity = EntIndexToEntRef(entity);

	for( int i = 0; i < MAX_ENTS; i++ )
	{
		if( g_iPunches[i][0] == entity )
		{
			return i;
		}
	}

	return -1;
}

bool SetEnt(int entity)
{
	entity = EntIndexToEntRef(entity);

	for( int i = 0; i < MAX_ENTS; i++ )
	{
		if( IsValidEntRef(g_iPunches[i][0]) == false )
		{
			g_iPunches[i][0] = entity;
			g_iPunches[i][1] = 1;
			return true;
		}
	}

	return false;
}

bool IsValidEntRef(int entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		return true;
	return false;
}