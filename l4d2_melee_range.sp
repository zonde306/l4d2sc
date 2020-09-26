/*
*	Melee Range
*	Copyright (C) 2020 Silvers
*
*	This program is free software: you can redistribute it and/or modify
*	it under the terms of the GNU General Public License as published by
*	the Free Software Foundation, either version 3 of the License, or
*	(at your option) any later version.
*
*	This program is distributed in the hope that it will be useful,
*	but WITHOUT ANY WARRANTY; without even the implied warranty of
*	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*	GNU General Public License for more details.
*
*	You should have received a copy of the GNU General Public License
*	along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/



#define PLUGIN_VERSION 		"1.5"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D2] Melee Range
*	Author	:	SilverShot
*	Descrp	:	Adjustable melee range for each melee weapon.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=318958
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.5 (24-Sep-2020)
	- Compatibility update for L4D2's "The Last Stand" update.
	- Added support for the 2 new Melee weapons.
	- Added 2 new cvars "l4d2_melee_range_weapon_pitchfork" and "l4d2_melee_range_weapon_shovel".

1.4 (10-May-2020)
	- Added better error log message when gamedata file is missing.
	- Extra checks to prevent "IsAllowedGameMode" throwing errors.

1.3 (01-Apr-2020)
	- Fixed "IsAllowedGameMode" from throwing errors when the "_tog" cvar was changed before MapStart.

1.2 (05-Feb-2020)
	- Added cvar "l4d2_melee_range_weapon_unknown" for 3rd party melee weapons.
	- Changed melee detection method and setting of range.
	- Should no longer conflict with simultaneous melee swings and set the correct range per weapon.
	- Optimized cvars for faster CPU processing.
	- Now requires DHooks and gamedata file.
	- Compiled with SourceMod 1.10.

1.1 (03-Oct-2019)
	- Increased string size to fix the plugin not working. Thanks to "xZk" for reporting.

1.0 (02-Oct-2019)
	- Initial release.

======================================================================================*/

// TESTING:
// give baseball_bat; give cricket_bat; give crowbar; give electric_guitar; give fireaxe; give frying_pan; give golfclub; give katana; give knife; give machete; give tonfa; give pitchfork; give shovel
// cv l4d2_melee_range_weapon_baseball_bat "700"; cv l4d2_melee_range_weapon_cricket_bat "700"; cv l4d2_melee_range_weapon_crowbar "700"; cv l4d2_melee_range_weapon_electric_guitar "700"; cv l4d2_melee_range_weapon_fireaxe "700";
// cv l4d2_melee_range_weapon_frying_pan "700"; cv l4d2_melee_range_weapon_golfclub "700"; cv l4d2_melee_range_weapon_katana "700"; cv l4d2_melee_range_weapon_knife "700"; cv l4d2_melee_range_weapon_machete "700"; cv l4d2_melee_range_weapon_tonfa "700";
// cv l4d2_melee_range_weapon_pitchfork "700"; cv l4d2_melee_range_weapon_shovel "700";
// cv l4d2_melee_range_weapon_unknown "700";



#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <dhooks>

#define CVAR_FLAGS			FCVAR_NOTIFY
#define	MAX_MELEE			14
#define GAMEDATA			"l4d2_melee_range"


ConVar g_hCvarAllow, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarMeleeRange, g_hCvarRange[MAX_MELEE];
bool g_bCvarAllow, g_bMapStarted;

int g_iCvarRange[MAX_MELEE];
int g_iStockRange;
Handle g_hDetour;
StringMap g_hScripts;



