#define PLUGIN_VERSION 		"1.8.2"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D2] Pour Gas
*	Author	:	SilverShot
*	Descrp	:	Players can pour gascans onto the ground, which can be ignited.
*	Link	:	http://forums.alliedmods.net/showthread.php?t=187567
*	Plugins	:	http://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.8.2 (03-Jun-2019)
	- Removed gamedata signature/SDKCall dependency for stagger.
	- Now uses native VScript API for stagger function thanks to "Timocop"'s function and "Lux" reporting.

1.8.1 (14-Aug-2018)
	- Fixed invalid entity error. - Thanks to "Ja-Forces" for reporting.
	- Changed Windows "OnStaggered" gamedata to be compatible with Left4Downtown detouring that function. - Thanks to "Spirit_12".

1.8 (05-May-2018)
	- Converted plugin source to the latest syntax utilizing methodmaps. Requires SourceMod 1.8 or newer.
	- Removed instructor hints due to Valve: FCVAR_SERVER_CAN_EXECUTE prevented server running command: gameinstructor_enable.

1.7.4 (20-Jul-2017)
	- Fixed bug when "l4d2_pourgas_hold" is set to "0". - Thanks to "yeahya" for reporting.

1.7.3 (01-Jul-2017)
	- Fixed random crashes when pouring the gascan. - Thanks to "PepeZukas" for reporting and testing.

1.7.2 (21-Aug-2013)
	- Fixed invalid entity error. - Thanks to "Electr000999" for reporting.

1.7.1 (14-Aug-2013)
	- Fixed index out of bounds error. - Thanks to "Electr000999" for reporting.

1.7 (10-Aug-2013)
	- Oil puddles are no longer time limited and stay until shot.
	- Added cvar "l4d2_pourgas_delete" to delete oil puddles after a specified time. 0 = stay forever.
	- Added cvar "l4d2_pourgas_burn" to set how long the fires burn for.
	- Fire particles added when "l4d2_pourgas_burn" is set higher than 15 seconds.

1.6 (06-Jul-2013)
    - Gamedata signatures file updated. No other changes.

1.6 (11-Jul-2012)
	- Fixed players spinning around when pouring.
	- Fixed the first explosion making the server freeze for a second.
	- Fixed not being able to pour if you were holding a gascan before a map change.

1.5 (30-Jun-2012)
	- Added some checks to prevent errors being logged - Thanks to "disawar1" for reporting.

1.4 (20-Jun-2012)
	- Added some checks to prevent errors being logged - Thanks to "gajo0650" for reporting.
	- Fixed a bug when players were pouring their last can and being hurt.

1.3 (16-Jun-2012)
	- Added some checks to prevent errors being logged - Thanks to "disawar1" for reporting.

1.2 (16-Jun-2012)
	- Blocked scavenge gascans from being used to pour gas. Causes too many bugs.
	- Stops pouring when players are hurt and "l4d2_pourgas_hold" is 0. Prevents endlessly pouring.

1.1 (16-Jun-2012)
	- Fixed the plugin not fully resetting, which prevented players from pouring.

1.0 (15-Jun-2012)
	- Initial release.

========================================================================================

	This plugin was made using source code from the following plugins.
	If I have used your code and not credited you, please let me know.

*	Thanks to "Downtown1", "ProdigySim" and "psychonic" for "[EXTENSION] Left 4 Downtown 2 L4D2 Only" - Used gamedata to stumble players.
	http://forums.alliedmods.net/showthread.php?t=134032

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define CVAR_FLAGS			FCVAR_NOTIFY
#define CHAT_TAG			"\x04[\x05Pour Gas\x04] \x01"

#define	MODEL_GASCAN		"models/props_junk/gascan001a.mdl"
#define	MODEL_TABLE			"models/props_urban/round_table_umbrella002.mdl"
#define MODEL_BOUNDING		"models/props/cs_militia/silo_01.mdl"
#define	SOUND_EXPLODE2		"physics/destruction/smash_cave_woodrockcollapse2.wav"
#define	SOUND_EXPLODE4		"physics/destruction/smash_cave_woodrockcollapse4.wav"
#define	PARTICLE_BLOOD		"blood_bleedout"
#define	PARTICLE_PUDDLE		"rain_puddle_ripples_small"
#define	PARTICLE_DROPS		"gore_blood_droplets_long"
#define	PARTICLE_CHAINSAW	"blood_chainsaw_constant_tp"
#define	PARTICLE_STEAM		"steam_long"
#define	PARTICLE_EXPLODE	"weapon_grenade_explosion"
#define	PARTICLE_FIRE		"burning_wood_01b"
#define	PARTICLE_FIRE_M		"fire_medium_base"

#define MAX_ENTS			5
#define MAX_POURS			64
#define MAX_PUDDLE			2
#define VALVE_INFERNO		15

ConVar g_hCvarAllow, g_hCvarBurn, g_hCvarChain, g_hCvarDamage, g_hCvarDelete, g_hCvarHint, g_hCvarHints, g_hCvarHold, g_hCvarInferno, g_hCvarLimit, g_hCvarLimitDist, g_hCvarLimitHurt, g_hCvarLimitStum, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarTimeout;
int g_iCvarBurn, g_iCvarDamage, g_iCvarDelete, g_iCvarHint, g_iCvarHints, g_iCvarHold, g_iCvarInferno, g_iCvarLimit, g_iCvarLimitHurt, g_iCvarLimitStum;

bool g_bBlockSound, g_bCvarAllow, g_bWatchHook;
float g_fCvarChain, g_fCvarLimitDist, g_fCvarTimeout;

Handle g_hTimeout[MAXPLAYERS+1]; // sdkStagger; // Stagger: SDKCall method
int g_iBlocked[MAXPLAYERS+1], g_iCans[MAX_POURS], g_iDisplayed[MAXPLAYERS+1], g_iHooked[MAXPLAYERS+1], g_iPours[MAXPLAYERS+1], g_iPuddles[MAX_POURS][MAX_PUDDLE], g_iRefuel[MAXPLAYERS+1][2];

