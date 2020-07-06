#pragma semicolon 1

#define DEBUG_WEIGHTS 0
#define DEBUG_SPAWNQUEUE 0
#define DEBUG_TIMERS 0
#define DEBUG_POSITIONER 0

#define VANILLA_COOP_SI_LIMIT 2
#define NUM_TYPES_INFECTED 6

#include <sourcemod>
#include <sdktools>
// #include <left4downtown>
#include <left4dhooks>

new Handle:hCvarReadyUpEnabled;
new Handle:hCvarConfigName;
new Handle:hCvarLineOfSightStarvationTime;
new Handle:hTimerHUD;

new bool:bShowSpawnerHUD[MAXPLAYERS];
new Float:g_fTimeLOS[100000]; // not sure what the largest possible userid is

// Modules
#include "includes/hardcoop_util.sp"
#include "modules/SS_SpawnQuantities.sp"
#include "modules/SS_SpawnTimers.sp"
#include "modules/SS_SpawnQueue.sp"
#include "modules/SS_SpawnPositioner.sp"

/*
 * TODO:
*/

/***********************************************************************************************************************************************************************************
     					All credit for the spawn timer, quantities and queue modules goes to the developers of the 'l4d2_autoIS' plugin                            
***********************************************************************************************************************************************************************************/
  
public Plugin:myinfo = 
{
	name = "刷特感",
	author = "Tordecybombo, breezy",
	description = "Provides customisable special infected spawing beyond vanilla coop limits",
	version = "",
	url = ""
};

public APLRes:AskPluginLoad2(Handle:plugin, bool:late, String:error[], errMax) { 
	// L4D2 check
	decl String:mod[32];
	GetGameFolderName(mod, sizeof(mod));
	if( !StrEqual(mod, "left4dead2", false) ) {
		return APLRes_Failure;
	}
	return APLRes_Success;
}

public OnPluginStart() {	
	// Load modules
	SpawnQuantities_OnModuleStart();
	SpawnTimers_OnModuleStart();
	SpawnQueue_OnModuleStart();
	SpawnPositioner_OnModuleStart();
	// Compatibility with server_namer.smx
	hCvarReadyUpEnabled = CreateConVar("l4d_ready_enabled", "1", "This cvar from readyup.smx is required by server_namer.smx, but is duplicated here to avoid use of readyup.smx");
	hCvarConfigName = CreateConVar("l4d_ready_cfg_name", "Hard Coop", "This cvar from readyup.smx is required by server_namer.smx, but is duplicated here to avoid use of readyup.smx");
	SetConVarFlags( hCvarReadyUpEnabled, FCVAR_CHEAT ); SetConVarFlags( hCvarConfigName, FCVAR_CHEAT ); // get rid of 'symbol is assigned a value that is never used' compiler warnings
	
	// Resetting at the end of rounds
	HookEvent("mission_lost", EventHook:OnRoundOver, EventHookMode_PostNoCopy);
	HookEvent("map_transition", EventHook:OnRoundOver, EventHookMode_PostNoCopy);
	HookEvent("round_end", EventHook:OnRoundOver, EventHookMode_PostNoCopy);
	HookEvent("survival_round_start", EventHook:OnSurvivalRoundStart, EventHookMode_PostNoCopy);
	// Faster spawns
	HookEvent("player_death", OnPlayerDeath, EventHookMode_PostNoCopy);
	// LOS tracking
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_PostNoCopy);
	hCvarLineOfSightStarvationTime = CreateConVar( "ss_los_starvation_time", "7.5", "当SI看不见敌人多长时间处死" );
	
	// Customisation commands
	RegConsoleCmd("sm_weight", Cmd_SetWeight, "Set spawn weights for SI classes");
	RegConsoleCmd("sm_limit", Cmd_SetLimit, "Set individual, total and simultaneous SI spawn limits");
	RegConsoleCmd("sm_timer", Cmd_SetTimer, "Set a variable or constant spawn time (seconds)");
	RegConsoleCmd("sm_spawnmode", Cmd_SpawnMode, "[ 0 = vanilla spawning, 1 = radial repositioning, 2 = grid repositioning ]");
	RegConsoleCmd("sm_spawnproximity", Cmd_SpawnProximity, "Set the minimum and maximum spawn distance");
	// Admin commands
	RegAdminCmd("sm_resetspawns", Cmd_ResetSpawns, ADMFLAG_RCON, "Reset by slaying all special infected and restarting the timer");
	RegAdminCmd("sm_forcetimer", Cmd_StartSpawnTimerManually, ADMFLAG_RCON, "Manually start the spawn timer");
	
	AutoExecConfig(true, "l4d2_specialspawnner");
}

