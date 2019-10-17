#define PLUGIN_VERSION 		"1.2"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Incapped Shove
*	Author	:	SilverShot
*	Descrp	:	Allows Survivors to shove common and special infected while incapacitated.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=318729
*	Plugins	:	http://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.2 (10-Oct-2019)
	- Can now push and stumble Common Infected in L4D1. Thanks to "Dragokas" for reporting.

1.1 (10-Oct-2019)
	- L4D1 Linux: Gamedata updated to fix crashing. Thanks to "Dragokas" for reporting.
	- Added cvar "l4d_incapped_shove_penalty" to set a shove penalty.
	- Added cvar "l4d_incapped_shove_swing" to set next shove time.
	- Changed "l4d_incapped_shove_types" by adding 8=Tank as an option.

1.0 (17-Sep-2019)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#define CVAR_FLAGS			FCVAR_NOTIFY
#define MAX_DEGREE			90.0	// Degrees to spread traces over.
#define MAX_TRACES			11		// How many TraceHull traces per hit. Odd number so 1 trace shoots down the center.

ConVar g_hCvarAllow, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarCooldown, g_hCvarPenalty, g_hCvarDamage, g_hCvarRange, g_hCvarTypes;
Handle g_hSDK_OnSwingStart, g_hSDK_StaggerClient;
bool g_bCvarAllow, g_bLeft4Dead2;
float g_fTimeout[MAXPLAYERS + 1];
int g_iIgnore[MAX_TRACES + 1];



