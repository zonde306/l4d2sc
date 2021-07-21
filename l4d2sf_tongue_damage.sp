#define PLUGIN_VERSION 		"1.4"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Tongue Damage
*	Author	:	SilverShot
*	Descrp	:	Control the Smokers tongue damage when pulling a Survivor.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=318959
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.4 (15-May-2020)
	- Replaced "point_hurt" entity with "SDKHooks_TakeDamage" function.

1.3 (10-May-2020)
	- Extra checks to prevent "IsAllowedGameMode" throwing errors.
	- Plugin now fixes game bug: Survivors who are pulled when not touching the ground would be stuck floating.
	- This fix is applied to all gamemodes even when the plugin has been turned off.

1.2 (01-Apr-2020)
	- Fixed "IsAllowedGameMode" from throwing errors when the "_tog" cvar was changed before MapStart.

1.1 (29-Nov-2019)
	- Fixed invalid timer errors - Thanks to "BlackSabbarh" for reporting.

1.0 (02-Oct-2019)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2_skill_framework>
#include "modules/l4d2ps.sp"

#define CVAR_FLAGS			FCVAR_NOTIFY


ConVar g_hCvarAllow, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarDamage, g_hCvarTime;
bool g_bCvarAllow, g_bMapStarted;
bool g_bChoking[MAXPLAYERS+1];
Handle g_hTimers[MAXPLAYERS+1];



// ====================================================================================================
//					PLUGIN INFO / START
// ====================================================================================================
public Plugin myinfo =
{
	name = "舌头拉人伤害",
	author = "SilverShot",
	description = "Control the Smokers tongue damage when pulling a Survivor.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=318959"
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

int g_iSlotAbility;
int g_iLevelTongue[MAXPLAYERS+1];

public void OnPluginStart()
{
	g_hCvarAllow =			CreateConVar(	"l4d_tongue_damage_allow",			"1",				"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarModes =			CreateConVar(	"l4d_tongue_damage_modes",			"",					"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff =		CreateConVar(	"l4d_tongue_damage_modes_off",		"",					"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog =		CreateConVar(	"l4d_tongue_damage_modes_tog",		"3",				"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	g_hCvarDamage =			CreateConVar(	"l4d_tongue_damage_damage",			"5.0",				"How much damage to apply.", CVAR_FLAGS );
	g_hCvarTime =			CreateConVar(	"l4d_tongue_damage_time",			"0.5",				"How often to damage players.", CVAR_FLAGS );
	CreateConVar(							"l4d_tongue_damage_version",		PLUGIN_VERSION,		"Tongue Damage plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true,					"l4d_tongue_damage");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	
	IsAllowed();
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);

	HookEvent("tongue_grab",		Event_GrabStart);
	
	LoadTranslations("l4d2sf_tongue_damage.phrases.txt");
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_first_spawn", Event_PlayerSpawn);
	
	g_iSlotAbility = L4D2SF_RegSlot("ability");
	L4D2SF_RegPerk(g_iSlotAbility, "tongue_damage", 1, 25, 5, 2.0);
}

public Action L4D2SF_OnGetPerkName(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "tongue_damage"))
		FormatEx(result, maxlen, "%T", "舌头伤害", client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public Action L4D2SF_OnGetPerkDescription(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "tongue_damage"))
		FormatEx(result, maxlen, "%T", tr("舌头伤害%d", IntBound(level, 1, 1)), client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public void L4D2SF_OnPerkPost(int client, int level, const char[] perk)
{
	if(!strcmp(perk, "tongue_damage"))
		g_iLevelTongue[client] = level;
}

public void L4D2SF_OnLoad(int client)
{
	g_iLevelTongue[client] = L4D2SF_GetClientPerk(client, "tongue_damage");
}

public void Event_PlayerSpawn(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	g_iLevelTongue[client] = L4D2SF_GetClientPerk(client, "tongue_damage");
}

int IntBound(int v, int min, int max)
{
	if(v < min)
		v = min;
	if(v > max)
		v = max;
	return v;
}

// ====================================================================================================
//					CVARS
// ====================================================================================================
/*
public void OnConfigsExecuted()
{
	IsAllowed();
}
*/

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
		HookEvent("tongue_release",		Event_GrabStop);
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;
		UnhookEvent("choke_start",		Event_ChokeStart);
		UnhookEvent("choke_end",		Event_ChokeStop);
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
		if( g_bMapStarted == false )
			return false;

		g_iCurrentMode = 0;

		int entity = CreateEntityByName("info_gamemode");
		if( entity != -1 )
		{
			DispatchSpawn(entity);
			HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
			ActivateEntity(entity);
			AcceptEntityInput(entity, "PostSpawnActivate");
			if( IsValidEntity(entity) ) // Because sometimes "PostSpawnActivate" seems to kill the ent.
				RemoveEdict(entity); // Because multiple plugins creating at once, avoid too many duplicate ents in the same frame
		}

		if( g_iCurrentMode == 0 )
			return false;

		if( !(iCvarModesTog & g_iCurrentMode) )
			return false;
	}

	char sGameModes[64], sGameMode[64];
	g_hCvarMPGameMode.GetString(sGameMode, sizeof(sGameMode));
	Format(sGameMode, sizeof(sGameMode), ",%s,", sGameMode);

	g_hCvarModes.GetString(sGameModes, sizeof(sGameModes));
	if( sGameModes[0] )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) == -1 )
			return false;
	}

	g_hCvarModesOff.GetString(sGameModes, sizeof(sGameModes));
	if( sGameModes[0] )
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
		delete g_hTimers[i];
	}
}

public void OnMapStart()
{
	g_bMapStarted = true;
}

public void OnMapEnd()
{
	g_bMapStarted = false;
	ResetPlugin();
}

public void OnClientDisconnect(int client)
{
	delete g_hTimers[client];
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
		// Fix floating bug
		if( GetEntityFlags(client) & FL_ONGROUND == 0 )
			SetEntityMoveType(client, MOVETYPE_WALK);

		// Apply damage
		if( g_bCvarAllow )
		{
			delete g_hTimers[client];
			g_hTimers[client] = CreateTimer(g_hCvarTime.FloatValue, tmrDamage, userid, TIMER_REPEAT);
		}
	}
}

public void Event_GrabStop(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("victim");
	int client = GetClientOfUserId(userid);
	if( client && IsClientInGame(client) )
	{
		delete g_hTimers[client];
	}
}

public Action tmrDamage(Handle timer, any client)
{
	client = GetClientOfUserId(client);
	if( client && IsClientInGame(client) && IsPlayerAlive(client) )
	{
		if( g_bChoking[client] || g_iLevelTongue[client] <= 0 )
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

	g_hTimers[client] = null;
	return Plugin_Stop;
}

void HurtEntity(int victim, int client, float damage)
{
	SDKHooks_TakeDamage(victim, client, client, damage, DMG_SLASH);
}