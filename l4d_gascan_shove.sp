/*
This plugin is a minor modification of "l4d_molotov_shove" by "SilverShot".
Credits to SilverShot.
Download Molotov Shove: http://forums.alliedmods.net/showthread.php?t=187941
*/

#define PLUGIN_VERSION 		"1.0"
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define CVAR_FLAGS			FCVAR_NOTIFY

ConVar g_hCvarAllow, g_hCvarInfected, g_hCvarLimit, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarTimed, g_hCvarTimeout;
int g_iCvarInfected, g_iCvarLimit, g_iCvarTimed, g_iLimiter[MAXPLAYERS+1];
bool g_bCvarAllow;
float g_fCvarTimeout;

public Plugin myinfo =
{
	name = "Gascan Shove",
	author = "Axel Juan Nieves",
	description = "Ignites infected when shoved by players holding a gascan.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?p=2632889"
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
	g_hCvarAllow = CreateConVar(		"l4d_gascan_shove_allow",			"1",			"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarModes = CreateConVar(		"l4d_gascan_shove_modes",			"",				"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff = CreateConVar(		"l4d_gascan_shove_modes_off",		"",				"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog = CreateConVar(		"l4d_gascan_shove_modes_tog",		"0",			"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	g_hCvarInfected = CreateConVar(		"l4d_gascan_shove_infected",		"511",			"1=Common, 2=Witch, 4=Smoker, 8=Boomer, 16=Hunter, 32=Spitter, 64=Jockey, 128=Charger, 256=Tank, 511=All.", CVAR_FLAGS );
	g_hCvarLimit = CreateConVar(		"l4d_gascan_shove_limit",			"0",			"0=Infinite. How many times per round can someone use their gascan to ignite infected.", CVAR_FLAGS );
	g_hCvarTimed = CreateConVar(		"l4d_gascan_shove_timed",			"256",			"These infected use l4d_gascan_shove_timeout, otherwise they burn forever. 0=None, 1=All, 2=Witch, 4=Smoker, 8=Boomer, 16=Hunter, 32=Spitter, 64=Jockey, 128=Charger, 256=Tank.", CVAR_FLAGS );
	g_hCvarTimeout = CreateConVar(		"l4d_gascan_shove_timeout",		"10.0",			"0=Forever. How long should the infected be ignited for?", CVAR_FLAGS );
	CreateConVar(						"l4d_gascan_shove_version",		PLUGIN_VERSION,	"Molotov Shove plugin version.", CVAR_FLAGS|FCVAR_DONTRECORD);
	AutoExecConfig(true,				"l4d_gascan_shove");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hCvarInfected.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarLimit.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarTimed.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarTimeout.AddChangeHook(ConVarChanged_Cvars);
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
	g_iCvarLimit = g_hCvarLimit.IntValue;
	g_iCvarTimed = g_hCvarTimed.IntValue;
	g_fCvarTimeout = g_hCvarTimeout.FloatValue;
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;
		HookEvent("round_end", Event_RoundEnd);
		HookEvent("entity_shoved", Event_EntityShoved);
		HookEvent("player_shoved", Event_PlayerShoved);
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;
		UnhookEvent("round_end", Event_RoundEnd);
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

public void OnMapEnd()
{
	ResetPlugin();
}

void ResetPlugin()
{
	for( int i = 1; i <= MaxClients; i++ )
	{
		g_iLimiter[i] = 0;
	}
}



// ====================================================================================================
//					EVENTS
// ====================================================================================================
public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	ResetPlugin();
}

public void Event_EntityShoved(Event event, const char[] name, bool dontBroadcast)
{
	int infected = g_iCvarInfected & (1<<0);
	int witch = g_iCvarInfected & (1<<1);
	if( infected || witch )
	{
		int client = GetClientOfUserId(event.GetInt("attacker"));

		if( g_iCvarLimit && g_iLimiter[client] >= g_iCvarLimit )
			return;

		if( CheckWeapon(client) )
		{
			int target = event.GetInt("entityid");

			char sTemp[32];
			GetEntityClassname(target, sTemp, sizeof(sTemp));

			if( infected && strcmp(sTemp, "infected") == 0 )
			{
				HurtPlayer(target, client, 0);
				g_iLimiter[client]++;
			}
			else if( witch && strcmp(sTemp, "witch") == 0 )
			{
				HurtPlayer(target, client, g_iCvarTimed == 1 || g_iCvarTimed & (1<<1));
				g_iLimiter[client]++;
			}
		}
	}
}

public void Event_PlayerShoved(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("attacker"));

	if( g_iCvarLimit && g_iLimiter[client] >= g_iCvarLimit )
		return;

	int target = GetClientOfUserId(event.GetInt("userid"));
	if( GetClientTeam(target) == 3 && CheckWeapon(client) )
	{
		int class = GetEntProp(target, Prop_Send, "m_zombieClass") + 1;
		if( class == 9 ) class = 8;
		if( g_iCvarInfected & (1 << class) )
		{
			HurtPlayer(target, client, class);
			g_iLimiter[client]++;
		}
	}
}

void HurtPlayer(int target, int client, int class)
{
	char sTemp[16];
	int entity = GetEntPropEnt(target, Prop_Data, "m_hEffectEntity");
	if( entity != -1 && IsValidEntity(entity) )
	{
		GetEntityClassname(entity, sTemp, sizeof(sTemp));
		if( strcmp(sTemp, "entityflame") == 0 )
		{
			return;
		}
	}

	entity = CreateEntityByName("point_hurt");
	Format(sTemp, sizeof(sTemp), "ext%d%d", entity, client);
	DispatchKeyValue(target, "targetname", sTemp);
	DispatchKeyValue(entity, "DamageTarget", sTemp);
	DispatchKeyValue(entity, "DamageType", "8");
	DispatchSpawn(entity);
	AcceptEntityInput(entity, "Hurt", client);
	RemoveEdict(entity);

	if( g_fCvarTimeout && g_iCvarTimed && class )
	{
		if( g_iCvarTimed == 1 || g_iCvarTimed & (1 << class) )
		{
			entity = GetEntPropEnt(target, Prop_Data, "m_hEffectEntity");
			if( entity != -1 )
			{
				GetEntityClassname(entity, sTemp, sizeof(sTemp));
				if( strcmp(sTemp, "entityflame") == 0 )
				{
					SetEntPropFloat(entity, Prop_Data, "m_flLifetime", GetGameTime() + g_fCvarTimeout);
				}
			}
		}
	}
}

bool CheckWeapon(int client)
{
	if( client && IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2 )
	{
		int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if( weapon > 0 && IsValidEntity(weapon) )
		{
			char sTemp[32];
			GetEntityClassname(weapon, sTemp, sizeof(sTemp));
			if( strcmp(sTemp, "weapon_gascan") == 0 )
				return true;
		}
	}
	return false;
}