#define PLUGIN_VERSION		"1.8"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D2] Weather Control
*	Author	:	SilverShot
*	Descrp	:	Create storms, lightning, fog, rain, wind, changes the skybox, sun and background colors.
*	Link	:	http://forums.alliedmods.net/showthread.php?t=184890
*	Plugins	:	http://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.8 (14-Aug-2018)
	- Added cvar "l4d2_storm_random" to control if a new weather preset is selected from the "random" section on each chapter or only the first.
	- Added data config key "rain_type", to control which type of rain to use. 0=Default. 4=Particle Rain. 6=Particle Rain Storm.
	- Copied 'Hard Rain' rain values as suggested by "Lux".
	- Rain particles (not type 0), are invisible to clients with low graphic settings, and in some parts of maps (due to how the engine works).

1.7 (05-May-2018)
	- Converted plugin source to the latest syntax utilizing methodmaps. Requires SourceMod 1.8 or newer.

1.6 (12-Aug-2013)
	- Added snow.
	- Added command "sm_stormconfig" to show which section has loaded from the data config.
	- Added command "sm_snows" to toggle snow on and off.
	- Added data config keys "snow", "snow_idle", "snow_storm", to control when snow is enabled.
	- Fixed duplicate key entry for "fog_idle_start" in the data. Replaced with the correct "fog_storm_start" key.

1.5 (23-May-2012)
	- Missing data config keys "rain_idle" and "rain_storm" will use default values "75" and "250" respectively.
	- Fixed creating entities when the map has not started.

1.4 (21-May-2012)
	- Fixed the fog disappearing when weather is reset during a transition between idle/storm.

1.3 (20-May-2012)
	- Added data config keys "rain_idle" and "rain_storm" to control the visibility of rain, requested by "adrianman".

1.2 (17-May-2012)
	- Fixed a bug with the fog when resetting the map, which caused the bots to not see properly.

1.1 (15-May-2012)
	- Added cvar "l4d2_storm_style". Method to refresh map light style: 0=Old (0.2 sec low FPS, does not the whole world). 1=Almost always lights the whole world (0.5 sec low FPS), 2=Lights the whole world (1 sec low FPS).
	- Added command "sm_farz" to set the maps far z-clip. This will make the map stop rendering stuff after the specified distance.
	- Added data config keys "far_z_idle" and "far_z_storm" which control the maps far z-clip when the weather is idle/storm.
	- Added data config key "lightning_time" to control how long fires burn when lightning strikes the ground.

1.0 (10-May-2012)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define CVAR_FLAGS			FCVAR_NOTIFY
#define CHAT_TAG			"\x03[STORM] \x05"
#define CONFIG_SETTINGS		"data/l4d2_storm.cfg"
#define CONFIG_TRIGGERS		"data/l4d2_storm_triggers.cfg"

#define MODEL_BOUNDING		"models/props/cs_militia/silo_01.mdl"

#define PARTICLE_FIRE		"fire_medium_base"
#define PARTICLE_FOG		"storm_cloud_parent"
#define PARTICLE_GLOW		"storm_lightning_screenglow"
#define PARTICLE_LIGHT1		"storm_lightning_01"
#define PARTICLE_LIGHT2		"storm_lightning_02"

#define	SOUND_STORM1		"ambient/ambience/rainscapes/Thunder_close01.wav"
#define	SOUND_STORM2		"ambient/ambience/rainscapes/Thunder_close02.wav"
#define	SOUND_STORM3		"ambient/ambience/rainscapes/Thunder_close03.wav"
#define	SOUND_STORM4		"ambient/ambience/rainscapes/Thunder_close04.wav"
#define	SOUND_STORM5		"ambient/ambience/rainscapes/thunder_distant01.wav"
#define	SOUND_STORM6		"ambient/ambience/rainscapes/thunder_distant02.wav"
#define	SOUND_STORM7		"ambient/ambience/rainscapes/thunder_distant03.wav"
#define	SOUND_STORM8		"ambient/weather/thunderstorm/lightning_strike_1.wav"
#define	SOUND_STORM9		"ambient/weather/thunderstorm/lightning_strike_2.wav"
#define	SOUND_STORM10		"ambient/weather/thunderstorm/lightning_strike_3.wav"
#define	SOUND_STORM11		"ambient/weather/thunderstorm/lightning_strike_4.wav"
#define	SOUND_STORM12		"ambient/weather/thunderstorm/thunder_1.wav"
#define	SOUND_STORM13		"ambient/weather/thunderstorm/thunder_2.wav"
#define	SOUND_STORM14		"ambient/weather/thunderstorm/thunder_3.wav"
#define	SOUND_STORM15		"ambient/weather/thunderstorm/thunder_far_away_1.wav"
#define	SOUND_STORM16		"ambient/weather/thunderstorm/thunder_far_away_2.wav"

#define	SOUND_RAIN1			"ambient/weather/crucial_rumble_rain_nowind.wav"
#define	SOUND_RAIN2			"ambient/water/water_flow_loop1.wav"
#define	SOUND_RAIN3			"ambient/ambience/rainscapes/rain/crucial_surfacerain_light_loop.wav"
#define	SOUND_RAIN4			"ambient/ambience/rainscapes/rain/crucial_int_rainverb_med_loop.wav"
#define	SOUND_RAIN5			"ambient/ambience/rainscapes/crucial_int_rainverb_hard_loop.wav"
#define	SOUND_RAIN6			"ambient/weather/crucial_rumble_rain.wav"
#define	SOUND_RAIN7			"ambient/ambience/rainscapes/crucial_surfacerain_hard_loop.wav"
#define	SOUND_RAIN8			"ambient/ambience/rainscapes/crucial_surfacerain_med_loop.wav"
#define	SOUND_RAIN9			"ambient/ambience/rainscapes/crucial_waterrain_hard_loop.wav"
#define	SOUND_RAIN10		"ambient/ambience/rainscapes/rain/interior_rain_med_loop.wav"

#define	SOUND_WIND1			"ambient/wind/crucial_wind_outdoors_1.wav"
#define	SOUND_WIND2			"ambient/ambience/streetwind01_loop.wav"
#define	SOUND_WIND3			"ambient/ambience/crucial_empty_street_wind_loop.wav"
#define	SOUND_WIND4			"ambient/ambience/crucial_urb4b_topfloorwind_loop.wav"
#define	SOUND_WIND5			"vehicles/helicopter/helicopterwind_loop.wav"
#define	SOUND_WIND6			"ambient/ambience/rainscapes/rain/whistle_debris_loop.wav"
#define	SOUND_WIND7			"ambient/ambience/rainscapes/rain/crucial_wind_rain_loop.wav"
#define	SOUND_WIND8			"ambient/ambience/rainscapes/rain/debris_loop.wav"

#define MAX_ALLOWED			10
#define MAX_ENTITIES		16
#define MAX_TRIGGERS		7
#define	MAX_RAIN			8
#define	MAX_FOG				16

enum ()
{
	STATE_OFF,
	STATE_IDLE,
	STATE_SURGE,
	STATE_STORM,
	STATE_END
}

Handle g_hTmrEndStorm, g_hTmrTimeout, g_hTmrTrigger;
ConVar g_hCvarAllow, g_hCvarMPGameMode, g_hCvarMixer, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarPost, g_hCvarRand, g_hCvarSkyName, g_hCvarStyle;
int g_iChance, g_iCvarMixer, g_iCvarRand, g_iCvarStyle, g_iLateLoad, g_iPlayerSpawn, g_iRandom, g_iReset, g_iRoundStart, g_iStarted, g_iStormState;
bool g_bCvarAllow, g_bLoaded;
float g_fCvarPost;

// Menu // Trigger boxes // Light Style
Handle g_hTmrBeam;
Menu g_hMenuMain, g_hMenuPos, g_hMenuVMaxs, g_hMenuVMins;
int g_iHaloMaterial, g_iLaserMaterial, g_iTriggerCount, g_iTriggerSelected, g_iLightStyle[MAXPLAYERS+1], g_iTriggerCfgIndex[MAXPLAYERS+1], g_iTriggers[MAX_TRIGGERS];

// Fog: saved // data settings
int g_iSunSaved = -1;
int g_iCfgFogBlend, g_iCfgFogIdle2, g_iCfgFogIdle, g_iCfgFogStorm2, g_iCfgFogStorm, g_iCfgFogZIdle, g_iCfgFogZStorm, g_iFog, g_iFogOn, g_iFogStolen[MAX_FOG][5], g_iParticleFog;
float g_fCfgFogOpaqueIdle, g_fCfgFogOpaqueStorm, g_fFogStolen[MAX_FOG][9];
char g_sCfgFogColor[16], g_sFogStolen[MAX_FOG][64];

// Other data settings
int g_iCfgBackground, g_iCfgClouds, g_iCfgLight, g_iCfgLightDmg, g_iCfgLightFlash, g_iCfgLightTime, g_iCfgRain, g_iCfgRainType, g_iCfgRainIdle, g_iCfgRainStorm, g_iCfgSnow, g_iCfgSnowIdle, g_iCfgSnowStorm, g_iCfgWind;
char g_sCfgLightStyle[64], g_sSkyBox[64];

// Storm state triggers
int g_iCfgFinale, g_iCfgForever, g_iCfgHorde, g_iCfgPanic, g_iCfgTank, g_iCfgTankDeath, g_iCfgTimeMax, g_iCfgTimeMin, g_iCfgTimeout, g_iCfgTimer, g_iCfgWitch, g_iCfgWitchAlert, g_iCfgWitchHead, g_iFogVolume, g_iLight, g_iLogicDirector, g_iLogicIn, g_iLogicOut, g_iPointCmd, g_iPostProcess, g_iRains[MAX_RAIN], g_iSkyCam[2], g_iSkyCamera, g_iSnow, g_iSound, g_iStormLayer, g_iVoip, g_iVoipIn, g_iVoipOut, g_iWind;

