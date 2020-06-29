// =============================================================================
// L4D2 coop save weapon
// =============================================================================
//
// Saved: equipment, ammo, health, revivecount, b&w status, prop & model
// Going idle / quitting the game will transfer saved data to the replacement bot
// Taking over a bot will transfer the saved data to the player
//

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#pragma newdecls required
#define PLUGIN_VERSION		"4.3"

enum()
{
	iClip = 0,
	iClipSlot1,
	iAmmo,
	iUpgrade,
	iUpAmmo,
	iHealth,
	iHealthTemp,
	iHealthTime,
	iReviveCount,
	iGoingToDie,
	iThirdStrike,
	iProp,
	iRecorded,
	iSpawned,
	iMaxHealth,
};

enum()
{
	Slot0 = 0,
	Slot1,
	Slot2,
	Slot3,
	Slot4,
	Model,
};

char	gameMode[16];
bool    g_bGiveWeapon;
bool    g_bCanAppropriate = true;

int 	g_iWeaponInfo[MAXPLAYERS+1][15];
char 	g_sWeaponInfo[MAXPLAYERS+1][6][64];
bool    g_bValidMapChange = false;

ConVar 	g_hNoob, g_hClearAfterCampaign, g_hFullHealth;

// *********************************************************************************
// METHODS FOR GAME START & END
// *********************************************************************************
public Plugin myinfo =
{
	name = "过关保存角色",
	author = "MAKS, Electr0, Merudo",
	description = "L4D2 coop save weapon",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?p=2398822#post2398822"
}

public void OnPluginStart()
{	
	CreateConVar("l4d2_ty_saveweapon", PLUGIN_VERSION, "L4D2 Save Weapon version",  FCVAR_NOTIFY);

	HookEvent("round_start",				Event_RoundStart,	EventHookMode_PostNoCopy);
	HookEvent("finale_win", 				Event_FinaleWin);
	HookEvent("map_transition", 			Event_MapTransition);	
	
	HookEvent("player_spawn",   			Event_PlayerSpawn);
	HookEvent("player_bot_replace", 		Event_Player_Bot_Replace);
	HookEvent("bot_player_replace", 		Event_Bot_Player_Replace);
	
	g_hNoob 								= CreateConVar("l4d2_ty_noob",							"0", "开局给冲锋枪", FCVAR_NOTIFY);
	g_hClearAfterCampaign 					= CreateConVar("l4d2_ty_clear_after_campaign", 			"1", "开局缓存武器模型", FCVAR_NOTIFY);
	g_hFullHealth							= CreateConVar("l4d2_ty_healing",						"0", "开局回血", FCVAR_NOTIFY);

	RegAdminCmd("sm_save_weap", 			CMD_SaveWeap, 		ADMFLAG_CHEATS, "Save equipment");
	RegAdminCmd("sm_save_weap_all", 		CMD_SaveWeapAll, 	ADMFLAG_CHEATS, "Save equipment of all survivors");
	RegAdminCmd("sm_load_weap", 			CMD_LoadWeap, 		ADMFLAG_CHEATS, "Load equipment");
	RegAdminCmd("sm_load_weap_all", 		CMD_LoadWeapAll, 	ADMFLAG_CHEATS, "Load equipment of all survivors");
	
	AutoExecConfig(true, "l4d2_ty_saveweapon");
}

// --------------------------------------
// Modes where weapons should be saved between maps
// --------------------------------------
char saveweapon_modes[20][] =
{
	"coop", "realism",
	"m60s", "hardcore", "l4d1coop",
	"mutation2",	"mutation3",	"mutation4",
	"mutation5",	"mutation6",	"mutation7",	"mutation8",
	"mutation9",	"mutation10",	"mutation16",	"mutation17", "mutation20",
	"community1",	"community2",	"community5"
};


public void OnMapStart()
{
	// Identify if weapons should be saved
	//////////////////////////////////////
	GetConVarString(FindConVar("mp_gamemode"), gameMode, sizeof(gameMode));
	
	g_bGiveWeapon = false;
	for (int i = 0; i < sizeof(saveweapon_modes); i++)
	{
		if (StrEqual(gameMode, saveweapon_modes[i], false))
		{
			g_bGiveWeapon = true;
		}
	}

	// Clean up weapon data if new campaign / versus mode
	//////////////////////////////////////	
	if ( (!g_bValidMapChange && g_hClearAfterCampaign.BoolValue) || !g_bGiveWeapon) TyCleanAll();
	
	g_bValidMapChange = false;  // Map changes between map start and transition are considered invalid
	
	if (!g_hClearAfterCampaign.BoolValue && g_bGiveWeapon) TyPrecache();  // Precache if we allow carrying weapons across campaigns
}

