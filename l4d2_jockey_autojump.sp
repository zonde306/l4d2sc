#define PLUGIN_VERSION 		"1.0"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D2] Jockey Auto Jump
*	Author	:	SilverShot (phoenix0001 idea)
*	Descrp	:	Makes the Jockey automatically jump when riding a survivor.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=316613
*	Plugins	:	http://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.0 (01-Jun-2019)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define CVAR_FLAGS			FCVAR_NOTIFY

ConVar g_hCvarAllow, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarBots, g_hCvarForce, g_hCvarTimeMin, g_hCvarTimeMax;
bool g_bCvarAllow, g_bRoundStart;
int g_iCvarBots;
float g_fCvarForce, g_fCvarTimeMin, g_fCvarTimeMax;



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "猴子自动起跳",
	author = "SilverShot",
	description = "Makes the Jockey automatically jump when riding a survivor.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=316613"
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
	// CVars
	g_hCvarAllow = CreateConVar(		"l4d2_jockey_autojump_allow",			"1",			"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarModes = CreateConVar(		"l4d2_jockey_autojump_modes",			"",				"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff = CreateConVar(		"l4d2_jockey_autojump_modes_off",		"",				"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog = CreateConVar(		"l4d2_jockey_autojump_modes_tog",		"0",			"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	g_hCvarBots = CreateConVar(			"l4d2_jockey_autojump_bots",			"1",			"0=Humans only. 1=Bots only. 2=Both.", CVAR_FLAGS );
	g_hCvarForce = CreateConVar(		"l4d2_jockey_autojump_force",			"300.0",		"The height of the jump, must be above 250.", CVAR_FLAGS, true, 251.0 );
	g_hCvarTimeMin = CreateConVar(		"l4d2_jockey_autojump_time_min",		"0.1",			"Min time before jumping again.", CVAR_FLAGS );
	g_hCvarTimeMax = CreateConVar(		"l4d2_jockey_autojump_time_max",		"0.5",			"Max time before jumping again.", CVAR_FLAGS );
	CreateConVar(						"l4d2_jockey_autojump_version",			PLUGIN_VERSION,	"Jockey Autojump plugin version.", FCVAR_DONTRECORD);
	AutoExecConfig(true,				"l4d2_jockey_autojump");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hCvarBots.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarForce.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarTimeMin.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarTimeMax.AddChangeHook(ConVarChanged_Cvars);
}



// ====================================================================================================
//					CVARS
// ====================================================================================================
public void OnConfigsExecuted()
{
	IsAllowed();
}

public void ConVarChanged_Allow(ConVar convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
}

public void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_iCvarBots = g_hCvarBots.IntValue;
	g_fCvarForce = g_hCvarForce.FloatValue;
	g_fCvarTimeMin = g_hCvarTimeMin.FloatValue;
	g_fCvarTimeMax = g_hCvarTimeMax.FloatValue;
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;
		g_bRoundStart = true;

		HookEvent("round_end",			Event_RoundEnd,		EventHookMode_PostNoCopy);
		HookEvent("round_start",		Event_RoundStart,	EventHookMode_PostNoCopy);
		HookEvent("jockey_ride",		Event_Jockey);
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;

		UnhookEvent("round_end",		Event_RoundEnd,		EventHookMode_PostNoCopy);
		UnhookEvent("round_start",		Event_RoundStart,	EventHookMode_PostNoCopy);
		UnhookEvent("jockey_ride",		Event_Jockey);
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
public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundStart = false;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundStart = true;
}

public void Event_Jockey(Event event, const char[] name, bool dontBroadcast)
{
	if( g_bRoundStart )
	{
		int userid = event.GetInt("userid");
		if( userid )
		{
			int client = GetClientOfUserId(userid);
			if( client && IsClientInGame(client) && GetClientTeam(client) == 3 )
			{
				if( g_iCvarBots != 2 )
				{
					bool fake = IsFakeClient(client);
					if( fake && g_iCvarBots == 0 ) return;
					if( !fake && g_iCvarBots == 1 ) return;
				}
				CreateTimer(GetRandomFloat(g_fCvarTimeMin, g_fCvarTimeMax), tmrJump, userid);
			}
		}
	}
}

void DoJump(int userid)
{
	if( g_bRoundStart )
	{
		int client = GetClientOfUserId(userid);
		if( client && IsClientInGame(client) && GetClientTeam(client) == 3 && IsPlayerAlive(client) )
		{
			// Player/bot takeover during jockey?
			if( g_iCvarBots != 2 )
			{
				bool fake = IsFakeClient(client);
				if( fake && g_iCvarBots == 0 ) return;
				if( !fake && g_iCvarBots == 1 ) return;
			}

			int victim = GetEntPropEnt(client, Prop_Send, "m_jockeyVictim");
			if( victim > 0 && IsClientInGame(victim) && IsPlayerAlive(victim) && GetEntPropEnt(victim, Prop_Send, "m_jockeyAttacker") == client)
			{
				if( GetEntProp(victim, Prop_Send, "m_fFlags") & FL_ONGROUND )
				{
					float vel[3];
					GetEntPropVector(victim, Prop_Send, "m_vecBaseVelocity", vel);
					vel[2] += g_fCvarForce;
					TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, vel);
					CreateTimer(GetRandomFloat(g_fCvarTimeMin, g_fCvarTimeMax), tmrJump, userid);
				} else {
					RequestFrame(OnFrame, userid);
				}
			}
		}
	}
}

public Action tmrJump(Handle timer, any userid)
{
	DoJump(userid);
}

void OnFrame(int userid)
{
	DoJump(userid);
}