enum ()
{
	INDEX_TRIG,
	INDEX_BLOOD
}



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D2] Pour Gas",
	author = "SilverShot",
	description = "Players can pour gascans onto the ground, which can be ignited.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=187567"
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
	/* Stagger: SDKCall method
	Handle hGameConf = LoadGameConfigFile("l4d2_pourgas");
	if( hGameConf == null )
		SetFailState("Missing required 'gamedata/l4d2_pourgas.txt', please re-download.");
	StartPrepSDKCall(SDKCall_Player);
	if( PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CTerrorPlayer::OnStaggered") == false )
		SetFailState("Could not load the 'CTerrorPlayer::OnStaggered' gamedata signature.");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	sdkStagger = EndPrepSDKCall();
	if( sdkStagger == null )
		SetFailState("Could not prep the 'CTerrorPlayer::OnStaggered' function.");
	*/

	LoadTranslations("pourgas.phrases");

	g_hCvarAllow =		CreateConVar(	"l4d2_pourgas_allow",		"1",			"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarBurn =		CreateConVar(	"l4d2_pourgas_burn",		"15",			"0=Forever? How long do the fires burn once ignited. The oil will fade out after ignition regardless of how long this is.", CVAR_FLAGS, true, 0.1 );
	g_hCvarChain =		CreateConVar(	"l4d2_pourgas_chain",		"1.0",			"Chain reaction time. When a puddle is hurt by fire, create it's own fire after this many seconds.", CVAR_FLAGS );
	g_hCvarDamage =		CreateConVar(	"l4d2_pourgas_damage",		"1",			"How much a player is hurt in the fire. Happens multiple times per second.", CVAR_FLAGS );
	g_hCvarDelete =		CreateConVar(	"l4d2_pourgas_delete",		"360",			"0=Infinite, stays forever. Remove puddles after this many seconds.", CVAR_FLAGS );
	g_hCvarHint =		CreateConVar(	"l4d2_pourgas_hint",		"4",			"Display hint when picking up gascans? 0=Off, 1=Chat text, 2=Hint box.", CVAR_FLAGS);
	g_hCvarHints =		CreateConVar(	"l4d2_pourgas_hints",		"2",			"How many times to display hints, count is reset each map/chapter.", CVAR_FLAGS);
	g_hCvarHold =		CreateConVar(	"l4d2_pourgas_hold",		"0",			"Should players hold down the RELOAD|ZOOM key to pour? 0=No, 1=Yes.", CVAR_FLAGS );
	g_hCvarLimit =		CreateConVar(	"l4d2_pourgas_limit",		"4",			"0=Infinite. Drop the gascan after this number of pours.", CVAR_FLAGS );
	g_hCvarLimitDist =	CreateConVar(	"l4d2_pourgas_limit_dist",	"250",			"0=Explosion Off. The dropped gascan explosion distance to hurt players.", CVAR_FLAGS );
	g_hCvarLimitHurt =	CreateConVar(	"l4d2_pourgas_limit_hurt",	"50",			"0=Explosion Off. When using the l4d2_pourgas_limit cvar, the dropped gascan will explode causing this much damage at the center.", CVAR_FLAGS );
	g_hCvarLimitStum =	CreateConVar(	"l4d2_pourgas_limit_stum",	"150",			"0=Off, The range to stumble players from dropped gascan explosions.", CVAR_FLAGS );
	g_hCvarModes =		CreateConVar(	"l4d2_pourgas_modes",		"",				"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff =	CreateConVar(	"l4d2_pourgas_modes_off",	"",				"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog =	CreateConVar(	"l4d2_pourgas_modes_tog",	"0",			"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	g_hCvarTimeout =	CreateConVar(	"l4d2_pourgas_timeout",		"0.3",			"Prevent pouring for this many seconds after completing a pour.", CVAR_FLAGS, true, 0.1 );
	CreateConVar(						"l4d2_pourgas_version",		PLUGIN_VERSION, "Pour Gas plugin version.", CVAR_FLAGS|FCVAR_DONTRECORD);
	AutoExecConfig(true,				"l4d2_pourgas");

	g_hCvarInferno = FindConVar("inferno_flame_lifetime");
	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarChain.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarDelete.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarDamage.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarHint.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarHints.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarHold.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarLimit.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarLimitDist.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarLimitHurt.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarLimitStum.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarBurn.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarTimeout.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarInferno.AddChangeHook(ConVarChanged_Inferno);
}

public void OnPluginEnd()
{
	ResetPlugin();
}

public void OnMapStart()
{
	PrecacheModel(MODEL_GASCAN);
	PrecacheModel(MODEL_TABLE);
	PrecacheModel(MODEL_BOUNDING);
	PrecacheSound(SOUND_EXPLODE2);
	PrecacheSound(SOUND_EXPLODE4);
	PrecacheParticle(PARTICLE_BLOOD);
	PrecacheParticle(PARTICLE_PUDDLE);
	PrecacheParticle(PARTICLE_CHAINSAW);
	PrecacheParticle(PARTICLE_DROPS);
	PrecacheParticle(PARTICLE_STEAM);
	PrecacheParticle(PARTICLE_EXPLODE);
	PrecacheParticle(PARTICLE_FIRE);
	PrecacheParticle(PARTICLE_FIRE_M);

	// Pre-cache env_shake -_- WTF
	int shake  = CreateEntityByName("env_shake");
	if( shake != -1 )
	{
		DispatchKeyValue(shake, "spawnflags", "8");
		DispatchKeyValue(shake, "amplitude", "16.0");
		DispatchKeyValue(shake, "frequency", "1.5");
		DispatchKeyValue(shake, "duration", "0.9");
		DispatchKeyValue(shake, "radius", "50");
		TeleportEntity(shake, view_as<float>({ 0.0, 0.0, -1000.0 }), NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(shake);
		ActivateEntity(shake);
		AcceptEntityInput(shake, "Enable");

		AcceptEntityInput(shake, "StartShake");

		SetVariantString("OnUser1 !self:Kill::1.1:1");
		AcceptEntityInput(shake, "AddOutput");
		AcceptEntityInput(shake, "FireUser1");
	}
}

public void OnMapEnd()
{
	ResetPlugin();
}

void ResetPlugin()
{
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsValidEntRef(g_iRefuel[i][1]) )
		{
			AcceptEntityInput(g_iRefuel[i][1], "Kill");
		}

		if( IsClientInGame(i) )
		{
			SetEntProp(i, Prop_Send, "m_iHideHUD", 0);
			SDKUnhook(i, SDKHook_WeaponCanSwitchTo, WeaponCanSwitchTo);

			if( g_iHooked[i] == 1 )
			{
				ResetClient(i);
			}
		}

		g_iHooked[i] = 0;
		g_iRefuel[i][0] = 0;
		g_iRefuel[i][1] = 0;
		g_iBlocked[i] = 0;
		g_hTimeout[i] = null;
	}

	for( int i = 0; i < MAX_POURS; i++ )
	{
		for( int x = 0; x < MAX_PUDDLE; x++ )
		{
			if( IsValidEntRef(g_iPuddles[i][x]) )
				AcceptEntityInput(g_iPuddles[i][x], "Kill");
			g_iPuddles[i][x] = 0;
		}

		if( IsValidEntRef(g_iCans[i]) )
			AcceptEntityInput(g_iCans[i], "Kill");
		g_iCans[i] = 0;
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

public void ConVarChanged_Inferno(Handle convar, const char[] oldValue, const char[] newValue)
{
	if( !g_bBlockSound ) g_iCvarInferno = g_hCvarInferno.IntValue;
}

public void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_fCvarChain = g_hCvarChain.FloatValue;
	g_iCvarDelete = g_hCvarDelete.IntValue;
	g_iCvarDamage = g_hCvarDamage.IntValue;
	g_iCvarHint = g_hCvarHint.IntValue;
	g_iCvarHints = g_hCvarHints.IntValue;
	g_iCvarHold = g_hCvarHold.IntValue;
	g_iCvarLimit = g_hCvarLimit.IntValue;
	g_fCvarLimitDist = g_hCvarLimitDist.FloatValue;
	g_iCvarLimitHurt = g_hCvarLimitHurt.IntValue;
	g_iCvarLimitStum = g_hCvarLimitStum.IntValue;
	g_iCvarBurn = g_hCvarBurn.IntValue;
	g_fCvarTimeout = g_hCvarTimeout.FloatValue;
	g_iCvarInferno = g_hCvarInferno.IntValue;
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;

		HookEvent("item_pickup", Event_GascanPickup);
		AddNormalSoundHook(view_as<NormalSHook>(SoundHook));
		AddAmbientSoundHook(view_as<AmbientSHook>(SoundHook));

		char sTemp[16];
		int entity;
		for( int i = 1; i <= MaxClients; i++ )
		{
			if( IsClientInGame(i) )
			{
				SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);

				if( GetClientTeam(i) == 2 && IsPlayerAlive(i) && (entity = GetEntPropEnt(i, Prop_Send, "m_hActiveWeapon")) > 0 )
				{
					GetEdictClassname(entity, sTemp, sizeof(sTemp));
					if( strcmp(sTemp, "weapon_gascan") == 0 )
					{
						g_iHooked[i] = 1;
						SDKHook(i, SDKHook_PreThink, OnPreThink);
						g_iRefuel[i][0] = EntIndexToEntRef(entity);
					}
				}
			}
		}
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;
		ResetPlugin();

		UnhookEvent("item_pickup", Event_GascanPickup);
		RemoveNormalSoundHook(view_as<NormalSHook>(SoundHook));
		RemoveAmbientSoundHook(view_as<AmbientSHook>(SoundHook));

		for( int i = 1; i <= MaxClients; i++ )
		{
			if( IsClientInGame(i) )
			{
				SDKUnhook(i, SDKHook_OnTakeDamage, OnTakeDamage);
			}
		}
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
//					EVENTS - Pickup gascan / Hints
// ====================================================================================================
public void Event_GascanPickup(Event event, const char[] name, bool dontBroadcast)
{
	char sTemp[8];
	event.GetString("item", sTemp, sizeof(sTemp));
	if( strcmp(sTemp, "gascan") == 0 )
	{
		int userid = event.GetInt("userid");
		int client = GetClientOfUserId(userid);

		int entity = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if( entity > 0 )
		{
			if( GetEntProp(entity, Prop_Data, "m_nSkin") == 0 )
			{
				g_iRefuel[client][0] = EntIndexToEntRef(entity);
				g_iPours[client] = GetEntProp(entity, Prop_Data, "m_iHammerID");

				if( g_iHooked[client] == 0 )
				{
					g_iHooked[client] = 1;
					SDKHook(client, SDKHook_PreThink, OnPreThink);

					HintMessages(client);
				}
			}
		}
		else
		{
			g_iRefuel[client][0] = 0;
		}
	}
}

public void OnClientPostAdminCheck(int client)
{
	g_iDisplayed[client] = 0;
}

void HintMessages(int client)
{
	if( !g_iCvarHint || (g_iCvarHint < 3 && g_iDisplayed[client] >= g_iCvarHints) || IsFakeClient(client) )
		return;

	g_iDisplayed[client]++;
	int hint = g_iCvarHint;
	if( hint == 3 )			hint = 1; // Can no longer support instructor hints
	else if( hint == 4 )	hint = 2;

	switch ( hint )
	{
		case 1:		// Print To Chat
		{
			PrintToChat(client, "%s%T", CHAT_TAG, "PourGas_Pickup", client);
		}

		case 2:		// Print Hint Text
		{
			PrintHintText(client, "%T", "PourGas_Pickup", client);
		}
	}
}



// ====================================================================================================
//					PRETHINK - Holding gascan / pouring
// ====================================================================================================
public void OnPreThink(int client)
{
	if( g_hTimeout[client] == null )
	{
		int entity = g_iRefuel[client][0];

		if( entity && (entity = EntRefToEntIndex(entity)) != -1 && entity == GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon") )
		{
			int buttons = GetClientButtons(client);
			bool bIsValid = IsValidEntRef(g_iRefuel[client][1]);

			if( bIsValid )
			{
				if( g_iCvarHold == 0 || (buttons & IN_RELOAD || buttons & IN_ZOOM) )
				{
					if( g_iBlocked[client] == 0 )
					{
						SetEntProp(client, Prop_Data, "m_nButtons", buttons|IN_ATTACK);
					}
					else
					{
						AcceptEntityInput(entity, "Kill");
						OnUseFinished("", g_iRefuel[client][1], client, 0.0);
						ResetClient(client);
					}
				}
			}
			else
			{
				if( (buttons & IN_RELOAD || buttons & IN_ZOOM) && GetEntityFlags(client) & FL_ONGROUND )
				{
					float vAng[3];
					GetClientEyeAngles(client, vAng);

					if( vAng[0] < 1.0 )
						return;

					SDKHook(client, SDKHook_WeaponCanSwitchTo, WeaponCanSwitchTo);

					StartPouring(client);

					if( g_iCvarHold == 0 )
					{
						CreatePuddle(client, true);
						g_iPours[client] += 1;
					}
				}
			}
		}
		else if( g_iHooked[client] == 1 )
		{
			ResetClient(client);
		}
	}
}

void ResetClient(int client)
{
	int entity = g_iRefuel[client][1];
	g_iRefuel[client][0] = 0;
	g_iRefuel[client][1] = 0;
	g_iHooked[client] = 0;
	g_iBlocked[client] = 0;

	SDKUnhook(client, SDKHook_PreThink, OnPreThink);

	if( IsValidEntRef(entity) )
	{
		SetEntProp(client, Prop_Send, "m_iHideHUD", 0);
		SDKUnhook(client, SDKHook_WeaponCanSwitchTo, WeaponCanSwitchTo);
		AcceptEntityInput(entity, "Kill");
	}
}



// ====================================================================================================
//					EFFECTS - START POURING
// ====================================================================================================
void StartPouring(int client)
{
	SetEntProp(client, Prop_Send, "m_iHideHUD", 1);
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, view_as<float>({ 0.0, 0.0, 0.0 }));

	float vPos[3], vAng[3], vDir[3];
	GetClientAbsOrigin(client, vPos);
	GetClientAbsAngles(client, vAng);
	GetAngleVectors(vAng, vDir, NULL_VECTOR, NULL_VECTOR);
	vPos[0] += vDir[0] * 5.0;
	vPos[1] += vDir[1] * 5.0;
	vPos[2] += vDir[2] * 5.0;

	int entity = CreateEntityByName("point_prop_use_target");
	DispatchKeyValue(entity, "nozzle", "gas_nozzle");
	TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
	DispatchSpawn(entity);
	SetVariantString("OnUseCancelled !self:Kill::0:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnUseFinished !self:Kill::0:-1");
	AcceptEntityInput(entity, "AddOutput");
	HookSingleEntityOutput(entity, "OnUseCancelled", OnUseCancelled);
	HookSingleEntityOutput(entity, "OnUseFinished", OnUseFinished, true);
	SetEntProp(entity, Prop_Data, "m_iHammerID", client);
	g_iRefuel[client][1] = EntIndexToEntRef(entity);

	int target = entity;

	vPos[0] += vDir[0] * 25.0;
	vPos[1] += vDir[1] * 25.0;
	vPos[2] += vDir[2] * 25.0;
	vPos[2] += 50.0;
	GetAngleVectors(vAng, NULL_VECTOR, vDir, NULL_VECTOR);
	vPos[0] += vDir[0] * 8.0;
	vPos[1] += vDir[1] * 8.0;

	entity = CreateEntityByName("info_particle_system");
	DispatchKeyValue(entity, "effect_name", PARTICLE_DROPS);
	TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
	DispatchSpawn(entity);
	ActivateEntity(entity);
	SetVariantString("OnUser2 !self:Start::0.4:-1");
	AcceptEntityInput(entity, "AddOutput");
	AcceptEntityInput(entity, "FireUser2");
	SetVariantString("OnUser1 !self:Kill::2.0:-1");
	AcceptEntityInput(entity, "AddOutput");
	AcceptEntityInput(entity, "FireUser1");
	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetParent", target);

	entity = CreateEntityByName("info_particle_system");
	DispatchKeyValue(entity, "effect_name", PARTICLE_STEAM);
	TeleportEntity(entity, vPos, view_as<float>({ 90.0, 0.0, 0.0 }), NULL_VECTOR);
	DispatchSpawn(entity);
	ActivateEntity(entity);
	SetVariantString("OnUser2 !self:Start::0.4:-1");
	AcceptEntityInput(entity, "AddOutput");
	AcceptEntityInput(entity, "FireUser2");
	SetVariantString("OnUser1 !self:Kill::2.0:-1");
	AcceptEntityInput(entity, "AddOutput");
	AcceptEntityInput(entity, "FireUser1");
	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetParent", target);

	vPos[2] -= 48.0;
	entity = CreateEntityByName("info_particle_system");
	DispatchKeyValue(entity, "effect_name", PARTICLE_PUDDLE);
	TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
	DispatchSpawn(entity);
	ActivateEntity(entity);
	SetVariantString("OnUser2 !self:Start::0.4:-1");
	AcceptEntityInput(entity, "AddOutput");
	AcceptEntityInput(entity, "FireUser2");
	SetVariantString("OnUser1 !self:Kill::2.0:-1");
	AcceptEntityInput(entity, "AddOutput");
	AcceptEntityInput(entity, "FireUser1");
	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetParent", target);
}

// ====================================================================================================
//					EFFECTS - POURING FINISHED
// ====================================================================================================
public void OnUseCancelled(const char[] output, int entity, int activator, float delay)
{
	int client = GetEntProp(entity, Prop_Data, "m_iHammerID");
	g_iRefuel[client][1] = 0;
	SetEntProp(client, Prop_Send, "m_iHideHUD", 0);

	SDKUnhook(client, SDKHook_WeaponCanSwitchTo, WeaponCanSwitchTo);

	AcceptEntityInput(entity, "Kill");
}

public Action WeaponCanSwitchTo(int client, int weapon)
{
	return Plugin_Handled;
}

public void OnUseFinished(const char[] output, int entity, int activator, float delay)
{
	int client = GetEntProp(entity, Prop_Data, "m_iHammerID");
	g_iRefuel[client][0] = 0;
	g_iRefuel[client][1] = 0;
	SetEntProp(client, Prop_Send, "m_iHideHUD", 0);

	SDKUnhook(client, SDKHook_WeaponCanSwitchTo, WeaponCanSwitchTo);

	AcceptEntityInput(entity, "Kill");

	if( g_iHooked[client] == 1 )
	{
		SDKUnhook(client, SDKHook_PreThink, OnPreThink);
		g_iHooked[client] = 0;
	}

	int pours;
	if( g_iCvarHold == 1 )
	{
		CreatePuddle(client, false);
	}

	if( g_iCvarLimit )
	{
		if( g_iCvarHold == 1 )
			g_iPours[client] += 1;
		pours = g_iPours[client];

		// Limit reached, create dropped gascan and explode on damage.
		if( pours >= g_iCvarLimit )
		{
			float vPos[3], vAng[3], vDir[3];
			GetClientAbsOrigin(client, vPos);
			GetClientAbsAngles(client, vAng);
			GetAngleVectors(vAng, NULL_VECTOR, vDir, NULL_VECTOR);
			NormalizeVector(vDir, vDir);
			vPos[0] -= vDir[0] * 20.0;
			vPos[1] -= vDir[1] * 20.0;
			vPos[2] -= vDir[2] * 20.0;
			vDir = vPos;
			vPos[2] += 20.0;
			vDir[2] -= 100.0;

			Handle trace = TR_TraceRayFilterEx(vPos, vDir, MASK_SHOT, RayType_EndPoint, TraceFilter);
			if( trace != null )
			{
				TR_GetEndPosition(vPos, trace);
				TR_GetPlaneNormal(trace, vAng);
				GetVectorAngles(vAng, vAng);
				vPos[2] += 4.0;

				entity = CreateEntityByName("prop_dynamic_override");
				DispatchKeyValue(entity, "health", "99999");
				DispatchKeyValue(entity, "disableshadows", "1");
				SetEntityModel(entity, MODEL_GASCAN);
				TeleportEntity(entity, vPos, vAng, NULL_VECTOR);
				DispatchSpawn(entity);

				for( int i = 0; i < MAX_POURS; i++ )
				{
					if( !IsValidEntRef(g_iCans[i]) )
					{
						g_iCans[i] = EntIndexToEntRef(entity);
						break;
					}
				}

				if( g_fCvarLimitDist && g_iCvarLimitHurt )
					SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamageDynamic);
			}

			return;
		}
	}

	// Replace gascan which gets removed
	if( IsClientInGame(client) )
	{
		int bits = GetUserFlagBits(client);
		int flags = GetCommandFlags("give");
		SetUserFlagBits(client, ADMFLAG_ROOT);
		SetCommandFlags("give", flags & ~FCVAR_CHEAT);
		FakeClientCommand(client, "give gascan");
		SetUserFlagBits(client, bits);
		SetCommandFlags("give", flags);
	}

	if( g_iCvarLimit )
	{
		entity = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		SetEntProp(entity, Prop_Data, "m_iHammerID", pours);
		g_iPours[client] = pours;
		g_iRefuel[client][0] = EntIndexToEntRef(entity);
	}

	// Prevent pouring
	if( g_hTimeout[client] != null )
		delete g_hTimeout[client];
	g_hTimeout[client] = CreateTimer(g_fCvarTimeout, TimerBlock, GetClientUserId(client));
}

public Action TimerBlock(Handle timer, any client)
{
	client = GetClientOfUserId(client);
	if( client )
	{
		g_iBlocked[client] = 0;
		g_hTimeout[client] = null;
	}
}

public void OnClientDisconnect(int client)
{
	if( g_hTimeout[client] != null )
	{
		delete g_hTimeout[client];
	}
}

public Action OnTakeDamageDynamic(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if( damagetype & DMG_BURN || damagetype & DMG_BULLET || damagetype & DMG_BLAST )
	{
		SDKUnhook(victim, SDKHook_OnTakeDamage, OnTakeDamageDynamic);

		AcceptEntityInput(victim, "Ignite");
		SetEntProp(victim, Prop_Data, "m_iHammerID", attacker);

		SetVariantString("OnUser2 !self:Kill::2.0:-1");
		AcceptEntityInput(victim, "AddOutput");
		AcceptEntityInput(victim, "FireUser2");
		SetVariantString("OnUser4 !self:FireUser3::1.0:-1");
		AcceptEntityInput(victim, "AddOutput");
		AcceptEntityInput(victim, "FireUser4");
		HookSingleEntityOutput(victim, "OnUser3", OnUser3);
		SetEntProp(victim, Prop_Data, "m_iHammerID", GetEntProp(victim, Prop_Data, "m_iHammerID"));
	}
}

public void OnUser3(const char[] output, int caller, int activator, float delay)
{
	int victim = caller;
	float vPos[3];
	char sTemp[32];
	GetEntPropVector(victim, Prop_Data, "m_vecOrigin", vPos);
	AcceptEntityInput(victim, "Kill");


	// Explode Particle
	int entity = CreateEntityByName("info_particle_system");
	if( entity != -1 )
	{
		vPos[2] += 5.0;
		TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
		DispatchKeyValue(entity, "effect_name", PARTICLE_EXPLODE);
		DispatchSpawn(entity);
		ActivateEntity(entity);
		AcceptEntityInput(entity, "Start");
		SetVariantString("OnUser1 !self:Kill::2.0:1");
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser1");
	}


	// Attacker index
	int attacker = GetEntProp(victim, Prop_Data, "m_iHammerID");
	if( attacker < 1 || attacker > MaxClients || !IsClientInGame(attacker) )
		attacker = 0;


	// Create explosion, kills infected, hurts special infected/survivors, pushes physics entities.
	entity = CreateEntityByName("env_explosion");
	if( entity != -1 )
	{
		TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
		DispatchKeyValue(entity, "iRadiusOverride", sTemp);
		DispatchKeyValue(entity, "spawnflags", "1916");
		IntToString(g_iCvarLimitHurt, sTemp, sizeof(sTemp));
		DispatchKeyValue(entity, "iMagnitude", sTemp);
		FloatToString(g_fCvarLimitDist, sTemp, sizeof(sTemp));
		DispatchSpawn(entity);
		SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", attacker);
		AcceptEntityInput(entity, "Explode");
	}


	// Shake!
	int shake  = CreateEntityByName("env_shake");
	if( shake != -1 )
	{
		TeleportEntity(shake, vPos, NULL_VECTOR, NULL_VECTOR);
		DispatchKeyValue(shake, "spawnflags", "8");
		DispatchKeyValue(shake, "amplitude", "16.0");
		DispatchKeyValue(shake, "frequency", "1.5");
		DispatchKeyValue(shake, "duration", "0.9");
		FloatToString(g_fCvarLimitDist + 50.0, sTemp, sizeof(sTemp));
		DispatchKeyValue(shake, "radius", sTemp);
		DispatchSpawn(shake);
		ActivateEntity(shake);
		AcceptEntityInput(shake, "Enable");

		AcceptEntityInput(shake, "StartShake");

		SetVariantString("OnUser1 !self:Kill::1.1:1");
		AcceptEntityInput(shake, "AddOutput");
		AcceptEntityInput(shake, "FireUser1");
	}


	// Loop through survivors, work out distance and stumble.
	if( g_iCvarLimitStum )
	{
		float fDistance;
		float vPos2[3];

		for( int i = 1; i <= MaxClients; i++ )
		{
			if( IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) )
			{
				GetClientAbsOrigin(i, vPos2);
				fDistance = GetVectorDistance(vPos, vPos2);

				if( fDistance <= g_iCvarLimitStum )
				{
					StaggerClient(GetClientUserId(i), vPos);
					// SDKCall(sdkStagger, i, shake, vPos); // Stagger: SDKCall method
				}
			}
		}
	}


	// Sound
	if( GetRandomInt(0, 1) )
		EmitSoundToAll(SOUND_EXPLODE2, shake, SNDCHAN_AUTO, SNDLEVEL_HELICOPTER);
	else
		EmitSoundToAll(SOUND_EXPLODE4, shake, SNDCHAN_AUTO, SNDLEVEL_HELICOPTER);
}



