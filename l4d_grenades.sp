#define PLUGIN_VERSION 		"1.5"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Prototype Grenades
*	Author	:	SilverShot
*	Descrp	:	Creates a selection of different grenade types.
*	Link	:	http://forums.alliedmods.net/showthread.php?t=318965
*	Plugins	:	http://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.5 (17-Oct-2019)
	- Added 6 new types: Extinguisher, Glow, Anti-Gravity, Fire Cluster, Bullets and Flak.
	- Added command "sm_grenade" to open a menu for choosing the grenade type. Optional args to specify a type.
	- Added "mode_switch" in the config to control how to change grenade type. Menu and/or key combination.
	- Auto display and close menu with "mode_switch" when selecting a different type via key combination.
	- Changed L4D2 vocalizations from "throwing pipebomb" or "throwing molotov" etc to "throwing grenade" when not stock.
	- Changed grenade bounce impact sound.
	- Cleaned up the sounds by changing some and adding a few missing ones.
	- Feature to push and stumble Common Infected now works in L4D1.
	- Fixed wrong Deafen offset for L4D1 Linux. Fixes Flashbang.
	- Fixed wrong OnStaggered signature for Linux L4D1. Fixes staggering clients.
	- Fixed Freezer type not following the "targets" setting.
	- Fixed "damage_tick" to function for most types. Values smaller than "effect_tick" will use the effect tick time.
	- Thanks to "Dragokas" for the menu ideas and reporting problems in L4D1.

	- Required updated files:
	- Config: l4d_grenades.cfg
	- Gamedata: l4d_grenades.txt
	- Translations: grenades.phrases.txt.

1.4 (10-Oct-2019)
	- Added Russian translations. Thanks to "KRUTIK" for providing.
	- Fixed OnNextEquip errors. Thanks to "KRUTIK" for reporting.

1.3 (10-Oct-2019)
	- Added support for "Gear Transfer" plugin. For persistent grenade types when "preferences" is set to random grenade mode.
	- Changed Vaporizer to inflict full damage on Common instead of range scaled. Original functionality before 1.1.

1.2 (10-Oct-2019)
	- Fixed OnWeaponDrop errors. Thanks to "BlackSabbarh" for reporting.
	- Some optimizations.

1.1 (08-Oct-2019)
	- Added "bots" in the config to control if bots can use Prototype Grenades. Requires external plugin.
	- Added "damage_special", "damage_survivors", "damage_tank", "damage_witch" and "damage_physics" in the config to scale damage.
	- Added "preferences" in the config to save a players selected mode, or give a random grenade type. Persistent with dropping.
	- Added "targets" in the config to control who can be affected by the grenade effects.
	- Changed "nade" in the config to use bit flags, which allows all grenade modes to work for all grenades.
	- Fixed map transition breaking the ability to change grenade modes.
	- Fixed over-healing when a player has temp health.
	- Fixed sometimes detonating immediately after throwing.
	- Fixed sounds not stopping when reloading the plugin during an active grenade.
	- Updated data config, plugin requires new version, or effects will break: l4d_grenades.cfg.

1.0 (03-Oct-2019)
	- Initial release.

========================================================================================
	Thanks:

	This plugin was made using source code from the following plugins.
	If I have used your code and not credited you, please let me know.

*	Thanks to "Lux" for "L4D_TE_Create_Particle" - stock function.
	https://gist.github.com/LuxLuma/73a8fab2b5f44ef800070bfd5e7fe257

*	Thanks to "AtomicStryker" for "[L4D & L4D2] Smoker Cloud Damage" - Modified IsVisibleTo() function.
	http://forums.alliedmods.net/showthread.php?p=866613

*	"Zuko & McFlurry" for "[L4D2] Weapon/Zombie Spawner" - Modified SetTeleportEndPoint() function.
	http://forums.alliedmods.net/showthread.php?t=109659

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <clientprefs>
#include <sdktools>
#include <sdkhooks>
#include <l4d2_simple_combat>


//LMC
#undef REQUIRE_PLUGIN
#tryinclude <LMCCore>
#define REQUIRE_PLUGIN

#if !defined _LMCCore_included
	native int LMC_GetEntityOverlayModel(int iEntity);
#endif

bool	bLMC_Available;
//LMC



// DEFINES
#define CVAR_FLAGS				FCVAR_NOTIFY
#define CONFIG_DATA				"data/l4d_grenades.cfg"
#define GAMEDATA				"l4d_grenades"



// EFFECTS
#define MODEL_BOUNDING			"models/props/cs_militia/silo_01.mdl"
#define MODEL_CRATE				"models/props_junk/explosive_box001.mdl"
#define MODEL_GASCAN			"models/props_junk/gascan001a.mdl"
#define MODEL_SPRAYCAN			"models/props_junk/garbage_spraypaintcan01a.mdl"
#define MODEL_SPRITE			"models/sprites/glow01.spr"

#define PARTICLE_MUZZLE			"weapon_muzzle_flash_autoshotgun"
#define PARTICLE_TRACERS		"weapon_tracers"
#define PARTICLE_TRACER_50		"weapon_tracers_50cal"
#define PARTICLE_SMOKER1		"smoker_smokecloud_cheap"
#define PARTICLE_SMOKER2		"smoker_spore_trail"
#define PARTICLE_BOOMER			"boomer_explode_E"
#define PARTICLE_SMOKE2			"apc_wheel_smoke2" // White smoke
#define PARTICLE_BURST			"gas_explosion_initialburst" // Large explosion
#define PARTICLE_BLAST			"gas_explosion_initialburst_blast" // Large explosion HD
#define PARTICLE_BLAST2			"weapon_pipebomb_water_child_fire" // Cluster explosion
#define PARTICLE_MINIG			"weapon_muzzle_flash_minigun" // Constant white flashing glow
#define PARTICLE_STEAM			"steam_long" // Small water steam
#define PARTICLE_BLACK			"smoke_window" // Large black smoke
#define PARTICLE_SMOKER			"smoker_smokecloud" // Smoker cloud
#define PARTICLE_IMPACT			"impact_steam" // Long water impact, points in 1 direction
#define PARTICLE_VOMIT			"boomer_vomit"
#define PARTICLE_TRAIL			"water_trail_directional"
#define PARTICLE_SPLASH			"weapon_pipebomb_water_splash" // Large water splash
#define PARTICLE_PIPE1			"weapon_pipebomb" // Explosion
#define PARTICLE_PIPE2			"weapon_pipebomb_child_fire" // Medium blast
#define PARTICLE_PIPE3			"weapon_pipebomb_water_child_flash" // Flash
#define PARTICLE_SHORT			"impact_steam_short" // Medium water impact, points in 1 direction
#define PARTICLE_CHARGE			"charger_wall_impact_b"
#define PARTICLE_FLARE			"flare_burning"
#define PARTICLE_SPIT_T			"spitter_projectile_trail_old"
#define PARTICLE_SPIT_P			"spitter_projectile_explode"
#define PARTICLE_SMOKE			"apc_wheel_smoke1"
#define PARTICLE_DEFIB			"item_defibrillator_body"
#define PARTICLE_ELMOS			"st_elmos_fire_cp0"
#define PARTICLE_TES1			"electrical_arc_01"
#define PARTICLE_TES2			"electrical_arc_01_system"
#define PARTICLE_TES3			"st_elmos_fire"
#define PARTICLE_TES6			"impact_ricochet_sparks"
#define PARTICLE_TES7			"railroad_wheel_sparks"
#define PARTICLE_GSPARKS		"sparks_generic_random"
#define PARTICLE_SPARKS			"fireworks_sparkshower_01e"

#define SOUND_SHOOTING			"weapons/flash/flash01.wav"
#define SOUND_EXPLODE3			"weapons/hegrenade/explode3.wav"
#define SOUND_EXPLODE5			"weapons/hegrenade/explode5.wav"
#define SOUND_FIREWORK1			"ambient/atmosphere/firewerks_burst_01.wav"
#define SOUND_FIREWORK2			"ambient/atmosphere/firewerks_burst_02.wav"
#define SOUND_FIREWORK3			"ambient/atmosphere/firewerks_burst_03.wav"
#define SOUND_FIREWORK4			"ambient/atmosphere/firewerks_burst_04.wav"
#define SOUND_FREEZER			"physics/glass/glass_impact_bullet4.wav"
#define SOUND_BUTTON1			"buttons/blip2.wav"
#define SOUND_BUTTON2			"ui/menu_countdown.wav"
#define SOUND_FLICKER			"ambient/spacial_loops/lights_flicker.wav"
#define SOUND_GAS				"ambient/gas/cannister_loop.wav"
#define SOUND_GATE				"ambient/machines/floodgate_stop1.wav"
#define SOUND_NOISE				"ambient/atmosphere/noise2.wav"
#define SOUND_SPATIAL			"ambient/spacial_loops/computer_spatial_amb_loop.wav"
#define SOUND_SQUEAK			"ambient/random_amb_sfx/randommetalsqueak01.wav"
#define SOUND_STEAM				"ambient/gas/steam_loop1.wav"
#define SOUND_TUNNEL			"ambient/atmosphere/tunnel1.wav"
#define SOUND_SPLASH1			"ambient/water/water_splash1.wav"
#define SOUND_SPLASH2			"ambient/water/water_splash2.wav"
#define SOUND_SPLASH3			"ambient/water/water_splash3.wav"

#define SPRITE_BEAM				"materials/sprites/laserbeam.vmt"
#define SPRITE_HALO				"materials/sprites/glow01.vmt"
#define SPRITE_GLOW				"sprites/blueglow1.vmt"
// L4D2 client? is missing "sprites/blueglow1.vmt" - used by env_entity_dissolver.
// Precache prevents server's error message, and clients can attempt to precache before round_start to avoid any possible stutter on the first attempt live in-game
// Error messages:
// Client:		Unable to load sprite material materials/sprites/blueglow1.vmt!
// Server:		Late precache of sprites/blueglow1.vmt

static const char g_sSoundsHit[][]	=
{
	"physics/plastic/plastic_barrel_impact_soft1.wav",
	"physics/plastic/plastic_barrel_impact_soft2.wav",
	"physics/plastic/plastic_barrel_impact_soft3.wav",
	"physics/plastic/plastic_barrel_impact_soft4.wav",
	"physics/plastic/plastic_barrel_impact_soft5.wav",
	"physics/plastic/plastic_barrel_impact_soft6.wav"
};

static const char g_sSoundsMiss[][]	=
{
	"weapons/fx/nearmiss/bulletltor08.wav",
	"weapons/fx/nearmiss/bulletltor10.wav",
	"weapons/fx/nearmiss/bulletltor11.wav",
	"weapons/fx/nearmiss/bulletltor13.wav",
	"weapons/fx/nearmiss/bulletltor14.wav"
};

static const char g_sSoundsZap[][]	=
{
	"ambient/energy/zap1.wav",
	"ambient/energy/zap2.wav",
	"ambient/energy/zap3.wav",
	"ambient/energy/zap5.wav",
	"ambient/energy/zap6.wav",
	"ambient/energy/zap7.wav",
	"ambient/energy/zap8.wav",
	"ambient/energy/zap9.wav"
};

// Grenade vocalizations unused by default.
static const char g_sSoundsMissing[][]	=
{
	"player/survivor/voice/gambler/grenade10.wav",
	"player/survivor/voice/gambler/grenade12.wav"
};



// ARRAYS etc
#define MAX_ENTS			2048									// Max ents
#define MAX_DATA			16										// Total data entries to read from a grenades config.
#define MAX_TYPES			18										// Number of grenade types.
#define MAX_WAIT			0.2										// Delay between +USE mode changes.
#define BEAM_OFFSET			100.0									// Increase beam diameter by this value to correct visual size.
#define BEAM_RINGS			5										// Number of beam rings.
#define SHAKE_RANGE			150.0									// How far to increase the shake from the effect range.

float	g_fLastTesla[MAX_ENTS];										// Last time damage taken, used by Tesla mode.
float	g_fLastFreeze[MAXPLAYERS+1];								// Last time in the freezer area.
float	g_fLastShield[MAXPLAYERS+1];								// Last time in the shield, for damage hook.
float	g_fLastUse[MAXPLAYERS+1];									// Clients last time pressing +USE.
bool	g_bChangingTypesMenu[MAXPLAYERS+1];							// Store when clients are changing type, to close menu when ended.
int		g_iClientGrenadeType[MAXPLAYERS+1] = { -1, ... };			// The current mode a player has selected
int		g_iClientGrenadePref[MAXPLAYERS+1][3];						// Client cookie preferences - mode client last used for all grenades

float	g_GrenadeData[MAX_TYPES][MAX_DATA];							// Config data for all grenade modes.
int		g_GrenadeSlot[MAX_TYPES][2];								// [0]=L4D2, [1]=L4D1. Which grenade slot the grenade mode uses.
int		g_GrenadeTarg[MAX_TYPES];									// Who the grenade affects.
int		g_BeamSprite, g_HaloSprite;									// Beam Rings
int		g_iConfigBots;												// Can bots use Prototype Grenades
int		g_iConfigStock;												// Which grenades have their default feature.
int		g_iConfigTypes;												// Which grenade modes are allowed.
int		g_iConfigBinds;												// Menu or Pressing keys to change mode.
int		g_iConfigPrefs;												// Client preferences save/load mode or give random mode.
float	g_fConfigSurvivors;											// Survivors damage multiplier.
float	g_fConfigSpecial;											// Special Infected damage multiplier.
float	g_fConfigTank;												// Tank damage multiplier.
float	g_fConfigWitch;												// Witch damage multiplier.
float	g_fConfigPhysics;											// Physics props damage multiplier.
int		g_iEntityHurt;												// Hurt entity.
int		g_iParticleTracer;											// Particle index for TE.
int		g_iParticleTracer50;										// Particle index for TE.



// VARS
Handle sdkDissolveCreate, sdkActivateSpit, sdkStaggerClient, sdkDeafenClient;
ConVar g_hCvarAllow, g_hDecayDecay, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog;
bool g_bCvarAllow, g_bLeft4Dead2, g_bLateLoad, g_bHookFire, g_bBlockHook, g_bBlockSound;
Handle g_hCookie;

enum ()
{
	INDEX_BOMB = 0,
	INDEX_CLUSTER,
	INDEX_FIREWORK,
	INDEX_SMOKE,
	INDEX_BLACKHOLE,
	INDEX_FLASHBANG,
	INDEX_SHIELD,
	INDEX_TESLA,
	INDEX_CHEMICAL,
	INDEX_FREEZER,
	INDEX_MEDIC,
	INDEX_VAPORIZER,
	INDEX_EXTINGUISHER,
	INDEX_GLOW,
	INDEX_ANTIGRAVITY,
	INDEX_FIRECLUSTER,
	INDEX_BULLETS,
	INDEX_FLAK
}

enum ()
{
	CONFIG_ELASTICITY = 0,
	CONFIG_GRAVITY,
	CONFIG_DMG_PHYSICS,
	CONFIG_DMG_SPECIAL,
	CONFIG_DMG_SURVIVORS,
	CONFIG_DMG_TANK,
	CONFIG_DMG_WITCH,
	CONFIG_DAMAGE,
	CONFIG_DMG_TICK,
	CONFIG_FUSE,
	CONFIG_SHAKE,
	CONFIG_STICK,
	CONFIG_STUMBLE,
	CONFIG_RANGE,
	CONFIG_TICK,
	CONFIG_TIME
}

enum ()
{
	TARGET_COMMON = 0,
	TARGET_SURVIVOR,
	TARGET_SPECIAL,
	TARGET_TANK,
	TARGET_WITCH,
	TARGET_PHYSICS
}



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "原型手雷",
	author = "SilverShot",
	description = "Creates a selection of different grenade types.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=318965"
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

	MarkNativeAsOptional("LMC_GetEntityOverlayModel"); // LMC

	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	bLMC_Available = LibraryExists("LMCEDeathHandler");
}

public void OnLibraryAdded(const char[] sName)
{
	if(StrEqual(sName, "LMCEDeathHandler"))
		bLMC_Available = true;
}

public void OnLibraryRemoved(const char[] sName)
{
	if(StrEqual(sName, "LMCEDeathHandler"))
		bLMC_Available = false;
}

public void OnPluginStart()
{
	// ====================================================================================================
	// GAMEDATA
	// ====================================================================================================
	Handle hGamedata = LoadGameConfigFile(GAMEDATA);
	if( hGamedata == null ) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	// Deafen
	StartPrepSDKCall(SDKCall_Player);
	if( PrepSDKCall_SetFromConf(hGamedata, SDKConf_Virtual, "CTerrorPlayer::Deafen") == false )
		SetFailState("Failed to find signature: CTerrorPlayer::Deafen");
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	sdkDeafenClient = EndPrepSDKCall();
	if( sdkDeafenClient == INVALID_HANDLE )
		SetFailState("Failed to create SDKCall: CTerrorPlayer::Deafen");

	// Dissolve
	StartPrepSDKCall(SDKCall_Static);
	if( PrepSDKCall_SetFromConf(hGamedata, SDKConf_Signature, "CEntityDissolve_Create") == false )
		SetFailState("Could not load the \"CEntityDissolve_Create\" gamedata signature.");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	sdkDissolveCreate = EndPrepSDKCall();
	if( sdkDissolveCreate == null )
		SetFailState("Could not prep the \"CEntityDissolve_Create\" function.");

	// Stagger
	StartPrepSDKCall(SDKCall_Player);
	if( PrepSDKCall_SetFromConf(hGamedata, SDKConf_Signature, "CTerrorPlayer::OnStaggered") == false )
		SetFailState("Could not load the 'CTerrorPlayer::OnStaggered' gamedata signature.");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);
	sdkStaggerClient = EndPrepSDKCall();
	if( sdkStaggerClient == null )
		SetFailState("Could not prep the 'CTerrorPlayer::OnStaggered' function.");

	// Spitter Projectile
	if( g_bLeft4Dead2 )
	{
		StartPrepSDKCall(SDKCall_Static);
		if( PrepSDKCall_SetFromConf(hGamedata, SDKConf_Signature, "CSpitterProjectile_Create") == false )
			SetFailState("Could not load the \"CSpitterProjectile_Create\" gamedata signature.");
		PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
		PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
		PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
		PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
		PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
		PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
		sdkActivateSpit = EndPrepSDKCall();
		if( sdkActivateSpit == null )
			SetFailState("Could not prep the \"CSpitterProjectile_Create\" function.");
	}

	delete hGamedata;



	// ====================================================================================================
	// CVARS
	// ====================================================================================================
	g_hCvarAllow = CreateConVar(	"l4d_grenades_allow",			"1",					"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarModes = CreateConVar(	"l4d_grenades_modes",			"",						"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff = CreateConVar(	"l4d_grenades_modes_off",		"",						"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog = CreateConVar(	"l4d_grenades_modes_tog",		"0",					"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	CreateConVar(					"l4d_grenades_version",			PLUGIN_VERSION,			"Prototype Grenades plugin version.", CVAR_FLAGS|FCVAR_DONTRECORD);
	AutoExecConfig(true,			"l4d_grenades");

	g_hDecayDecay = FindConVar("pain_pills_decay_rate");
	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);



	// ====================================================================================================
	// COMMANDS
	// ====================================================================================================
	RegConsoleCmd("sm_grenade",			Cmd_Grenade, 	"Opens a menu to choose the current grenades mode. Force change with args, usage: sm_grenade [type: 1 - 18]");
	RegAdminCmd("sm_grenade_reload",	Cmd_Reload,		ADMFLAG_ROOT, "Reloads the settings config.");
	RegAdminCmd("sm_grenade_spawn",		Cmd_SpawnSpawn,	ADMFLAG_ROOT, "Spawn grenade explosions: <type: 1 - 18>");
	RegAdminCmd("sm_grenade_throw",		Cmd_SpawnThrow,	ADMFLAG_ROOT, "Spawn grenade projectile: <type: 1 - 18>");



	// ====================================================================================================
	// OTHER
	// ====================================================================================================	
	// Translations
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "translations/grenades.phrases.txt");
	if( !FileExists(sPath) )
		SetFailState("Required translation file is missing: 'translations/grenades.phrases.txt'");

	LoadTranslations("grenades.phrases");



	// Saved client options
	g_hCookie = RegClientCookie("l4d_grenades_modes", "Prototype Grenades - Modes", CookieAccess_Protected);



	// Late load
	if( g_bLateLoad )
	{
		LoadDataConfig();

		for( int i = 1; i <= MaxClients; i++ )
		if( IsClientInGame(i) )
		{
			// Hook WeaponEquip
			OnClientPutInServer(i);
			// Get cookies
			OnClientPostAdminCheck(i);
		}
	}
	
	CreateTimer(1.0, Timer_Register);
}

public void OnPluginEnd()
{
	ResetPlugin();
}