// --------------------------------------
// Reset weapon spawn status (it is 1 if spawned in the round previously)
// --------------------------------------
public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for( int i = 1; i <= MaxClients; i++) g_iWeaponInfo[i][iSpawned] = 0;
	g_bCanAppropriate = true;
}

// --------------------------------------
// Save weapon when transition after safe house
// --------------------------------------
public Action Event_MapTransition(Event event, const char[] name, bool dontBroadcast)
{
	TyCleanAll();
	TySaveWeaponAll();
	g_bValidMapChange = true;  // only map changes between transition and new map are valid
}

// --------------------------------------
// Save weapons at end of campaign (may be overwritten by OnMapStart() )
// --------------------------------------
public Action Event_FinaleWin(Event event, const char[] name, bool dontBroadcast)
{	
	TyCleanAll();
	TySaveWeaponAll();
}

// --------------------------------------
// Load weapons on spawn
// --------------------------------------
public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int userid = GetEventInt(event, "userid");
	CreateTimer(0.2, timer_Give, userid, TIMER_FLAG_NO_MAPCHANGE); 
	
	return Plugin_Continue;
}

// --------------------------------------
// Load weapons. Delayed to not deal with bogus fake clients
// --------------------------------------
public Action timer_Give(Handle handle, int userid)
{
	int client = GetClientOfUserId(userid);

	// if since then disconnected, don't do anything
	if (!client || !IsClientInGame(client) || GetClientTeam(client) != 2 || !g_bGiveWeapon) return;
	
	if (g_bCanAppropriate) CreateTimer(10.0, timer_StopAppropriate, TIMER_FLAG_NO_MAPCHANGE);

	// If not recorded, search if there is a missing record not yet spawned. For bots only
	if (g_iWeaponInfo[client][iRecorded] != 1 && g_iWeaponInfo[client][iSpawned] == 0 && IsFakeClient(client) && g_bCanAppropriate)
	{
		AppropriateUnusedSave(client);
	}
	
	// If not yet spawned in the round
	if (g_iWeaponInfo[client][iSpawned] == 0)
	{
		if (g_iWeaponInfo[client][iRecorded] == 1) TyGiveWeapon(client);
		else if (g_hNoob.BoolValue && g_bCanAppropriate) // If start of round, no weapons saved & g_bNoob enabled
		{
			int iSlot = GetPlayerWeaponSlot(client, 0);
			if (iSlot <= 0) CheatCommand(client, "give", "weapon_smg","");
		}		
		g_iWeaponInfo[client][iSpawned] = 1;
	}
}

// --------------------------------------
// Turns off appropriation after 10 sec, to prevent idle bots from getting different stuff
// --------------------------------------
public Action timer_StopAppropriate(Handle handle, int client) {g_bCanAppropriate = false;}

// --------------------------------------
// Bot -> Player
// --------------------------------------
public Action Event_Bot_Player_Replace(Handle event, char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(GetEventInt(event, "player"));
	int bot    = GetClientOfUserId(GetEventInt(event, "bot")); 
	
	if (IsFakeClient(player)) return;  // do nothing if bot replace other bot (byproduct of creating survivor bots)
	
	if (GetClientTeam(player) == 2)
	{
		CopyWeaponFromTo(bot, player);
		TyCleanW(bot);
	}
}

// --------------------------------------
// Player -> Bot
// --------------------------------------
public Action Event_Player_Bot_Replace(Handle event, char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(GetEventInt(event, "player"));
	int bot    = GetClientOfUserId(GetEventInt(event, "bot")); 

	if (IsFakeClient(player)) return;  // do nothing if bot replace other bot (byproduct of creating survivor bots)
	
	if (GetClientTeam(bot) == 2)
	{
		CopyWeaponFromTo(player, bot);
		TyCleanW(player);
	}
}

// --------------------------------------
// Find abandoned saved data (from player leaving between levels, bots autokicked at end of map, etc) and appropriate it
// --------------------------------------
void AppropriateUnusedSave(int client)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientConnected(i) && g_iWeaponInfo[i][iRecorded] == 1 && client != i)
		{
			CopyWeaponFromTo(i, client);
			TyCleanW(i);
			return;
		}
	}
}

