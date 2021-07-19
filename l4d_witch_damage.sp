#define PLUGIN_VERSION 		"1.5"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Witch Damage - Block Insta-Kill
*	Author	:	SilverShot
*	Descrp	:	Prevents the Witch from insta-killing survivors and set her damage scaled to game difficulty.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=318712
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.5 (15-May-2020)
	- Replaced "point_hurt" entity with "SDKHooks_TakeDamage" function.

1.4 (10-May-2020)
	- Extra checks to prevent "IsAllowedGameMode" throwing errors.

1.3 (01-Apr-2020)
	- Fixed "IsAllowedGameMode" from throwing errors when the "_tog" cvar was changed before MapStart.

1.2 (16-Feb-2020)
	- Fixed not doing damage due to wrong string size mistake.

1.1 (17-Sep-2019)
	- Fixed not working in all cases. - Thanks to "cacaopea" for reporting.

1.0 (16-Sep-2019)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#define CVAR_FLAGS			FCVAR_NOTIFY


ConVar g_hCvarAllow, g_hCvarMPGameMode, g_hCvarZDiff, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarDamage, g_hCvarIncap, g_hCvarScale;
bool g_bCvarAllow, g_bMapStarted;
float g_fCvarDamage, g_fCvarIncapped;



// ====================================================================================================
//					PLUGIN INFO / START
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D & L4D2] Witch Damage - Block Insta-Kill",
	author = "SilverShot",
	description = "Prevents the Witch from insta-killing survivors and set her damage scaled to game difficulty.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=318712"
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
	// CVARS
	g_hCvarAllow = CreateConVar(	"l4d_witch_damage_allow",			"1",					"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarDamage = CreateConVar(	"l4d_witch_damage_damage",			"100",					"Damage applied when survivor is not incapped. Scaled with scale cvar depending on the game difficulty.", CVAR_FLAGS );
	g_hCvarIncap = CreateConVar(	"l4d_witch_damage_incapped",		"30",					"Damage applied when survivor is incapped. Scaled with scale cvar depending on the game difficulty.", CVAR_FLAGS );
	g_hCvarScale = CreateConVar(	"l4d_witch_damage_scale",			"100,100,100,100",		"Scales damage depending on game difficulty, each comma separated: 1st = Easy. 2nd = Normal. 3rd = Advanced. 4th = Expert.", CVAR_FLAGS );
	g_hCvarModes = CreateConVar(	"l4d_witch_damage_modes",			"",						"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff = CreateConVar(	"l4d_witch_damage_modes_off",		"",						"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog = CreateConVar(	"l4d_witch_damage_modes_tog",		"0",					"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	CreateConVar(					"l4d_witch_damage_version",			PLUGIN_VERSION,			"Witch Damage plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true,			"l4d_witch_damage");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);

	g_hCvarZDiff = FindConVar("z_difficulty");
	g_hCvarZDiff.AddChangeHook(ConVarChanged_Cvars);
	// g_hCvarDamage = FindConVar("z_witch_damage"); // Use witches Cvar instead?
	// g_hCvarIncap = FindConVar("z_witch_damage_per_kill_hit"); // Use witches Cvar instead?
	g_hCvarDamage.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarIncap.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarScale.AddChangeHook(ConVarChanged_Cvars);
}



// ====================================================================================================
//					CVARS
// ====================================================================================================
public void OnMapStart()
{
	g_bMapStarted = true;
}

public void OnMapEnd()
{
	g_bMapStarted = false;
}

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
	// Read damage values
	g_fCvarDamage = g_hCvarDamage.FloatValue;
	g_fCvarIncapped = g_hCvarIncap.FloatValue;

	// Read scale cvar array
	char buff[16], buffers[4][4];
	g_hCvarScale.GetString(buff, sizeof(buff));
	ExplodeString(buff, ",", buffers, sizeof(buffers), sizeof(buffers[]));

	// Check game difficulty
	g_hCvarZDiff.GetString(buff, sizeof(buff));
	int index;

	switch( CharToLower(buff[0]) )
	{
		case 'e': index = 0;
		case 'n': index = 1;
		case 'h': index = 2;
		case 'i': index = 3;
	}

	// Scale damage to difficulty
	g_fCvarDamage *= StringToInt(buffers[index]);
	g_fCvarIncapped *= StringToInt(buffers[index]);
	g_fCvarDamage /= 100;
	g_fCvarIncapped /= 100;
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		HookClients();
		g_bCvarAllow = true;
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		UnhookClients();
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
		if( g_bMapStarted == false )
			return false;

		g_iCurrentMode = 0;

		int entity = CreateEntityByName("info_gamemode");
		if( IsValidEntity(entity) )
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
//					EVENTS
// ====================================================================================================
public void OnClientPutInServer(int client)
{
	if( g_bCvarAllow )
	{
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	}
}

void HookClients()
{
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame(i) )
		{
			SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
		}
	}
}

void UnhookClients()
{
	for( int i = 1; i <= MaxClients; i++ )
	{
		SDKUnhook(i, SDKHook_OnTakeDamage, OnTakeDamage);
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if( attacker > MaxClients && (damagetype == DMG_SLASH || damagetype == DMG_SLASH + DMG_PARALYZE) && GetClientTeam(victim) == 2 )
	{
		char class[6];
		GetEdictClassname(attacker, class, sizeof(class));

		if( strcmp(class, "witch") == 0 )
		{
			// Incapped or normal damage?
			bool incapped = GetEntProp(victim, Prop_Send, "m_isIncapacitated") != 0;
			damage = incapped ? g_fCvarIncapped : g_fCvarDamage;

			// Prevent insta kill
			if( incapped == false )
			{
				int health = GetClientHealth(victim);
				if( health - damage < 1.0 )
				{
					// Incap them instead.
					SetEntityHealth(victim, 1);
					HurtEntity(victim);
					damage = 0.0;
				}
			}

			// Set damage
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}

void HurtEntity(int target)
{
	SDKHooks_TakeDamage(target, 0, 0, 100.0, DMG_GENERIC);
}