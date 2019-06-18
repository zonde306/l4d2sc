#define PLUGIN_VERSION 		"1.1"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Special Infected Ability Movement
*	Author	:	SilverShot
*	Descrp	:	Continue normal movement speed while spitting/smoking/tank throwing rock
*	Link	:	http://forums.alliedmods.net/showthread.php?t=307330

========================================================================================
	Change Log:

1.1 (23-Aug-2018)
	- Fixed the Smoker not working correctly. Thanks to "phoenix0001" for reporting.

1.0 (05-May-2018)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define CVAR_FLAGS			FCVAR_NOTIFY


ConVar g_hCvarAllow, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarType, g_hSpeedSmoke, g_hSpeedSpit, g_hSpeedTank;
int g_iCvarAllow, g_iCvarType;
bool g_bCvarAllow, g_bLeft4Dead2;
float g_fSpeedSmoke, g_fSpeedSpit, g_fSpeedTank;

enum ()
{
	ENUM_SMOKE = 1,
	ENUM_SPITS = 2,
	ENUM_TANKS = 4
}



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "感染者使用技能时移动",
	author = "SilverShot",
	description = "Continue normal movement speed while spitting/smoking/tank throwing rocks.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=307330"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if (test == Engine_Left4Dead) g_bLeft4Dead2 = false;
	else if (test == Engine_Left4Dead2) g_bLeft4Dead2 = true;
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_hCvarAllow =		CreateConVar(	"l4d_infected_movement_allow",		"3",			"0=Plugin off, 1=Allow players only, 2=Allow bots only, 3=Both.", CVAR_FLAGS );
	g_hCvarType =		CreateConVar(	"l4d_infected_movement_type",		"7",			"These Special Infected can use: 1=Smoker, 2=Spitter, 4=Tank, 7=All.", CVAR_FLAGS );
	g_hCvarModes =		CreateConVar(	"l4d_infected_movement_modes",		"",				"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff =	CreateConVar(	"l4d_infected_movement_modes_off",	"",				"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog =	CreateConVar(	"l4d_infected_movement_modes_tog",	"0",			"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	CreateConVar(						"l4d_infected_movement_version",		PLUGIN_VERSION, "Ability Movement plugin version.", CVAR_FLAGS|FCVAR_DONTRECORD);
	AutoExecConfig(true,				"l4d_infected_movement");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarType.AddChangeHook(ConVarChanged_Cvars);

	g_hSpeedTank = FindConVar("z_tank_speed");
	g_hSpeedTank.AddChangeHook(ConVarChanged_Cvars);
	g_hSpeedSmoke = FindConVar("tongue_victim_max_speed");
	g_hSpeedSmoke.AddChangeHook(ConVarChanged_Cvars);

	if( g_bLeft4Dead2 )
	{
		g_hSpeedSpit = FindConVar("z_spitter_speed");
		g_hSpeedSpit.AddChangeHook(ConVarChanged_Cvars);
	}
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
	if( g_bLeft4Dead2 )
		g_fSpeedSpit = g_hSpeedSpit.FloatValue;
	g_fSpeedSmoke = g_hSpeedSmoke.FloatValue;
	g_fSpeedTank = g_hSpeedTank.FloatValue;
	g_iCvarType = g_hCvarType.IntValue;
}

void IsAllowed()
{
	g_iCvarAllow = g_hCvarAllow.IntValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && g_iCvarAllow && bAllowMode == true )
	{
		g_bCvarAllow = true;
		HookEvent("round_end", Event_Reset);
		HookEvent("round_start", Event_Reset);
		HookEvent("ability_use", Event_Use);
	}
	else if( g_bCvarAllow == true && (g_iCvarAllow == 0 || bAllowMode == false) )
	{
		g_bCvarAllow = false;
		UnhookEvent("round_end", Event_Reset);
		UnhookEvent("round_start", Event_Reset);
		UnhookEvent("ability_use", Event_Use);
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
static float g_fTime[MAXPLAYERS+1];

public void Event_Reset(Event event, const char[] name, bool dontBroadcast)
{
	ResetPlugin();
}

void ResetPlugin()
{
	for( int i = 0; i < sizeof(g_fTime[]); i++ )
	{
		g_fTime[i] = 0.0;
	}
}

public void Event_Use(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if( !client || !IsClientInGame(client) ) return;


	// Class check
	// Smoker = 1; Spitter = 4; Tank = 8
	int class = GetEntProp(client, Prop_Send, "m_zombieClass");
	if( !g_bLeft4Dead2 && class == 5 ) class = 8;
	switch( class )
	{
		case 1: class = 0;
		case 4: class = 1;
		case 8: class = 2;
		default: class = 99;
	}
	if( !(g_iCvarType & (1 << class)) ) return;


	// Bots check
	if( g_iCvarAllow != 3 )
	{
		bool fake = IsFakeClient(client);
		if( g_iCvarAllow == 1 && fake ) return;
		if( g_iCvarAllow == 2 && !fake ) return;
	}


	// Event check
	char sUse[16];
	event.GetString("ability", sUse, sizeof(sUse));
	if(
		(g_bLeft4Dead2 && strcmp(sUse, "ability_spit") == 0)
		|| strcmp(sUse, "ability_throw") == 0
		|| strcmp(sUse, "ability_tongue") == 0
	)
	{
		if( GetGameTime() - g_fTime[client] >= 3.0 )
		{
			// Hooked 3 times, because each alone is not enough, this creates the smoothest play with minimal movement stutter
			SDKHook(client, SDKHook_PostThinkPost, onThinkFunk);
			SDKHook(client, SDKHook_PreThink, onThinkFunk);
			SDKHook(client, SDKHook_PreThinkPost, onThinkFunk);
		}
		g_fTime[client] = GetGameTime();
	}
}

public void onThinkFunk(int client) //Dance
{
	if( IsClientInGame(client) )
	{
		if( GetGameTime() - g_fTime[client] < 3.0 )
		{
			SetEntPropFloat(client, Prop_Send, "m_flStamina", 0.0);

			int class = GetEntProp(client, Prop_Send, "m_zombieClass");
			if( class == 1 || class == 4 || class == 8 || (!g_bLeft4Dead2 && class == 5) )
			{
				SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", class == 4 ? g_fSpeedSpit : class == 1 ? g_fSpeedSmoke : g_fSpeedTank);
			}
		} else {
			g_fTime[client] = 0.0;
			SDKUnhook(client, SDKHook_PostThinkPost, onThinkFunk);
			SDKUnhook(client, SDKHook_PreThink, onThinkFunk);
			SDKUnhook(client, SDKHook_PreThinkPost, onThinkFunk);
		}
	}
}