// ====================================================================================================
//					PLUGIN INFO / START
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D2] Melee Range",
	author = "SilverShot",
	description = "Adjustable melee range for each melee weapon.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=318958"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if( GetEngineVersion() != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

public void OnPluginStart()
{
	// GAMEDATA
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	if( FileExists(sPath) == false ) SetFailState("\n==========\nMissing required file: \"%s\".\nRead installation instructions again.\n==========", sPath);

	Handle hGameData = LoadGameConfigFile(GAMEDATA);
	if( hGameData == null ) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	g_hDetour = DHookCreateFromConf(hGameData, "CTerrorMeleeWeapon::TestMeleeSwingCollision");
	delete hGameData;

	if( !g_hDetour )
		SetFailState("Failed to find \"CTerrorMeleeWeapon::GetPrimaryAttackActivity\" signature.");

	// SCRIPTS - Must match cvars list and their index numbers. The "_unknown" cvar must be last and not in scripts list.
	// You must also increase MAX_MELEE by 1 for each script you add.
	g_hScripts = CreateTrie();
	g_hScripts.SetValue("baseball_bat",		0);
	g_hScripts.SetValue("cricket_bat",		1);
	g_hScripts.SetValue("crowbar",			2);
	g_hScripts.SetValue("electric_guitar",	3);
	g_hScripts.SetValue("fireaxe",			4);
	g_hScripts.SetValue("frying_pan",		5);
	g_hScripts.SetValue("golfclub",			6);
	g_hScripts.SetValue("katana",			7);
	g_hScripts.SetValue("knife",			8);
	g_hScripts.SetValue("machete",			9);
	g_hScripts.SetValue("tonfa",			10);
	g_hScripts.SetValue("pitchfork",		11);
	g_hScripts.SetValue("shovel",			12);
	// g_hScripts.SetValue("riotshield",		13); // Uncommenting? Increase MAX_MELEE at top of plugin by 1, change unknown cvar below from index [13] to [14] and uncomment [13] cvar.

	// CVARS
	g_hCvarAllow = CreateConVar(		"l4d2_melee_range_allow",					"1",			"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarModes = CreateConVar(		"l4d2_melee_range_modes",					"",				"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff = CreateConVar(		"l4d2_melee_range_modes_off",				"",				"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog = CreateConVar(		"l4d2_melee_range_modes_tog",				"0",			"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	g_hCvarRange[0] = CreateConVar(		"l4d2_melee_range_weapon_baseball_bat",		"150",			"70=Default. Range for Baseball Bat.", CVAR_FLAGS );
	g_hCvarRange[1] = CreateConVar(		"l4d2_melee_range_weapon_cricket_bat",		"150",			"70=Default. Range for Cricket Bat.", CVAR_FLAGS );
	g_hCvarRange[2] = CreateConVar(		"l4d2_melee_range_weapon_crowbar",			"150",			"70=Default. Range for Crowbar.", CVAR_FLAGS );
	g_hCvarRange[3] = CreateConVar(		"l4d2_melee_range_weapon_electric_guitar",	"150",			"70=Default. Range for Electric Guitar.", CVAR_FLAGS );
	g_hCvarRange[4] = CreateConVar(		"l4d2_melee_range_weapon_fireaxe",			"150",			"70=Default. Range for Fire Axe.", CVAR_FLAGS );
	g_hCvarRange[5] = CreateConVar(		"l4d2_melee_range_weapon_frying_pan",		"70",			"70=Default. Range for Frying Pan.", CVAR_FLAGS );
	g_hCvarRange[6] = CreateConVar(		"l4d2_melee_range_weapon_golfclub",			"150",			"70=Default. Range for Golf Club .", CVAR_FLAGS );
	g_hCvarRange[7] = CreateConVar(		"l4d2_melee_range_weapon_katana",			"150",			"70=Default. Range for Katana.", CVAR_FLAGS );
	g_hCvarRange[8] = CreateConVar(		"l4d2_melee_range_weapon_knife",			"70",			"70=Default. Range for Knife.", CVAR_FLAGS );
	g_hCvarRange[9] = CreateConVar(		"l4d2_melee_range_weapon_machete",			"120",			"70=Default. Range for Machete.", CVAR_FLAGS );
	g_hCvarRange[10] = CreateConVar(	"l4d2_melee_range_weapon_tonfa",			"120",			"70=Default. Range for Tonfa.", CVAR_FLAGS );
	g_hCvarRange[11] = CreateConVar(	"l4d2_melee_range_weapon_pitchfork",		"120",			"70=Default. Range for Pitchfork.", CVAR_FLAGS );
	g_hCvarRange[12] = CreateConVar(	"l4d2_melee_range_weapon_shovel",			"120",			"70=Default. Range for Shovel.", CVAR_FLAGS );
	// g_hCvarRange[13] = CreateConVar(	"l4d2_melee_range_weapon_riotshield",		"70",			"70=Default. Range for Riot Shield.", CVAR_FLAGS );
	g_hCvarRange[13] = CreateConVar(	"l4d2_melee_range_weapon_unknown",			"70",			"70=Default. Range for unknown melee weapons, 3rd party.", CVAR_FLAGS );
	CreateConVar(						"l4d2_melee_range_version",					PLUGIN_VERSION,	"Melee Range plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true,				"l4d2_melee_range");

	g_hCvarMeleeRange = FindConVar("melee_range");
	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);

	for( int i = 0; i < MAX_MELEE; i++ )
		g_hCvarRange[i].AddChangeHook(ConVarChanged_Cvars);
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
	for( int i = 0; i < MAX_MELEE; i++ )
		g_iCvarRange[i] = g_hCvarRange[i].IntValue;
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;
		g_iStockRange = g_hCvarMeleeRange.IntValue;

		if( !DHookEnableDetour(g_hDetour, false, TestMeleeSwingCollisionPre) )
			SetFailState("Failed to detour pre \"CTerrorMeleeWeapon::TestMeleeSwingCollision\".");

		if( !DHookEnableDetour(g_hDetour, true, TestMeleeSwingCollisionPost) )
			SetFailState("Failed to detour post \"CTerrorMeleeWeapon::TestMeleeSwingCollision\".");
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;
		g_hCvarMeleeRange.SetInt(g_iStockRange);

		if( !DHookDisableDetour(g_hDetour, false, TestMeleeSwingCollisionPre) )
			SetFailState("Failed to disable detour pre \"CTerrorMeleeWeapon::TestMeleeSwingCollision\".");

		if( !DHookDisableDetour(g_hDetour, true, TestMeleeSwingCollisionPost) )
			SetFailState("Failed to disable detour post \"CTerrorMeleeWeapon::TestMeleeSwingCollision\".");
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
//					DETOURS
// ====================================================================================================
public MRESReturn TestMeleeSwingCollisionPre(int pThis, Handle hReturn)
{
	if( IsValidEntity(pThis) )
	{
		static char sTemp[16];
		GetEntPropString(pThis, Prop_Data, "m_strMapSetScriptName", sTemp, sizeof(sTemp));

		int index;
		if( g_hScripts.GetValue(sTemp, index) )
		{
			g_hCvarMeleeRange.SetInt(g_iCvarRange[index]);
		} else {
			g_hCvarMeleeRange.SetInt(g_iCvarRange[MAX_MELEE - 1]);
		}
	}
}

public MRESReturn TestMeleeSwingCollisionPost(int pThis, Handle hReturn)
{
	g_hCvarMeleeRange.SetInt(g_iStockRange);
}