public OnPluginEnd() {
	ResetConVar( FindConVar("director_spectate_specials") );
	ResetConVar( FindConVar("director_no_specials") ); // Disable Director spawning specials naturally
	ResetConVar( FindConVar("z_safe_spawn_range") );
	ResetConVar( FindConVar("z_spawn_safety_range") );
	ResetConVar( FindConVar("z_spawn_range") );
	ResetConVar( FindConVar("z_discard_range") );
	
	CloseHandle(hTimerHUD);
	SpawnTimers_OnModuleEnd();
	SpawnPositioner_OnModuleEnd();
}

/***********************************************************************************************************************************************************************************

                                                 					PER ROUND
                                                                    
***********************************************************************************************************************************************************************************/

public OnConfigsExecuted() {	
	// Load customised cvar values to override any .cfg values
	LoadCacheSpawnLimits();
	LoadCacheSpawnWeights(); 
	hTimerHUD = CreateTimer( 0.1, Timer_DrawSpawnerHUD, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );
}

public Action:L4D_OnFirstSurvivorLeftSafeArea(client) { 
	// Disable for PvP modes
	/*
	decl String:gameMode[16];
	GetConVarString(FindConVar("mp_gamemode"), gameMode, sizeof(gameMode));
	if( StrContains(gameMode, "versus", false) != -1 || StrContains(gameMode, "scavenge", false) != -1 ) {
		SetFailState("Plugin does not support PvP modes");
	} else if( StrContains(gameMode, "survival", false) == -1 ) { // would otherwise cause spawns in survival before button is pressed
		g_bHasSpawnTimerStarted = false;
		StartSpawnTimer();
	}
	*/
	
	int entity = CreateEntityByName("info_gamemode");
	if(!IsValidEntity(entity))
	{
		decl String:gameMode[16];
		GetConVarString(FindConVar("mp_gamemode"), gameMode, sizeof(gameMode));
		if( StrContains(gameMode, "versus", false) != -1 || StrContains(gameMode, "scavenge", false) != -1 ) {
			SetFailState("Plugin does not support PvP modes");
		} else if( StrContains(gameMode, "survival", false) == -1 ) { // would otherwise cause spawns in survival before button is pressed
			g_bHasSpawnTimerStarted = false;
			StartSpawnTimer();
		}
		return Plugin_Continue;
	}
	
	DispatchSpawn(entity);
	HookSingleEntityOutput(entity, "OnCoop", OnGamemodeCoop, true);
	// HookSingleEntityOutput(entity, "OnSurvival", OnGamemodeCoop, true);
	HookSingleEntityOutput(entity, "OnVersus", OnGamemodeVersus, true);
	HookSingleEntityOutput(entity, "OnScavenge", OnGamemodeVersus, true);
	ActivateEntity(entity);
	AcceptEntityInput(entity, "PostSpawnActivate");
	if(IsValidEntity(entity))
		RemoveEntity(entity);
	
	return Plugin_Continue;
}

public void OnGamemodeCoop(const char[] output, int caller, int activator, float delay)
{
	g_bHasSpawnTimerStarted = false;
	StartSpawnTimer();
}

public void OnGamemodeVersus(const char[] output, int caller, int activator, float delay)
{
	ResetConVar( FindConVar("director_spectate_specials") );
	ResetConVar( FindConVar("director_no_specials") ); // Disable Director spawning specials naturally
	ResetConVar( FindConVar("z_safe_spawn_range") );
	ResetConVar( FindConVar("z_spawn_safety_range") );
	ResetConVar( FindConVar("z_spawn_range") );
	ResetConVar( FindConVar("z_discard_range") );
}