void CopyWeaponFromTo(int Fclient, int Tclient)
{
	for (int i = 0; i < sizeof(g_iWeaponInfo[]) ; i++)
	{
		g_iWeaponInfo[Tclient][i] = g_iWeaponInfo[Fclient][i];
	}
	for (int i = 0; i < sizeof(g_sWeaponInfo[]) ; i++)
	{
		 strcopy(g_sWeaponInfo[Tclient][i], sizeof(g_sWeaponInfo[][]), g_sWeaponInfo[Fclient][i]);
	}
}

// *********************************************************************************
// Save & Load Weapons functions
// *********************************************************************************

void TySaveWeaponAll()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2)	TySaveWeapon(i);
	}
}

void TyGiveWeaponAll()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2) TyGiveWeapon(i);
	}
}

void TySaveWeapon(int client)
{
	TyCleanW(client);
	
	if (GetClientTeam(client) != 2) return;

	// Store model
	GetClientModel(client, g_sWeaponInfo[client][Model], 64);
	
	// Store prop
	g_iWeaponInfo[client][iProp] = GetEntProp(client, Prop_Send, "m_survivorCharacter");	
	
	g_iWeaponInfo[client][iRecorded] = 1; 
		
	// if dead, set ressurected state
	if (!IsPlayerAlive(client))
	{
		g_iWeaponInfo[client][iHealth] = 50;
		g_iWeaponInfo[client][iMaxHealth] = 100;
		return;
	}
	
	// Save health
	g_iWeaponInfo[client][iReviveCount] =  GetEntProp(client, Prop_Send, "m_currentReviveCount");
	g_iWeaponInfo[client][iThirdStrike] =  GetEntProp(client, Prop_Send, "m_bIsOnThirdStrike");

	if (GetEntProp(client, Prop_Send, "m_isIncapacitated") == 1) 
	{
		g_iWeaponInfo[client][iHealth]       =  1;	
		g_iWeaponInfo[client][iHealthTemp]   = 30;
		g_iWeaponInfo[client][iHealthTime]   =  0;
		g_iWeaponInfo[client][iGoingToDie]   =  1;
		g_iWeaponInfo[client][iMaxHealth] = 100;
	}
	else 
	{
		g_iWeaponInfo[client][iHealth]		= GetEntData(client, FindDataMapInfo(client, "m_iHealth"), 4);
		g_iWeaponInfo[client][iHealthTemp]	= RoundToNearest( GetEntPropFloat(client, Prop_Send, "m_healthBuffer") );
		g_iWeaponInfo[client][iHealthTime]  = RoundToNearest( GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime") );
		g_iWeaponInfo[client][iGoingToDie]  = GetEntProp(client, Prop_Send, "m_isGoingToDie");
		g_iWeaponInfo[client][iMaxHealth] = GetEntProp(client, Prop_Send, "m_iMaxHealth");
	}

	// Save equipment
	int iSlot0 = GetPlayerWeaponSlot(client, 0);
	int iSlot1 = GetPlayerWeaponSlot(client, 1);
	int iSlot2 = GetPlayerWeaponSlot(client, 2);
	int iSlot3 = GetPlayerWeaponSlot(client, 3);
	int iSlot4 = GetPlayerWeaponSlot(client, 4);

	if (iSlot0 > 0)
	{
		GetEdictClassname(iSlot0, g_sWeaponInfo[client][Slot0], 64);
		
		g_iWeaponInfo[client][iClip] = GetEntProp(iSlot0, Prop_Send, "m_iClip1", 4);
		g_iWeaponInfo[client][iAmmo] = GetClientAmmo(client, g_sWeaponInfo[client][Slot0]);
		g_iWeaponInfo[client][iUpgrade] = GetEntProp(iSlot0, Prop_Send, "m_upgradeBitVec", 4);
		g_iWeaponInfo[client][iUpAmmo]  = GetEntProp(iSlot0, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", 4);
	}
	if (iSlot1 > 0) TySaveSlot1(client, iSlot1);
	if (iSlot2 > 0) GetEdictClassname(iSlot2, g_sWeaponInfo[client][2], 64);
	if (iSlot3 > 0) GetEdictClassname(iSlot3, g_sWeaponInfo[client][3], 64);
	if (iSlot4 > 0) GetEdictClassname(iSlot4, g_sWeaponInfo[client][4], 64);
}

// --------------------------------------
// Special code to save slot 1 (because of melee weapons)
// --------------------------------------
void TySaveSlot1(int client, int iSlot1)
{
	char className[64];
	char modelName[64];
	
	GetEdictClassname(iSlot1, className, sizeof(className));
	
	if 		(!strcmp(className, "weapon_melee", true)) // if melee
	{
		GetEntPropString(iSlot1, Prop_Data, "m_strMapSetScriptName", g_sWeaponInfo[client][Slot1], 64);
	} 
	else if (!strcmp(className, "weapon_pistol", true)) // if pistol
	{
		if (GetEntProp(iSlot1, Prop_Send, "m_hasDualWeapons" ) == 1) g_sWeaponInfo[client][Slot1] = "dual_pistol";
		else g_sWeaponInfo[client][Slot1] = "weapon_pistol";
	}
	else // if non-melee, non-pistol
	{
		g_sWeaponInfo[client][Slot1] = className;
	}
	
	// IF model checking is required
	if (g_sWeaponInfo[client][Slot1][0] == '\0')
	{
		GetEntPropString(iSlot1, Prop_Data, "m_ModelName", modelName, sizeof(modelName));

		if 		(StrContains(modelName, "v_pistolA.mdl",         true) != -1)	g_sWeaponInfo[client][Slot1] = "weapon_pistol";
		else if (StrContains(modelName, "v_dual_pistolA.mdl",    true) != -1)	g_sWeaponInfo[client][Slot1] = "dual_pistol";
		else if (StrContains(modelName, "v_desert_eagle.mdl",    true) != -1)	g_sWeaponInfo[client][Slot1] = "weapon_pistol_magnum";
		else if (StrContains(modelName, "v_bat.mdl",             true) != -1)	g_sWeaponInfo[client][Slot1] = "baseball_bat";
		else if (StrContains(modelName, "v_cricket_bat.mdl",     true) != -1)	g_sWeaponInfo[client][Slot1] = "cricket_bat";
		else if (StrContains(modelName, "v_crowbar.mdl",         true) != -1)	g_sWeaponInfo[client][Slot1] = "crowbar";
		else if (StrContains(modelName, "v_fireaxe.mdl",         true) != -1)	g_sWeaponInfo[client][Slot1] = "fireaxe";
		else if (StrContains(modelName, "v_katana.mdl",          true) != -1)	g_sWeaponInfo[client][Slot1] = "katana";
		else if (StrContains(modelName, "v_golfclub.mdl",        true) != -1)	g_sWeaponInfo[client][Slot1] = "golfclub";
		else if (StrContains(modelName, "v_machete.mdl",         true) != -1)	g_sWeaponInfo[client][Slot1] = "machete";
		else if (StrContains(modelName, "v_tonfa.mdl",           true) != -1)	g_sWeaponInfo[client][Slot1] = "tonfa";
		else if (StrContains(modelName, "v_electric_guitar.mdl", true) != -1)	g_sWeaponInfo[client][Slot1] = "electric_guitar";
		else if (StrContains(modelName, "v_frying_pan.mdl",      true) != -1)	g_sWeaponInfo[client][Slot1] = "frying_pan";
		else if (StrContains(modelName, "v_knife_t.mdl",         true) != -1)	g_sWeaponInfo[client][Slot1] = "knife";
		else if (StrContains(modelName, "v_chainsaw.mdl",        true) != -1)	g_sWeaponInfo[client][Slot1] = "weapon_chainsaw";
		else if (StrContains(modelName, "v_riotshield.mdl",      true) != -1)	g_sWeaponInfo[client][Slot1] = "riotshield";
		else if (StrContains(modelName, "v_foamfinger.mdl",      true) != -1)	g_sWeaponInfo[client][Slot1] = "b_foamfinger";			
		else if (StrContains(modelName, "v_fubar.mdl",           true) != -1)	g_sWeaponInfo[client][Slot1] = "fubar";		
		else if (StrContains(modelName, "v_paintrain.mdl",       true) != -1)	g_sWeaponInfo[client][Slot1] = "nail_board";
		else if (StrContains(modelName, "v_sledgehammer.mdl",    true) != -1)	g_sWeaponInfo[client][Slot1] = "sledgehammer";
	}
	
	if (!strcmp(g_sWeaponInfo[client][Slot1], "dual_pistol", true)   || !strcmp(g_sWeaponInfo[client][Slot1], "weapon_pistol", true)
	 || !strcmp(g_sWeaponInfo[client][Slot1], "weapon_pistol_magnum", true) || !strcmp(g_sWeaponInfo[client][Slot1], "weapon_chainsaw", true))
	{
		g_iWeaponInfo[client][iClipSlot1] = GetEntProp(iSlot1, Prop_Send, "m_iClip1", 4);
	}
}

char survivor_names[8][] = { "Nick", "Rochelle", "Coach", "Ellis", "Bill", "Zoey", "Francis", "Louis"};
char survivor_models[8][] =
{
	"models/survivors/survivor_gambler.mdl",
	"models/survivors/survivor_producer.mdl",
	"models/survivors/survivor_coach.mdl",
	"models/survivors/survivor_mechanic.mdl",
	"models/survivors/survivor_namvet.mdl",
	"models/survivors/survivor_teenangst.mdl",
	"models/survivors/survivor_biker.mdl",
	"models/survivors/survivor_manager.mdl"
};

void TyGiveWeapon(int client)
{
	if (!IsClientInGame(client) || g_iWeaponInfo[client][iRecorded] == 0) return;
	
	g_iWeaponInfo[client][iSpawned] = 1;
	
	// Update model & props
	SetEntProp(client, Prop_Send, "m_survivorCharacter", g_iWeaponInfo[client][iProp]);  
	SetEntityModel(client, g_sWeaponInfo[client][Model]);

	if (IsFakeClient(client))		// if bot, replace name
	{
		for (int i = 0; i < 8; i++)
		{
			if (StrEqual(g_sWeaponInfo[client][Model], survivor_models[i])) SetClientInfo(client, "name", survivor_names[i]);
		}
	}
	
	if (!IsPlayerAlive(client)) return;

	// Restore health
	if (GetEntProp(client, Prop_Send, "m_isIncapacitated") == 1) SetEntProp(client, Prop_Send, "m_isIncapacitated", 0);	
	SetEntProp(client, Prop_Send, "m_iMaxHealth", g_iWeaponInfo[client][iMaxHealth]);

	if(g_hFullHealth.BoolValue && g_bCanAppropriate)
	{
		SetEntProp(client, Prop_Send, "m_currentReviveCount", 0);
		SetEntProp(client, Prop_Send, "m_isGoingToDie", 0);
		SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 0);
		
		SetEntProp(client, Prop_Send, "m_iHealth", g_iWeaponInfo[client][iMaxHealth], 2);
		SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
		SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
	}
	else
	{
		SetEntProp(client, Prop_Send, "m_currentReviveCount", g_iWeaponInfo[client][iReviveCount]);
		SetEntProp(client, Prop_Send, "m_isGoingToDie", g_iWeaponInfo[client][iGoingToDie]);
		SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", g_iWeaponInfo[client][iThirdStrike]);
		
		SetEntProp(client, Prop_Send, "m_iHealth", g_iWeaponInfo[client][iHealth], 2);
		SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 1.0*g_iWeaponInfo[client][iHealthTemp]);
		SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime() - 1.0*g_iWeaponInfo[client][iHealthTime]);
	}
	
	// Disable heart beat sound if not B&W
	if (!g_iWeaponInfo[client][iThirdStrike]) for (int i = 0; i <= 255; i++) StopSound(client, i, "player/heartbeatloop.wav");
	
	// Remove previous equipment
	DeletePlayerSlotAll(client);
	
	// Give saved equipment
	if (g_sWeaponInfo[client][2][0] != '\0') CheatCommand(client, "give", g_sWeaponInfo[client][2],"");
	if (g_sWeaponInfo[client][3][0] != '\0') CheatCommand(client, "give", g_sWeaponInfo[client][3],"");
	if (g_sWeaponInfo[client][4][0] != '\0') CheatCommand(client, "give", g_sWeaponInfo[client][4],"");
	
	int iSlot;
	
	if (g_sWeaponInfo[client][1][0] != '\0')
	{
		if (!strcmp(g_sWeaponInfo[client][1], "dual_pistol", true))
		{
			CheatCommand(client, "give", "weapon_pistol","");
			CheatCommand(client, "give", "weapon_pistol","");
		}
		else
		{
			CheatCommand(client, "give", g_sWeaponInfo[client][1],"");
		}
			
		// Restore chainsaw fuel
		if (!strcmp(g_sWeaponInfo[client][1], "weapon_chainsaw", true))
		{
			iSlot = GetPlayerWeaponSlot(client, 1);
			if (iSlot > 0)
			{
				SetEntProp(iSlot, Prop_Send, "m_iClip1", g_iWeaponInfo[client][iClipSlot1], 4);
			}
		}
	}
	else
	{
		CheatCommand(client, "give", "weapon_pistol","");
	}
	
	// Give primary weapon last so its the one yielded
	if (g_sWeaponInfo[client][0][0] != '\0')
	{
		CheatCommand(client, "give", g_sWeaponInfo[client][0],"");
		iSlot = GetPlayerWeaponSlot(client, 0);
		if (iSlot > 0)
		{	
			SetEntProp(iSlot, Prop_Send, "m_iClip1", g_iWeaponInfo[client][iClip], 4);
			SetClientAmmo(client, g_sWeaponInfo[client][0], g_iWeaponInfo[client][iAmmo]);
			SetEntProp(iSlot, Prop_Send, "m_upgradeBitVec", g_iWeaponInfo[client][iUpgrade], 4);
			SetEntProp(iSlot, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", g_iWeaponInfo[client][iUpAmmo], 4);
		}
	}
	else if (g_hNoob.BoolValue) CheatCommand(client, "give", "weapon_smg","");
}