char g_sConfigSection[64];



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D2] Weather Control",
	author = "SilverShot",
	description = "Create storms, lightning, fog, rain, wind, changes the skybox, sun and background colors.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=184890"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}

	g_iLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "%s", CONFIG_SETTINGS);
	if( FileExists(sPath) == false )
		SetFailState("Plugin requires data file: %s.", sPath);

	g_hCvarSkyName = FindConVar("sv_skyname");
	if( g_hCvarSkyName == null )
		SetFailState("Cannot find the ConVar handle for 'sv_skyname'");
	g_hCvarSkyName.AddChangeHook(ConVarChanged_SkyBox);

	g_hCvarAllow = CreateConVar(		"l4d2_storm_allow",			"1",			"0=Plugin off, 1=Plugin on.", CVAR_FLAGS);
	g_hCvarModes =	CreateConVar(		"l4d2_storm_modes",			"",				"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS);
	g_hCvarModesOff =	CreateConVar(	"l4d2_storm_modes_off",		"",				"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog = CreateConVar(		"l4d2_storm_modes_tog",		"0",			"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	g_hCvarMixer =	CreateConVar(		"l4d2_storm_mixer",			"1",			"0=Off, 1=Turn down the voip voice transmit volume during the storm state.", CVAR_FLAGS);
	g_hCvarPost =	CreateConVar(		"l4d2_storm_post",			"-0.25",		"0.0=Off. Applies post process effect during the storm state. Value near 0 will blur, lower values cause other effects.", CVAR_FLAGS);
	g_hCvarRand =	CreateConVar(		"l4d2_storm_random",		"1",			"0=Off. 1=On. Select a new weather preset from the random section when changing chapter.", CVAR_FLAGS);
	g_hCvarStyle =	CreateConVar(		"l4d2_storm_style",			"1",			"Method to refresh map light style: 0=Old (0.2 sec low FPS, does not the whole world). 1=Almost always lights the whole world (0.5 sec low FPS), 2=Lights the whole world (1 sec low FPS).", CVAR_FLAGS);
	CreateConVar(						"l4d2_storm_version",		PLUGIN_VERSION,	"Weather Control plugin version.", CVAR_FLAGS|FCVAR_DONTRECORD);
	AutoExecConfig(true,				"l4d2_storm");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarMixer.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarPost.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarRand.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarStyle.AddChangeHook(ConVarChanged_Cvars);

	RegAdminCmd(	"sm_storm",			CmdStormMenu,		ADMFLAG_ROOT,	"Opens the Storm menu.");
	RegAdminCmd(	"sm_stormstart",	CmdStormStart,		ADMFLAG_ROOT,	"Starts the Storm if possible.");
	RegAdminCmd(	"sm_stormstop",		CmdStormStop,		ADMFLAG_ROOT,	"Stops the Storm if possible.");
	RegAdminCmd(	"sm_stormrefresh",	CmdStormRefresh,	ADMFLAG_ROOT,	"Refresh the plugin, reloading the config and storm.");
	RegAdminCmd(	"sm_stormreset",	CmdStormReset,		ADMFLAG_ROOT,	"Stops the storm and resets the weather to the maps default.");
	RegAdminCmd(	"sm_stormconfig",	CmdStormConfig,		ADMFLAG_ROOT,	"Display the currently loaded section from the data config.");
	RegAdminCmd(	"sm_lightning",		CmdLightning,		ADMFLAG_ROOT,	"Creates a Lightning Strike.");
	RegAdminCmd(	"sm_background",	CmdBackground,		ADMFLAG_ROOT,	"Set the background color. Reset with no args. Set the color with three values between 0-255 separated by spaces: sm_background <r> <g> <b>.");
	RegAdminCmd(	"sm_farz",			CmdFarZ,			ADMFLAG_ROOT,	"Set the maps far z-clip. This will make the map stop rendering stuff after the specified distance. Usage: sm_farz <distance>.");
	RegAdminCmd(	"sm_maplight",		CmdMapLight,		ADMFLAG_ROOT,	"Set the maps lighting. Reset with no args. Usage: sm_maplight: <chars a-z, 1-64 chars allowed. More info: http://developer.valvesoftware.com/wiki/Light#Appearances");
	RegAdminCmd(	"sm_fog",			CmdFog,				ADMFLAG_ROOT,	"No args toggles the fog on/off. Set the color with three values between 0-255 separated by spaces: sm_fog <r> <g> <b>.");
	RegAdminCmd(	"sm_rains",			CmdRain,			ADMFLAG_ROOT,	"Toggles the rain on/off.");
	RegAdminCmd(	"sm_snows",			CmdSnow,			ADMFLAG_ROOT,	"Toggles the snow on/off.");
	RegAdminCmd(	"sm_wind",			CmdWind,			ADMFLAG_ROOT,	"Toggles the wind on/off.");
	RegAdminCmd(	"sm_sun",			CmdSun,				ADMFLAG_ROOT,	"Set the sun color. Reset with no args. Turn off: sm_sun 0. Set the color with three values between 0-255 separated by spaces: sm_sun <r> <g> <b>.");
	RegAdminCmd(	"sm_stormset",		CmdStormSet,		ADMFLAG_ROOT,	"Sets the fog, background and sun color. Reset with no args. Set the color with three values between 0-255 separated by spaces: sm_stormset <r> <g> <b>.");

	g_hMenuMain = new Menu(MainMenuHandler);
	g_hMenuMain.AddItem("", "Start Storm");
	g_hMenuMain.AddItem("", "Stop Storm");
	g_hMenuMain.AddItem("", "Reset Weather");
	g_hMenuMain.AddItem("", "Triggers");
	g_hMenuMain.AddItem("", "Refresh");
	g_hMenuMain.SetTitle("Weather Control");
	g_hMenuMain.ExitButton = true;

	g_hMenuVMaxs = new Menu(VMaxsMenuHandler);
	g_hMenuVMaxs.AddItem("", "10 x 10 x 100");
	g_hMenuVMaxs.AddItem("", "25 x 25 x 100");
	g_hMenuVMaxs.AddItem("", "50 x 50 x 100");
	g_hMenuVMaxs.AddItem("", "100 x 100 x 100");
	g_hMenuVMaxs.AddItem("", "150 x 150 x 100");
	g_hMenuVMaxs.AddItem("", "200 x 200 x 100");
	g_hMenuVMaxs.AddItem("", "250 x 250 x 100");
	g_hMenuVMaxs.SetTitle("Storm - Trigger VMaxs");
	g_hMenuVMaxs.ExitBackButton = true;

	g_hMenuVMins = new Menu(VMinsMenuHandler);
	g_hMenuVMins.AddItem("", "-10 x -10 x 0");
	g_hMenuVMins.AddItem("", "-25 x -25 x 0");
	g_hMenuVMins.AddItem("", "-50 x -50 x 0");
	g_hMenuVMins.AddItem("", "-100 x -100 x 0");
	g_hMenuVMins.AddItem("", "-150 x -150 x 0");
	g_hMenuVMins.AddItem("", "-200 x -200 x 0");
	g_hMenuVMins.AddItem("", "-250 x -250 x 0");
	g_hMenuVMins.SetTitle("Storm - Trigger VMins");
	g_hMenuVMins.ExitBackButton = true;

	g_hMenuPos = new Menu(PosMenuHandler);
	g_hMenuPos.AddItem("", "X + 1.0");
	g_hMenuPos.AddItem("", "Y + 1.0");
	g_hMenuPos.AddItem("", "Z + 1.0");
	g_hMenuPos.AddItem("", "X - 1.0");
	g_hMenuPos.AddItem("", "Y - 1.0");
	g_hMenuPos.AddItem("", "Z - 1.0");
	g_hMenuPos.AddItem("", "SAVE");
	g_hMenuPos.SetTitle("Storm - Set Origin");
	g_hMenuPos.ExitBackButton = true;
}

public void OnPluginEnd()
{
	ResetPlugin();
}

public void OnMapStart()
{
	if( g_iLateLoad )
	{
		g_iStarted = 2;
		g_iLateLoad = 0;
	}

	if( g_iStarted == 0 && g_iPlayerSpawn == 1 && g_iRoundStart == 1 )
	{
		LoadStorm();
		g_iReset = 0;
	}

	if( g_iStarted == 0 )
		g_iStarted = 1;
	else if( g_iStarted == 1 )
		g_iStarted = 2;

	if( g_iCvarRand || (g_iCvarRand == 0 && IsStartOrEndMap() && !IsFinalMap()) )
		g_iRandom = 0;

	g_iLaserMaterial = PrecacheModel("materials/sprites/laserbeam.vmt");
	g_iHaloMaterial = PrecacheModel("materials/sprites/halo01.vmt");
	PrecacheModel(MODEL_BOUNDING, true);

	PrecacheSound(SOUND_RAIN1, true);
	PrecacheSound(SOUND_RAIN2, true);
	PrecacheSound(SOUND_RAIN3, true);
	PrecacheSound(SOUND_RAIN4, true);
	PrecacheSound(SOUND_RAIN5, true);
	PrecacheSound(SOUND_RAIN6, true);
	PrecacheSound(SOUND_RAIN7, true);
	PrecacheSound(SOUND_RAIN8, true);
	PrecacheSound(SOUND_RAIN9, true);
	PrecacheSound(SOUND_RAIN10, true);

	PrecacheSound(SOUND_STORM1, true);
	PrecacheSound(SOUND_STORM2, true);
	PrecacheSound(SOUND_STORM3, true);
	PrecacheSound(SOUND_STORM4, true);
	PrecacheSound(SOUND_STORM5, true);
	PrecacheSound(SOUND_STORM6, true);
	PrecacheSound(SOUND_STORM7, true);
	PrecacheSound(SOUND_STORM8, true);
	PrecacheSound(SOUND_STORM9, true);
	PrecacheSound(SOUND_STORM10, true);
	PrecacheSound(SOUND_STORM11, true);
	PrecacheSound(SOUND_STORM12, true);
	PrecacheSound(SOUND_STORM13, true);
	PrecacheSound(SOUND_STORM14, true);
	PrecacheSound(SOUND_STORM15, true);
	PrecacheSound(SOUND_STORM16, true);

	PrecacheSound(SOUND_WIND1, true);
	PrecacheSound(SOUND_WIND2, true);
	PrecacheSound(SOUND_WIND3, true);
	PrecacheSound(SOUND_WIND4, true);
	PrecacheSound(SOUND_WIND5, true);
	PrecacheSound(SOUND_WIND6, true);
	PrecacheSound(SOUND_WIND7, true);
	PrecacheSound(SOUND_WIND8, true);

	PrecacheParticle(PARTICLE_FIRE);
	PrecacheParticle(PARTICLE_FOG);
	PrecacheParticle(PARTICLE_GLOW);
	PrecacheParticle(PARTICLE_LIGHT1);
	PrecacheParticle(PARTICLE_LIGHT2);
}

public void OnMapEnd()
{
	g_iReset = 0;
	ResetPlugin();
	g_iStarted = 0;
}

void ResetPlugin()
{
	ChangeLightStyle("m");
	SetBackground(true);
	StopAmbientSound();

	for( int i = 1; i <= MAXPLAYERS; i++ )
		g_iLightStyle[i] = 0;

	if( g_iReset == 0 )
		g_iChance = 0;
	else
		g_iReset = 0;

	g_bLoaded = false;
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
	g_iTriggerCount = 0;
	g_iStormState = STATE_OFF;

	if( g_iSunSaved != -1 )
	{
		ToggleEnvSun(g_iSunSaved);
		g_iSunSaved = -1;
	}

	if( IsValidEntRef(g_iLogicIn) )
	{
		AcceptEntityInput(g_iLogicIn, "CancelPending");
		AcceptEntityInput(g_iLogicIn, "Kill");
	}
	g_iLogicIn = 0;

	if( IsValidEntRef(g_iLogicOut) )
	{
		AcceptEntityInput(g_iLogicOut, "CancelPending");
		AcceptEntityInput(g_iLogicOut, "Kill");
	}
	g_iLogicOut = 0;

	ResetFog();
	ResetVars();

	if( g_hTmrEndStorm != null ) delete g_hTmrEndStorm;
	if( g_hTmrTimeout != null ) delete g_hTmrTimeout;
	if( g_hTmrTrigger != null ) delete g_hTmrTrigger;
	if( g_hTmrBeam != null ) delete g_hTmrBeam;

	for( int i = 0; i < MAX_TRIGGERS; i++ )
	{
		if( IsValidEntRef(g_iTriggers[i]) )
		{
			AcceptEntityInput(g_iTriggers[i], "Kill");
			g_iTriggers[i] = 0;
		}
	}

	for( int i = 0; i < MAX_RAIN; i++ )
	{
		if( IsValidEntRef(g_iRains[i]) )
		{
			AcceptEntityInput(g_iRains[i], "Kill");
			g_iRains[i] = 0;
		}
	}

	if( IsValidEntRef(g_iFogVolume) )
		AcceptEntityInput(g_iFogVolume, "Kill");
	g_iFogVolume = 0;

	if( IsValidEntRef(g_iPostProcess) )
		AcceptEntityInput(g_iPostProcess, "Kill");
	g_iPostProcess = 0;

	if( IsValidEntRef(g_iLogicDirector) )
		AcceptEntityInput(g_iLogicDirector, "Kill");
	g_iLogicDirector = 0;

	if( IsValidEntRef(g_iStormLayer) )
		AcceptEntityInput(g_iStormLayer, "Kill");
	g_iStormLayer = 0;

	if( IsValidEntRef(g_iVoip) )
		AcceptEntityInput(g_iVoip, "Kill");
	g_iVoip = 0;

	if( IsValidEntRef(g_iVoipIn) )
		AcceptEntityInput(g_iVoipIn, "Kill");
	g_iVoipIn = 0;

	if( IsValidEntRef(g_iVoipOut) )
		AcceptEntityInput(g_iVoipOut, "Kill");
	g_iVoipOut = 0;

	if( IsValidEntRef(g_iPointCmd) )
		AcceptEntityInput(g_iPointCmd, "Kill");
	g_iPointCmd = 0;

	if( IsValidEntRef(g_iParticleFog) )
		AcceptEntityInput(g_iParticleFog, "Kill");
	g_iParticleFog = 0;

	if( IsValidEntRef(g_iLight) )
		AcceptEntityInput(g_iLight, "Kill");
	g_iLight = 0;

	if( IsValidEntRef(g_iWind) )
		AcceptEntityInput(g_iWind, "Kill");
	g_iWind = 0;
}

void ResetVars()
{
	strcopy(g_sSkyBox, sizeof(g_sSkyBox), "");
	strcopy(g_sCfgFogColor, sizeof(g_sCfgFogColor), "");
	strcopy(g_sCfgLightStyle, sizeof(g_sCfgLightStyle), "");
	g_iCfgFogBlend = -1;
	g_iCfgFogIdle =	0;
	g_iCfgFogStorm = 0;
	g_fCfgFogOpaqueIdle = 0.0;
	g_fCfgFogOpaqueStorm = 0.0;
	g_iCfgFogZIdle = 0;
	g_iCfgFogZStorm = 0;
	g_iCfgClouds = 0;
	g_iCfgLight = 0;
	g_iCfgLightDmg = 0;
	g_iCfgLightFlash = 0;
	g_iCfgRain = 0;
	g_iCfgRainType = 0;
	g_iCfgRainIdle = 0;
	g_iCfgRainStorm = 0;
	g_iCfgWind = 0;
	g_iCfgForever = 0;
	g_iCfgTimeout = 0;
	g_iCfgTimeMax = 0;
	g_iCfgTimeMin = 0;
	g_iCfgTimer = 0;
	g_iCfgFinale = 0;
	g_iCfgHorde = 0;
	g_iCfgPanic = 0;
	g_iCfgTank = 0;
	g_iCfgTankDeath = 0;
	g_iCfgWitch = 0;
	g_iCfgWitchHead = 0;
	g_iCfgWitchAlert = 0;
}

void ResetFog()
{
	if( g_iFogOn == 0 )
		return;
	g_iFogOn = 0;

	if( IsValidEntRef(g_iFog) )
	{
		AcceptEntityInput(g_iFog, "Kill");
		g_iFog  = 0;
	}

	int entity = -1;
	while( (entity = FindEntityByClassname(entity, "env_fog_controller")) != INVALID_ENT_REFERENCE )
	{
		for( int i = 0; i < MAX_FOG; i++ )
		{
			if( EntIndexToEntRef(entity) == g_iFogStolen[i][0] )
			{
				char temps[64];
				GetEntPropString(entity, Prop_Data,"m_iName", temps, 64);

				if( g_fFogStolen[i][1] == 0 )
					g_fFogStolen[i][1] = 10000.0;

				SetEntProp(entity, Prop_Data, "m_nNextThinkTick", -1);

				DispatchKeyValue(entity, "targetname", g_sFogStolen[i]);
				SetEntProp(entity, Prop_Send, "m_fog.colorPrimary", g_iFogStolen[i][1]);
				SetEntProp(entity, Prop_Send, "m_fog.colorSecondary", g_iFogStolen[i][2]);
				SetEntProp(entity, Prop_Send, "m_fog.colorPrimaryLerpTo", g_iFogStolen[i][3]);
				SetEntProp(entity, Prop_Send, "m_fog.colorSecondaryLerpTo", g_iFogStolen[i][4]);
				SetEntPropFloat(entity, Prop_Send, "m_fog.start", g_fFogStolen[i][0]);
				SetEntPropFloat(entity, Prop_Send, "m_fog.end", g_fFogStolen[i][1]);
				SetEntPropFloat(entity, Prop_Send, "m_fog.maxdensity", g_fFogStolen[i][2]);
				SetEntPropFloat(entity, Prop_Send, "m_fog.farz", g_fFogStolen[i][3]);
				SetEntPropFloat(entity, Prop_Send, "m_fog.skyboxFogFactor", g_fFogStolen[i][4]);
				SetEntPropFloat(entity, Prop_Send, "m_fog.startLerpTo", g_fFogStolen[i][5]);
				SetEntPropFloat(entity, Prop_Send, "m_fog.endLerpTo", g_fFogStolen[i][6]);
				SetEntPropFloat(entity, Prop_Send, "m_fog.maxdensityLerpTo", g_fFogStolen[i][7]);
				SetEntPropFloat(entity, Prop_Send, "m_fog.duration", g_fFogStolen[i][8]);
				SetEntPropFloat(entity, Prop_Send, "m_fog.lerptime", 1.0);

				strcopy(g_sFogStolen[i], 64, "");
				g_iFogStolen[i][0] = 0;
				g_iFogStolen[i][1] = 0;
				g_iFogStolen[i][2] = 0;
				g_iFogStolen[i][3] = 0;
				g_iFogStolen[i][4] = 0;
				g_fFogStolen[i][0] = 0.0;
				g_fFogStolen[i][1] = 0.0;
				g_fFogStolen[i][2] = 0.0;
				g_fFogStolen[i][3] = 0.0;
				g_fFogStolen[i][4] = 0.0;
				g_fFogStolen[i][5] = 0.0;
				g_fFogStolen[i][6] = 0.0;
				g_fFogStolen[i][7] = 0.0;
				g_fFogStolen[i][8] = 0.0;
				break;
			}
		}
	}
}



// ====================================================================================================
//					EVENTS
// ====================================================================================================
public void OnClientPutInServer(int client)
{
	if( g_iCfgWind )
	{
		if( g_iCfgWind == 1 )		EmitSoundToClient(client, SOUND_WIND1);
		else if( g_iCfgWind == 2 )	EmitSoundToClient(client, SOUND_WIND2, _, _, 43);
		else if( g_iCfgWind == 3 )	EmitSoundToClient(client, SOUND_WIND3, _, _, 43);
		else if( g_iCfgWind == 4 )	EmitSoundToClient(client, SOUND_WIND4, _, _, 42);
		else if( g_iCfgWind == 5 )	EmitSoundToClient(client, SOUND_WIND5, _, _, 42);
		else if( g_iCfgWind == 6 )	EmitSoundToClient(client, SOUND_WIND6, _, _, 42);
		else if( g_iCfgWind == 7 )	EmitSoundToClient(client, SOUND_WIND7, _, _, 42);
		else if( g_iCfgWind == 8 )	EmitSoundToClient(client, SOUND_WIND8, _, _, 42);
	}

	if( IsValidEntRef(g_iSound) )
	{
		SetVariantInt(10);
		AcceptEntityInput(g_iSound, "Volume");
		CreateTimer(0.1, TimerPlaySound, GetClientUserId(client));
	}
}

public Action TimerPlaySound(Handle timer, any client)
{
	client = GetClientOfUserId(client);
	if( client )
	{
		if( IsValidEntRef(g_iSound) )
		{
			SetVariantInt(10);
			AcceptEntityInput(g_iSound, "Volume");
		}
	}
}

void HookEvents()
{
	HookEvent("finale_vehicle_incoming",	Event_FinaleIn,			EventHookMode_PostNoCopy);
	HookEvent("create_panic_event",			Event_PanicAlert,		EventHookMode_PostNoCopy);
	HookEvent("tank_spawn",					Event_TankSpawn,		EventHookMode_PostNoCopy);
	HookEvent("player_death",				Event_TankKilled);
	HookEvent("witch_killed",				Event_WitchKilled);
	HookEvent("witch_harasser_set",			Event_WitchAlert,		EventHookMode_PostNoCopy);
	HookEvent("round_end",					Event_RoundEnd,			EventHookMode_PostNoCopy);
	HookEvent("round_start",				Event_RoundStart,		EventHookMode_PostNoCopy);
	HookEvent("player_spawn",				Event_PlayerSpawn);
}

void UnhookEvents()
{
	UnhookEvent("finale_vehicle_incoming",	Event_FinaleIn,			EventHookMode_PostNoCopy);
	UnhookEvent("create_panic_event",		Event_PanicAlert,		EventHookMode_PostNoCopy);
	UnhookEvent("tank_spawn",				Event_TankSpawn,		EventHookMode_PostNoCopy);
	UnhookEvent("player_death",				Event_TankKilled);
	UnhookEvent("witch_killed",				Event_WitchKilled);
	UnhookEvent("witch_harasser_set",		Event_WitchAlert,		EventHookMode_PostNoCopy);
	UnhookEvent("round_end",				Event_RoundEnd,			EventHookMode_PostNoCopy);
	UnhookEvent("round_start",				Event_RoundStart,		EventHookMode_PostNoCopy);
	UnhookEvent("player_spawn",				Event_PlayerSpawn);
}

public void Event_FinaleIn(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iCfgForever == 0 && g_iCfgFinale )
		if( GetRandomInt(1, 100) <= g_iCfgFinale )
			StartStorm();
}

public void Event_PanicAlert(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iCfgForever == 0 && g_iCfgPanic )
		if( GetRandomInt(1, 100) <= g_iCfgPanic )
			StartStorm();
}

public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iCfgForever == 0 && g_iCfgTank )
		if( GetRandomInt(1, 100) <= g_iCfgTank )
			StartStorm();
}

public void Event_TankKilled(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iCfgForever == 0 && g_iCfgTankDeath )
	{
		if( GetRandomInt(1, 100) <= g_iCfgTankDeath )
		{
			int client = GetClientOfUserId(event.GetInt("userid"));

			if( client >= 1 && client <= MaxClients && GetEntProp(client, Prop_Send, "m_zombieClass") == 8 )
			{
				StartStorm();
			}
		}
	}
}

public void Event_WitchKilled(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iCfgForever == 0 && g_iCfgWitch )
		if( g_iCfgWitchHead == 0 || (g_iCfgWitchHead == 1 && event.GetBool("oneshot") == true) )
			if( GetRandomInt(1, 100) <= g_iCfgWitch )
				StartStorm();
}

public void Event_WitchAlert(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iCfgForever == 0 && g_iCfgWitchAlert )
		if( GetRandomInt(1, 100) <= g_iCfgWitchAlert )
			StartStorm();
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_iReset = 1;
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
	g_iStarted = 1;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iStarted != 0 && g_iPlayerSpawn == 1 && g_iRoundStart == 0 )
	{
		LoadStorm();
		g_iReset = 0;
	}
	g_iRoundStart = 1;

	if( g_iStarted == 0 )
		g_iStarted = 1;
	else if( g_iStarted == 1 )
		g_iStarted = 2;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iPlayerSpawn == 0 && g_iRoundStart == 1 )
	{
		LoadStorm();
		g_iReset = 0;
	}
	g_iPlayerSpawn = 1;

	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);

	if( strcmp(g_sCfgLightStyle, "") != 0 && g_iLightStyle[client] != userid && !IsFakeClient(client) )
	{
		CreateTimer(5.5, TimerLightStyle, userid);
		CreateTimer(8.0, TimerLightStyle, userid);
		if( g_iCvarStyle == 0 )
			CreateTimer(10.0, TimerLightStyle, userid);
	}

	g_iLightStyle[client] = userid;
}

// Thanks to "Timocop"
bool IsFinalMap()
{
	return( FindEntityByClassname(-1, "info_changelevel") == -1
		&& FindEntityByClassname(-1, "trigger_changelevel") == -1 );
}

bool IsStartOrEndMap()
{
    int iCount;
    int i = -1;
    while( (i = FindEntityByClassname(i, "info_landmark")) != -1 ) {
        iCount++;
    }

    return (iCount == 1);
}



// ====================================================================================================
//					MAP LIGHT STYLE
// ====================================================================================================
public Action TimerLightStyle(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if( client != 0 && !IsFakeClient(client) )
	{
		g_iLightStyle[client] = userid;
		ChangeLightStyle(g_sCfgLightStyle, client);
	}
}