public Action Timer_Register(Handle timer, any unused)
{
	// 1=Bomb, 2=Cluster, 3=Firework, 4=Smoke, 5=Black Hole
	// 6=Flashbang, 7=Shield, 8=Tesla, 9=Chemical, 10=Freeze
	// 11=Medic, 12=Vaporizer, 13=Extinguisher, 14=Glow, 15=Anti-Gravity
	// 16=Fire Cluster, 17=Bullets, 18=Flak
	SC_CreateSpell("ss_pg_bomb", "高爆弹", 10, 200, "爆炸");
	SC_CreateSpell("ss_pg_cluster", "分裂弹", 10, 200, "散布多个小型炸弹");
	SC_CreateSpell("ss_pg_firework", "烟花弹", 10, 200, "烟花盒爆炸效果");
	SC_CreateSpell("ss_pg_smoke", "烟雾弹", 10, 200, "在范围内遮挡视线");
	SC_CreateSpell("ss_pg_hole", "引力弹", 10, 200, "将范围内的目标吸到中心");
	SC_CreateSpell("ss_pg_flashbang", "震撼弹", 10, 200, "令范围内的目标耳鸣");
	SC_CreateSpell("ss_pg_shield", "护卫弹", 10, 200, "在范围内的生还者伤害降低");
	SC_CreateSpell("ss_pg_tesla", "电击弹", 10, 200, "电击范围内的目标");
	SC_CreateSpell("ss_pg_chemical", "酸液弹", 10, 200, "创建一滩酸液腐蚀里面的目标");
	SC_CreateSpell("ss_pg_freeze", "冷冻弹", 10, 200, "冻结范围内的敌人");
	SC_CreateSpell("ss_pg_medic", "治疗弹", 10, 200, "在范围内恢复生命");
	SC_CreateSpell("ss_pg_vaporizer", "溶解弹", 10, 200, "溶解范围内的目标");
	SC_CreateSpell("ss_pg_extinguisher", "灭火弹", 10, 200, "扑灭范围内的火焰");
	SC_CreateSpell("ss_pg_glow", "标记弹", 10, 200, "给范围内的目标加上光圈");
	SC_CreateSpell("ss_pg_gravity", "抛射弹", 10, 200, "将范围内的目标抛起来");
	SC_CreateSpell("ss_pg_fire", "分裂燃烧弹", 10, 200, "散布多个小型燃烧弹");
	SC_CreateSpell("ss_pg_bullets", "破片弹", 10, 200, "散布多个破片以伤害范围内的目标");
	SC_CreateSpell("ss_pg_flask", "火花弹", 10, 200, "喷射火花点燃附近目标");
	return Plugin_Continue;
}

public void SC_OnUseSpellPost(int client, const char[] classname)
{
	char bombType[18][32] = {
		"ss_pg_bomb",
		"ss_pg_cluster",
		"ss_pg_firework",
		"ss_pg_smoke",
		"ss_pg_hole",
		"ss_pg_flashbang",
		"ss_pg_shield",
		"ss_pg_tesla",
		"ss_pg_chemical",
		"ss_pg_freeze",
		"ss_pg_medic",
		"ss_pg_vaporizer",
		"ss_pg_extinguisher",
		"ss_pg_glow",
		"ss_pg_gravity",
		"ss_pg_fire",
		"ss_pg_bullets",
		"ss_pg_flask"
	};
	
	for(int i = 0; i < 18; ++i)
	{
		if(StrEqual(classname, bombType[i]))
		{
			CreateGrenadeProjectile(client, i + 1, true);
			break;
		}
	}
}

// ====================================================================================================
//					CLIENT PREFS
// ====================================================================================================
public void OnClientPutInServer(int client)
{
	// SDKHook(client, SDKHook_WeaponEquip,	OnWeaponEquip);
	// SDKHook(client, SDKHook_WeaponDrop,		OnWeaponDrop);
}

public void OnClientPostAdminCheck(int client)
{
	if( g_iConfigPrefs != 1 )
		g_iClientGrenadeType[client] = -1;

	if( !IsFakeClient(client) )
	{
		// CreateTimer(0.2, tmrCookies, GetClientUserId(client));
	} else {
		SetCurrentNadePref(client); // Mostly for lateloads
	}
}

public Action tmrCookies(Handle timer, any client)
{
	client = GetClientOfUserId(client);
	if( client && IsClientInGame(client) )
	{
		// Get client cookies, set type if available or default.
		char sCookie[10];
		char sChars[3][3];
		GetClientCookie(client, g_hCookie, sCookie, sizeof(sCookie));

		if( strlen(sCookie) >= 5 )
		{
			ExplodeString(sCookie, ",", sChars, sizeof sChars, sizeof sChars[]);
		} else {
			sChars[0] = "0";
			sChars[1] = "0";
			sChars[2] = "0";
		}

		g_iClientGrenadePref[client][0] = StringToInt(sChars[0]);
		g_iClientGrenadePref[client][1] = StringToInt(sChars[1]);
		g_iClientGrenadePref[client][2] = StringToInt(sChars[2]);

		SetCurrentNadePref(client); // Mostly for lateloads
	}
}

void SetCurrentNadePref(int client)
{
	// Get current nade if applicable.
	if( IsPlayerAlive(client) )
	{
		int weapon = GetPlayerWeaponSlot(client, 2);
		if( weapon != -1 )
		{
			OnWeaponEquip(client, weapon);
		}
	}
}

void SetClientPrefs(int client)
{
	if( !IsFakeClient(client) )
	{
		char sCookie[10];
		Format(sCookie, sizeof sCookie, "%d,%d,%d", g_iClientGrenadePref[client][0], g_iClientGrenadePref[client][1], g_iClientGrenadePref[client][2]);
		SetClientCookie(client, g_hCookie, sCookie);
	}
}



// ====================================================================================================
//					COMMANDS
// ====================================================================================================
public Action Cmd_Reload(int client, int args)
{
	LoadDataConfig();
	PrintToChat(client, "\x04[\x05Grenade\x04] Reloaded config");
	return Plugin_Handled;
}

public Action Cmd_SpawnThrow(int client, int args)
{
	DoSpawnCommand(client, args, true);
	return Plugin_Handled;
}

public Action Cmd_SpawnSpawn(int client, int args)
{
	DoSpawnCommand(client, args, false);
	return Plugin_Handled;
}

void DoSpawnCommand(int client, int args, bool projectile)
{
	// Validate
	if( !client )
	{
		ReplyToCommand(client, "Command can only be used in game.");
		return;
	}

	if( args != 1 )
	{
		ReplyToCommand(client, "Usage: sm_grenade_%s <1=Bomb, 2=Cluster, 3=Firework, 4=Smoke, 5=Black Hole, 6=Flashbang, 7=Shield, 8=Tesla, 9=Chemical, 10=Freeze, 11=Medic, 12=Vaporizer, 13=Extinguisher, 14=Glow, 15=Anti-Gravity, 16=Fire Cluster, 17=Bullets, 18=Flak>", projectile ? "throw" : "spawn");
		return;
	}

	// Index
	char sTemp[4];
	GetCmdArg(1, sTemp, sizeof sTemp);
	int index = StringToInt(sTemp);

	if( index < 1 || index > MAX_TYPES )
	{
		ReplyToCommand(client, "Usage: sm_grenade_%s <1=Bomb, 2=Cluster, 3=Firework, 4=Smoke, 5=Black Hole, 6=Flashbang, 7=Shield, 8=Tesla, 9=Chemical, 10=Freeze, 11=Medic, 12=Vaporizer, 13=Extinguisher, 14=Glow, 15=Anti-Gravity, 16=Fire Cluster, 17=Bullets, 18=Flak>", projectile ? "throw" : "spawn");
		return;
	}

	// Create
	int entity = CreateGrenadeProjectile(client, index, projectile);
	if(entity != -1)
	{
		char translation[256];
		Format(translation, sizeof translation, "GrenadeMod_Title_%d", index);
		PrintToChat(client, "\x04[\x05Grenade\x04] \x05Created: \x04%T", translation, client);
	}
}

int CreateGrenadeProjectile(int client, int index, bool projectile)
{
	int entity = CreateEntityByName("pipe_bomb_projectile");
	if( entity != -1 )
	{
		SetEntityModel(entity, MODEL_SPRAYCAN);
		SetEntProp(entity, Prop_Data, "m_iHammerID", index);		// Store mode type
		SetEntPropEnt(entity, Prop_Send, "m_hThrower", client);		// Store owner
		SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);	// Store owner
		SetEntPropVector(entity, Prop_Send, "m_vInitialVelocity", view_as<float>({ 0.0, 0.0, 1.0 }));
		g_iClientGrenadeType[client] = index;

		float vPos[3];
		if( projectile )
		{
			float vAng[3];
			float vDir[3];
			GetClientEyePosition(client, vPos);
			GetClientEyeAngles(client, vAng);

			GetAngleVectors(vAng, vDir, NULL_VECTOR, NULL_VECTOR);
			vPos[0] += vDir[0] * 20;
			vPos[1] += vDir[1] * 20;
			vPos[2] += vDir[2] * 20;

			NormalizeVector(vDir, vDir);
			ScaleVector(vDir, 600.0);
			vDir[2] += 200.0;
			TeleportEntity(entity, vPos, NULL_VECTOR, vDir);
			SetEntPropVector(entity, Prop_Send, "m_vInitialVelocity", vDir);
		} else {
			SetTeleportEndPoint(client, vPos);
			vPos[2] += 20.0;
			TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
		}
		DispatchSpawn(entity);
	}
	return entity;
}

// ====================================================================================================
//					MENU
// ====================================================================================================
public Action Cmd_Grenade(int client, int args)
{
	if( !client )
	{
		ReplyToCommand(client, "Command can only be used in game.");
		return Plugin_Handled;
	}

	// If grenade mode not allowed to change
	if( g_iConfigPrefs == 3 )
	{
		return Plugin_Handled;
	}

	if( args == 0 )
	{
		ShowGrenadeMenu(client);
	} else {
		// Validate weapon
		int iWeapon = GetPlayerWeaponSlot(client, 2);
		if( iWeapon > MaxClients && IsValidEntity(iWeapon) )
		{
			int type = IsGrenade(iWeapon);
			if( type )
			{
				char temp[4];
				GetCmdArg(1, temp, sizeof temp);
				int index = StringToInt(temp);

				// Validate index
				if( index >= 0 && index <= MAX_TYPES )
				{
					g_iClientGrenadeType[client] = index - 1;
					GetGrenadeIndex(client, type); // Iterate to valid index.
					index = g_iClientGrenadeType[client];

					char translation[256];
					Format(translation, sizeof translation, "GrenadeMod_Title_%d", index);
					Format(translation, sizeof translation, "%T %T", "GrenadeMod_Mode", client, translation, client);
					ReplaceColors(translation, sizeof translation);
					PrintToChat(client, "%s", translation);
				}
			}
		}
	}

	return Plugin_Handled;
}

void ShowGrenadeMenu(int client)
{
	// Validate weapon
	int iWeapon = GetPlayerWeaponSlot(client, 2);
	if( iWeapon > MaxClients && IsValidEntity(iWeapon) )
	{
		int type = IsGrenade(iWeapon);
		if( type )
		{
			// Create menu
			Menu menu = new Menu(Menu_Grenade);
			char text[64];
			char temp[4];

			Format(text, sizeof(text), "%T", "GrenadeMenu_Title", client);
			menu.SetTitle(text);

			// Cycle through valid modes
			int selected;
			int count;
			int index;
			bool ins;

			for( int i = -1; i < MAX_TYPES; i++ )
			{
				ins = false;

				if( i == -1 )
				{
					index = 0;
					if( g_iConfigStock & (1<<(type - 1)) )
					{
						ins = true;
					}
				} else {
					if( g_GrenadeSlot[i][!g_bLeft4Dead2] & (1<<type - 1) && g_iConfigTypes & (1<<i) )
					{
						ins = true;
						index = i + 1;
					}
				}

				// Add to menu
				if( ins )
				{
					if( index == g_iClientGrenadeType[client] )
						selected = count;
					count++;

					IntToString(index, temp, sizeof temp);
					Format(text, sizeof text, "GrenadeMod_Title_%d", index);
					Format(text, sizeof text, "%s%T", index == g_iClientGrenadeType[client] ? "(*) " : "", text, client); // Mark selected
					menu.AddItem(temp, text);
				}
			}

			// Display
			menu.ExitButton = true;
			menu.DisplayAt(client, 7 * RoundToFloor(selected / 7.0), 30); // Display on selected page
			return;
		}
	}

	char translation[256];
	Format(translation, sizeof translation, "%T", "GrenadeMenu_Invalid", client);
	ReplaceColors(translation, sizeof translation);
	PrintToChat(client, translation);
}