// ====================================================================================================
//					EFFECTS - Blood puddle + Physics ignition trigger
// ====================================================================================================
void CreatePuddle(int client, bool delay = false)
{
	float vPos[3], vAng[3], vDir[3];
	GetClientAbsOrigin(client, vPos);
	GetClientAbsAngles(client, vAng);
	GetAngleVectors(vAng, vDir, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(vDir, vDir);
	vPos[0] += vDir[0] * 25.0;
	vPos[1] += vDir[1] * 25.0;
	vPos[2] += vDir[2] * 25.0;
	vDir = vPos;
	vPos[2] += 10.0;
	vDir[2] -= 50.0;

	Handle trace = TR_TraceRayFilterEx(vPos, vDir, MASK_SHOT, RayType_EndPoint, TraceFilter);
	if( trace != null )
	{
		TR_GetEndPosition(vPos, trace);
		TR_GetPlaneNormal(trace, vAng);
		GetVectorAngles(vAng, vAng);
		if( vAng[0] != 0.0 )
			vAng[0] += 90.0;


		int index = -1;
		for( int i = 0; i < MAX_POURS; i++ )
		{
			if( !IsValidEntRef(g_iPuddles[i][INDEX_TRIG]) )
			{
				index = i;
				break;
			}
		}

		if( index == -1 ) return;

		// BLOOD
		int entity = CreateEntityByName("info_particle_system");
		if( entity != -1 )
		{
			DispatchKeyValue(entity, "effect_name", PARTICLE_BLOOD);
			vPos[2] -= 1.0;
			TeleportEntity(entity, vPos, vAng, NULL_VECTOR);
			DispatchSpawn(entity);
			ActivateEntity(entity);
			g_iPuddles[index][INDEX_BLOOD] = EntIndexToEntRef(entity);

			if( delay == true )
			{
				SetVariantString("OnUser2 !self:Start::0.4:-1");
				AcceptEntityInput(entity, "AddOutput");
				AcceptEntityInput(entity, "FireUser2");
			}
			else
			{
				AcceptEntityInput(entity, "start");
			}

			SetVariantString("OnUser3 !self:Stop::60.0:-1");
			AcceptEntityInput(entity, "AddOutput");
			SetVariantString("OnUser3 !self:FireUser3::60.0:-1");
			AcceptEntityInput(entity, "AddOutput");
			AcceptEntityInput(entity, "FireUser3");
			HookSingleEntityOutput(entity, "OnUser3", OnUserOil, false);

			if( g_iCvarDelete )
			{
				char sTemp[64];
				Format(sTemp, sizeof(sTemp), "OnUser4 !self:Kill::%d:-1", g_iCvarDelete);
				SetVariantString(sTemp);
				AcceptEntityInput(entity, "AddOutput");
				AcceptEntityInput(entity, "FireUser4");
			}
		}


		// PHYSICS TRIGGER
		entity = CreateEntityByName("prop_physics_override");
		if( entity != -1 )
		{
			TeleportEntity(entity, vPos, vAng, NULL_VECTOR);
			SetEntityModel(entity, MODEL_TABLE);
			DispatchKeyValue(entity, "disableshadows", "1");
			DispatchSpawn(entity);
			SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
			SetEntityRenderColor(entity, 10, 0, 0, 1);
			SetEntProp(entity, Prop_Send, "m_iGlowType", 3);
			SetEntProp(entity, Prop_Send, "m_glowColorOverride", 1);
			SetEntProp(entity, Prop_Send, "m_CollisionGroup", 1);
			SetEntProp(entity, Prop_Data, "m_iHealth", 20);
			SetEntProp(entity, Prop_Data, "m_iHammerID", 9109382);
			SetEntityMoveType(entity, MOVETYPE_NONE);
			g_iPuddles[index][INDEX_TRIG] = EntIndexToEntRef(entity);
		}

		if( g_iCvarDelete )
		{
			char sTemp[64];
			Format(sTemp, sizeof(sTemp), "OnUser4 !self:Kill::%d:-1", g_iCvarDelete);
			SetVariantString(sTemp);
			AcceptEntityInput(entity, "AddOutput");
			AcceptEntityInput(entity, "FireUser4");
		}

		SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamagePhysics);
	}
}