// 突变模式兼容
public Action L4D_OnGetScriptValueInt(const char[] key, int &retVal)
{
	if(StrEqual(key, "MaxSpecials", false) || StrEqual(key, "cm_MaxSpecials", false))
	{
		hSILimit.IntValue = retVal;
		hSILimitServerCap.IntValue = retVal * 2;
	}
	else if(StrEqual(key, "BoomerLimit", false))
		hSpawnLimits[SI_BOOMER].IntValue = retVal;
	else if(StrEqual(key, "SmokerLimit", false))
		hSpawnLimits[SI_SMOKER].IntValue = retVal;
	else if(StrEqual(key, "HunterLimit", false))
		hSpawnLimits[SI_HUNTER].IntValue = retVal;
	else if(StrEqual(key, "ChargerLimit", false))
		hSpawnLimits[SI_CHARGER].IntValue = retVal;
	else if(StrEqual(key, "SpitterLimit", false))
		hSpawnLimits[SI_SPITTER].IntValue = retVal;
	else if(StrEqual(key, "JockeyLimit", false))
		hSpawnLimits[SI_JOCKEY].IntValue = retVal;
	else if(StrEqual(key, "cm_SpecialRespawnInterval", false))
	{
		hSpawnTimeMin.IntValue = retVal;
		hSpawnTimeMax.IntValue = retVal + 5;
	}
	
	return Plugin_Continue;
}

public OnSurvivalRoundStart() {
	g_bHasSpawnTimerStarted = false;
	StartSpawnTimer();
}

public void OnClientDisconnect_Post(int client)
{
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(i == client || !IsClientConnected(i) || IsFakeClient(i))
			continue;
		
		return;
	}
	
	EndSpawnTimer();
}

public OnRoundOver() {
	EndSpawnTimer();
}

// Kick infected bots promptly after death to allow quicker infected respawn
public Action:OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast) {
	new player = GetClientOfUserId(GetEventInt(event, "userid"));
	if( IsBotInfected(player) ) {
		CreateTimer(1.0, Timer_KickBot, player);
	}
}

/***********************************************************************************************************************************************************************************

                                                 					LOS STARVATION
                                                                    
***********************************************************************************************************************************************************************************/

// Slay infected if they have not had LOS to survivors for a defined (hCvarLineOfSightStarvationTime/ss_los_starvation_time) period
public OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
	new userid = GetEventInt(event, "userid");
	new client = GetClientOfUserId(userid);
	if( IsBotInfected(client) && !IsTank(client) && userid >= 0 ) {
		g_fTimeLOS[userid] = 0.0;
		// Checking LOS
		CreateTimer( 0.5, Timer_StarvationLOS, userid, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );
	}
}