public int Menu_Grenade(Menu menu, MenuAction action, int client, int index)
{
	switch( action )
	{
		case MenuAction_Select:
		{
			// Validate weapon
			int iWeapon = GetPlayerWeaponSlot(client, 2);
			if( iWeapon > MaxClients && IsValidEntity(iWeapon) )
			{
				int type = IsGrenade(iWeapon);
				if( type )
				{
					// Get index
					char sTemp[4];
					menu.GetItem(index, sTemp, sizeof(sTemp));
					index = StringToInt(sTemp);

					// Validate index
					g_iClientGrenadeType[client] = index - 1; // Iterate to valid index.
					GetGrenadeIndex(client, type);
					index = g_iClientGrenadeType[client];
					SetEntProp(iWeapon, Prop_Data, "m_iHammerID", index + 1);

					// Print
					char translation[256];
					Format(translation, sizeof translation, "GrenadeMod_Title_%d", index);
					Format(translation, sizeof translation, "%T %T", "GrenadeMod_Mode", client, translation, client);
					ReplaceColors(translation, sizeof translation);
					PrintToChat(client, "%s", translation);

					// Redisplay menu
					ShowGrenadeMenu(client);
				}
			} else {
				PrintToChat(client, "%T", "GrenadeMenu_Invalid", client);
			}
		}
		case MenuAction_End:
			delete menu;
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

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;

		AddNormalSoundHook(view_as<NormalSHook>(SoundHook));
		HookEvent("round_end",			Event_RoundEnd,			EventHookMode_PostNoCopy);
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		ResetPlugin();
		g_bCvarAllow = false;

		RemoveNormalSoundHook(view_as<NormalSHook>(SoundHook));
		UnhookEvent("round_end",		Event_RoundEnd,			EventHookMode_PostNoCopy);
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
//					MAP END / START
// ====================================================================================================
public void OnMapEnd()
{
	ResetPlugin();
}

public void OnMapStart()
{
	// PRECACHE
	PrecacheModel(MODEL_BOUNDING, true);
	PrecacheModel(MODEL_CRATE, true);
	PrecacheModel(MODEL_GASCAN, true);
	PrecacheModel(MODEL_SPRAYCAN, true);
	PrecacheModel(MODEL_SPRITE, true);
	PrecacheModel(SPRITE_GLOW, true);
	g_BeamSprite = PrecacheModel(SPRITE_BEAM);
	g_HaloSprite = PrecacheModel(SPRITE_HALO);

	if( g_bLeft4Dead2 )
		g_iParticleTracer50 = PrecacheParticle(PARTICLE_TRACER_50);
	g_iParticleTracer = PrecacheParticle(PARTICLE_TRACERS);
	PrecacheParticle(PARTICLE_MUZZLE);
	PrecacheParticle(PARTICLE_SMOKER1);
	PrecacheParticle(PARTICLE_SMOKER2);
	PrecacheParticle(PARTICLE_BOOMER);
	PrecacheParticle(PARTICLE_SMOKE2);
	PrecacheParticle(PARTICLE_BURST);
	PrecacheParticle(PARTICLE_BLAST);
	PrecacheParticle(PARTICLE_BLAST2);
	PrecacheParticle(PARTICLE_MINIG);
	PrecacheParticle(PARTICLE_STEAM);
	PrecacheParticle(PARTICLE_BLACK);
	PrecacheParticle(PARTICLE_SMOKER);
	PrecacheParticle(PARTICLE_IMPACT);
	PrecacheParticle(PARTICLE_VOMIT);
	PrecacheParticle(PARTICLE_SPLASH);
	PrecacheParticle(PARTICLE_PIPE1);
	PrecacheParticle(PARTICLE_PIPE2);
	PrecacheParticle(PARTICLE_PIPE3);
	PrecacheParticle(PARTICLE_SMOKE);
	PrecacheParticle(PARTICLE_TES1);
	PrecacheParticle(PARTICLE_TES2);
	PrecacheParticle(PARTICLE_TES3);
	PrecacheParticle(PARTICLE_TES6);
	PrecacheParticle(PARTICLE_TES7);
	PrecacheParticle(PARTICLE_ELMOS);

	if( g_bLeft4Dead2 )
	{
		PrecacheParticle(PARTICLE_SPARKS);
		PrecacheParticle(PARTICLE_GSPARKS);
		PrecacheParticle(PARTICLE_FLARE);
		PrecacheParticle(PARTICLE_SPIT_T);
		PrecacheParticle(PARTICLE_SPIT_P);
		PrecacheParticle(PARTICLE_DEFIB);

		PrecacheSound(SOUND_FIREWORK1, true);
		PrecacheSound(SOUND_FIREWORK2, true);
		PrecacheSound(SOUND_FIREWORK3, true);
		PrecacheSound(SOUND_FIREWORK4, true);
	}

	PrecacheSound(SOUND_SHOOTING, true);
	PrecacheSound(SOUND_EXPLODE3, true);
	PrecacheSound(SOUND_EXPLODE5, true);
	PrecacheSound(SOUND_FREEZER, true);
	PrecacheSound(SOUND_BUTTON1, true);
	PrecacheSound(SOUND_BUTTON2, true);
	PrecacheSound(SOUND_FLICKER, true);
	PrecacheSound(SOUND_GAS, true);
	PrecacheSound(SOUND_GATE, true);
	PrecacheSound(SOUND_NOISE, true);
	PrecacheSound(SOUND_SPATIAL, true);
	PrecacheSound(SOUND_SQUEAK, true);
	PrecacheSound(SOUND_STEAM, true);
	PrecacheSound(SOUND_TUNNEL, true);
	PrecacheSound(SOUND_SPLASH1, true);
	PrecacheSound(SOUND_SPLASH2, true);
	PrecacheSound(SOUND_SPLASH3, true);

	for( int i = 0; i < sizeof g_sSoundsHit; i++ )			PrecacheSound(g_sSoundsHit[i], true);
	for( int i = 0; i < sizeof g_sSoundsMiss; i++ )			PrecacheSound(g_sSoundsMiss[i], true);
	for( int i = 0; i < sizeof g_sSoundsZap; i++ )			PrecacheSound(g_sSoundsZap[i], true);
	for( int i = 0; i < sizeof g_sSoundsMissing; i++ )		PrecacheSound(g_sSoundsMissing[i], true);



	// LOAD CONFIG
	if( g_bLateLoad )
	{
		g_bLateLoad = false; // No double load from lateload
	} else {
		LoadDataConfig();
	}
}



// ====================================================================================================
//					CONFIG
// ====================================================================================================
void LoadDataEntry(int index, KeyValues hFile, const char[] KeyName)
{
	if( hFile.JumpToKey(KeyName) )
	{
		g_GrenadeData[index][CONFIG_ELASTICITY]		=	hFile.GetFloat("elasticity",			0.4);
		g_GrenadeData[index][CONFIG_GRAVITY]		=	hFile.GetFloat("gravity",				1.0);

		g_GrenadeData[index][CONFIG_DMG_PHYSICS]	=	hFile.GetFloat("damage_physics",		1.0);
		g_GrenadeData[index][CONFIG_DMG_SPECIAL]	=	hFile.GetFloat("damage_special",		1.0);
		g_GrenadeData[index][CONFIG_DMG_SURVIVORS]	=	hFile.GetFloat("damage_survivors",		1.0);
		g_GrenadeData[index][CONFIG_DMG_TANK]		=	hFile.GetFloat("damage_tank",			1.0);
		g_GrenadeData[index][CONFIG_DMG_WITCH]		=	hFile.GetFloat("damage_witch",			1.0);
		g_GrenadeData[index][CONFIG_DAMAGE]			=	hFile.GetFloat("damage",				1.0);
		g_GrenadeData[index][CONFIG_DMG_TICK]		=	hFile.GetFloat("damage_tick",			1.0);

		g_GrenadeData[index][CONFIG_FUSE]			=	hFile.GetFloat("detonate_fuse",			0.0);
		g_GrenadeData[index][CONFIG_SHAKE]			=	hFile.GetFloat("detonate_shake",		0.0);
		g_GrenadeData[index][CONFIG_STICK]			=	hFile.GetFloat("detonate_stick",		0.0);
		g_GrenadeData[index][CONFIG_STUMBLE]		=	hFile.GetFloat("range_stumble",			0.0);
		g_GrenadeData[index][CONFIG_RANGE]			=	hFile.GetFloat("effect_range",			0.0);
		g_GrenadeData[index][CONFIG_TICK]			=	hFile.GetFloat("effect_tick",			0.0);
		g_GrenadeData[index][CONFIG_TIME]			=	hFile.GetFloat("effect_time",			0.0);
		g_GrenadeSlot[index][0]						=	hFile.GetNum("nade",					1);
		g_GrenadeSlot[index][1]						=	hFile.GetNum("nade_l4d1",				0);
		g_GrenadeTarg[index]						=	hFile.GetNum("targets",					31);
	}
	hFile.Rewind();
}

void LoadDataConfig()
{
	// Load Config
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "%s", CONFIG_DATA);
	if( !FileExists(sPath) )
	{
		SetFailState("Missing config '%s' please re-install.", CONFIG_DATA);
	}

	// Import
	KeyValues hFile = new KeyValues("Grenades");
	if( !hFile.ImportFromFile(sPath) )
	{
		delete hFile;
		SetFailState("Error reading config '%s' please re-install.", CONFIG_DATA);
	}

	// Read
	if( hFile.JumpToKey("Settings") )
	{
		g_iConfigBots =					hFile.GetNum("bots",				0);
		g_iConfigBots =					Clamp(g_iConfigBots, 				(1<<MAX_TYPES) - 1, 0);

		g_iConfigBinds =				hFile.GetNum("mode_switch",			3);
		g_iConfigBinds =				Clamp(g_iConfigBinds, 				4, 1);

		g_iConfigPrefs =				hFile.GetNum("preferences",			1);
		g_iConfigPrefs =				Clamp(g_iConfigPrefs, 				3, 1);

		g_fConfigSurvivors =			hFile.GetFloat("damage_survivors",	1.0);
		g_fConfigSurvivors =			Clamp(g_fConfigSurvivors, 			1000.0, 0.0);

		g_fConfigSpecial =				hFile.GetFloat("damage_special",	1.0);
		g_fConfigSpecial =				Clamp(g_fConfigSpecial, 			1000.0, 0.0);

		g_fConfigTank =					hFile.GetFloat("damage_tank",		1.0);
		g_fConfigTank =					Clamp(g_fConfigTank, 				1000.0, 0.0);

		g_fConfigWitch =				hFile.GetFloat("damage_witch",		1.0);
		g_fConfigWitch =				Clamp(g_fConfigWitch, 				1000.0, 0.0);

		g_fConfigPhysics =				hFile.GetFloat("damage_physics",	1.0);
		g_fConfigPhysics =				Clamp(g_fConfigPhysics, 			1000.0, 0.0);

		g_iConfigStock =				hFile.GetNum("stocks",				0);
		g_iConfigStock =				Clamp(g_iConfigStock, 				7,	0);

		g_iConfigTypes =				hFile.GetNum("types",				0);
		g_iConfigTypes =				Clamp(g_iConfigTypes, 				(1<<MAX_TYPES) - 1,	0);
		hFile.Rewind();
	}

	LoadDataEntry(INDEX_BOMB,			hFile,		"Mod_Bomb");
	LoadDataEntry(INDEX_CLUSTER,		hFile,		"Mod_Cluster");
	LoadDataEntry(INDEX_FIREWORK,		hFile,		"Mod_Firework");
	LoadDataEntry(INDEX_SMOKE,			hFile,		"Mod_Smoke");
	LoadDataEntry(INDEX_BLACKHOLE,		hFile,		"Mod_Black_Hole");
	LoadDataEntry(INDEX_FLASHBANG,		hFile,		"Mod_Flashbang");
	LoadDataEntry(INDEX_SHIELD,			hFile,		"Mod_Shield");
	LoadDataEntry(INDEX_TESLA,			hFile,		"Mod_Tesla");
	LoadDataEntry(INDEX_CHEMICAL,		hFile,		"Mod_Chemical");
	LoadDataEntry(INDEX_FREEZER,		hFile,		"Mod_Freezer");
	LoadDataEntry(INDEX_MEDIC,			hFile,		"Mod_Medic");
	LoadDataEntry(INDEX_VAPORIZER,		hFile,		"Mod_Vaporizer");
	LoadDataEntry(INDEX_EXTINGUISHER,	hFile,		"Mod_Extinguisher");
	LoadDataEntry(INDEX_GLOW,			hFile,		"Mod_Glow");
	LoadDataEntry(INDEX_ANTIGRAVITY,	hFile,		"Mod_Anti_Gravity");
	LoadDataEntry(INDEX_FIRECLUSTER,	hFile,		"Mod_Cluster_Fire");
	LoadDataEntry(INDEX_BULLETS,		hFile,		"Mod_Bullets");
	LoadDataEntry(INDEX_FLAK,			hFile,		"Mod_Flak");

	delete hFile;
}

any Clamp(any value, any max, any min = 0.0)
{
	if( value < min )
		value = min;
	else if( value > max )
		value = max;
	return value;
}



// ====================================================================================================
//					EVENTS - WEAPON EQUIP
// ====================================================================================================
public void OnWeaponEquip(int client, int weapon)
{
	RequestFrame(OnNextEquip, EntIndexToEntRef(weapon)); // Delayed by a frame to support Gear Transfer plugin setting the type.
}

public void OnNextEquip(int weapon)
{
	if( (weapon = EntRefToEntIndex(weapon)) == INVALID_ENT_REFERENCE ) return;

	int type = IsGrenade(weapon);
	if( type )
	{
		int client = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
		if( client == -1 || !IsClientInGame(client) ) return;

		// Random grenade prefs
		if( g_iConfigPrefs != 1 || g_iConfigBots && IsFakeClient(client) )
		{
			int index = GetEntProp(weapon, Prop_Data, "m_iHammerID"); // Was previously picked up / set type
			if( index > 0 )
			{
				g_iClientGrenadeType[client] = index - 1;
			} else {
				int types = g_iConfigBots && IsFakeClient(client) ? g_iConfigBots : g_iConfigTypes; // Allowed types for bots / players
				int min = MAX_TYPES;
				int max;
				int slot;

				// Cycle through modes
				for( int i = 0; i < MAX_TYPES; i++ )
				{
					if( g_GrenadeSlot[i][!g_bLeft4Dead2] & (1<<type - 1) && types & (1<<i) )
					{
						if( i < min )	min = i - 1;
						if( i > max)	max = i;
					}
				}

				slot = GetRandomInt(min, max);
				g_iClientGrenadeType[client] = slot == min ? -1 : slot;
				GetGrenadeIndex(client, type); // Iterate to valid index.
			}
		} else {
			g_iClientGrenadeType[client] = -1;
		}

		// Client prefs default
		if( g_iClientGrenadeType[client] == -1 )
		{
			g_iClientGrenadeType[client] = g_iClientGrenadePref[client][type - 1];

			if( g_iClientGrenadeType[client] == -1 )
			{
				ThrowError("OnWeaponEquip == -1. This should never happen.");
			}
		}

		SetEntProp(weapon, Prop_Data, "m_iHammerID", g_iClientGrenadeType[client] + 1); // Store type

		// Hints
		if( !IsFakeClient(client) )
		{
			char translation[256];
			Format(translation, sizeof translation, "GrenadeMod_Title_%d", g_iClientGrenadeType[client]);

			Format(translation, sizeof translation, "%T %T", "GrenadeMod_Mode", client, translation, client);
			ReplaceColors(translation, sizeof translation);
			PrintToChat(client, "%s", translation);

			// If grenade mode allowed to change
			if( g_iConfigPrefs != 3 )
			{
				if( g_iConfigBinds == 2 )
					Format(translation, sizeof translation, "%T", "GrenadeMod_Hint2", client);
				else
					Format(translation, sizeof translation, "%T", "GrenadeMod_Hint", client);

				ReplaceColors(translation, sizeof translation);
			}
		}
	}
}

public void OnWeaponDrop(int client, int weapon)
{
	// Random grenade prefs
	if( g_iConfigPrefs != 1 && weapon != -1 && IsValidEntity(weapon) )
	{
		// Validate weapon
		int type = IsGrenade(weapon);
		if( type )
		{
			SetEntProp(weapon, Prop_Data, "m_iHammerID", g_iClientGrenadeType[client] + 1);
		}
	}
}



// ====================================================================================================
//					SOUND HOOK
// ====================================================================================================
// From "boomerjar##.wav" filenames.
int g_iGambl_InvalidBile[]	=	{08, 10};
int g_iMecha_InvalidBile[]	=	{08, 09, 10, 14, 13};
int g_iProdu_InvalidBile[]	=	{05, 07, 08, 09};
// From "Grenade##.wav" filenames.
int g_iCoach_InvalidNade[]	=	{08, 09, 10, 11, 12};
int g_iGambl_InvalidNade[]	=	{02, 03, 05, 06, 07, 08, 09, 11, 13};
int g_iMecha_InvalidNade[]	=	{03, 04, 05, 06, 07, 08, 11, 12, 13};
int g_iProdu_InvalidNade[]	=	{02, 03, 04, 05};
// Valid alternatives
int g_iCoach_ValidSample[]	=	{01, 02, 03, 04, 05, 06, 07};
int g_iGambl_ValidSample[]	=	{01, 04, 10, 12};
int g_iMecha_ValidSample[]	=	{01, 02, 09, 10};
int g_iProdu_ValidSample[]	=	{01, 06, 07};

public Action SoundHook(int clients[64], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags)
{
	// Block molotov sound when throwing. Deleting the molotov straight away causes the sound to loop endlessly.
	if( g_bBlockSound )
	{
		if( strcmp(sample, "weapons/molotov/fire_loop_1.wav") == 0 )
		{
			volume = 0.0;
			return Plugin_Changed;
		}
	}



	// Replace Prototype Grenades bounce sound.
	// weapons/hegrenade/he_bounce-1.wav
	if( sample[0] == 'w' && sample[8] == 'h' && sample[18] == 'h' )
	{
		if( GetEntProp(entity, Prop_Data, "m_iHammerID") )
		{
			volume = 0.5;
			strcopy(sample, sizeof sample, g_sSoundsHit[GetRandomInt(0, sizeof g_sSoundsHit - 1)]);
			return Plugin_Changed;
		}
	}



	// L4D2 survivors only.
	// Change players saying "throwing molotov" or "throwing pipebomb" to "throwing grenade" when a Prototype Grenade mode is selected.

	// Info for anyone who reads:
	// Players can vocalize from other objects, eg an "info_target" entity (see Mic plugin) and not a client index.
	// No point doing excess classname checking etc to block the rare vocalizations through non-player entities.
	// For other serious vocalization plugins this should be considered. Eg replacing a characters voices with another.
	if( g_bLeft4Dead2 && entity > 0 && entity <= MaxClients && g_iClientGrenadeType[entity] )
	{
		// player/survivor/voice/
		if( sample[0] == 'p' && sample[7] == 's' && sample[16] == 'v' )
		{
			// Coach, Gambler, Mechanic, Producer
			int dot;
			int pos;
			int edit;
			switch( sample[22] )
			{
				case 'G': pos = 30;
				case 'M': pos = 31;
				case 'P': pos = 31;
			}



			// "Grenade##.wav"
			if( pos && sample[pos] == 'G' && sample[pos + 9] == '.' )
			{
				dot = 9;
				sample[pos + dot] = '\x0';
				int num = StringToInt(sample[pos + dot - 2]); // Get grenade vocalize sound number.
				sample[pos + dot] = '.';

				switch( sample[22] ) // Match invalid number.
				{
					case 'C': for( int i = 0; i < sizeof g_iCoach_InvalidNade; i++ ) if( num == g_iCoach_InvalidNade[i] ) { edit = g_iCoach_ValidSample[GetRandomInt(0, sizeof g_iCoach_ValidSample - 1)]; break; }
					case 'G': for( int i = 0; i < sizeof g_iGambl_InvalidNade; i++ ) if( num == g_iGambl_InvalidNade[i] ) { edit = g_iGambl_ValidSample[GetRandomInt(0, sizeof g_iGambl_ValidSample - 1)]; break; }
					case 'M': for( int i = 0; i < sizeof g_iMecha_InvalidNade; i++ ) if( num == g_iMecha_InvalidNade[i] ) { edit = g_iMecha_ValidSample[GetRandomInt(0, sizeof g_iMecha_ValidSample - 1)]; break; }
					case 'P': for( int i = 0; i < sizeof g_iProdu_InvalidNade; i++ ) if( num == g_iProdu_InvalidNade[i] ) { edit = g_iProdu_ValidSample[GetRandomInt(0, sizeof g_iProdu_ValidSample - 1)]; break; }
				}
			}



			// boomerjar##.wav
			else if( pos && sample[pos] == 'B' && sample[pos + 6] == 'J' && sample[22] != 'C' ) // Not Coach
			{
				dot = 11;
				sample[pos + dot] = '\x0';
				int num = StringToInt(sample[pos + dot - 2]); // Get grenade vocalize sound number.
				sample[pos + dot] = '.';

				switch( sample[22] ) // Match invalid number.
				{
					case 'G': for( int i = 0; i < sizeof g_iGambl_InvalidBile; i++ ) if( num == g_iGambl_InvalidBile[i] ) { edit = g_iGambl_ValidSample[GetRandomInt(0, sizeof g_iGambl_ValidSample - 1)]; break; }
					case 'M': for( int i = 0; i < sizeof g_iMecha_InvalidBile; i++ ) if( num == g_iMecha_InvalidBile[i] ) { edit = g_iMecha_ValidSample[GetRandomInt(0, sizeof g_iMecha_ValidSample - 1)]; break; }
					case 'P': for( int i = 0; i < sizeof g_iProdu_InvalidBile; i++ ) if( num == g_iProdu_InvalidBile[i] ) { edit = g_iProdu_ValidSample[GetRandomInt(0, sizeof g_iProdu_ValidSample - 1)]; break; }
				}

				if( edit ) // Replace name
				{
					sample[pos] = '\x0';
					StrCat(sample, sizeof sample, "Grenade##.wav");
				}
			}

			if( edit ) // Replace invalid number with valid number
			{
				char val[3];
				Format(val, sizeof val, "%02d", edit);
				sample[pos + 7] = val[0];
				sample[pos + 8] = val[1];
				return Plugin_Changed;
			}
		}
	}

	return Plugin_Continue;
}



// ====================================================================================================
//					RESET PLUGIN
// ====================================================================================================
public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	ResetPlugin();
}

void ResetPlugin()
{
	for( int i = 1; i <= MaxClients; i++ )
	{
		g_bChangingTypesMenu[i] = false;
		g_fLastFreeze[i] = 0.0;
		g_fLastShield[i] = 0.0;
		g_fLastUse[i] = 0.0;
		SDKUnhook(i, SDKHook_OnTakeDamageAlive, OnShield);
	}

	int entity = -1;
	while( (entity = FindEntityByClassname(entity, "pipe_bomb_projectile")) != INVALID_ENT_REFERENCE )
	{
		StopSounds(entity);
	}

	if( g_iEntityHurt && EntRefToEntIndex(g_iEntityHurt) != INVALID_ENT_REFERENCE )
	{
		AcceptEntityInput(g_iEntityHurt, "Kill");
	}
}



// ====================================================================================================
//					CHANGE MODE
// ====================================================================================================
/*
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	// Preferences allow to change grenade type, holding Shoot and pressing Shove
	if( g_iConfigPrefs != 3 )
	{
		if( buttons & IN_ATTACK )
		{
			if( buttons & IN_ATTACK2  )
			{
				// Check only a few times per second
				if( GetGameTime() - g_fLastUse[client] > MAX_WAIT )
				{
					g_fLastUse[client] = GetGameTime();

					// Validate weapon
					int iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
					if( iWeapon > MaxClients && IsValidEntity(iWeapon) )
					{
						int type = IsGrenade(iWeapon);
						if( type )
						{
							// Cycle through modes
							int index = GetGrenadeIndex(client, type);
							SetEntProp(iWeapon, Prop_Data, "m_iHammerID", index + 1);

							char translation[256];
							Format(translation, sizeof translation, "GrenadeMod_Title_%d", index);
							Format(translation, sizeof translation, "%T %T", "GrenadeMod_Mode", client, translation, client);
							ReplaceColors(translation, sizeof translation);
							PrintToChat(client, "%s", translation);

							if( g_iConfigBinds == 4 )
							{
								g_bChangingTypesMenu[client] = true;
								ShowGrenadeMenu(client);
							}
						}
					}
				}
			}
		}
		else if( g_bChangingTypesMenu[client] )
		{
			g_bChangingTypesMenu[client] = false;

			if( GetClientMenu(client, INVALID_HANDLE) != MenuSource_None )
			{
				InternalShowMenu(client, "\10", 1); // thanks to Zira
				CancelClientMenu(client, true, INVALID_HANDLE);
			}
		}
	}
}
*/

int GetGrenadeIndex(int client, int type)
{
	int index = g_iClientGrenadeType[client];

	if( index == -1 )
		index = 0;
	else
		index++;

	// Default to stock
	if( index == 0 || index > MAX_TYPES )
	{
		if( g_iConfigStock & (1<<(type - 1)) )
			index = 0;
		else
			index = 1;
	}

	// If modded
	if( index > 0 )
	{
		int types = g_iConfigBots && IsFakeClient(client) ? g_iConfigBots : g_iConfigTypes; // Allowed types for bots / players

		// Loop next
		for( int i = index - 1; i < MAX_TYPES; i++ )
		{
			if( g_GrenadeSlot[i][!g_bLeft4Dead2] & (1<<type - 1) && types & (1<<i) )
			{
				index = i + 1;
				break;
			}
			else if( i == MAX_TYPES - 1 )
			{
				// Allow stock
				if( g_iConfigStock & (1<<(type - 1)) )
				{
					index = 0;
				}
				else
				{
					// Loop from 0
					for( int x = 0; x < MAX_TYPES; x++ )
					{
						if( g_GrenadeSlot[i][!g_bLeft4Dead2] & (1<<type - 1) && types & (1<<x) )
						{
							index = x + 1;
							break;
						}
					}
				}
			}
		}
	}

	g_iClientGrenadeType[client] = index;
	g_iClientGrenadePref[client][type - 1] = index;
	SetClientPrefs(client);
	return index;
}



// ====================================================================================================
//					PROJECTILE THROWN
// ====================================================================================================
// Listen for thrown grenades to hook and replace.
public void OnEntityCreated(int entity, const char[] classname)
{
	if( g_bCvarAllow )
	{
		if( !g_bBlockHook )
		{
			if(
				classname[0] == 'm' ||
				classname[0] == 'p' ||
				classname[0] == 'v'
			)
			{
				if(
					strcmp(classname, "molotov_projectile") == 0 ||
					strcmp(classname, "pipe_bomb_projectile") == 0 ||
					g_bLeft4Dead2 && strcmp(classname, "vomitjar_projectile") == 0
				)
				{
					SDKHook(entity, SDKHook_SpawnPost, SpawnPost);
					return;
				}
			}
		}

		if( g_bHookFire && strcmp(classname, "inferno") == 0 ) // Small fires
		{
			SDKHook(entity, SDKHook_ThinkPost, OnPostThink);
		}
	}
}

public void OnPostThink(int entity)
{
	SetEntProp(entity, Prop_Send, "m_fireXDelta", 1, 1, 0);
	SetEntProp(entity, Prop_Send, "m_fireCount", 1);
}

public void SpawnPost(int entity)
{
	// 1 frame later required to get velocity
	RequestFrame(OnNextFrame, EntIndexToEntRef(entity));

	// Stop molotov loop sound since it gets stuck.
	g_bBlockSound = true;
}

public void OnNextFrame(int entity)
{
	g_bBlockSound = false;

	// Validate entity
	if( EntRefToEntIndex(entity) == INVALID_ENT_REFERENCE || !IsValidEntity(entity) )
		return;

	// Get Client
	int client = GetEntPropEnt(entity, Prop_Data, "m_hThrower");
	if( client > 0 && client <= MaxClients && IsClientInGame(client) )
	{
		int index = g_iClientGrenadeType[client];
		if( index > 0 )
		{
			// Game bug: when "weapon_oxygentank" and "weapon_propanetank" explode they create a "pipe_bomb_projectile". This prevents those erroneous ents.
			float vTest[3];
			GetEntPropVector(entity, Prop_Send, "m_vInitialVelocity", vTest);
			if( vTest[0] == 0.0 && vTest[1] == 0.0 && vTest[2] == 0.0 )
				return;

			// Recreate projectile to deactivate it.
			entity = CreateProjectile(entity, client, index);
			if( entity == 0 )
				return;

			// Detonate / Stick on contact
			float detonate = g_GrenadeData[index - 1][CONFIG_FUSE];
			if( detonate == 0.0 )
				SDKHook(entity, SDKHook_Touch, OnTouch_Detonate);
			else
				CreateTimer(detonate, Timer_Detonate, EntIndexToEntRef(entity));

			// Create projectile effects
			DoPrjEffects(entity, index);
		}
	}
}