void ChangeLightStyle(char[] lightstring, int client = 0)
{
	if( g_iStarted == 2 && strcmp(lightstring, "") != 0 )
	{
		SetLightStyle(0, lightstring);

		// This refreshes and updates the entire map with the new light style.
		int entity = CreateEntityByName("light_dynamic");

		DispatchKeyValue(entity, "_light", "0 0 0 0");
		DispatchKeyValue(entity, "brightness", "0");
		DispatchKeyValue(entity, "style", "13");
		DispatchKeyValue(entity, "distance", "19999");
		DispatchSpawn(entity);

		if( client )
		{
			SetEntProp(entity, Prop_Data, "m_iHammerID", client);
			SDKHook(entity, SDKHook_SetTransmit, Hook_SetTransmitLight);
		}

		if( g_iCvarStyle == 0 )
		{
			float vPos[3], vMins[3], vMaxs[3];
			GetEntPropVector(0, Prop_Data, "m_WorldMins", vMins);
			GetEntPropVector(0, Prop_Data, "m_WorldMaxs", vMaxs);
			vPos[0] = (vMins[0] + vMaxs[0]) / 2;
			vPos[1] = (vMins[1] + vMaxs[1]) / 2;
			vPos[2] = vMaxs[2] + 2000.0;
			TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);

			AcceptEntityInput(entity, "TurnOn");
			SetVariantString("OnUser1 !self:TurnOff::0.2:-1");
			AcceptEntityInput(entity, "AddOutput");
			SetVariantString("OnUser1 !self:TurnOff::0.3:-1");
			AcceptEntityInput(entity, "AddOutput");
			SetVariantString("OnUser1 !self:TurnOff::0.4:-1");
			AcceptEntityInput(entity, "AddOutput");
			SetVariantString("OnUser1 !self:Kill::0.5:-1");
			AcceptEntityInput(entity, "AddOutput");
			AcceptEntityInput(entity, "FireUser1");
		}
		else
		{
			if( g_iCvarStyle == 1 )
			{
				SetVariantString("OnUser1 !self:TurnOff::0.7:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser1 !self:TurnOff::0.8:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser1 !self:Kill::1.0:-1");
				AcceptEntityInput(entity, "AddOutput");
				AcceptEntityInput(entity, "FireUser1");

				SetVariantString("OnUser3 !self:FireUser2::0.05:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser3 !self:FireUser2::0.10:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser3 !self:FireUser2::0.15:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser3 !self:FireUser2::0.20:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser3 !self:FireUser2::0.25:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser3 !self:FireUser2::0.30:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser3 !self:FireUser2::0.35:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser3 !self:FireUser2::0.40:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser3 !self:FireUser2::0.45:-1");
				AcceptEntityInput(entity, "AddOutput");
			}
			else
			{
				SetVariantString("OnUser1 !self:TurnOff::1.2:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser1 !self:TurnOff::1.3:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser1 !self:Kill::1.5:-1");
				AcceptEntityInput(entity, "AddOutput");
				AcceptEntityInput(entity, "FireUser1");

				SetVariantString("OnUser3 !self:FireUser2::0.1:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser3 !self:FireUser2::0.2:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser3 !self:FireUser2::0.3:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser3 !self:FireUser2::0.4:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser3 !self:FireUser2::0.5:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser3 !self:FireUser2::0.6:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser3 !self:FireUser2::0.7:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser3 !self:FireUser2::0.8:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser3 !self:FireUser2::0.9:-1");
				AcceptEntityInput(entity, "AddOutput");
			}

			SetEntProp(entity, Prop_Data, "m_iHealth", 1);
			HookSingleEntityOutput(entity, "OnUser2", OnUser2);
			AcceptEntityInput(entity, "FireUser3");
		}
	}
}

public Action Hook_SetTransmitLight(int entity, int client)
{
	if( GetEntProp(entity, Prop_Data, "m_iHammerID") == client )
		return Plugin_Continue;
	return Plugin_Handled;
}

public void OnUser2(const char[] output, int entity, int activator, float delay)
{
	int corner = GetEntProp(entity, Prop_Data, "m_iHealth");
	SetEntProp(entity, Prop_Data, "m_iHealth", corner + 1);


	float vPos[3], vMins[3], vMaxs[3];
	GetEntPropVector(0, Prop_Data, "m_WorldMins", vMins);
	GetEntPropVector(0, Prop_Data, "m_WorldMaxs", vMaxs);

	if( corner == 1 )
	{
		AcceptEntityInput(entity, "TurnOff");
		vPos[0] = (vMins[0] + vMaxs[0]) / 2;
		vPos[1] = (vMins[1] + vMaxs[1]) / 2;
		vPos[2] = vMaxs[2] += 2000.0;
		TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(entity, "TurnOn");
	}
	else if( corner == 2 )
	{
		AcceptEntityInput(entity, "TurnOff");
		vPos[0] = vMins[0];
		vPos[1] = vMins[1];
		vPos[2] = vMins[2];
		TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(entity, "TurnOn");
	}
	else if( corner == 3 )
	{
		AcceptEntityInput(entity, "TurnOff");
		vPos[0] = vMaxs[0];
		vPos[1] = vMins[1];
		vPos[2] = vMins[2];
		TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(entity, "TurnOn");
	}
	else if( corner == 4 )
	{
		AcceptEntityInput(entity, "TurnOff");
		vPos[0] = vMins[0];
		vPos[1] = vMaxs[1];
		vPos[2] = vMins[2];
		TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(entity, "TurnOn");
	}
	else if( corner == 5 )
	{
		AcceptEntityInput(entity, "TurnOff");
		vPos[0] = vMins[0];
		vPos[1] = vMins[1];
		vPos[2] = vMaxs[2];
		TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(entity, "TurnOn");
	}
	else if( corner == 6 )
	{
		AcceptEntityInput(entity, "TurnOff");
		vPos[0] = vMaxs[0];
		vPos[1] = vMaxs[1];
		vPos[2] = vMins[2];
		TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(entity, "TurnOn");
	}
	else if( corner == 7 )
	{
		AcceptEntityInput(entity, "TurnOff");
		vPos[0] = vMins[0];
		vPos[1] = vMaxs[1];
		vPos[2] = vMaxs[2];
		TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(entity, "TurnOn");
	}
	else if( corner == 8 )
	{
		AcceptEntityInput(entity, "TurnOff");
		vPos[0] = vMaxs[0];
		vPos[1] = vMins[1];
		vPos[2] = vMaxs[2];
		TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(entity, "TurnOn");
	}

	if( corner == 9 )
	{
		AcceptEntityInput(entity, "TurnOff");
		vPos[0] = vMaxs[0];
		vPos[1] = vMaxs[1];
		vPos[2] = vMaxs[2];
		TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(entity, "TurnOn");

		corner = 0;
		SetVariantString("OnUser4 !self:TurnOff::0.2:-1");
		AcceptEntityInput(entity, "AddOutput");
		SetVariantString("OnUser4 !self:TurnOff::0.3:-1");
		AcceptEntityInput(entity, "AddOutput");
		SetVariantString("OnUser4 !self:Kill::0.5:-1");
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser4");
	}
}