public void OnUserOil(const char[] output, int caller, int activator, float delay)
{
	int index = -1;
	int entref = EntIndexToEntRef(caller);

	for( int i = 0; i < MAX_POURS; i++ )
{
		if( g_iPuddles[i][INDEX_BLOOD] == entref )
		{
			index = i;
			break;
		}
	}

	if( index == -1 ) // This should never happen
	{
		LogError("Error OnUserOil index %d/%d/%d/%d",index,caller,activator,entref);
		return;
	}

	if( IsValidEntRef(g_iPuddles[index][INDEX_TRIG]) )
	{
		CreateTimer(0.5, tmrBlood, caller, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action tmrBlood(Handle timer, any entity)
{
	if( (entity = EntRefToEntIndex(entity)) != INVALID_ENT_REFERENCE && IsValidEntity(entity) )
	{
		AcceptEntityInput(entity, "Start");
	}
}

public bool TraceFilter(int entity, int contentsMask)
{
	if( entity <= MaxClients || !IsValidEntity(entity) || GetEntProp(entity, Prop_Data, "m_iHammerID") == 9109382 )
		return false;
	return true;
}

public Action OnTakeDamagePhysics(int entity, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if( damagetype & DMG_BURN )
	{
		SDKUnhook(entity, SDKHook_OnTakeDamage, OnTakeDamagePhysics);
		CreateFires(entity, inflictor, true);
	}
	else if( damagetype & DMG_BULLET || damagetype & DMG_BLAST )
	{
		SDKUnhook(entity, SDKHook_OnTakeDamage, OnTakeDamagePhysics);
		CreateFires(entity, inflictor, false);
	}
	return Plugin_Continue;
}



// ====================================================================================================
//					EFFECTS - Fire Damage
// ====================================================================================================
public void OnClientPutInServer(int client)
{
	if( g_bCvarAllow )
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if( g_iCvarHold == 0 )
	{
		int target = g_iRefuel[victim][1];
		if( IsValidEntRef(target) )
		{
			g_iBlocked[victim] = 1;
			SetEntProp(victim, Prop_Send, "m_iHideHUD", 0);
			SDKUnhook(victim, SDKHook_WeaponCanSwitchTo, WeaponCanSwitchTo);

			if( g_iCvarLimit )
			{
				int entity = GetEntPropEnt(victim, Prop_Send, "m_hActiveWeapon");
				if( entity > 0 )
				{
					char sTemp[16];
					GetEdictClassname(entity, sTemp, sizeof(sTemp));
					if( strcmp(sTemp, "weapon_gascan") == 0 )
					{
						int pours = GetEntProp(entity, Prop_Data, "m_iHammerID") + 1;

						if( pours >= g_iCvarLimit ) // Drop Can
						{
							g_iBlocked[victim] = 1; // PreThink will deal with the drop.
						}
						else // Allow pouring, increase counter.
						{
							g_iBlocked[victim] = 1;
							if( g_hTimeout[victim] != null )
								delete g_hTimeout[victim];
							g_hTimeout[victim] = CreateTimer(0.5, TimerBlock, GetClientUserId(victim));

							g_iPours[victim] = pours;
							SetEntProp(entity, Prop_Data, "m_iHammerID", pours);
							g_iRefuel[victim][0] = EntIndexToEntRef(entity);
						}
					}
				}
			}
		}
	}

	if( damagetype & DMG_BURN && victim > 0 && victim <= MaxClients )
	{
		if( GetEntProp(inflictor, Prop_Data, "m_iHammerID") == 9109382 )
		{
			damage = float(g_iCvarDamage);
			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}



// ====================================================================================================
//					EFFECTS - Fire
// ====================================================================================================
void CreateFires(int target, int client, bool delay)
{
	int entref = EntIndexToEntRef(target);
	int index = -1;
	for( int i = 0; i < MAX_POURS; i++ )
	{
		for( int x = 0; x < MAX_PUDDLE; x++ )
		{
			if( g_iPuddles[i][x] == entref )
			{
				index = i;
				break;
			}
		}
	}

	if( index == -1 ) // This should never happen
	{
		LogError("Error CreateFires index %d/%d/%d/%d",target,client,delay,entref);
		return;
	}

	int entity = g_iPuddles[index][INDEX_BLOOD];
	if( IsValidEntRef(entity) )
		AcceptEntityInput(entity, "Kill");

	entity = g_iPuddles[index][INDEX_TRIG];
	if( IsValidEntRef(entity) )
		AcceptEntityInput(entity, "Kill");

	g_iPuddles[index][INDEX_TRIG] = 0;
	g_iPuddles[index][INDEX_BLOOD] = 0;


	entity = CreateEntityByName("prop_physics");
	if( entity != -1 )
	{
		DispatchKeyValue(entity, "disableshadows", "1");
		SetEntityModel(entity, MODEL_GASCAN);

		float vPos[3];
		GetEntPropVector(target, Prop_Data, "m_vecOrigin", vPos);
		vPos[2] += 15.0;
		TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(entity);

		SetEntPropEnt(entity, Prop_Data, "m_hPhysicsAttacker", client);
		SetEntPropFloat(entity, Prop_Data, "m_flLastPhysicsInfluenceTime", GetGameTime());
		SetEntProp(entity, Prop_Send, "m_iGlowType", 3);
		SetEntProp(entity, Prop_Send, "m_glowColorOverride", 2);
		SetEntProp(entity, Prop_Send, "m_CollisionGroup", 1);
		SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
		SetEntityRenderColor(entity, 0, 0, 0, 0);
		SetEntityMoveType(entity, MOVETYPE_NONE);

		char sTemp[32];
		Format(sTemp, sizeof(sTemp), "OnUser1 !self:FireUser2::%f:-1", delay ? g_fCvarChain : 0.2);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser1");
		HookSingleEntityOutput(entity, "OnUser2", OnBreakPhysics, true);
	}

	AcceptEntityInput(target, "Kill");
}

public void OnBreakPhysics(const char[] output, int caller, int activator, float delay)
{
	g_bBlockSound = true;
	g_hCvarInferno.IntValue = g_iCvarBurn < 1 ? 99999 : g_iCvarBurn;
	g_bWatchHook = true;
	AcceptEntityInput(caller, "break");
	g_bWatchHook = false;
	g_hCvarInferno.IntValue = g_iCvarInferno;
	g_bBlockSound = false;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if( g_bWatchHook && strcmp(classname, "inferno") == 0 )
	{
		g_bWatchHook = false;
		SetEntProp(entity, Prop_Data, "m_iHammerID", 9109382);
		SDKHook(entity, SDKHook_ThinkPost, OnPostThink);
		if( g_iCvarBurn > VALVE_INFERNO )
		{
			CreateTimer(10.0, tmrFire, EntIndexToEntRef(entity));
		}
	}
}

public void OnPostThink(int entity)
{
	SetEntProp(entity, Prop_Send, "m_fireXDelta", 1, 4, 0);
	SetEntProp(entity, Prop_Send, "m_fireXDelta", 1, 4, 0);
	SetEntProp(entity, Prop_Send, "m_fireXDelta", 1, 4, 0);
	SetEntProp(entity, Prop_Send, "m_fireCount", 1);
}

public Action tmrFire(Handle timer, any target)
{
	if( EntRefToEntIndex(target) != INVALID_ENT_REFERENCE )
	{
		float vPos[3];
		GetEntPropVector(target, Prop_Send, "m_vecOrigin", vPos);
		int entity = CreateEntityByName("info_particle_system");
		if( entity != -1 )
		{
			vPos[0] -= 5.0;
			vPos[1] -= 5.0;
			vPos[2] += 2.0;

			DispatchKeyValue(entity, "effect_name", PARTICLE_FIRE);
			TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
			DispatchSpawn(entity);
			ActivateEntity(entity);
			AcceptEntityInput(entity, "start");
			char sTemp[64];
			Format(sTemp, sizeof(sTemp), "OnUser1 !self:Kill::%f.0:-1", g_iCvarBurn - 11.0);
			SetVariantString(sTemp);
			AcceptEntityInput(entity, "AddOutput");
			AcceptEntityInput(entity, "FireUser1");
			SetVariantString("!activator");
			AcceptEntityInput(entity, "SetParent", target);
		}

		entity = CreateEntityByName("info_particle_system");
		if( entity != -1 )
		{
			vPos[0] += 10.0;
			vPos[1] += 10.0;
			vPos[2] += 2.0;

			DispatchKeyValue(entity, "effect_name", PARTICLE_FIRE_M);
			TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
			DispatchSpawn(entity);
			ActivateEntity(entity);
			AcceptEntityInput(entity, "start");
			char sTemp[64];
			Format(sTemp, sizeof(sTemp), "OnUser1 !self:Kill::%f.0:-1", g_iCvarBurn - 11.0);
			SetVariantString(sTemp);
			AcceptEntityInput(entity, "AddOutput");
			AcceptEntityInput(entity, "FireUser1");
			SetVariantString("!activator");
			AcceptEntityInput(entity, "SetParent", target);
		}
	}
}

public Action SoundHook(int clients[64], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags)
{
	if( g_bBlockSound )
	{
		if( StrContains(sample, "weapons/molotov/fire_ignite", false) != -1 || StrContains(sample, "weapons/molotov/molotov", false) != -1 )
		{
			volume = 0.0;
			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}

// Credit to Timocop on VScript function
void StaggerClient(int iUserID, const float fPos[3])
{
	static int iScriptLogic = INVALID_ENT_REFERENCE;
	if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic))
	{
		iScriptLogic = EntIndexToEntRef(CreateEntityByName("logic_script"));
		if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic))
			LogError("Could not create 'logic_script");

		DispatchSpawn(iScriptLogic);
	}

	char sBuffer[96];
	Format(sBuffer, sizeof(sBuffer), "GetPlayerFromUserID(%d).Stagger(Vector(%d,%d,%d))", iUserID, RoundFloat(fPos[0]), RoundFloat(fPos[1]), RoundFloat(fPos[2]));
	SetVariantString(sBuffer);
	AcceptEntityInput(iScriptLogic, "RunScriptCode");
	AcceptEntityInput(iScriptLogic, "Kill");
}

bool IsValidEntRef(int entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		return true;
	return false;
}

void PrecacheParticle(const char[] ParticleName)
{
	int entity = CreateEntityByName("info_particle_system");
	DispatchKeyValue(entity, "effect_name", ParticleName);
	DispatchSpawn(entity);
	ActivateEntity(entity);
	AcceptEntityInput(entity, "start");
	SetVariantString("OnUser1 !self:Kill::1.0:-1");
	AcceptEntityInput(entity, "AddOutput");
	AcceptEntityInput(entity, "FireUser1");
}