/*
*	Target Override
*	Copyright (C) 2021 Silvers
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



#define PLUGIN_VERSION 		"2.15a"
#define DEBUG_BENCHMARK		0			// 0=Off. 1=Benchmark only (for command). 2=Benchmark (displays on server). 3=PrintToServer various data.

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Target Override
*	Author	:	SilverShot
*	Descrp	:	Overrides Special Infected targeting of Survivors.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=322311
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

2.15a (09-Jul-2021)
	- L4D2: Fixed GameData file from the "2.2.2.0" game update.

2.15 (06-Jul-2021)
	- Limited the patch from last update to L4D2 only.

2.14 (03-Jul-2021)
	- L4D2: Fixed plugin not ignoring players using a minigun. Thanks to "ProjectSky" for reporting.
	- L4D2: GameData .txt file updated.

2.13 (04-Jun-2021)
	- Fixed the plugin not working without the optional "Left 4 DHooks Direct" plugin being installed. Thanks to "spaghettipastaman" for reporting.

2.12 (20-Apr-2021)
	- Changed cvar "l4d_target_override_type" adding type "3" to order range by nav flow distance.
	- This requires the "Left4DHooks" plugin and used only when the plugin is detected. Maybe unreliable due to unreachable flow areas.

	- Fixed "Highest Health" and "Highest Health" orders not validating the clients correctly, Thanks to "larrybrains" for reporting.
	- Fixed "Highest Health" and "Highest Health" config orders description being flipped.

2.11 (12-Apr-2021)
	- Added priority order option "11" to target players using a Mini Gun.

2.10 (15-Feb-2021)
	- Added option "safe" to control if Survivors can be attacked when in a saferoom. Requested by "axelnieves2012".

2.9 (18-Sep-2020)
	- Added option "range" to set how near a Survivor must be to target. Defaults to 0.0 for no range check.
	- Added option "voms2" to control if Survivors can be attacked when incapacitated and vomited.
	- Data config "data/l4d_target_override.cfg" updated to reflect changes.
	- Thanks to "XDglory" for requesting and testing.

2.8 (17-May-2020)
	- Fixed "normal" order test affecting ledge hanging players. Thanks to "tRololo312312" for reporting.
	- Optimized the order test loop by exiting when order is 0, unavailable.

2.7 (15-May-2020)
	- Fixed not resetting variables on clients spawning causing issues e.g. thinking someone's ledge hanging.
	- Thanks to "tRololo312312" for reporting.

2.6 (10-May-2020)
	- Added option "8" to "order" to choose targeting the survivor with highest health.
	- Added option "9" to "order" to choose targeting the survivor with lowest health.
	- Added option "10" to "order" to choose targeting a survivor being Pummelled by the Charger (L4D2 only).
	- Extra checks to prevent "IsAllowedGameMode" throwing errors.
	- Fixed "incap" option not working correctly. Thanks to "login101" for reporting.
	- Fixed not resetting the last attacker on special infected spawning.
	- Gamedata changed to wildcard first few bytes due to Left4DHooks using as a detour.

2.5 (07-Apr-2020)
	- Added cvar "l4d_target_override_type" to select which method to search for survivors.
	- Fixed "Invalid index 0" when no valid targets are available. Thanks to "tRololo312312".

2.4 (01-Apr-2020)
	- Fixed "IsAllowedGameMode" from throwing errors when the "_tog" cvar was changed before MapStart.

2.3 (26-Mar-2020)
	- Added option "last" to the config to enable targeting the last attacker using order value 7.
	- Added option "7" to "order" to choose targeting the last attacker.
	- This option won't change target if one is already very close (250 units).
	- Thanks to "xZk" for requesting.

2.2 (24-Mar-2020)
	- Fixed memory leak. Thanks to "sorallll" for reporting. Thanks to "Lux" for adding the fix.

2.1 (23-Mar-2020)
	- Fixed only using the first 5 priority order values and never checking the 6th when the first 5 fail.

2.0 (23-Mar-2020)
	- Initial Release.

	- Combined L4D1 and L4D2 versions into 1 plugin.
	- Major changes to how the plugin works. 
	- Now has a data config to choose preferences for each Special Infected.

	- Renamed plugin (delete the old .smx - added check to prevent duplicate plugins).
	- Removed cvar "l4d2_target_patch_special", now part part of data config settings.
	- Removed cvar "l4d2_target_patch_targets", now part part of data config settings.
	- Removed cvar "l4d2_target_patch_wait", now part part of data config settings.
	- Removed cvar "l4d2_target_patch_incap", now part part of data config settings.
	- Removed cvar "l4d_target_patch_incap", now part part of data config settings.

1.5 (17-Jan-2020)
	- Added cvar "l4d2_target_patch_incap" to control the following:
	1. Only target vomited and incapacitated players. - Requested by "ReCreator".
	2. Only target incapacitated when everyone is incapacitated. - Requested by "Mr. Man".

1.4 (14-Jan-2020)
	- Fixed not actually using the GetClientsInRange array. Thanks to "Peace-Maker" for reporting.

1.3 (14-Jan-2020)
	- Added cvar "l4d2_target_patch_wait" to delay between switching targets unless current target is invalid.
	- Now using "GetClientsInRange" to select potentially visible clients. Thanks to "Peace-Maker" for recommending.

1.2 (13-Jan-2020)
	- Added cvar "l4d2_target_patch_targets" to control which Special Infected cannot target incapped survivors.
	- If used, this will change those specific Special Infected to target the nearest non-incapped survivor.

1.1 (13-Jan-2020)
	- Fixed mistake causing error with "m_isHangingFromLedge".

1.0 (13-Jan-2020)
	- Initial release.

=========================
*	L4D1 - Target Patch:
=========================

1.2 (16-Jan-2020)
	- Added cvar "l4d_target_patch_incap" to control the following:
	1. Only target vomited and incapacitated players. - Requested by "ReCreator".
	2. Only target incapacitated when everyone is incapacitated. - Requested by "Mr. Man".

1.1 (14-Jan-2020)
	- Fixed invalid entity. Thanks to "Venom1777" for reporting.

1.0 (13-Jan-2020)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <dhooks>
// #include <left4dhooks>

// Left4DHooks natives - optional - (added here to avoid requiring Left4DHooks include)
native float L4D2Direct_GetFlowDistance(int client);
native Address L4D2Direct_GetTerrorNavArea(float pos[3], float beneathLimit = 120.0);
native float L4D2Direct_GetTerrorNavAreaFlow(Address pTerrorNavArea);



#if DEBUG_BENCHMARK == 1 || DEBUG_BENCHMARK == 2
#include <profiler>
Handle g_Prof;
float g_fBenchMin;
float g_fBenchMax;
float g_fBenchAvg;
float g_iBenchTicks;
#endif


#define CVAR_FLAGS			FCVAR_NOTIFY
#define GAMEDATA			"l4d_target_override"
#define CONFIG_DATA			"data/l4d_target_override.cfg"

ConVar g_hCvarAllow, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarSpecials, g_hCvarType, g_hDecayDecay;
bool g_bCvarAllow, g_bMapStarted, g_bLateLoad, g_bLeft4Dead2, g_bLeft4DHooks;
int g_iCvarSpecials, g_iCvarType;
float g_fDecayDecay;
Handle g_hDetour;

ArrayList g_BytesSaved;
Address g_iFixOffset;
int g_iFixCount, g_iFixMatch;



#define MAX_ORDERS		10
int g_iOrderTank[MAX_ORDERS];
int g_iOrderSmoker[MAX_ORDERS];
int g_iOrderBoomer[MAX_ORDERS];
int g_iOrderHunter[MAX_ORDERS];
int g_iOrderSpitter[MAX_ORDERS];
int g_iOrderJockeys[MAX_ORDERS];
int g_iOrderCharger[MAX_ORDERS];

#define MAX_SPECIAL		7
int g_iOptionLast[MAX_SPECIAL];
int g_iOptionPinned[MAX_SPECIAL];
int g_iOptionIncap[MAX_SPECIAL];
int g_iOptionVoms[MAX_SPECIAL];
int g_iOptionVoms2[MAX_SPECIAL];
int g_iOptionSafe[MAX_SPECIAL];
float g_fOptionRange[MAX_SPECIAL];
float g_fOptionWait[MAX_SPECIAL];

#define MAX_PLAY		MAXPLAYERS+1
float g_fLastSwitch[MAX_PLAY];
int g_iLastAttacker[MAX_PLAY];
int g_iLastOrders[MAX_PLAY];
int g_iLastVictim[MAX_PLAY];
bool g_bIncapped[MAX_PLAY];
bool g_bLedgeGrab[MAX_PLAY];
bool g_bPinBoomer[MAX_PLAY];
bool g_bPinSmoker[MAX_PLAY];
bool g_bPinHunter[MAX_PLAY];
bool g_bPinJockey[MAX_PLAY];
bool g_bPinCharger[MAX_PLAY];
bool g_bPumCharger[MAX_PLAY];
bool g_bCheckpoint[MAXPLAYERS+1];

enum
{
	INDEX_TANK		= 0,
	INDEX_SMOKER	= 1,
	INDEX_BOOMER	= 2,
	INDEX_HUNTER	= 3,
	INDEX_SPITTER	= 4,
	INDEX_JOCKEY	= 5,
	INDEX_CHARGER	= 6
}



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D & L4D2] Target Override",
	author = "SilverShot",
	description = "Overrides Special Infected targeting of Survivors.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=322311"
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

	MarkNativeAsOptional("L4D2Direct_GetFlowDistance");
	MarkNativeAsOptional("L4D2Direct_GetTerrorNavArea");
	MarkNativeAsOptional("L4D2Direct_GetTerrorNavAreaFlow");

	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnLibraryAdded(const char[] sName)
{
	if( strcmp(sName, "left4dhooks") == 0 )
		g_bLeft4DHooks = true;
}

public void OnLibraryRemoved(const char[] sName)
{
	if( strcmp(sName, "left4dhooks") == 0 )
		g_bLeft4DHooks = false;
}

public void OnAllPluginsLoaded()
{
	// =========================
	// PREVENT OLD PLUGIN
	// =========================
	if( FindConVar(g_bLeft4Dead2 ? "l4d2_target_patch_version" : "l4d_target_patch_version") != null )
		SetFailState("Error: Old plugin \"%s\" detected. This plugin supersedes the old version, delete it and restart server.", g_bLeft4Dead2 ? "l4d2_target_patch" : "l4d_target_patch");
}

public void OnPluginStart()
{
	// =========================
	// GAMEDATA
	// =========================
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	if( FileExists(sPath) == false ) SetFailState("\n==========\nMissing required file: \"%s\".\nRead installation instructions again.\n==========", sPath);

	Handle hGameData = LoadGameConfigFile(GAMEDATA);
	if( hGameData == null ) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	// Detour
	g_hDetour = DHookCreateFromConf(hGameData, "BossZombiePlayerBot::ChooseVictim");

	if( !g_hDetour ) SetFailState("Failed to find \"BossZombiePlayerBot::ChooseVictim\" signature.");



	// =========================
	// PATCH
	// =========================
	if( g_bLeft4Dead2 )
	{
		g_iFixOffset = GameConfGetAddress(hGameData, "TankAttack::Update");
		if( !g_iFixOffset ) SetFailState("Failed to find \"TankAttack::Update\" signature.", GAMEDATA);

		int offs = GameConfGetOffset(hGameData, "TankAttack__Update_Offset");
		if( offs == -1 ) SetFailState("Failed to load \"TankAttack__Update_Offset\" offset.", GAMEDATA);

		g_iFixOffset += view_as<Address>(offs);

		g_iFixCount = GameConfGetOffset(hGameData, "TankAttack__Update_Count");
		if( g_iFixCount == -1 ) SetFailState("Failed to load \"TankAttack__Update_Count\" offset.", GAMEDATA);

		g_iFixMatch = GameConfGetOffset(hGameData, "TankAttack__Update_Match");
		if( g_iFixMatch == -1 ) SetFailState("Failed to load \"TankAttack__Update_Match\" offset.", GAMEDATA);

		g_BytesSaved = new ArrayList();

		for( int i = 0; i < g_iFixCount; i++ )
		{
			g_BytesSaved.Push(LoadFromAddress(g_iFixOffset + view_as<Address>(i), NumberType_Int8));
		}

		if( g_BytesSaved.Get(0) != g_iFixMatch ) SetFailState("Failed to load, byte mis-match @ %d (0x%02X != 0x%02X)", offs, g_BytesSaved.Get(0), g_iFixMatch);
	}

	delete hGameData;



	// =========================
	// CVARS
	// =========================
	g_hCvarAllow =			CreateConVar(	"l4d_target_override_allow",			"1",				"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarModes =			CreateConVar(	"l4d_target_override_modes",			"",					"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff =		CreateConVar(	"l4d_target_override_modes_off",		"",					"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog =		CreateConVar(	"l4d_target_override_modes_tog",		"0",				"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	if( g_bLeft4Dead2 )
		g_hCvarSpecials =	CreateConVar(	"l4d_target_override_specials",			"127",				"Override these Specials target function: 1=Smoker, 2=Boomer, 4=Hunter, 8=Spitter, 16=Jockey, 32=Charger, 64=Tank. 127=All. Add numbers together.", CVAR_FLAGS );
	else
		g_hCvarSpecials =	CreateConVar(	"l4d_target_override_specials",			"15",				"Override these Specials target function: 1=Smoker, 2=Boomer, 4=Hunter, 8=Tank. 15=All. Add numbers together.", CVAR_FLAGS );
	g_hCvarType =			CreateConVar(	"l4d_target_override_type",				"1",				"How should the plugin search through Survivors. 1=Nearest visible (defaults to games method on fail). 2=All Survivors from the nearest. 3=Nearest by flow distance (requires Left4DHooks plugin, defaults to type 2).", CVAR_FLAGS );
	CreateConVar(							"l4d_target_override_version",			PLUGIN_VERSION,		"Target Override plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true,					"l4d_target_override");

	g_hDecayDecay = FindConVar("pain_pills_decay_rate");
	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hDecayDecay.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarSpecials.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarType.AddChangeHook(ConVarChanged_Cvars);



	// =========================
	// COMMANDS
	// =========================
	RegAdminCmd("sm_to_reload",		CmdReload,	ADMFLAG_ROOT, "Reloads the data config.");

	#if DEBUG_BENCHMARK == 1 || DEBUG_BENCHMARK == 2
	RegAdminCmd("sm_to_stats",		CmdStats,	ADMFLAG_ROOT, "Displays benchmarking stats (min/avg/max).");
	#endif



	// =========================
	// LATELOAD
	// =========================
	if( g_bLateLoad )
	{
		for( int i = 1; i <= MaxClients; i++ )
		{
			if( IsClientInGame(i) && IsPlayerAlive(i) )
			{
				g_bIncapped[i]			= GetEntProp(i, Prop_Send, "m_isIncapacitated", 1) == 1;
				g_bLedgeGrab[i]			= GetEntProp(i, Prop_Send, "m_isHangingFromLedge", 1) == 1;
				g_bPinSmoker[i]			= GetEntPropEnt(i, Prop_Send, "m_tongueOwner") > 0;
				g_bPinHunter[i]			= GetEntPropEnt(i, Prop_Send, "m_pounceAttacker") > 0;
				if( g_bLeft4Dead2 )
				{
					g_bPinJockey[i]		= GetEntPropEnt(i, Prop_Send, "m_jockeyAttacker") > 0;
					g_bPinCharger[i]	= GetEntPropEnt(i, Prop_Send, "m_pummelAttacker") > 0;
					g_bPumCharger[i] = g_bPinCharger[i];
				}
				// g_bPinBoomer[i]		= Unvomit/Left4DHooks method could solve this, but only required for lateload - cba.
			}
		}
	}

	#if DEBUG_BENCHMARK == 1 || DEBUG_BENCHMARK == 2
	g_Prof = CreateProfiler();
	#endif
}

public void OnPluginEnd()
{
	DetourAddress(false);
	PatchAddress(false);
}



// ====================================================================================================
//					LOAD DATA CONFIG
// ====================================================================================================
#if DEBUG_BENCHMARK == 1 || DEBUG_BENCHMARK == 2
public Action CmdStats(int client, int args)
{
	ReplyToCommand(client, "Target Override: Stats: Min %f. Avg %f. Max %f", g_fBenchMin, g_fBenchAvg / g_iBenchTicks, g_fBenchMax);
	return Plugin_Handled;
}
#endif

public Action CmdReload(int client, int args)
{
	OnMapStart();
	ReplyToCommand(client, "Target Override: Data config reloaded.");
	return Plugin_Handled;
}

public void OnMapEnd()
{
	g_bMapStarted = false;
}

public void OnMapStart()
{
	g_bMapStarted = true;

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_DATA);
	if( FileExists(sPath) == false ) SetFailState("\n==========\nMissing required file: \"%s\".\nRead installation instructions again.\n==========", sPath);

	// Load config
	KeyValues hFile = new KeyValues("target_patch");
	if( !hFile.ImportFromFile(sPath) )
	{
		SetFailState("Error loading file: \"%s\". Try replacing the file with the original.", sPath);
	}

	ExplodeToArray("tank",			hFile,	INDEX_TANK,		g_iOrderTank);
	ExplodeToArray("smoker",		hFile,	INDEX_SMOKER,	g_iOrderSmoker);
	ExplodeToArray("boomer",		hFile,	INDEX_BOOMER,	g_iOrderBoomer);
	ExplodeToArray("hunter",		hFile,	INDEX_HUNTER,	g_iOrderHunter);
	if( g_bLeft4Dead2 )
	{
		ExplodeToArray("spitter",	hFile,	INDEX_SPITTER,	g_iOrderSpitter);
		ExplodeToArray("jockey",	hFile,	INDEX_JOCKEY,	g_iOrderJockeys);
		ExplodeToArray("charger",	hFile,	INDEX_CHARGER,	g_iOrderCharger);
	}

	delete hFile;
}

void ExplodeToArray(char[] key, KeyValues hFile, int index, int arr[MAX_ORDERS])
{
	if( hFile.JumpToKey(key) )
	{
		char buffer[16];
		char buffers[MAX_ORDERS][3];

		hFile.GetString("order", buffer, sizeof(buffer), "0,0,0,0,0,0,0,0,0,0");
		ExplodeString(buffer, ",", buffers, MAX_ORDERS, sizeof(buffers[]));

		for( int i = 0; i < MAX_ORDERS; i++ )
		{
			arr[i] = StringToInt(buffers[i]);
		}

		g_iOptionPinned[index] = hFile.GetNum("pinned");
		g_iOptionIncap[index] = hFile.GetNum("incap");
		g_iOptionVoms[index] = hFile.GetNum("voms");
		g_iOptionVoms2[index] = hFile.GetNum("voms2");
		g_fOptionRange[index] = hFile.GetFloat("range");
		g_fOptionWait[index] = hFile.GetFloat("wait");
		g_iOptionLast[index] = hFile.GetNum("last");
		g_iOptionSafe[index] = hFile.GetNum("safe");
		hFile.Rewind();
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
	g_fDecayDecay =		g_hDecayDecay.FloatValue;
	g_iCvarSpecials =	g_hCvarSpecials.IntValue;
	g_iCvarType =		g_hCvarType.IntValue;
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		HookPlayerHurt(true);

		HookEvent("player_spawn",						Event_PlayerSpawn);
		HookEvent("round_start",						Event_RoundStart);
		HookEvent("revive_success",						Event_ReviveSuccess);	// Revived
		HookEvent("player_incapacitated",				Event_Incapacitated);
		HookEvent("player_ledge_grab",					Event_LedgeGrab);		// Ledge
		HookEvent("player_now_it",						Event_BoomerStart);		// Boomer
		HookEvent("player_no_longer_it",				Event_BoomerEnd);
		HookEvent("lunge_pounce",						Event_HunterStart);		// Hunter
		HookEvent("pounce_end",							Event_HunterEnd);
		HookEvent("tongue_grab",						Event_SmokerStart);		// Smoker
		HookEvent("tongue_release",						Event_SmokerEnd);
		HookEvent("player_left_checkpoint",				Event_LeftCheckpoint);
		HookEvent("player_entered_checkpoint",			Event_EnteredCheckpoint);

		if( g_bLeft4Dead2 )
		{
			HookEvent("jockey_ride",					Event_JockeyStart);		// Jockey
			HookEvent("jockey_ride_end",				Event_JockeyEnd);
			HookEvent("charger_pummel_start",			Event_ChargerPummel);	// Charger
			HookEvent("charger_carry_start",			Event_ChargerStart);
			HookEvent("charger_carry_end",				Event_ChargerEnd);
			HookEvent("charger_pummel_end",				Event_ChargerEnd);
			HookEvent("player_entered_start_area",		Event_EnteredCheckpoint);
		}

		DetourAddress(true);
		PatchAddress(true);
		g_bCvarAllow = true;
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		HookPlayerHurt(false);

		UnhookEvent("player_spawn",						Event_PlayerSpawn);
		UnhookEvent("round_start",						Event_RoundStart);
		UnhookEvent("revive_success",					Event_ReviveSuccess);	// Revived
		UnhookEvent("player_incapacitated",				Event_Incapacitated);
		UnhookEvent("player_ledge_grab",				Event_LedgeGrab);		// Ledge
		UnhookEvent("player_now_it",					Event_BoomerStart);		// Boomer
		UnhookEvent("player_no_longer_it",				Event_BoomerEnd);
		UnhookEvent("lunge_pounce",						Event_HunterStart);		// Hunter
		UnhookEvent("pounce_end",						Event_HunterEnd);
		UnhookEvent("tongue_grab",						Event_SmokerStart);		// Smoker
		UnhookEvent("tongue_release",					Event_SmokerEnd);
		UnhookEvent("player_left_checkpoint",			Event_LeftCheckpoint);
		UnhookEvent("player_entered_checkpoint",		Event_EnteredCheckpoint);

		if( g_bLeft4Dead2 )
		{
			UnhookEvent("jockey_ride",					Event_JockeyStart);		// Jockey
			UnhookEvent("jockey_ride_end",				Event_JockeyEnd);
			UnhookEvent("charger_pummel_start",			Event_ChargerPummel);	// Charger
			UnhookEvent("charger_carry_start",			Event_ChargerStart);
			UnhookEvent("charger_carry_end",			Event_ChargerEnd);
			UnhookEvent("charger_pummel_end",			Event_ChargerEnd);
			UnhookEvent("player_entered_start_area",	Event_EnteredCheckpoint);
		}

		DetourAddress(false);
		PatchAddress(false);
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
public void Event_EnteredCheckpoint(Event event, const char[] name, bool dontBroadcast)
{
	g_bCheckpoint[GetClientOfUserId(event.GetInt("userid"))] = true;
}

public void Event_LeftCheckpoint(Event event, const char[] name, bool dontBroadcast)
{
	g_bCheckpoint[GetClientOfUserId(event.GetInt("userid"))] = false;
}

void HookPlayerHurt(bool doHook)
{
	// Hook player_hurt for order type 7 - target last attacker.
	bool hook;
	for( int i = 0; i < MAX_SPECIAL; i++ )
	{
		if( g_iOptionLast[i] )
		{
			hook = true;
			break;
		}
	}

	static bool bHookedHurt;

	if( doHook && hook && !bHookedHurt )
	{
		bHookedHurt = true;
		HookEvent("player_hurt",		Event_PlayerHurt);
	}
	else if( (!doHook || !hook) && bHookedHurt )
	{
		bHookedHurt = false;
		UnhookEvent("player_hurt",		Event_PlayerHurt);
	}
}

void ResetVars(int client)
{
	g_iLastAttacker[client] = 0;
	g_iLastOrders[client] = 0;
	g_iLastVictim[client] = 0;
	g_fLastSwitch[client] = 0.0;
	g_bIncapped[client] = false;
	g_bLedgeGrab[client] = false;
	g_bPinBoomer[client] = false;
	g_bPinSmoker[client] = false;
	g_bPinHunter[client] = false;
	g_bPinJockey[client] = false;
	g_bPinCharger[client] = false;
	g_bPumCharger[client] = false;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for( int i = 0; i <= MaxClients; i++ )
	{
		ResetVars(i);

		if( i && IsClientInGame(i) && GetClientTeam(i) == 2 )
			g_bCheckpoint[i] = true;
		else
			g_bCheckpoint[i] = false;
	}
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	ResetVars(client);
}

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	g_iLastAttacker[client] = event.GetInt("attacker");
}

public void Event_ReviveSuccess(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("subject"));
	g_bIncapped[client] = false;
	g_bLedgeGrab[client] = false;
}

public void Event_Incapacitated(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	g_bIncapped[client] = true;
}

public void Event_LedgeGrab(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	g_bLedgeGrab[client] = true;
}

public void Event_SmokerStart(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	g_bPinSmoker[client] = true;
}

public void Event_SmokerEnd(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	g_bPinSmoker[client] = false;
}

public void Event_BoomerStart(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	g_bPinBoomer[client] = true;
}

public void Event_BoomerEnd(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	g_bPinBoomer[client] = false;
}

public void Event_HunterStart(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	g_bPinHunter[client] = true;
}

public void Event_HunterEnd(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	g_bPinHunter[client] = false;
}

public void Event_JockeyStart(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	g_bPinJockey[client] = true;
}

public void Event_JockeyEnd(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	g_bPinJockey[client] = false;
}

public void Event_ChargerPummel(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	g_bPumCharger[client] = true;
	g_bPinCharger[client] = true;
}

public void Event_ChargerStart(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	g_bPinCharger[client] = true;
}

public void Event_ChargerEnd(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	g_bPinCharger[client] = false;
	g_bPumCharger[client] = false;
}



// ====================================================================================================
//					DETOUR
// ====================================================================================================
void DetourAddress(bool patch)
{
	static bool patched;

	if( !patched && patch )
	{
		if( !DHookEnableDetour(g_hDetour, false, ChooseVictim) )
			SetFailState("Failed to detour \"BossZombiePlayerBot::ChooseVictim\".");

		patched = true;
	}
	else if( patched && !patch )
	{
		if( !DHookDisableDetour(g_hDetour, false, ChooseVictim) )
			SetFailState("Failed to disable detour \"BossZombiePlayerBot::ChooseVictim\".");

		patched = false;
	}
}

void PatchAddress(bool patch)
{
	if( !g_bLeft4Dead2 ) return;

	static bool patched;

	if( !patched && patch )
	{
		patched = true;	

		for( int i = 0; i < g_iFixCount; i++ )
		{
			StoreToAddress(g_iFixOffset + view_as<Address>(i), 0x90, NumberType_Int8);
		}
	}
	else if( patched && !patch )
	{
		patched = false;

		for( int i = 0; i < g_iFixCount; i++ )
		{
			StoreToAddress(g_iFixOffset + view_as<Address>(i), g_BytesSaved.Get(i), NumberType_Int8);
		}
	}
}

public MRESReturn ChooseVictim(int attacker, Handle hReturn)
{
	#if DEBUG_BENCHMARK == 1 || DEBUG_BENCHMARK == 2
	StartProfiling(g_Prof);
	#endif

	#if DEBUG_BENCHMARK == 3
	PrintToServer("");
	PrintToServer("");
	PrintToServer("CHOOSER %d (%N)", attacker, attacker);
	#endif



	// =========================
	// VALIDATE SPECIAL ALLOWED CHANGE TARGET
	// =========================
	// 1=Smoker, 2=Boomer, 3=Hunter, 4=Spitter, 5=Jockey, 6=Charger, 5 (L4D1) / 8 (L4D2)=Tank
	int class = GetEntProp(attacker, Prop_Send, "m_zombieClass");
	if( class == (g_bLeft4Dead2 ? 8 : 5) ) class -= 1;
	if( g_iCvarSpecials & (1 << class - 1) == 0 )
	{
		#if DEBUG_BENCHMARK == 1 || DEBUG_BENCHMARK == 2
		StopProfiling(g_Prof);
		float speed = GetProfilerTime(g_Prof);
		if( speed < g_fBenchMin ) g_fBenchMin = speed;
		if( speed > g_fBenchMax ) g_fBenchMax = speed;
		g_fBenchAvg += speed;
		g_iBenchTicks++;
		#endif

		#if DEBUG_BENCHMARK == 2
		PrintToServer("ChooseVictim End 1 in %f (Min %f. Avg %f. Max %f)", speed, g_fBenchMin, g_fBenchAvg / g_iBenchTicks, g_fBenchMax);
		#endif

		return MRES_Ignored;
	}

	// Change tank class for use as index
	if( class == (g_bLeft4Dead2 ? 7 : 4) )
	{
		class = 0;
	}



	// =========================
	// VALIDATE OLD TARGET, WAIT
	// =========================
	int newVictim;
	int lastVictim = g_iLastVictim[attacker];
	if( lastVictim )
	{
		// Player disconnected or player dead, otherwise validate last selected order still applies
		if( IsClientInGame(lastVictim) == true && IsPlayerAlive(lastVictim) )
		{
			#if DEBUG_BENCHMARK == 3
			PrintToServer("=== Test Last: Order: %d. newVictim %d (%N)", g_iLastOrders[attacker], lastVictim, lastVictim);
			#endif

			newVictim = OrderTest(attacker, lastVictim, GetClientTeam(lastVictim), g_iLastOrders[attacker]);

			#if DEBUG_BENCHMARK == 3
			PrintToServer("=== Test Last: newVictim %d (%N)", lastVictim, lastVictim);
			#endif
		}

		// Not reached delay time
		if( newVictim && GetGameTime() <= g_fLastSwitch[attacker] )
		{
			// CONTINUE OVERRIDE LAST
			DHookSetReturn(hReturn, newVictim);

			#if DEBUG_BENCHMARK == 1 || DEBUG_BENCHMARK == 2
			StopProfiling(g_Prof);
			float speed = GetProfilerTime(g_Prof);
			if( speed < g_fBenchMin ) g_fBenchMin = speed;
			if( speed > g_fBenchMax ) g_fBenchMax = speed;
			g_fBenchAvg += speed;
			g_iBenchTicks++;
			#endif

			#if DEBUG_BENCHMARK == 2
			PrintToServer("ChooseVictim End 2 in %f (Min %f. Avg %f. Max %f)", speed, g_fBenchMin, g_fBenchAvg / g_iBenchTicks, g_fBenchMax);
			#endif

			#if DEBUG_BENCHMARK == 3
			PrintToServer("=== Test Last: wait delay.");
			#endif
			return MRES_Supercede;
		}
		else
		{
			#if DEBUG_BENCHMARK == 3
			PrintToServer("=== Test Last: wait reset.");
			#endif

			g_iLastOrders[attacker] = 0;
			g_iLastVictim[attacker] = 0;
			g_fLastSwitch[attacker] = 0.0;
		}
	}



	// =========================
	// FIND NEAREST SURVIVORS
	// =========================
	// Visible near
	float vPos[3];
	int targets[MAX_PLAY];
	int numClients;


	// Search method
	switch( g_iCvarType )
	{
		case 1:
		{
			GetClientEyePosition(attacker, vPos);
			numClients = GetClientsInRange(vPos, RangeType_Visibility, targets, MAXPLAYERS);
		}
		case 2, 3:
		{
			GetClientAbsOrigin(attacker, vPos);
			for( int i = 1; i <= MaxClients; i++ )
			{
				if( IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) )
				{
					targets[numClients++] = i;
				}
			}
		}
	}

	if( numClients == 0 )
	{
		#if DEBUG_BENCHMARK == 1 || DEBUG_BENCHMARK == 2
		StopProfiling(g_Prof);
		float speed = GetProfilerTime(g_Prof);
		if( speed < g_fBenchMin ) g_fBenchMin = speed;
		if( speed > g_fBenchMax ) g_fBenchMax = speed;
		g_fBenchAvg += speed;
		g_iBenchTicks++;
		#endif

		#if DEBUG_BENCHMARK == 2
		PrintToServer("ChooseVictim End 3 in %f (Min %f. Avg %f. Max %f)", speed, g_fBenchMin, g_fBenchAvg / g_iBenchTicks, g_fBenchMax);
		#endif

		return MRES_Ignored;
	}



	// =========================
	// GET DISTANCE
	// =========================
	ArrayList aTargets = new ArrayList(3);
	float vTarg[3];
	float dist;
	float flow;
	int team;
	int index;
	int victim;

	// Check range by nav flow
	int type = g_iCvarType;
	if( type == 3 && g_bLeft4DHooks )
	{
		// Attempt to get flow distance from position and nav address
		flow = L4D2Direct_GetFlowDistance(attacker);
		if( flow == 0.0 || flow == -9999.0 ) // Invalid flows
		{
			// Failing that try backup method
			Address addy = L4D2Direct_GetTerrorNavArea(vPos);
			if( addy )
			{
				flow = L4D2Direct_GetTerrorNavAreaFlow(addy);

				if( flow == 0.0 || flow == -9999.0 ) // Invalid flows
				{
					type = 2;
				}
			} else {
				type = 2;
			}
		}
	} else {
		type = 2;
	}

	for( int i = 0; i < numClients; i++ )
	{
		victim = targets[i];

		if( victim && IsPlayerAlive(victim) )
		{
			team = GetClientTeam(victim);
			// Option "voms2" then allow attacking vomited survivors ELSE not vomited
			// Option "voms" then allow choosing team 3 when vomited
			if( (team == 2 && (g_iOptionVoms2[class] == 1 || g_bPinBoomer[i] == false) ) ||
				(team == 3 && g_iOptionVoms[class] == 1 && g_bPinBoomer[i] == true) )
			{
				// Saferoom test
				if( !g_iOptionSafe[class] || !g_bCheckpoint[victim] )
				{
					if( type == 3 )
					{
						// Attempt to get flow distance from position and nav address
						dist = L4D2Direct_GetFlowDistance(victim);
						if( dist == 0.0 || dist == -9999.0 ) // Invalid flows
						{
							// Failing that try backup method
							GetClientAbsOrigin(victim, vTarg);
							Address addy = L4D2Direct_GetTerrorNavArea(vTarg);
							if( addy )
							{
								dist = L4D2Direct_GetTerrorNavAreaFlow(addy);

								if( dist == 0.0 || dist == -9999.0 ) // Invalid flows
								{
									dist = 999999.0;
								}
							} else {
								dist = 999999.0;
							}
						}

						if( dist != 999999.0 ) // Invalid flows
						{
							dist -= flow;
							if( dist < 0.0 ) dist *= -1.0;
						}
					}
					else
					{
						GetClientAbsOrigin(victim, vTarg);
						dist = GetVectorDistance(vPos, vTarg);
					}

					if( dist != 999999.0 && (dist < g_fOptionRange[class] || g_fOptionRange[class] == 0.0) )
					{
						index = aTargets.Push(dist);
						aTargets.Set(index, victim, 1);
						aTargets.Set(index, team, 2);
					}
				}
			}
		}
	}

	// Sort by nearest
	int len = aTargets.Length;
	if( len == 0 )
	{
		delete aTargets;

		#if DEBUG_BENCHMARK == 1 || DEBUG_BENCHMARK == 2
		StopProfiling(g_Prof);
		float speed = GetProfilerTime(g_Prof);
		if( speed < g_fBenchMin ) g_fBenchMin = speed;
		if( speed > g_fBenchMax ) g_fBenchMax = speed;
		g_fBenchAvg += speed;
		g_iBenchTicks++;
		#endif

		#if DEBUG_BENCHMARK == 2
		PrintToServer("ChooseVictim End 4 in %f (Min %f. Avg %f. Max %f)", speed, g_fBenchMin, g_fBenchAvg / g_iBenchTicks, g_fBenchMax);
		#endif

		return MRES_Ignored;
	}

	SortADTArray(aTargets, Sort_Ascending, Sort_Float);



	// =========================
	// ALL INCAPPED CHECK
	// OPTION: "incap" "3"
	// =========================
	// 3=Only attack incapacitated when everyone is incapacitated.
	bool allIncap;
	if( g_iOptionIncap[class] == 3 )
	{
		allIncap = true;

		for( int i = 1; i <= MaxClients; i++ )
		{
			if( IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) )
			{
				if( g_bIncapped[i] == false )
				{
					allIncap = false;
					break;
				}
			}
		}
	}



	// =========================
	// ORDER VALIDATION
	// =========================
	// Loop through all orders progressing to the next on fail, and each time loop through all survivors from nearest to test the order preference
	bool allPinned = true;
	int order;

	int orders;
	for( ; orders < MAX_ORDERS; orders++ )
	{
		// Found someone last order loop, exit loop
		#if DEBUG_BENCHMARK == 3
		PrintToServer("=== ORDER LOOP %d. newVictim %d (%N)", orders + 1, newVictim, newVictim);
		#endif

		if( newVictim ) break;



		// =========================
		// OPTION: "order"
		// =========================
		switch( class )
		{
			case INDEX_TANK:		order = g_iOrderTank[orders];
			case INDEX_SMOKER:		order = g_iOrderSmoker[orders];
			case INDEX_BOOMER:		order = g_iOrderBoomer[orders];
			case INDEX_HUNTER:		order = g_iOrderHunter[orders];
			case INDEX_SPITTER:		order = g_iOrderSpitter[orders];
			case INDEX_JOCKEY:		order = g_iOrderJockeys[orders];
			case INDEX_CHARGER:		order = g_iOrderCharger[orders];
		}



		// Last Attacker enabled?
		if( order == 7 )
		{
			if( g_iOptionLast[class] == 0 ) continue;

			// Don't stop targeting if really close
			dist = aTargets.Get(0, 0); // 0 = Nearest player, 0 = distance.
			if( dist <= 250.0) continue;
		}



		// =========================
		// LOOP SURVIVORS
		// =========================
		for( int i = 0; i < len; i++ )
		{
			victim = aTargets.Get(i, 1);



			// All incapped, target nearest
			if( allIncap )
			{
				#if DEBUG_BENCHMARK == 3
				PrintToServer("Break allIncap");
				#endif

				newVictim = victim;
				break;
			}



			team = aTargets.Get(i, 2);
			// dist = aTargets.Get(i, 0);



			// =========================
			// OPTION: "incap"
			// =========================
			// 0=Ignore incapacitated players.
			// 1=Allow attacking incapacitated players.
			// 2=Only attack incapacitated players when they are vomited.
			// 3=Only attack incapacitated when everyone is incapacitated.
			// 3 is already checked above.
			if( team == 2 && g_bIncapped[victim] == true )
			{
				switch( g_iOptionIncap[class] )
				{
					case 0: continue;
					case 2: if( g_bPinBoomer[victim] == false ) continue;
				}
			}



			// =========================
			// OPTION: "pinned"
			// =========================
			// Validate pinned and allowed
			// 1=Smoker. 2=Hunter. 4=Jockey. 8=Charger.
			if( team == 2 )
			{
				if( g_iOptionPinned[class] & 1 && g_bPinSmoker[victim] ) continue;
				if( g_iOptionPinned[class] & 2 && g_bPinHunter[victim] ) continue;
				if( g_bLeft4Dead2 )
				{
					if( g_iOptionPinned[class] & 4 && g_bPinJockey[victim] ) continue;
					if( g_iOptionPinned[class] & 8 && g_bPinCharger[victim] ) continue;
				}

				allPinned = false;
			}



			// =========================
			// OPTION: "order"
			// =========================
			newVictim = OrderTest(attacker, victim, team, order);

			#if DEBUG_BENCHMARK == 3
			PrintToServer("Order %d newVictim %d (%N)", order, newVictim, newVictim);
			#endif

			if( newVictim ) break;
			if( order == 0 ) break;
		}

		if( newVictim ) break;
		if( order == 0 ) break;
	}



	// All pinned and not allowed to target, target self to avoid attacking pinned.
	if( allPinned && g_iOptionPinned[class] == 0 )
	{
		newVictim = attacker;
	}



	// =========================
	// NEW TARGET
	// =========================
	if( newVictim != g_iLastVictim[attacker] )
	{
		g_iLastOrders[attacker] = orders;
		g_iLastVictim[attacker] = newVictim;
		g_fLastSwitch[attacker] = GetGameTime() + g_fOptionWait[class];
	}



	// =========================
	// OVERRIDE VICTIM
	// =========================
	if( newVictim )
	{
		DHookSetReturn(hReturn, newVictim);

		#if DEBUG_BENCHMARK == 1 || DEBUG_BENCHMARK == 2
		StopProfiling(g_Prof);
		float speed = GetProfilerTime(g_Prof);
		if( speed < g_fBenchMin ) g_fBenchMin = speed;
		if( speed > g_fBenchMax ) g_fBenchMax = speed;
		g_fBenchAvg += speed;
		g_iBenchTicks++;
		#endif

		#if DEBUG_BENCHMARK == 2
		PrintToServer("ChooseVictim End 5 in %f (Min %f. Avg %f. Max %f)", speed, g_fBenchMin, g_fBenchAvg / g_iBenchTicks, g_fBenchMax);
		#endif

		delete aTargets;
		return MRES_Supercede;
	}

	#if DEBUG_BENCHMARK == 1 || DEBUG_BENCHMARK == 2
	StopProfiling(g_Prof);
	float speed = GetProfilerTime(g_Prof);
	if( speed < g_fBenchMin ) g_fBenchMin = speed;
	if( speed > g_fBenchMax ) g_fBenchMax = speed;
	g_fBenchAvg += speed;
	g_iBenchTicks++;
	#endif

	#if DEBUG_BENCHMARK == 2
	PrintToServer("ChooseVictim End 6 in %f (Min %f. Avg %f. Max %f)", speed, g_fBenchMin, g_fBenchAvg / g_iBenchTicks, g_fBenchMax);
	#endif

	delete aTargets;
	return MRES_Ignored;
}

int OrderTest(int attacker, int victim, int team, int order)
{
	int newVictim;

	switch( order )
	{
		// 1=Normal Survivor
		case 1:
		{
			if( team == 2 &&
				g_bLedgeGrab[victim] == false &&
				g_bIncapped[victim] == false &&
				g_bPinBoomer[victim] == false &&
				g_bPinSmoker[victim] == false &&
				g_bPinHunter[victim] == false &&
				g_bPinJockey[victim] == false &&
				g_bPinCharger[victim] == false
			)
			{
				newVictim = victim;

				#if DEBUG_BENCHMARK == 3
				PrintToServer("Break order 1");
				#endif
			}
		}

		// 2=Vomited Survivor
		case 2:
		{
			if( team == 2 && g_bPinBoomer[victim] == true )
			{
				newVictim = victim;

				#if DEBUG_BENCHMARK == 3
				PrintToServer("Break order 2");
				#endif
			}
		}

		// 3=Incapped
		case 3:
		{
			if( team == 2 && g_bIncapped[victim] == true && g_bLedgeGrab[victim] == false )
			{
				newVictim = victim;

				#if DEBUG_BENCHMARK == 3
				PrintToServer("Break order 3");
				#endif
			}
		}

		// 4=Pinned
		case 4:
		{
			if( team == 2 &&
				g_bPinSmoker[victim] == true ||
				g_bPinHunter[victim] == true ||
				g_bPinJockey[victim] == true ||
				g_bPinCharger[victim] == true
			)
			{
				newVictim = victim;

				#if DEBUG_BENCHMARK == 3
				PrintToServer("Break order 4");
				#endif
			}
		}

		// 5=Ledge
		case 5:
		{
			if( team == 2 && g_bLedgeGrab[victim] )
			{
				newVictim = victim;

				#if DEBUG_BENCHMARK == 3
				PrintToServer("Break order 5");
				#endif
			}
		}

		// 6=Infected Vomited
		case 6:
		{
			if( team == 3 && victim != attacker && g_bPinBoomer[victim] )
			{
				newVictim = victim;

				#if DEBUG_BENCHMARK == 3
				PrintToServer("Break order 6");
				#endif
			}
		}

		// 7=Last Attacker
		case 7:
		{
			if( g_iLastAttacker[attacker] )
			{
				victim = GetClientOfUserId(g_iLastAttacker[attacker]);
				if( victim && IsPlayerAlive(victim) && GetClientTeam(victim) == 2 )
				{
					newVictim = victim;
				}

				#if DEBUG_BENCHMARK == 3
				PrintToServer("Break order 7");
				#endif
			}
		}

		// 8=Lowest Health Survivor
		case 8:
		{
			int target;
			int health;
			int total = 10000;

			for( int i = 1; i <= MaxClients; i++ )
			{
				if( IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) )
				{
					health = RoundFloat(GetClientHealth(i) + GetTempHealth(i));
					if( health < total )
					{
						target = i;
						total = health;
					}
				}
			}

			if( target == victim )
			{
				newVictim = target;

				#if DEBUG_BENCHMARK == 3
				PrintToServer("Break order 8");
				#endif
			}
		}

		// 9=Highest Health Survivor
		case 9:
		{
			int target;
			int health;
			int total;

			for( int i = 1; i <= MaxClients; i++ )
			{
				if( IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) )
				{
					health = RoundFloat(GetClientHealth(i) + GetTempHealth(i));
					if( health > total )
					{
						target = i;
						total = health;
					}
				}
			}

			if( target == victim )
			{
				newVictim = target;

				#if DEBUG_BENCHMARK == 3
				PrintToServer("Break order 9");
				#endif
			}
		}

		// 10=Pummelled Survivor
		case 10:
		{
			if( g_bPumCharger[victim] )
			{
				newVictim = victim;

				#if DEBUG_BENCHMARK == 3
				PrintToServer("Break order 10");
				#endif
			}
		}

		// 11=Mounted Mini Gun
		case 11:
		{
			if( GetEntProp(victim, Prop_Send, "m_usingMountedWeapon") > 0 )
			{
				newVictim = victim;

				#if DEBUG_BENCHMARK == 3
				PrintToServer("Break order 11");
				#endif
			}
		}
	}

	// Ignore players using a minigun if not checking for that
	if( newVictim && order != 11 && GetEntProp(newVictim, Prop_Send, "m_usingMountedWeapon") > 0 )
	{
		newVictim = 0;
	}

	return newVictim;
}

float GetTempHealth(int client)
{
	float fHealth = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
	fHealth -= (GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * g_fDecayDecay;
	return fHealth < 0.0 ? 0.0 : fHealth;
}