void CheckDynamicLightStyle()
{
	if( g_bCvarAllow && strcmp(g_sCfgLightStyle, "") != 0 )
	{
		int entity = -1;
		while( (entity = FindEntityByClassname(entity, "light_dynamic")) != INVALID_ENT_REFERENCE )
		{
			if( GetEntProp(entity, Prop_Send, "m_LightStyle") == 0 )
			{
				SetEntProp(entity, Prop_Send, "m_LightStyle", 13); // Style non-defined, appears just like 0.
			}
		}
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if( g_bCvarAllow && strcmp(g_sCfgLightStyle, "") != 0 )
	{
		if( strcmp(classname, "light_dynamic") == 0 )
		{
			CreateTimer(0.0, TimerLight, EntIndexToEntRef(entity));
		}
	}
}

public Action TimerLight(Handle timer, any entity)
{
	if( EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
	{
		if( GetEntProp(entity, Prop_Send, "m_LightStyle") == 0 )
		{
			SetEntProp(entity, Prop_Send, "m_LightStyle", 13); // Style non-defined, appears just like 0.
		}
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
	g_iCvarMixer =	g_hCvarMixer.IntValue;
	g_fCvarPost =	g_hCvarPost.FloatValue;
	g_iCvarRand =	g_hCvarRand.IntValue;
	g_iCvarStyle =	g_hCvarStyle.IntValue;
}

void IsAllowed()
{
	bool bAllowCvar = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bAllowCvar == true && bAllowMode == true )
	{
		g_bCvarAllow = true;
		g_bLoaded = false;
		HookEvents();
		LoadStorm();
	}

	else if( g_bCvarAllow == true && (bAllowCvar == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;
		ResetPlugin();
		UnhookEvents();
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
//					SET SKYBOX
// ====================================================================================================
public void ConVarChanged_SkyBox(Handle convar, const char[] oldValue, const char[] newValue)
{
	SetSkyname();
}

void SetSkyname()
{
	if( g_bCvarAllow )
	{
		KeyValues hFile = ConfigOpen();

		if( hFile != null )
		{
			char sMap[64];
			GetCurrentMap(sMap, sizeof(sMap));

			int completed_jump = ConfigJumpA(hFile, sMap);
			if( completed_jump )
			{
				if( ConfigChance(0, hFile) == false )
				{
					delete hFile;
					return;
				}

				hFile.GetString("skybox", g_sSkyBox, sizeof(g_sSkyBox));

				if( completed_jump == 1 && ConfigJumpB(hFile, sMap) )
				{
					if( ConfigChance(0, hFile) == false )
					{
						delete hFile;
						return;
					}

					hFile.GetString("skybox", g_sSkyBox, sizeof(g_sSkyBox), g_sSkyBox);
				}

				if( strcmp(g_sSkyBox, "") != 0 )
				{
					g_hCvarSkyName.SetString(g_sSkyBox);
				}
			}

			delete hFile;
		}
	}
}



// ====================================================================================================
//					SET SKYBOX
// ====================================================================================================
void SetBackground(bool resetsky)
{
	if( g_bLoaded == false )
		return;

	if( IsValidEntRef(g_iSkyCamera) == false )
	{
		g_iSkyCamera = FindEntityByClassname(-1, "sky_camera");
		if( g_iSkyCamera == -1 )
			return;

		g_iSkyCam[0] = GetEntProp(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.colorPrimary");
		g_iSkyCam[1] = GetEntProp(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.colorSecondary");
	}

	if( resetsky == true )
	{
		CreateSkyCamera(g_iSkyCam[0], g_iSkyCam[1]);
	}
	else
	{
		KeyValues hFile = ConfigOpen();

		if( hFile != null )
		{
			char sMap[64];
			GetCurrentMap(sMap, sizeof(sMap));

			int completed_jump = ConfigJumpA(hFile, sMap);
			if( completed_jump )
			{
				if( ConfigChance(0, hFile) == false )
				{
					delete hFile;
					return;
				}

				char sBack[12];
				hFile.GetString("background", sBack, sizeof(sBack));

				if( completed_jump == 1 && ConfigJumpB(hFile, sMap) )
				{
					if( ConfigChance(0, hFile) == false )
					{
						delete hFile;
						return;
					}

					hFile.GetString("background", sBack, sizeof(sBack), sBack);
				}

				g_iCfgBackground = GetColor(sBack);
				if( g_iCfgBackground != 0 )
				{
					CreateSkyCamera(g_iCfgBackground, g_iCfgBackground);
				}
			}

			delete hFile;
		}
	}
}

void CreateSkyCamera(int color1, int color2)
{
	if( IsValidEntRef(g_iSkyCamera) == true )
	{
		int iSkyCamData[5];
		float fSkyCamData[5];

		iSkyCamData[0] = GetEntProp(g_iSkyCamera, Prop_Data, "m_bUseAngles");
		iSkyCamData[1] = GetEntProp(g_iSkyCamera, Prop_Data, "m_skyboxData.scale");
		iSkyCamData[2] = GetEntProp(g_iSkyCamera, Prop_Data, "m_skyboxData.bClip3DSkyBoxNearToWorldFar");
		iSkyCamData[3] = GetEntProp(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.blend");
		iSkyCamData[4] = GetEntProp(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.enable");
		fSkyCamData[0] = GetEntPropFloat(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.start");
		fSkyCamData[1] = GetEntPropFloat(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.end");
		fSkyCamData[2] = GetEntPropFloat(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.maxdensity");
		fSkyCamData[3] = GetEntPropFloat(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.HDRColorScale");
		fSkyCamData[4] = GetEntPropFloat(g_iSkyCamera, Prop_Data, "m_skyboxData.flClip3DSkyBoxNearToWorldFarOffset");

		float vAng[3], vPos[3];
		GetEntPropVector(g_iSkyCamera, Prop_Data, "m_vecOrigin", vPos);
		GetEntPropVector(g_iSkyCamera, Prop_Data, "m_angRotation", vAng);
		AcceptEntityInput(g_iSkyCamera, "Kill");


		g_iSkyCamera = CreateEntityByName("sky_camera");

		SetEntProp(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.colorPrimary", color1);
		SetEntProp(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.colorSecondary", color2);
		SetEntProp(g_iSkyCamera, Prop_Data, "m_bUseAngles", iSkyCamData[0]);
		SetEntProp(g_iSkyCamera, Prop_Data, "m_skyboxData.scale", iSkyCamData[1]);
		SetEntProp(g_iSkyCamera, Prop_Data, "m_skyboxData.bClip3DSkyBoxNearToWorldFar", iSkyCamData[2]);
		SetEntProp(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.blend", iSkyCamData[3]);
		SetEntProp(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.enable", iSkyCamData[4]);
		SetEntPropFloat(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.start", fSkyCamData[0]);
		SetEntPropFloat(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.end", fSkyCamData[1]);
		SetEntPropFloat(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.maxdensity", fSkyCamData[2]);
		SetEntPropFloat(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.HDRColorScale", fSkyCamData[3]);
		SetEntPropFloat(g_iSkyCamera, Prop_Data, "m_skyboxData.flClip3DSkyBoxNearToWorldFarOffset", fSkyCamData[4]);

		TeleportEntity(g_iSkyCamera, vPos, vAng, NULL_VECTOR);
		DispatchSpawn(g_iSkyCamera);
		AcceptEntityInput(g_iSkyCamera, "ActivateSkybox");
	}
}



// ====================================================================================================
//					COMMANDS
// ====================================================================================================
public Action CmdStormMenu(int client, int args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Storm] Commands may only be used in-game on a dedicated server.");
		return Plugin_Handled;
	}

	ShowMenuMain(client);
	return Plugin_Handled;
}

public Action CmdStormStart(int client, int args)
{
	StartStorm();
	return Plugin_Handled;
}

public Action CmdStormStop(int client, int args)
{
	StopStorm();
	return Plugin_Handled;
}

public Action CmdStormRefresh(int client, int args)
{
	ResetPlugin();
	LoadStorm();
	return Plugin_Handled;
}

public Action CmdStormReset(int client, int args)
{
	ResetPlugin();
	return Plugin_Handled;
}

public Action CmdStormConfig(int client, int args)
{
	PrintToChat(client, "%s Config: {%s}.", CHAT_TAG, g_sConfigSection);
	return Plugin_Handled;
}

public Action CmdLightning(int client, int args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Storm] Commands may only be used in-game on a dedicated server.");
		return Plugin_Handled;
	}

	int stormstate = g_iStormState;
	g_iStormState = STATE_OFF;
	DisplayLightning(client);
	g_iStormState = stormstate;
	return Plugin_Handled;
}

public Action CmdBackground(int client, int args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Storm] Commands may only be used in-game on a dedicated server.");
	}
	else if( args == 0 )
	{
		if( IsValidEntRef(g_iSkyCamera) == true )
		{
			CreateSkyCamera(g_iSkyCam[0], g_iSkyCam[1]);
			PrintToChat(client, "%sBackground color has been reset.", CHAT_TAG);
		}
		else
		{
			PrintToChat(client, "%sBackground error: Cannot find the \x01sky_camera\x06 entity. Was never created or has been deleted.", CHAT_TAG);
		}
	}
	else if( args == 3 )
	{
		if( IsValidEntRef(g_iSkyCamera) == false )
		{
			g_iSkyCamera = FindEntityByClassname(-1, "sky_camera");
			if( g_iSkyCamera == -1 )
			{
				PrintToChat(client, "%sBackground error: Cannot find the \x01sky_camera\x06 entity. Was never created or has been deleted.", CHAT_TAG);
				return Plugin_Handled;
			}

			g_iSkyCam[0] = GetEntProp(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.colorPrimary");
			g_iSkyCam[1] = GetEntProp(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.colorSecondary");
		}

		char sTemp[12];
		GetCmdArgString(sTemp, sizeof(sTemp));
		int color = GetColor(sTemp);
		CreateSkyCamera(color, color);
	}
	else
	{
		PrintToChat(client, "%sUsage: sm_background <no args = reset, or string from a-z.", CHAT_TAG);
	}
	return Plugin_Handled;
}

public Action CmdMapLight(int client, int args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Storm] Commands may only be used in-game on a dedicated server.");
		return Plugin_Handled;
	}

	if( strcmp(g_sCfgLightStyle, "") == 0 )
	{
		strcopy(g_sCfgLightStyle, sizeof(g_sCfgLightStyle), "m");
		CheckDynamicLightStyle();
	}

	if( args == 0 )
	{
		ChangeLightStyle("m");
		PrintToChat(client, "%sMap light style has been reset.", CHAT_TAG);
	}
	else if( args == 1 )
	{
		char sTemp[64];
		GetCmdArg(1, sTemp, sizeof(sTemp));
		PrintToChat(client, "%sMap light style has been set to '\x03%s\x01'.", CHAT_TAG, sTemp);
		ChangeLightStyle(sTemp);
	}
	else
	{
		PrintToChat(client, "%sUsage: sm_maplight <no args = reset, or string from a-z.", CHAT_TAG);
	}
	return Plugin_Handled;
}

public Action CmdFarZ(int client, int args)
{
	if( args == 1)
	{
		int entity = -1;
		char sTemp[16];
		GetCmdArg(1, sTemp, sizeof(sTemp));

		while( (entity = FindEntityByClassname(entity, "env_fog_controller")) != INVALID_ENT_REFERENCE )
		{
			SetVariantString(sTemp);
			AcceptEntityInput(entity, "SetFarZ");
		}
	}
	else
	{
		PrintToChat(client, "%sUsage: sm_farz <distance in game units>.", CHAT_TAG);
	}
	return Plugin_Handled;
}

public Action CmdFog(int client, int args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Storm] Commands may only be used in-game on a dedicated server.");
		return Plugin_Handled;
	}

	if( g_iFogOn == 0 )
	{
		CreateFog();
		PrintToChat(client, "%sFog has been turned '\x03On\x05'", CHAT_TAG);
	}
	else if( args == 0 )
	{
		ResetFog();
		PrintToChat(client, "%sFog has been turned '\x03Off\x05'", CHAT_TAG);
	}

	if( args == 3 )
	{
		char sTemp[12];
		GetCmdArgString(sTemp, sizeof(sTemp));

		int entity = -1;
		while( (entity = FindEntityByClassname(entity, "env_fog_controller")) != INVALID_ENT_REFERENCE )
		{
			DispatchKeyValue(entity, "fogcolor", sTemp);
			DispatchKeyValue(entity, "fogcolor2", sTemp);

			SetVariantString(sTemp);
			AcceptEntityInput(entity, "SetColorLerpTo");
		}
	}
	return Plugin_Handled;
}

public Action CmdRain(int client, int args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Storm] Commands may only be used in-game on a dedicated server.");
		return Plugin_Handled;
	}

	int count;
	for( int i = 0; i < MAX_RAIN; i++ )
		if( IsValidEntRef(g_iRains[i]) )
			count++;

	if( count != 0 )
	{
		for( int i = 0; i < MAX_RAIN; i++ )
		{
			if( IsValidEntRef(g_iRains[i]) )
			{
				AcceptEntityInput(g_iRains[i], "Kill");
				g_iRains[i] = 0;
			}
		}

		if( IsValidEntRef(g_iSnow) )
		{
			AcceptEntityInput(g_iSnow, "Kill");
			g_iSnow = 0;
			CreateSnow();
		}

		PrintToChat(client, "%sRain has been turned '\x03Off\x05'", CHAT_TAG);
	}
	else
	{
		if( g_iCfgRain == 0 )
		{
			g_iCfgRain = 1;
			CreateRain();
			g_iCfgRain = 0;
		}
		else
		{
			CreateRain();
		}
		PrintToChat(client, "%sRain has been turned '\x03On\x05'", CHAT_TAG);
	}
	return Plugin_Handled;
}

public Action CmdSnow(int client, int args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Storm] Commands may only be used in-game on a dedicated server.");
		return Plugin_Handled;
	}

	if( IsValidEntRef(g_iSnow) )
	{
		AcceptEntityInput(g_iSnow, "Kill");
		g_iSnow = 0;

		PrintToChat(client, "%sSnow has been turned '\x03Off\x05'", CHAT_TAG);
	}
	else
	{
		if( g_iCfgSnow == 0 )
		{
			g_iCfgSnow = 1;
			CreateSnow();
			g_iCfgSnow = 0;
		}
		else
		{
			CreateSnow();
		}
		PrintToChat(client, "%sSnow has been turned '\x03On\x05'", CHAT_TAG);
	}
	return Plugin_Handled;
}

public Action CmdWind(int client, int args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Storm] Commands may only be used in-game on a dedicated server.");
		return Plugin_Handled;
	}

	if( IsValidEntRef(g_iWind) )
	{
		AcceptEntityInput(g_iWind, "Kill");
		g_iWind = 0;
		PrintToChat(client, "%sWind has been turned '\x03Off\x05'", CHAT_TAG);
	}
	else
	{
		CreateWind();
		PrintToChat(client, "%sWind has been turned '\x03On\x05'", CHAT_TAG);
	}
	return Plugin_Handled;
}

public Action CmdSun(int client, int args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Storm] Commands may only be used in-game on a dedicated server.");
		return Plugin_Handled;
	}

	if( args == 0 )
	{
		ToggleEnvSun(g_iSunSaved);
		return Plugin_Handled;
	}

	if( args == 1 )
	{
		ToggleEnvSun(0);
		return Plugin_Handled;
	}

	if( args != 3 )
	{
		PrintToChat(client, "%sUsage: sm_sun <r> <g> <b> (values 0-255, eg: sm_sun 255 0 0).", CHAT_TAG);
		return Plugin_Handled;
	}

	char sTemp[12];
	GetCmdArgString(sTemp, sizeof(sTemp));
	ToggleEnvSun(GetColor(sTemp));
	return Plugin_Handled;
}

public Action CmdStormSet(int client, int args)
{
	if( args == 3 )
	{
		char sTemp[12];
		GetCmdArgString(sTemp, sizeof(sTemp));
		int color = GetColor(sTemp);


		// Background
		if( IsValidEntRef(g_iSkyCamera) == false )
		{
			g_iSkyCamera = FindEntityByClassname(-1, "sky_camera");
			if( g_iSkyCamera == -1 )
			{
				PrintToChat(client, "%sBackground error: Cannot find the \x01sky_camera\x06 entity. Was never created or has been deleted.", CHAT_TAG);
			}

			g_iSkyCam[0] = GetEntProp(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.colorPrimary");
			g_iSkyCam[1] = GetEntProp(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.colorSecondary");
		}

		CreateSkyCamera(color, color);


		// Sun
		ToggleEnvSun(color);


		// Fog
		int entity = -1;
		while( (entity = FindEntityByClassname(entity, "env_fog_controller")) != INVALID_ENT_REFERENCE )
		{
			DispatchKeyValue(entity, "fogcolor", sTemp);
			DispatchKeyValue(entity, "fogcolor2", sTemp);

			SetVariantString(sTemp);
			AcceptEntityInput(entity, "SetColorLerpTo");
		}
	}
	else
	{
		PrintToChat(client, "%sUsage: sm_stormset <r> <g> <b> (values 0-255, eg: sm_stormset 255 0 0).", CHAT_TAG);
	}

	return Plugin_Handled;
}


// ====================================================================================================
//					MENU - MAIN
// ====================================================================================================
void ShowMenuMain(int client)
{
	g_hMenuMain.Display(client, MENU_TIME_FOREVER);
}

public int MainMenuHandler(Menu menu, MenuAction action, int client, int index)
{
	if( action == MenuAction_Select )
	{
		if( index == 0 )
		{
			ShowMenuMain(client);

			if( g_iStormState == STATE_OFF )
				LoadStorm(client);
			else
				StartStorm(client);
		}
		else if( index == 1 )
		{
			ShowMenuMain(client);
			StopStorm(client);
		}
		else if( index == 2 )
		{
			ShowMenuMain(client);
			if( IsValidEntRef(g_iLogicOut) )
				AcceptEntityInput(g_iLogicOut, "Trigger");
			ResetPlugin();
		}
		else if( index == 3 )
		{
			ShowMenuTrigger(client);
		}
		else if( index == 4 )
		{
			ShowMenuMain(client);
			ResetPlugin();
			LoadStorm();
		}
	}
}

void ShowMenuTrigger(int client)
{
	Menu hMenu = new Menu(TrigMenuHandler);

	hMenu.AddItem("0", "Create");
	if( g_hTmrBeam == null )
		hMenu.AddItem("1", "Show");
	else
		hMenu.AddItem("1", "Hide");
	hMenu.AddItem("2", "Delete");
	hMenu.AddItem("3", "VMaxs");
	hMenu.AddItem("4", "VMins");
	hMenu.AddItem("5", "Origin");
	hMenu.AddItem("6", "Go To");

	hMenu.SetTitle("Storm - Trigger:");
	hMenu.ExitBackButton = true;

	hMenu.Display(client, MENU_TIME_FOREVER);
}

public int TrigMenuHandler(Menu menu, MenuAction action, int client, int index)
{
	if( action == MenuAction_End )
	{
		delete menu;
	}
	else if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowMenuMain(client);
	}
	else if( action == MenuAction_Select )
	{
		char sTemp[4];
		menu.GetItem(index, sTemp, sizeof(sTemp));
		index = StringToInt(sTemp);

		if( index == 0 )
		{
			CreateTrigger(client);
			ShowMenuTrigger(client);
		}
		else if( index == 1 )
		{
			if( g_hTmrBeam != null )
			{
				delete g_hTmrBeam;
				g_hTmrBeam = null;
				g_iTriggerSelected = 0;
			}
			ShowMenuTrigList(client, index);
		}
		else if( index == 2 )
		{
			ShowMenuTrigList(client, index);
		}
		else if( index == 3 )
		{
			ShowMenuTrigList(client, index);
		}
		else if( index == 4 )
		{
			ShowMenuTrigList(client, index);
		}
		else if( index == 5 )
		{
			ShowMenuTrigList(client, index);
		}
		else if( index == 6 )
		{
			ShowMenuTrigList(client, index);
		}
	}
}

void ShowMenuTrigList(int client, int index)
{
	g_iTriggerCfgIndex[client] = index;

	int count;
	Menu hMenu = new Menu(TriggerMenuHandler);
	char sIndex[8], sTemp[16];

	for( int i = 0; i < MAX_TRIGGERS; i++ )
	{
		if( IsValidEntRef(g_iTriggers[i]) )
		{
			count++;
			Format(sIndex, sizeof(sIndex), "%d", i);
			Format(sTemp, sizeof(sTemp), "Trigger %d", count);
			hMenu.AddItem(sIndex, sTemp);
		}
	}

	if( index == 1 )
		hMenu.SetTitle("Storm - Select Trigger To Show:");
	else if( index == 2 )
		hMenu.SetTitle("Storm - Select Trigger To Delete:");
	else if( index == 3 )
		hMenu.SetTitle("Storm - Select Trigger - Maxs:");
	else if( index == 4 )
		hMenu.SetTitle("Storm - Select Trigger - Mins:");
	else if( index == 5 )
		hMenu.SetTitle("Storm - Select Trigger - Origin:");
	else if( index == 6 )
		hMenu.SetTitle("Storm - Select Trigger - Go To:");

	hMenu.ExitBackButton = true;
	hMenu.Display(client, MENU_TIME_FOREVER);
}

public int TriggerMenuHandler(Menu menu, MenuAction action, int client, int index)
{
	if( action == MenuAction_End )
	{
		delete menu;
	}
	else if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowMenuTrigger(client);
	}
	else if( action == MenuAction_Select )
	{
		int type = g_iTriggerCfgIndex[client];
		char sTemp[4];
		menu.GetItem(index, sTemp, sizeof(sTemp));
		index = StringToInt(sTemp);

		if( type == 1 )
		{
			g_iTriggerSelected = g_iTriggers[index];
			if( IsValidEntRef(g_iTriggerSelected) )
			{
				g_hTmrBeam = CreateTimer(0.1, TimerBeam, _, TIMER_REPEAT);
			}
			else
			{
				g_iTriggerSelected = 0;
			}
			ShowMenuTrigger(client);
		}
		else if( type == 2 )
		{
			DeleteTrigger(client, index);
			ShowMenuTrigger(client);
		}
		else if( type == 3 )
		{
			g_iTriggerCfgIndex[client] = index;
			g_hMenuVMaxs.Display(client, MENU_TIME_FOREVER);
		}
		else if( type == 4 )
		{
			g_iTriggerCfgIndex[client] = index;
			g_hMenuVMins.Display(client, MENU_TIME_FOREVER);
		}
		else if( type == 5 )
		{
			g_iTriggerCfgIndex[client] = index;
			g_hMenuPos.Display(client, MENU_TIME_FOREVER);
		}
		else if( type == 6 )
		{
			int trigger = g_iTriggers[index];
			if( IsValidEntRef(trigger) )
			{
				float vPos[3];
				GetEntPropVector(trigger, Prop_Send, "m_vecOrigin", vPos);
				vPos[2] += 10.0;
				TeleportEntity(client, vPos, NULL_VECTOR, NULL_VECTOR);
			}
		}
	}
}

public int VMaxsMenuHandler(Menu menu, MenuAction action, int client, int index)
{
	if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowMenuTrigger(client);
	}
	else if( action == MenuAction_Select )
	{
		if( index == 0 )
			SaveMaxMin(client, 1, view_as<float>({ 10.0, 10.0, 100.0 }));
		else if( index == 1 )
			SaveMaxMin(client, 1, view_as<float>({ 25.0, 25.0, 100.0 }));
		else if( index == 2 )
			SaveMaxMin(client, 1, view_as<float>({ 50.0, 50.0, 100.0 }));
		else if( index == 3 )
			SaveMaxMin(client, 1, view_as<float>({ 100.0, 100.0, 100.0 }));
		else if( index == 4 )
			SaveMaxMin(client, 1, view_as<float>({ 150.0, 150.0, 100.0 }));
		else if( index == 5 )
			SaveMaxMin(client, 1, view_as<float>({ 200.0, 200.0, 100.0 }));
		else if( index == 6 )
			SaveMaxMin(client, 1, view_as<float>({ 300.0, 300.0, 100.0 }));

		g_hMenuVMaxs.Display(client, MENU_TIME_FOREVER);
	}
}

public int VMinsMenuHandler(Menu menu, MenuAction action, int client, int index)
{
	if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowMenuTrigger(client);
	}
	else if( action == MenuAction_Select )
	{
		if( index == 0 )
			SaveMaxMin(client, 2, view_as<float>({ -10.0, -10.0, 0.0 }));
		else if( index == 1 )
			SaveMaxMin(client, 2, view_as<float>({ -25.0, -25.0, 0.0 }));
		else if( index == 2 )
			SaveMaxMin(client, 2, view_as<float>({ -50.0, -50.0, 0.0 }));
		else if( index == 3 )
			SaveMaxMin(client, 2, view_as<float>({ -100.0, -100.0, 0.0 }));
		else if( index == 4 )
			SaveMaxMin(client, 2, view_as<float>({ -150.0, -150.0, 0.0 }));
		else if( index == 5 )
			SaveMaxMin(client, 2, view_as<float>({ -200.0, -200.0, 0.0 }));
		else if( index == 6 )
			SaveMaxMin(client, 2, view_as<float>({ -300.0, -300.0, 0.0 }));

		g_hMenuVMins.Display(client, MENU_TIME_FOREVER);
	}
}

public int PosMenuHandler(Menu menu, MenuAction action, int client, int index)
{
	if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowMenuTrigger(client);
	}
	else if( action == MenuAction_Select )
	{
		int cfgindex = g_iTriggerCfgIndex[client];
		int trigger = g_iTriggers[cfgindex];

		float vPos[3];
		GetEntPropVector(trigger, Prop_Send, "m_vecOrigin", vPos);

		if( index == 0 )
			vPos[0] += 1.0;
		else if( index == 1 )
			vPos[1] += 1.0;
		else if( index == 2 )
			vPos[2] += 1.0;
		else if( index == 3 )
			vPos[0] -= 1.0;
		else if( index == 4 )
			vPos[1] -= 1.0;
		else if( index == 5 )
			vPos[2] -= 1.0;

		if( index != 6 )
			TeleportEntity(trigger, vPos, NULL_VECTOR, NULL_VECTOR);
		else
			SaveTrigger(client, cfgindex+1, "vpos", vPos);

		g_hMenuPos.Display(client, MENU_TIME_FOREVER);
	}
}

void SaveTrigger(int client, int index, char[] sKey, float vVec[3])
{
	KeyValues hFile = ConfigOpen(2);

	if( hFile != null )
	{
		char sTemp[64];
		GetCurrentMap(sTemp, sizeof(sTemp));

		if( hFile.JumpToKey(sTemp, true) )
		{
			Format(sTemp, sizeof(sTemp), "%s_%d", sKey, index);
			hFile.SetVector(sTemp, vVec);

			ConfigSave(hFile);
			if( client )
				PrintToChat(client, "%s(\x05%d/%d\x01) - Saved trigger '%s'.", CHAT_TAG, g_iTriggerCount, MAX_TRIGGERS, sKey);
		}
		else if( client )
			PrintToChat(client, "%s(\x05%d/%d\x01) - Failed to save trigger '%s'.", CHAT_TAG, g_iTriggerCount, MAX_TRIGGERS, sKey);

		delete hFile;
	}
}

void SaveMaxMin(int client, int type, float vVec[3])
{
	int cfgindex = g_iTriggerCfgIndex[client];
	int trigger = g_iTriggers[cfgindex];

	if( IsValidEntRef(trigger) )
	{
		if( type == 1 )
			SetEntPropVector(trigger, Prop_Send, "m_vecMaxs", vVec);
		else
			SetEntPropVector(trigger, Prop_Send, "m_vecMins", vVec);
	}

	KeyValues hFile = ConfigOpen(2);

	if( hFile != null )
	{
		char sTemp[64];
		GetCurrentMap(sTemp, sizeof(sTemp));

		if( hFile.JumpToKey(sTemp, true) )
		{
			if( type == 1 )
			{
				Format(sTemp, sizeof(sTemp), "vmax_%d", cfgindex+1);
				hFile.SetVector(sTemp, vVec);
			}
			else
			{
				Format(sTemp, sizeof(sTemp), "vmin_%d", cfgindex+1);
				hFile.SetVector(sTemp, vVec);
			}

			if( client )
				PrintToChat(client, "%sSaved trigger '%s'.", CHAT_TAG, type == 1 ? "maxs" : "mins");
			ConfigSave(hFile);
		}
		else if( client )
			PrintToChat(client, "%sFailed to save trigger '%s'.", CHAT_TAG, type == 1 ? "maxs" : "mins");

		delete hFile;
	}
}

void DeleteTrigger(int client, int cfgindex)
{
	KeyValues hFile = ConfigOpen(1);

	if( hFile != null )
	{
		char sMap[64];
		GetCurrentMap(sMap, sizeof(sMap));

		if( hFile.JumpToKey(sMap) )
		{
			char sTemp[16];
			float vTemp[3];
			Format(sTemp, sizeof(sTemp), "vpos_%d", cfgindex+1);
			hFile.DeleteKey(sTemp);
			Format(sTemp, sizeof(sTemp), "vmax_%d", cfgindex+1);
			hFile.DeleteKey(sTemp);
			Format(sTemp, sizeof(sTemp), "vmin_%d", cfgindex+1);
			hFile.DeleteKey(sTemp);

			AcceptEntityInput(g_iTriggers[cfgindex], "Kill");
			g_iTriggers[cfgindex] = 0;

			for( int i = cfgindex+1; i <= g_iTriggerCount; i++ )
			{
				g_iTriggers[i-1] = g_iTriggers[i];
				g_iTriggers[i] = 0;

				Format(sTemp, sizeof(sTemp), "vpos_%d", i);
				hFile.GetVector(sTemp, vTemp);
				if( vTemp[0] != 0.0 && vTemp[1] != 0.0 && vTemp[2] != 0.0 )
				{
					hFile.DeleteKey(sTemp);
					Format(sTemp, sizeof(sTemp), "vpos_%d", i-1);
					hFile.SetVector(sTemp, vTemp);

					Format(sTemp, sizeof(sTemp), "vmax_%d", i);
					hFile.GetVector(sTemp, vTemp);
					hFile.DeleteKey(sTemp);
					Format(sTemp, sizeof(sTemp), "vmax_%d", i-1);
					hFile.SetVector(sTemp, vTemp);

					Format(sTemp, sizeof(sTemp), "vmin_%d", i);
					hFile.GetVector(sTemp, vTemp);
					hFile.DeleteKey(sTemp);
					Format(sTemp, sizeof(sTemp), "vmin_%d", i-1);
					hFile.SetVector(sTemp, vTemp);
				}
			}

			g_iTriggerCount--;
			ConfigSave(hFile);

			PrintToChat(client, "%s(\x05%d/%d\x01) - Storm TriggerBox removed from config.", CHAT_TAG, g_iTriggerCount, MAX_TRIGGERS);
		}

		delete hFile;
	}
}

void CreateTrigger(int client)
{
	float vPos[3];
	GetClientAbsOrigin(client, vPos);
	CreateTriggerMultiple(vPos, view_as<float>({ 25.0, 25.0, 100.0}), view_as<float>({ -25.0, -25.0, 0.0 }));
	g_iTriggerCount++;

	SaveTrigger(client, g_iTriggerCount, "vpos", vPos);
	SaveTrigger(client, g_iTriggerCount, "vmax", view_as<float>({ 25.0, 25.0, 100.0}));
	SaveTrigger(client, g_iTriggerCount, "vmin", view_as<float>({ -25.0, -25.0, 0.0 }));

	g_iTriggerSelected = g_iTriggers[g_iTriggerCount-1];

	if( g_hTmrBeam == null )
	{
		g_hTmrBeam = CreateTimer(0.1, TimerBeam, _, TIMER_REPEAT);
	}
}

void CreateTriggerMultiple(float vPos[3], float vMaxs[3], float vMins[3])
{
	int trigger = CreateEntityByName("trigger_multiple");
	DispatchKeyValue(trigger, "StartDisabled", "1");
	DispatchKeyValue(trigger, "spawnflags", "1");
	DispatchKeyValue(trigger, "entireteam", "0");
	DispatchKeyValue(trigger, "allowincap", "0");
	DispatchKeyValue(trigger, "allowghost", "0");

	DispatchSpawn(trigger);
	SetEntityModel(trigger, MODEL_BOUNDING);

	SetEntPropVector(trigger, Prop_Send, "m_vecMaxs", vMaxs);
	SetEntPropVector(trigger, Prop_Send, "m_vecMins", vMins);
	SetEntProp(trigger, Prop_Send, "m_nSolidType", 2);

	TeleportEntity(trigger, vPos, NULL_VECTOR, NULL_VECTOR);

	SetVariantString("OnUser1 !self:Enable::5.0:-1");
	AcceptEntityInput(trigger, "AddOutput");
	AcceptEntityInput(trigger, "FireUser1");

	HookSingleEntityOutput(trigger, "OnStartTouch", OnStartTouch);
	g_iTriggers[g_iTriggerCount] = EntIndexToEntRef(trigger);
}

public void OnStartTouch(const char[] output, int caller, int activator, float delay)
{
	if( IsClientInGame(activator) && GetClientTeam(activator) == 2 )
	{
		StartStorm();
		AcceptEntityInput(caller, "Disable");
	}
}

public Action TimerBeam(Handle timer)
{
	if( IsValidEntRef(g_iTriggerSelected) )
	{
		float vMaxs[3], vMins[3], vPos[3];
		GetEntPropVector(g_iTriggerSelected, Prop_Send, "m_vecOrigin", vPos);
		GetEntPropVector(g_iTriggerSelected, Prop_Send, "m_vecMaxs", vMaxs);
		GetEntPropVector(g_iTriggerSelected, Prop_Send, "m_vecMins", vMins);
		AddVectors(vPos, vMaxs, vMaxs);
		AddVectors(vPos, vMins, vMins);
		TE_SendBox(vMins, vMaxs);
		return Plugin_Continue;
	}

	g_hTmrBeam = null;
	return Plugin_Stop;
}

void TE_SendBox(float vMins[3], float vMaxs[3])
{
	float vPos1[3], vPos2[3], vPos3[3], vPos4[3], vPos5[3], vPos6[3];
	vPos1 = vMaxs;
	vPos1[0] = vMins[0];
	vPos2 = vMaxs;
	vPos2[1] = vMins[1];
	vPos3 = vMaxs;
	vPos3[2] = vMins[2];
	vPos4 = vMins;
	vPos4[0] = vMaxs[0];
	vPos5 = vMins;
	vPos5[1] = vMaxs[1];
	vPos6 = vMins;
	vPos6[2] = vMaxs[2];
	TE_SendBeam(vMaxs, vPos1);
	TE_SendBeam(vMaxs, vPos2);
	TE_SendBeam(vMaxs, vPos3);
	TE_SendBeam(vPos6, vPos1);
	TE_SendBeam(vPos6, vPos2);
	TE_SendBeam(vPos6, vMins);
	TE_SendBeam(vPos4, vMins);
	TE_SendBeam(vPos5, vMins);
	TE_SendBeam(vPos5, vPos1);
	TE_SendBeam(vPos5, vPos3);
	TE_SendBeam(vPos4, vPos3);
	TE_SendBeam(vPos4, vPos2);
}

void TE_SendBeam(const float vMins[3], const float vMaxs[3])
{
	TE_SetupBeamPoints(vMins, vMaxs, g_iLaserMaterial, g_iHaloMaterial, 0, 0, 0.2, 1.0, 1.0, 1, 0.0, { 0, 150, 255, 255 }, 0);
	TE_SendToAll();
}



// ====================================================================================================
//					CONFIG - OPEN
// ====================================================================================================
KeyValues ConfigOpen(int configtype = 0)
{
	char sPath[PLATFORM_MAX_PATH];
	if( configtype == 0 )
		BuildPath(Path_SM, sPath, sizeof(sPath), "%s", CONFIG_SETTINGS);
	else
		BuildPath(Path_SM, sPath, sizeof(sPath), "%s", CONFIG_TRIGGERS);

	if( !FileExists(sPath) )
	{
		if( configtype == 2 )
		{
			File hCfg = OpenFile(sPath, "w");
			hCfg.WriteLine("");
			delete hCfg;
		}
		else
		{
			return null;
		}
	}

	KeyValues hFile = new KeyValues("storms");
	if( !hFile.ImportFromFile(sPath) )
	{
		delete hFile;
		return null;
	}

	return hFile;
}

// ====================================================================================================
//					CONFIG - SAVE
// ====================================================================================================
void ConfigSave(KeyValues hFile)
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "%s", CONFIG_TRIGGERS);
	if( !FileExists(sPath) )
	{
		return;
	}

	hFile.Rewind();
	hFile.ExportToFile(sPath);
}