// ====================================================================================================
//					PROJECTILE EFFECTS - Create projectile effects
// ====================================================================================================
void DoPrjEffects(int entity, int index)
{
	switch( index - 1 )
	{
		case INDEX_BOMB:			PrjEffects_Bomb				(entity);
		case INDEX_CLUSTER:			PrjEffects_Cluster			(entity);
		case INDEX_FIREWORK:		PrjEffects_Firework			(entity);
		case INDEX_SMOKE:			PrjEffects_Smoke			(entity);
		case INDEX_BLACKHOLE:		PrjEffects_BlackHole		(entity);
		case INDEX_FLASHBANG:		PrjEffects_Flashbang		(entity);
		case INDEX_SHIELD:			PrjEffects_Shield			(entity);
		case INDEX_TESLA:			PrjEffects_Tesla			(entity);
		case INDEX_CHEMICAL:		PrjEffects_Chemical			(entity);
		case INDEX_FREEZER:			PrjEffects_Freezer			(entity);
		case INDEX_MEDIC:			PrjEffects_Medic			(entity);
		case INDEX_VAPORIZER:		PrjEffects_Vaporizer		(entity);
		case INDEX_EXTINGUISHER:	PrjEffects_Extinguisher		(entity);
		case INDEX_GLOW:			PrjEffects_Glow				(entity);
		case INDEX_ANTIGRAVITY:		PrjEffects_AntiGravity		(entity);
		case INDEX_FIRECLUSTER:		PrjEffects_FireCluster		(entity);
		case INDEX_BULLETS:			PrjEffects_Bullets			(entity);
		case INDEX_FLAK:			PrjEffects_Flak				(entity);
	}
}

void SetupPrjEffects(int entity, float vPos[3], const char[] color)
{
	// Grenade Pos
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vPos);

	// Sprite
	CreateEnvSprite(entity, color);

	// Steam
	float vAng[3];
	GetEntPropVector(entity, Prop_Data, "m_angRotation", vAng);
	MakeEnvSteam(entity, vPos, vAng, color);

	// Light
	int light = MakeLightDynamic(entity, vPos);
	SetVariantEntity(light);
	SetVariantString(color);
	AcceptEntityInput(light, "color");
	AcceptEntityInput(light, "TurnOn");
}

// ====================================================================================================
//					PRJ EFFECT - BOMB
// ====================================================================================================
void PrjEffects_Bomb(int entity)
{
	// Grenade Pos + Effects
	float vPos[3];
	SetupPrjEffects(entity, vPos, "255 0 0"); // Red

	// Particles
	DisplayParticle(entity,		PARTICLE_MINIG,			vPos, NULL_VECTOR);
	DisplayParticle(entity,		PARTICLE_FLARE,			vPos, NULL_VECTOR);
	if( g_bLeft4Dead2 )
	{
		DisplayParticle(entity,	PARTICLE_SPARKS,		vPos, NULL_VECTOR);
		DisplayParticle(entity,	PARTICLE_GSPARKS,		vPos, NULL_VECTOR, 0.2);
	}

	// Sound
	PlaySound(entity, SOUND_STEAM);
}

// ====================================================================================================
//					PRJ EFFECT - CLUSTER
// ====================================================================================================
void PrjEffects_Cluster(int entity)
{
	// Grenade Pos + Effects
	float vPos[3];
	SetupPrjEffects(entity, vPos, "255 255 0"); // Yellow

	// Particles
	DisplayParticle(entity,		PARTICLE_MINIG,		vPos, NULL_VECTOR);
	if( g_bLeft4Dead2 )
	{
		DisplayParticle(entity,	PARTICLE_SPARKS,	vPos, NULL_VECTOR);
		DisplayParticle(entity,	PARTICLE_GSPARKS,	vPos, NULL_VECTOR, 0.2);
	}

	// Sound
	PlaySound(entity, SOUND_STEAM);
}

// ====================================================================================================
//					PRJ EFFECT - FIREWORK
// ====================================================================================================
void PrjEffects_Firework(int entity)
{
	// Grenade Pos + Effects
	float vPos[3];
	SetupPrjEffects(entity, vPos, "255 150 0"); // Orange

	// Particles
	DisplayParticle(entity,		PARTICLE_MINIG,		vPos, NULL_VECTOR);
	DisplayParticle(entity,		PARTICLE_TES7,		vPos, NULL_VECTOR);
	if( g_bLeft4Dead2 )
	{
		DisplayParticle(entity,	PARTICLE_SPARKS,	vPos, NULL_VECTOR);
		DisplayParticle(entity, PARTICLE_GSPARKS,	vPos, NULL_VECTOR, 0.2);
	}
}

// ====================================================================================================
//					PRJ EFFECT - SMOKE
// ====================================================================================================
void PrjEffects_Smoke(int entity)
{
	// Grenade Pos + Effects
	float vPos[3];
	SetupPrjEffects(entity, vPos, "100 100 100"); // Grey

	// Particles
	if( g_bLeft4Dead2 )
		DisplayParticle(entity,	PARTICLE_SPARKS,	vPos, NULL_VECTOR);
	DisplayParticle(entity,		PARTICLE_SMOKE2,	vPos, NULL_VECTOR);
	DisplayParticle(entity,		PARTICLE_IMPACT,	vPos, NULL_VECTOR);
	DisplayParticle(entity,		PARTICLE_SMOKE,		vPos, NULL_VECTOR);

	// Sound
	PlaySound(entity, SOUND_GAS);
}

// ====================================================================================================
//					PRJ EFFECT - BLACK HOLE
// ====================================================================================================
void PrjEffects_BlackHole(int entity)
{
	// Grenade Pos + Effects
	float vPos[3];
	SetupPrjEffects(entity, vPos, "200 0 255"); // Purple

	// Particles
	if( g_bLeft4Dead2 )
		DisplayParticle(entity,	PARTICLE_DEFIB,		vPos, NULL_VECTOR, 0.5);

	// Sound
	PlaySound(entity, SOUND_SQUEAK);
	PlaySound(entity, SOUND_SPATIAL);
	PlaySound(entity, SOUND_FLICKER);
	PlaySound(entity, SOUND_TUNNEL);
	PlaySound(entity, SOUND_NOISE);
}

// ====================================================================================================
//					PRJ EFFECT - FLASHBANG
// ====================================================================================================
void PrjEffects_Flashbang(int entity)
{
	// Grenade Pos + Effects
	float vPos[3];
	SetupPrjEffects(entity, vPos, "255 255 255"); // White

	// Particles
	if( g_bLeft4Dead2 )
	{
		DisplayParticle(entity,	PARTICLE_SPARKS,	vPos, NULL_VECTOR);
		DisplayParticle(entity,	PARTICLE_GSPARKS,	vPos, NULL_VECTOR, 0.2);
	}

	// Sound
	PlaySound(entity, SOUND_BUTTON1);
}

// ====================================================================================================
//					PRJ EFFECT - SHIELD
// ====================================================================================================
void PrjEffects_Shield(int entity)
{
	// Grenade Pos + Effects
	float vPos[3];
	SetupPrjEffects(entity, vPos, "0 220 255"); // Light Blue

	// Particles
	if( g_bLeft4Dead2 )
		DisplayParticle(entity,	PARTICLE_DEFIB,		vPos, NULL_VECTOR);
	DisplayParticle(entity,		PARTICLE_ELMOS,		vPos, NULL_VECTOR);

	// Sound
	PlaySound(entity, SOUND_SPATIAL);
	PlaySound(entity, SOUND_TUNNEL);
	PlaySound(entity, SOUND_NOISE);
}

// ====================================================================================================
//					PRJ EFFECT - TESLA
// ====================================================================================================
void PrjEffects_Tesla(int entity)
{
	// Grenade Pos + Effects
	float vPos[3];
	SetupPrjEffects(entity, vPos, "0 50 155"); // Blue

	// Particles
	if( g_bLeft4Dead2 )
		DisplayParticle(entity,	PARTICLE_DEFIB,		vPos, NULL_VECTOR, 0.5);
	DisplayParticle(entity,		PARTICLE_ELMOS,		vPos, NULL_VECTOR, 0.5);

	// Sound
	PlaySound(entity, SOUND_SQUEAK);
	PlaySound(entity, SOUND_SPATIAL);
	PlaySound(entity, SOUND_FLICKER);
	PlaySound(entity, SOUND_TUNNEL);
}

// ====================================================================================================
//					PRJ EFFECT - CHEMICAL
// ====================================================================================================
void PrjEffects_Chemical(int entity)
{
	// Grenade Pos + Effects
	float vPos[3];
	SetupPrjEffects(entity, vPos, "150 255 0"); // Lime green

	// Particles
	if( g_bLeft4Dead2 )
		DisplayParticle(entity,	PARTICLE_SPIT_T,	vPos, NULL_VECTOR);
	DisplayParticle(entity,		PARTICLE_VOMIT,		vPos, NULL_VECTOR);

	// Sound
	PlaySound(entity, SOUND_GAS);
}

// ====================================================================================================
//					PRJ EFFECT - FREEZER
// ====================================================================================================
void PrjEffects_Freezer(int entity)
{
	// Grenade Pos + Effects
	float vPos[3];
	SetupPrjEffects(entity, vPos, "0 150 255"); // Light Blue

	// Particles
	DisplayParticle(entity, PARTICLE_STEAM,		vPos, NULL_VECTOR, 0.5);
	DisplayParticle(entity, PARTICLE_ELMOS,		vPos, NULL_VECTOR, 0.5);

	// Sound
	PlaySound(entity, SOUND_GAS);
	PlaySound(entity, SOUND_STEAM);
	PlaySound(entity, SOUND_NOISE);
}

// ====================================================================================================
//					PRJ EFFECT - MEDIC
// ====================================================================================================
void PrjEffects_Medic(int entity)
{
	// Grenade Pos + Effects
	float vPos[3];
	SetupPrjEffects(entity, vPos, "0 150 0"); // Green

	// Sound
	PlaySound(entity, SOUND_TUNNEL);
	PlaySound(entity, SOUND_NOISE);
	PlaySound(entity, SOUND_SQUEAK);
}

// ====================================================================================================
//					PRJ EFFECT - VAPORIZER
// ====================================================================================================
void PrjEffects_Vaporizer(int entity)
{
	// Grenade Pos + Effects
	float vPos[3];
	SetupPrjEffects(entity, vPos, "50 0 255"); // Purple

	// Particles
	if( g_bLeft4Dead2 )
		DisplayParticle(entity,	PARTICLE_DEFIB,		vPos, NULL_VECTOR, 0.5);
	DisplayParticle(entity,		PARTICLE_TES2,		vPos, NULL_VECTOR, 0.5);
	DisplayParticle(entity,		PARTICLE_ELMOS,		vPos, NULL_VECTOR, 0.5);

	// Sound
	PlaySound(entity, SOUND_SQUEAK);
	PlaySound(entity, SOUND_SPATIAL);
	PlaySound(entity, SOUND_FLICKER);
	PlaySound(entity, SOUND_TUNNEL);
}

// ====================================================================================================
//					PRJ EFFECT - EXTINGUISHER
// ====================================================================================================
void PrjEffects_Extinguisher(int entity)
{
	// Grenade Pos + Effects
	float vPos[3];
	SetupPrjEffects(entity, vPos, "0 50 255"); // Blue

	// Particles
	DisplayParticle(entity, PARTICLE_STEAM,		vPos, NULL_VECTOR, 0.5);
}

// ====================================================================================================
//					PRJ EFFECT - GLOW
// ====================================================================================================
void PrjEffects_Glow(int entity)
{
	// Grenade Pos + Effects
	float vPos[3];
	SetupPrjEffects(entity, vPos, "255 150 0"); // Yellow-ish

	// Particles
	DisplayParticle(entity, PARTICLE_STEAM,		vPos, NULL_VECTOR, 0.5);

	// Sound
	PlaySound(entity, SOUND_TUNNEL);
	PlaySound(entity, SOUND_SPATIAL);
}

// ====================================================================================================
//					PRJ EFFECT - ANTI-GRAVITY
// ====================================================================================================
void PrjEffects_AntiGravity(int entity)
{
	// Grenade Pos + Effects
	float vPos[3];
	SetupPrjEffects(entity, vPos, "0 255 100"); // Lime Green

	// Particles
	DisplayParticle(entity,		PARTICLE_ELMOS,		vPos, NULL_VECTOR, 0.5);

	// Sound
	PlaySound(entity, SOUND_TUNNEL);

	// Slow projectile
	CreateTimer(0.1, tmrSlowdown, EntIndexToEntRef(entity), TIMER_REPEAT);
}

public Action tmrSlowdown(Handle timer, any entity)
{
	if( (entity = EntRefToEntIndex(entity)) != INVALID_ENT_REFERENCE )
	{
		float vVel[3];
		GetEntPropVector(entity, Prop_Data, "m_vecAbsVelocity", vVel);
		float speed = GetVectorLength(vVel);

		ScaleVector(vVel, speed < 100 ? 0.6 : 0.9);
		TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, vVel);

		if( speed > 20 )
		{
			return Plugin_Continue;
		}

		SetEntityGravity(entity, -0.01);
	}
	return Plugin_Stop;
}

// ====================================================================================================
//					PRJ EFFECT - CLUSTER
// ====================================================================================================
void PrjEffects_FireCluster(int entity)
{
	// Grenade Pos + Effects
	float vPos[3];
	SetupPrjEffects(entity, vPos, "255 50 0"); // Orange

	// Particles
	DisplayParticle(entity,		PARTICLE_MINIG,		vPos, NULL_VECTOR);
	if( g_bLeft4Dead2 )
	{
		DisplayParticle(entity,	PARTICLE_SPARKS,	vPos, NULL_VECTOR);
		DisplayParticle(entity,	PARTICLE_GSPARKS,	vPos, NULL_VECTOR, 0.2);
	}

	// Sound
	PlaySound(entity, SOUND_STEAM);
}

// ====================================================================================================
//					PRJ EFFECT - BULLETS
// ====================================================================================================
void PrjEffects_Bullets(int entity)
{
	// Grenade Pos + Effects
	float vPos[3];
	SetupPrjEffects(entity, vPos, "255 100 0"); // Yellow orange

	// Particles
	DisplayParticle(entity,	PARTICLE_SPARKS,	vPos, NULL_VECTOR);
	DisplayParticle(entity,	PARTICLE_GSPARKS,	vPos, NULL_VECTOR, 0.2);

	// Sound
	PlaySound(entity, SOUND_STEAM);
}

// ====================================================================================================
//					PRJ EFFECT - FLAK
// ====================================================================================================
void PrjEffects_Flak(int entity)
{
	// Grenade Pos + Effects
	float vPos[3];
	SetupPrjEffects(entity, vPos, "255 100 100"); // Rose

	// Particles
	DisplayParticle(entity,	PARTICLE_SPARKS,	vPos, NULL_VECTOR);
	DisplayParticle(entity,	PARTICLE_GSPARKS,	vPos, NULL_VECTOR, 0.2);

	// Sound
	PlaySound(entity, SOUND_STEAM);
}



// ====================================================================================================
//					PROJECTILE EXPLODED
// ====================================================================================================
public Action Timer_Detonate(Handle timer, any entity)
{
	if( (entity = EntRefToEntIndex(entity)) != INVALID_ENT_REFERENCE )
	{
		Detonate_Grenade(entity);
	}
}

public void OnTouch_Detonate(int entity, int other)
{
	if( other > MaxClients )
	{
		char classname[12];
		GetEdictClassname(other, classname, sizeof classname);

		if(
			classname[0] == 't' &&
			classname[1] == 'r' &&
			classname[2] == 'i' &&
			classname[3] == 'g' &&
			classname[4] == 'g' &&
			classname[5] == 'e' &&
			classname[6] == 'r' &&
			classname[7] == '_'
		)
		{
			return;
		}
	}

	Detonate_Grenade(entity);
	SDKUnhook(entity, SDKHook_Touch, OnTouch_Detonate);
}

void Detonate_Grenade(int entity)
{
	// Validate client
	int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if( client > 0 && IsClientInGame(client) )
	{
		// Get index
		int index = GetEntProp(entity, Prop_Data, "m_iHammerID");
		float vPos[3];

		// Stick to surface
		if( g_GrenadeData[index - 1][CONFIG_STICK] )
		{
			GetEntPropVector(entity, Prop_Data, "m_vecAbsVelocity", vPos);
			if(
				vPos[0] > -1.0 && vPos[0] < 1.0 &&
				vPos[1] > -1.0 && vPos[1] < 1.0 &&
				vPos[2] > -1.0 && vPos[2] < 1.0
			)
			{
				SetEntPropVector(entity, Prop_Data, "m_vecAbsVelocity", view_as<float>({ 0.0, 0.0, 0.0 }));
				SetEntityMoveType(entity, MOVETYPE_NONE);
				SetEntProp(entity, Prop_Send, "m_nSolidType", 6);
			}
		}

		// Grenade Pos
		GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vPos);

		// Explosion start time
		SetEntPropFloat(entity, Prop_Send, "m_flCreateTime", GetGameTime());

		// Do explode
		Explode_Effects(client, entity, index, false);

		// Detonation duration
		float tick = g_GrenadeData[index - 1][CONFIG_TICK];
		if( tick != 0.0 )
		{
			CreateTimer(tick, Timer_Repeat_Explode, EntIndexToEntRef(entity), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		}

		// Stop env_steam
		char sTemp[64];
		Format(sTemp, sizeof sTemp, "OnUser4 silv_steam_%d:TurnOff::0.0:-1", entity);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		Format(sTemp, sizeof sTemp, "OnUser4 silv_steam_%d:Kill::2.0:-1", entity);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser4");
	}
}

public Action Timer_Repeat_Explode(Handle timer, any entity)
{
	if( (entity = EntRefToEntIndex(entity)) != INVALID_ENT_REFERENCE )
	{
		// Get index
		int index = GetEntProp(entity, Prop_Data, "m_iHammerID");

		// Validate client
		int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
		if( client > 0 && IsClientInGame(client) )
		{
			// Do explode
			Explode_Effects(client, entity, index);
		}

		// Check duration
		if( GetGameTime() - GetEntPropFloat(entity, Prop_Send, "m_flCreateTime") > g_GrenadeData[index - 1][CONFIG_TIME] )
		{
			InputKill(entity, 0.2);

			// Stop sounds
			StopSounds(entity);
			return Plugin_Stop;
		}

		return Plugin_Continue;
	}

	return Plugin_Stop;
}



// ====================================================================================================
//					EXPLOSION EFFECTS - Create explosion effects
// ====================================================================================================
void Explode_Effects(int client, int entity, int index, bool fromTimer = true)
{
	switch( index - 1 )
	{
		case INDEX_BOMB:			Explode_Bomb			(client, entity, index);
		case INDEX_CLUSTER:			Explode_Cluster			(client, entity, index, fromTimer);
		case INDEX_FIREWORK:		Explode_Firework		(client, entity, index, fromTimer);
		case INDEX_SMOKE:			Explode_Smoke			(client, entity, index, fromTimer);
		case INDEX_BLACKHOLE:		Explode_BlackHole		(client, entity, index, fromTimer);
		case INDEX_FLASHBANG:		Explode_Flashbang		(client, entity, index);
		case INDEX_SHIELD:			Explode_Shield			(client, entity, index, fromTimer);
		case INDEX_TESLA:			Explode_Tesla			(client, entity, index, fromTimer);
		case INDEX_CHEMICAL:		Explode_Chemical		(client, entity, index, fromTimer);
		case INDEX_FREEZER:			Explode_Freezer			(client, entity, index, fromTimer);
		case INDEX_MEDIC:			Explode_Medic			(client, entity, index);
		case INDEX_VAPORIZER:		Explode_Vaporizer		(client, entity, index, fromTimer);
		case INDEX_EXTINGUISHER:	Explode_Extinguisher	(client, entity, index);
		case INDEX_GLOW:			Explode_Glow			(client, entity, index);
		case INDEX_ANTIGRAVITY:		Explode_AntiGravity		(client, entity, index);
		case INDEX_FIRECLUSTER:		Explode_Cluster			(client, entity, index, fromTimer);
		case INDEX_BULLETS:			Explode_Bullets			(client, entity, index, fromTimer);
		case INDEX_FLAK:			Explode_Flak			(client, entity, index);
	}



	// Detonation duration - instant explode only
	float tick = g_GrenadeData[index - 1][CONFIG_TICK];
	float time = g_GrenadeData[index - 1][CONFIG_TIME];
	if( tick == 0.0 || time == 0.0 )
	{
		InputKill(entity, 0.2);

		// Stop sounds
		StopSounds(entity);
	}
	
	g_iClientGrenadeType[client] = -1;
}