void TyCleanW(int client)
{
	g_iWeaponInfo[client][iClip] 		=   0;
	g_iWeaponInfo[client][iClipSlot1] 	=   0;
	g_iWeaponInfo[client][iAmmo] 		=   0;
	g_iWeaponInfo[client][iUpgrade] 	=   0;
	g_iWeaponInfo[client][iUpAmmo] 		=   0;
	g_iWeaponInfo[client][iProp] 		=  -1;
	
	g_iWeaponInfo[client][iHealth] 		= 100;	
	g_iWeaponInfo[client][iReviveCount] =   0;
	g_iWeaponInfo[client][iGoingToDie]  =   0;
	g_iWeaponInfo[client][iHealthTemp]  =   0;
	g_iWeaponInfo[client][iHealthTime]  =   0;
	g_iWeaponInfo[client][iThirdStrike] =   0;
	
	g_iWeaponInfo[client][iRecorded]	=   0;
	g_iWeaponInfo[client][iSpawned] 	=   0;
	
	g_sWeaponInfo[client][Slot0][0] = '\0';
	g_sWeaponInfo[client][Slot1][0] = '\0';
	g_sWeaponInfo[client][Slot2][0] = '\0';
	g_sWeaponInfo[client][Slot3][0] = '\0';
	g_sWeaponInfo[client][Slot4][0] = '\0';
	g_sWeaponInfo[client][Model][0] = '\0';	
}