// ====================================================================================================
//					CONFIG JUMP : map, main, use_section, random.
// ====================================================================================================
int ConfigJumpA(KeyValues hFile, char sMap[64])
{
	int completed_jump;

	if( hFile.JumpToKey(sMap) == true || hFile.JumpToKey("main") == true )
	{
		char sJump[64];
		hFile.GetString("use_section", sJump, sizeof(sJump));

		if( strcmp(sJump, "") )
		{
			hFile.Rewind();

			if( hFile.JumpToKey(sJump) == true )
			{
				int count = hFile.GetNum("count");

				if( count != 0 )
				{
					if( g_iRandom == 0 ) // Pick global random, use this index to load data.
						g_iRandom = GetRandomInt(1, count);
					else if( g_iRandom > count )
						g_iRandom = count;

					char sNum[8];
					IntToString(g_iRandom, sNum, sizeof(sNum));
					hFile.GetString(sNum, sJump, sizeof(sJump));
				}

				hFile.Rewind();
			}

			if( hFile.JumpToKey(sJump) == false )
			{
				hFile.Rewind();
				hFile.JumpToKey(sMap);
			}
			else
			{
				strcopy(g_sConfigSection, sizeof(g_sConfigSection), sJump);
				completed_jump = 1;
			}
		}
		else
		{
			completed_jump = 1;
		}
	}

	return completed_jump;
}

// ====================================================================================================
//					CONFIG JUMP
// ====================================================================================================
bool ConfigJumpB(KeyValues hFile, char sMap[64])
{
	hFile.Rewind();

	if( hFile.JumpToKey(sMap) )
	{
		return true;
	}

	return false;
}

// ====================================================================================================
//					CONFIG - Read chance, allow or disallow spawn.
// ====================================================================================================
bool ConfigChance(int client, KeyValues hFile)
{
	if( g_iChance == 0 )
		g_iChance = GetRandomInt(1, 100);

	if( client == 0 )
	{
		int chance = hFile.GetNum("chance", 100);

		if( chance == 0 )
		{
			ResetVars();
			return false;
		}

		if( chance != 100 )
		{
			if( g_iChance > chance )
			{
				ResetVars();
				return false;
			}
		}
	}

	return true;
}



// ====================================================================================================
//					LOAD STORM
// ====================================================================================================
int GetColor(char sTemp[12])
{
	if( strcmp(sTemp, "") == 0 )
	{
		return 0;
	}

	char sColors[3][4];
	ExplodeString(sTemp, " ", sColors, 3, 4);

	int color;
	color = StringToInt(sColors[0]);
	color += 256 * StringToInt(sColors[1]);
	color += 65536 * StringToInt(sColors[2]);
	return color;
}

int Clamp(int value, int max, int min = 0)
{
	if( value < min )
		value = min;
	else if( value > max )
		value = max;
	return value;
}

void LoadStorm(int client = 0)
{
	if( g_iReset == 1 )
		ResetPlugin();

	if( g_bLoaded && client == 0 )
		return;

	strcopy(g_sConfigSection, sizeof(g_sConfigSection), "");

	KeyValues hFile = ConfigOpen();

	if( hFile != null )
	{
		char sMap[64];
		GetCurrentMap(sMap, sizeof(sMap));

		int completed_jump = ConfigJumpA(hFile, sMap);
		if( completed_jump )
		{
			if( ConfigChance(client, hFile) == false )
			{
				delete hFile;
				return;
			}

			hFile.GetString("light_style", g_sCfgLightStyle, sizeof(g_sCfgLightStyle));
			hFile.GetString("fog_color", g_sCfgFogColor, sizeof(g_sCfgFogColor));
			g_iCfgFogBlend =		hFile.GetNum("fog_blend", -1);
			g_iCfgFogIdle =			hFile.GetNum("fog_idle", 0);
			g_iCfgFogStorm =		hFile.GetNum("fog_storm", 0);
			g_iCfgFogIdle2 =		hFile.GetNum("fog_idle_start", 0);
			g_iCfgFogStorm2 =		hFile.GetNum("fog_storm_start", 0);
			g_fCfgFogOpaqueIdle =	hFile.GetFloat("fog_opaque_idle", 0.0);
			g_fCfgFogOpaqueStorm =	hFile.GetFloat("fog_opaque_storm", 0.0);
			g_iCfgFogZIdle =		hFile.GetNum("far_z_idle", 0);
			g_iCfgFogZStorm =		hFile.GetNum("far_z_storm", 0);
			g_iCfgClouds =			hFile.GetNum("clouds", 0);
			g_iCfgLight =			hFile.GetNum("lightning", 0);
			g_iCfgLightDmg =		hFile.GetNum("lightning_damage", 0);
			g_iCfgLightTime =		hFile.GetNum("lightning_time", 0);
			g_iCfgLightFlash =		hFile.GetNum("lightning_flash", 0);
			g_iCfgSnow =			hFile.GetNum("snow", 0);
			g_iCfgSnowIdle =		hFile.GetNum("snow_idle", -1);
			g_iCfgSnowStorm =		hFile.GetNum("snow_storm", -1);
			g_iCfgRain =			hFile.GetNum("rain", 0);
			g_iCfgRainType =		hFile.GetNum("rain_type", 0);
			g_iCfgRainIdle =		hFile.GetNum("rain_idle", -1);
			g_iCfgRainStorm =		hFile.GetNum("rain_storm", -1);
			g_iCfgWind =			hFile.GetNum("wind", 0);
			g_iCfgForever =			hFile.GetNum("forever", 0);
			g_iCfgTimeout =			hFile.GetNum("timeout", 0);
			g_iCfgTimeMax =			hFile.GetNum("duration_max", 0);
			g_iCfgTimeMin =			hFile.GetNum("duration_min", 0);
			g_iCfgTimer =			hFile.GetNum("trigger_timer", 0);
			g_iCfgFinale =			hFile.GetNum("trigger_finale", 0);
			g_iCfgHorde =			hFile.GetNum("trigger_horde", 0);
			g_iCfgPanic =			hFile.GetNum("trigger_panic", 0);
			g_iCfgTank =			hFile.GetNum("trigger_tank", 0);
			g_iCfgTankDeath =		hFile.GetNum("trigger_tank_death", 0);
			g_iCfgWitch =			hFile.GetNum("trigger_witch", 0);
			g_iCfgWitchHead =		hFile.GetNum("trigger_witch_head", 0);
			g_iCfgWitchAlert =		hFile.GetNum("trigger_witch_alert", 0);

			char sColors[12];
			hFile.GetString("sun", sColors, sizeof(sColors));

			if( completed_jump == 1 && ConfigJumpB(hFile, sMap) )
			{
				if( ConfigChance(client, hFile) == false )
				{
					delete hFile;
					return;
				}

				hFile.GetString("fog_color",	g_sCfgFogColor, sizeof(g_sCfgFogColor),		g_sCfgFogColor);
				hFile.GetString("light_style",	g_sCfgLightStyle, sizeof(g_sCfgLightStyle),	g_sCfgLightStyle);
				g_iCfgFogBlend =		hFile.GetNum("fog_blend",							g_iCfgFogBlend);
				g_iCfgFogIdle =			hFile.GetNum("fog_idle",							g_iCfgFogIdle);
				g_iCfgFogStorm =		hFile.GetNum("fog_storm",							g_iCfgFogStorm);
				g_iCfgFogIdle2 =		hFile.GetNum("fog_idle_start",						g_iCfgFogIdle2);
				g_iCfgFogStorm2 =		hFile.GetNum("fog_storm_start",						g_iCfgFogStorm2);
				g_fCfgFogOpaqueIdle =	hFile.GetFloat("fog_opaque_idle",					g_fCfgFogOpaqueIdle);
				g_fCfgFogOpaqueStorm =	hFile.GetFloat("fog_opaque_storm",					g_fCfgFogOpaqueStorm);
				g_iCfgFogZIdle =		hFile.GetNum("far_z_idle",							g_iCfgFogZIdle);
				g_iCfgFogZStorm =		hFile.GetNum("far_z_storm",							g_iCfgFogZStorm);
				g_iCfgClouds =			hFile.GetNum("clouds",								g_iCfgClouds);
				g_iCfgLight =			hFile.GetNum("lightning",							g_iCfgLight);
				g_iCfgLightDmg =		hFile.GetNum("lightning_damage",					g_iCfgLightDmg);
				g_iCfgLightTime =		hFile.GetNum("lightning_time",						g_iCfgLightTime);
				g_iCfgLightFlash =		hFile.GetNum("lightning_flash",						g_iCfgLightFlash);
				g_iCfgSnow =			hFile.GetNum("snow",								g_iCfgSnow);
				g_iCfgSnowIdle =		hFile.GetNum("snow_idle",							g_iCfgSnowIdle);
				g_iCfgSnowStorm =		hFile.GetNum("snow_storm",							g_iCfgSnowStorm);
				g_iCfgRain =			hFile.GetNum("rain",								g_iCfgRain);
				g_iCfgRainType =		hFile.GetNum("rain_type",							g_iCfgRainType);
				g_iCfgRainIdle =		hFile.GetNum("rain_idle",							g_iCfgRainIdle);
				g_iCfgRainStorm =		hFile.GetNum("rain_storm",							g_iCfgRainStorm);
				g_iCfgWind =			hFile.GetNum("wind",								g_iCfgWind);
				g_iCfgTimeout =			hFile.GetNum("timeout",								g_iCfgTimeout);
				g_iCfgForever =			hFile.GetNum("forever",								g_iCfgForever);
				g_iCfgTimeMax =			hFile.GetNum("duration_max",						g_iCfgTimeMax);
				g_iCfgTimeMin =			hFile.GetNum("duration_min",						g_iCfgTimeMin);
				g_iCfgTimer =			hFile.GetNum("trigger_timer",						g_iCfgTimer);
				g_iCfgHorde =			hFile.GetNum("trigger_horde",						g_iCfgHorde);
				g_iCfgPanic =			hFile.GetNum("trigger_panic",						g_iCfgPanic);
				g_iCfgTank =			hFile.GetNum("trigger_tank",						g_iCfgTank);
				g_iCfgTankDeath =		hFile.GetNum("trigger_tank_death",					g_iCfgTankDeath);
				g_iCfgWitch =			hFile.GetNum("trigger_witch",						g_iCfgWitch);
				g_iCfgWitchHead =		hFile.GetNum("trigger_witch_head",					g_iCfgWitchHead);
				hFile.GetString("sun", sColors, sizeof(sColors), sColors);
			}

			g_iCfgRain = Clamp(g_iCfgRain, MAX_RAIN);
			if( g_iCfgRainType != 0 && g_iCfgRainType != 4 && g_iCfgRainType != 6 )
				g_iCfgRainType = 0;

			if( g_iCfgRainIdle == -1 )
				g_iCfgRainIdle = 75;
			if( g_iCfgRainStorm == -1 )
				g_iCfgRainStorm = 250;
			// if( g_iCfgSnowIdle == -1 )
				// g_iCfgSnowIdle = 75;
			// if( g_iCfgSnowStorm == -1 )
				// g_iCfgSnowStorm = 250;


			if( strcmp(sColors, "") )
			{
				ToggleEnvSun(GetColor(sColors));
			}

			g_bLoaded = true;
			g_iStarted = 2;

			CheckDynamicLightStyle();


			if( g_iCfgForever == 0 )
			{
				// TRIGGERS TO START STORM
				if( g_iCfgHorde )
				{
					g_iLogicDirector = CreateEntityByName("logic_director_query");
					DispatchKeyValue(g_iLogicDirector, "minAngerRange", "1");
					DispatchKeyValue(g_iLogicDirector, "maxAngerRange", "10");
					DispatchKeyValue(g_iLogicDirector, "distribution", "3");
					DispatchSpawn(g_iLogicDirector);

					SetVariantString("On20SecondsToMob !self:FireUser1::15:-1");
					AcceptEntityInput(g_iLogicDirector, "AddOutput");

					HookSingleEntityOutput(g_iLogicDirector, "OnUser1", OnDirectorMob);
					g_iLogicDirector = EntIndexToEntRef(g_iLogicDirector);
				}


				if( g_iCfgTimer != 0 )
				{
					g_hTmrTrigger = CreateTimer(float(g_iCfgTimer), TimerTrigger, _, TIMER_REPEAT);
				}


				// TRIGGER BOXES
				KeyValues hTrig = ConfigOpen(1);

				if( hTrig != null )
				{
					if( hTrig.JumpToKey(sMap) == true )
					{
						char sTemp[64];
						float vPos[3], vMin[3], vMax[3];

						for( int i = 1; i <= MAX_TRIGGERS; i++ )
						{
							Format(sTemp, sizeof(sTemp), "vpos_%d", i);
							hTrig.GetVector(sTemp, vPos);
							if( vPos[0] != 0.0 && vPos[1] != 0.0 && vPos[2] != 0.0 )
							{
								Format(sTemp, sizeof(sTemp), "vmax_%d", i);
								hTrig.GetVector(sTemp, vMin);
								Format(sTemp, sizeof(sTemp), "vmin_%d", i);
								hTrig.GetVector(sTemp, vMax);

								CreateTriggerMultiple(vPos, vMin, vMax);
								g_iTriggerCount++;
							}
							else
							{
								break;
							}
						}
					}

					delete hTrig;
				}
			}

			if( g_iCfgClouds )
				CreateClouds();
			if( g_iCfgLight )
				CreateLightning();
			if( g_iCfgRain )
				CreateRain();
			if( g_iCfgSnow && g_iCfgSnowIdle )
				CreateSnow();
			if( g_iCfgWind )
				CreateWind();
			if( g_iCfgFogIdle && g_iCfgFogStorm )
				CreateFog();

			if( g_iCfgLight != 0 || g_iCfgRain != 0 || g_iCfgWind != 0 || g_iCfgFogIdle != 0 || g_iCfgFogStorm != 0 )
			{
				CreateLogics();

				if( g_iCvarMixer )
					CreateMixer();

				g_iStormState = STATE_IDLE;
				StopAmbientSound();
				PlaySoundRain();
				PlaySoundWind();
			}

			if( g_iCfgForever == 1 )
			{
				StartStorm();
			}

			SetSkyname();
			CreateTimer(0.1, TimerSetSkyCam);
		}

		delete hFile;
	}
}

