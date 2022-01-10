/*
*	Throwable Melee Weapons
*	Copyright (C) 2022 Silvers
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



#define PLUGIN_VERSION 		"1.19"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D2] Throwable Melee Weapons
*	Author	:	SilverShot
*	Descrp	:	Allows players to throw melee weapons.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=321049
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.19 (06-Jan-2022)
	- Added each weapon types damage flags for slash and club. Requested by "Shao".

1.18 (01-Nov-2021)
	- Added cvar "l4d2_throwable_view" to enable/disable the throw animation in first person view that causes screen tilt bug.
	- Blocked throwing melee weapons if they that was their only held weapon/item. Thanks to "swiftswing1" for reporting.
	- Blocked throwing melee weapons if pinned or incapacitated.

1.17 (21-Sep-2021)
	- Fixed errors. Thanks to "Sev" for reporting.

1.16 (19-Sep-2021)
	- Fixed potentially blocking throwing on map changes.

1.15 (19-Sep-2021)
	- Now plays a throwing animation. Requested by "Sev".
	- Now removes the weapon glow when thrown (most of the time).
	- Now delays the throw slightly to hide the weapon being frozen when thrown.

1.14 (17-Sep-2021)
	- Fixed 1 line of code blocking unknown (generic) melee weapons from being used. Thanks to "swiftswing1" for reporting.

1.13 (20-Jun-2021)
	- Changed "SDKHook_WeaponSwitchPost" to read the "m_hActiveWeapon" netprop instead of using "weapon" from the callback.
	- When climbing ladders or being pinged "SDKHook_WeaponSwitchPost" returns the wrong weapon.
	- This should fix various issues such as not being able to throw after pinned or throwing after climbing while primary weapon is active.
	- Thanks to "SDArt" for reporting various issues.

1.12 (01-Oct-2020)
	- Fixed not verifying weapon reference and causing errors. Thanks to "SDArt" for reporting.

1.11 (30-Sep-2020)
	- Fixed compile errors on SM 1.11.
	- Fixed being able to throw while using something or climbing ladders.
	- To enable the new melee weapons, change cvar "l4d2_throwable_types" value adding the new ones.

1.10 (24-Sep-2020)
	- Compatibility update for L4D2's "The Last Stand" update.
	- Added support for the 2 new melee weapons.
	- Changed cvar "l4d2_throwable_types" to support the new types.
	- Updated data config "data/l4d2_throwable_melee.cfg" updated with the new Melee weapons.

1.9 (15-May-2020)
	- Replaced "point_hurt" entity with "SDKHooks_TakeDamage" function.

1.8 (10-May-2020)
	- Extra checks to prevent "IsAllowedGameMode" throwing errors.
	- Various changes to tidy up code.

1.7 (01-Apr-2020)
	- Fixed "IsAllowedGameMode" from throwing errors when the "_tog" cvar was changed before MapStart.

1.6 (29-Feb-2020)
	- Fixed throwing the melee weapon after switching weapon and back to melee. Thanks to "moschinovac" for reporting.

1.5 (26-Jan-2020)
	- To fix the Tonfa not working change "l4d2_throwable_types" value to "2047".

	- New feature: Throw distance - the longer you hold Zoom before releasing the further you throw. Requested by "MasterMind420".
	- Added cvar "l4d2_throwable_speed_max" to set a maximum throwing speed when holding MMB. Minimum speed set by "l4d2_throwable_speed".
	- Added cvar "l4d2_throwable_speed_time" to scale the throwing speed, how long the key must be held to reach maximum speed when letting go.
	- Changed cvar "l4d2_throwable_types" value to "2047" to include the missing Frying Pan option.
	- Boomerang type now verifies the players weapon slot is empty before equipping.
	- Optimized throwing event CPU cycles by validating weapon in WeaponSwitch.
	- Removed all commented out reference code.

1.4 (25-Jan-2020)
	- Fixed incorrect Linux gamedata signature causing crashing.
	- Fixed the "l4d2_throwable_types" cvar using the wrong index.
	- Fixed the Baseball Bat not working.
	- Fixed the Golfclub not playing any sounds.
	- Fixed the Tank not taking damage.
	- Fixed truncating damage values with 4 numbers to 3.
	- Fixed hitting when the melee is not moving or potentially not always hitting.
	- Fixed hitting yourself.
	- Removed TraceRay.

1.3 (24-Jan-2020)
	- Added cvar "l4d2_throwable_return" to enable a boomerang effect and return the weapon to thrower.
	- Added support for "Riot Shield" melee type and "Generic" - any 3rd party melee weapon.
	- Riot Shield requires extra scripts to enable, I do not support. You're on your own.
	- Data config changed to add the new types.
	- Changed from using max health cvars to reading the entities "m_iMaxHealth" value.
	- Fixed incorrect percentage calculation when using the "hits" damage type.
	- Replaced index numbers with enums for easier source readability.

1.2 (24-Jan-2020)
	- Added TraceRay to hit zombies directly in front of player. Thanks to "Lux" for suggesting.
	- Replaced optional VPhysics extension with gamedata method. Thanks to "BHaType" for suggesting.
	- Cvar "l4d2_throwable_spin" uses this method and requires the optional gamedata file.
	- Fixed damage not crediting the owner.

1.1 (22-Jan-2020)
	- Added correct data config.
	- Changed plugin to point to the correct config.
	- Changed plugin to remove VPhysics extension for now, since optional is not working.

1.0 (22-Jan-2020)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sdktools>
#include <sdkhooks>

#define CVAR_FLAGS			FCVAR_NOTIFY
#define SOUND_THROW			"weapons/knife/knife_swing_miss1.wav"
#define CONFIG_DATA			"data/l4d2_throwable_melee.cfg"
#define GAMEDATA			"l4d2_throwable_melee"


ConVar g_hCvarAllow, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarReturn, g_hCvarSpeed, g_hCvarSpeedMax, g_hCvarSpeedTime, g_hCvarSpin, g_hCvarView, g_hCvarTypes;
int g_iCvarReturn, g_iCvarSpeed, g_iCvarSpeedMax, g_iCvarSpin, g_iCvarView, g_iCvarTypes;
float g_fCvarSpeedTime;
bool g_bCvarAllow, g_bMapStarted, g_bLateLoad;

float g_fDamageHits[10];
float g_fDamageWeps[15];
float g_fDamageTarg[10];
float g_fLastPos[2048][3];
// float g_fFlightTime[MAXPLAYERS+1];
float g_fPlayerTime[MAXPLAYERS+1];
float g_fThrowAnim[MAXPLAYERS+1];
int g_iHasWeapon[MAXPLAYERS+1];
bool g_bTouchBack[4096];

StringMap g_hMeleeTypes;
Handle sdkAngularVelocity;
bool g_bHasGamedata;

enum
{
	INDEX_COMMON = 0,
	INDEX_WITCH,
	INDEX_SURVIVOR,
	INDEX_TANK,
	INDEX_SMOKER,
	INDEX_BOOMER,
	INDEX_HUNTER,
	INDEX_SPITTER,
	INDEX_JOCKEY,
	INDEX_CHARGER
}

enum
{
	WEAPON_BASEBALL = 0,
	WEAPON_CRICKET,
	WEAPON_CROWBAR,
	WEAPON_GUITAR,
	WEAPON_FIREAXE,
	WEAPON_FRYING,
	WEAPON_GOLFCLUB,
	WEAPON_KATANA,
	WEAPON_KNIFE,
	WEAPON_MACHETE,
	WEAPON_TONFA,
	WEAPON_PITCHFORK,
	WEAPON_SHOVEL,
	WEAPON_SHIELD,
	WEAPON_GENERIC
}

// axe_break.wav // cool sound
static const char g_sSounds_Axe[][] =
{
	"weapons/axe/melee_axe_01.wav",
	"weapons/axe/melee_axe_02.wav",
	"weapons/axe/melee_axe_03.wav"
};

static const char g_sSounds_Bat[][] =
{
	"weapons/bat/bat_impact_world1.wav",
	"weapons/bat/bat_impact_world2.wav",
};

static const char g_sSounds_Cricket[][] =
{
	"weapons/bat/melee_cricket_bat_01.wav",
	"weapons/bat/melee_cricket_bat_02.wav",
	"weapons/bat/melee_cricket_bat_03.wav"
};

static const char g_sSounds_Crowbar[][] =
{
	"weapons/crowbar/crowbar_impact_flesh1.wav",
	"weapons/crowbar/crowbar_impact_flesh2.wav"
};

static const char g_sSounds_Golf[][] =
{
	"weapons/golf_club/wpn_golf_club_melee_01.wav",
	"weapons/golf_club/wpn_golf_club_melee_02.wav"
};

static const char g_sSounds_Gtr[][] =
{
	"weapons/guitar/melee_guitar_01.wav",
	"weapons/guitar/melee_guitar_02.wav",
	"weapons/guitar/melee_guitar_03.wav",
	"weapons/guitar/melee_guitar_04.wav",
	"weapons/guitar/melee_guitar_05.wav",
	"weapons/guitar/melee_guitar_07.wav",
	"weapons/guitar/melee_guitar_08.wav",
	"weapons/guitar/melee_guitar_10.wav",
	"weapons/guitar/melee_guitar_11.wav",
	"weapons/guitar/melee_guitar_12.wav",
	"weapons/guitar/melee_guitar_13.wav",
	"weapons/guitar/melee_guitar_14.wav"
};

static const char g_sSounds_Kat[][] =
{
	"weapons/katana/melee_katana_01.wav",
	"weapons/katana/melee_katana_02.wav",
	"weapons/katana/melee_katana_03.wav"
};

static const char g_sSounds_Knife[][] =
{
	"weapons/knife/melee_knife_01.wav",
	"weapons/knife/melee_knife_02.wav"
};

static const char g_sSounds_Machete[][] =
{
	"weapons/machete/machete_impact_flesh1.wav",
	"weapons/machete/machete_impact_flesh2.wav"
};

static const char g_sSounds_Pan[][] =
{
	"weapons/pan/melee_frying_pan_01.wav",
	"weapons/pan/melee_frying_pan_02.wav",
	"weapons/pan/melee_frying_pan_03.wav",
	"weapons/pan/melee_frying_pan_04.wav"
};

static const char g_sSounds_Tonfa[][] =
{
	"weapons/tonfa/melee_tonfa_01.wav",
	"weapons/tonfa/melee_tonfa_02.wav"
};

static const char g_sSounds_Pitch[][] =
{
	"weapons/pitchfork/pitchfork_impact_world1.wav",
	"weapons/pitchfork/pitchfork_impact_world2.wav",
	"weapons/pitchfork/pitchfork_impact_world3.wav",
	"weapons/pitchfork/pitchfork_impact_world4.wav"
};

static const char g_sSounds_Shovel[][] =
{
	"weapons/shovel/shovel_impact_world1.wav",
	"weapons/shovel/shovel_impact_world2.wav"
};

bool g_bAllowCreator[MAXPLAYERS+1];


// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "投掷近战武器",
	author = "SilverShot",
	description = "Allows players to throw melee weapons.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=321049"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}

	g_bLateLoad = late;
	
	CreateNative("ThrowMelee_SetAllowedClient", NATIVE_ThrowMelee_SetAllowedClient);
	RegPluginLibrary("throwmelee_helpers");
	
	return APLRes_Success;
}

public int NATIVE_ThrowMelee_SetAllowedClient(Handle plugin, int numParams)
{
	if(numParams < 2)
		ThrowNativeError(SP_ERROR_PARAM, "Invalid numParams");
	
	int client = GetNativeCell(1);
	bool allow = GetNativeCell(2);
	bool old = g_bAllowCreator[client];
	g_bAllowCreator[client] = allow;
	return view_as<int>(old);
}

public void OnPluginStart()
{
	// ====================================================================================================
	// SDKCall
	// ====================================================================================================
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	if( FileExists(sPath) )
	{
		Handle hGameData = LoadGameConfigFile(GAMEDATA);
		if( hGameData == null ) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

		StartPrepSDKCall(SDKCall_Entity);
		if( PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CBaseEntity::ApplyLocalAngularVelocityImpulse") == false )
			SetFailState("Could not load the \"CBaseEntity::ApplyLocalAngularVelocityImpulse\" gamedata signature.");

		delete hGameData;

		PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
		sdkAngularVelocity = EndPrepSDKCall();
		if( sdkAngularVelocity == null )
			SetFailState("Could not prep the \"CPipeBombProjectile_Create\" function.");

		g_bHasGamedata = true;
	}

	// ====================================================================================================
	// Cvars
	// ====================================================================================================
	g_hCvarAllow =		CreateConVar(	"l4d2_throwable_allow",			"1",				"是否开启插件", CVAR_FLAGS );
	g_hCvarModes =		CreateConVar(	"l4d2_throwable_modes",			"",					"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff =	CreateConVar(	"l4d2_throwable_modes_off",		"",					"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog =	CreateConVar(	"l4d2_throwable_modes_tog",		"0",				"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	g_hCvarReturn =		CreateConVar(	"l4d2_throwable_return",		"1",				"是否开启回旋镖模式", CVAR_FLAGS);
	g_hCvarSpeed =		CreateConVar(	"l4d2_throwable_speed",			"500",				"最小飞行速度", CVAR_FLAGS);
	g_hCvarSpeedMax =	CreateConVar(	"l4d2_throwable_speed_max",		"1000",				"最大飞行速度", CVAR_FLAGS);
	g_hCvarSpeedTime =	CreateConVar(	"l4d2_throwable_speed_time",	"1.0",				"蓄力最大时间,速度基于蓄力时长", CVAR_FLAGS);
	g_hCvarSpin =		CreateConVar(	"l4d2_throwable_spin",			"3",				"飞行旋转方式.1=竖着转.2=横着转", CVAR_FLAGS);
	g_hCvarTypes =		CreateConVar(	"l4d2_throwable_types",			"32767",			"可以投掷的武器: 1=棒球棒, 2=船桨, 4=敲鼓, 8=锅, 16=吉他, 32=斧子, 64=球棍, 128=武士刀, 256=小刀, 512=柴刀, 1024=警棍, 2048=盾牌, 4096=通用, 8192=叉子, 16384=铲子, 32767=全部. Add numbers together.", CVAR_FLAGS);
	g_hCvarView =		CreateConVar(	"l4d2_throwable_view",			"1",				"投掷时屏幕晃动(可能有bug)", CVAR_FLAGS);
	CreateConVar(						"l4d2_throwable_version",		PLUGIN_VERSION,		"Throwable Melee Weapons plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true,				"l4d2_throwable_melee");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hCvarReturn.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarSpeed.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarSpeedMax.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarSpeedTime.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarSpin.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarView.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarTypes.AddChangeHook(ConVarChanged_Cvars);

	// ====================================================================================================
	// Other
	// ====================================================================================================
	RegAdminCmd("sm_throwable_reload", CmdReload, ADMFLAG_ROOT, "Reloads the weapons damage data config.");

	LoadData();

	g_hMeleeTypes = CreateTrie();
	g_hMeleeTypes.SetValue("baseball_bat",		WEAPON_BASEBALL);
	g_hMeleeTypes.SetValue("cricket_bat",		WEAPON_CRICKET);
	g_hMeleeTypes.SetValue("crowbar",			WEAPON_CROWBAR);
	g_hMeleeTypes.SetValue("electric_guitar",	WEAPON_GUITAR);
	g_hMeleeTypes.SetValue("fireaxe",			WEAPON_FIREAXE);
	g_hMeleeTypes.SetValue("frying_pan",		WEAPON_FRYING);
	g_hMeleeTypes.SetValue("golfclub",			WEAPON_GOLFCLUB);
	g_hMeleeTypes.SetValue("katana",			WEAPON_KATANA);
	g_hMeleeTypes.SetValue("knife",				WEAPON_KNIFE);
	g_hMeleeTypes.SetValue("machete",			WEAPON_MACHETE);
	g_hMeleeTypes.SetValue("tonfa",				WEAPON_TONFA);
	g_hMeleeTypes.SetValue("pitchfork",			WEAPON_PITCHFORK);
	g_hMeleeTypes.SetValue("shovel",			WEAPON_SHOVEL);
	g_hMeleeTypes.SetValue("riot_shield",		WEAPON_SHIELD);
	g_hMeleeTypes.SetValue("generic",			WEAPON_GENERIC);

	if( g_bLateLoad )
	{
		for( int i = 1; i <= MaxClients; i++ )
		{
			if( IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) )
			{
				SDKHook(i, SDKHook_WeaponSwitchPost, WeaponSwitch);

				int weapon = GetEntPropEnt(i, Prop_Send, "m_hActiveWeapon");
				if( weapon > MaxClients && IsValidEntity(weapon) )
				{
					WeaponSwitch(i, weapon);
				}
			}
		}
	}
}

public void OnMapStart()
{
	g_bMapStarted = true;

	PrecacheSound(SOUND_THROW);
	for( int i = 0; i < sizeof(g_sSounds_Axe); i++ )			PrecacheSound(g_sSounds_Axe[i]);
	for( int i = 0; i < sizeof(g_sSounds_Bat); i++ )			PrecacheSound(g_sSounds_Bat[i]);
	for( int i = 0; i < sizeof(g_sSounds_Cricket); i++ )		PrecacheSound(g_sSounds_Cricket[i]);
	for( int i = 0; i < sizeof(g_sSounds_Crowbar); i++ )		PrecacheSound(g_sSounds_Crowbar[i]);
	for( int i = 0; i < sizeof(g_sSounds_Golf); i++ )			PrecacheSound(g_sSounds_Golf[i]);
	for( int i = 0; i < sizeof(g_sSounds_Gtr); i++ )			PrecacheSound(g_sSounds_Gtr[i]);
	for( int i = 0; i < sizeof(g_sSounds_Kat); i++ )			PrecacheSound(g_sSounds_Kat[i]);
	for( int i = 0; i < sizeof(g_sSounds_Knife); i++ )			PrecacheSound(g_sSounds_Knife[i]);
	for( int i = 0; i < sizeof(g_sSounds_Machete); i++ )		PrecacheSound(g_sSounds_Machete[i]);
	for( int i = 0; i < sizeof(g_sSounds_Pan); i++ )			PrecacheSound(g_sSounds_Pan[i]);
	for( int i = 0; i < sizeof(g_sSounds_Tonfa); i++ )			PrecacheSound(g_sSounds_Tonfa[i]);
}

public void OnMapEnd()
{
	g_bMapStarted = false;
}

public Action CmdReload(int client, int args)
{
	LoadData();
	return Plugin_Handled;
}

public void LoadData()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_DATA);
	if( FileExists(sPath) == false )
	{
		LogError("Missing data config: \"%s\"", CONFIG_DATA);
		return;
	}

	// Load config
	KeyValues hFile = new KeyValues("throwable_damage");
	if( !hFile.ImportFromFile(sPath) )
	{
		LogError("Failed to load data config: \"%s\"", CONFIG_DATA);
		delete hFile;
		return;
	}

	if( hFile.JumpToKey("hits") )
	{
		g_fDamageHits[INDEX_COMMON]		= hFile.GetFloat("common",		0.0);
		g_fDamageHits[INDEX_WITCH]		= hFile.GetFloat("witch",		0.0);
		g_fDamageHits[INDEX_SURVIVOR]	= hFile.GetFloat("survivor",	0.0);
		g_fDamageHits[INDEX_TANK]		= hFile.GetFloat("tank",		0.0);
		g_fDamageHits[INDEX_SMOKER]		= hFile.GetFloat("smoker",		0.0);
		g_fDamageHits[INDEX_BOOMER]		= hFile.GetFloat("boomer",		0.0);
		g_fDamageHits[INDEX_HUNTER]		= hFile.GetFloat("hunter",		0.0);
		g_fDamageHits[INDEX_SPITTER]	= hFile.GetFloat("spitter",		0.0);
		g_fDamageHits[INDEX_JOCKEY]		= hFile.GetFloat("jockey",		0.0);
		g_fDamageHits[INDEX_CHARGER]	= hFile.GetFloat("charger",		0.0);
	}
	hFile.Rewind();

	if( hFile.JumpToKey("targets") )
	{
		g_fDamageTarg[INDEX_COMMON]		= hFile.GetFloat("common",		0.0);
		g_fDamageTarg[INDEX_WITCH]		= hFile.GetFloat("witch",		0.0);
		g_fDamageTarg[INDEX_SURVIVOR]	= hFile.GetFloat("survivor",	0.0);
		g_fDamageTarg[INDEX_TANK]		= hFile.GetFloat("tank",		0.0);
		g_fDamageTarg[INDEX_SMOKER]		= hFile.GetFloat("smoker",		0.0);
		g_fDamageTarg[INDEX_BOOMER]		= hFile.GetFloat("boomer",		0.0);
		g_fDamageTarg[INDEX_HUNTER]		= hFile.GetFloat("hunter",		0.0);
		g_fDamageTarg[INDEX_SPITTER]	= hFile.GetFloat("spitter",		0.0);
		g_fDamageTarg[INDEX_JOCKEY]		= hFile.GetFloat("jockey",		0.0);
		g_fDamageTarg[INDEX_CHARGER]	= hFile.GetFloat("charger",		0.0);
	}
	hFile.Rewind();

	if( hFile.JumpToKey("weapons") )
	{
		g_fDamageWeps[WEAPON_BASEBALL]		= hFile.GetFloat("baseball_bat",		0.0);
		g_fDamageWeps[WEAPON_CRICKET]		= hFile.GetFloat("cricket_bat",			0.0);
		g_fDamageWeps[WEAPON_CROWBAR]		= hFile.GetFloat("crowbar",				0.0);
		g_fDamageWeps[WEAPON_GUITAR]		= hFile.GetFloat("electric_guitar",		0.0);
		g_fDamageWeps[WEAPON_FIREAXE]		= hFile.GetFloat("fireaxe",				0.0);
		g_fDamageWeps[WEAPON_FRYING]		= hFile.GetFloat("frying_pan",			0.0);
		g_fDamageWeps[WEAPON_GOLFCLUB]		= hFile.GetFloat("golfclub",			0.0);
		g_fDamageWeps[WEAPON_KATANA]		= hFile.GetFloat("katana",				0.0);
		g_fDamageWeps[WEAPON_KNIFE]			= hFile.GetFloat("knife",				0.0);
		g_fDamageWeps[WEAPON_MACHETE]		= hFile.GetFloat("machete",				0.0);
		g_fDamageWeps[WEAPON_TONFA]			= hFile.GetFloat("tonfa",				0.0);
		g_fDamageWeps[WEAPON_PITCHFORK]		= hFile.GetFloat("pitchfork",			0.0);
		g_fDamageWeps[WEAPON_SHOVEL]		= hFile.GetFloat("shovel",				0.0);
		g_fDamageWeps[WEAPON_SHIELD]		= hFile.GetFloat("riot_shield",			0.0);
		g_fDamageWeps[WEAPON_GENERIC]		= hFile.GetFloat("generic",				0.0);
	}

	delete hFile;
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
	g_iCvarReturn = g_hCvarReturn.IntValue;
	g_iCvarSpeed = g_hCvarSpeed.IntValue;
	g_iCvarSpeedMax = g_hCvarSpeedMax.IntValue;
	g_fCvarSpeedTime = g_hCvarSpeedTime.FloatValue;
	g_iCvarSpin = g_hCvarSpin.IntValue;
	g_iCvarView = g_hCvarView.IntValue;
	g_iCvarTypes = g_hCvarTypes.IntValue;
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		HookEvent("player_spawn", Event_PlayerSpawn);
		HookEvent("player_death", Event_PlayerDeath);
		g_bCvarAllow = true;
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		UnhookEvent("player_spawn", Event_PlayerSpawn);
		UnhookEvent("player_death", Event_PlayerDeath);
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
public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if( client && GetClientTeam(client) == 2 )
	{
		SDKHook(client, SDKHook_WeaponSwitchPost, WeaponSwitch);
	}
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if( client )
	{
		SDKUnhook(client, SDKHook_WeaponSwitchPost, WeaponSwitch);
	}
}

public void WeaponSwitch(int client, int weapon)
{
	g_iHasWeapon[client] = 0;

	weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if( weapon > MaxClients && IsValidEntity(weapon) && !IsFakeClient(client) )
	{
		char class[16];
		GetEdictClassname(weapon, class, sizeof(class));

		if( strncmp(class[7], "melee", 5) == 0 )
		{
			g_iHasWeapon[client] = EntIndexToEntRef(weapon);
			g_fThrowAnim[client] = 0.0;
		} else {
			g_fPlayerTime[client] = 0.0;
		}
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3])
{
	if( g_bCvarAllow && g_iHasWeapon[client] && !IsFakeClient(client) && IsPlayerAlive(client) )
	{
		if( buttons & IN_ZOOM )
		{
			if( !g_fCvarSpeedTime )
			{
				CreateMelee(client);
			}
			else if( g_fPlayerTime[client] == 0.0 )
			{
				g_fPlayerTime[client] = GetGameTime();
			}
		}
		else if( g_fPlayerTime[client] )
		{
			CreateMelee(client);
		}
	}

	return Plugin_Continue;
}

void CreateMelee(int client)
{
	if(!g_bAllowCreator[client]) return;
	
	// Timeout between checks
	if( g_fThrowAnim[client] > GetGameTime() ) return;
	g_fThrowAnim[client] = GetGameTime() + 0.3;

	// Verify melee is not the only weapon
	int weapons;
	for( int i = 0; i <= 5; i++ )
		if( GetPlayerWeaponSlot(client, i) != -1 ) weapons++;
	if( weapons == 1 ) return;

	// Setting animation to pipebomb plays the throw animation, but resetting back to original makes both hands lift up and looks even better than lift/throw grenade animation!
	if( g_iCvarView )
	{
		static char sModelName[64];
		int viewmodel = GetEntPropEnt(client, Prop_Data, "m_hViewModel");
		GetEntPropString(viewmodel, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));
		SetEntityModel(viewmodel, "models/v_models/v_pipebomb.mdl");
		SetEntProp(viewmodel, Prop_Send, "m_nLayerSequence", 5);
		SetEntPropFloat(viewmodel, Prop_Send, "m_flLayerStartTime", GetGameTime());
		SetEntityModel(viewmodel, sModelName);
	}

	// Throw weapon delayed
	CreateTimer(0.2, TimerThrowMelee, GetClientUserId(client));
}

public Action TimerThrowMelee(Handle timer, any client)
{
	client = GetClientOfUserId(client);
	if( client && IsClientInGame(client) )
	{
		CreateMeleeEntity(client);
	}

	return Plugin_Continue;
}

void CreateMeleeEntity(int client)
{
	// Validate can use
	if( GetEntityMoveType(client) & MOVETYPE_LADDER || GetEntPropEnt(client, Prop_Send, "m_hUseEntity") != -1 || GetEntProp(client, Prop_Send, "m_iCurrentUseAction") != 0 )
	{
		g_fPlayerTime[client] = 0.0;
		return;
	}

	// Validate not pinned
	if( GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) || GetEntProp(client, Prop_Send, "m_isHangingFromLedge", 1) || GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0 || GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0 )
	{
		g_fPlayerTime[client] = 0.0;
		return;
	}

	if( GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0 || GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0 || GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0 )
	{
		g_fPlayerTime[client] = 0.0;
		return;
	}



	// Validate type
	char script[16];
	int weapon = g_iHasWeapon[client];
	if( weapon == 0 ) return;

	g_iHasWeapon[client] = 0;

	weapon = EntRefToEntIndex(weapon);
	if( weapon <= 0 ) return;

	GetEntPropString(weapon, Prop_Data, "m_strMapSetScriptName", script, sizeof(script));

	int type;
	if( g_hMeleeTypes.GetValue(script, type) == false ) type = WEAPON_GENERIC;
	if( g_iCvarTypes & (1<<type) == 0 ) return;

	// Remove
	RemovePlayerItem(client, weapon);
	RemoveEntity(weapon);

	// Create
	weapon = CreateEntityByName("weapon_melee"); // prop_physics* doesn't work
	if( weapon != -1 )
	{
		// Vectors
		float vPos[3], vAng[3], vDir[3];
		GetClientEyeAngles(client, vAng);
		GetClientEyePosition(client, vPos);

		DispatchKeyValue(weapon, "solid", "6");
		DispatchKeyValue(weapon, "melee_script_name", script);
		DispatchSpawn(weapon);
		SetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity", client);
		GetAngleVectors(vAng, vDir, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(vDir, vDir);

		// Throwing speed
		float speed;
		if( g_fCvarSpeedTime )
		{
			speed = GetGameTime() - g_fPlayerTime[client]; // How long held
			if( speed > g_fCvarSpeedTime ) speed = g_fCvarSpeedTime; // Limit max time
			speed = 100.0 * speed / g_fCvarSpeedTime;
			speed = float(g_iCvarSpeedMax) * speed / 100.0;

			if( speed > float(g_iCvarSpeedMax) )		speed = float(g_iCvarSpeedMax);
			else if( speed < float(g_iCvarSpeed) )		speed = float(g_iCvarSpeed);

			g_fPlayerTime[client] = 0.0;
		} else {
			speed = float(g_iCvarSpeed);
		}

		ScaleVector(vDir, speed);

		vAng[0] = 90.0; // So knife flies flat, if not using vphysics
		TeleportEntity(weapon, vPos, vAng, vDir);

		// Hide entity so it's not visibly frozen in the air until it starts moving
		SetEntityRenderMode(weapon, RENDER_TRANSALPHA);
		SetEntityRenderColor(weapon, 0, 0, 0, 0);

		// Hide weapon glow when throwing
		SetEntProp(weapon, Prop_Send, "m_iGlowType", 3);
		SetEntProp(weapon, Prop_Data, "m_iGlowType", 3);
		SetEntProp(weapon, Prop_Send, "m_glowColorOverride", 1);

		CreateTimer(0.1, TimerRender, EntIndexToEntRef(weapon));

		// Spin
		if( g_iCvarSpin && g_bHasGamedata )
		{
			int spin = g_iCvarSpin == 3 ? GetRandomInt(1, 2) : g_iCvarSpin;
			if( spin == 1 ) vDir = view_as<float>({ 0.0, 1.0, 0.0});
			else vDir = view_as<float>({ -1.0, 0.0, 0.0});

			NormalizeVector(vDir, vDir);
			ScaleVector(vDir, 10000.0);
			SDKCall(sdkAngularVelocity, weapon, vDir);
		}

		EmitSoundToAll(SOUND_THROW, weapon);

		// Because we cannot get objects moving speed to determine when it's stationary
		g_fLastPos[weapon] = vPos;
		CreateTimer(0.2, TimerPos, EntIndexToEntRef(weapon), TIMER_REPEAT);

		SDKHook(weapon, SDKHook_Touch, OnTouch);
		g_bTouchBack[weapon] = true;
	}
}

public Action TimerRender(Handle timer, any weapon)
{
	if( EntRefToEntIndex(weapon) != INVALID_ENT_REFERENCE )
	{
		SetEntityRenderColor(weapon, 255, 255, 255, 255);
	}

	return Plugin_Continue;
}

public Action TimerPos(Handle timer, any entity)
{
	entity = EntRefToEntIndex(entity);
	if( entity != INVALID_ENT_REFERENCE )
	{
		float vPos[3];
		GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vPos);
		if( GetVectorDistance(g_fLastPos[entity], vPos) < 5.0 )
		{
			SDKUnhook(entity, SDKHook_Touch, OnTouch);
			g_fLastPos[entity] = view_as<float>({0.0, 0.0, 0.0});
		} else {
			g_fLastPos[entity] = vPos;
			return Plugin_Continue;
		}
	}
	
	// 触地回弹
	if( g_iCvarReturn && entity != INVALID_ENT_REFERENCE && g_bTouchBack[entity] )
	{
		int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
		if(client > 0 && IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2)
		{
			// Vectors
			float vPos[3], vOrg[3], vDir[3];
			GetClientEyePosition(client, vPos);
			GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vOrg);
			g_fLastPos[entity] = vOrg;
			MakeVectorFromPoints(vOrg, vPos, vDir);

			NormalizeVector(vDir, vDir);
			ScaleVector(vDir, float(g_iCvarSpeed));

			vDir[2] += GetVectorDistance(vPos, vOrg);
			TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, vDir);
			CreateTimer(0.1, TimerCheck, EntIndexToEntRef(entity), TIMER_REPEAT);
			// g_fFlightTime[client] = GetGameTime();
			g_bTouchBack[entity] = false;
			
			return Plugin_Continue;
		}
	}

	return Plugin_Stop;
}

public void OnTouch(int weapon, int target)
{
	int client = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
	if( client == -1 || client == target )
	{
		return;
	}

	// Stop
	TeleportEntity(weapon, NULL_VECTOR, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
	SDKUnhook(weapon, SDKHook_Touch, OnTouch);
	g_bTouchBack[weapon] = false;

	// Type
	char script[16];
	GetEntPropString(weapon, Prop_Data, "m_strMapSetScriptName", script, sizeof(script));
	int type;
	if( g_hMeleeTypes.GetValue(script, type) == false ) type = WEAPON_GENERIC;

	// Damage
	float damage;
	bool hit;

	if( target >= 1 && target <= MaxClients )
	{
		if( GetClientTeam(target) == 2 )
		{
			// Survivors
			hit = true;
			damage = g_fDamageHits[INDEX_SURVIVOR] ? float(GetEntProp(target, Prop_Data, "m_iMaxHealth")) / 100.0 * g_fDamageHits[INDEX_SURVIVOR] : g_fDamageWeps[type] * g_fDamageTarg[INDEX_SURVIVOR];
		}
		else
		{
			// Special Infected
			hit = true;
			int index = GetEntProp(target, Prop_Send, "m_zombieClass") + 3;
			if( index == 11 ) index = 3;
			damage = g_fDamageHits[index] ? float(GetEntProp(target, Prop_Data, "m_iMaxHealth")) / 100.0 * g_fDamageHits[index] : g_fDamageWeps[type] * g_fDamageTarg[index];
		}
	}
	else if( target > MaxClients )
	{
		if( g_fDamageHits[INDEX_COMMON] || g_fDamageHits[INDEX_WITCH] || g_fDamageTarg[INDEX_COMMON] || g_fDamageTarg[INDEX_WITCH] )
		{
			// Classname
			char class[10];
			GetEdictClassname(target, class, sizeof(class));

			// Common Infected
			if( strcmp(class, "infected") == 0 )
			{
				hit = true;
				damage = g_fDamageHits[INDEX_COMMON] ? float(GetEntProp(target, Prop_Data, "m_iMaxHealth")) / 100.0 * g_fDamageHits[INDEX_COMMON] : g_fDamageWeps[type] * g_fDamageTarg[INDEX_COMMON];
			}
			// Witch
			else if( strcmp(class, "witch") == 0 )
			{
				hit = true;
				damage = g_fDamageHits[INDEX_WITCH] ? float(GetEntProp(target, Prop_Data, "m_iMaxHealth")) / 100.0 * g_fDamageHits[INDEX_WITCH] : g_fDamageWeps[type] * g_fDamageTarg[INDEX_WITCH];
			}
		}
	}

	if( damage )
	{
		HurtEntity(target, client, type, damage);
	}

	// Sound
	if( hit )
	{
		SDKUnhook(weapon, SDKHook_Touch, OnTouch);

		switch( type )
		{
			case WEAPON_BASEBALL:	EmitSoundToAll(g_sSounds_Bat[		GetRandomInt(0, sizeof(g_sSounds_Bat) - 1)],		weapon);
			case WEAPON_CRICKET:	EmitSoundToAll(g_sSounds_Cricket[	GetRandomInt(0, sizeof(g_sSounds_Cricket) - 1)],	weapon);
			case WEAPON_CROWBAR:	EmitSoundToAll(g_sSounds_Crowbar[	GetRandomInt(0, sizeof(g_sSounds_Crowbar) - 1)],	weapon);
			case WEAPON_GUITAR:		EmitSoundToAll(g_sSounds_Gtr[		GetRandomInt(0, sizeof(g_sSounds_Gtr) - 1)],		weapon);
			case WEAPON_FIREAXE:	EmitSoundToAll(g_sSounds_Axe[		GetRandomInt(0, sizeof(g_sSounds_Axe) - 1)],		weapon);
			case WEAPON_FRYING:		EmitSoundToAll(g_sSounds_Pan[		GetRandomInt(0, sizeof(g_sSounds_Pan) - 1)],		weapon);
			case WEAPON_GOLFCLUB:	EmitSoundToAll(g_sSounds_Golf[		GetRandomInt(0, sizeof(g_sSounds_Golf) - 1)],		weapon);
			case WEAPON_KATANA:		EmitSoundToAll(g_sSounds_Kat[		GetRandomInt(0, sizeof(g_sSounds_Kat) - 1)],		weapon);
			case WEAPON_KNIFE:		EmitSoundToAll(g_sSounds_Knife[		GetRandomInt(0, sizeof(g_sSounds_Knife) - 1)],		weapon);
			case WEAPON_MACHETE:	EmitSoundToAll(g_sSounds_Machete[	GetRandomInt(0, sizeof(g_sSounds_Machete) - 1)],	weapon);
			case WEAPON_TONFA:		EmitSoundToAll(g_sSounds_Tonfa[		GetRandomInt(0, sizeof(g_sSounds_Tonfa) - 1)],		weapon);
			case WEAPON_PITCHFORK:	EmitSoundToAll(g_sSounds_Pitch[		GetRandomInt(0, sizeof(g_sSounds_Pitch) - 1)],		weapon);
			case WEAPON_SHOVEL:		EmitSoundToAll(g_sSounds_Shovel[	GetRandomInt(0, sizeof(g_sSounds_Shovel) - 1)],		weapon);
			case WEAPON_SHIELD:		EmitSoundToAll(g_sSounds_Tonfa[		GetRandomInt(0, sizeof(g_sSounds_Tonfa) - 1)],		weapon);
			case WEAPON_GENERIC:	EmitSoundToAll(g_sSounds_Knife[		GetRandomInt(0, sizeof(g_sSounds_Knife) - 1)],		weapon);
		}
	}

	// Boomerang
	if( g_iCvarReturn )
	{
		// Vectors
		float vPos[3], vOrg[3], vDir[3];
		GetClientEyePosition(client, vPos);
		GetEntPropVector(weapon, Prop_Data, "m_vecAbsOrigin", vOrg);
		MakeVectorFromPoints(vOrg, vPos, vDir);

		NormalizeVector(vDir, vDir);
		ScaleVector(vDir, float(g_iCvarSpeed));

		vDir[2] += GetVectorDistance(vPos, vOrg);
		TeleportEntity(weapon, NULL_VECTOR, NULL_VECTOR, vDir);
		CreateTimer(0.1, TimerCheck, EntIndexToEntRef(weapon), TIMER_REPEAT);
		// g_fFlightTime[client] = GetGameTime();
	}
}

public Action TimerCheck(Handle timer, any weapon)
{
	// Valid and still moving
	weapon = EntRefToEntIndex(weapon);
	if( weapon != INVALID_ENT_REFERENCE && g_fLastPos[weapon][0] != 0.0 && g_fLastPos[weapon][1] != 0.0 && g_fLastPos[weapon][2] != 0.0)
	{
		// Valid owner
		int client = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
		// if( IsClientInGame(client) && IsPlayerAlive(client) && GetGameTime() - g_fFlightTime[client] < 2.0 )

		if( IsClientInGame(client) && IsPlayerAlive(client) && GetPlayerWeaponSlot(client, 1) == -1 )
		{
			// Near object
			float vPos[3], vDir[3];
			GetClientEyePosition(client, vPos);
			GetEntPropVector(weapon, Prop_Data, "m_vecAbsOrigin", vDir);

			if( GetVectorDistance(vPos, vDir) < 75.0 )
			{
				EquipPlayerWeapon(client, weapon);
				SDKUnhook(weapon, SDKHook_Touch, OnTouch);
				return Plugin_Stop;
			} else {
				return Plugin_Continue;
			}
		}
	}
	return Plugin_Stop;
}

void HurtEntity(int victim, int client, int type, float damage)
{
	int dmg;
	switch( type )
	{
		case WEAPON_CROWBAR:	dmg = DMG_SLASH;
		case WEAPON_FIREAXE:	dmg = DMG_SLASH;
		case WEAPON_KATANA:		dmg = DMG_SLASH;
		case WEAPON_KNIFE:		dmg = DMG_SLASH;
		case WEAPON_MACHETE:	dmg = DMG_SLASH;
		case WEAPON_TONFA:		dmg = DMG_CLUB|DMG_SLASH;
		case WEAPON_SHOVEL:		dmg = DMG_CLUB|DMG_SLASH;
		default:				dmg = DMG_CLUB;
	}

	SDKHooks_TakeDamage(victim, client, client, damage, dmg);
}