void TyCleanAll()
{
	for (int i = 1; i <= MaxClients; i++) TyCleanW(i);
}

// *********************************************************************************
// Commands
// *********************************************************************************

public Action CMD_SaveWeap(int client, int args)
{
	if (client && GetClientTeam(client) == 2) TySaveWeapon(client);
	return Plugin_Continue;
}

public Action CMD_SaveWeapAll(int client, int args)
{
	TySaveWeaponAll();
	PrintToChat(client, "Weapons Saved");
	return Plugin_Continue;
}

public Action CMD_LoadWeap(int client, int args)
{
	if (client && GetClientTeam(client) == 2) TyGiveWeapon(client);
	return Plugin_Continue;
}

public Action CMD_LoadWeapAll(int client, int args)
{
	TyGiveWeaponAll();
	PrintToChat(client, "Weapons Loaded");
	return Plugin_Continue;
}
// *********************************************************************************
// Get/Set ammo
// *********************************************************************************

int GetWeaponOffset(char[] weapon)
{
	int weapon_offset;

	if (StrEqual(weapon, "weapon_rifle") || StrEqual(weapon, "weapon_rifle_sg552") || StrEqual(weapon, "weapon_rifle_desert") || StrEqual(weapon, "weapon_rifle_ak47"))
	{
		weapon_offset = 12;
	}
	else if (StrEqual(weapon, "weapon_rifle_m60"))
	{
		weapon_offset = 24;
	}
	else if (StrEqual(weapon, "weapon_smg") || StrEqual(weapon, "weapon_smg_silenced") || StrEqual(weapon, "weapon_smg_mp5"))
	{
		weapon_offset = 20;
	}
	else if (StrEqual(weapon, "weapon_pumpshotgun") || StrEqual(weapon, "weapon_shotgun_chrome"))
	{
		weapon_offset = 28;
	}
	else if (StrEqual(weapon, "weapon_autoshotgun") || StrEqual(weapon, "weapon_shotgun_spas"))
	{
		weapon_offset = 32;
	}
	else if (StrEqual(weapon, "weapon_hunting_rifle"))
	{
		weapon_offset = 36;
	}
	else if (StrEqual(weapon, "weapon_sniper_scout") || StrEqual(weapon, "weapon_sniper_military") || StrEqual(weapon, "weapon_sniper_awp"))
	{
		weapon_offset = 40;
	}
	else if (StrEqual(weapon, "weapon_grenade_launcher"))
	{
		weapon_offset = 68;
	}

	return weapon_offset;
}