public Action TimerSetSkyCam(Handle timer)
{
	SetBackground(false);
	ChangeLightStyle(g_sCfgLightStyle);
}

public void OnDirectorMob(const char[] output, int caller, int activator, float delay)
{
	if( g_iStormState == STATE_OFF )
		return;

	if( GetRandomInt(1, 100) <= g_iCfgHorde )
		StartStorm();
}

public Action TimerTrigger(Handle timer, any data)
{
	if( g_bCvarAllow == false  )
	{
		g_hTmrTrigger = null;
		return Plugin_Stop;
	}

	StartStorm();
	return Plugin_Continue;
}

void StartStorm(int client = 0)
{
	if( g_iStormState == STATE_IDLE )
	{
		if( g_hTmrTimeout != null )
		{
			if( client != 0 )
			{
				delete g_hTmrTimeout;
			}
			else
			{
				return;
			}
		}

		g_iStormState = STATE_STORM;

		// END STORM TIMER
		if( g_iCfgForever == 0 && g_hTmrEndStorm == null )
		{
			if( g_iCfgTimeMin != 0 && g_iCfgTimeMax != 0 )
			{
				int time = GetRandomInt(g_iCfgTimeMin, g_iCfgTimeMax);
				g_hTmrEndStorm = CreateTimer(float(time), TimerEndStorm);
			}
		}

		// SOUNDS
		StopAmbientSound();
		PlaySoundRain();
		PlaySoundWind();

		// POST PROCESS
		if( g_fCvarPost != 0.0 )
			CreatePostProcess();

		// TRIGGER STORM IN
		if( IsValidEntRef(g_iLogicIn) )
			AcceptEntityInput(g_iLogicIn, "Trigger");

		if( client )
			PrintToChat(client, "%sStorm started.", CHAT_TAG);
	}
}

public Action TimerEndStorm(Handle timer)
{
	g_hTmrEndStorm = null;
	StopStorm();
}

void StopStorm(int client = 0)
{
	if( g_hTmrEndStorm != null ) delete g_hTmrEndStorm;

	// TIMEOUT
	if( g_iCfgForever == 0 && g_iCfgTimeout != 0 )
	{
		if( g_hTmrTimeout != null ) delete g_hTmrTimeout;

		g_hTmrTimeout = CreateTimer(float(g_iCfgTimeout), TimerTimeout);
	}

	if( g_iStormState == STATE_STORM )
	{
		g_iStormState = STATE_IDLE;

		// SOUNDS
		StopAmbientSound();
		PlaySoundRain();
		PlaySoundWind();

		// POST PROCESS
		if( IsValidEntRef(g_iFogVolume) )
			AcceptEntityInput(g_iFogVolume, "Kill");
		if( IsValidEntRef(g_iPostProcess) )
			AcceptEntityInput(g_iPostProcess, "Kill");

		// TRIGGER STORM OUT
		if( IsValidEntRef(g_iLogicOut) )
			AcceptEntityInput(g_iLogicOut, "Trigger");

		if( client )
			PrintToChat(client, "%sStorm ended.", CHAT_TAG);
	}
}

public Action TimerTimeout(Handle timer)
{
	g_hTmrTimeout = null;
}



// ====================================================================================================
//					POST PROCESS
// ====================================================================================================
void CreatePostProcess()
{
	float vPos[3];
	int client;

	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame(i) && IsPlayerAlive(i) )
		{
			client = i;
			break;
		}
	}

	if( client == 0 )
		return;

	GetClientAbsOrigin(client, vPos);

	g_iPostProcess = CreateEntityByName("postprocess_controller");
	if( g_iPostProcess == -1 )
	{
		LogError("Failed to create 'postprocess_controller'");
		return;
	}
	else
	{
		char sTemp[16];
		DispatchKeyValue(g_iPostProcess, "targetname", "silver_fx_settings_storm");
		DispatchKeyValue(g_iPostProcess, "vignettestart", "1");
		DispatchKeyValue(g_iPostProcess, "vignetteend", "4");
		DispatchKeyValue(g_iPostProcess, "vignetteblurstrength", "0");
		DispatchKeyValue(g_iPostProcess, "topvignettestrength", "1");
		DispatchKeyValue(g_iPostProcess, "spawnflags", "1");
		Format(sTemp, sizeof(sTemp), "%f", g_fCvarPost);
		DispatchKeyValue(g_iPostProcess, "localcontraststrength", sTemp);
		DispatchKeyValue(g_iPostProcess, "localcontrastedgestrength", "-.3");
		DispatchKeyValue(g_iPostProcess, "grainstrength", "1");
		DispatchKeyValue(g_iPostProcess, "fadetime", "3");

		DispatchSpawn(g_iPostProcess);
		ActivateEntity(g_iPostProcess);
		TeleportEntity(g_iPostProcess, vPos, NULL_VECTOR, NULL_VECTOR);
		g_iPostProcess = EntIndexToEntRef(g_iPostProcess);
	}

	ToggleFogVolume(false);

	g_iFogVolume = CreateEntityByName("fog_volume");
	if( g_iFogVolume == -1 )
	{
		LogError("Failed to create 'fog_volume'");
	}
	else
	{
		DispatchKeyValue(g_iFogVolume, "PostProcessName", "silver_fx_settings_storm");
		DispatchKeyValue(g_iFogVolume, "spawnflags", "0");

		DispatchSpawn(g_iFogVolume);
		ActivateEntity(g_iFogVolume);

		float vMins[3]; vMins = view_as<float>({ -5000.0, -5000.0, -5000.0 });
		float vMaxs[3]; vMaxs = view_as<float>({ 5000.0, 5000.0, 5000.0 });
		SetEntPropVector(g_iFogVolume, Prop_Send, "m_vecMins", vMins);
		SetEntPropVector(g_iFogVolume, Prop_Send, "m_vecMaxs", vMaxs);
		TeleportEntity(g_iFogVolume, vPos, NULL_VECTOR, NULL_VECTOR);
	}

	ToggleFogVolume(true);
}

// We have to disable fog_volume when we create ours, so it has priority. Thankfully this works.
// Also saves the enabled/disabled state of fog_volume's we change to prevent visual corruption!
void ToggleFogVolume(bool enable)
{
	if( enable == true )
	{
		if( IsValidEntRef(g_iFogVolume) )
		{
			AcceptEntityInput(g_iFogVolume, "Disable");
			AcceptEntityInput(g_iFogVolume, "Enable");
		}
	}

	int m_bDisabled, entity = -1;

	while( (entity = FindEntityByClassname(entity, "fog_volume")) != INVALID_ENT_REFERENCE )
	{
		if( g_iFogVolume == entity )
		{
			break;
		}

		if( enable == true )
		{
			m_bDisabled = GetEntProp(entity, Prop_Data, "m_bDisabled");
			if( m_bDisabled == 0 )
				AcceptEntityInput(entity, "Enable");
		}
		else if( enable == false )
		{
			m_bDisabled = GetEntProp(entity, Prop_Data, "m_bDisabled");
			SetEntProp(entity, Prop_Data, "m_iHammerID", m_bDisabled);
			AcceptEntityInput(entity, "Disable");
		}
	}
}



// ====================================================================================================
//					LIGHTNING
// ====================================================================================================
void CreateLightning()
{
	g_iLight = CreateEntityByName("logic_timer");
	DispatchKeyValue(g_iLight, "targetname", "silver_timer_storm_lightning_strike");
	DispatchKeyValue(g_iLight, "spawnflags", "0");
	DispatchKeyValue(g_iLight, "StartDisabled", "0");
	DispatchKeyValue(g_iLight, "UseRandomTime", "1");
	DispatchKeyValue(g_iLight, "LowerRandomBound", "5");
	DispatchKeyValue(g_iLight, "UpperRandomBound", "25");

	DispatchSpawn(g_iLight);
	ActivateEntity(g_iLight);
	TeleportEntity(g_iLight, view_as<float>({ 1.0, 1.0, 1.0 }), NULL_VECTOR, NULL_VECTOR);
	HookSingleEntityOutput(g_iLight, "OnTimer", OutputOnLightning);
}

public void OutputOnLightning(const char[] output, int caller, int activator, float delay)
{
	DisplayLightning();
}