// ====================================================================================================
//					EXPLOSION FX - BOMB
// ====================================================================================================
public void Explode_Bomb(int client, int entity, int index)
{
	// Grenade Pos
	float vPos[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vPos);

	// Explosion
	CreateExplosion(client, entity, index, 0.0, vPos, DMG_BLAST);

	// Shake
	CreateShake(g_GrenadeData[index - 1][CONFIG_SHAKE], g_GrenadeData[index - 1][CONFIG_RANGE] + SHAKE_RANGE, vPos);

	// Particles
	if( g_bLeft4Dead2 )
		DisplayParticle(entity,		PARTICLE_CHARGE,	vPos, NULL_VECTOR);
	DisplayParticle(entity,			PARTICLE_BURST,		vPos, NULL_VECTOR);
	DisplayParticle(entity,			PARTICLE_PIPE1,		vPos, NULL_VECTOR);

	// Sound
	if( g_bLeft4Dead2 )
	{
		int random = GetRandomInt(1, 4);
		switch( random )
		{
			case 1: PlaySound(entity, SOUND_FIREWORK1);
			case 2: PlaySound(entity, SOUND_FIREWORK2);
			case 3: PlaySound(entity, SOUND_FIREWORK3);
			case 4: PlaySound(entity, SOUND_FIREWORK4);
		}
	} else {
		if( GetRandomInt(0, 1) ) PlaySound(entity, SOUND_EXPLODE3);
		else PlaySound(entity, SOUND_EXPLODE5);
	}
}

// ====================================================================================================
//					EXPLOSION FX - CLUSTER
// ====================================================================================================
public void Explode_Cluster(int client, int entity, int index, bool fromTimer)
{
	// Grenade Pos
	float vPos[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vPos);

	if( fromTimer == false )
	{
		// Explosion
		CreateExplosion(client, entity, index, 0.0, vPos, DMG_BLAST);

		// Shake
		CreateShake(g_GrenadeData[index - 1][CONFIG_SHAKE], g_GrenadeData[index - 1][CONFIG_RANGE] + SHAKE_RANGE, vPos);
	}

	// Particles
	DisplayParticle(entity, PARTICLE_BLAST,			vPos, NULL_VECTOR);
	DisplayParticle(entity, PARTICLE_BLAST2,		vPos, NULL_VECTOR);
	DisplayParticle(entity, PARTICLE_PIPE2,			vPos, NULL_VECTOR);

	// Sound
	if( g_bLeft4Dead2 )
	{
		int random = GetRandomInt(1, 4);
		switch( random )
		{
			case 1: PlaySound(entity, SOUND_FIREWORK1);
			case 2: PlaySound(entity, SOUND_FIREWORK2);
			case 3: PlaySound(entity, SOUND_FIREWORK3);
			case 4: PlaySound(entity, SOUND_FIREWORK4);
		}
	} else {
		if( GetRandomInt(0, 1) ) PlaySound(entity, SOUND_EXPLODE3);
		else PlaySound(entity, SOUND_EXPLODE5);
	}

	// Projectiles
	int max = 3;
	int particle;
	vPos[2] += 10.0;

	if( index - 1 == INDEX_FIRECLUSTER ) max = 1;

	for( int i = 0; i < max; i++ )
	{
		// Create new projectile
		g_bBlockHook = true;
		entity = CreateEntityByName("pipe_bomb_projectile");
		g_bBlockHook = false;

		if( entity != -1 )
		{
			// Fire and forget - cluster projectiles
			InputKill(entity, 3.0);

			SetEntProp(entity, Prop_Data, "m_iHammerID", index);		// Store mode type
			SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client); // Store owner

			// Set origin and velocity
			float vVel[3];
			if( index - 1 == INDEX_FIRECLUSTER )
			{
				vVel[0] = GetRandomFloat(-g_GrenadeData[index - 1][CONFIG_RANGE], g_GrenadeData[index - 1][CONFIG_RANGE] / 2);
				vVel[1] = GetRandomFloat(-g_GrenadeData[index - 1][CONFIG_RANGE], g_GrenadeData[index - 1][CONFIG_RANGE] / 2);
				vVel[2] = GetRandomFloat(270.0, g_GrenadeData[index - 1][CONFIG_RANGE]);
			} else {
				vVel[0] = GetRandomFloat(-g_GrenadeData[index - 1][CONFIG_RANGE], g_GrenadeData[index - 1][CONFIG_RANGE]);
				vVel[1] = GetRandomFloat(-g_GrenadeData[index - 1][CONFIG_RANGE], g_GrenadeData[index - 1][CONFIG_RANGE]);
				vVel[2] = GetRandomFloat(270.0, g_GrenadeData[index - 1][CONFIG_RANGE] / 2);
			}

			TeleportEntity(entity, vPos, NULL_VECTOR, vVel);
			DispatchSpawn(entity);
			SetEntityModel(entity, MODEL_SPRAYCAN); // Model after Dispatch otherwise the projectile effects (flashing light + trail) show.
			SetEntityRenderMode(entity, RENDER_NONE);

			// Particles
			particle = DisplayParticle(entity,		PARTICLE_MINIG,		vPos, NULL_VECTOR);
			InputKill(particle, 3.0);

			if( g_bLeft4Dead2 )
			{
				particle = DisplayParticle(entity,	PARTICLE_SPARKS,	vPos, NULL_VECTOR);
				InputKill(particle, 3.0);

				particle = DisplayParticle(entity,	PARTICLE_GSPARKS,	vPos, NULL_VECTOR, 0.2);
				InputKill(particle, 3.0);
			}

			SDKHook(entity, SDKHook_Touch, OnTouchTrigger_Cluster);
		}
	}
}

public void OnTouchTrigger_Cluster(int entity, int target)
{
	char classname[12];
	GetEdictClassname(target, classname, sizeof classname);

	if(
		classname[0] == 't' &&
		classname[1] == 'r' &&
		classname[2] == 'i' &&
		classname[3] == 'g' &&
		classname[4] == 'g' &&
		classname[5] == 'e' &&
		classname[6] == 'r' &&
		classname[7] == '_'
	)
	{
		return;
	}

	float vPos[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vPos);
	DisplayParticle(entity, PARTICLE_BLAST2,		vPos, NULL_VECTOR);
	DisplayParticle(entity, PARTICLE_PIPE2,			vPos, NULL_VECTOR);

	InputKill(entity, 0.1);

	// Hurt enemies
	int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	int index = GetEntProp(entity, Prop_Data, "m_iHammerID");

	if( index - 1 == INDEX_CLUSTER )
		CreateExplosion(client, entity, INDEX_CLUSTER + 1, 200.0, vPos, DMG_BLAST);
	else
	{
		if( g_bLeft4Dead2 ) // Property "m_fireXDelta" does not exist in L4D1. TODO: Make compatible alternative effect.
			g_bHookFire = true;
		CreateFires(entity, client, true);
		g_bHookFire = false;
	}

	// Shake
	CreateShake(g_GrenadeData[index - 1][CONFIG_SHAKE] / 2, 200.0, vPos);
}

// ====================================================================================================
//					EXPLOSION FX - FIREWORK
// ====================================================================================================
public void Explode_Firework(int client, int entity, int index, bool fromTimer)
{
	// Only want to trigger effects on initial detonation. Timers will fire past the effect life time when deleting, sometimes wanted in other modes.
	if( fromTimer == false )
	{
		// Grenade Pos
		float vPos[3];
		GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vPos);

		// Explosion
		CreateExplosion(client, entity, index, 0.0, vPos, DMG_BURN);

		// Shake
		CreateShake(g_GrenadeData[index - 1][CONFIG_SHAKE], g_GrenadeData[index - 1][CONFIG_RANGE] + SHAKE_RANGE, vPos);

		// Particles
		DisplayParticle(entity, PARTICLE_BLAST,			vPos, NULL_VECTOR);
		DisplayParticle(entity, PARTICLE_BLAST2,		vPos, NULL_VECTOR);
		DisplayParticle(entity, PARTICLE_PIPE2,			vPos, NULL_VECTOR);

		// Sound
		if( GetRandomInt(0, 1) ) PlaySound(entity, SOUND_EXPLODE3);
		else PlaySound(entity, SOUND_EXPLODE5);

		// Fire
		CreateFires(entity, client, !g_bLeft4Dead2);

		// Fire Particles
		if( g_bLeft4Dead2 == false )
		{
			DisplayParticle(entity,		PARTICLE_TES6,			vPos, NULL_VECTOR);
			DisplayParticle(entity,		PARTICLE_TES7,			vPos, NULL_VECTOR);
		} else {
			DisplayParticle(entity,		PARTICLE_GSPARKS,		vPos, NULL_VECTOR);
		}
	}
}

// ====================================================================================================
//					EXPLOSION FX - SMOKE
// ====================================================================================================
public void Explode_Smoke(int client, int entity, int index, bool fromTimer)
{
	// Grenade Pos
	float vPos[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vPos);

	if( fromTimer == false )
	{
		// Explosion
		CreateExplosion(client, entity, index, 0.0, vPos, DMG_NERVEGAS);

		// Shake
		CreateShake(g_GrenadeData[index - 1][CONFIG_SHAKE], g_GrenadeData[index - 1][CONFIG_RANGE] + SHAKE_RANGE, vPos);
	}

	// Particles
	DisplayParticle(entity, PARTICLE_BLACK,			vPos, NULL_VECTOR);
	DisplayParticle(entity, PARTICLE_SMOKER,		vPos, NULL_VECTOR);
}

// ====================================================================================================
//					EXPLOSION FX - BLACK HOLE
// ====================================================================================================
public void Explode_BlackHole(int client, int entity, int index, bool fromTimer)
{
	// Grenade Pos
	float vPos[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vPos);

	// Create Explosion
	CreateExplosion(client, entity, index, 0.0, vPos, DMG_GENERIC);

	if( fromTimer == false )
	{
		// Shake
		CreateShake(g_GrenadeData[index - 1][CONFIG_SHAKE], g_GrenadeData[index - 1][CONFIG_RANGE] + SHAKE_RANGE, vPos);

		// Particles
		if( g_bLeft4Dead2 )
			DisplayParticle(entity,		PARTICLE_CHARGE,	vPos, NULL_VECTOR);
		DisplayParticle(entity,			PARTICLE_TES2,		vPos, NULL_VECTOR, 1.0);
	}

	// Sound
	PlaySound(entity, g_sSoundsZap[GetRandomInt(0, sizeof g_sSoundsZap - 1)]);

	// Beam Ring
	float range = g_GrenadeData[index - 1][CONFIG_RANGE] * 2 + BEAM_OFFSET;
	CreateBeamRing(entity, { 255, 0, 255, 255 }, range - (range / BEAM_RINGS), 0.1);
}

// ====================================================================================================
//					EXPLOSION FX - FLASHBANG
// ====================================================================================================
public void Explode_Flashbang(int client, int entity, int index)
{
	// Grenade Pos
	float vPos[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vPos);

	// Explosion
	CreateExplosion(client, entity, index, 0.0, vPos, DMG_GENERIC);

	// Shake
	CreateShake(g_GrenadeData[index - 1][CONFIG_SHAKE], g_GrenadeData[index - 1][CONFIG_RANGE] + SHAKE_RANGE, vPos);

	// Particles
	int ent;
	if( g_bLeft4Dead2 )
	{
		ent = DisplayParticle(0,	PARTICLE_CHARGE,		vPos, NULL_VECTOR);
		if( ent ) InputKill(ent, 1.0);
	}
	ent = DisplayParticle(0,		PARTICLE_PIPE3,			vPos, NULL_VECTOR);
	if( ent ) InputKill(ent, 1.0);

	// Sound
	if( GetRandomInt(0, 1) ) PlaySound(entity, SOUND_EXPLODE3);
	else PlaySound(entity, SOUND_EXPLODE5);

	// Kill flashbang
	AcceptEntityInput(entity, "Kill");
}

// ====================================================================================================
//					EXPLOSION FX - SHIELD
// ====================================================================================================
public void Explode_Shield(int client, int entity, int index, bool fromTimer)
{
	// Grenade Pos
	float vPos[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vPos);

	// Particles
	DisplayParticle(entity, PARTICLE_TES2,		vPos, NULL_VECTOR);

	// Sound
	PlaySound(entity, SOUND_BUTTON1);

	// Beam rings
	float range = g_GrenadeData[index - 1][CONFIG_RANGE] * 2 + BEAM_OFFSET;
	static bool flip;
	flip = !flip;
	CreateBeamRing(entity, { 0, 220, 255, 255 }, flip ? 0.1 : range - (range / BEAM_RINGS), flip ? range - (range / BEAM_RINGS) : 0.1);


	if( fromTimer == false )
	{
		// Create Trigger
		TriggerMultipleDamage(entity, index, range, vPos);
	}
}

public void OnTouchTriggerShield(int entity, int target)
{
	if( target <= MaxClients && GetClientTeam(target) == 2 )
	{
		if( g_fLastShield[target] == 0.0 )
		{
			SDKHook(target, SDKHook_OnTakeDamageAlive, OnShield);
		}

		g_fLastShield[target] = GetGameTime();
	}
}

public Action OnShield(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	// Check hook time
	if( GetGameTime() - g_fLastShield[victim] > 0.5 )
	{
		g_fLastShield[victim] = 0.0;
		SDKUnhook(victim, SDKHook_OnTakeDamageAlive, OnShield);
		return Plugin_Continue;
	}

	if( GetClientTeam(victim) == 2 )
	{
		damage *= (100 - g_GrenadeData[INDEX_SHIELD][CONFIG_DAMAGE]) / 100;
		if( damage < 0.0 ) damage = 0.0;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

// ====================================================================================================
//					EXPLOSION FX - TESLA
// ====================================================================================================
public void Explode_Tesla(int client, int grenade, int index, bool fromTimer)
{
	// Grenade Pos
	float vPos[3];
	GetEntPropVector(grenade, Prop_Data, "m_vecAbsOrigin", vPos);

	// Explosion
	CreateExplosion(client, grenade, index, 0.0, vPos, DMG_PLASMA, true);

	// Particles
	if( GetGameTime() - g_fLastTesla[grenade] >= 1.8 )
	{
		DisplayParticle(grenade, PARTICLE_TES2, vPos, NULL_VECTOR);
		g_fLastTesla[grenade] = GetGameTime();
	}

	if( fromTimer == false )
	{
		// Shake
		CreateShake(g_GrenadeData[index - 1][CONFIG_SHAKE], g_GrenadeData[index - 1][CONFIG_RANGE] + SHAKE_RANGE, vPos);
	}
}

void TeslaShock(int grenade, int target)
{
	char sTemp[32];
	float vPos[3];
	int entity;
	int iType = GetRandomInt(0, 1);



	// PARTICLE TARGET
	if( g_bLeft4Dead2 )
		entity = CreateEntityByName("info_particle_target");
	else
	{
		entity = CreateEntityByName("info_particle_system");
	}

	if( iType == 0 )
		DispatchKeyValue(entity, "effect_name", PARTICLE_TES1);
	else if( iType == 1 )
		DispatchKeyValue(entity, "effect_name", PARTICLE_TES3);

	Format(sTemp, sizeof(sTemp), "tesla%d%d%d", entity, grenade, target);
	DispatchKeyValue(entity, "targetname", sTemp);

	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetParent", grenade);
	vPos[2] = 10.0;
	TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
	DispatchSpawn(entity);
	ActivateEntity(entity);
	AcceptEntityInput(entity, "Start");

	InputKill(entity, 1.5);



	// PARTICLE
	entity = CreateEntityByName("info_particle_system");
	DispatchKeyValue(entity, "cpoint1", sTemp);
	if( iType == 0 )
		DispatchKeyValue(entity, "effect_name", PARTICLE_TES1);
	else if( iType == 1 )
		DispatchKeyValue(entity, "effect_name", PARTICLE_TES3);

	AcceptEntityInput(entity, "Start");

	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetParent", target);
	vPos[2] = GetRandomFloat(10.0, 50.0);
	TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
	DispatchSpawn(entity);
	ActivateEntity(entity);

	InputKill(entity, 1.2);



	// SOUND
	PlaySound(entity, g_sSoundsZap[GetRandomInt(0, sizeof g_sSoundsZap - 1)]);
}

// ====================================================================================================
//					EXPLOSION FX - CHEMICAL
// ====================================================================================================
public void Explode_Chemical(int client, int entity, int index, bool fromTimer)
{
	// Grenade Pos
	float vPos[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vPos);

	// Explosion
	CreateExplosion(client, entity, index, 0.0, vPos, DMG_BULLET);

	if( fromTimer == false )
	{
		// Shake
		CreateShake(g_GrenadeData[index - 1][CONFIG_SHAKE], g_GrenadeData[index - 1][CONFIG_RANGE] + SHAKE_RANGE, vPos);

		// Particles
		if( g_bLeft4Dead2 )
		{
			// Would prefer the particles above the grenade, but need to parent so it moves with the grenade and not bugged.
			DisplayParticle(entity, PARTICLE_SPIT_P,		vPos, NULL_VECTOR, 0.5);

			// SetParent forces this particle to 0,0,0 on the parent entity, to teleport slightly above it cannot be parented.
			// vPos[2] += 10.0;
			// entity = DisplayParticle(0, PARTICLE_SPIT_P,		vPos, NULL_VECTOR, 0.5);
			// vPos[2] -= 10.0;

			// Fire and forget itself
			// char sTime[64];
			// InputKill(entity, g_GrenadeData[index - 1][CONFIG_TIME]);
		}
		else
		{
			DisplayParticle(entity, PARTICLE_TRAIL,			vPos, NULL_VECTOR, 0.5);
			DisplayParticle(entity, PARTICLE_SPLASH,		vPos, NULL_VECTOR, 0.7);
			DisplayParticle(entity, PARTICLE_STEAM,			vPos, NULL_VECTOR, 0.5);
		}

		// Spitter Goo
		if( g_bLeft4Dead2 )
		{
			vPos[1] += 5.0;
			vPos[2] += 5.0;
			entity = SDKCall(sdkActivateSpit, vPos, view_as<float>({ 0.0, 0.0, 0.0 }), view_as<float>({ 0.0, 0.0, 0.0 }), view_as<float>({ 0.0, 0.0, 0.0 }), client);
			SetEntPropEnt(entity, Prop_Data, "m_hThrower", client);
			vPos[1] -= 5.0;
			vPos[2] -= 5.0;
		}
	}
}

// ====================================================================================================
//					EXPLOSION FX - FREEZER
// ====================================================================================================
public void Explode_Freezer(int client, int entity, int index, bool fromTimer)
{
	// Grenade Pos
	float vPos[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vPos);

	if( fromTimer == false )
	{
		// Explosion
		CreateExplosion(client, entity, index, 0.0, vPos, DMG_GENERIC);

		// Shake
		CreateShake(g_GrenadeData[index - 1][CONFIG_SHAKE], g_GrenadeData[index - 1][CONFIG_RANGE] + SHAKE_RANGE, vPos);

		// Trigger
		float range = g_GrenadeData[index - 1][CONFIG_RANGE];
		TriggerMultipleDamage(entity, index, range, vPos);
	}

	// Particles
	DisplayParticle(entity, PARTICLE_SPLASH, vPos, NULL_VECTOR);

	// Sound
	int random = GetRandomInt(1, 3);
	switch( random )
	{
		case 1: PlaySound(entity, SOUND_SPLASH1);
		case 2: PlaySound(entity, SOUND_SPLASH2);
		case 3: PlaySound(entity, SOUND_SPLASH3);
	}
}

public void OnTouchTriggerFreezer2(int entity, int target)
{
	if( target > MaxClients )
	{
		char classname[12];
		GetEdictClassname(target, classname, sizeof classname);

		int targ = g_GrenadeTarg[INDEX_FREEZER];
		if( (targ & (1 << TARGET_COMMON) && strcmp(classname, "infected") == 0) || (targ & (1 << TARGET_WITCH) && strcmp(classname, "witch") == 0) )
		{
			if( g_bLeft4Dead2 )
				SetEntPropFloat(target, Prop_Data, "m_flFrozen", 0.3); // Only exists in L4D2

			PlaySound(target, SOUND_FREEZER);

			float vPos[3];
			GetEntPropVector(target, Prop_Data, "m_vecOrigin", vPos);
			int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
			PushCommon(client, target, vPos);
		}
	}
}

public void OnTouchTriggerFreezer(int entity, int target)
{
	if( target <= MaxClients )
	{
		int targ = g_GrenadeTarg[INDEX_FREEZER];

		if( (targ & (1<<TARGET_SURVIVOR) || targ & (1<<TARGET_SPECIAL)) )
		{
			if( GetEntProp(target, Prop_Send, "m_fFlags") & FL_ONGROUND )
			{
				bool pass;

				int team = GetClientTeam(target);
				if( team == 2 && targ & (1<<TARGET_SURVIVOR) )
					pass = true;
				else if( team == 3 && targ & (1<<TARGET_SPECIAL) )
					pass = true;
				else if( team == 3 && targ & (1<<TARGET_TANK) && GetEntProp(target, Prop_Send, "m_zombieClass") == (g_bLeft4Dead2 ? 8 : 5) )
					pass = true;

				if( pass )
				{
					if( GetGameTime() - g_fLastFreeze[target] > 1.0 )
					{
						CreateTimer(0.5, tmrFreezer, GetClientUserId(target), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

						PlaySound(target, SOUND_FREEZER);
						SetEntityRenderColor(target, 0, 128, 255, 192);
					}

					if( GetEntityMoveType(target) != MOVETYPE_NONE )
						SetEntityMoveType(target, MOVETYPE_NONE); // Has to be outside the timer, if player staggers they'll be able to move, so constantly apply.
					g_fLastFreeze[target] = GetGameTime();
				}
			}
		}
	}
}

public Action tmrFreezer(Handle timer, any client)
{
	if( (client = GetClientOfUserId(client)) && IsClientInGame(client) && IsPlayerAlive(client) )
	{
		if( GetGameTime() - g_fLastFreeze[client] < 1.0 )
		{
			return Plugin_Continue;
		}

		PlaySound(client, SOUND_FREEZER);
		SetEntityRenderColor(client, 255, 255, 255, 255);
		SetEntityMoveType(client, MOVETYPE_WALK);
	}
	return Plugin_Stop;
}

// ====================================================================================================
//					EXPLOSION FX - MEDIC
// ====================================================================================================
public void Explode_Medic(int client, int entity, int index)
{
	// Grenade Pos
	float vPos[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vPos);

	// Shake
	CreateShake(g_GrenadeData[index - 1][CONFIG_SHAKE], g_GrenadeData[index - 1][CONFIG_RANGE] + SHAKE_RANGE, vPos);

	// Sound
	PlaySound(entity, SOUND_BUTTON2);

	// Beam Ring
	float range = g_GrenadeData[index - 1][CONFIG_RANGE] * 2 + BEAM_OFFSET;
	CreateBeamRing(entity, { 0, 150, 0, 255 }, 0.1, range - (range / BEAM_RINGS));

	// Heal survivors
	int iHealth;
	float fHealth;
	float vEnd[3];
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) )
		{
			GetClientAbsOrigin(i, vEnd);
			if( GetVectorDistance(vPos, vEnd) <= g_GrenadeData[index - 1][CONFIG_RANGE] )
			{
				iHealth = GetClientHealth(i);
				if( iHealth < 100 )
				{
					iHealth += RoundFloat(g_GrenadeData[index - 1][CONFIG_DAMAGE]);
					if( iHealth > 100 )
						iHealth = 100;

					fHealth = GetTempHealth(i);
					if( iHealth + fHealth > 100 )
					{
						fHealth = 100.0 - iHealth;
						SetTempHealth(i, fHealth);
					}

					SetEntityHealth(i, iHealth);
				}
			}
		}
	}
}

