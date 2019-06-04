#define PLUGIN_VERSION 		"1.8"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Pipebomb Shove
*	Author	:	SilverShot
*	Descrp	:	Attaches an activated pipebomb to infected when shoved by players holding pipebombs.
*	Link	:	http://forums.alliedmods.net/showthread.php?t=188066
*	Plugins	:	http://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.8 (05-May-2018)
	- Converted plugin source to the latest syntax utilizing methodmaps. Requires SourceMod 1.8 or newer.
	- Changed cvar "l4d_pipebomb_shove_modes_tog" now supports L4D1.

1.7.1 (24-Mar-2018)
	- Added a couple checks to prevent errors being logged - Thanks to "Crasher_3637" for reporting.

1.7 (02-Dec-2017)
	- Added cvar "l4d_pipebomb_reload" to make the "Reload" key attach the pipebomb. Thanks to "bazrael" for the idea and testing.
	- Added cvar "l4d_pipebomb_time" to set the fuse duration before detonation. Thanks to "Sunyata" for the idea and testing.

1.6 (21-Jun-2015)
	- Fixed "GetEntPropEnt" error - Thanks to "Danny_l4d" for reporting.

1.5 (07-Oct-2012)
	- Fixed tank attachment and tank related cvars in L4D1 - Thanks to "disawar1" for fixing.
	- Changed the Witch attachment point from her mouth to her eye!

1.4 (03-Jul-2012)
	- Fixed errors by adding some checks - Thanks to "gajo0650" for reporting.

1.3 (30-Jun-2012)
	- Fixed the plugin not working in L4D1.
	- Fixed sticking the pipebomb into common infected which have just died.

1.2 (23-Jun-2012)
	- Fixed the last update breaking the plugin.

1.1 (22-Jun-2012)
	- Added cvars "l4d_pipebomb_shove_damage" and "l4d_pipebomb_shove_distance".

1.0 (21-Jun-2012)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define CVAR_FLAGS			FCVAR_NOTIFY

#define PARTICLE_FUSE		"weapon_pipebomb_fuse"
#define PARTICLE_LIGHT		"weapon_pipebomb_blinking_light"
#define MAX_GRENADES		32

