#define PLUGIN_VERSION 		"1.1"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Tongue Damage
*	Author	:	SilverShot
*	Descrp	:	Control the Smokers tongue damage when pulling a Survivor.
*	Link	:	http://forums.alliedmods.net/showthread.php?t=318959
*	Plugins	:	http://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.1 (29-Nov-2019)
	- Fixed invalid timer errors - Thanks to "BlackSabbarh" for reporting.

1.0 (02-Oct-2019)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define CVAR_FLAGS			FCVAR_NOTIFY

ConVar g_hCvarAllow, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarDamage, g_hCvarTime;
bool g_bCvarAllow;
bool g_bChoking[MAXPLAYERS+1];
Handle g_iTimers[MAXPLAYERS+1];



// ====================================================================================================
//					PLUGIN INFO / START
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D & L4D2] Tongue Damage",
	author = "SilverShot",
	description = "Control the Smokers tongue damage when pulling a Survivor.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=318959"
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
	g_hCvarAllow =			CreateConVar(	"l4d_tongue_damage_allow",			"1",				"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarModes =			CreateConVar(	"l4d_tongue_damage_modes",			"",					"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff =		CreateConVar(	"l4d_tongue_damage_modes_off",		"",					"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog =		CreateConVar(	"l4d_tongue_damage_modes_tog",		"12",				"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	g_hCvarDamage =			CreateConVar(	"l4d_tongue_damage_damage",			"5.0",				"How much damage to apply.", CVAR_FLAGS );
	g_hCvarTime =			CreateConVar(	"l4d_tongue_damage_time",			"0.5",				"How often to damage players.", CVAR_FLAGS );
	CreateConVar(							"l4d_tongue_damage_version",		PLUGIN_VERSION,		"Tongue Damage plugin version.", CVAR_FLAGS|FCVAR_DONTRECORD);
	AutoExecConfig(true,					"l4d_tongue_damage");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
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

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;
		HookEvent("choke_start",		Event_ChokeStart);
		HookEvent("choke_end",			Event_ChokeStop);
		HookEvent("tongue_grab",		Event_GrabStart);
		HookEvent("tongue_release",		Event_GrabStop);
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;
		UnhookEvent("choke_start",		Event_ChokeStart);
		UnhookEvent("choke_end",		Event_ChokeStop);
		UnhookEvent("tongue_grab",		Event_GrabStart);
		UnhookEvent("tongue_release",	Event_GrabStop);
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
//					FUNCTION
// ====================================================================================================
void ResetPlugin()
{
	for( int i = 1; i <= MaxClients; i++ )
	{
		delete g_iTimers[i];
	}
}

public void OnMapEnd()
{
	ResetPlugin();
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	ResetPlugin();
}

public void Event_ChokeStart(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	g_bChoking[client] = true;
}

public void Event_ChokeStop(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	g_bChoking[client] = false;
}

public void Event_GrabStart(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("victim");
	int client = GetClientOfUserId(userid);
	if( client && IsClientInGame(client) )
	{
		delete g_iTimers[client];
		g_iTimers[client] = CreateTimer(g_hCvarTime.FloatValue, tmrDamage, userid, TIMER_REPEAT);
	}
}

public void Event_GrabStop(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("victim");
	int client = GetClientOfUserId(userid);
	if( client && IsClientInGame(client) )
	{
		delete g_iTimers[client];
	}
}

public Action tmrDamage(Handle timer, any client)
{
	client = GetClientOfUserId(client);
	if( client && IsClientInGame(client) && IsPlayerAlive(client) )
	{
		if( g_bChoking[client] )
			return Plugin_Continue;

		if( GetEntProp(client, Prop_Send, "m_isHangingFromTongue") != 1 )
		{
			int attacker = GetEntPropEnt(client, Prop_Send, "m_tongueOwner");
			if( attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker) )
			{
				HurtEntity(client, attacker, g_hCvarDamage.FloatValue);
				return Plugin_Continue;
			}
		}
	}

	g_iTimers[client] = INVALID_HANDLE;
	return Plugin_Stop;
}

void HurtEntity(int victim, int client, float damage)
{
	char sTemp[16];
	int entity = CreateEntityByName("point_hurt");
	DispatchKeyValue(victim, "targetname", "silvershot");
	DispatchKeyValue(entity, "DamageTarget", "silvershot");
	FloatToString(damage, sTemp, sizeof(sTemp));
	DispatchKeyValue(entity, "Damage", sTemp);
	DispatchKeyValue(entity, "DamageType", "4");
	DispatchSpawn(entity);
	AcceptEntityInput(entity, "Hurt", client > 0 ? client : -1);
	DispatchKeyValue(victim, "targetname", "");
	RemoveEdict(entity);
}