// ====================================================================================================
//					EXPLOSION FX - VAPORIZER
// ====================================================================================================
public void Explode_Vaporizer(int client, int entity, int index, bool fromTimer)
{
	// Grenade Pos
	float vPos[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vPos);

	// Explosion
	CreateExplosion(client, entity, index, 0.0, vPos, DMG_BULLET, true);

	// Shake
	if( fromTimer == false )
		CreateShake(g_GrenadeData[index - 1][CONFIG_SHAKE], g_GrenadeData[index - 1][CONFIG_RANGE] + SHAKE_RANGE, vPos);
}

void DissolveCommon(int client, int entity, int target, float fDamage)
{
	// Pos
	float vPos[3], vEnd[3];
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vPos);
	GetEntPropVector(target, Prop_Data, "m_vecOrigin", vEnd);
	vEnd[2] += 50;

	// Beam
	TE_SetupBeamPoints(vPos, vEnd, g_BeamSprite, g_HaloSprite, 30, 0, 0.2, 1.0, 2.0, 0, 0.0, { 50, 50, 150, 150 }, 0);
	TE_SendToAll();

	// Sound
	PlaySound(target, g_sSoundsZap[GetRandomInt(0, 7)]);

	// Damage - only dissolve when dead
	if( GetEntProp(target, Prop_Data, "m_iHealth") - fDamage > 0 )
		return;

	// Dissolve
	int iOverlayModel = -1;
	if( bLMC_Available )
		iOverlayModel = LMC_GetEntityOverlayModel(target);

	if( target <= MaxClients )
	{
		int clone = AttachFakeRagdoll(target);
		if( clone > 0 )
		{
			SetEntityRenderMode(clone, RENDER_NONE); // Hide and dissolve clone - method to show more particles
			DissolveTarget(client, clone, GetEntProp(target, Prop_Send, "m_zombieClass") == 2 ? 0 : target); // Exclude boomer to producer gibs
		}
	} else {
		SetEntityRenderFx(target, RENDERFX_FADE_FAST);
		if( iOverlayModel < 1 )
			DissolveTarget(client, target);
		else
			DissolveTarget(client, iOverlayModel, target);
	}
}

void DissolveTarget(int client, int target, int original = 0)
{
	// CreateEntityByName "env_entity_dissolver" has broken particles, this way works 100% of the time
	float time = GetRandomFloat(0.2, 0.7);

	int dissolver = SDKCall(sdkDissolveCreate, target, "", GetGameTime() + time, 2, false);
	if( dissolver > MaxClients && IsValidEntity(dissolver) )
	{
		if( target > MaxClients )
		{
			// Have to kill here because this function is called above the actual hurt in CreateExplosion.
			char sTemp[8];
			IntToString(GetEntProp(target, Prop_Data, "m_iHealth") - 10, sTemp, sizeof(sTemp));
			DispatchKeyValue(g_iEntityHurt, "Damage", sTemp);
			DispatchKeyValue(g_iEntityHurt, "DamageType", "0");
			DispatchKeyValue(target, "targetname", "silvershot");
			AcceptEntityInput(g_iEntityHurt, "Hurt", client, client);

			// Prevent common infected from crashing the server when taking damage from the dissolver.
			SDKHook(target, SDKHook_OnTakeDamage, OnCommonDamage);

			// Prevent immortal common infected if they fail to die from the dissolver.
			// Bug should not happen because the SDKHook was in the wrong section in version <= 1.5 (from Dissolve Infected plugin).
			InputKill(target, time + 0.5);
		}

		SetEntPropFloat(dissolver, Prop_Send, "m_flFadeOutStart", 0.0); // Fixes broken particles

		int fader = CreateEntityByName("func_ragdoll_fader");
		if( fader != -1 )
		{
			float vec[3];
			GetEntPropVector(original ? original : target, Prop_Data, "m_vecOrigin", vec);
			TeleportEntity(fader, vec, NULL_VECTOR, NULL_VECTOR);
			DispatchSpawn(fader);

			SetEntPropVector(fader, Prop_Send, "m_vecMaxs", view_as<float>({ 50.0, 50.0, 50.0 }));
			SetEntPropVector(fader, Prop_Send, "m_vecMins", view_as<float>({ -50.0, -50.0, -50.0 }));
			SetEntProp(fader, Prop_Send, "m_nSolidType", 2);

			InputKill(fader, 0.1);
		}
	}
}

int AttachFakeRagdoll(int target)
{
	int entity = CreateEntityByName("prop_dynamic_ornament");
	if( entity != -1 )
	{
		char sModel[64];
		GetEntPropString(target, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
		DispatchKeyValue(entity, "model", sModel);
		DispatchSpawn(entity);

		SetVariantString("!activator");
		AcceptEntityInput(entity, "SetParent", target);
		SetVariantString("!activator");
		AcceptEntityInput(entity, "SetAttached", target);
	}

	return entity;
}

public Action OnCommonDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	damage = 0.0;
	return Plugin_Handled;
}

// ====================================================================================================
//					EXPLOSION FX - EXTINGUISHER
// ====================================================================================================
void Explode_Extinguisher(int client, int entity, int index)
{
	// Grenade Pos
	float vPos[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vPos);

	// Explosion
	CreateExplosion(client, entity, index, 0.0, vPos, DMG_BULLET, true);

	// Shake
	CreateShake(g_GrenadeData[index - 1][CONFIG_SHAKE], g_GrenadeData[index - 1][CONFIG_RANGE] + SHAKE_RANGE, vPos);

	// Particles
	DisplayParticle(entity, PARTICLE_SPLASH, vPos, NULL_VECTOR, 0.7);

	// Sound
	int random = GetRandomInt(1, 3);
	switch( random )
	{
		case 1: PlaySound(entity, SOUND_SPLASH1);
		case 2: PlaySound(entity, SOUND_SPLASH2);
		case 3: PlaySound(entity, SOUND_SPLASH3);
	}

	// Extinguish fires
	float vEnd[3];
	int inferno = -1;
	while( (inferno = FindEntityByClassname(inferno, "inferno")) != INVALID_ENT_REFERENCE )
	{
		GetEntPropVector(inferno, Prop_Data, "m_vecAbsOrigin", vEnd);
		if( GetVectorDistance(vPos, vEnd) < g_GrenadeData[INDEX_EXTINGUISHER][CONFIG_RANGE] )
		{
			AcceptEntityInput(inferno, "Kill");
		}
	}

	inferno = -1;
	while( (inferno = FindEntityByClassname(inferno, "fire_cracker_blast")) != INVALID_ENT_REFERENCE )
	{
		GetEntPropVector(inferno, Prop_Data, "m_vecAbsOrigin", vEnd);
		if( GetVectorDistance(vPos, vEnd) < g_GrenadeData[INDEX_EXTINGUISHER][CONFIG_RANGE] )
		{
			AcceptEntityInput(inferno, "Kill");
		}
	}
}

// ====================================================================================================
//					EXPLOSION FX - GLOW
// ====================================================================================================
void Explode_Glow(int client, int entity, int index)
{
	// Grenade Pos
	float vPos[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vPos);

	// Explosion
	CreateExplosion(client, entity, index, 0.0, vPos, DMG_BULLET, true);

	// Shake
	CreateShake(g_GrenadeData[index - 1][CONFIG_SHAKE], g_GrenadeData[index - 1][CONFIG_RANGE], vPos);

	// Particles
	int particle = DisplayParticle(0, PARTICLE_BOOMER, vPos, NULL_VECTOR);
	if( particle ) InputKill(particle, 3.0);

	particle = DisplayParticle(0, PARTICLE_SMOKER1, vPos, NULL_VECTOR);
	if( particle ) InputKill(particle, 3.0);

	particle = DisplayParticle(0, PARTICLE_SMOKER2, vPos, NULL_VECTOR);
	if( particle ) InputKill(particle, 3.0);

	// Sound
	PlaySound(entity, SOUND_GATE, SNDLEVEL_RAIDSIREN);
}

// ====================================================================================================
//					EXPLOSION FX - ANTI-GRAVITY
// ====================================================================================================
void Explode_AntiGravity(int client, int entity, int index)
{
	// Grenade Pos
	float vPos[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vPos);

	// Explosion
	CreateExplosion(client, entity, index, 0.0, vPos, DMG_BULLET, true);

	// Shake
	CreateShake(g_GrenadeData[index - 1][CONFIG_SHAKE], g_GrenadeData[index - 1][CONFIG_RANGE], vPos);

	// Sound
	PlaySound(entity, SOUND_BUTTON2, SNDLEVEL_RAIDSIREN);

	// Beam Ring
	float range = g_GrenadeData[index - 1][CONFIG_RANGE] * 2 + BEAM_OFFSET;
	CreateBeamRing(entity, { 0, 255, 100, 255 }, range - (range / BEAM_RINGS), 0.1);
}

// ====================================================================================================
//					EXPLOSION FX - BULLETS
// ====================================================================================================
void Explode_Bullets(int client, int entity, int index, bool fromTimer)
{
	// Grenade Pos
	float vPos[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vPos);

	// Explosion
	if( fromTimer == false )
	{
		CreateExplosion(client, entity, index, 0.0, vPos, DMG_BULLET, true);

		// Shake
		CreateShake(g_GrenadeData[index - 1][CONFIG_SHAKE], g_GrenadeData[index - 1][CONFIG_RANGE], vPos);
	}

	// Sound
	if( GetRandomInt(0,3) == 3 )
		PlaySound(entity, g_sSoundsMiss[GetRandomInt(0, sizeof g_sSoundsMiss - 1)]);
	PlaySound(entity, SOUND_SHOOTING, SNDLEVEL_RAIDSIREN);



	// Bullets
	char classname[16];
	Handle trace;
	float vEnd[3];
	float vAng[3];
	float fDamage = g_GrenadeData[index - 1][CONFIG_DAMAGE];
	int particle;
	int target;
	int targ;
	bool pass;
	vPos[2] += 5.0;

	for( int x = 1; x <= 8; x++ )
	{
		vAng[0] = GetRandomFloat(-20.0, 5.0); // How far up/down tracers point (0=Horizontal, -90=Up.)
		vAng[1] = GetRandomFloat(-180.0, 180.0); // Random direction

		// Trace + Particles
		trace = TR_TraceRayFilterEx(vPos, vAng, MASK_SHOT, RayType_Infinite, _TraceFilter);
		TR_GetEndPosition(vEnd, trace);

		if( g_bLeft4Dead2 && GetRandomInt(0, 3) == 0 )
			L4D_TE_Create_Particle(vPos, vEnd, g_iParticleTracer50);
		else
			L4D_TE_Create_Particle(vPos, vEnd, g_iParticleTracer);

		if( x <= 3 )
		{
			particle = DisplayParticle(0, PARTICLE_MUZZLE, vPos, vAng);
			InputKill(particle, 0.01);
		}

		// /* // Test to show traces:
		// #include <neon_beams> // Put outside of function
		// float vEnd[3];
		// TR_GetEndPosition(vEnd, trace);
		// NeonBeams_TempMap(0, vPos, vEnd, 5.0);
		// */

		// Validate entity hit
		if( TR_DidHit(trace) == true )
		{
			target = TR_GetEntityIndex(trace);
			targ = g_GrenadeTarg[index - 1];
			pass = false;

			// Valid target. Scale damage
			if( target > 0 && target <= MaxClients && (targ & (1<<TARGET_SURVIVOR) || targ & (1<<TARGET_SPECIAL)) )
			{
				int team = GetClientTeam(target);
				if( team == 2 && targ & (1<<TARGET_SURVIVOR) )
				{
					fDamage = fDamage * g_fConfigSurvivors * g_GrenadeData[index - 1][CONFIG_DMG_SURVIVORS];
					pass = true;
				}
				else if( team == 3 && targ & (1<<TARGET_SPECIAL) )
				{
					fDamage = fDamage * g_fConfigSpecial * g_GrenadeData[index - 1][CONFIG_DMG_SPECIAL];
					pass = true;
				}
				else if( team == 3 && targ & (1<<TARGET_TANK) && GetEntProp(target, Prop_Send, "m_zombieClass") == (g_bLeft4Dead2 ? 8 : 5) )
				{
					fDamage = fDamage * g_fConfigTank * g_GrenadeData[index - 1][CONFIG_DMG_TANK];
					pass = true;
				}
			}

			if( target > MaxClients && (targ & (1<<TARGET_WITCH) || targ & (1<<TARGET_COMMON) || targ & (1<<TARGET_PHYSICS)) )
			{
				// Check classname
				GetEdictClassname(target, classname, sizeof classname);

				if( targ & (1 << TARGET_WITCH) && strcmp(classname, "witch") == 0 )
				{
					fDamage = fDamage * g_fConfigWitch * g_GrenadeData[index - 1][CONFIG_DMG_WITCH];

					pass = true;
				}
				else if( targ & (1 << TARGET_COMMON) && strcmp(classname, "infected") == 0 )
				{
					pass = true;
				}
				else if( targ & (1<<TARGET_PHYSICS) )
				{
					if(
						strcmp(classname, "prop_physics") == 0 ||
						strcmp(classname, "weapon_gascan") == 0
					)
					{
						fDamage = fDamage * g_fConfigPhysics * g_GrenadeData[index - 1][CONFIG_DMG_PHYSICS];

						pass = true;
					}
				}
			}

			if( pass )
			{
				IntToString(RoundFloat(fDamage), classname, sizeof classname);
				DispatchKeyValue(g_iEntityHurt, "Damage", classname);
				DispatchKeyValue(target, "targetname", "silvershot");
				AcceptEntityInput(g_iEntityHurt, "Hurt", client, client);
				DispatchKeyValue(target, "targetname", "");
			}
		}
		delete trace;
	}
}

// ====================================================================================================
//					EXPLOSION FX - FLAK
// ====================================================================================================
void Explode_Flak(int client, int entity, int index)
{
	// Grenade Pos
	float vPos[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vPos);

	// Shake
	CreateShake(g_GrenadeData[index - 1][CONFIG_SHAKE], g_GrenadeData[index - 1][CONFIG_RANGE], vPos);

	// Sound
	if( g_bLeft4Dead2 )
	{
		int random = GetRandomInt(1, 4);
		switch( random )
		{
			case 1: PlaySound(entity, SOUND_FIREWORK1);
			case 2: PlaySound(entity, SOUND_FIREWORK2);
			case 3: PlaySound(entity, SOUND_FIREWORK3);
			case 4: PlaySound(entity, SOUND_FIREWORK4);
		}
	} else {
		if( GetRandomInt(0, 1) ) PlaySound(entity, SOUND_EXPLODE3);
		else PlaySound(entity, SOUND_EXPLODE5);
	}

	// Random position
	vPos[0] += GetRandomFloat(-g_GrenadeData[index - 1][CONFIG_RANGE], g_GrenadeData[index - 1][CONFIG_RANGE]);
	vPos[1] += GetRandomFloat(-g_GrenadeData[index - 1][CONFIG_RANGE], g_GrenadeData[index - 1][CONFIG_RANGE]);
	vPos[2] += GetRandomFloat(75.0, 120.0);

	// Sparks
	int spark = CreateEntityByName("env_spark");
	DispatchKeyValue(spark, "angles", "-90 0 0");
	DispatchKeyValue(spark, "TrailLength", "1");
	DispatchKeyValue(spark, "Magnitude", "5");
	TeleportEntity(spark, vPos, NULL_VECTOR, NULL_VECTOR);
	DispatchSpawn(spark);
	ActivateEntity(spark);
	AcceptEntityInput(spark, "SparkOnce");
	InputKill(spark, 0.5);

	// Particles
	if( g_bLeft4Dead2 )
		DisplayParticle(spark,		PARTICLE_CHARGE,	vPos, NULL_VECTOR);
	DisplayParticle(spark,			PARTICLE_BLAST,		vPos, NULL_VECTOR);
	DisplayParticle(spark,			PARTICLE_PIPE2,		vPos, NULL_VECTOR);

	// Explosion
	vPos[2] -= 75.0;
	CreateExplosion(client, entity, index, 150.0, vPos, DMG_BURN);
}



// ====================================================================================================
//					STOCKS - CREATE PROJECTILE
// ====================================================================================================
int CreateProjectile(int entity, int client, int index)
{
	// Save origin and velocity
	float vPos[3], vAng[3], vVel[3];
	GetEntPropVector(entity, Prop_Data, "m_angRotation", vAng);
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vPos);
	GetEntPropVector(entity, Prop_Send, "m_vInitialVelocity", vVel);
	AcceptEntityInput(entity, "Kill");

	// Create new projectile
	g_bBlockHook = true;
	entity = CreateEntityByName("pipe_bomb_projectile"); // prop_physics_override doesn't work with MODEL_SPRAYCAN.
	g_bBlockHook = false;

	if( entity == -1 )
	{
		return 0;
	}

	SetEntProp(entity, Prop_Data, "m_iHammerID", index);			// Store mode type
	SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);		// Store owner
	SetEntPropFloat(entity, Prop_Data, "m_flGravity", g_GrenadeData[index - 1][CONFIG_GRAVITY]);
	SetEntPropFloat(entity, Prop_Data, "m_flElasticity", g_GrenadeData[index - 1][CONFIG_ELASTICITY]);

	// Set origin and velocity
	float vDir[3];
	GetAngleVectors(vAng, vDir, NULL_VECTOR, NULL_VECTOR);
	vPos[0] += vDir[0] * 10;
	vPos[1] += vDir[1] * 10;
	vPos[2] += vDir[2] * 10;
	TeleportEntity(entity, vPos, vAng, vVel);
	DispatchSpawn(entity);
	SetEntityModel(entity, MODEL_SPRAYCAN); // Model after Dispatch otherwise the projectile effects (flashing light + trail) show and model doesn't change.

	// Fire and forget - if plugins unloaded the entity and fx will still be deleted.
	float tick = g_GrenadeData[index - 1][CONFIG_TICK];
	float time = g_GrenadeData[index - 1][CONFIG_TIME];

	// + 10 to account for flight time before impact.
	InputKill(entity, (time > tick ? time : tick) + g_GrenadeData[index - 1][CONFIG_FUSE] + 10.0);

	return entity;
}