void DisplayLightning(int client = 0)
{
	// SOUND
	int rand;
	if( client )
		rand = GetRandomInt(0, 3);
	else
		rand = GetRandomInt(0, 1);

	if( rand == 0 )
	{
		rand = GetRandomInt(1, 16);

		if( rand == 1 )			EmitSoundToAll(SOUND_STORM1);
		else if( rand == 2 )	EmitSoundToAll(SOUND_STORM2);
		else if( rand == 3 )	EmitSoundToAll(SOUND_STORM3);
		else if( rand == 4 )	EmitSoundToAll(SOUND_STORM4);
		else if( rand == 5 )	EmitSoundToAll(SOUND_STORM5);
		else if( rand == 6 )	EmitSoundToAll(SOUND_STORM6);
		else if( rand == 7 )	EmitSoundToAll(SOUND_STORM7);
		else if( rand == 8 )	EmitSoundToAll(SOUND_STORM8);
		else if( rand == 9 )	EmitSoundToAll(SOUND_STORM9);
		else if( rand == 10 )	EmitSoundToAll(SOUND_STORM10);
		else if( rand == 11 )	EmitSoundToAll(SOUND_STORM11);
		else if( rand == 12 )	EmitSoundToAll(SOUND_STORM12);
		else if( rand == 13 )	EmitSoundToAll(SOUND_STORM13);
		else if( rand == 14 )	EmitSoundToAll(SOUND_STORM14);
		else if( rand == 15 )	EmitSoundToAll(SOUND_STORM15);
		else if( rand == 16 )	EmitSoundToAll(SOUND_STORM16);
	}


	static int stormstate;
	if( g_iStormState <= STATE_IDLE )
	{
		if( stormstate != 1 )
		{
			SetVariantInt(5);
			AcceptEntityInput(g_iLight, "LowerRandomBound");
			SetVariantInt(25);
			AcceptEntityInput(g_iLight, "UpperRandomBound");
			stormstate = 1;
		}

		if( client == 0 )
		{
			return;
		}
	}
	else
	{
		if( stormstate != 2 )
		{
			SetVariantInt(1);
			AcceptEntityInput(g_iLight, "LowerRandomBound");
			SetVariantInt(5);
			AcceptEntityInput(g_iLight, "UpperRandomBound");
			stormstate = 2;
		}
	}


	// GET RANDOM CLIENT
	float vPos[3], vAim[3];
	int player, clients[MAXPLAYERS+1], count;

	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) )
		{
			clients[count++] = i;
		}
	}


	// RANDOM CLIENT SELECTED
	if( count )
	{
		player = clients[GetRandomInt(0, count-1)];

		float vMaxs[3];
		GetEntPropVector(0, Prop_Data, "m_WorldMaxs", vMaxs);
		GetClientAbsOrigin(player, vPos);

		vPos[0] += GetRandomInt(-1200, 1200);
		vPos[1] += GetRandomInt(-1200, 1200);
		vPos[2] = vMaxs[2];
	}
	else // RANDOM PLACE ON MAP
	{
		float vMins[3], vMaxs[3];
		GetEntPropVector(0, Prop_Data, "m_WorldMins", vMins);
		GetEntPropVector(0, Prop_Data, "m_WorldMaxs", vMaxs);

		vPos[0] = GetRandomFloat(vMins[0], vMaxs[0]);
		vPos[1] = GetRandomFloat(vMins[1], vMaxs[1]);
		vPos[2] = vMaxs[2];
	}


	// TRACE FROM SKYBOX TO GROUND
	client = TraceDown(vPos, vAim);


	// SHAKE
	Handle UserShake = StartMessageAll("Shake");
	BfWrite UserMsgShake = UserMessageToBfWrite(UserShake); // 2018: WTF SERIOUSLY
	UserMsgShake.WriteByte(0);
	UserMsgShake.WriteFloat(1.0);
	UserMsgShake.WriteFloat(0.5);
	UserMsgShake.WriteFloat(0.5);
	EndMessage();


	// PARTICLE TARGET
	char sTemp[64];
	int target = CreateEntityByName("info_particle_target");
	DispatchKeyValue(target, "spawnflags", "0");
	DispatchSpawn(target);
	TeleportEntity(target, vAim, NULL_VECTOR, NULL_VECTOR);

	Format(sTemp, sizeof(sTemp), "storm%d%d%d", target, player, GetRandomInt(99,999));
	DispatchKeyValue(target, "targetname", sTemp);

	SetVariantString("OnUser1 !self:Kill::1.0:1");
	AcceptEntityInput(target, "AddOutput");
	AcceptEntityInput(target, "FireUser1");


	// PARTICLE SYSTEM
	int entity = CreateEntityByName("info_particle_system");
	DispatchKeyValue(entity, "cpoint1", sTemp);
	if( GetRandomInt(0, 1) )
		DispatchKeyValue(entity, "effect_name", PARTICLE_LIGHT1);
	else
		DispatchKeyValue(entity, "effect_name", PARTICLE_LIGHT2);
	DispatchSpawn(entity);
	ActivateEntity(entity);
	TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(entity, "Start");

	SetVariantString("OnUser1 !self:Kill::1.0:1");
	AcceptEntityInput(entity, "AddOutput");
	AcceptEntityInput(entity, "FireUser1");


	// FLASH
	if( g_iCfgLightFlash )
	{
		entity = CreateEntityByName("info_particle_system");
		DispatchKeyValue(entity, "targetname", "silver_fx_screen_flash");
		DispatchKeyValue(entity, "effect_name", PARTICLE_GLOW);
		DispatchSpawn(entity);
		ActivateEntity(entity);
		TeleportEntity(entity, vAim, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(entity, "start");
		SetVariantString("OnUser1 !self:Kill::1.0:1");
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser1");
	}


	// LIGHTNING HURT
	if( g_iCfgLightDmg && client == 0 )
	{
		// FIRE PARTICLES
		vAim[2] += 10.0;
		entity = CreateEntityByName("info_particle_system");
		DispatchKeyValue(entity, "effect_name", PARTICLE_FIRE);
		DispatchSpawn(entity);
		ActivateEntity(entity);
		TeleportEntity(entity, vAim, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(entity, "start");

		Format(sTemp, sizeof(sTemp), "OnUser1 !self:Kill::%d:1", g_iCfgLightTime);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser1");

		// HURT
		int trigger = CreateEntityByName("trigger_hurt");
		DispatchKeyValue(trigger, "spawnflags", "3");
		DispatchKeyValue(trigger, "damagetype", "8");
		DispatchKeyValue(trigger, "damage", "2");
		DispatchSpawn(trigger);
		AcceptEntityInput(trigger, "Enable");

		SetEntityModel(trigger, MODEL_BOUNDING);
		SetEntPropVector(trigger, Prop_Send, "m_vecMaxs", view_as<float>({ 20.0, 20.0, 20.0}));
		SetEntPropVector(trigger, Prop_Send, "m_vecMins", view_as<float>({ -20.0, -20.0, 20.0 }));
		SetEntProp(trigger, Prop_Send, "m_nSolidType", 2);
		TeleportEntity(trigger, vAim, NULL_VECTOR, NULL_VECTOR);

		SetVariantString(sTemp);
		AcceptEntityInput(trigger, "AddOutput");
		AcceptEntityInput(trigger, "FireUser1");
	}
}

int TraceDown(float vPos[3], float vAim[3])
{
	vAim = vPos;
	vAim[2] -= 10000.0;
	vPos[2] -= 500.0;
	TR_TraceRay(vPos, vAim, MASK_OPAQUE, RayType_EndPoint);
	vPos[2] += 500.0;

	int client;

	if( TR_DidHit() )
	{
		TR_GetEndPosition(vAim);
		client = TR_GetEntityIndex();
		if( client == -1 )
			client = 1;
		else if( client > MaxClients )
			client = 0;
	}

	return client;
}



// ====================================================================================================
//					LOGICS - FADE IN / FADE OUT
// ====================================================================================================
void CreateLogics()
{
	char sTemp[64];
	int alpha;

	// ====================================================================================================
	// logic_relay - FADE IN
	// ====================================================================================================
	g_iLogicIn = CreateEntityByName("logic_relay");
	if( g_iLogicIn != -1 )
	{
		DispatchKeyValue(g_iLogicIn, "spawnflags", "2");
		DispatchKeyValue(g_iLogicIn, "targetname", "silver_relay_storm_blendin");

		// SILVER
		if( g_iCfgFogStorm )
		{
			Format(sTemp, sizeof(sTemp), "OnTrigger silver_fog_storm:SetEndDistLerpTo:%d:0:-1", g_iCfgFogStorm);
			SetVariantString(sTemp);
			AcceptEntityInput(g_iLogicIn, "AddOutput");
		}
		if( g_iCfgFogStorm2 )
		{
			Format(sTemp, sizeof(sTemp), "OnTrigger silver_fog_storm:SetStartDistLerpTo:%d:0:-1", g_iCfgFogStorm2);
			SetVariantString(sTemp);
			AcceptEntityInput(g_iLogicIn, "AddOutput");
		}
		if( g_fCfgFogOpaqueStorm )
		{
			Format(sTemp, sizeof(sTemp), "OnTrigger silver_fog_storm:Setmaxdensitylerpto:%f:0:-1", g_fCfgFogOpaqueStorm);
			SetVariantString(sTemp);
			AcceptEntityInput(g_iLogicIn, "AddOutput");
		}
		if( g_iCfgFogZIdle && g_iCfgFogZStorm )
		{
			Format(sTemp, sizeof(sTemp), "OnTrigger silver_fog_storm:SetFarZ:%d:%d:-1", g_iCfgFogZStorm, g_iCfgFogBlend - 1);
			SetVariantString(sTemp);
			AcceptEntityInput(g_iLogicIn, "AddOutput");
		}
		SetVariantString("OnTrigger silver_fog_storm:Set2DSkyboxFogFactorLerpTo:1:0:-1");
		AcceptEntityInput(g_iLogicIn, "AddOutput");
		SetVariantString("OnTrigger silver_fog_storm:StartFogTransition::0.1:-1");
		AcceptEntityInput(g_iLogicIn, "AddOutput");

		// STOLEN
		if( g_iCfgFogStorm )
		{
			Format(sTemp, sizeof(sTemp), "OnTrigger stolen_fog_storm:SetEndDistLerpTo:%d:0:-1", g_iCfgFogStorm);
			SetVariantString(sTemp);
			AcceptEntityInput(g_iLogicIn, "AddOutput");
		}
		if( g_iCfgFogStorm2 )
		{
			Format(sTemp, sizeof(sTemp), "OnTrigger stolen_fog_storm:SetStartDistLerpTo:%d:0:-1", g_iCfgFogStorm2);
			SetVariantString(sTemp);
			AcceptEntityInput(g_iLogicIn, "AddOutput");
		}
		if( g_fCfgFogOpaqueStorm )
		{
			Format(sTemp, sizeof(sTemp), "OnTrigger stolen_fog_storm:Setmaxdensitylerpto:%f:0:-1", g_fCfgFogOpaqueStorm);
			SetVariantString(sTemp);
			AcceptEntityInput(g_iLogicIn, "AddOutput");
		}
		if( g_iCfgFogZIdle && g_iCfgFogZStorm )
		{
			Format(sTemp, sizeof(sTemp), "OnTrigger stolen_fog_storm:SetFarZ:%d:%d:-1", g_iCfgFogZStorm, g_iCfgFogBlend - 1);
			SetVariantString(sTemp);
			AcceptEntityInput(g_iLogicIn, "AddOutput");
		}
		SetVariantString("OnTrigger stolen_fog_storm:Set2DSkyboxFogFactorLerpTo:1:0:-1");
		AcceptEntityInput(g_iLogicIn, "AddOutput");
		SetVariantString("OnTrigger stolen_fog_storm:StartFogTransition::0.1:-1");
		AcceptEntityInput(g_iLogicIn, "AddOutput");

		// RAIN
		alpha = g_iCfgRainStorm - g_iCfgRainIdle;
		Format(sTemp, sizeof(sTemp), "OnTrigger silver_rain:alpha:%d:0.5:-1", g_iCfgRainIdle + (alpha / 4));
		SetVariantString(sTemp);
		AcceptEntityInput(g_iLogicIn, "AddOutput");
		Format(sTemp, sizeof(sTemp), "OnTrigger silver_rain:alpha:%d:1.0:-1", g_iCfgRainIdle + ((alpha / 4) * 2));
		SetVariantString(sTemp);
		AcceptEntityInput(g_iLogicIn, "AddOutput");
		Format(sTemp, sizeof(sTemp), "OnTrigger silver_rain:alpha:%d:1.5:-1", g_iCfgRainIdle + ((alpha / 4) * 3));
		SetVariantString(sTemp);
		AcceptEntityInput(g_iLogicIn, "AddOutput");
		Format(sTemp, sizeof(sTemp), "OnTrigger silver_rain:alpha:%d:2.0:-1", g_iCfgRainStorm);
		SetVariantString(sTemp);
		AcceptEntityInput(g_iLogicIn, "AddOutput");

		// SNOW - Does not work... :/
		// alpha = g_iCfgSnowStorm - g_iCfgSnowIdle;
		// Format(sTemp, sizeof(sTemp), "OnTrigger silver_snow:alpha:%d:0.5:-1", g_iCfgSnowIdle + (alpha / 4));
		// SetVariantString(sTemp);
		// AcceptEntityInput(g_iLogicIn, "AddOutput");
		// Format(sTemp, sizeof(sTemp), "OnTrigger silver_snow:alpha:%d:1.0:-1", g_iCfgSnowIdle + ((alpha / 4) * 2));
		// SetVariantString(sTemp);
		// AcceptEntityInput(g_iLogicIn, "AddOutput");
		// Format(sTemp, sizeof(sTemp), "OnTrigger silver_snow:alpha:%d:1.5:-1", g_iCfgSnowIdle + ((alpha / 4) * 3));
		// SetVariantString(sTemp);
		// AcceptEntityInput(g_iLogicIn, "AddOutput");
		// Format(sTemp, sizeof(sTemp), "OnTrigger silver_snow:alpha:%d:2.0:-1", g_iCfgSnowStorm);
		// SetVariantString(sTemp);
		// AcceptEntityInput(g_iLogicIn, "AddOutput");

		// OUTHER OUTPUTS
		SetVariantString("OnTrigger silver_relay_mix_blendin:Trigger::0:-1");
		AcceptEntityInput(g_iLogicIn, "AddOutput");
		SetVariantString("OnTrigger silver_fx_settings_storm:FireUser1::0:-1");
		AcceptEntityInput(g_iLogicIn, "AddOutput");

		DispatchSpawn(g_iLogicIn);
		ActivateEntity(g_iLogicIn);

		HookSingleEntityOutput(g_iLogicIn, "OnTrigger", OnLogicIn);
	}
	else
		LogError("Failed to create g_iLogicIn 'logic_relay'");


	// ====================================================================================================
	// logic_relay - FADE OUT
	// ====================================================================================================
	g_iLogicOut = CreateEntityByName("logic_relay");
	if( g_iLogicOut != -1 )
	{
		DispatchKeyValue(g_iLogicOut, "spawnflags", "2");
		DispatchKeyValue(g_iLogicOut, "targetname", "silver_relay_storm_blendout");

		// SILVER
		if( g_iCfgFogIdle2 )
		{
			Format(sTemp, sizeof(sTemp), "OnTrigger silver_fog_storm:SetStartDistLerpTo:%d:0:-1", g_iCfgFogIdle2);
			SetVariantString(sTemp);
			AcceptEntityInput(g_iLogicOut, "AddOutput");
		}
		if( g_iCfgFogIdle )
		{
			Format(sTemp, sizeof(sTemp), "OnTrigger silver_fog_storm:SetEndDistLerpTo:%d:0:-1", g_iCfgFogIdle);
			SetVariantString(sTemp);
			AcceptEntityInput(g_iLogicOut, "AddOutput");
		}
		if( g_fCfgFogOpaqueIdle )
		{
			Format(sTemp, sizeof(sTemp), "OnTrigger silver_fog_storm:Setmaxdensitylerpto:%f:0:-1", g_fCfgFogOpaqueIdle);
			SetVariantString(sTemp);
			AcceptEntityInput(g_iLogicOut, "AddOutput");
		}
		if( g_iCfgFogZIdle && g_iCfgFogZStorm )
		{
			Format(sTemp, sizeof(sTemp), "OnTrigger silver_fog_storm:SetFarZ:%d:1:-1", g_iCfgFogZIdle);
			SetVariantString(sTemp);
			AcceptEntityInput(g_iLogicOut, "AddOutput");
		}
		SetVariantString("OnTrigger silver_fog_storm:Set2DSkyboxFogFactorLerpTo:0:0:-1");
		AcceptEntityInput(g_iLogicOut, "AddOutput");
		SetVariantString("OnTrigger silver_fog_storm:StartFogTransition::0.1:-1");
		AcceptEntityInput(g_iLogicOut, "AddOutput");

		// STOLEN
		if( g_iCfgFogIdle2 )
		{
			Format(sTemp, sizeof(sTemp), "OnTrigger stolen_fog_storm:SetStartDistLerpTo:%d:0:-1", g_iCfgFogIdle2);
			SetVariantString(sTemp);
			AcceptEntityInput(g_iLogicOut, "AddOutput");
		}
		if( g_iCfgFogIdle )
		{
			Format(sTemp, sizeof(sTemp), "OnTrigger stolen_fog_storm:SetEndDistLerpTo:%d:0:-1", g_iCfgFogIdle);
			SetVariantString(sTemp);
			AcceptEntityInput(g_iLogicOut, "AddOutput");
		}
		if( g_fCfgFogOpaqueIdle )
		{
			Format(sTemp, sizeof(sTemp), "OnTrigger stolen_fog_storm:Setmaxdensitylerpto:%f:0:-1", g_fCfgFogOpaqueIdle);
			SetVariantString(sTemp);
			AcceptEntityInput(g_iLogicOut, "AddOutput");
		}
		if( g_iCfgFogZIdle && g_iCfgFogZStorm )
		{
			Format(sTemp, sizeof(sTemp), "OnTrigger stolen_fog_storm:SetFarZ:%d:1:-1", g_iCfgFogZIdle);
			SetVariantString(sTemp);
			AcceptEntityInput(g_iLogicOut, "AddOutput");
		}
		SetVariantString("OnTrigger stolen_fog_storm:Set2DSkyboxFogFactorLerpTo:0:0:-1");
		AcceptEntityInput(g_iLogicOut, "AddOutput");
		SetVariantString("OnTrigger stolen_fog_storm:StartFogTransition::0.1:-1");
		AcceptEntityInput(g_iLogicOut, "AddOutput");

		// RAIN
		alpha = g_iCfgRainStorm - g_iCfgRainIdle;
		Format(sTemp, sizeof(sTemp), "OnTrigger silver_rain:alpha:%d:0.5:-1", g_iCfgRainIdle + ((alpha / 4) * 2));
		SetVariantString(sTemp);
		AcceptEntityInput(g_iLogicOut, "AddOutput");
		Format(sTemp, sizeof(sTemp), "OnTrigger silver_rain:alpha:%d:1.0:-1", g_iCfgRainIdle + ((alpha / 4) * 3));
		SetVariantString(sTemp);
		AcceptEntityInput(g_iLogicOut, "AddOutput");
		Format(sTemp, sizeof(sTemp), "OnTrigger silver_rain:alpha:%d:1.5:-1", g_iCfgRainIdle + (alpha / 4));
		SetVariantString(sTemp);
		AcceptEntityInput(g_iLogicOut, "AddOutput");
		Format(sTemp, sizeof(sTemp), "OnTrigger silver_rain:alpha:%d:2.0:-1", g_iCfgRainIdle);
		SetVariantString(sTemp);
		AcceptEntityInput(g_iLogicOut, "AddOutput");

		// OTHER OUTPUTS
		SetVariantString("OnTrigger silver_relay_mix_blendout:Trigger::0:-1");
		AcceptEntityInput(g_iLogicOut, "AddOutput");

		DispatchSpawn(g_iLogicOut);
		ActivateEntity(g_iLogicOut);
		AcceptEntityInput(g_iLogicOut, "Trigger");

		HookSingleEntityOutput(g_iLogicOut, "OnTrigger", OnLogicOut);
	}
	else
		LogError("Failed to create g_iLogicOut 'logic_relay'");
}

public void OnLogicOut(const char[] output, int entity, int activator, float delay)
{
	if( g_iCfgSnow && g_iCfgSnowIdle == 1 )
	{
		if( IsValidEntRef(g_iSnow) == false )
		{
			CreateSnow();
		}
	} else {
		if( IsValidEntRef(g_iSnow) )
		{
			AcceptEntityInput(g_iSnow, "Kill");
			g_iSnow = 0;
		}
	}
}

public void OnLogicIn(const char[] output, int entity, int activator, float delay)
{
	if( g_iCfgSnow && g_iCfgSnowStorm == 1 )
	{
		if( IsValidEntRef(g_iSnow) == false )
		{
			CreateSnow();
		}
	} else {
		if( IsValidEntRef(g_iSnow) )
		{
			AcceptEntityInput(g_iSnow, "Kill");
			g_iSnow = 0;
		}
	}
}



// ====================================================================================================
//					sound_mix_layer
// ====================================================================================================
void CreateMixer()
{
	g_iStormLayer = CreateEntityByName("sound_mix_layer");
	if( g_iStormLayer != -1 )
	{
		DispatchKeyValue(g_iStormLayer, "targetname", "silver_rainLayer_voip");
		DispatchKeyValue(g_iStormLayer, "MixLayerName", "stormLayer");
		DispatchKeyValue(g_iStormLayer, "Level", "1");

		DispatchSpawn(g_iStormLayer);
		ActivateEntity(g_iStormLayer);

		g_iStormLayer = EntIndexToEntRef(g_iStormLayer);
	}
	else
		LogError("Failed to create g_iStormLayer 'sound_mix_layer'");


	g_iVoip = CreateEntityByName("sound_mix_layer");
	if( g_iVoip != -1 )
	{
		DispatchKeyValue(g_iVoip, "targetname", "silver_rainLayer_voip");
		DispatchKeyValue(g_iVoip, "MixLayerName", "voipLayer");
		DispatchSpawn(g_iVoip);
		g_iVoip = EntIndexToEntRef(g_iVoip);
	}
	else
		LogError("Failed to create g_iVoip 'sound_mix_layer'");


	g_iVoipIn = CreateEntityByName("logic_relay");
	if( g_iVoipIn != -1 )
	{
		DispatchKeyValue(g_iVoipIn, "targetname", "silver_relay_mix_blendin");

		SetVariantString("OnTrigger silver_rainLayer_voip:Level:.2:0:-1");
		AcceptEntityInput(g_iVoipIn, "AddOutput");
		SetVariantString("OnTrigger silver_rainLayer_voip:Level:.4:1:-1");
		AcceptEntityInput(g_iVoipIn, "AddOutput");
		SetVariantString("OnTrigger silver_rainLayer_voip:Level:.6:2:-1");
		AcceptEntityInput(g_iVoipIn, "AddOutput");
		SetVariantString("OnTrigger silver_rainLayer_voip:Level:.8:3:-1");
		AcceptEntityInput(g_iVoipIn, "AddOutput");
		SetVariantString("OnTrigger silver_rainLayer_voip:Level:1:4:-1");
		AcceptEntityInput(g_iVoipIn, "AddOutput");

		DispatchSpawn(g_iVoipIn);
		ActivateEntity(g_iVoipIn);
	}
	else
		LogError("Failed to create g_iVoipIn 'logic_relay'");


	g_iVoipOut = CreateEntityByName("logic_relay");
	if( g_iVoipOut != -1 )
	{
		DispatchKeyValue(g_iVoipOut, "targetname", "silver_relay_mix_blendout");

		SetVariantString("OnTrigger silver_rainLayer_voip:Level:1:0:-1");
		AcceptEntityInput(g_iVoipOut, "AddOutput");
		SetVariantString("OnTrigger silver_rainLayer_voip:Level:.8:1:-1");
		AcceptEntityInput(g_iVoipOut, "AddOutput");
		SetVariantString("OnTrigger silver_rainLayer_voip:Level:.6:2:-1");
		AcceptEntityInput(g_iVoipOut, "AddOutput");
		SetVariantString("OnTrigger silver_rainLayer_voip:Level:.4:3:-1");
		AcceptEntityInput(g_iVoipOut, "AddOutput");
		SetVariantString("OnTrigger silver_rainLayer_voip:Level:.2:4:-1");
		AcceptEntityInput(g_iVoipOut, "AddOutput");

		DispatchSpawn(g_iVoipOut);
		ActivateEntity(g_iVoipOut);
	}
	else
		LogError("Failed to create g_iVoipOut 'logic_relay'");
}



// ====================================================================================================
//					env_sun
// ====================================================================================================
void ToggleEnvSun(int color)
{
	int env_sun = -1;
	while( (env_sun = FindEntityByClassname(env_sun, "env_sun")) != INVALID_ENT_REFERENCE )
	{
		if( g_iSunSaved == -1 )
		{
			g_iSunSaved = GetEntProp(env_sun, Prop_Send, "m_clrRender");
		}

		if( color == 0 )
			AcceptEntityInput(env_sun, "TurnOff");
		else
		{
			SetEntProp(env_sun, Prop_Send, "m_clrRender", color);
			AcceptEntityInput(env_sun, "TurnOn");
		}
	}
}



// ====================================================================================================
//					FOG CLOUDS
// ====================================================================================================
void CreateClouds()
{
	int entity = FindEntityByClassname(-1, "sky_camera");

	if( entity != -1 )
	{
		float vPos[3];
		GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vPos);

		g_iParticleFog = CreateEntityByName("info_particle_system");
		DispatchKeyValue(g_iParticleFog, "effect_name", PARTICLE_FOG);
		DispatchKeyValue(g_iParticleFog, "targetname", "silver_fx_skybox_general_lightning");
		DispatchSpawn(g_iParticleFog);
		ActivateEntity(g_iParticleFog);
		AcceptEntityInput(g_iParticleFog, "Start");
		g_iParticleFog = EntIndexToEntRef(g_iParticleFog);
		TeleportEntity(g_iParticleFog, vPos, NULL_VECTOR, NULL_VECTOR);
	}
}