public Action:Timer_StarvationLOS( Handle:timer, any:userid ) {
	new client = GetClientOfUserId( userid );
	// increment tracked LOS time
	if( IsBotInfected(client) && IsPlayerAlive(client) ) {
	
		if( bool:GetEntProp(client, Prop_Send, "m_hasVisibleThreats") ) {
			g_fTimeLOS[userid] = 0.0;
		} else {
			g_fTimeLOS[userid] += 0.5; 
		}
		
		if( g_fTimeLOS[userid] > GetConVarFloat(hCvarLineOfSightStarvationTime) ) {
			switch ( GetConVarInt(FindConVar("ss_spawnpositioner_mode")) ) {
				case 1: {
					RepositionRadial(userid, GetLeadSurvivor());
				}
				case 2: {
					RepositionGrid(userid);
				}
				default: {
				}
			}
			return Plugin_Stop;
		}
	} else {
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

/***********************************************************************************************************************************************************************************

                                                           SPAWN TIMER AND CUSTOMISATION CMDS
                                                                    
***********************************************************************************************************************************************************************************/

public Action:Cmd_SetLimit(client, args) {
	if( !IsSurvivor(client) && !IsGenericAdmin(client) ) {
		PrintToChat(client, "You do not have access to this command");
		return Plugin_Handled;
	} 
	
	if (args == 2) {
		// Read in the SI class
		new String:sTargetClass[32];
		GetCmdArg(1, sTargetClass, sizeof(sTargetClass));
		// Read in limit value 
		new String:sLimitValue[32];     
		GetCmdArg(2, sLimitValue, sizeof(sLimitValue));
		new iLimitValue = StringToInt(sLimitValue);    
		// Must be valid limit value		
		if( iLimitValue < 0 ) {
			PrintToChat(client, "[SS] Limit value must be >= 0");
		} else {
			// Apply limit value to appropriate class
			if( StrEqual(sTargetClass, "all", false) ) {
				for( new i = 0; i < NUM_TYPES_INFECTED; i++ ) {
					SpawnLimitsCache[i] = iLimitValue;
				}
				Client_PrintToChatAll( true, "[SS] All SI limits have been set to {G}%d", iLimitValue );
			} else if( StrEqual(sTargetClass, "max", false) ) {  // Max specials
				SILimitCache = iLimitValue;
				Client_PrintToChatAll(true, "[SS] -> {O}Max {N}SI limit set to {G}%i", iLimitValue);		           
			} else if( StrEqual(sTargetClass, "group", false) || StrEqual(sTargetClass, "wave", false) ) {
				SpawnSizeCache = iLimitValue;
				Client_PrintToChatAll(true, "[SS] -> SI will spawn in {O}groups{N} of {G}%i", iLimitValue);
			} else {
				for( new i = 0; i < NUM_TYPES_INFECTED; i++ ) {
					if( StrEqual(Spawns[i], sTargetClass, false) ) {
						SpawnLimitsCache[i] = iLimitValue;
						Client_PrintToChatAll(true, "[SS] {O}%s {N}limit set to {G}%i", sTargetClass, iLimitValue);
					}
				}
			}
		}	 
	} else {  // Invalid command syntax
		Client_PrintToChat(client, true, "{O}!limit/sm_limit {B}<class> <limit>");
		Client_PrintToChat(client, true, "{B}<class> {N}[ all | max | group/wave | smoker | boomer | hunter | spitter | jockey | charger ]");
		Client_PrintToChat(client, true, "{B}<limit> {N}[ >= 0 ]");
	}
	// Load cache into appropriate cvars
	LoadCacheSpawnLimits(); 
	return Plugin_Handled;  
}

public Action:Cmd_SetWeight(client, args) {
	if( !IsSurvivor(client) && !IsGenericAdmin(client) ) {
		PrintToChat(client, "You do not have access to this command");
		return Plugin_Handled;
	} 
	
	if( args == 1 ) {
		decl String:arg[16];
		GetCmdArg(1, arg, sizeof(arg));	
		if( StrEqual(arg, "reset", false) ) {
			ResetWeights();
			ReplyToCommand(client, "[SS] Spawn weights reset to default values");
		} 
	} else if( args == 2 ) {
		// Read in the SI class
		new String:sTargetClass[32];
		GetCmdArg(1, sTargetClass, sizeof(sTargetClass));

		// Read in limit value 
		new String:sWeightPercent[32];     
		GetCmdArg(2, sWeightPercent, sizeof(sWeightPercent));
		new iWeightPercent = StringToInt(sWeightPercent);      
		if( iWeightPercent < 0 || iWeightPercent > 100 ) {
			PrintToChat( client, "0 <= weight value <= 100") ;
			return Plugin_Handled;
		} else { //presets for spawning special infected i only
			if( StrEqual(sTargetClass, "all", false) ) {
				for( new i = 0; i < NUM_TYPES_INFECTED; i++ ) {
					SpawnWeightsCache[i] = iWeightPercent;			
				}	
				Client_PrintToChat(client, true, "[SS] -> {O}All spawn weights {N}set to {G}%d", iWeightPercent );	
			} else {
				for( new i = 0; i < NUM_TYPES_INFECTED; i++ ) {
					if( StrEqual(sTargetClass, Spawns[i], false) ) {
						SpawnWeightsCache[i] =  iWeightPercent;
						Client_PrintToChat(client, true, "[SS] {O}%s {N}weight set to {G}%d", Spawns[i], iWeightPercent );				
					}
				}	
			}
			
		}
	} else {
		Client_PrintToChat( client, true, "{O}!weight/sm_weight {B}<class> <value>" );
		Client_PrintToChat( client, true, "{B}<class> {N}[ reset | all | smoker | boomer | hunter | spitter | jockey | charger ] " );	
		Client_PrintToChat( client, true, "{B}value {N}[ >= 0 ] " );	
	}
	LoadCacheSpawnWeights();
	return Plugin_Handled;
}

public Action:Cmd_SetTimer(client, args) {
	if( !IsSurvivor(client) && !IsGenericAdmin(client) ) {
		PrintToChat(client, "You do not have access to this command");
		return Plugin_Handled;
	} 
	
	if( args == 1 ) {
		new Float:time;
		decl String:arg[8];
		GetCmdArg(1, arg, sizeof(arg));
		time = StringToFloat(arg);
		if (time < 0.0) { 
			time = 1.0; // don't want a constant spawn time of 0s
		}
		SetConVarFloat( hSpawnTimeMin, time );
		SetConVarFloat( hSpawnTimeMax, time );
		SetSpawnTimes(); //refresh times since hooked event from SetConVarFloat is temporarily disabled
		Client_PrintToChat(client, true, "[SS] Spawn timer set to constant {G}%.3f {N}seconds", time);
	} else if( args == 2 ) {
		new Float:min, Float:max;
		decl String:arg[8];
		GetCmdArg( 1, arg, sizeof(arg) );
		min = StringToFloat(arg);
		GetCmdArg( 2, arg, sizeof(arg) );
		max = StringToFloat(arg);
		if( min > 0.0 && max > 1.0 && max > min ) {
			SetConVarFloat( hSpawnTimeMin, min );
			SetConVarFloat( hSpawnTimeMax, max );
			SetSpawnTimes(); //refresh times since hooked event from SetConVarFloat is temporarily disabled
			Client_PrintToChat(client, true, "[SS] Spawn timer will be between {G}%.3f {N}and {G}%.3f {N}seconds", min, max );
		} else {
			ReplyToCommand(client, "[SS] Max(>= 1.0) spawn time must greater than min(>= 0.0) spawn time");
		}
	} else {
		ReplyToCommand(client, "[SS] timer <constant> || timer <min> <max>");
	}
	return Plugin_Handled;
}

public Action:Cmd_SpawnMode( client, args ) {
	if( !IsSurvivor(client) && !IsGenericAdmin(client) ) {
		ReplyToCommand( client, "You do not have access to this command" );	
	}
	// Switch to appropriate mode
	new bool:isValidParams = false;
	if( args == 1 ) {
		new String:arg[8];
		GetCmdArg( 1, arg, sizeof(arg) );
		new mode = StringToInt(arg);
		if( mode >= 0 && mode <= 2 ) {
			SetConVarInt( hCvarSpawnPositionerMode, mode );
			new String:spawnModes[3][8] = { "Vanilla", "Radial", "Grid" };
			Client_PrintToChat( client, true, "[SS] {O}%s {N}spawn mode activated", spawnModes[mode] );
			isValidParams = true;
		}
	} 
	// Correct command usage
	if( !isValidParams ) {
		new String:spawnModes[3][8] = { "Vanilla", "Radial", "Grid" };
		Client_PrintToChat( client, true, "[SS] Current spawnmode: {O}%s", spawnModes[GetConVarInt(hCvarSpawnPositionerMode)] );
		ReplyToCommand( client, "Usage: spawnmode <mode> [ 0 = vanilla spawning, 1 = radial repositioning, 2 = grid repositioning ]" );
	}
}

public Action:Cmd_SpawnProximity(client, args) {	
	if( args == 2 ) {
		new Float:min, Float:max;
		decl String:arg[8];
		GetCmdArg( 1, arg, sizeof(arg) );
		min = StringToFloat(arg);
		GetCmdArg( 2, arg, sizeof(arg) );
		max = StringToFloat(arg);
		if( min > 0.0 && max > 1.0 && max > min ) {
			SetConVarFloat( hCvarSpawnProximityMin, min );
			SetConVarFloat( hCvarSpawnProximityMax, max );
			Client_PrintToChat(client, true, "[SS] Spawn proximity set between {G}%.3f {N}and {G}%.3f {N}units", min, max );
		} else {
			ReplyToCommand(client, "[SS] Max(>= 1.0) spawn proximity must greater than min(>= 0.0) spawn proximity");
		}
	} else {
		ReplyToCommand(client, "[SS] spawnproximity <min> <max>");
	}
	return Plugin_Handled;
}

/***********************************************************************************************************************************************************************************

                                                                         ADMIN COMMANDS
                                                                    
***********************************************************************************************************************************************************************************/

public Action:Cmd_ResetSpawns(client, args) {	
	for( new i = 0; i < MAXPLAYERS; i++ ) {
		if( IsBotInfected(i) ) {
			ForcePlayerSuicide(i);
		}
	}	
	StartCustomSpawnTimer(SpawnTimes[0]);
	ReplyToCommand( client, "[SS] Slayed all special infected. Spawn timer restarted. Next potential spawn in %.3f seconds.", GetConVarFloat(hSpawnTimeMin) );
	return Plugin_Handled;
}

public Action:Cmd_StartSpawnTimerManually(client, args) {
	if( args < 1 ) {
		StartSpawnTimer();
		ReplyToCommand(client, "[SS] Spawn timer started manually.");
	} else {
		new Float:time = 1.0;
		decl String:arg[8];
		GetCmdArg(1, arg, sizeof(arg));
		time = StringToFloat(arg);
		
		if (time < 0.0) {
			time = 1.0;
		}
		
		StartCustomSpawnTimer(time);
		ReplyToCommand(client, "[SS] Spawn timer started manually. Next potential spawn in %.3f seconds.", time);
	}
	return Plugin_Handled;
}

/***********************************************************************************************************************************************************************************

                                                                         SPAWNER HUD
                                                                    
***********************************************************************************************************************************************************************************/

public Action:OnPlayerRunCmd( client, &buttons ) {
	if( !IsFakeClient(client) && buttons & IN_USE && buttons & IN_RELOAD ) {
		bShowSpawnerHUD[client] = true;
	} else {
		bShowSpawnerHUD[client] = false;
	}
}

public Action:Timer_DrawSpawnerHUD( Handle:timer ) {
	new Handle:spawnerHUD = CreatePanel();
	FillHeaderInfo(spawnerHUD);
	FillSpecialInfectedInfo(spawnerHUD);
	FillTimerInfo(spawnerHUD);
	// Send to survivors
	for( new i = 1; i < MAXPLAYERS; i++ ) {
		if( IsValidClient(i) && !IsFakeClient(i) && bShowSpawnerHUD[i] ) {
			SendPanelToClient( spawnerHUD, i, DummySpawnerHUDHandler, 3 ); 
		}
	}
	CloseHandle(spawnerHUD);
	return Plugin_Continue;
}

FillHeaderInfo(Handle:spawnerHUD) {
	SetPanelTitle(spawnerHUD, "--------- SPAWNER HUD ---------");
	DrawPanelText(spawnerHUD, " \n");
}

FillSpecialInfectedInfo(Handle:spawnerHUD) {
	// Potential SI
	new String:SILimit[32];
	Format( SILimit, sizeof(SILimit), "SI max -> %d / %d (Cap: %d)", CountSpecialInfectedBots(), GetConVarInt(hSILimit), GetConVarInt(hSILimitServerCap) );
	DrawPanelText(spawnerHUD, SILimit);
	// Simultaneous spawn limit
	new String:simultaneousSpawnLimit[32];
	Format( simultaneousSpawnLimit, sizeof(simultaneousSpawnLimit), "Group spawn size -> %d", GetConVarInt(hSpawnSize) );
	DrawPanelText(spawnerHUD, simultaneousSpawnLimit);
	DrawPanelText(spawnerHUD, " \n");
	// Individual class weights and limits
	new String:classCustomisationInfo[NUM_TYPES_INFECTED][64];
	for( new i = 0; i < NUM_TYPES_INFECTED; i++ ) {
		Format( 
			classCustomisationInfo[i],
			128, 
			"%s | weight: %d | limit: %d/%d ",
			Spawns[i], GetConVarInt(hSpawnWeights[i]), CountSIClass(i + 1), GetConVarInt(hSpawnLimits[i])
		);
		DrawPanelText(spawnerHUD, classCustomisationInfo[i]);
	}
	DrawPanelText(spawnerHUD, " \n");
}

FillTimerInfo(Handle:spawnerHUD) {
	// Section heading
	DrawPanelText(spawnerHUD, "Timer:");
	// Min spawn time
	new String:timerMin[32];
	Format( timerMin, sizeof(timerMin), "Min: %f", GetConVarFloat(hSpawnTimeMin) );
	DrawPanelText(spawnerHUD, timerMin);
	// Max spawn time
	new String:timerMax[32];
	Format( timerMax, sizeof(timerMax), "Max: %f", GetConVarFloat(hSpawnTimeMax) );
	DrawPanelText(spawnerHUD, timerMax);
}

public DummySpawnerHUDHandler(Handle:hMenu, MenuAction:action, param1, param2) {}

CountSIClass( targetClass ) {
	new iClassSpawnVolume;
	for( new i = 0; i < MaxClients; i++ ) {
		if( IsBotInfected(i) && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") == targetClass ) {
			iClassSpawnVolume++;
		}
	}	
	return iClassSpawnVolume;
}