// ====================================================================================================
//					PLUGIN INFO / START
// ====================================================================================================
public Plugin myinfo =
{
	name = "倒地推",
	author = "SilverShot",
	description = "Allows Survivors to shove common and special infected while incapacitated.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=318729"
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
	// CVARS
	g_hCvarAllow = CreateConVar(	"l4d_incapped_shove_allow",			"1",					"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarDamage = CreateConVar(	"l4d_incapped_shove_damage",		"5",					"The amount of damage each hit does.", CVAR_FLAGS );
	g_hCvarRange = CreateConVar(	"l4d_incapped_shove_range",			"85",					"How close to survivors, common or special infected to stumble them.", CVAR_FLAGS );
	g_hCvarPenalty = CreateConVar(	"l4d_incapped_shove_penalty",		"0.1",					"Penalty delay to add per shove. Delays each consecutive swing by this amount.", CVAR_FLAGS );
	g_hCvarCooldown = CreateConVar(	"l4d_incapped_shove_swing",			"0.8",					"How quickly can a survivor shove. Time to wait till next swing.", CVAR_FLAGS );
	g_hCvarTypes = CreateConVar(	"l4d_incapped_shove_types",			"5",					"Who to affect: 1=Common Infected, 2=Survivors, 4=Special Infected, 8=Tank. Add numbers together.", CVAR_FLAGS );
	g_hCvarModes = CreateConVar(	"l4d_incapped_shove_modes",			"",						"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff = CreateConVar(	"l4d_incapped_shove_modes_off",		"",						"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog = CreateConVar(	"l4d_incapped_shove_modes_tog",		"0",					"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	CreateConVar(					"l4d_incapped_shove_version",		PLUGIN_VERSION,			"Incapped Shove plugin version.", CVAR_FLAGS|FCVAR_DONTRECORD);
	AutoExecConfig(true,			"l4d_incapped_shove");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);



	// GAMEDATA
	Handle hConf = LoadGameConfigFile("l4d_incapped_shove");
	if( hConf == null )
		SetFailState("Missing required 'gamedata/l4d_incapped_shove.txt', please re-download.");

	StartPrepSDKCall(SDKCall_Player);
	if( PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CTerrorPlayer::OnStaggered") == false )
		SetFailState("Could not load the 'CTerrorPlayer::OnStaggered' gamedata signature.");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);
	g_hSDK_StaggerClient = EndPrepSDKCall();
	if( g_hSDK_StaggerClient == null )
		SetFailState("Could not prep the 'CTerrorPlayer::OnStaggered' function.");

	StartPrepSDKCall(SDKCall_Entity);
	if( PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CTerrorWeapon::OnSwingStart") == false )
		SetFailState("Could not load the 'CTerrorWeapon::OnSwingStart' gamedata signature.");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDK_OnSwingStart = EndPrepSDKCall();
	if( g_hSDK_OnSwingStart == null )
		SetFailState("Could not prep the 'CTerrorWeapon::OnSwingStart' function.");



	// EVENTS
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
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
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;
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
public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for( int i = 0; i <= MaxClients; i++ )
	{
		g_fTimeout[i] = 0.0;
	}
}
	
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
// public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	// Validate
	if(
		g_bCvarAllow &&																			// Plugin on
		buttons & IN_ATTACK2 &&																	// Shove button
		!(buttons & IN_FORWARD) &&																// Not moving
		GetClientTeam(client) == 2 &&															// Survivor
		!IsFakeClient(client) &&																// Human
		GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) &&								// Incapped
		GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_flNextShoveTime") > 0 &&			// Can shove
		GetCurrentAttacker(client) == -1
	)
	{
		// Swing
		int entity = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		SDKCall(g_hSDK_OnSwingStart, entity, entity);

		// Penalty
		int penalty;
		if( g_hCvarPenalty.FloatValue > 0.0 )
		{
			penalty = GetEntProp(client, Prop_Send, "m_iShovePenalty");
			if( penalty > 0 )
			{
				// Last swing more than 1 second ago
				int last = RoundToFloor(GetGameTime() - g_fTimeout[client]);
				if( last > 1 )
				{
					// Remove penalty by number of seconds since last swing.
					penalty -= last;
					if( penalty < 0 ) penalty = 0;
				}
			}

			SetEntProp(client, Prop_Send, "m_iShovePenalty", penalty + 1);
			g_fTimeout[client] = GetGameTime();
		}

		// Set next shove
		SetEntPropFloat(client, Prop_Send, "m_flNextShoveTime", GetGameTime() + g_hCvarCooldown.FloatValue + (penalty * g_hCvarPenalty.FloatValue));

		// Hit
		// float fStart = GetEngineTime(); // Benchmark
		DoTraceHit(client);
		// PrintToServer("DoTraceHit took: %f", GetEngineTime() - fStart);
	}
}

stock int GetCurrentAttacker(int client)
{
	int attacker = GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker");
	if(attacker > -1)
		return attacker;
	
	attacker = GetEntPropEnt(client, Prop_Send, "m_pummelAttacker");
	if(attacker > -1)
		return attacker;
	
	attacker = GetEntPropEnt(client, Prop_Send, "m_pounceAttacker");
	if(attacker > -1)
		return attacker;
	
	attacker = GetEntPropEnt(client, Prop_Send, "m_tongueOwner");
	if(attacker > -1)
		return attacker;
	
	attacker = GetEntPropEnt(client, Prop_Send, "m_carryAttacker");
	if(attacker > -1)
		return attacker;
	
	return -1;
}

void DoTraceHit(int client)
{
	g_iIgnore[0] = client;

	// Try to hit several
	float vPos[3], vAng[3], vLoc[3];
	GetClientEyePosition(client, vPos);
	GetClientEyeAngles(client, vAng);

	char sTemp[16];
	Handle trace;
	int target;

	// Divide degree by traces
	vAng[1] += (MAX_DEGREE / 2);
	vAng[0] = 0.0; // Point horizontal
	// vAng[0] = -15.0; // Point up
	// vPos[2] -= 5;
	vPos[2] += 15;

	// Loop number of traces
	for( int i = 1; i <= MAX_TRACES; i++ )
	{
		g_iIgnore[i] = 0;

		vAng[1] -= (MAX_DEGREE / (MAX_TRACES + 1));
		trace = TR_TraceRayFilterEx(vPos, vAng, MASK_SHOT, RayType_Infinite, FilterExcludeSelf);

		if( TR_DidHit(trace) == false )
		{
			delete trace;
			continue;
		}

		/* // Test to show traces:
		#include <neon_beams> // Put outside of function
		float vEnd[3];
		TR_GetEndPosition(vEnd, trace);
		NeonBeams_TempMap(0, vPos, vEnd, 5.0);
		// */

		// Validate entity hit
		target = TR_GetEntityIndex(trace);
		delete trace;

		if( target <= 0 || IsValidEntity(target) == false )
			continue;

		// Unique hit
		for( int x = 0; x < i; x++ )
			if( g_iIgnore[x] == target )
				target = 0;

		if( target == 0 )
			continue;

		g_iIgnore[i] = target;

		// Push survivor/special infected
		if( target <= MaxClients )
		{
			if( g_hCvarTypes.IntValue > 1 && IsClientInGame(target) && IsPlayerAlive(target) )
			{
				// Type check
				int team = GetClientTeam(target);
				if(
					team == 2 && g_hCvarTypes.IntValue & (1<<1) ||
					team == 3 && g_hCvarTypes.IntValue & (1<<2) ||
					team == 3 && g_hCvarTypes.IntValue & (1<<3)
				)
				{
					// Tank allowed?
					if( team == 3 && !(g_hCvarTypes.IntValue & (1<<3)) && GetEntProp(target, Prop_Send, "m_zombieClass") == (g_bLeft4Dead2 ? 8 : 5) )
						continue;

					// Specials allowed?
					if( team == 3 && !(g_hCvarTypes.IntValue & (1<<2)) && GetEntProp(target, Prop_Send, "m_zombieClass") != (g_bLeft4Dead2 ? 8 : 5) )
						continue;

					// Range check
					GetClientEyePosition(target, vLoc);
					if( GetVectorDistance(vPos, vLoc) < g_hCvarRange.FloatValue )
						SDKCall(g_hSDK_StaggerClient, target, client, vPos); // Stagger: SDKCall method
				}
			}
		}
		// Push common infected
		else if( g_hCvarTypes.IntValue & (1<<0) )
		{
			// Check class
			GetEdictClassname(target, sTemp, sizeof sTemp);
			if( strcmp(sTemp, "infected") == 0 )
			{
				// Range check
				GetEntPropVector(target, Prop_Data, "m_vecAbsOrigin", vLoc);
				if( GetVectorDistance(vPos, vLoc) < g_hCvarRange.FloatValue )
				{
					// Push common
					PushCommonInfected(client, target, vPos);
				}
			}
		}
	}
}

void PushCommonInfected(int client, int target, float vPos[3])
{
	char dmg[8];
	g_hCvarDamage.GetString(dmg, sizeof dmg);

	int entity = CreateEntityByName("point_hurt");
	DispatchKeyValue(target, "targetname", "silvershot");
	DispatchKeyValue(entity, "DamageTarget", "silvershot");
	DispatchKeyValue(entity, "Damage", dmg);
	if( g_bLeft4Dead2 )		DispatchKeyValue(entity, "DamageType", "33554432");		// DMG_AIRBOAT (1<<25)	// Common L4D2
	else					DispatchKeyValue(entity, "DamageType", "536870912");	// DMG_BUCKSHOT (1<<29)	// Common L4D1
	TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
	DispatchSpawn(entity);
	AcceptEntityInput(entity, "Hurt", client, client);
	RemoveEdict(entity);
	DispatchKeyValue(target, "targetname", "");
}

public bool FilterExcludeSelf(int entity, int contentsMask, any client)
{
	if( entity == client )
		return false;
	return true;
}