int GetClientAmmo(int client, char[] weapon)
{
	int weapon_offset = GetWeaponOffset(weapon);
	int iAmmoOffset = FindSendPropInfo("CTerrorPlayer", "m_iAmmo");
	
	return weapon_offset > 0 ? GetEntData(client, iAmmoOffset+weapon_offset) : 0;
}

void SetClientAmmo(int client, char[] weapon, int count)
{
	int weapon_offset = GetWeaponOffset(weapon);
	int iAmmoOffset = FindSendPropInfo("CTerrorPlayer", "m_iAmmo");
	
	if (weapon_offset > 0) SetEntData(client, iAmmoOffset+weapon_offset, count);
}

// *********************************************************************************
// Commands to create / delete weapons
// *********************************************************************************

void CheatCommand(int client, const char[] command, const char[] argument1, const char[] argument2)
{
	int userFlags = GetUserFlagBits(client);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	int flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s %s", command, argument1, argument2);
	SetCommandFlags(command, flags);
	SetUserFlagBits(client, userFlags);
}

void DeletePlayerSlot(int client, int weapon)
{		
	if(RemovePlayerItem(client, weapon)) AcceptEntityInput(weapon, "Kill");
}

void DeletePlayerSlotAll(int client)
{
	int iSlot;
	for (int i; i < 5; i++)
	{
		iSlot = GetPlayerWeaponSlot(client, i);
		if (iSlot > 0)	DeletePlayerSlot(client, iSlot);
	}
}