// ====================================================================================================
//					STOCKS - GRENADE MODE
// ====================================================================================================
int IsGrenade(int weapon)
{
	char classname[20];
	GetEdictClassname(weapon, classname, sizeof classname);

	if(
		classname[7] == 'm' ||
		classname[7] == 'p' ||
		classname[7] == 'v'
	)
	{
		if( strcmp(classname, "weapon_molotov") == 0 )							return 1;
		if( strcmp(classname, "weapon_pipe_bomb") == 0 )						return 2;
		if( g_bLeft4Dead2 && strcmp(classname, "weapon_vomitjar") == 0 )		return 3;
	}
	return 0;
}

void ReplaceColors(char[] translation, int size)
{
	ReplaceString(translation, size, "{white}",		"\x01");
	ReplaceString(translation, size, "{cyan}",		"\x03");
	ReplaceString(translation, size, "{orange}",	"\x04");
	ReplaceString(translation, size, "{green}",		"\x05");
}



// ====================================================================================================
//					STOCKS - SOUND
// ====================================================================================================
void PlaySound(int entity, const char[] sound, int level = SNDLEVEL_NORMAL)
{
	EmitSoundToAll(sound, entity, level == SNDLEVEL_RAIDSIREN ? SNDCHAN_ITEM : SNDCHAN_AUTO, level);
}

void StopSounds(int entity)
{
	StopSound(entity, SNDCHAN_AUTO, SOUND_FLICKER);
	StopSound(entity, SNDCHAN_AUTO, SOUND_GAS);
	StopSound(entity, SNDCHAN_AUTO, SOUND_GATE);
	StopSound(entity, SNDCHAN_AUTO, SOUND_NOISE);
	StopSound(entity, SNDCHAN_AUTO, SOUND_SPATIAL);
	StopSound(entity, SNDCHAN_AUTO, SOUND_SQUEAK);
	StopSound(entity, SNDCHAN_AUTO, SOUND_STEAM);
	StopSound(entity, SNDCHAN_AUTO, SOUND_TUNNEL);
}



// ====================================================================================================
//					STOCKS - STAGGER
// ====================================================================================================
void PushCommon(int client, int target, float vPos[3], bool common = true)
{
	CreateHurtEntity();

	if( common && g_bLeft4Dead2 )			DispatchKeyValue(g_iEntityHurt, "DamageType", "33554432");	// DMG_AIRBOAT (1<<25)	// Common L4D2
	else if( common )						DispatchKeyValue(g_iEntityHurt, "DamageType", "536870912");	// DMG_BUCKSHOT (1<<29)	// Common L4D1
	else									DispatchKeyValue(g_iEntityHurt, "DamageType", "64");		// DMG_BLAST (1<<6) // Witch

	DispatchKeyValue(g_iEntityHurt, "Damage", "0");
	DispatchKeyValue(target, "targetname", "silvershot");
	TeleportEntity(g_iEntityHurt, vPos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(g_iEntityHurt, "Hurt", client, client);
	DispatchKeyValue(target, "targetname", "");
}

void StaggerClient(int userid, const float vPos[3])
{
	if( g_bLeft4Dead2 )
	{
		// Credit to Timocop on VScript function
		static int iScriptLogic = INVALID_ENT_REFERENCE;
		if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic))
		{
			iScriptLogic = EntIndexToEntRef(CreateEntityByName("logic_script"));
			if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic))
				LogError("Could not create 'logic_script");

			DispatchSpawn(iScriptLogic);
		}

		char sBuffer[96];
		Format(sBuffer, sizeof(sBuffer), "GetPlayerFromUserID(%d).Stagger(Vector(%d,%d,%d))", userid, RoundFloat(vPos[0]), RoundFloat(vPos[1]), RoundFloat(vPos[2]));
		SetVariantString(sBuffer);
		AcceptEntityInput(iScriptLogic, "RunScriptCode");
		AcceptEntityInput(iScriptLogic, "Kill");
	} else {
		userid = GetClientOfUserId(userid);
		SDKCall(sdkStaggerClient, userid, userid, vPos); // Stagger: SDKCall method
	}
}



// ====================================================================================================
//					STOCKS - EXPLOSION
// ====================================================================================================
void CreateExplosion(int client, int entity, int index, float range = 0.0, float vPos[3], int damagetype = DMG_GENERIC, bool ignorePhysics = false)
{
	int targ = g_GrenadeTarg[index - 1];
	if( targ == 0 ) return;



	// Damage tick timeout. Tesla and Vaporizer have their own timeout.
	if( index -1 != INDEX_TESLA && index -1 != INDEX_VAPORIZER )
	{
		if( GetGameTime() - g_fLastTesla[entity] < g_GrenadeData[index - 1][CONFIG_DMG_TICK] ) return;
		g_fLastTesla[entity] = GetGameTime();
	}



	// Range
	float range_damage;
	float range_stumble;
	if( range == 0.0 )
	{
		range_damage		= g_GrenadeData[index - 1][CONFIG_RANGE];
		range_stumble		= g_GrenadeData[index - 1][CONFIG_STUMBLE];
	} else {
		// From Cluster projectiles
		range_damage		= range;
		range_stumble		= range;
	}



	// Vars
	ArrayList aGodMode = new ArrayList(); // GodMode list, prevent players/common/witch from taking env_explosion damage.
	float damage = g_GrenadeData[index - 1][CONFIG_DAMAGE];
	float fDamage, fDistance;
	float vEnd[3];
	char sTemp[16];
	int team;
	int i;



	// Hurt survivors/special/common/witch with scaled damage
	CreateHurtEntity();
	vPos[2] -= 5.0;



	// ==================================================
	// PLAYERS - SURVIVORS + SPECIAL INFECTED
	// ==================================================
	// Loop through players, workout range and scale damage according distance. Stumble if needed.
	// Enable godmode so the explosion below does not hurt, and only our scaled damage affects clients.
	// ==================================================
	if( (targ & (1<<TARGET_SURVIVOR) || targ & (1<<TARGET_SPECIAL)) )
	{
		int clients[MAXPLAYERS+1]; // Flashbang
		int flashcount;

		for( i = 1; i <= MaxClients; i++ )
		{
			if( IsClientInGame(i) && IsPlayerAlive(i) )
			{
				team = GetClientTeam(i);
				if( team == 2 ? targ & (1<<TARGET_SURVIVOR) : targ & (1<<TARGET_SPECIAL) )
				{
					GetEntPropVector(i, Prop_Data, "m_vecOrigin", vEnd);
					fDistance = GetVectorDistance(vPos, vEnd);

					// Stumble
					// In range, not Cluster projectiles, not Tesla, not BlackHole, not Anti-Gravity
					if( range == 0.0 && range_stumble && fDistance < range_stumble && index -1 != INDEX_TESLA && index -1 != INDEX_BLACKHOLE && index -1 != INDEX_ANTIGRAVITY )
					{
						StaggerClient(GetClientUserId(i), vPos);
					}

					// Scale Damage to Range
					if( fDistance <= range_damage )
					{
						if( index -1 == INDEX_VAPORIZER )
						{
							fDamage = damage; // Full damage
						} else {
							fDamage = fDistance / (index -1 == INDEX_TESLA ? range_damage * 2 : range_damage); // Double Tesla range so damage is more when entering.
							fDamage = damage * fDamage;
							fDamage = damage - fDamage;
						}

						if( team == 3 )
						{
							if( GetEntProp(i, Prop_Send, "m_zombieClass") == (g_bLeft4Dead2 ? 8 : 5) )
							{
								if( targ & (1<<TARGET_TANK) )
									fDamage = fDamage * g_fConfigTank * g_GrenadeData[index - 1][CONFIG_DMG_TANK];
								else
									fDamage = 0.0;
							}
							else
								fDamage = fDamage * g_fConfigSpecial * g_GrenadeData[index - 1][CONFIG_DMG_SPECIAL];
						} else {
							fDamage = fDamage * g_fConfigSurvivors * g_GrenadeData[index - 1][CONFIG_DMG_SURVIVORS];
						}

						// Round to 1 because damage fall off scaling can set the value to above 0 and below 1. So affected guaranteed to lose 1 HP.
						if( fDamage > 0.0 && fDamage < 1.0 )
							fDamage = 1.0;

						if( fDamage > 0.0 )
						{
							// ==================================================
							// Grenade mode specific things:
							// ==================================================
							if( GrenadeSpecificExplosion(i, client, entity, index, TARGET_SURVIVOR, 0.0, fDistance, vPos, vEnd) == false )
								fDamage = 0.0;

							// Damage
							if( fDamage != 0.0 && (!g_bLeft4Dead2 || index -1 != INDEX_CHEMICAL) ) // Chemical mode in L4D2 only needs to damage non-survivor, the spit already damages them.
							{
								clients[flashcount++] = i;

								// Hurt
								FloatToString(fDamage, sTemp, sizeof(sTemp));
								DispatchKeyValue(g_iEntityHurt, "Damage", sTemp);
								IntToString(damagetype, sTemp, sizeof(sTemp));
								DispatchKeyValue(g_iEntityHurt, "DamageType", sTemp);
								DispatchKeyValue(i, "targetname", "silvershot");

								if( i == client ) // Otherwise can't hurt self. Also to avoid red flash on Flashbang
									AcceptEntityInput(g_iEntityHurt, "Hurt");
								else
									AcceptEntityInput(g_iEntityHurt, "Hurt", client, client);

								DispatchKeyValue(i, "targetname", "");
							}
						}

						// GodMode
						aGodMode.Push(i);
						SetEntProp(i, Prop_Data, "m_takedamage", 0); // Prevent taking damage from env_explosion
					}
				}
			}
		}

		// Flashbang
		if( flashcount && index -1 == INDEX_FLASHBANG )
		{
			// Blind
			UserMsg g_FadeUserMsgId = GetUserMessageId("Fade");
			Handle message = StartMessageEx(g_FadeUserMsgId, clients, flashcount);
			BfWrite bf = UserMessageToBfWrite(message);
			bf.WriteShort(RoundFloat(g_GrenadeData[index - 1][CONFIG_TIME]) * 1000);
			bf.WriteShort(100);
			bf.WriteShort(0x0001);
			bf.WriteByte(255);
			bf.WriteByte(255);
			bf.WriteByte(255);
			bf.WriteByte(240);
			EndMessage();
		}
	}



	// ==================================================
	// COMMON INFECTED - Loop
	// ==================================================
	if( targ & (1 << TARGET_COMMON) )
	{
		int numTesla;
		int numVapo;

		i = -1;
		while( (i = FindEntityByClassname(i, "infected")) != INVALID_ENT_REFERENCE && GetEntProp(i, Prop_Data, "m_iHealth") > 0 )
		{
			GetEntPropVector(i, Prop_Data, "m_vecOrigin", vEnd);
			fDistance = GetVectorDistance(vPos, vEnd);
			if( fDistance <= range_damage )
			{
				if( index -1 == INDEX_VAPORIZER )
				{
					fDamage = damage;
				} else {
					fDamage = fDistance / (index -1 == INDEX_TESLA ? range_damage * 2 : range_damage);
					fDamage = damage * fDamage;
					fDamage = damage - fDamage;
				}



				if( fDamage != 0.0 )
				{
					// ==================================================
					// Grenade mode specific things:
					// ==================================================
					if( GrenadeSpecificExplosion(i, client, entity, index, TARGET_COMMON, fDamage, fDistance, vPos, vEnd) == false )
						fDamage = 0.0;



					// Damage
					if( fDamage != 0.0 )
					{
						FloatToString(fDamage, sTemp, sizeof(sTemp));
						DispatchKeyValue(g_iEntityHurt, "Damage", sTemp);

						if( range_stumble && fDistance <= range_stumble )
						{
							if( g_bLeft4Dead2 )		DispatchKeyValue(g_iEntityHurt, "DamageType", "33554432");	// DMG_AIRBOAT (1<<25)	// Common L4D2
							else					DispatchKeyValue(g_iEntityHurt, "DamageType", "536870912");	// DMG_BUCKSHOT (1<<29)	// Common L4D1
						}
						else
							DispatchKeyValue(g_iEntityHurt, "DamageType", "0");

						DispatchKeyValue(i, "targetname", "silvershot");

						if( index -1 == INDEX_BLACKHOLE )
						{
							float vAng[3];
							MakeVectorFromPoints(vPos, vEnd, vAng);
							NormalizeVector(vAng, vAng);
							vEnd[0] += vAng[0] * 10;
							vEnd[1] += vAng[1] * 10;
							vEnd[2] += vAng[2] * 10;
							TeleportEntity(g_iEntityHurt, vEnd, NULL_VECTOR, NULL_VECTOR);
						} else {
							TeleportEntity(g_iEntityHurt, vPos, NULL_VECTOR, NULL_VECTOR);
						}

						AcceptEntityInput(g_iEntityHurt, "Hurt", client, client);
						DispatchKeyValue(i, "targetname", "");
					}
				}



				// GodMode
				aGodMode.Push(i);
				SetEntProp(i, Prop_Data, "m_takedamage", 0); // Prevent taking damage from env_explosion



				if( fDamage != 0.0 )
				{
					if( index -1 == INDEX_TESLA )
					{
						if( numTesla++ >= 3 )
						{
							numTesla = 0;
							break;
						}
					}
					else if( index -1 == INDEX_VAPORIZER )
					{
						if( numVapo++ >= 2 )
						{
							numVapo = 0;
							break;
						}
					}
				}
			}
		}
	}



	// ==================================================
	// WITCH - Loop
	// ==================================================
	if( targ & (1 << TARGET_WITCH) )
	{
		i = -1;
		while( (i = FindEntityByClassname(i, "witch")) != INVALID_ENT_REFERENCE )
		{
			GetEntPropVector(i, Prop_Data, "m_vecOrigin", vEnd);
			fDistance = GetVectorDistance(vPos, vEnd);
			if( fDistance <= range_damage )
			{
				if( index -1 == INDEX_VAPORIZER )
				{
					fDamage = damage;
				} else {
					fDamage = fDistance / (index -1 == INDEX_TESLA ? range_damage * 2 : range_damage);
					fDamage = damage * fDamage;
					fDamage = damage - fDamage;
					fDamage = fDamage * g_fConfigWitch * g_GrenadeData[index - 1][CONFIG_DMG_WITCH];
				}



				if( fDamage != 0.0 )
				{
					// ==================================================
					// Grenade mode specific things:
					// ==================================================
					if( GrenadeSpecificExplosion(i, client, entity, index, TARGET_WITCH, 0.0, fDistance, vPos, vEnd) == false )
						fDamage = 0.0;



					// Damage
					if( fDamage != 0.0 )
					{
						FloatToString(fDamage, sTemp, sizeof(sTemp));
						DispatchKeyValue(g_iEntityHurt, "Damage", sTemp);

						if( range_stumble && fDistance <= range_stumble )
							DispatchKeyValue(g_iEntityHurt, "DamageType", "64"); // DMG_BLAST (1<<6) // Witch
						else
							DispatchKeyValue(g_iEntityHurt, "DamageType", "0");

						DispatchKeyValue(i, "targetname", "silvershot");
						TeleportEntity(g_iEntityHurt, index -1 == INDEX_BLACKHOLE ? vEnd : vPos, NULL_VECTOR, NULL_VECTOR);
						AcceptEntityInput(g_iEntityHurt, "Hurt", client, client);
						DispatchKeyValue(i, "targetname", "");
					}
				}



				// GodMode
				aGodMode.Push(i);
				SetEntProp(i, Prop_Data, "m_takedamage", 0); // Prevent taking damage from env_explosion
			}
		}
	}



	// ==================================================
	// PHYSICS EXPLOSION
	// ==================================================
	if( ignorePhysics == false && targ & (1 << TARGET_PHYSICS) )
	{
		if( g_GrenadeData[index - 1][CONFIG_DMG_PHYSICS] )
		{
			int explo = CreateEntityByName("env_explosion");
			fDamage = damage * g_fConfigPhysics * g_GrenadeData[index - 1][CONFIG_DMG_PHYSICS];
			// FloatToString(fDamage, sTemp, sizeof(sTemp));
			// DispatchKeyValue(explo, "iMagnitude", sTemp);
			// FloatToString(range_damage, sTemp, sizeof(sTemp));
			// DispatchKeyValue(explo, "iRadiusOverride", sTemp);
			DispatchKeyValueFloat(explo, "iMagnitude", fDamage * 2);
			DispatchKeyValue(explo, "spawnflags", "18301");
			SetEntPropEnt(explo, Prop_Send, "m_hOwnerEntity", client);
			DispatchSpawn(explo);
			TeleportEntity(explo, vPos, NULL_VECTOR, NULL_VECTOR);
			AcceptEntityInput(explo, "Explode");

			InputKill(explo, 0.3);
		}
	}



	// Reset GodMode
	for( i = 0; i < aGodMode.Length; i++ )
	{
		SetEntProp(aGodMode.Get(i), Prop_Data, "m_takedamage", 2);
	}
}



// ====================================================================================================
//					STOCKS - GRENADE SPECIFIC EXPLOSION
// ====================================================================================================
bool GrenadeSpecificExplosion(int target, int client, int entity, int index, int type, float fDamage, float fDistance, float vPos[3], float vEnd[3])
{
	// ==================================================
	// BLACKHOLE - Pull into center
	// ==================================================
	if( index -1 == INDEX_BLACKHOLE )
	{
		if( type == TARGET_SURVIVOR )
		{
			MakeVectorFromPoints(vEnd, vPos, vEnd);
			NormalizeVector(vEnd, vEnd);
			ScaleVector(vEnd, fDistance);

			if( fDistance < 150 && GetEntProp(target, Prop_Send, "m_fFlags") & FL_ONGROUND == 0 ) // Reduce height when in air near center
				vEnd[2] = 100.0;
			else
				vEnd[2] = 300.0;

			TeleportEntity(target, NULL_VECTOR, NULL_VECTOR, vEnd);
		}
		else
		{
			if( type == TARGET_WITCH )
			{
				float vAng[3];
				MakeVectorFromPoints(vPos, vEnd, vAng);
				NormalizeVector(vAng, vAng);
				vEnd[0] += vAng[0] * 10;
				vEnd[1] += vAng[1] * 10;
				vEnd[2] += vAng[2] * 10;

				PushCommon(client, target, vEnd, false);
			}
		}
	}

	// ==================================================
	// TESLA - Push away
	// ==================================================
	else if( index -1 == INDEX_TESLA )
	{
		// Check duration
		if( GetGameTime() - g_fLastTesla[target] >= g_GrenadeData[INDEX_TESLA][CONFIG_DMG_TICK] )
		{
			g_fLastTesla[entity] = GetGameTime();
			g_fLastTesla[target] = GetGameTime();

			GetEntPropVector(target, Prop_Data, "m_vecOrigin", vEnd);
			vPos[2] += 50.0;
			vEnd[2] += 50.0;
			if( IsVisibleTo(vPos, vEnd) )
			{
				if( type == TARGET_SURVIVOR )
				{
					MakeVectorFromPoints(vPos, vEnd, vEnd);
					NormalizeVector(vEnd, vEnd);
					ScaleVector(vEnd, 400.0);
					vEnd[2] = 300.0;
					TeleportEntity(target, NULL_VECTOR, NULL_VECTOR, vEnd);
				}

				TeslaShock(entity, target);
				vPos[2] -= 50.0;
			} else {
				return false;
			}
		} else {
			return false;
		}
	}

	// ==================================================
	// FLASHBANG - Blind
	// ==================================================
	else if( index -1 == INDEX_FLASHBANG )
	{
		if( type == TARGET_SURVIVOR )
		{
			GetEntPropVector(target, Prop_Data, "m_vecOrigin", vEnd);
			vPos[2] += 50.0;
			vEnd[2] += 50.0;
			if( IsVisibleTo(vPos, vEnd) )
			{
				SDKCall(sdkDeafenClient, target, 1.0, 0.0, 0.01 );
			}
		}
	}

	// ==================================================
	// VAPORIZER - Dissolve
	// ==================================================
	else if( index -1 == INDEX_VAPORIZER )
	{
		if( GetGameTime() - GetEntPropFloat(target, Prop_Send, "m_flCreateTime") > g_GrenadeData[index - 1][CONFIG_DMG_TICK] )
		{
			GetEntPropVector(target, Prop_Data, "m_vecOrigin", vEnd);
			vEnd[2] += 50.0;
			if( IsVisibleTo(vPos, vEnd) )
			{
				SetEntPropFloat(target, Prop_Send, "m_flCreateTime", GetGameTime());
				DissolveCommon(client, entity, target, fDamage);
				return true;
			}
		}

		return false;
	}

	// ==================================================
	// GLOW
	// ==================================================
	else if( index -1 == INDEX_GLOW )
	{
		if( GetEntProp(target, Prop_Data, "m_iHammerID") == 0 && GetEntProp(target, Prop_Send, "m_glowColorOverride") == 0 ) // Avoid conflict with Mutant Zombies and already glowing.
		{
			SetEntProp(target, Prop_Send, "m_nGlowRange", RoundFloat(g_GrenadeData[index - 1][CONFIG_RANGE] * 4));
			SetEntProp(target, Prop_Send, "m_iGlowType", 3); // 2 = Requires line of sight. 3 = Glow through walls.
			SetEntProp(target, Prop_Send, "m_glowColorOverride", 38655); // GetColor("255 150 0");

			CreateTimer(g_GrenadeData[index - 1][CONFIG_TIME], tmrResetGlow, target <= MaxClients ? GetClientUserId(target) : EntIndexToEntRef(target));
		}
		return false;
	}

	// ==================================================
	// ANTI-GRAVITY - Teleport up
	// ==================================================
	else if( index -1 == INDEX_ANTIGRAVITY )
	{
		if( type == TARGET_SURVIVOR )
		{
			float vVel[3];
			GetEntPropVector(target, Prop_Data, "m_vecAbsVelocity", vVel);
			if( GetEntProp(target, Prop_Send, "m_fFlags") & FL_ONGROUND )
				vVel[2] = 350.0;
			else
				vVel[2] = 100.0;
			TeleportEntity(target, NULL_VECTOR, NULL_VECTOR, vVel);

			SetEntityGravity(target, 0.4);
			CreateTimer(0.1, tmrResetGravity, target <= MaxClients ? GetClientUserId(target) : EntIndexToEntRef(target), TIMER_REPEAT);
		}
	}

	// ==================================================
	// EXTINGUISHER
	// ==================================================
	else if( index -1 == INDEX_EXTINGUISHER )
	{
		ExtinguishEntity(target);
		return false;
	}

	return true;
}