// ====================================================================================================
//					env_fog_controller
// ====================================================================================================
void CreateFog()
{
	if( g_iFogOn == 1 )
		return;
	g_iFogOn = 1;

	char sTemp[8];
	int entity = -1;
	int count;

	entity = -1;
	while( (entity = FindEntityByClassname(entity, "env_fog_controller")) != INVALID_ENT_REFERENCE )
	{
		if( count < MAX_FOG )
		{
			GetEntPropString(entity, Prop_Data, "m_iName", g_sFogStolen[count], 64);
			g_iFogStolen[count][0] = EntIndexToEntRef(entity);
			g_iFogStolen[count][1] = GetEntProp(entity, Prop_Send, "m_fog.colorPrimary");
			g_iFogStolen[count][2] = GetEntProp(entity, Prop_Send, "m_fog.colorSecondary");
			g_iFogStolen[count][3] = GetEntProp(entity, Prop_Send, "m_fog.colorPrimaryLerpTo");
			g_iFogStolen[count][4] = GetEntProp(entity, Prop_Send, "m_fog.colorSecondaryLerpTo");
			g_fFogStolen[count][0] = GetEntPropFloat(entity, Prop_Send, "m_fog.start");
			g_fFogStolen[count][1] = GetEntPropFloat(entity, Prop_Send, "m_fog.end");
			g_fFogStolen[count][2] = GetEntPropFloat(entity, Prop_Send, "m_fog.maxdensity");
			g_fFogStolen[count][3] = GetEntPropFloat(entity, Prop_Send, "m_fog.farz");
			g_fFogStolen[count][4] = GetEntPropFloat(entity, Prop_Send, "m_fog.skyboxFogFactor");
			g_fFogStolen[count][5] = GetEntPropFloat(entity, Prop_Send, "m_fog.startLerpTo");
			g_fFogStolen[count][6] = GetEntPropFloat(entity, Prop_Send, "m_fog.endLerpTo");
			g_fFogStolen[count][7] = GetEntPropFloat(entity, Prop_Send, "m_fog.maxdensityLerpTo");
			g_fFogStolen[count][8] = GetEntPropFloat(entity, Prop_Send, "m_fog.duration");
			count++;
		}

		DispatchKeyValue(entity, "targetname", "stolen_fog_storm");
		DispatchKeyValue(entity, "use_angles", "1");
		DispatchKeyValue(entity, "fogstart", "1");
		DispatchKeyValue(entity, "fogmaxdensity", "1");
		DispatchKeyValue(entity, "heightFogStart", "0.0");
		DispatchKeyValue(entity, "heightFogMaxDensity", "1.0");
		DispatchKeyValue(entity, "heightFogDensity", "0.0");
		DispatchKeyValue(entity, "fogdir", "1 0 0");
		DispatchKeyValue(entity, "angles", "0 180 0");

		if( g_iCfgFogBlend != -1 )
		{
			IntToString(g_iCfgFogBlend, sTemp, sizeof(sTemp));
			DispatchKeyValue(entity, "foglerptime", sTemp);
		}

		if( strcmp(g_sCfgFogColor, "") )
		{
			DispatchKeyValue(entity, "fogcolor", g_sCfgFogColor);
			DispatchKeyValue(entity, "fogcolor2", g_sCfgFogColor);
			SetVariantString(g_sCfgFogColor);
			AcceptEntityInput(entity, "SetColorLerpTo");
		}
	}

	if( count == 0 )
	{
		g_iFog = CreateEntityByName("env_fog_controller");
		if( g_iFog != -1 )
		{
			DispatchKeyValue(g_iFog, "targetname", "silver_fog_storm");
			DispatchKeyValue(g_iFog, "use_angles", "1");
			DispatchKeyValue(g_iFog, "fogstart", "1");
			DispatchKeyValue(g_iFog, "fogmaxdensity", "1");
			DispatchKeyValue(g_iFog, "heightFogStart", "0.0");
			DispatchKeyValue(g_iFog, "heightFogMaxDensity", "1.0");
			DispatchKeyValue(g_iFog, "heightFogDensity", "0.0");
			DispatchKeyValue(g_iFog, "fogenable", "1");
			DispatchKeyValue(g_iFog, "fogdir", "1 0 0");
			DispatchKeyValue(g_iFog, "angles", "0 180 0");

			if( g_iCfgFogBlend != -1 )
			{
				IntToString(g_iCfgFogBlend, sTemp, sizeof(sTemp));
				DispatchKeyValue(g_iFog, "foglerptime", sTemp);
			}

			if( g_iCfgFogZIdle && g_iCfgFogZStorm )
			{
				IntToString(g_iCfgFogZIdle, sTemp, sizeof(sTemp));
				DispatchKeyValue(g_iFog, "farz", sTemp);
			}

			if( strcmp(g_sCfgFogColor, "") )
			{
				DispatchKeyValue(g_iFog, "fogcolor", g_sCfgFogColor);
				DispatchKeyValue(g_iFog, "fogcolor2", g_sCfgFogColor);
			}

			DispatchSpawn(g_iFog);
			ActivateEntity(g_iFog);

			TeleportEntity(g_iFog, view_as<float>({ 10.0, 15.0, 20.0 }), NULL_VECTOR, NULL_VECTOR);
			g_iFog = EntIndexToEntRef(g_iFog);
		}
	}
}



// ====================================================================================================
//					func_precipitation
// ====================================================================================================
//					Create Rain
// ====================================================================================================
void CreateRain()
{
	int value, entity = -1;
	while( (entity = FindEntityByClassname(entity, "func_precipitation")) != INVALID_ENT_REFERENCE )
	{
		value = GetEntProp(entity, Prop_Data, "m_nPrecipType");
		if( value < 0 || value == 4 || value > 5 )
			AcceptEntityInput(entity, "Kill");
	}

	for( int i = 0; i < g_iCfgRain; i++ )
	{
		entity = CreateEntityByName("func_precipitation");
		if( entity != -1 )
		{
			char buffer[128];
			GetCurrentMap(buffer, sizeof(buffer));
			Format(buffer, sizeof(buffer), "maps/%s.bsp", buffer);

			DispatchKeyValue(entity, "model", buffer);
			DispatchKeyValue(entity, "targetname", "silver_rain");
			IntToString(g_iCfgRainType, buffer, sizeof(buffer));
			DispatchKeyValue(entity, "preciptype", buffer);
			DispatchKeyValue(entity, "minSpeed", "25");
			DispatchKeyValue(entity, "maxSpeed", "35");
			DispatchKeyValue(entity, "renderfx", "21");
			DispatchKeyValue(entity, "rendercolor", "31 34 52");
			DispatchKeyValue(entity, "renderamt", "100");
			g_iRains[i] = EntIndexToEntRef(entity);

			float vMins[3], vMaxs[3];
			GetEntPropVector(0, Prop_Data, "m_WorldMins", vMins);
			GetEntPropVector(0, Prop_Data, "m_WorldMaxs", vMaxs);
			SetEntPropVector(entity, Prop_Send, "m_vecMins", vMins);
			SetEntPropVector(entity, Prop_Send, "m_vecMaxs", vMaxs);

			float vBuff[3];
			vBuff[0] = vMins[0] + vMaxs[0];
			vBuff[1] = vMins[1] + vMaxs[1];
			vBuff[2] = vMins[2] + vMaxs[2];

			DispatchSpawn(entity);
			ActivateEntity(entity);
			TeleportEntity(entity, vBuff, NULL_VECTOR, NULL_VECTOR);
		}
		else
			LogError("Failed to create Rain %d 'func_precipitation'", i+1);
	}
}



// ====================================================================================================
//					Create Snow
// ====================================================================================================
void CreateSnow()
{
	int value, entity = -1;
	while( (entity = FindEntityByClassname(entity, "func_precipitation")) != INVALID_ENT_REFERENCE )
	{
		value = GetEntProp(entity, Prop_Data, "m_nPrecipType");
		if( value < 0 || value == 4 || value > 5 )
			AcceptEntityInput(entity, "Kill");
	}

	entity = CreateEntityByName("func_precipitation");
	if( entity != -1 )
	{
		char buffer[128];
		GetCurrentMap(buffer, sizeof(buffer));
		Format(buffer, sizeof(buffer), "maps/%s.bsp", buffer);

		DispatchKeyValue(entity, "model", buffer);
		DispatchKeyValue(entity, "targetname", "silver_snow");
		DispatchKeyValue(entity, "preciptype", "3");
		DispatchKeyValue(entity, "renderamt", "100");
		DispatchKeyValue(entity, "rendercolor", "200 200 200");

		g_iSnow = EntIndexToEntRef(entity);

		float vBuff[3], vMins[3], vMaxs[3];
		GetEntPropVector(0, Prop_Data, "m_WorldMins", vMins);
		GetEntPropVector(0, Prop_Data, "m_WorldMaxs", vMaxs);
		SetEntPropVector(g_iSnow, Prop_Send, "m_vecMins", vMins);
		SetEntPropVector(g_iSnow, Prop_Send, "m_vecMaxs", vMaxs);

		bool found = false;
		for( int i = 1; i <= MaxClients; i++ )
		{
			if( !found && IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) )
			{
				found = true;
				GetClientAbsOrigin(i, vBuff);
			}
		}

		if( !found )
		{
			vBuff[0] = vMins[0] + vMaxs[0];
			vBuff[1] = vMins[1] + vMaxs[1];
			vBuff[2] = vMins[2] + vMaxs[2];
		}

		DispatchSpawn(g_iSnow);
		ActivateEntity(g_iSnow);
		TeleportEntity(g_iSnow, vBuff, NULL_VECTOR, NULL_VECTOR);
	}
	else
		LogError("Failed to create Snow %d 'func_precipitation'");
}



// ====================================================================================================
//					env_wind
// ====================================================================================================
void CreateWind()
{
	g_iWind = CreateEntityByName("env_wind");
	if( g_iWind != -1 )
	{
		DispatchKeyValue(g_iWind, "targetname", "silverwind");
		DispatchKeyValue(g_iWind, "windradius", "-1");
		DispatchKeyValue(g_iWind, "minwind", "75");
		DispatchKeyValue(g_iWind, "mingustdelay", "15");
		DispatchKeyValue(g_iWind, "mingust", "100");
		DispatchKeyValue(g_iWind, "maxwind", "150");
		DispatchKeyValue(g_iWind, "maxgustdelay", "30");
		DispatchKeyValue(g_iWind, "maxgust", "200");
		DispatchKeyValue(g_iWind, "gustduration", "5");
		DispatchKeyValue(g_iWind, "gustdirchange", "20");
		DispatchSpawn(g_iWind);

		ActivateEntity(g_iWind);

		g_iWind = EntIndexToEntRef(g_iWind);
	}
	else
		LogError("Failed to create 'env_wind'");
}



// ====================================================================================================
//					SOUNDS
// ====================================================================================================
void PlayAmbientSound(const char[] sample)
{
	if( IsValidEntRef(g_iSound) == false )
	{
		int entity = CreateEntityByName("ambient_generic");
		if( entity != -1 )
		{
			DispatchKeyValue(entity, "spawnflags", "17");
			DispatchKeyValue(entity, "message", sample);
			DispatchKeyValue(entity, "Volume", "10");
			DispatchKeyValue(entity, "health", "0");
			DispatchSpawn(entity);
			ActivateEntity(entity);
			TeleportEntity(entity, view_as<float>({ 10.0, 20.0, 30.0 }), NULL_VECTOR, NULL_VECTOR);

			SetVariantString("OnUser1 !self:Volume:2:0.1:-1");
			AcceptEntityInput(entity, "AddOutput");
			SetVariantString("OnUser1 !self:Volume:4:0.2:-1");
			AcceptEntityInput(entity, "AddOutput");
			SetVariantString("OnUser1 !self:Volume:6:0.3:-1");
			AcceptEntityInput(entity, "AddOutput");
			SetVariantString("OnUser1 !self:Volume:8:0.4:-1");
			AcceptEntityInput(entity, "AddOutput");
			SetVariantString("OnUser1 !self:Volume:10:0.5:-1");
			AcceptEntityInput(entity, "AddOutput");
			AcceptEntityInput(entity, "FireUser1");

			g_iSound = EntIndexToEntRef(entity);
		}
	}
}

void StopAmbientSound()
{
	if( g_iCfgRain != 0 || g_iCfgWind != 0 )
	{
		if( IsValidEntRef(g_iSound) == true )
		{
			SetVariantInt(0);
			AcceptEntityInput(g_iSound, "Volume");
			AcceptEntityInput(g_iSound, "Kill");
		}

		g_iSound = 0;
	}

	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame(i) )
		{
			StopSound(i, SNDCHAN_AUTO, SOUND_WIND1);
			StopSound(i, SNDCHAN_AUTO, SOUND_WIND2);
			StopSound(i, SNDCHAN_AUTO, SOUND_WIND3);
			StopSound(i, SNDCHAN_AUTO, SOUND_WIND4);
			StopSound(i, SNDCHAN_AUTO, SOUND_WIND5);
			StopSound(i, SNDCHAN_AUTO, SOUND_WIND6);
			StopSound(i, SNDCHAN_AUTO, SOUND_WIND7);
			StopSound(i, SNDCHAN_AUTO, SOUND_WIND8);
		}
	}
}

void PlaySoundRain()
{
	if( g_iCfgRain )
	{
		int random;
		if( g_iStormState <= STATE_IDLE )	random = GetRandomInt(1, 4);
		else								random = GetRandomInt(5, 10);

		if( random == 1 )			PlayAmbientSound(SOUND_RAIN1);
		else if( random == 2 )		PlayAmbientSound(SOUND_RAIN2);
		else if( random == 3 )		PlayAmbientSound(SOUND_RAIN3);
		else if( random == 4 )		PlayAmbientSound(SOUND_RAIN4);
		else if( random == 5 )		PlayAmbientSound(SOUND_RAIN5);
		else if( random == 6 )		PlayAmbientSound(SOUND_RAIN6);
		else if( random == 7 )		PlayAmbientSound(SOUND_RAIN7);
		else if( random == 8 )		PlayAmbientSound(SOUND_RAIN8);
		else if( random == 9 )		PlayAmbientSound(SOUND_RAIN9);
		else if( random == 10 )		PlayAmbientSound(SOUND_RAIN10);
	}
}

void PlaySoundWind()
{
	if( g_iCfgWind )
	{
		if( g_iStormState <= STATE_IDLE )	g_iCfgWind = GetRandomInt(1, 4);
		else								g_iCfgWind = GetRandomInt(5, 8);

		if( g_iCfgWind == 1 )		EmitSoundToAll(SOUND_WIND1);
		else if( g_iCfgWind == 2 )	EmitSoundToAll(SOUND_WIND2, _, _, 42);
		else if( g_iCfgWind == 3 )	EmitSoundToAll(SOUND_WIND3, _, _, 43);
		else if( g_iCfgWind == 4 )	EmitSoundToAll(SOUND_WIND4, _, _, 42);
		else if( g_iCfgWind == 5 )	EmitSoundToAll(SOUND_WIND5, _, _, 43);
		else if( g_iCfgWind == 6 )	EmitSoundToAll(SOUND_WIND6, _, _, 42);
		else if( g_iCfgWind == 7 )	EmitSoundToAll(SOUND_WIND7, _, _, 42);
		else if( g_iCfgWind == 8 )	EmitSoundToAll(SOUND_WIND8, _, _, 42);
	}
}



// ====================================================================================================
//					OTHER
// ====================================================================================================
void PrecacheParticle(const char[] ParticleName)
{
	int Particle = CreateEntityByName("info_particle_system");
	DispatchKeyValue(Particle, "effect_name", ParticleName);
	DispatchSpawn(Particle);
	ActivateEntity(Particle);
	AcceptEntityInput(Particle, "start");
	Particle = EntIndexToEntRef(Particle);
	SetVariantString("OnUser1 !self:Kill::0.1:-1");
	AcceptEntityInput(Particle, "AddOutput");
	AcceptEntityInput(Particle, "FireUser1");
}

bool IsValidEntRef(int entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		return true;
	return false;
}