Handle sdkActivatePipe;
ConVar g_hCvarAllow, g_hCvarDamage, g_hCvarDistance, g_hCvarInfected, g_hCvarL4DTime, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarReload, g_hCvarTime;
int g_iClients[MAX_GRENADES], g_iCvarInfected, g_iCvarL4DTime, g_iCvarReload, g_iCvarTime, g_iGrenades[MAX_GRENADES];
bool g_bCvarAllow, g_bCvarSwitching, g_bLeft4Dead2;
float g_fCvarDamage, g_fCvarDistance;



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D & L4D2] Pipebomb Shove",
	author = "SilverShot",
	description = "Attaches an activated pipebomb to infected when shoved by players holding pipebombs.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=188066"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test == Engine_Left4Dead ) g_bLeft4Dead2 = false;
	else if( test == Engine_Left4Dead2 ) g_bLeft4Dead2 = true;
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	Handle hGameConf = LoadGameConfigFile("l4d_pipebomb_shove");
	if( hGameConf == null )
		SetFailState("Couldn't find the offsets and signatures file. Please, check that it is installed correctly.");
	StartPrepSDKCall(SDKCall_Static);
	if( PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CPipeBombProjectile_Create") == false )
		SetFailState("Could not load the \"CPipeBombProjectile_Create\" gamedata signature.");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	sdkActivatePipe = EndPrepSDKCall();
	if( sdkActivatePipe == null )
		SetFailState("Could not prep the \"CPipeBombProjectile_Create\" function.");

	g_hCvarAllow = CreateConVar(	"l4d_pipebomb_shove_allow",			"1",			"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarDamage = CreateConVar(	"l4d_pipebomb_shove_damage",		"25",			"0=Default. Other values sets the explosion damage.", CVAR_FLAGS );
	g_hCvarDistance = CreateConVar(	"l4d_pipebomb_shove_distance",		"400",			"0=Default. Other value sets the explosion damage range.", CVAR_FLAGS );
	g_hCvarModes = CreateConVar(	"l4d_pipebomb_shove_modes",			"",				"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff = CreateConVar(	"l4d_pipebomb_shove_modes_off",		"",				"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog = CreateConVar(	"l4d_pipebomb_shove_modes_tog",		"0",			"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	g_hCvarInfected = CreateConVar(	"l4d_pipebomb_shove_infected",		"511",			"1=Common, 2=Witch, 4=Smoker, 8=Boomer, 16=Hunter, 32=Spitter, 64=Jockey, 128=Charger, 256=Tank, 511=All.", CVAR_FLAGS );
	g_hCvarReload = CreateConVar(	"l4d_pipebomb_reload",				"0",			"0=Off, 1=Trigger with reload key, 2=Only trigger with reload key.", CVAR_FLAGS );
	g_hCvarTime = CreateConVar(		"l4d_pipebomb_time",				"6",			"Fuse duration before detonation. Game default is 6 seconds.", CVAR_FLAGS );
	CreateConVar(					"l4d_pipebomb_shove_version",		PLUGIN_VERSION,	"Pipebomb Shove plugin version.", CVAR_FLAGS|FCVAR_DONTRECORD);
	AutoExecConfig(true,			"l4d_pipebomb_shove");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hCvarDamage.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarDistance.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarInfected.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarReload.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarTime.AddChangeHook(ConVarChanged_Cvars);

	g_hCvarL4DTime = FindConVar("pipe_bomb_timer_duration");
	g_hCvarL4DTime.AddChangeHook(ConVarChanged_Pipe);
	FuseChanged();
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

public void ConVarChanged_Pipe(Handle convar, const char[] oldValue, const char[] newValue)
{
	FuseChanged();
}

void FuseChanged()
{
	if( !g_bCvarSwitching ) g_iCvarL4DTime = g_hCvarL4DTime.IntValue;
}

void GetCvars()
{
	g_iCvarTime = g_hCvarTime.IntValue;
	g_fCvarDamage = g_hCvarDamage.FloatValue;
	g_fCvarDistance = g_hCvarDistance.FloatValue;
	g_iCvarInfected = g_hCvarInfected.IntValue;
	g_iCvarReload = g_hCvarReload.IntValue;
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;
		HookEvent("player_death", Event_PlayerDeath);
		HookEvent("entity_shoved", Event_EntityShoved);
		HookEvent("player_shoved", Event_PlayerShoved);
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;
		UnhookEvent("player_death", Event_PlayerDeath);
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
public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	if( userid )
	{
		int client = GetClientOfUserId(userid);
		if( client )
		{
			MatchClients(client);
		}
	}
	else
	{
		int common = event.GetInt("entityid");
		if( common )
		{
			MatchClients(common);
		}
	}
}

void MatchClients(int client)
{
	for( int i = 0; i < MAX_GRENADES; i++ )
	{
		if( g_iClients[i] == client )
		{
			int entity = g_iGrenades[i];
			g_iClients[i] = 0;
			g_iGrenades[i] = 0;

			if( IsValidEntity(entity) )
			{
				SetEntityMoveType(entity, MOVETYPE_FLYGRAVITY);
				AcceptEntityInput(entity, "ClearParent");
			}
		}
	}
}

public void Event_EntityShoved(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iCvarReload != 2 )
	{
		int infected = g_iCvarInfected & (1 << 0);
		int witch = g_iCvarInfected & (1 << 1);
		if( infected || witch )
		{
			int client = GetClientOfUserId(event.GetInt("attacker"));

			int weapon = CheckWeapon(client);
			if( weapon )
			{
				int target = event.GetInt("entityid");

				char sTemp[32];
				GetEntityClassname(target, sTemp, sizeof(sTemp));

				if( (infected && strcmp(sTemp, "infected") == 0 ) )
				{
					if( GetEntProp(target, Prop_Data, "m_iHealth") >= 1 )
					{
						HurtPlayer(target, client, weapon, 0);
					}
				}
				else if( (witch && strcmp(sTemp, "witch") == 0) )
				{
					HurtPlayer(target, client, weapon, -1);
				}
			}
		}
	}
}

public void Event_PlayerShoved(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iCvarInfected && g_iCvarReload != 2 )
	{
		int client = GetClientOfUserId(event.GetInt("attacker"));
		int target = GetClientOfUserId(event.GetInt("userid"));

		if( GetClientTeam(target) == 3 )
		{
			int weapon = CheckWeapon(client);
			if( weapon )
			{
				int class = GetEntProp(target, Prop_Send, "m_zombieClass") + 1;
				if( class == 9 || class == 6 && g_bLeft4Dead2 == false ) class = 8;
				if( g_iCvarInfected & (1 << class) )
				{
					HurtPlayer(target, client, weapon, class -1);
				}
			}
		}
	}
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if( g_bCvarAllow && g_iCvarReload != 0 )
	{
		if( buttons & IN_RELOAD )
		{
			int target = GetClientAimTarget(client, false);
			if( target != -1)
			{
				DoKey(client, target);
			}
		}
	}
}

static float fLastUse;
void DoKey(int client, int target)
{
	float fNow = GetEngineTime();
	if( fNow - fLastUse > 0.2 )
	{
		fLastUse = GetEngineTime();

		int weapon = CheckWeapon(client);
		if( weapon )
		{
			if( target > MaxClients )
			{
				int infected = g_iCvarInfected & (1 << 0);
				int witch = g_iCvarInfected & (1 << 1);
				if( infected || witch )
				{
					char sTemp[32];
					GetEntityClassname(target, sTemp, sizeof(sTemp));

					if( (infected && strcmp(sTemp, "infected") == 0 ) )
					{
						if( GetEntProp(target, Prop_Data, "m_iHealth") >= 1 )
						{
							HurtPlayer(target, client, weapon, 0);
						}
					}
					else if( (witch && strcmp(sTemp, "witch") == 0) )
					{
						HurtPlayer(target, client, weapon, -1);
					}
				}
			} else {
				if( GetClientTeam(target) == 3 )
				{
					int class = GetEntProp(target, Prop_Send, "m_zombieClass") + 1;
					if( class == 9 || class == 6 && g_bLeft4Dead2 == false ) class = 8;
					if( g_iCvarInfected & (1 << class) )
					{
						HurtPlayer(target, client, weapon, class -1);
					}
				}
			}
		}
	}
}

int CheckWeapon(int client)
{
	if( client && IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2 )
	{
		int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if( weapon > 0 && IsValidEntity(weapon) )
		{
			char sTemp[32];
			GetEntityClassname(weapon, sTemp, sizeof(sTemp));
			if( strcmp(sTemp, "weapon_pipe_bomb") == 0 )
				return weapon;
		}
	}
	return 0;
}

void HurtPlayer(int target, int client, int weapon, int special)
{
	int index = -1;

	for( int i = 0; i < MAX_GRENADES; i++ )
	{
		if( g_iClients[i] == 0 || g_iGrenades[i] == 0 || EntRefToEntIndex(g_iGrenades[i]) == INVALID_ENT_REFERENCE )
		{
			index = i;
			break;
		}
	}

	if( index == -1 )	return;

	g_bCvarSwitching = true;
	g_hCvarL4DTime.IntValue = g_iCvarTime;

	RemovePlayerItem(client, weapon);
	AcceptEntityInput(weapon, "Kill");

	float vAng[3], vPos[3];
	GetEntPropVector(target, Prop_Send, "m_vecOrigin", vPos);
	vPos[2] += 40.0;

	int entity = SDKCall(sdkActivatePipe, vPos, vAng, vAng, vAng, client, 2.0);

	g_iClients[index] = target;
	g_iGrenades[index] = EntIndexToEntRef(entity);

	CreateParticle(entity, 0);
	CreateParticle(entity, 1);

	if( g_fCvarDistance )	SetEntPropFloat(entity, Prop_Data, "m_DmgRadius", g_fCvarDistance);
	if( g_fCvarDamage )		SetEntPropFloat(entity, Prop_Data, "m_flDamage", g_fCvarDamage);

	SetEntProp(entity, Prop_Send, "m_nSolidType", 0);
	SetEntityMoveType(entity, MOVETYPE_NONE);

	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetParent", target);

	if( special == -1 )
		SetVariantString("leye");
	else if( special == 1 )
		SetVariantString("smoker_mouth");
	else if( special == 3 || special == 5  || special == 6)
		SetVariantString(GetRandomInt(0, 1) ? "rhand" : "lhand");
	else
		SetVariantString("mouth");

	AcceptEntityInput(entity, "SetParentAttachment", target);
	TeleportEntity(entity, NULL_VECTOR, view_as<float>({ 90.0, 0.0, 0.0 }), NULL_VECTOR);

	g_hCvarL4DTime.IntValue = g_iCvarL4DTime;
	g_bCvarSwitching = false;
}

void CreateParticle(int target, int type)
{
	int entity = CreateEntityByName("info_particle_system");
	if( type == 0 )	DispatchKeyValue(entity, "effect_name", PARTICLE_FUSE);
	else			DispatchKeyValue(entity, "effect_name", PARTICLE_LIGHT);

	DispatchSpawn(entity);
	ActivateEntity(entity);
	AcceptEntityInput(entity, "Start");

	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetParent", target);

	if( type == 0 )	SetVariantString("fuse");
	else			SetVariantString("pipebomb_light");
	AcceptEntityInput(entity, "SetParentAttachment", target);
}