public Action tmrResetGravity(Handle timer, any target)
{
	target = ValidTargetRef(target);
	if( target )
	{
		if( GetEntProp(target, Prop_Send, "m_fFlags") & FL_ONGROUND )
		{
			SetEntityGravity(target, 1.0);
		} else {
			return Plugin_Continue;
		}
	}

	return Plugin_Stop;
}

public Action tmrResetGlow(Handle timer, any target)
{
	target = ValidTargetRef(target);
	if( target && GetEntProp(target, Prop_Send, "m_glowColorOverride") == 38655 ) // GetColor("255 150 0");
	{
		SetEntProp(target, Prop_Send, "m_nGlowRange", 0);
		SetEntProp(target, Prop_Send, "m_iGlowType", 0);
		SetEntProp(target, Prop_Send, "m_glowColorOverride", 0);
	}
}

int ValidTargetRef(int target)
{
	if( target < 0 )
	{
		if( (target = EntRefToEntIndex(target)) != INVALID_ENT_REFERENCE )
			return target;
	} else {
		if( (target = GetClientOfUserId(target)) != 0 )
			return target;
	}

	return 0;
}

/*
int GetColor(char sTemp[32])
{
	char sColors[3][4];
	ExplodeString(sTemp, " ", sColors, 3, 4);

	int color;
	color = StringToInt(sColors[0]);
	color += 256 * StringToInt(sColors[1]);
	color += 65536 * StringToInt(sColors[2]);
	return color;
}
// */



// ====================================================================================================
//					STOCKS - SHAKE
// ====================================================================================================
void CreateShake(float intensity, float range, float vPos[3])
{
	if( intensity == 0.0 ) return;

	int entity = CreateEntityByName("env_shake");
	if( entity == -1 )
	{
		LogError("Failed to create 'env_shake'");
		return;
	}

	char sTemp[8];
	FloatToString(intensity, sTemp, sizeof sTemp);
	DispatchKeyValue(entity, "amplitude", sTemp);
	DispatchKeyValue(entity, "frequency", "1.5");
	DispatchKeyValue(entity, "duration", "0.9");
	FloatToString(range, sTemp, sizeof sTemp);
	DispatchKeyValue(entity, "radius", sTemp);
	DispatchKeyValue(entity, "spawnflags", "8");
	DispatchSpawn(entity);
	ActivateEntity(entity);
	AcceptEntityInput(entity, "Enable");

	TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(entity, "StartShake");
	RemoveEdict(entity);
}



// ====================================================================================================
//					STOCKS - HEALTH
// ====================================================================================================
float GetTempHealth(int client)
{
	float fGameTime = GetGameTime();
	float fHealthTime = GetEntPropFloat(client, Prop_Send, "m_healthBufferTime");
	float fHealth = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
	fHealth -= (fGameTime - fHealthTime) * g_hDecayDecay.FloatValue;
	return fHealth < 0.0 ? 0.0 : fHealth;
}

void SetTempHealth(int client, float fHealth)
{
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", fHealth < 0.0 ? 0.0 : fHealth );
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
}



// ====================================================================================================
//					STOCKS - HURT
// ====================================================================================================
void CreateHurtEntity()
{
	if( !g_iEntityHurt || EntRefToEntIndex(g_iEntityHurt) == INVALID_ENT_REFERENCE )
	{
		g_iEntityHurt = CreateEntityByName("point_hurt");
		DispatchKeyValue(g_iEntityHurt, "DamageTarget", "silvershot");
		DispatchSpawn(g_iEntityHurt);
		g_iEntityHurt = EntIndexToEntRef(g_iEntityHurt);
	}
}

void CreateFires(int target, int client, bool gascan)
{
	int entity = CreateEntityByName("prop_physics");
	if( entity != -1 )
	{
		if( gascan )		SetEntityModel(entity, MODEL_GASCAN);
		else				SetEntityModel(entity, MODEL_CRATE);

		float vPos[3];
		GetEntPropVector(target, Prop_Data, "m_vecOrigin", vPos);
		vPos[2] += 10.0;
		TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(entity);

		SetEntData(entity, GetEntSendPropOffs(entity, "m_CollisionGroup"), 1, 1, true);
		SetEntPropEnt(entity, Prop_Data, "m_hPhysicsAttacker", client);
		SetEntPropFloat(entity, Prop_Data, "m_flLastPhysicsInfluenceTime", GetGameTime());
		SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
		SetEntityRenderColor(entity, 0, 0, 0, 0);
		AcceptEntityInput(entity, "Break");
	}
}

void InputKill(int entity, float time)
{
	char temp[40];
	Format(temp, sizeof temp, "OnUser4 !self:Kill::%f:-1", time);
	SetVariantString(temp);
	AcceptEntityInput(entity, "AddOutput");
	AcceptEntityInput(entity, "FireUser4");
}



// ====================================================================================================
//					STOCKS - TRIGGER
// ====================================================================================================
void TriggerMultipleDamage(int entity, int index, float range, float vPos[3])
{
	int trigger = CreateEntityByName("trigger_multiple");
	DispatchKeyValue(trigger, "spawnflags", "1");
	DispatchKeyValue(trigger, "entireteam", "0");
	DispatchKeyValue(trigger, "allowincap", "1");
	DispatchKeyValue(trigger, "allowghost", "0");
	SetEntityModel(trigger, MODEL_BOUNDING);
	DispatchSpawn(trigger);

	SetEntProp(trigger, Prop_Data, "m_iHammerID", index);
	SetEntProp(trigger, Prop_Send, "m_nSolidType", 2);

	// Box size
	range /= 2;
	float vMins[3];
	vMins[0] = -range;
	vMins[1] = -range;
	float vMaxs[3];
	vMaxs[0] = range;
	vMaxs[1] = range;
	vMaxs[2] = 70.0;

	SetEntPropVector(trigger, Prop_Send, "m_vecMins", vMins);
	SetEntPropVector(trigger, Prop_Send, "m_vecMaxs", vMaxs);

	TeleportEntity(trigger, vPos, NULL_VECTOR, NULL_VECTOR);
	SetVariantString("!activator");
	AcceptEntityInput(trigger, "SetParent", entity);

	// Collision hooks
	SDKHook(trigger, SDKHook_Touch, OnTouchTriggerMultple);

	// Freezer collision
	if( index - 1 == INDEX_FREEZER && (g_GrenadeTarg[INDEX_FREEZER] & (1 << TARGET_COMMON) || g_GrenadeTarg[INDEX_FREEZER] & (1 << TARGET_WITCH)) ) // Freezer and common only
		SDKHook(trigger, SDKHook_StartTouch, OnTouchTriggerFreezer2);
}

public void OnTouchTriggerMultple(int trigger, int target)
{
	// Check duration
	int index = GetEntProp(trigger, Prop_Data, "m_iHammerID") - 1;

	// Check classname
	char classname[12];
	GetEdictClassname(target, classname, sizeof classname);
	if(
		(index == INDEX_SHIELD && strcmp(classname, "player")) ||
		(index != INDEX_SHIELD && strcmp(classname, "player") == 0 || strcmp(classname, "infected") == 0 || strcmp(classname, "witch") == 0)
	)
	{
		switch( index )
		{
			case INDEX_FREEZER:	OnTouchTriggerFreezer	(trigger, target);
			case INDEX_SHIELD:	OnTouchTriggerShield	(trigger, target);
		}
	}
}



// ====================================================================================================
//					STOCKS - FX
// ====================================================================================================
int MakeLightDynamic(int target, const float vPos[3])
{
	int entity = CreateEntityByName("light_dynamic");
	if( entity == -1 )
	{
		LogError("Failed to create 'light_dynamic'");
		return 0;
	}

	DispatchKeyValue(entity, "_light", "0 255 0 0");
	DispatchKeyValue(entity, "brightness", "0.1");
	DispatchKeyValueFloat(entity, "spotlight_radius", 32.0);
	DispatchKeyValueFloat(entity, "distance", 600.0);
	DispatchKeyValue(entity, "style", "6");
	DispatchSpawn(entity);
	AcceptEntityInput(entity, "TurnOff");

	TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);

	// Attach
	if( target )
	{
		SetVariantString("!activator");
		AcceptEntityInput(entity, "SetParent", target);
	}

	return entity;
}

void MakeEnvSteam(int target, const float vPos[3], const float vAng[3], const char[] sColor)
{
	int entity = CreateEntityByName("env_steam");
	if( entity == -1 )
	{
		LogError("Failed to create 'env_steam'");
		return;
	}

	char sTemp[32];
	Format(sTemp, sizeof sTemp, "silv_steam_%d", target);
	DispatchKeyValue(entity, "targetname", sTemp);
	DispatchKeyValue(entity, "SpawnFlags", "1");
	DispatchKeyValue(entity, "rendercolor", sColor);
	DispatchKeyValue(entity, "SpreadSpeed", "10");
	DispatchKeyValue(entity, "Speed", "100");
	DispatchKeyValue(entity, "StartSize", "5");
	DispatchKeyValue(entity, "EndSize", "10");
	DispatchKeyValue(entity, "Rate", "50");
	DispatchKeyValue(entity, "JetLength", "100");
	DispatchKeyValue(entity, "renderamt", "150");
	DispatchKeyValue(entity, "InitialState", "1");
	DispatchSpawn(entity);
	AcceptEntityInput(entity, "TurnOn");
	TeleportEntity(entity, vPos, vAng, NULL_VECTOR);

	// Attach
	if( target )
	{
		SetVariantString("!activator");
		AcceptEntityInput(entity, "SetParent", target);
	}

	return;
}

void CreateEnvSprite(int target, const char[] sColor)
{
	int entity = CreateEntityByName("env_sprite");
	if( entity == -1)
	{
		LogError("Failed to create 'env_sprite'");
		return;
	}

	DispatchKeyValue(entity, "rendercolor", sColor);
	DispatchKeyValue(entity, "model", MODEL_SPRITE);
	DispatchKeyValue(entity, "spawnflags", "3");
	DispatchKeyValue(entity, "rendermode", "9");
	DispatchKeyValue(entity, "GlowProxySize", "0.1");
	DispatchKeyValue(entity, "renderamt", "175");
	DispatchKeyValue(entity, "scale", "0.1");
	DispatchSpawn(entity);

	// Attach
	if( target )
	{
		SetVariantString("!activator");
		AcceptEntityInput(entity, "SetParent", target);
	}
}

void CreateBeamRing(int entity, int iColor[4], float min, float max)
{
	// Grenade Pos
	float vPos[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vPos);

	// Make beam rings
	for( int i = 1; i <= BEAM_RINGS; i++ )
	{
		vPos[2] += 20;
		TE_SetupBeamRingPoint(vPos, min, max, g_BeamSprite, g_HaloSprite, 0, 15, 1.0, 1.0, 2.0, iColor, 20, 0);
		TE_SendToAll();
	}
}



// ====================================================================================================
//					STOCKS - PARTICLES
// ====================================================================================================
int DisplayParticle(int target, const char[] sParticle, const float vPos[3], const float vAng[3], float refire = 0.0)
{
	int entity = CreateEntityByName("info_particle_system");
	if( entity == -1)
	{
		LogError("Failed to create 'info_particle_system'");
		return 0;
	}

	DispatchKeyValue(entity, "effect_name", sParticle);
	DispatchSpawn(entity);
	ActivateEntity(entity);
	AcceptEntityInput(entity, "start");
	TeleportEntity(entity, vPos, vAng, NULL_VECTOR);

	// Refire
	if( refire )
	{
		char sTemp[64];
		Format(sTemp, sizeof sTemp, "OnUser1 !self:Stop::%f:-1", refire - 0.05);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		Format(sTemp, sizeof sTemp, "OnUser1 !self:FireUser2::%f:-1", refire);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser1");

		SetVariantString("OnUser2 !self:Start::0:-1");
		AcceptEntityInput(entity, "AddOutput");
		SetVariantString("OnUser2 !self:FireUser1::0:-1");
		AcceptEntityInput(entity, "AddOutput");
	}

	// Attach
	if( target )
	{
		SetVariantString("!activator"); 
		AcceptEntityInput(entity, "SetParent", target);
	}

	return entity;
}

int PrecacheParticle(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;

	if( table == INVALID_STRING_TABLE )
	{
		table = FindStringTable("ParticleEffectNames");
	}

	int index = FindStringIndex(table, sEffectName);
	if( index == INVALID_STRING_INDEX )
	{
		bool save = LockStringTables(false);
		AddToStringTable(table, sEffectName);
		LockStringTables(save);
		index = FindStringIndex(table, sEffectName);
	}

	return index;
}



// ====================================================================================================
//					STOCKS - TRACERAY
// ====================================================================================================
stock bool IsVisibleTo(float position[3], float targetposition[3])
{
	float vAngles[3], vLookAt[3];
	position[2] += 50.0;

	MakeVectorFromPoints(position, targetposition, vLookAt); // compute vector from start to target
	GetVectorAngles(vLookAt, vAngles); // get angles from vector for trace

	// execute Trace
	Handle trace = TR_TraceRayFilterEx(position, vAngles, MASK_ALL, RayType_Infinite, _TraceFilter);

	bool isVisible = false;
	if( TR_DidHit(trace) )
	{
		float vStart[3];
		TR_GetEndPosition(vStart, trace); // retrieve our trace endpoint

		if( GetVectorDistance(position, vStart) + 25.0 >= GetVectorDistance(position, targetposition) )
			isVisible = true; // if trace ray length plus tolerance equal or bigger absolute distance, you hit the target
	}
	else
		isVisible = false;

	position[2] -= 50.0;
	delete trace;
	return isVisible;
}

public bool _TraceFilter(int entity, int contentsMask)
{
	if( !entity || !IsValidEntity(entity) ) // dont let WORLD, or invalid ents be hit
		return false;

	// Don't hit triggers
	char classname[12];
	GetEdictClassname(entity, classname, sizeof classname);
	if(
		classname[0] == 't' &&
		classname[1] == 'r' &&
		classname[2] == 'i' &&
		classname[3] == 'g' &&
		classname[4] == 'g' &&
		classname[5] == 'e' &&
		classname[6] == 'r' &&
		classname[7] == '_'
	)
	{
		return false;
	}

	return true;
}

bool SetTeleportEndPoint(int client, float vPos[3])
{
	GetClientEyePosition(client, vPos);
	float vAng[3];
	GetClientEyeAngles(client, vAng);

	Handle trace = TR_TraceRayFilterEx(vPos, vAng, MASK_SHOT, RayType_Infinite, ExcludeSelf_Filter, client);

	if(TR_DidHit(trace))
	{
		TR_GetEndPosition(vPos, trace);

		float vDir[3];
		GetAngleVectors(vAng, vDir, NULL_VECTOR, NULL_VECTOR);
		vPos[0] -= vDir[0] * 10;
		vPos[1] -= vDir[1] * 10;
		vPos[2] -= vDir[2] * 10;
	}
	else
	{
		delete trace;
		return false;
	}
	delete trace;
	return true;
}

public bool ExcludeSelf_Filter(int entity, int contentsMask, any client)
{
	if( entity == client )
		return false;
	return true;
}



// ====================================================================================================
//					STOCKS - TEMPENT PARTICLE - By Lux
// ====================================================================================================
/*
*	iParticleIndex = "ParticleString" index location in String table "ParticleEffectNames"
*	iEntIndex = entity index usually used for attachpoints
*	fDelay = delay for TE_SendToAll
*	SendToAll = if send to all false call send to clients your self
*	sParticleName =  particle name only used if iParticleIndex -1 it will find the index for you
*	iAttachmentIndex =  attachpoint index there is no way to get this currently with sm, gotta decompile the model :p
*	ParticleAngles =  angles usually effects particles that have no gravity
*	iFlags = 1 required for attachpoints as well as damage type ^^
*	iDamageType = saw it being used in impact effect dispatch and attachpoints need to be set to use (maybe)
*	fMagnitude = no idea saw being used with pipebomb blast (needs testing)
*	fScale = guess its particle scale but most dont scale (needs testing)
*/
stock bool L4D_TE_Create_Particle(float fParticleStartPos[3]={0.0, 0.0, 0.0}, 
								float fParticleEndPos[3]={0.0, 0.0, 0.0}, 
								int iParticleIndex=-1, 
								int iEntIndex=0,
								float fDelay=0.0,
								bool SendToAll=true,
								char sParticleName[64]="",
								int iAttachmentIndex=0,
								float fParticleAngles[3]={0.0, 0.0, 0.0}, 
								int iFlags=0,
								int iDamageType=0,
								float fMagnitude=0.0,
								float fScale=1.0,
								float fRadius=0.0)
{
	TE_Start("EffectDispatch");
	TE_WriteFloat("m_vOrigin.x", fParticleStartPos[0]);
	TE_WriteFloat("m_vOrigin.y", fParticleStartPos[1]);
	TE_WriteFloat("m_vOrigin.z", fParticleStartPos[2]);
	TE_WriteFloat("m_vStart.x", fParticleEndPos[0]);//end point usually for bulletparticles or ropes
	TE_WriteFloat("m_vStart.y", fParticleEndPos[1]);
	TE_WriteFloat("m_vStart.z", fParticleEndPos[2]);
	
	static int iEffectIndex = INVALID_STRING_INDEX;
	if(iEffectIndex < 0)
	{
		iEffectIndex = __FindStringIndex2(FindStringTable("EffectDispatch"), "ParticleEffect");
		if(iEffectIndex == INVALID_STRING_INDEX)
			SetFailState("Unable to find EffectDispatch/ParticleEffect indexes");
		
	}
	
	TE_WriteNum("m_iEffectName", iEffectIndex);
	
	if(iParticleIndex < 0)
	{
		static int iParticleStringIndex = INVALID_STRING_INDEX;
		iParticleStringIndex = __FindStringIndex2(iEffectIndex, sParticleName);
		if(iParticleStringIndex == INVALID_STRING_INDEX)
			return false;
		
		TE_WriteNum("m_nHitBox", iParticleStringIndex);
	}
	else
		TE_WriteNum("m_nHitBox", iParticleIndex);
	
	TE_WriteNum("entindex", iEntIndex);
	TE_WriteNum("m_nAttachmentIndex", iAttachmentIndex);
	
	TE_WriteVector("m_vAngles", fParticleAngles);
	
	TE_WriteNum("m_fFlags", iFlags);
	TE_WriteFloat("m_flMagnitude", fMagnitude);// saw this being used in pipebomb needs testing what it does probs shaking screen?
	TE_WriteFloat("m_flScale", fScale);
	TE_WriteFloat("m_flRadius", fRadius);// saw this being used in pipebomb needs testing what it does probs shaking screen?
	TE_WriteNum("m_nDamageType", iDamageType);// this shit is required dunno why for attachpoint emitting valve probs named it wrong
	
	if(SendToAll)
		TE_SendToAll(fDelay);
	
	return true;
}

//Credit smlib https://github.com/bcserv/smlib
/*
 * Rewrite of FindStringIndex, because in my tests
 * FindStringIndex failed to work correctly.
 * Searches for the index of a given string in a string table. 
 * 
 * @param tableidx		A string table index.
 * @param str			String to find.
 * @return				String index if found, INVALID_STRING_INDEX otherwise.
 */
stock int __FindStringIndex2(int tableidx, const char[] str)
{
	char buf[1024];

	int numStrings = GetStringTableNumStrings(tableidx);
	for (int i=0; i < numStrings; i++) {
		ReadStringTable(tableidx, i, buf, sizeof(buf));
		
		if (StrEqual(buf, str)) {
			return i;
		}
	}
	
	return INVALID_STRING_INDEX;
}