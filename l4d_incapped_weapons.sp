/*
*	Incapped Weapons Patch
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



#define PLUGIN_VERSION 		"1.13"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Incapped Weapons Patch
*	Author	:	SilverShot
*	Descrp	:	Patches the game to allow using Weapons while Incapped, instead of changing weapons scripts.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=322859
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.13 (16-Jun-2021)
	- L4D2: Optimized plugin by resetting Melee damage hooks on map end and round start.
	- L4D2: Compatibility update for "2.2.1.3" update. Thanks to "Dragokas" for fixing.
	- GameData .txt file updated.

1.12 (08-Mar-2021)
	- Added cvar "l4d_incapped_weapons_melee" to control Melee weapon damage to Survivors. Thanks to "Mystik Spiral" for reporting.

1.11 (15-Jan-2021)
	- Fixed weapons being blocked when incapped and changing team. Thanks to "HarryPotter" for reporting.

1.10 (10-May-2020)
	- Added better error log message when gamedata file is missing.
	- Extra checks to prevent "IsAllowedGameMode" throwing errors.

1.9 (12-Apr-2020)
	- Now keeps the active weapon selected unless it's restricted.
	- Fixed not being able to switch to melee weapons.
	- Fixed pistols possibly disappearing sometimes.
	- Fixed potential of duped pistols when dropped after incap.
	- Extra checks to prevent "IsAllowedGameMode" throwing errors.

1.8 (09-Apr-2020)
	- Fixed again not always restricting weapons correctly on incap. Thanks to "MasterMind420" for reporting.

1.7 (08-Apr-2020)
	- Fixed not equipping melee weapons when allowed on incap.

1.6 (08-Apr-2020)
	- Fixed breaking pistols, due to the last update.

1.5 (08-Apr-2020)
	- Fixed ammo being wiped when incapped, due to 1.3 update. Thanks to "Dragokas" for reporting.
	- Fixed not always restricting weapons correctly on incap. Thanks to "MasterMind420" for reporting.

1.4 (07-Apr-2020)
	- Fixed throwing a pistol when dual wielding. Thanks to "MasterMind420" for reporting.

1.3 (07-Apr-2020)
	- Fixed not equipping a valid weapon when the last equipped weapon was restricted.
	- Removed the ability to block pistols.
	- Thanks to "MasterMind420" for reporting.

1.2 (07-Apr-2020)
	- Fixed L4D1 Linux crashing. Only the plugin updated. Thanks to "Dragokas" for testing.

1.1 (07-Apr-2020)
	- Fixed hooking the L4D2 pistol cvar in L4D1. Thanks to "Alliance" for reporting.

1.0 (06-Apr-2020)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define CVAR_FLAGS			FCVAR_NOTIFY
#define GAMEDATA			"l4d_incapped_weapons"

ConVar g_hCvarAllow, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarMelee, g_hCvarPist, g_hCvarRest;
bool g_bCvarAllow, g_bMapStarted, g_bLeft4Dead2, g_bLateLoad;
int g_iCvarPist, g_iCvarMelee;

ArrayList g_ByteSaved_Deploy, g_ByteSaved_OnIncap;
Address g_Address_Deploy, g_Address_OnIncap;

ArrayList g_aRestrict;
StringMap g_aWeaponIDs;



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "倒地切换武器",
	author = "SilverShot",
	description = "Patches the game to allow using Weapons while Incapped, instead of changing weapons scripts.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=322859"
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

	g_bLateLoad = late;
	
	RegPluginLibrary("incapweapon_helpers");
	CreateNative("IncapWeapon_SetAllowedClient", Native_IncapWeapon_SetAllowedClient);
	
	return APLRes_Success;
}

bool g_bAllowedClient[MAXPLAYERS+1];

public int Native_IncapWeapon_SetAllowedClient(Handle plugin, int numParams)
{
	if(numParams < 2)
		ThrowNativeError(SP_ERROR_PARAM, "Invalid numParams");
	
	int client = GetNativeCell(1);
	bool allow = GetNativeCell(2);
	bool old = g_bAllowedClient[client];
	g_bAllowedClient[client] = allow;
	return view_as<int>(old);
}

public void OnAllPluginsLoaded()
{
	if( FindConVar("incapped_weapons_enable") != null )
	{
		SetFailState("Delete the old \"Incapped Weapons\" plugin to run this one.");
	}
}

public void OnPluginStart()
{
	// ====================================================================================================
	// GAMEDATA
	// ====================================================================================================
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	if( FileExists(sPath) == false ) SetFailState("\n==========\nMissing required file: \"%s\".\nRead installation instructions again.\n==========", sPath);

	Handle hGameData = LoadGameConfigFile(GAMEDATA);
	if( hGameData == null ) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	// Patch usage
	int iOffset = GameConfGetOffset(hGameData, "CanDeploy_Offset");
	if( iOffset == -1 ) SetFailState("Failed to load \"CanDeploy_Offset\" offset.");

	int iByteMatch = GameConfGetOffset(hGameData, "CanDeploy_Byte");
	if( iByteMatch == -1 ) SetFailState("Failed to load \"CanDeploy_Byte\" byte.");

	int iByteCount = GameConfGetOffset(hGameData, "CanDeploy_Count");
	if( iByteCount == -1 ) SetFailState("Failed to load \"CanDeploy_Count\" count.");

	g_Address_Deploy = GameConfGetAddress(hGameData, "CanDeploy");
	if( !g_Address_Deploy ) SetFailState("Failed to load \"CanDeploy\" address.");

	g_Address_Deploy += view_as<Address>(iOffset);
	g_ByteSaved_Deploy = new ArrayList();

	for( int i = 0; i < iByteCount; i++ )
	{
		g_ByteSaved_Deploy.Push(LoadFromAddress(g_Address_Deploy + view_as<Address>(i), NumberType_Int8));
	}

	if( g_ByteSaved_Deploy.Get(0) != iByteMatch ) SetFailState("Failed to load 'Deploy', byte mis-match @ %d (0x%02X != 0x%02X)", iOffset, g_ByteSaved_Deploy.Get(0), iByteMatch);

	// Patch melee
	if( g_bLeft4Dead2 )
	{
		g_Address_OnIncap = GameConfGetAddress(hGameData, "OnIncapacitatedAsSurvivor");
		if( !g_Address_OnIncap ) SetFailState("Failed to load \"OnIncapacitatedAsSurvivor\" address.");

		iOffset = GameConfGetOffset(hGameData, "OnIncap_Offset");
		if( iOffset == -1 ) SetFailState("Failed to load \"OnIncap_Offset\" offset.");

		iByteMatch = GameConfGetOffset(hGameData, "OnIncap_Byte");
		if( iByteMatch == -1 ) SetFailState("Failed to load \"OnIncap_Byte\" byte.");

		iByteCount = GameConfGetOffset(hGameData, "OnIncap_Count");
		if( iByteCount == -1 ) SetFailState("Failed to load \"OnIncap_Count\" count.");

		g_Address_OnIncap += view_as<Address>(iOffset);
		g_ByteSaved_OnIncap = new ArrayList();

		for( int i = 0; i < iByteCount; i++ )
		{
			g_ByteSaved_OnIncap.Push(LoadFromAddress(g_Address_OnIncap + view_as<Address>(i), NumberType_Int8));
		}

		if( g_ByteSaved_OnIncap.Get(0) != iByteMatch ) SetFailState("Failed to load 'OnIncap', byte mis-match @ %d (0x%02X != 0x%02X)", iOffset, g_ByteSaved_OnIncap.Get(0), iByteMatch);
	}

	delete hGameData;



	// ====================================================================================================
	// CVARS
	// ====================================================================================================
	g_hCvarAllow =		CreateConVar(	"l4d_incapped_weapons_allow",			"1",					"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarModes =		CreateConVar(	"l4d_incapped_weapons_modes",			"",						"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff =	CreateConVar(	"l4d_incapped_weapons_modes_off",		"",						"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog =	CreateConVar(	"l4d_incapped_weapons_modes_tog",		"0",					"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	if( g_bLeft4Dead2 )
	{
		g_hCvarMelee =	CreateConVar(	"l4d_incapped_weapons_melee",			"0",					"倒地后是否能攻击队友", CVAR_FLAGS);
		g_hCvarPist =	CreateConVar(	"l4d_incapped_weapons_pistol",			"1",					"倒地后是否把近战换成手枪", CVAR_FLAGS);
		g_hCvarRest =	CreateConVar(	"l4d_incapped_weapons_restrict",		"12,15,23,24,30,31",	"倒地禁止使用的武器,具体看帖子", CVAR_FLAGS);
	} else {
		g_hCvarRest =	CreateConVar(	"l4d_incapped_weapons_restrict",		"8,12",					"Empty string to allow all. Prevent these weapon/item IDs from being used while incapped. See plugin post for details.", CVAR_FLAGS);
	}
	CreateConVar(						"l4d_incapped_weapons_version",			PLUGIN_VERSION,			"Incapped Weapons plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true,				"l4d_incapped_weapons");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	if( g_bLeft4Dead2 )
	{
		g_hCvarPist.AddChangeHook(ConVarChanged_Cvars);
		g_hCvarMelee.AddChangeHook(ConVarChanged_Cvars);
	}
	g_hCvarRest.AddChangeHook(ConVarChanged_Cvars);



	// ====================================================================================================
	// WEAPON RESTRICTION
	// ====================================================================================================
	// Taken from "Left 4 DHooks Direct", see for complete list.
	g_aWeaponIDs = new StringMap();

	if( g_bLeft4Dead2 )
	{
		g_aWeaponIDs.SetValue("weapon_pistol",						1);
		g_aWeaponIDs.SetValue("weapon_smg",							2);
		g_aWeaponIDs.SetValue("weapon_pumpshotgun",					3);
		g_aWeaponIDs.SetValue("weapon_autoshotgun",					4);
		g_aWeaponIDs.SetValue("weapon_rifle",						5);
		g_aWeaponIDs.SetValue("weapon_hunting_rifle",				6);
		g_aWeaponIDs.SetValue("weapon_smg_silenced",				7);
		g_aWeaponIDs.SetValue("weapon_shotgun_chrome",				8);
		g_aWeaponIDs.SetValue("weapon_rifle_desert",				9);
		g_aWeaponIDs.SetValue("weapon_sniper_military",				10);
		g_aWeaponIDs.SetValue("weapon_shotgun_spas",				11);
		g_aWeaponIDs.SetValue("weapon_first_aid_kit",				12);
		g_aWeaponIDs.SetValue("weapon_molotov",						13);
		g_aWeaponIDs.SetValue("weapon_pipe_bomb",					14);
		g_aWeaponIDs.SetValue("weapon_pain_pills",					15);
		g_aWeaponIDs.SetValue("weapon_melee",						19);
		g_aWeaponIDs.SetValue("weapon_chainsaw",					20);
		g_aWeaponIDs.SetValue("weapon_grenade_launcher",			21);
		g_aWeaponIDs.SetValue("weapon_adrenaline",					23);
		g_aWeaponIDs.SetValue("weapon_defibrillator",				24);
		g_aWeaponIDs.SetValue("weapon_vomitjar",					25);
		g_aWeaponIDs.SetValue("weapon_rifle_ak47",					26);
		g_aWeaponIDs.SetValue("weapon_upgradepack_incendiary",		30);
		g_aWeaponIDs.SetValue("weapon_upgradepack_explosive",		31);
		g_aWeaponIDs.SetValue("weapon_pistol_magnum",				32);
		g_aWeaponIDs.SetValue("weapon_smg_mp5",						33);
		g_aWeaponIDs.SetValue("weapon_rifle_sg552",					34);
		g_aWeaponIDs.SetValue("weapon_sniper_awp",					35);
		g_aWeaponIDs.SetValue("weapon_sniper_scout",				36);
		g_aWeaponIDs.SetValue("weapon_rifle_m60",					37);
	} else {
		g_aWeaponIDs.SetValue("weapon_pistol",						1);
		g_aWeaponIDs.SetValue("weapon_smg",							2);
		g_aWeaponIDs.SetValue("weapon_pumpshotgun",					3);
		g_aWeaponIDs.SetValue("weapon_autoshotgun",					4);
		g_aWeaponIDs.SetValue("weapon_rifle",						5);
		g_aWeaponIDs.SetValue("weapon_hunting_rifle",				6);
		g_aWeaponIDs.SetValue("weapon_first_aid_kit",				8);
		g_aWeaponIDs.SetValue("weapon_molotov",						9);
		g_aWeaponIDs.SetValue("weapon_pipe_bomb",					10);
		g_aWeaponIDs.SetValue("weapon_pain_pills",					12);
	}



	// ====================================================================================================
	// LATE LOAD
	// ====================================================================================================
	if( g_bLateLoad )
	{
		for( int i = 1; i <= MaxClients; i++ )
		{
			if( IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_isIncapacitated", 1) && GetEntProp(i, Prop_Send, "m_isHangingFromLedge") == 0 )
			{
				SDKHook(i, SDKHook_WeaponCanSwitchTo, CanSwitchTo);
			}
		}
	}
}

public void OnPluginEnd()
{
	PatchAddress(false);
	PatchMelee(false);
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
	ResetPlugin();

	if( g_bLeft4Dead2 )
		MeleeDamageBlock(false);
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
	if( g_bLeft4Dead2 )
	{
		g_iCvarPist = g_hCvarPist.IntValue;
		g_iCvarMelee = g_hCvarMelee.IntValue;
		PatchMelee(g_iCvarPist == 0);

		if( g_bCvarAllow && g_iCvarPist == 0 && g_iCvarMelee == 0 )
			MeleeDamageBlock(true);
		else
			MeleeDamageBlock(false);
	}

	// Add weapon IDs to array
	char sBlock[128];
	g_hCvarRest.GetString(sBlock, sizeof(sBlock));

	delete g_aRestrict;
	g_aRestrict = new ArrayList();

	if( sBlock[0] )
	{
		StrCat(sBlock, sizeof(sBlock), ",");

		int index, last;
		while( (index = StrContains(sBlock[last], ",")) != -1 )
		{
			sBlock[last + index] = 0;
			g_aRestrict.Push(StringToInt(sBlock[last]));
			sBlock[last + index] = ',';
			last += index + 1;
		}
	}
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;
		PatchAddress(true);
		PatchMelee(g_iCvarPist == 0);
		HookEvents();

		if( g_bLeft4Dead2 && g_iCvarPist == 0 && g_iCvarMelee == 0 )
		{
			MeleeDamageBlock(true);
		}
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;
		PatchAddress(false);
		PatchMelee(false);
		UnhookEvents();
		ResetPlugin();

		if( g_bLeft4Dead2 )
		{
			MeleeDamageBlock(false);
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
void HookEvents()
{
	HookEvent("player_incapacitated",		Event_Incapped);
	HookEvent("revive_success",				Event_ReviveSuccess);
	HookEvent("player_death",				Event_PlayerDeath);
	HookEvent("player_team",				Event_PlayerDeath);
	HookEvent("round_start",				Event_RoundStart,	EventHookMode_PostNoCopy);
}

void UnhookEvents()
{
	UnhookEvent("player_incapacitated",		Event_Incapped);
	UnhookEvent("player_death",				Event_PlayerDeath);
	UnhookEvent("player_team",				Event_PlayerDeath);
	UnhookEvent("revive_success",			Event_ReviveSuccess);
	UnhookEvent("round_start",				Event_RoundStart,	EventHookMode_PostNoCopy);
}

public void Event_Incapped(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if( client && GetClientTeam(client) == 2 )
	{
		// Melee weapons block friendly fire
		if( g_bLeft4Dead2 && g_iCvarPist == 0 && g_iCvarMelee == 0 )
		{
			MeleeDamageBlock(true);
		}

		// For weapon restrictions
		SDKHook(client, SDKHook_WeaponCanSwitchTo, CanSwitchTo);

		// Active allowed
		int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if( weapon != -1 && ValidateWeapon(client, weapon) ) return;

		// Switch to primary/pistol/melee/other valid if current weapon restricted, otherwise do nothing.
		for( int i = 0; i < 5; i++ )
		{
			weapon = GetPlayerWeaponSlot(client, i);
			if( weapon != -1 && ValidateWeapon(client, weapon) )
			{
				return;
			}
		}
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon,
	int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(!g_bAllowedClient[client] && GetClientTeam(client) == 2 && GetEntProp(client, Prop_Send, "m_isIncapacitated", 1))
	{
		// 强制使用副武器
		int slot = GetPlayerWeaponSlot(client, 1);
		if(slot > MaxClients && weapon != slot)
		{
			weapon = slot;
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}

stock bool CheatCommand(int client, const char[] command, const char[] arguments = "", any ...)
{
	char fmt[1024];
	VFormat(fmt, 1024, arguments, 4);

	int cmdFlags = GetCommandFlags(command);
	SetCommandFlags(command, cmdFlags & ~FCVAR_CHEAT);

	if(IsClientInGame(client))
	{
		int adminFlags = GetUserFlagBits(client);
		SetUserFlagBits(client, ADMFLAG_ROOT);
		FakeClientCommand(client, "%s \"%s\"", command, fmt);
		SetUserFlagBits(client, adminFlags);
	}
	else
	{
		ServerCommand("%s \"%s\"", command, fmt);
	}

	SetCommandFlags(command, cmdFlags);

	return true;
}

bool ValidateWeapon(int client, int weapon)
{
	static char classname[32];
	GetEdictClassname(weapon, classname, sizeof(classname));

	int index;
	g_aWeaponIDs.GetValue(classname, index);

	if( index != 0 && g_aRestrict.FindValue(index) == -1 )
	{
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
		return true;
	}

	return false;
}

// Hook players OnTakeDamage if someone is incapped - to block melee weapon damage to survivors
void MeleeDamageBlock(bool enable)
{
	bool incapped;

	// Check someone is incapped
	if( enable )
	{
		for( int i = 1; i <= MaxClients; i++ )
		{
			if( IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_isIncapacitated", 1) && GetEntProp(i, Prop_Send, "m_isHangingFromLedge") == 0 )
			{
				incapped = true;
				break;
			}
		}
	}

	// Unhook and enable if required and someone incapped
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame(i) )
		{
			SDKUnhook(i, SDKHook_OnTakeDamageAlive, OnTakeDamage);

			if( enable && incapped && GetClientTeam(i) == 2 && IsPlayerAlive(i) )
				SDKHook(i, SDKHook_OnTakeDamageAlive, OnTakeDamage);
		}
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if( victim > 0 && victim <= MaxClients && attacker > 0 && attacker <= MaxClients && GetClientTeam(victim) == 2 && GetClientTeam(attacker) == 2 && GetEntProp(attacker, Prop_Send, "m_isIncapacitated", 1) && GetEntProp(attacker, Prop_Send, "m_isHangingFromLedge") == 0 )
	{
		weapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
		if( weapon > MaxClients && IsValidEntity(weapon) )
		{
			static char classname[16];
			GetEdictClassname(weapon, classname, sizeof(classname));

			if( strcmp(classname[7], "melee") == 0 )
			{
				damage = 0.0;
				return Plugin_Changed;
			}
		}
	}

	return Plugin_Continue;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if( client && GetClientTeam(client) == 2 )
	{
		if( g_bLeft4Dead2 && g_iCvarPist == 0 && g_iCvarMelee == 0 )
		{
			MeleeDamageBlock(true);
		}

		SDKUnhook(client, SDKHook_WeaponCanSwitchTo, CanSwitchTo);
	}
}

public void Event_ReviveSuccess(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("subject"));
	if( client && GetClientTeam(client) == 2 )
	{
		if( g_bLeft4Dead2 && g_iCvarPist == 0 && g_iCvarMelee == 0 )
		{
			MeleeDamageBlock(true);
		}

		SDKUnhook(client, SDKHook_WeaponCanSwitchTo, CanSwitchTo);
	}
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	ResetPlugin();

	if( g_bLeft4Dead2 )
		MeleeDamageBlock(false);
}

void ResetPlugin()
{
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame(i) )
		{
			SDKUnhook(i, SDKHook_WeaponCanSwitchTo, CanSwitchTo);
		}
	}
}

Action CanSwitchTo(int client, int weapon)
{
	static char classname[32];
	GetEdictClassname(weapon, classname, sizeof(classname));

	int index;
	g_aWeaponIDs.GetValue(classname, index);

	if( index == 0 || g_aRestrict.FindValue(index) != -1 )
		return Plugin_Handled;
	
	if(!g_bAllowedClient[client] && StrContains(classname, "pistol", false) == -1)
		return Plugin_Handled;
	
	return Plugin_Continue;
}



// ====================================================================================================
//					PATCH
// ====================================================================================================
void PatchAddress(int patch)
{
	static bool patched;

	if( !patched && patch )
	{
		patched = true;

		int len = g_ByteSaved_Deploy.Length;
		for( int i = 0; i < len; i++ )
		{
			if( len == 1 )
				StoreToAddress(g_Address_Deploy + view_as<Address>(i), 0x78, NumberType_Int8); // 0x75 JNZ (jump short if non zero) to 0x78 JS (jump short if sign) - always jump
			else
				StoreToAddress(g_Address_Deploy + view_as<Address>(i), 0x90, NumberType_Int8);
		}
	}
	else if( patched && !patch )
	{
		patched = false;

		int len = g_ByteSaved_Deploy.Length;
		for( int i = 0; i < len; i++ )
		{
			StoreToAddress(g_Address_Deploy + view_as<Address>(i), g_ByteSaved_Deploy.Get(i), NumberType_Int8);
		}
	}
}

void PatchMelee(int patch)
{
	if( !g_bLeft4Dead2 ) return;

	static bool patched;

	if( !patched && patch )
	{
		patched = true;

		int len = g_ByteSaved_OnIncap.Length;
		for( int i = 0; i < len; i++ )
		{
			StoreToAddress(g_Address_OnIncap + view_as<Address>(i), 0x90, NumberType_Int8);
		}
	}
	else if( patched && !patch )
	{
		patched = false;

		int len = g_ByteSaved_OnIncap.Length;
		for( int i = 0; i < len; i++ )
		{
			StoreToAddress(g_Address_OnIncap + view_as<Address>(i), g_ByteSaved_OnIncap.Get(i), NumberType_Int8);
		}
	}
}