// *********************************************************************************
// Precache
// *********************************************************************************
public void TyPrecache()
{
	// Survivors
	if (!IsModelPrecached("models/survivors/survivor_biker.mdl"))		PrecacheModel("models/survivors/survivor_biker.mdl", true);
	if (!IsModelPrecached("models/survivors/survivor_manager.mdl"))		PrecacheModel("models/survivors/survivor_manager.mdl", true);
	if (!IsModelPrecached("models/survivors/survivor_teenangst.mdl"))	PrecacheModel("models/survivors/survivor_teenangst.mdl", true);
	if (!IsModelPrecached("models/survivors/survivor_coach.mdl"))		PrecacheModel("models/survivors/survivor_coach.mdl", true);
	if (!IsModelPrecached("models/survivors/survivor_gambler.mdl"))		PrecacheModel("models/survivors/survivor_gambler.mdl", true);
	if (!IsModelPrecached("models/survivors/survivor_mechanic.mdl"))	PrecacheModel("models/survivors/survivor_mechanic.mdl", true);
	if (!IsModelPrecached("models/survivors/survivor_producer.mdl"))	PrecacheModel("models/survivors/survivor_producer.mdl", true);


	// CS weapons
	if (!IsModelPrecached("models/v_models/v_rif_sg552.mdl"))			PrecacheModel("models/v_models/v_rif_sg552.mdl", true);
	if (!IsModelPrecached("models/w_models/weapons/w_rifle_sg552.mdl"))	PrecacheModel("models/w_models/weapons/w_rifle_sg552.mdl", true);	
	if (!IsModelPrecached("models/v_models/v_smg_mp5.mdl"))				PrecacheModel("models/v_models/v_smg_mp5.mdl", true);
	if (!IsModelPrecached("models/w_models/weapons/w_smg_mp5.mdl"))		PrecacheModel("models/w_models/weapons/w_smg_mp5.mdl", true);		
	if (!IsModelPrecached("models/v_models/v_snip_awp.mdl"))			PrecacheModel("models/v_models/v_snip_awp.mdl", true);
	if (!IsModelPrecached("models/w_models/weapons/w_sniper_awp.mdl"))	PrecacheModel("models/w_models/weapons/w_sniper_awp.mdl", true);	
	if (!IsModelPrecached("models/v_models/v_snip_scout.mdl"))			PrecacheModel("models/v_models/v_snip_scout.mdl", true);
	if (!IsModelPrecached("models/w_models/weapons/w_sniper_scout.mdl"))PrecacheModel("models/w_models/weapons/w_sniper_scout.mdl");	
	if (!IsModelPrecached("models/v_models/v_knife_t.mdl")) 			PrecacheModel("models/v_models/v_knife_t.mdl", true);
	if (!IsModelPrecached("models/w_models/weapons/w_knife_t.mdl"))		PrecacheModel("models/w_models/weapons/w_knife_t.mdl", true);
	if (!IsModelPrecached("models/v_models/v_snip_scout.mdl"))			PrecacheModel("models/v_models/v_snip_scout.mdl", true);
	if (!IsModelPrecached("models/w_models/weapons/w_sniper_scout.mdl"))PrecacheModel("models/w_models/weapons/w_sniper_scout.mdl", true);
	
	// M60
	if (!IsModelPrecached("models/v_models/v_m60.mdl")) 				PrecacheModel("models/v_models/v_m60.mdl", true);
	if (!IsModelPrecached("models/w_models/weapons/w_m60.mdl")) 		PrecacheModel("models/w_models/weapons/w_m60.mdl", true);

	// Melee weapons	
	if (!IsModelPrecached("models/weapons/melee/v_bat.mdl"))			PrecacheModel("models/weapons/melee/v_bat.mdl", true);
	if (!IsModelPrecached("models/weapons/melee/w_bat.mdl"))			PrecacheModel("models/weapons/melee/w_bat.mdl", true);	
	if (!IsModelPrecached("models/weapons/melee/v_cricket_bat.mdl"))	PrecacheModel("models/weapons/melee/v_cricket_bat.mdl", true);
	if (!IsModelPrecached("models/weapons/melee/w_cricket_bat.mdl"))	PrecacheModel("models/weapons/melee/w_cricket_bat.mdl", true);
	if (!IsModelPrecached("models/weapons/melee/v_crowbar.mdl"))		PrecacheModel("models/weapons/melee/v_crowbar.mdl", true);	
	if (!IsModelPrecached("models/weapons/melee/w_crowbar.mdl"))		PrecacheModel("models/weapons/melee/w_crowbar.mdl", true);
	if (!IsModelPrecached("models/weapons/melee/v_electric_guitar.mdl"))PrecacheModel("models/weapons/melee/v_electric_guitar.mdl", true);	
	if (!IsModelPrecached("models/weapons/melee/w_electric_guitar.mdl"))PrecacheModel("models/weapons/melee/w_electric_guitar.mdl", true);
	if (!IsModelPrecached("models/weapons/melee/v_fireaxe.mdl"))		PrecacheModel("models/weapons/melee/v_fireaxe.mdl", true);
	if (!IsModelPrecached("models/weapons/melee/w_fireaxe.mdl"))		PrecacheModel("models/weapons/melee/w_fireaxe.mdl", true);		
	if (!IsModelPrecached("models/weapons/melee/v_frying_pan.mdl"))		PrecacheModel("models/weapons/melee/v_frying_pan.mdl", true);	
	if (!IsModelPrecached("models/weapons/melee/w_frying_pan.mdl"))		PrecacheModel("models/weapons/melee/w_frying_pan.mdl", true);
	if (!IsModelPrecached("models/weapons/melee/v_golfculb.mdl")) 		PrecacheModel("models/weapons/melee/v_golfculb.mdl", true);
	if (!IsModelPrecached("models/weapons/melee/w_golfculb.mdl"))		PrecacheModel("models/weapons/melee/w_golfculb.mdl", true);
	if (!IsModelPrecached("models/weapons/melee/v_katana.mdl"))			PrecacheModel("models/weapons/melee/v_katana.mdl", true);		
	if (!IsModelPrecached("models/weapons/melee/w_katana.mdl"))			PrecacheModel("models/weapons/melee/w_katana.mdl", true);	
	if (!IsModelPrecached("models/weapons/melee/v_machete.mdl"))		PrecacheModel("models/weapons/melee/v_machete.mdl", true);	
	if (!IsModelPrecached("models/weapons/melee/w_machete.mdl"))		PrecacheModel("models/weapons/melee/w_machete.mdl", true);
	if (!IsModelPrecached("models/weapons/melee/v_riotshield.mdl"))		PrecacheModel("models/weapons/melee/v_riotshield.mdl", true);
	if (!IsModelPrecached("models/weapons/melee/w_riotshield.mdl"))		PrecacheModel("models/weapons/melee/w_riotshield.mdl", true);
	if (!IsModelPrecached("models/weapons/melee/v_tonfa.mdl")) 			PrecacheModel("models/weapons/melee/v_tonfa.mdl", true);
	if (!IsModelPrecached("models/weapons/melee/w_tonfa.mdl")) 			PrecacheModel("models/weapons/melee/w_tonfa.mdl", true);
}