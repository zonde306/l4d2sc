/**
* Simple Player Statistics
* 
* Copyright (C) 2019 
* 
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
* 
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License 
* along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

#include <sourcemod>
#include <clientprefs>
#include <sdktools>
#include <smlib>

#pragma semicolon 1
#pragma newdecls required

#define DEBUG

#define PLUGIN_AUTHOR "mac & cheese (a.k.a thresh0ld)"
#define PLUGIN_VERSION "1.0.0-alpha"

#define TEAM_SPECTATOR          1
#define TEAM_SURVIVOR           2
#define TEAM_INFECTED           3

#define IS_VALID_CLIENT(%1)     (%1 > 0 && %1 <= MaxClients)
#define IS_VALID_HUMAN(%1)		(IS_VALID_CLIENT(%1) && IsClientConnected(%1) && !IsFakeClient(%1))
#define IS_SPECTATOR(%1)        (GetClientTeam(%1) == TEAM_SPECTATOR)
#define IS_SURVIVOR(%1)         (GetClientTeam(%1) == TEAM_SURVIVOR)
#define IS_INFECTED(%1)         (GetClientTeam(%1) == TEAM_INFECTED)
#define IS_VALID_INGAME(%1)     (IS_VALID_CLIENT(%1) && IsClientInGame(%1))
#define IS_VALID_SURVIVOR(%1)   (IS_VALID_INGAME(%1) && IS_SURVIVOR(%1))
#define IS_VALID_INFECTED(%1)   (IS_VALID_INGAME(%1) && IS_INFECTED(%1))
#define IS_VALID_SPECTATOR(%1)  (IS_VALID_INGAME(%1) && IS_SPECTATOR(%1))
#define IS_SURVIVOR_ALIVE(%1)   (IS_VALID_SURVIVOR(%1) && IsPlayerAlive(%1))
#define IS_INFECTED_ALIVE(%1)   (IS_VALID_INFECTED(%1) && IsPlayerAlive(%1))
#define IS_HUMAN_SURVIVOR(%1)   (IS_VALID_HUMAN(%1) && IS_SURVIVOR(%1))
#define IS_HUMAN_INFECTED(%1)   (IS_VALID_HUMAN(%1) && IS_INFECTED(%1))

#define MAX_CLIENTS MaxClients

#define CONFIG_FILE "playerstats.cfg"
#define DB_CONFIG_NAME "playerstats"

#define STATS_DISPLAY_TYPE_POINTS 1
#define STATS_DISPLAY_TYPE_AMOUNT 2
#define STATS_DISPLAY_TYPE_BOTH 3

//Player general information
#define STATS_STEAM_ID "steam_id"
#define STATS_LAST_KNOWN_ALIAS "last_known_alias"
#define STATS_LAST_JOIN_DATE "last_join_date"
#define STATS_RANK "rank_num"
#define STATS_CREATE_DATE "create_date"
#define STATS_TOTAL_POINTS "total_points"

//Player in-game statistics
#define STATS_SURVIVOR_KILLED "survivor_killed"
#define STATS_SURVIVOR_INCAPPED "survivor_incapped"
#define STATS_INFECTED_KILLED "infected_killed"
#define STATS_INFECTED_HEADSHOT "infected_headshot"

//Extra special stats
#define STATS_EXTRA_SURV_SKEET_HUNTER_SNIPER "skeet_hunter_sniper"
#define STATS_EXTRA_SURV_SKEET_HUNTER_SHOTGUN "skeet_hunter_shotgun"
#define STATS_EXTRA_SURV_SKEET_HUNTER_MELEE "skeet_hunter_melee"
#define STATS_EXTRA_SURV_SKEET_TANK_ROCK "skeet_tank_rock"
#define STATS_EXTRA_SURV_WITCH_CROWN_STD "witch_crown_standard"
#define STATS_EXTRA_SURV_WITCH_CROWN_DRAW "witch_crown_draw"
#define STATS_EXTRA_SURV_BOOMER_POP "boomer_pop"
#define STATS_EXTRA_SURV_CHARGER_LEVEL "charger_level"
#define STATS_EXTRA_SURV_SMOKER_TONGUE_CUT "smoker_tongue_cut"
#define STATS_EXTRA_SURV_HUNTER_DEADSTOP "hunter_dead_stop"
#define STATS_EXTRA_SI_BOOMER_QUAD "boomer_quad"
#define STATS_EXTRA_SI_HUNTER_25 "hunter_twenty_five"
#define STATS_EXTRA_SI_DEATHCHARGE "death_charge"
#define STATS_EXTRA_SI_TANK_ROCK_HITS "tank_rock_hits" 

#define DEFAULT_POINT_MODIFIER 1.0
#define DEFAULT_PLUGIN_TAG "PSTATS"
#define DEFAULT_TITLE_STAT_PANEL_PLAYER "Player Stats"
#define DEFAULT_TITLE_STAT_PANEL_TOPN "Top {top_player_count} Players"
#define DEFAULT_TITLE_STAT_PANEL_INGAME "Player In-Game Ranks"
#define DEFAULT_TITLE_STAT_PANEL_EXTRAS "Additional Stats"

#define DEFAULT_CONFIG_ANNOUNCE_FORMAT "{N}玩家 '{G}{last_known_alias}{N}' ({B}{steam_id}{N}) 正在加入游戏 ({G}排名:{N} {i:rank_num}, {G}积分:{N} {f:total_points})"
#define DEFAULT_TOP_PLAYERS 10
#define DEFAULT_MIN_TOP_PLAYERS 10
#define DEFAULT_MAX_TOP_PLAYERS 50

#define GAMEINFO_SERVER_NAME "server_name"

Database g_hDatabase = null;
StringMap g_mStatModifiers;

bool g_bPlayerInitialized[MAXPLAYERS + 1] = false;
bool g_bInitializing[MAXPLAYERS + 1] = false;
bool g_bShowingRankPanel[MAXPLAYERS + 1] = false;
//need this flag below to allow us to know if the player has viewed his rank on join. 
//we do not need to keep displaying his/her rank everytime he/she changes teams.
bool g_bPlayerRankShown[MAXPLAYERS + 1] = true;
char g_ConfigPath[PLATFORM_MAX_PATH];

char g_StatPanelTitlePlayer[255];
char g_StatPanelTitleTopN[255];
char g_StatPanelTitleInGame[255];
char g_StatPanelTitleExtras[255];

char g_ConfigAnnounceFormat[512];
bool g_bSkillDetectLoaded = false;
char g_SelSteamIds[MAXPLAYERS + 1][64];

ConVar g_bDebug;
ConVar g_bVersusExclusive;
ConVar g_bEnabled;
ConVar g_bRecordBots;
ConVar g_iStatsMenuTimeout;
ConVar g_iStatsMaxTopPlayers;
ConVar g_bEnableExtraStats;
ConVar g_iStatsDisplayType;
ConVar g_sGameMode;
ConVar g_sServerName;
ConVar g_bShowRankOnConnect;
ConVar g_bConnectAnnounceEnabled;

char g_sBasicStats[][128] =  {
	STATS_SURVIVOR_KILLED, 
	STATS_SURVIVOR_INCAPPED, 
	STATS_INFECTED_KILLED, 
	STATS_INFECTED_HEADSHOT
};

char g_sExtraStats[][128] =  {
	STATS_EXTRA_SURV_SKEET_HUNTER_SNIPER, 
	STATS_EXTRA_SURV_SKEET_HUNTER_SHOTGUN, 
	STATS_EXTRA_SURV_SKEET_HUNTER_MELEE, 
	STATS_EXTRA_SURV_SKEET_TANK_ROCK, 
	STATS_EXTRA_SURV_WITCH_CROWN_STD, 
	STATS_EXTRA_SURV_WITCH_CROWN_DRAW, 
	STATS_EXTRA_SURV_BOOMER_POP, 
	STATS_EXTRA_SURV_CHARGER_LEVEL, 
	STATS_EXTRA_SURV_SMOKER_TONGUE_CUT, 
	STATS_EXTRA_SURV_HUNTER_DEADSTOP, 
	STATS_EXTRA_SI_BOOMER_QUAD, 
	STATS_EXTRA_SI_HUNTER_25, 
	STATS_EXTRA_SI_DEATHCHARGE, 
	STATS_EXTRA_SI_TANK_ROCK_HITS
};

public Plugin myinfo = 
{
	name = "简易玩家统计", 
	author = PLUGIN_AUTHOR, 
	description = "Tracks kills, deaths and other special skills", 
	version = PLUGIN_VERSION, 
	url = "https://github.com/sourcemod-plugins/l4d2-player-stats"
};

/**
* Called when the plugin is fully initialized and all known external references are resolved. This is only called once in the lifetime of the plugin, and is paired with OnPluginEnd().
* If any run-time error is thrown during this callback, the plugin will be marked as failed.
*/
public void OnPluginStart()
{
	//Make sure we are on left 4 dead 2!
	if (GetEngineVersion() != Engine_Left4Dead2) {
		SetFailState("This plugin only supports left 4 dead 2!");
		return;
	}
	
	BuildPath(Path_SM, g_ConfigPath, sizeof(g_ConfigPath), "configs/%s", CONFIG_FILE);
	
	char defaultTopPlayerStr[32];
	IntToString(DEFAULT_TOP_PLAYERS, defaultTopPlayerStr, sizeof(defaultTopPlayerStr));
	
	CreateConVar("pstats_version", PLUGIN_VERSION, "Plugin Version", FCVAR_DONTRECORD|FCVAR_NOTIFY);
	g_bEnabled = CreateConVar("pstats_enabled", "1", "是否开启插件", _, true, 0.0, true, 1.0);
	g_bDebug = CreateConVar("pstats_debug_enabled", "0", "是否显示调试信息", _, true, 0.0, true, 1.0);
	g_bVersusExclusive = CreateConVar("pstats_versus_exclusive", "0", "是否只在对抗模式开启", _, true, 0.0, true, 1.0);
	g_bRecordBots = CreateConVar("pstats_record_bots", "1", "是否允许记录机器人统计", _, true, 0.0, true, 1.0);
	g_iStatsMenuTimeout = CreateConVar("pstats_menu_timeout", "30", "统计面板显示时间", _, true, 3.0, true, 9999.0);
	g_iStatsMaxTopPlayers = CreateConVar("pstats_max_top_players", defaultTopPlayerStr, "显示前多少的玩家排名", _, true, float(DEFAULT_MIN_TOP_PLAYERS), true, float(DEFAULT_MAX_TOP_PLAYERS));
	g_bEnableExtraStats = CreateConVar("pstats_extras_enabled", "1", "统计附加信息，需要 skill_detect 插件", _, true, 0.0, true, 1.0);
	g_iStatsDisplayType = CreateConVar("pstats_display_type", "2", "显示模式.1=积分.2=计数.3=全部", _, true, 1.0, true, 3.0);
	g_bShowRankOnConnect = CreateConVar("pstats_show_rank_onjoin", "1", "换图或加入时显示统计", _, true, 0.0, true, 1.0);
	g_bConnectAnnounceEnabled = CreateConVar("pstats_cannounce_enabled", "1", "玩家连接时显示统计", _, true, 0.0, true, 1.0);
	AutoExecConfig(true, "l4d2_simpleplayerstats");
	
	g_sGameMode = FindConVar("mp_gamemode");
	g_sServerName = FindConVar("hostname");
	g_mStatModifiers = new StringMap();
	
	if (!InitDatabase()) {
		Error("Could not connect to the database. Please check your database configuration file and make sure everything is configured correctly. (db section name: %s)", DB_CONFIG_NAME);
		SetFailState("Could not connect to the database");
	}
	
	RegConsoleCmd("sm_rank", Command_ShowRank, "Display the current stats & ranking of the requesting player. A panel will be displayed to the player.");
	RegConsoleCmd("sm_top", Command_ShowTopPlayers, "Display the top N players. A menu panel will be displayed to the requesting player");
	RegConsoleCmd("sm_ranks", Command_ShowTopPlayersInGame, "Display the ranks of the players currently playing in the server. A menu panel will be displayed to the requesting player.");
	RegConsoleCmd("sm_hidestats", Command_HideExtraFromPublic, "If set by the player, extra stats will not be shown to the public (e.g. via top 10 panel)");
	RegAdminCmd("sm_pstats_reload", Command_ReloadConfig, ADMFLAG_ROOT, "Reloads plugin configuration. This is useful if you have modified the playerstats.cfg file. 'This command also synchronizes the modifier values set from the configuration file to the database.");
	
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	HookEvent("player_incapacitated", Event_PlayerIncapped, EventHookMode_Post);
	HookEvent("round_start", Event_OnRoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_OnRoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Post);
	HookEvent("witch_killed", Event_WitchKilled, EventHookMode_Post);
	//Perform one time initialization when the player first connects to the server (shouldn't be called on map change)
	HookEvent("player_connect", Event_PlayerConnect, EventHookMode_Post);
	//Note: We use this event instead of OnClientDisconnect because this event does not get fired on map change.
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Post);
	HookEvent("map_transition", Event_MapTransition, EventHookMode_Post);
	HookEvent("player_transitioned", Event_PlayerTransitioned, EventHookMode_Post);
	HookEvent("bot_player_replace", Event_PlayerReplaceBot, EventHookMode_Post);
}

/**
* Called when all plugins have been loaded
*/
public void OnAllPluginsLoaded() {
	g_bSkillDetectLoaded = LibraryExists("skill_detect");
	
	Debug("OnAllPluginsLoaded()");
}

/**
* Called when a plugin/library has been removed/unloaded
*/
public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "skill_detect")) {
		g_bSkillDetectLoaded = false;
		Debug("Skill detect plugin unloaded");
	}
}

/**
* Called when a plugin/library has been added/reloaded
*/
public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "skill_detect")) {
		g_bSkillDetectLoaded = true;
		Debug("Skill detect plugin loaded");
	}
}

/**
* Called when the map has loaded, servercfgfile (server.cfg) has been executed, and all plugin configs are done executing. 
* This is the best place to initialize plugin functions which are based on cvar data.
*/
public void OnConfigsExecuted() {
	Debug("Loading config file: %s", g_ConfigPath);
	
	//Load and parse the config file
	if (!LoadConfigData()) {
		SetFailState("Problem loading/reading config file: %s", g_ConfigPath);
		return;
	}
	
	//Determine if whether we should automatically sync the values of the cached modifier entries
	if (GetStatModifierCount() == 0) {
		FlushStatModifiersToDb();
	}
	
	//If the plugin has been reloaded, we re-initialize the players herer. 
	//This does not apply during map transition
	if (GetHumanPlayerCount() > 0) {
		Debug("OnConfigsExecuted() :: Initializing players");
		InitializePlayers();
	}
	else {
		Debug("OnConfigsExecuted() :: Skipped player initialization. No available players or players have not connected yet.");
	}
}

/**
* Called when a client receives an auth ID. The state of a client's authorization as an admin is not guaranteed here. 
* Use OnClientPostAdminCheck() if you need a client's admin status.
* This is called by bots, but the ID will be "BOT".
*/
public void OnClientAuthorized(int client, const char[] auth) {
	//Ignore bots
	if (!IS_VALID_HUMAN(client))
		return;
	Debug("OnClientAuthorized(%N) = %s", client, auth);
	if (!isInitialized(client)) {
		InitializePlayer(client, true);
	} else {
		Debug("OnClientAuthorized :: Client '%N' has already been initialized. Skipping initialization", client);
	}
}

/**
* Called once a client successfully connects. This callback is paired with OnClientDisconnect.
*/
public void OnClientConnected(int client) {
	if (!IS_VALID_HUMAN(client))
		return;
	Debug("OnClientConnected(%N)", client);
}

/**
* Called when a client is entering the game.
* Whether a client has a steamid is undefined until OnClientAuthorized is called, which may occur either before or after OnClientPutInServer. 
* Similarly, use OnClientPostAdminCheck() if you need to verify whether connecting players are admins.
* GetClientCount() will include clients as they are passed through this function, as clients are already in game at this point.
*/
public void OnClientPutInServer(int client) {
	if (!IS_VALID_HUMAN(client))
		return;
	Debug("OnClientPutInServer(%N)", client);
}

/**
* Called once a client is authorized and fully in-game, and after all post-connection authorizations have been performed.
* This callback is guaranteed to occur on all clients, and always after each OnClientPutInServer() call.
*/
public void OnClientPostAdminCheck(int client) {
	if (!IS_VALID_HUMAN(client))
		return;
	Debug("OnClientPostAdminCheck(%N = %i)", client, client);
	//Just in-case, need to check if initialized since we are going to retrieve stats info from the player
	if (!isInitialized(client)) {
		Debug("Player has not yet been initialized. Skipping connect announce for '%N'", client);
		return;
	}
	PlayerConnectAnnounce(client);
}

/**
* Called when a client is disconnecting from the server. 
*  Note: This will also be called when server is changing levels
*/
public void OnClientDisconnect(int client) {
	if (!IS_VALID_HUMAN(client))
		return;
	
	Debug("OnClientDisconnect(%N) :: Resetting flags for client.", client);
	g_bInitializing[client] = false;
}

/**
* Called when the map is loaded.
*/
public void OnMapStart() {
	Debug("================================= OnMapStart =================================");
	ResetShowPlayerRankFlags();
}

/**
* Called right before a map ends.
*/
public void OnMapEnd() {
	if (HasNextMap()) {
		Debug("================================= OnMapEnd ================================= (CHANGING LEVELS)");
	} else {
		Debug("================================= OnMapEnd ================================= (NOT CHANGING LEVEL)");
	}
}

/**
* Callback for sm_hidestats command
*/
public Action Command_HideExtraFromPublic(int client, int args) {
	Debug("Hide stats");
	return Plugin_Handled;
}

/**
* Callback for sm_pstats_reload command
*/
public Action Command_ReloadConfig(int client, int args) {
	if (PluginDisabled()) {
		Debug("Client %N tried to execute command but player stats is currently disabled.", client);
		return Plugin_Handled;
	}
	
	bool sync = false;
	
	//check if sync argument was provided
	if (args >= 1) {
		char arg[255];
		GetCmdArg(1, arg, sizeof(arg));
		String_Trim(arg, arg, sizeof(arg));
		
		if (StrEqual("sync", arg)) {
			sync = true;
		} else {
			Notify(client, "Usage: sm_pstats_reload <sync>");
			return Plugin_Handled;
		}
	}
	
	if (!LoadConfigData()) {
		LogAction(client, -1, "Failed to reload plugin configuration file");
		SetFailState("Problem loading/reading config file: %s", g_ConfigPath);
		return Plugin_Handled;
	}
	
	//If sync is specified, flush the cached entries to the database
	if (sync) {
		if (!ExtrasEnabled()) {
			Notify(client, "Note: Extra statistics are excluded from this operation since the feature is disabled.");
		}
		FlushStatModifiersToDb();
	}
	
	LogAction(client, -1, "Plugin configuration reloaded successfully");
	Notify(client, "Plugin configuration reloaded successfully");
	
	if (DebugEnabled()) {
		PlayerConnectAnnounce(client);
	}
	return Plugin_Handled;
}

/**
* Flushes the cached stat modifiers (entries that have been recently read from the config file) into the database
*/
public void FlushStatModifiersToDb() {
	if (g_mStatModifiers == null || g_mStatModifiers.Size == 0) {
		Debug("FlushStatModifiersToDb :: No cached entries available. Perhaps the config file was not loaded?");
		return;
	}
	
	StringMapSnapshot keys = g_mStatModifiers.Snapshot();
	
	for (int i = 0; i < keys.Length; i++) {
		int bufferSize = keys.KeyBufferSize(i);
		char[] keyName = new char[bufferSize];
		keys.GetKey(i, keyName, bufferSize);
		
		float value = DEFAULT_POINT_MODIFIER;
		if (g_mStatModifiers.GetValue(keyName, value)) {
			if (!ExtrasEnabled() && IsExtraStat(keyName)) {
				Debug("Extra stats disabled. Skipping stat update for '%s' = %.2f", keyName, value);
				continue;
			}
			SyncStatModifiers(keyName, value);
		}
	}
}

/**
* Load/Reload the plugin configuration file
*
* @param forceSync If true, the stat modifiers read from the config file will be synchronized to the database.
*/
bool LoadConfigData() {
	KeyValues kv = new KeyValues("PlayerStats");
	
	if (!kv.ImportFromFile(g_ConfigPath)) {
		return false;
	}
	
	//Re-initialize the modifier map
	if (g_mStatModifiers == null) {
		Debug("Re-initializing map");
		g_mStatModifiers = new StringMap();
	}
	
	Info("Parsing configuration file: %s", g_ConfigPath);
	
	Debug("Processing Stat Modifiers");
	if (kv.JumpToKey("StatModifiers", false))
	{
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				char key[255];
				float value;
				kv.GetSectionName(key, sizeof(key));
				value = kv.GetFloat(NULL_STRING, DEFAULT_POINT_MODIFIER);
				
				Debug("> Caching modifier: %s = %f", key, value);
				g_mStatModifiers.SetValue(key, value, true);
			}
			while (kv.GotoNextKey(false));
		}
		kv.GoBack();
	} else {
		Error("Missing config key 'StatModifiers'");
		delete kv;
		return false;
	}
	kv.GoBack();
	
	Debug("Cached a total of %d stat modifiers", g_mStatModifiers.Size);
	
	Debug("Processing Stat Panel Configuration");
	if (!kv.JumpToKey("StatPanels"))
	{
		Error("Missing config key 'PlayerRankPanel'");
		delete kv;
		return false;
	}
	
	//Player rank panel
	kv.GetString("title_rank_player", g_StatPanelTitlePlayer, sizeof(g_StatPanelTitlePlayer));
	
	if (strcmp(g_StatPanelTitlePlayer, "", false) == 0) {
		Debug("Config 'title_rank_player' is empty. Using default");
		FormatEx(g_StatPanelTitlePlayer, sizeof(g_StatPanelTitlePlayer), DEFAULT_TITLE_STAT_PANEL_PLAYER);
	}
	
	//Top N rank panel
	kv.GetString("title_rank_topn", g_StatPanelTitleTopN, sizeof(g_StatPanelTitleTopN));
	
	if (strcmp(g_StatPanelTitleTopN, "", false) == 0) {
		Debug("Config 'title_rank_topn' is empty. Using default");
		FormatEx(g_StatPanelTitleTopN, sizeof(g_StatPanelTitleTopN), DEFAULT_TITLE_STAT_PANEL_TOPN);
	}
	
	//In-Game players rank panel
	kv.GetString("title_rank_ingame", g_StatPanelTitleInGame, sizeof(g_StatPanelTitleInGame));
	
	if (strcmp(g_StatPanelTitleInGame, "", false) == 0) {
		Debug("Config 'title_rank_ingame' is empty. Using default");
		FormatEx(g_StatPanelTitleInGame, sizeof(g_StatPanelTitleInGame), DEFAULT_TITLE_STAT_PANEL_INGAME);
	}
	
	kv.GetString("title_rank_extras", g_StatPanelTitleExtras, sizeof(g_StatPanelTitleExtras));
	if (strcmp(g_StatPanelTitleExtras, "", false) == 0) {
		Debug("Config 'title_rank_extras' is empty. Using default");
		FormatEx(g_StatPanelTitleExtras, sizeof(g_StatPanelTitleExtras), DEFAULT_TITLE_STAT_PANEL_EXTRAS);
	}
	
	Debug("> Parsed title : Stat Panel Title (Player) = %s", g_StatPanelTitlePlayer);
	Debug("> Parsed title : Stat Panel Title (Top N) = %s", g_StatPanelTitleTopN);
	Debug("> Parsed title : Stat Panel Title (In-Game) = %s", g_StatPanelTitleInGame);
	Debug("> Parsed title : Stat Panel Title (Extras) = %s", g_StatPanelTitleExtras);
	
	kv.GoBack();
	
	Debug("Processing Connect Announce");
	if (!kv.JumpToKey("ConnectAnnounce")) {
		Error("Missing config key 'ConnectAnnounce'");
		delete kv;
		return false;
	}
	
	kv.GetString("format", g_ConfigAnnounceFormat, sizeof(g_ConfigAnnounceFormat));
	
	if (strcmp(g_ConfigAnnounceFormat, "", false) == 0) {
		Debug("> Connect announce format is empty. Using default");
		FormatEx(g_ConfigAnnounceFormat, sizeof(g_ConfigAnnounceFormat), DEFAULT_CONFIG_ANNOUNCE_FORMAT);
	}
	
	Debug("> Parsed connect announce format : Connect Announce Format = %s", g_ConfigAnnounceFormat);
	
	delete kv;
	return true;
}

public int GetStatModifierCount() {
	int count = 0;
	DBResultSet query = SQL_Query(g_hDatabase, "SELECT COUNT(1) FROM STATS_SKILLS");
	if (query == null) {
		char error[255];
		SQL_GetError(g_hDatabase, error, sizeof(error));
		Error("GetStatModifierCount :: Failed to query table count (Reason: %s)", error);
		return -1;
	}
	else {
		if (query.FetchRow()) {
			count = query.FetchInt(0);
			Debug("Got total stat modifier count in table: %i", count);
		}
		delete query;
	}
	return count;
}

/**
* Synchronizes (Insert or Update) the statistic key/value into the STATS_SKILLS database table
*/
public void SyncStatModifiers(const char[] key, float value) {
	if (StringBlank(key)) {
		Debug("No key specified. Skipping sync");
		return;
	}
	
	int len = strlen(key) * 2 + 1;
	char[] qKey = new char[len];
	if (!g_hDatabase.Escape(key, qKey, len)) {
		Debug("Could not escape string '%s'", key);
		return;
	}
	
	char query[512];
	FormatEx(query, sizeof(query), "INSERT INTO STATS_SKILLS (name, modifier, update_date) VALUES ('%s', %f, current_timestamp()) ON DUPLICATE KEY UPDATE modifier = %f, update_date = current_timestamp()", qKey, value, value);
	
	DataPack pack = new DataPack();
	pack.WriteString(key);
	pack.WriteFloat(value);
	
	g_hDatabase.Query(TQ_SyncStatModifiers, query, pack);
}

/**
* SQL Callback for SyncStatModifiers
*/
public void TQ_SyncStatModifiers(Database db, DBResultSet results, const char[] error, any data) {
	if (results == null) {
		Error("TQ_SyncStatModifiers :: Query failed (Reason: %s)", error);
		return;
	}
	
	DataPack pack = data;
	char name[255];
	float modifier;
	
	pack.Reset();
	pack.ReadString(name, sizeof(name));
	modifier = pack.ReadFloat();
	
	if (results.AffectedRows > 0) {
		Debug("Synchronized cached entry to DB (%s = %.2f)", name, modifier);
	} else {
		Debug("Nothing was synced (%s = %.2f)", name, modifier);
	}
}

public Action Event_PlayerReplaceBot(Event event, const char[] name, bool dontBroadcast) {
	int botId = event.GetInt("bot");
	int userId = event.GetInt("player");
	
	int botClientId = GetClientOfUserId(botId);
	int clientId = GetClientOfUserId(userId);
	
	Debug("Player %N has replaced bot %N", clientId, botClientId);
	
	return Plugin_Continue;
}

public Action Event_PlayerTransitioned(Event event, const char[] name, bool dontBroadcast) {
	int userId = event.GetInt("userid");
	int clientId = GetClientOfUserId(userId);
	Debug("Player has transitioned to first person view = %N", clientId);
	
	if (IS_VALID_HUMAN(clientId) && ShowRankOnConnect() && !PlayerRankShown(clientId)) {
		char steamId[MAX_STEAMAUTH_LENGTH];
		if (GetClientAuthId(clientId, AuthId_Steam2, steamId, sizeof(steamId))) {
			ShowPlayerRankPanel(clientId, steamId);
			SetPlayerRankShownFlag(clientId);
		} else {
			Error("Event_PlayerTransitioned :: Could not obtain steam id of client %N", clientId);
		}
	}
	
	return Plugin_Continue;
}

public Action Event_PlayerConnect(Event event, const char[] name, bool dontBroadcast) {
	char playerName[MAX_NAME_LENGTH];
	char steamId[MAX_STEAMAUTH_LENGTH];
	char ipAddress[16];
	
	event.GetString("name", playerName, sizeof(playerName));
	event.GetString("networkid", steamId, sizeof(steamId));
	event.GetString("address", ipAddress, sizeof(ipAddress));
	int slot = event.GetInt("index");
	int userid = event.GetInt("userid");
	bool isBot = event.GetBool("bot");
	
	if (!isBot) {
		int client = GetClientOfUserId(userid);
		Debug("\n\nPLAYER_CONNECT_EVENT :: Name = %s, Steam ID: %s, IP: %s, Slot: %i, User ID: %i, Is Bot: %i, Client ID: %i\n\n", playerName, steamId, ipAddress, slot, userid, isBot, client);
		//InitializePlayer(client, true);
	}
}

public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast) {
	char reason[512];
	char playerName[MAX_NAME_LENGTH];
	char networkId[255];
	
	int userId = event.GetInt("userid");
	int clientId = GetClientOfUserId(userId);
	
	event.GetString("name", playerName, sizeof(playerName));
	event.GetString("reason", reason, sizeof(reason));
	event.GetString("networkid", networkId, sizeof(networkId));
	int isBot = event.GetInt("bot");
	
	if (!IS_VALID_CLIENT(clientId) || IsFakeClient(clientId))
		return Plugin_Continue;
	
	Debug("(EVENT => %s): name = %s, reason = %s, id = %s, isBot = %i, clientid = %i", name, playerName, reason, networkId, isBot, clientId);
	Debug("Resetting client flags for player %N", clientId);
	
	g_bPlayerInitialized[clientId] = false;
	
	UnsetPlayerRankShownFlag(clientId);
	
	return Plugin_Continue;
}

public Action Event_MapTransition(Event event, const char[] name, bool dontBroadcast) {
	Debug("================================= MAP TRANSITION =================================");
}

/**
* Called when the plugin is about to be unloaded.
* It is not necessary to close any handles or remove hooks in this function. SourceMod guarantees that plugin shutdown automatically and correctly releases all resources.
*/
public void OnPluginEnd() {
	Debug("================================= OnPluginEnd =================================");
}

/**
* Check if player has been initialized (existing record in database)
*
* @return true if the player record has been initialized
*/
public bool isInitialized(int client) {
	return g_bPlayerInitialized[client];
}

/**
* Function to check if we are on the final level of the versus campaign
*
* @return true if the current map is the final map of the versus campaign
*/
stock bool IsFinalMap()
{
	return (FindEntityByClassname(-1, "info_changelevel") == -1
		 && FindEntityByClassname(-1, "trigger_changelevel") == -1);
}

/**
* Function to check if we still have a next level after the current
* 
* @return true if we still have next map after the current
*/
stock bool HasNextMap()
{
	return (FindEntityByClassname(-1, "info_changelevel") >= 0
		 || FindEntityByClassname(-1, "trigger_changelevel") >= 0);
}

/**
* Callback for sm_topig command
*/
public Action Command_ShowTopPlayersInGame(int client, int args) {
	if (PluginDisabled()) {
		Notify(client, "Cannot execute command. Player stats is currently disabled.");
		return Plugin_Handled;
	}
	ShowInGamePlayerRanks(client);
	return Plugin_Handled;
}

/**
* Display a panel showing the statistics and rank of the players in-game
*
* @param client The requesting client index
*/
public void ShowInGamePlayerRanks(int client) {
	if (!IS_VALID_CLIENT(client) || IsFakeClient(client)) {
		Debug("ShowInGamePlayerRanks :: Skipping show stats. Not a valid client (%i)", client);
		return;
	}
	
	char steamId[128];
	GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));
	
	char steamIds[256];
	int count = GetInGamePlayerSteamIds(steamIds, sizeof(steamIds));
	
	if (count == 0) {
		Debug("ShowInGamePlayerRanks :: No players available to query");
		return;
	}
	
	Debug("Steam Ids = %s", steamIds);
	
	char query[512];
	
	if (ExtrasEnabled()) {
		FormatEx(query, sizeof(query), "SELECT * from STATS_VW_PLAYER_RANKS_EXTRAS s WHERE s.steam_id IN (%s) ORDER BY rank_num LIMIT 8", steamIds);
	} else {
		FormatEx(query, sizeof(query), "SELECT * from STATS_VW_PLAYER_RANKS s WHERE s.steam_id IN (%s) ORDER BY rank_num LIMIT 8", steamIds);
	}
	
	Debug("ShowInGamePlayerRanks :: Executing query: %s", query);
	
	DataPack pack = new DataPack();
	pack.WriteCell(client);
	pack.WriteCell(count);
	g_hDatabase.Query(TQ_ShowInGamePlayerRanks, query, pack);
}

/**
* SQL Callback for 'ShowInGamePlayerRanks' Command
*/
public void TQ_ShowInGamePlayerRanks(Database db, DBResultSet results, const char[] error, any data) {
	DataPack pack = data;
	StringMap map = new StringMap();
	
	pack.Reset();
	int clientId = pack.ReadCell();
	//int playerCount = pack.ReadCell();
	
	//Verify that the player is still connected to the server
	if (!IS_VALID_HUMAN(clientId)) {
		Error("TQ_ShowInGamePlayerRanks :: Client id %i is no longer valid (Player has probably left the server before the completion of this request)", clientId);
		delete pack;
		delete map;
		return;
	}
	
	char msg[255];
	Menu menu = new Menu(TopInGameRanksMenuHandler);
	menu.ExitButton = true;
	menu.SetTitle(g_StatPanelTitleInGame);
	
	while (results.FetchRow()) {
		ExtractPlayerStats(results, map);
		
		char steamId[128];
		char lastKnownAlias[255];
		int rankNum;
		
		map.GetString(STATS_STEAM_ID, steamId, sizeof(steamId));
		map.GetString(STATS_LAST_KNOWN_ALIAS, lastKnownAlias, sizeof(lastKnownAlias));
		map.GetValue(STATS_RANK, rankNum);
		
		Debug("> Player: %s", lastKnownAlias);
		Format(msg, sizeof(msg), "%s (Rank %d)", lastKnownAlias, rankNum);
		menu.AddItem(steamId, msg);
		
		delete map;
		map = new StringMap();
	}
	
	menu.Display(clientId, g_iStatsMenuTimeout.IntValue);
	
	delete pack;
	delete map;
}

/**
* Callback for TQ_ShowInGamePlayerRanks menu
*/
public int TopInGameRanksMenuHandler(Menu menu, MenuAction action, int clientId, int idIndex) {
	//Verify that the player is still connected to the server
	/*if (!IS_VALID_HUMAN(clientId)) {
		Error("TopInGameRanksMenuHandler :: Client id %i is no longer valid (Player has probably left the server before the completion of this request)", clientId);
		delete menu;
		return;
	}*/
	
	/* If an option was selected, tell the client about the item. */
	if (action == MenuAction_Select)
	{
		char steamId[64];
		bool found = menu.GetItem(idIndex, steamId, sizeof(steamId));
		
		if (found) {
			ShowPlayerRankPanel(clientId, steamId);
		}
	}
	/* If the menu was cancelled, print a message to the server about it. */
	else if (action == MenuAction_Cancel)
	{
		Debug("Client %N's menu was cancelled.  Reason: %d", clientId, idIndex);
	}
	/* If the menu has ended, destroy it */
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

/**
* Builds a comma delimited string of steam ids of each player who is currently in-game and associated with a team (survivor or infected). 
* Spectators or players with invalid steam id are ignored. Note: The buffer should be big enough to contain 8 steam id strings (at least 256).
*/
public int GetInGamePlayerSteamIds(char[] buffer, int size) {
	if (size < 171) {
		Error("GetInGamePlayerSteamIds :: Buffer size is too small (%i). Should be > 170", size);
		return 0;
	}
	int count = 0;
	char steamId[128];
	char tmp[128];
	
	int humanCount = GetHumanPlayerCount(false);
	
	for (int i = 1; i <= MAX_CLIENTS; i++) {
		if (IS_VALID_HUMAN(i) && (IS_VALID_SURVIVOR(i) || IS_VALID_INFECTED(i))) {
			//yeah, do not ignore retvals
			if (GetClientAuthId(i, AuthId_Steam2, steamId, sizeof(steamId))) {
				if ((count + 1) >= humanCount) {
					FormatEx(tmp, sizeof(tmp), "'%s'", steamId);
				} else {
					FormatEx(tmp, sizeof(tmp), "'%s',", steamId);
				}
				Debug("GetInGamePlayerSteamIds :: Adding: %s", tmp);
				StrCat(buffer, size, tmp);
				count++;
			}
		}
	}
	return count;
}

/**
* Callback method for the sm_top console command
*/
public Action Command_ShowTopPlayers(int client, int args) {
	if (PluginDisabled()) {
		Notify(client, "Cannot execute command. Player stats is currently disabled.");
		return Plugin_Handled;
	}
	
	int maxPlayers = (g_iStatsMaxTopPlayers.IntValue <= 0) ? DEFAULT_MAX_TOP_PLAYERS : g_iStatsMaxTopPlayers.IntValue;
	
	if (args >= 1) {
		
		char arg[255];
		GetCmdArg(1, arg, sizeof(arg));
		
		if (!String_IsNumeric(arg)) {
			Notify(client, "Argument must be numeric: %s", arg);
			return Plugin_Handled;
		}
		
		String_Trim(arg, arg, sizeof(arg));
		
		maxPlayers = StringToInt(arg);
		
		//Check bounds
		if (maxPlayers < DEFAULT_MIN_TOP_PLAYERS) {
			maxPlayers = DEFAULT_MIN_TOP_PLAYERS;
		}
		if (maxPlayers > DEFAULT_MAX_TOP_PLAYERS)
			maxPlayers = DEFAULT_MAX_TOP_PLAYERS;
	}
	
	Debug("Displaying top %i players", maxPlayers);
	ShowTopPlayersRankPanel(client, maxPlayers);
	
	return Plugin_Handled;
}

/**
* Display the Player Rank Panel to the target user
*
* @param client The target client index
* @param max The maximum number of players to be displayed on the rank panel. Note: The upper and lower limits are capped between DEFAULT_MIN_TOP_PLAYERS and DEFAULT_MAX_TOP_PLAYERS.
*/
void ShowTopPlayersRankPanel(int client, int max = DEFAULT_MAX_TOP_PLAYERS) {
	if (!IS_VALID_CLIENT(client) || IsFakeClient(client)) {
		Debug("Skipping show stats. Not a valid client");
		return;
	}
	
	char steamId[128];
	GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));
	
	int len = strlen(steamId) * 2 + 1;
	char[] qSteamId = new char[len];
	SQL_EscapeString(g_hDatabase, steamId, qSteamId, len);
	
	int maxRows = (max <= 0) ? ((g_iStatsMaxTopPlayers.IntValue <= 0) ? DEFAULT_MAX_TOP_PLAYERS : g_iStatsMaxTopPlayers.IntValue) : max;
	
	char query[512];
	
	if (ExtrasEnabled()) {
		FormatEx(query, sizeof(query), "select * from STATS_VW_PLAYER_RANKS_EXTRAS s LIMIT %i", maxRows);
	} else {
		FormatEx(query, sizeof(query), "select * from STATS_VW_PLAYER_RANKS s LIMIT %i", maxRows);
	}
	
	Debug("ShowTopPlayersRankPanel :: Executing query: %s", query);
	
	DataPack pack = new DataPack();
	pack.WriteCell(client);
	pack.WriteCell(maxRows);
	
	g_hDatabase.Query(TQ_ShowTopPlayers, query, pack);
}

/**
* SQL Callback for Show Top Players Command
*/
public void TQ_ShowTopPlayers(Database db, DBResultSet results, const char[] error, DataPack pack) {
	pack.Reset();
	int clientId = pack.ReadCell();
	int maxRows = pack.ReadCell();
	
	//Verify that the player is still connected to the server
	if (!IS_VALID_HUMAN(clientId)) {
		Error("TQ_ShowTopPlayers :: Client id %i is no longer valid (Player has probably left the server before the completion of this request)", clientId);
		delete pack;
		return;
	}
	
	StringMap map = new StringMap();
	
	Debug("Displaying Total of %i entries", maxRows);
	
	char msg[255];
	Menu menu = new Menu(TopPlayerStatsMenuHandler);
	menu.ExitButton = true;
	
	FormatEx(msg, sizeof(msg), "%s", g_StatPanelTitleTopN);
	
	char maxRowsStr[32];
	IntToString(maxRows, maxRowsStr, sizeof(maxRowsStr));
	ReplaceString(msg, sizeof(msg), "{top_player_count}", maxRowsStr);
	menu.SetTitle(msg);
	
	while (results.FetchRow()) {
		ExtractPlayerStats(results, map);
		
		char steamId[128];
		char lastKnownAlias[255];
		int rankNum;
		
		map.GetString(STATS_STEAM_ID, steamId, sizeof(steamId));
		map.GetString(STATS_LAST_KNOWN_ALIAS, lastKnownAlias, sizeof(lastKnownAlias));
		map.GetValue(STATS_RANK, rankNum);
		
		Debug("> Player: %s", lastKnownAlias);
		Format(msg, sizeof(msg), "%s (第 %d 名)", lastKnownAlias, rankNum);
		menu.AddItem(steamId, msg);
		
		delete map;
		map = new StringMap();
	}
	
	menu.Display(clientId, g_iStatsMenuTimeout.IntValue);
	
	delete pack;
	delete map;
}

public int TopPlayerStatsMenuHandler(Menu menu, MenuAction action, int clientId, int idIndex)
{
	/* If an option was selected, tell the client about the item. */
	if (action == MenuAction_Select)
	{
		char steamId[64];
		bool found = menu.GetItem(idIndex, steamId, sizeof(steamId));
		
		if (found) {
			ShowPlayerRankPanel(clientId, steamId);
		}
	}
	/* If the menu was cancelled, print a message to the server about it. */
	else if (action == MenuAction_Cancel)
	{
		Debug("Client %N's menu was cancelled.  Reason: %d", clientId, idIndex);
	}
	/* If the menu has ended, destroy it */
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

/**
* Callback method for the command show rank
*/
public Action Command_ShowRank(int client, int args) {
	if (PluginDisabled()) {
		Notify(client, "Cannot execute command. Player stats is currently disabled.");
		return Plugin_Handled;
	}
	
	if (!IS_VALID_HUMAN(client)) {
		Error("Client '%N' is not valid. Skipping show rank", client);
		return Plugin_Handled;
	}
	
	char steamId[128];
	if (!GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId))) {
		Error("Unable to retrieve a valid steam id from client %N", client);
	}
	ShowPlayerRankPanel(client, steamId);
	return Plugin_Handled;
}

/**
* Display the rank/stats panel to the requesting player
*/
public void ShowPlayerRankPanel(int client, const char[] steamId) {
	//Check if a request is already in progress
	if (g_bShowingRankPanel[client]) {
		if (IS_VALID_HUMAN(client)) {
			Notify(client, "Your request is already being processed");
			return;
		}
	}
	
	if (!IS_VALID_HUMAN(client)) {
		Debug("Skipping display of rank panel for client %i. Not a valid human player", client);
		return;
	}
	
	char clientSteamId[128];
	
	if (GetClientAuthId(client, AuthId_Steam2, clientSteamId, sizeof(clientSteamId)) && StrEqual(clientSteamId, steamId)) {
		Info("Player '%N' is viewing his own rank", client);
	} else {
		Info("Player '%N' is viewing the rank of steam id '%s'", client, steamId);
	}
	
	int len = strlen(steamId) * 2 + 1;
	char[] qSteamId = new char[len];
	SQL_EscapeString(g_hDatabase, steamId, qSteamId, len);
	
	char query[512];
	
	if (ExtrasEnabled()) {
		FormatEx(query, sizeof(query), "select * from STATS_VW_PLAYER_RANKS_EXTRAS s WHERE s.steam_id = '%s'", qSteamId);
	} else {
		FormatEx(query, sizeof(query), "select * from STATS_VW_PLAYER_RANKS s WHERE s.steam_id = '%s'", qSteamId);
	}
	
	Debug("ShowPlayerRankPanel :: Executing Query: %s", query);
	
	g_bShowingRankPanel[client] = true;
	
	DataPack pack = new DataPack();
	pack.WriteString(steamId);
	pack.WriteCell(client);
	
	g_hDatabase.Query(TQ_ShowPlayerRankPanel, query, pack);
}

/**
* SQL Callback for Player Rank/Stats Panel.
*/
public void TQ_ShowPlayerRankPanel(Database db, DBResultSet results, const char[] error, DataPack pack) {
	pack.Reset();
	char selSteamId[64];
	pack.ReadString(selSteamId, sizeof(selSteamId));
	int clientId = pack.ReadCell();
	
	//Verify that the player is still connected to the server
	if (!IS_VALID_HUMAN(clientId)) {
		Debug("TQ_ShowPlayerRankPanel :: Client id %i is no longer valid (Player has probably left the server before the completion of this request)", clientId);
		g_bShowingRankPanel[clientId] = false;
		delete pack;
		return;
	}
	
	if (results == null) {
		Error("TQ_ShowPlayerRankPanel :: Query failed (Reason: %s)", error);
		g_bShowingRankPanel[clientId] = false;
	} else if (results.RowCount > 0) {
		StringMap map = new StringMap();
		
		if (results.FetchRow()) {
			//Extract basic stats
			ExtractPlayerStats(results, map);
			
			char steamId[128];
			int createDate;
			int lastJoinDate;
			
			//Retrieve general info
			map.GetString(STATS_STEAM_ID, steamId, sizeof(steamId));
			map.GetValue(STATS_LAST_JOIN_DATE, lastJoinDate);
			map.GetValue(STATS_CREATE_DATE, createDate);
			
			char msg[255];
			Panel panel = new Panel();
			if (!StringBlank(g_StatPanelTitlePlayer)) {
				panel.SetTitle(g_StatPanelTitlePlayer);
			}
			
			PanelDrawStatLineBreak(panel);
			
			PanelDrawStatLabelStr(panel, "名字", STATS_LAST_KNOWN_ALIAS, map, "\"", "\"");
			PanelDrawStatLabelInt(panel, "排名", STATS_RANK, map, "#");
			PanelDrawStatLabelFloat(panel, "积分", STATS_TOTAL_POINTS, map);
			
			PanelDrawStatLineBreak(panel);
			
			PanelDrawStatItem(panel, "幸存者");
			
			PanelDrawStat(panel, "击杀", STATS_INFECTED_KILLED, map);
			PanelDrawStat(panel, "爆头", STATS_INFECTED_HEADSHOT, map);
			
			PanelDrawStatLineBreak(panel);
			
			PanelDrawStatItem(panel, "感染者");
			
			PanelDrawStat(panel, "击杀", STATS_SURVIVOR_KILLED, map);
			PanelDrawStat(panel, "击倒", STATS_SURVIVOR_INCAPPED, map);
			
			PanelDrawStatLineBreak(panel); //line-break
			
			//If extra stats are enabled, display the menu item
			if (ExtrasEnabled()) {
				Format(msg, sizeof(msg), "更多");
				panel.DrawItem(msg, ITEMDRAW_DEFAULT);
				
				//Since there is no way to pass the steam id to the menu handler callback, 
				//we store the steam id to a global variable instead.. :/
				
				//Copy data to global variable
				strcopy(g_SelSteamIds[clientId], sizeof(g_SelSteamIds[]), selSteamId);
				
				Debug("TQ_ShowPlayerRankPanel :: Updated client %N's player selection = %s", clientId, g_SelSteamIds[clientId]);
			}
			
			panel.Send(clientId, PlayerStatsMenuHandler, g_iStatsMenuTimeout.IntValue);
		}
		
		g_bShowingRankPanel[clientId] = false;
		delete map;
	}
}

/**
* Menu Callback Handler for Show Player Rank panel
*/
public int PlayerStatsMenuHandler(Menu menu, MenuAction action, int client, int selectedIndex)
{
	//Verify that the player is still connected to the server
	if (!IS_VALID_HUMAN(client)) {
		Error("PlayerStatsMenuHandler :: Client id %i is no longer valid (Player has probably left the server before the completion of this request)", client);
		delete menu;
		return;
	}
	
	/* If an option was selected, tell the client about the item. */
	if (action == MenuAction_Select)
	{
		if (selectedIndex != 3) {
			Debug("Clearing selected steam id");
			strcopy(g_SelSteamIds[client], sizeof(g_SelSteamIds[]), "");
			return;
		}
		
		if (StringBlank(g_SelSteamIds[client])) {
			Error("PlayerStatsMenuHandler :: Unable to retrieve the selected steam id");
			delete menu;
			return;
		}
		
		Debug("Showing the extra stats panel to %N", client);
		ShowExtraStatsPanel(client, g_SelSteamIds[client]);
	}
	/* If the menu was cancelled, print a message to the server about it. */
	else if (action == MenuAction_Cancel)
	{
		Debug("Client %d's menu was cancelled.  Reason: %d", client, selectedIndex);
		strcopy(g_SelSteamIds[client], sizeof(g_SelSteamIds[]), "");
	}
	/* If the menu has ended, destroy it */
	else if (action == MenuAction_End)
	{
		Debug("PlayerStatsMenuHandler :: Cleaning up resources");
		delete menu;
	}
}

/**
* Display the extra statistics panel to the requesting user. Request is ignored if the feature is disabled.
*/
public void ShowExtraStatsPanel(int client, const char[] steamId) {
	if (!ExtrasEnabled()) {
		Error("Extra stats are currently disabled");
		return;
	}
	
	if (!IS_VALID_HUMAN(client)) {
		Debug("Skipping display of extra stats panel for client %i. Not a valid human player", client);
		return;
	}
	
	char clientSteamId[128];
	
	if (GetClientAuthId(client, AuthId_Steam2, clientSteamId, sizeof(clientSteamId)) && StrEqual(clientSteamId, steamId)) {
		Info("Player '%N' is viewing his extra stats", client);
	} else {
		Info("Player '%N' is viewing the extra stats of steam id '%s'", client, steamId);
	}
	
	int len = strlen(steamId) * 2 + 1;
	char[] qSteamId = new char[len];
	SQL_EscapeString(g_hDatabase, steamId, qSteamId, len);
	
	char query[512];
	FormatEx(query, sizeof(query), "select * from STATS_VW_PLAYER_RANKS_EXTRAS s WHERE s.steam_id = '%s'", qSteamId);
	
	g_hDatabase.Query(TQ_ShowExtraStatsPanel, query, client);
}

public void BuildGameInfoMap(StringMap & map) {
	if (map == null)
		return;
	
	char serverName[MAX_NAME_LENGTH];
	GetServerName(serverName, sizeof(serverName));
	
	//Set server name
	map.SetString(GAMEINFO_SERVER_NAME, serverName);
}

/**
* SQL Callback for Extra Player Rank/Stats Panel.
*/
public void TQ_ShowExtraStatsPanel(Database db, DBResultSet results, const char[] error, int client) {
	//Verify that the player is still connected to the server
	if (!IS_VALID_HUMAN(client)) {
		Error("TQ_ShowExtraStatsPanel :: Client id %i is no longer valid (Player has probably left the server before the completion of this request)", client);
		return;
	}
	
	if (results == null) {
		Error("TQ_ShowExtraStatsPanel :: Query failed! %s", error);
	} else if (results.RowCount > 0) {
		
		StringMap map = new StringMap();
		
		if (results.FetchRow()) {
			
			//Extract and store to map
			ExtractPlayerStats(results, map);
			ExtractPlayerStatsExtra(results, map);
			
			Panel panel = new Panel();
			
			panel.SetTitle(g_StatPanelTitleExtras);
			
			PanelDrawStatLineBreak(panel);
			
			PanelDrawStatLabelStr(panel, "名字", STATS_LAST_KNOWN_ALIAS, map, "\"", "\"");
			
			PanelDrawStatLineBreak(panel);
			
			PanelDrawStatItem(panel, "幸存者");
			
			PanelDrawStat(panel, "喷秒 Hunter", STATS_EXTRA_SURV_SKEET_HUNTER_SHOTGUN, map);
			PanelDrawStat(panel, "狙秒 Hunter", STATS_EXTRA_SURV_SKEET_HUNTER_SNIPER, map);
			PanelDrawStat(panel, "刀秒 Hunter", STATS_EXTRA_SURV_SKEET_HUNTER_MELEE, map);
			PanelDrawStat(panel, "打石头", STATS_EXTRA_SURV_SKEET_TANK_ROCK, map);
			PanelDrawStat(panel, "秒妹", STATS_EXTRA_SURV_WITCH_CROWN_STD, map);
			PanelDrawStat(panel, "引秒妹", STATS_EXTRA_SURV_WITCH_CROWN_DRAW, map);
			PanelDrawStat(panel, "推停胖子", STATS_EXTRA_SURV_BOOMER_POP, map);
			PanelDrawStat(panel, "近战秒牛", STATS_EXTRA_SURV_CHARGER_LEVEL, map);
			PanelDrawStat(panel, "刀舌头", STATS_EXTRA_SURV_SMOKER_TONGUE_CUT, map);
			PanelDrawStat(panel, "推停 Hunter", STATS_EXTRA_SURV_HUNTER_DEADSTOP, map);
			
			PanelDrawStatLineBreak(panel);
			
			PanelDrawStatItem(panel, "感染者");
			
			PanelDrawStat(panel, "胖子空投", STATS_EXTRA_SI_BOOMER_QUAD, map);
			PanelDrawStat(panel, "砸 25", STATS_EXTRA_SI_HUNTER_25, map);
			PanelDrawStat(panel, "冲锋秒人", STATS_EXTRA_SI_DEATHCHARGE, map);
			PanelDrawStat(panel, "投石命中", STATS_EXTRA_SI_TANK_ROCK_HITS, map);
			
			PanelDrawStatLineBreak(panel);
			
			panel.DrawItem("返回", ITEMDRAW_DEFAULT);
			
			panel.Send(client, ShowExtraStatsMenuHandler, g_iStatsMenuTimeout.IntValue);
			
			Debug("TQ_ShowExtraStatsPanel :: Successfully extracted all values");
		}
		
		delete map;
	}
}

public void PanelDrawStat(Panel & panel, const char[] label, const char[] statKey, StringMap & map) {
	int amount = 0;
	char msg[64];
	
	//extract value
	if (!map.GetValue(statKey, amount)) {
		Error("Could not retrieve value for stat '%s' from the map", statKey);
		Format(msg, sizeof(msg), " ☼ %s (无记录)", label);
		panel.DrawText(msg);
		return;
	}
	
	int displayType = g_iStatsDisplayType.IntValue;
	
	//apply points modifier
	float modifier = DEFAULT_POINT_MODIFIER;
	
	//retrieve modifier from global map (if available)
	if (!g_mStatModifiers.GetValue(statKey, modifier))
		Debug("No modifier found for stat '%s'. Default modifier will be used (%.2f).", statKey, DEFAULT_POINT_MODIFIER);
	
	float points = amount * modifier;
	
	//display both points and amount	
	if (displayType == STATS_DISPLAY_TYPE_BOTH) {
		Format(msg, sizeof(msg), "☼ %s (%i, %.2f)", label, amount, points);
	}
	//display points
	else if (displayType == STATS_DISPLAY_TYPE_POINTS) {
		Format(msg, sizeof(msg), "☼ %s (%.2f)", label, points);
	}
	//display amount
	else {
		Format(msg, sizeof(msg), "☼ %s (%i)", label, amount);
	}
	panel.DrawText(msg);
}

void PanelDrawStatLabelStr(Panel & panel, const char[] label, const char[] statKey, StringMap & map, const char[] valPrefix = "", const char[] valPostfix = "") {
	char msg[255];
	char valueStr[255];
	if (!map.GetString(statKey, valueStr, sizeof(valueStr))) {
		Error("PanelDrawStatLabelStr :: Key '%s' does not exist", statKey);
		return;
	}
	FormatEx(msg, sizeof(msg), "%s: %s%s%s", label, valPrefix, valueStr, valPostfix);
	panel.DrawText(msg);
}

void PanelDrawStatLabelInt(Panel & panel, const char[] label, const char[] statKey, StringMap & map, const char[] valPrefix = "", const char[] valPostfix = "") {
	char msg[255];
	int value;
	if (!map.GetValue(statKey, value)) {
		Error("PanelDrawStatLabelInt :: Key '%s' does not exist", statKey);
		return;
	}
	FormatEx(msg, sizeof(msg), "%s: %s%i%s", label, valPrefix, value, valPostfix);
	panel.DrawText(msg);
}

void PanelDrawStatLabelFloat(Panel & panel, const char[] label, const char[] statKey, StringMap & map, const char[] valPrefix = "", const char[] valPostfix = "") {
	char msg[255];
	float value;
	if (!map.GetValue(statKey, value)) {
		Error("PanelDrawStatLabelFloat :: Key '%s' does not exist", statKey);
		return;
	}
	FormatEx(msg, sizeof(msg), "%s: %s%.2f%s", label, valPrefix, value, valPostfix);
	panel.DrawText(msg);
}

void PanelDrawStatLineBreak(Panel & panel) {
	if (panel == null)
		return;
	panel.DrawText(" "); //line-break
}

void PanelDrawStatItem(Panel & panel, const char[] name, const char[] valPrefix = "", const char[] valPostfix = "") {
	char msg[255];
	Format(msg, sizeof(msg), "%s%s%s", valPrefix, name, valPostfix);
	panel.DrawItem(name, ITEMDRAW_DEFAULT);
}

/**
* Menu Callback Handler for ShowExtraStatsPanel panel
*/
public int ShowExtraStatsMenuHandler(Menu menu, MenuAction action, int client, int selectedIndex) {
	//Verify that the player is still connected to the server
	if (!IS_VALID_HUMAN(client)) {
		Error("ShowExtraStatsMenuHandler :: Client id %i is no longer valid (Player has probably left the server before the completion of this request)", client);
		return;
	}
	
	/* If an option was selected, tell the client about the item. */
	if (action == MenuAction_Select)
	{
		Debug("ShowExtraStatsMenuHandler :: Item selected: %i", selectedIndex);
		
		//Go Back
		if (selectedIndex == 3) {
			ShowPlayerRankPanel(client, g_SelSteamIds[client]);
		}
	}
	/* If the menu was cancelled, print a message to the server about it. */
	else if (action == MenuAction_Cancel)
	{
		Debug("Client %d's menu was cancelled.  Reason: %d", client, selectedIndex);
		strcopy(g_SelSteamIds[client], sizeof(g_SelSteamIds[]), "");
	}
	/* If the menu has ended, destroy it */
	else if (action == MenuAction_End)
	{
		Debug("Menu has ended");
		delete menu;
		strcopy(g_SelSteamIds[client], sizeof(g_SelSteamIds[]), "");
	}
}

/**
* Helper function for extracting a single row of player statistic from the result set and store it on a map
* 
* @return true if the extraction was succesful from the result set, otherwise false if the extraction failed.
*/
public void ExtractPlayerStats(DBResultSet & results, StringMap & map) {
	if (results == null || map == null) {
		Debug("ExtractPlayerStats :: results or map is null");
		return;
	}
	
	int idxSteamId = -1;
	int idxLastKnownAlias = -1;
	int idxLastJoinDate = -1;
	int idxSurvivorsKilled = -1;
	int idxSurvivorsIncapped = -1;
	int idxInfectedKilled = -1;
	int idxInfectedHeadshot = -1;
	int idxTotalPoints = -1;
	int idxPlayerRank = -1;
	int idxCreateDate = -1;
	
	//Retrieve field indices
	results.FieldNameToNum(STATS_STEAM_ID, idxSteamId);
	results.FieldNameToNum(STATS_LAST_KNOWN_ALIAS, idxLastKnownAlias);
	results.FieldNameToNum(STATS_LAST_JOIN_DATE, idxLastJoinDate);
	results.FieldNameToNum(STATS_SURVIVOR_KILLED, idxSurvivorsKilled);
	results.FieldNameToNum(STATS_SURVIVOR_INCAPPED, idxSurvivorsIncapped);
	results.FieldNameToNum(STATS_INFECTED_KILLED, idxInfectedKilled);
	results.FieldNameToNum(STATS_INFECTED_HEADSHOT, idxInfectedHeadshot);
	results.FieldNameToNum(STATS_TOTAL_POINTS, idxTotalPoints);
	results.FieldNameToNum(STATS_RANK, idxPlayerRank);
	results.FieldNameToNum(STATS_CREATE_DATE, idxCreateDate);
	
	//Fetch values
	char steamId[128];
	char lastKnownAlias[255];
	int lastJoinDate = 0;
	float totalPoints = 0.0;
	int rankNum = -1;
	
	//Basic Stats
	int survivorsKilled = 0;
	int survivorsIncapped = 0;
	int infectedKilled = 0;
	int infectedHeadshot = 0;
	int createDate = 0;
	
	//Fetch general info
	results.FetchString(idxSteamId, steamId, sizeof(steamId));
	results.FetchString(idxLastKnownAlias, lastKnownAlias, sizeof(lastKnownAlias));
	lastJoinDate = results.FetchInt(idxLastJoinDate);
	createDate = results.FetchInt(idxCreateDate);
	totalPoints = results.FetchFloat(idxTotalPoints);
	rankNum = results.FetchInt(idxPlayerRank);
	
	//Fetch basic stats
	survivorsKilled = results.FetchInt(idxSurvivorsKilled);
	survivorsIncapped = results.FetchInt(idxSurvivorsIncapped);
	infectedKilled = results.FetchInt(idxInfectedKilled);
	infectedHeadshot = results.FetchInt(idxInfectedHeadshot);
	createDate = results.FetchInt(idxCreateDate);
	
	map.SetString(STATS_STEAM_ID, steamId, true);
	map.SetString(STATS_LAST_KNOWN_ALIAS, lastKnownAlias, true);
	map.SetValue(STATS_LAST_JOIN_DATE, lastJoinDate, true);
	map.SetValue(STATS_TOTAL_POINTS, totalPoints, true);
	map.SetValue(STATS_RANK, rankNum, true);
	map.SetValue(STATS_SURVIVOR_KILLED, survivorsKilled, true);
	map.SetValue(STATS_SURVIVOR_INCAPPED, survivorsIncapped, true);
	map.SetValue(STATS_INFECTED_KILLED, infectedKilled, true);
	map.SetValue(STATS_INFECTED_HEADSHOT, infectedHeadshot, true);
	map.SetValue(STATS_CREATE_DATE, createDate, true);
}

/**
* Extract player stats including the extras from the result set and store it into the provided map
*/
public void ExtractPlayerStatsExtra(DBResultSet & results, StringMap & map) {
	if (results == null || map == null) {
		Debug("ExtractPlayerStats :: results or map is null");
		return;
	}
	
	int idxSkeetHunterSniper = -1;
	int idxSkeetHunterShotgun = -1;
	int idxSkeetHunterMelee = -1;
	int idxSkeetTankRock = -1;
	int idxWitchCrownStandard = -1;
	int idxWitchCrownDraw = -1;
	int idxBoomerPop = -1;
	int idxChargerLevel = -1;
	int idxSmokerTongueCut = -1;
	int idxHunterDeadStop = -1;
	int idxBoomerQuad = -1;
	int idxHunterTwentyFive = -1;
	int idxDeathCharge = -1;
	int idxTankRockHits = -1;
	
	bool success = true;
	
	success &= results.FieldNameToNum(STATS_EXTRA_SURV_SKEET_HUNTER_SNIPER, idxSkeetHunterSniper);
	success &= results.FieldNameToNum(STATS_EXTRA_SURV_SKEET_HUNTER_SHOTGUN, idxSkeetHunterShotgun);
	success &= results.FieldNameToNum(STATS_EXTRA_SURV_SKEET_HUNTER_MELEE, idxSkeetHunterMelee);
	success &= results.FieldNameToNum(STATS_EXTRA_SURV_SKEET_TANK_ROCK, idxSkeetTankRock);
	success &= results.FieldNameToNum(STATS_EXTRA_SURV_WITCH_CROWN_STD, idxWitchCrownStandard);
	success &= results.FieldNameToNum(STATS_EXTRA_SURV_WITCH_CROWN_DRAW, idxWitchCrownDraw);
	success &= results.FieldNameToNum(STATS_EXTRA_SURV_BOOMER_POP, idxBoomerPop);
	success &= results.FieldNameToNum(STATS_EXTRA_SURV_CHARGER_LEVEL, idxChargerLevel);
	success &= results.FieldNameToNum(STATS_EXTRA_SURV_SMOKER_TONGUE_CUT, idxSmokerTongueCut);
	success &= results.FieldNameToNum(STATS_EXTRA_SURV_HUNTER_DEADSTOP, idxHunterDeadStop);
	success &= results.FieldNameToNum(STATS_EXTRA_SI_BOOMER_QUAD, idxBoomerQuad);
	success &= results.FieldNameToNum(STATS_EXTRA_SI_HUNTER_25, idxHunterTwentyFive);
	success &= results.FieldNameToNum(STATS_EXTRA_SI_DEATHCHARGE, idxDeathCharge);
	success &= results.FieldNameToNum(STATS_EXTRA_SI_TANK_ROCK_HITS, idxTankRockHits);
	
	if (!success) {
		Error("There was a problem retrieving one of the field names from the result set");
		return;
	}
	
	map.SetValue(STATS_EXTRA_SURV_SKEET_HUNTER_SNIPER, results.FetchInt(idxSkeetHunterSniper));
	map.SetValue(STATS_EXTRA_SURV_SKEET_HUNTER_SHOTGUN, results.FetchInt(idxSkeetHunterShotgun));
	map.SetValue(STATS_EXTRA_SURV_SKEET_HUNTER_MELEE, results.FetchInt(idxSkeetHunterMelee));
	map.SetValue(STATS_EXTRA_SURV_SKEET_TANK_ROCK, results.FetchInt(idxSkeetTankRock));
	map.SetValue(STATS_EXTRA_SURV_WITCH_CROWN_STD, results.FetchInt(idxWitchCrownStandard));
	map.SetValue(STATS_EXTRA_SURV_WITCH_CROWN_DRAW, results.FetchInt(idxWitchCrownDraw));
	map.SetValue(STATS_EXTRA_SURV_BOOMER_POP, results.FetchInt(idxBoomerPop));
	map.SetValue(STATS_EXTRA_SURV_CHARGER_LEVEL, results.FetchInt(idxChargerLevel));
	map.SetValue(STATS_EXTRA_SURV_SMOKER_TONGUE_CUT, results.FetchInt(idxSmokerTongueCut));
	map.SetValue(STATS_EXTRA_SURV_HUNTER_DEADSTOP, results.FetchInt(idxHunterDeadStop));
	map.SetValue(STATS_EXTRA_SI_BOOMER_QUAD, results.FetchInt(idxBoomerQuad));
	map.SetValue(STATS_EXTRA_SI_HUNTER_25, results.FetchInt(idxHunterTwentyFive));
	map.SetValue(STATS_EXTRA_SI_DEATHCHARGE, results.FetchInt(idxDeathCharge));
	map.SetValue(STATS_EXTRA_SI_TANK_ROCK_HITS, results.FetchInt(idxTankRockHits));
}

/**
* Returns the number of human players currently in the server (including spectators)
*/
int GetHumanPlayerCount(bool includeSpec = true) {
	int count = 0;
	for (int i = 1; i <= MAX_CLIENTS; i++) {
		if (includeSpec) {
			if (IS_VALID_HUMAN(i))
				count++;
		} else {
			if (IS_VALID_HUMAN(i) && (IS_VALID_SURVIVOR(i) || IS_VALID_INFECTED(i)))
				count++;
		}
	}
	return count;
}

/**
* Returns the number of human players on the survivor team
*/
int GetHumanSurvivorCount() {
	int count = 0;
	for (int i = 1; i <= MAX_CLIENTS; i++) {
		if (IS_VALID_HUMAN(i) && IS_VALID_SURVIVOR(i))
			count++;
	}
	return count;
}

/**
* Iterates and initialize all available players on the server
*/
public void InitializePlayers() {
	for (int i = 1; i <= MAX_CLIENTS; i++)
	{
		if (IS_VALID_HUMAN(i))
		{
			if (IsClientConnected(i) && isInitialized(i)) {
				Debug("Client '%N' is already initialized. Skipping process.", i);
				continue;
			}
			Debug("%i) Initialize %N", i, i);
			InitializePlayer(i, false);
		}
	}
}

/**
* Initialize a player record if not yet existing
*
* @param client The client index to initialize
*/
public void InitializePlayer(int client, bool updateJoinDateIfExists) {
	Debug("Initializing Client %N", client);
	
	if (!IS_VALID_CLIENT(client) || IsFakeClient(client)) {
		Debug("InitializePlayer :: Client index %i is not valid. Skipping Initialization", client);
		return;
	}
	
	if (g_bInitializing[client]) {
		Debug("InitializePlayer :: Initialization for '%N' is already in-progress. Please wait.", client);
		return;
	}
	
	char steamId[255];
	if (!GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId))) {
		g_bInitializing[client] = false;
		g_bPlayerInitialized[client] = false;
		Error("Could not initialize player '%N'. Invalid steam id (%s)", client, steamId);
		return;
	}
	
	char name[255];
	GetClientName(client, name, sizeof(name));
	
	//unnecessary? 
	int len = strlen(steamId) * 2 + 1;
	char[] qSteamId = new char[len];
	SQL_EscapeString(g_hDatabase, steamId, qSteamId, len);
	
	len = strlen(name) * 2 + 1;
	char[] qName = new char[len];
	SQL_EscapeString(g_hDatabase, name, qName, len);
	
	char query[512];
	
	if (updateJoinDateIfExists) {
		Debug("InitializePlayer :: Join date will be updated for %N", client);
		FormatEx(query, sizeof(query), "INSERT INTO STATS_PLAYERS (steam_id, last_known_alias, last_join_date) VALUES ('%s', '%s', CURRENT_TIMESTAMP()) ON DUPLICATE KEY UPDATE last_join_date = CURRENT_TIMESTAMP(), last_known_alias = '%s'", qSteamId, qName, qName);
	}
	else {
		Debug("InitializePlayer :: Join date will NOT be updated for %N", client);
		FormatEx(query, sizeof(query), "INSERT INTO STATS_PLAYERS (steam_id, last_known_alias, last_join_date) VALUES ('%s', '%s', CURRENT_TIMESTAMP()) ON DUPLICATE KEY UPDATE last_known_alias = '%s'", qSteamId, qName, qName);
	}
	
	g_bInitializing[client] = true;
	g_hDatabase.Query(TQ_InitializePlayer, query, client);
}

/**
* SQL Callback for InitializePlayer threaded query
*/
public void TQ_InitializePlayer(Database db, DBResultSet results, const char[] error, any data) {
	int client = data;
	
	if (!IS_VALID_CLIENT(client) || !IsClientConnected(client)) {
		Debug("TQ_InitializePlayer :: Client %N (%i) is not valid or not connected. Skipping initialization", client, client);
		g_bInitializing[client] = false;
		g_bPlayerInitialized[client] = false;
		return;
	}
	
	if (results == null) {
		Error("TQ_InitializePlayer :: Query failed (Reason: %s)", error);
		g_bPlayerInitialized[client] = false;
		g_bInitializing[client] = false;
		return;
	}
	
	if (results.AffectedRows == 0) {
		Debug("TQ_InitializePlayer :: Nothing was updated for player %N", client);
	}
	else if (results.AffectedRows == 1) {
		Debug("TQ_InitializePlayer :: Player %N has been initialized for the first time", client);
	}
	else if (results.AffectedRows > 1) {
		Debug("TQ_InitializePlayer :: Existing record has been updated for player %N", client);
	}
	
	g_bPlayerInitialized[client] = true;
	g_bInitializing[client] = false;
	
	Debug("Player '%N' successfully initialized", client);
}

/**
* Connect to the database
* 
* @return true if the connection is successful
*/
bool DbConnect(bool force = false)
{
	if (g_hDatabase != INVALID_HANDLE) {
		if (!force) {
			Debug("DbConnect() :: Already connected to the database, skipping.");
			return true;
		}
		delete g_hDatabase;
	}
	if (SQL_CheckConfig(DB_CONFIG_NAME)) {
		char error[512];
		g_hDatabase = SQL_Connect(DB_CONFIG_NAME, true, error, sizeof(error));
		if (g_hDatabase != INVALID_HANDLE) {
			LogMessage("Connected to the database: %s", DB_CONFIG_NAME);
			return true;
		} else {
			Error("Failed to connect to database: %s", error);
		}
	}
	return false;
}

/**
* Initialize database (create tables/indices etc)
*
* @return true if the initialization is successfull
*/
public bool InitDatabase() {
	if (!DbConnect()) {
		Error("InitDatabase :: Unable to retrieve database handle");
		return false;
	}
	return true;
}

/**
* Method to trigger the Player Connect Announcement in Chat
*/
public void PlayerConnectAnnounce(int client) {
	
	if (PluginDisabled() || !CAnnounceEnabled()) {
		Debug("Skipping connect announce for client '%N'. Either plugin has been disabled (pstats_enabled = 0) or Connect Announce Feature is.", client);
		return;
	}
	
	if (!IS_VALID_CLIENT(client) || IsFakeClient(client) || !IsClientAuthorized(client)) {
		Debug("PlayerConnectAnnounce() :: Skipping connect announce for %N", client);
		return;
	}
	
	char steamId[128];
	if (!GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId))) {
		Error("PlayerConnectAnnounce :: Unable to retrieve steam id for client %N", client);
		return;
	}
	
	int len = strlen(steamId) * 2 + 1;
	char[] qSteamId = new char[len];
	SQL_EscapeString(g_hDatabase, steamId, qSteamId, len);
	
	char query[512];
	
	if (ExtrasEnabled()) {
		FormatEx(query, sizeof(query), "select * from STATS_VW_PLAYER_RANKS_EXTRAS s WHERE s.steam_id = '%s'", qSteamId);
	} else {
		FormatEx(query, sizeof(query), "select * from STATS_VW_PLAYER_RANKS s WHERE s.steam_id = '%s'", qSteamId);
	}
	
	Debug("Executing Query: %s", query);
	
	g_hDatabase.Query(TQ_PlayerConnectAnnounce, query, client);
}

/**
* SQL callback for the Player Connect Announcement
*/
public void TQ_PlayerConnectAnnounce(Database db, DBResultSet results, const char[] error, any data) {
	
	/* Make sure the client didn't disconnect while the thread was running */
	if (!IS_VALID_CLIENT(data)) {
		Debug("Client '%i' is not a valid client index, skipping display stats", data);
		return;
	}
	
	if (results == null) {
		Error("TQ_PlayerConnectAnnounce :: Query failed (Reason: %s)", error);
	} else if (results.RowCount > 0) {
		
		StringMap map = new StringMap();
		
		if (results.FetchRow()) {
			
			//Extract results to map
			ExtractPlayerStats(results, map);
			
			char steamId[128];
			char lastKnownAlias[255];
			int createDate;
			int lastJoinDate;
			float totalPoints;
			int rankNum;
			int survivorsKilled;
			int survivorsIncapped;
			int infectedKilled;
			int infectedHeadshot;
			
			map.GetString(STATS_STEAM_ID, steamId, sizeof(steamId));
			map.GetString(STATS_LAST_KNOWN_ALIAS, lastKnownAlias, sizeof(lastKnownAlias));
			map.GetValue(STATS_LAST_JOIN_DATE, lastJoinDate);
			map.GetValue(STATS_TOTAL_POINTS, totalPoints);
			map.GetValue(STATS_RANK, rankNum);
			map.GetValue(STATS_SURVIVOR_KILLED, survivorsKilled);
			map.GetValue(STATS_SURVIVOR_INCAPPED, survivorsIncapped);
			map.GetValue(STATS_INFECTED_KILLED, infectedKilled);
			map.GetValue(STATS_INFECTED_HEADSHOT, infectedHeadshot);
			map.GetValue(STATS_CREATE_DATE, createDate);
			
			char tmpMsg[253];
			
			//parse stats
			ParseKeywordsWithMap(g_ConfigAnnounceFormat, tmpMsg, sizeof(tmpMsg), map);
			Debug("PARSE RESULT = %s", tmpMsg);
			
			Client_PrintToChatAll(true, tmpMsg);
			
			Debug("'%N' has joined the game (Id: %s, Points: %f, Rank: %i, Last Known Alias: %s)", data, steamId, totalPoints, rankNum, lastKnownAlias);
		}
		
		delete map;
	}
}

/**
* Parse keywords within the text and replace with values associated in the map
* 
* @param text The text to parse
* @param buffer The buffer to store the output
* @param size The size of the output buffer
* @param map The StringMap containing the key/value pairs that will be used for the lookup and replacement
*/
public void ParseKeywordsWithMap(const char[] text, char[] buffer, int size, StringMap & map) {
	Debug("======================================================= PARSE START =======================================================");
	
	Debug("Parsing stats string : \"%s\"", text);
	
	StringMapSnapshot keys = map.Snapshot();
	
	//Copy content
	FormatEx(buffer, size, "%s", g_ConfigAnnounceFormat);
	
	//iterate through all available keys in the map
	for (int i = 0; i < keys.Length; i++) {
		int bufferSize = keys.KeyBufferSize(i);
		char[] keyName = new char[bufferSize];
		keys.GetKey(i, keyName, bufferSize);
		
		int searchKeySize = bufferSize + 32;
		
		//There are probably simpler and more effective ways on doing this but i'm too lazy :)
		
		//Standard search key
		char[] searchKey = new char[searchKeySize];
		FormatEx(searchKey, searchKeySize, "{%s}", keyName);
		
		//Float search key
		char[] searchKeyFloat = new char[searchKeySize];
		FormatEx(searchKeyFloat, searchKeySize, "{f:%s}", keyName);
		
		//Int search key
		char[] searchKeyInt = new char[searchKeySize];
		FormatEx(searchKeyInt, searchKeySize, "{i:%s}", keyName);
		
		//Date search key
		char[] searchKeyDate = new char[searchKeySize];
		FormatEx(searchKeyDate, searchKeySize, "{d:%s}", keyName);
		
		char[] sKey = new char[searchKeySize];
		
		int pos = -1;
		
		char valueStr[128];
		
		bool found = false;
		
		//If we find the key, then replace it with the actual value
		if ((pos = StrContains(g_ConfigAnnounceFormat, searchKey, false)) > -1) {
			//Try extract string		
			map.GetString(keyName, valueStr, sizeof(valueStr));
			Debug("(%i: %s) Key '%s' FOUND at position %i (value = %s, type = string)", i, keyName, searchKey, pos, valueStr);
			FormatEx(sKey, searchKeySize, searchKey);
			found = true;
		} else if ((pos = StrContains(g_ConfigAnnounceFormat, searchKeyFloat, false)) > -1) {
			float valueFloat;
			map.GetValue(keyName, valueFloat);
			FormatEx(valueStr, sizeof(valueStr), "%.2f", valueFloat);
			FormatEx(sKey, searchKeySize, searchKeyFloat);
			Debug("(%i: %s) Key '%s' FOUND at position %i (value = %s, type = float)", i, keyName, sKey, pos, valueStr);
			found = true;
		} else if ((pos = StrContains(g_ConfigAnnounceFormat, searchKeyInt, false)) > -1) {
			int valueInt;
			map.GetValue(keyName, valueInt);
			FormatEx(valueStr, sizeof(valueStr), "%i", valueInt);
			FormatEx(sKey, searchKeySize, searchKeyInt);
			Debug("(%i: %s) Key '%s' FOUND at position %i (value = %s, type = integer)", i, keyName, sKey, pos, valueStr);
			found = true;
		}
		else if ((pos = StrContains(g_ConfigAnnounceFormat, searchKeyDate, false)) > -1) {
			int valueInt;
			map.GetValue(keyName, valueInt);
			FormatEx(sKey, searchKeySize, searchKeyDate);
			FormatTime(valueStr, sizeof(valueStr), NULL_STRING, valueInt);
			Debug("(%i: %s) Key '%s' FOUND at position %i (value = %s (%i), type = date)", i, keyName, sKey, pos, valueStr, valueInt);
			found = true;
		}
		else {
			Debug("(%i: %s) Key '%s' NOT FOUND", i, keyName, searchKey);
			Format(valueStr, sizeof(valueStr), "N/A");
		}
		
		if (!found) {
			continue;
		}
		//Perform the replacement
		//Debug("\tReplacing key '%s' with value '%s'", sKey, valueStr);
		ReplaceString(buffer, size, sKey, valueStr, false);
	}
	
	Debug("======================================================= PARSE END =======================================================");
}

public Action Event_OnRoundStart(Event event, const char[] name, bool dontBroadcast) {
	Debug("================================== OnRoundStart ==================================");
	return Plugin_Continue;
}

public Action Event_OnRoundEnd(Event event, const char[] name, bool dontBroadcast) {
	Debug("================================== OnRoundEnd ==================================");
	return Plugin_Continue;
}

public Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast) {
	char playerName[MAX_NAME_LENGTH];
	int userId = event.GetInt("userid");
	int clientId = GetClientOfUserId(userId);
	int newTeamId = event.GetInt("team");
	int oldTeamId = event.GetInt("oldteam");
	bool disconnect = event.GetBool("disconnect");
	bool isBot = event.GetBool("isbot");
	event.GetString("name", playerName, sizeof(playerName));
	
	//Only display the rank panel if the player has completed transitioning to a team
	if (IS_VALID_CLIENT(clientId) && !isBot) {
		Debug("Player %N has joined a team (old team = %i, new team = %i, disconnect = %i, bot = %i)", clientId, oldTeamId, newTeamId, disconnect, isBot);
		if (ShowRankOnConnect() && !PlayerRankShown(clientId) && IS_VALID_HUMAN(clientId)) {
			char steamId[MAX_STEAMAUTH_LENGTH];
			if (GetClientAuthId(clientId, AuthId_Steam2, steamId, sizeof(steamId))) {
				Debug("Displaying player rank to user %N", clientId);
				ShowPlayerRankPanel(clientId, steamId);
				SetPlayerRankShownFlag(clientId);
			} else {
				Error("Could not obtain steam id of client %N", clientId);
			}
		} else {
			Debug("Will not display player rank panel to client %N", clientId);
		}
	}
	
	return Plugin_Continue;
}

void ResetShowPlayerRankFlags() {
	Debug("Resetting Player Rank Shown Flags");
	for (int i = 0; i < sizeof(g_bPlayerRankShown); i++) {
		UnsetPlayerRankShownFlag(i);
	}
}

bool PlayerRankShown(int clientId) {
	return g_bPlayerRankShown[clientId];
}

void SetPlayerRankShownFlag(int clientId) {
	if (!IS_VALID_HUMAN(clientId))
		return;
	Debug("Setting Player Rank Shown Flags for client %N", clientId);
	g_bPlayerRankShown[clientId] = true;
}

void UnsetPlayerRankShownFlag(int clientId) {
	//Debug("> Unsetting Player Rank Shown Flag for Client Index: %i", clientId);
	g_bPlayerRankShown[clientId] = false;
}

/**
* Callback for player_incapped event. Records basic stats only.
*/
public Action Event_PlayerIncapped(Event event, const char[] name, bool dontBroadcast) {
	int victimId = event.GetInt("userid");
	int attackerId = event.GetInt("attacker");
	int attackerClientId = GetClientOfUserId(attackerId);
	int victimClientId = GetClientOfUserId(victimId);
	
	if (!IS_HUMAN_INFECTED(attackerClientId)) {
		return Plugin_Continue;
	}
	
	if (!RecordBots() && !IS_HUMAN_SURVIVOR(victimClientId)) {
		Debug("Skipping stat update '%s' for %N. Victim is a bot", STATS_SURVIVOR_INCAPPED, attackerClientId);
		return Plugin_Continue;
	}
	
	UpdateStat(attackerClientId, STATS_SURVIVOR_INCAPPED, 1);
	
	return Plugin_Continue;
}

/**
* Callback for witch death events. Records basic stats only
*/
public Action Event_WitchKilled(Event event, const char[] name, bool dontBroadcast) {
	int attackerId = event.GetInt("userid");
	int attackerClientId = GetClientOfUserId(attackerId);
	//int witchId = event.GetInt("witchid");
	//bool oneShot = event.GetBool("oneshot");
	
	//We will only process valid human survivor players
	if (!IS_HUMAN_SURVIVOR(attackerClientId)) {
		return Plugin_Continue;
	}
	
	if (!AllowCollectStats()) {
		return Plugin_Continue;
	}
	
	/*char entityClassName[64];
	Entity_GetClassName(witchId, entityClassName, sizeof(entityClassName));*/
	
	UpdateStat(attackerClientId, STATS_INFECTED_KILLED, 1);
	
	return Plugin_Continue;
}

/**
* Callback for player_death event. This records basic stats only (kills and headshots).
*/
public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int victimId = event.GetInt("userid");
	int attackerId = event.GetInt("attacker");
	int attackerClientId = GetClientOfUserId(attackerId);
	int victimClientId = GetClientOfUserId(victimId);
	//int entityId = event.GetInt("entityid");
	bool headshot = event.GetBool("headshot");
	bool attackerIsBot = event.GetBool("attackerisbot");
	bool victimIsBot = event.GetBool("victimisbot");
	
	if (IS_VALID_CLIENT(attackerClientId) && !attackerIsBot) {
		if (!AllowCollectStats())
			return Plugin_Continue;
		
		if (!RecordBots() && victimIsBot) {
			if (DebugEnabled()) {
				if (headshot) {
					Debug("Skipping stat update '%s' for attacker %N. Victim '%N' is a bot", STATS_INFECTED_HEADSHOT, attackerClientId, victimClientId);
				} else {
					Debug("Skipping stat update '%s' for attacker %N. Victim '%N' is a bot", STATS_INFECTED_KILLED, attackerClientId, victimClientId);
				}
			}
			return Plugin_Continue;
		}
		
		//survivor killed infected
		if (IS_VALID_SURVIVOR(attackerClientId) && IS_VALID_INFECTED(victimClientId)) {
			if (headshot) {
				UpdateStat(attackerClientId, STATS_INFECTED_HEADSHOT, 1);
			}
			UpdateStat(attackerClientId, STATS_INFECTED_KILLED, 1);
		}
		//infected killed survivor
		else if (IS_VALID_INFECTED(attackerClientId) && IS_VALID_SURVIVOR(victimClientId)) {
			UpdateStat(attackerClientId, STATS_SURVIVOR_KILLED, 1);
		} //ignore the rest
	}
	return Plugin_Continue;
}

/**
* Utility function for updating the stat field of the player
*/
public void UpdateStat(int client, const char[] column, int amount) {
	if (!AllowCollectStats()) {
		return;
	}
	
	bool isExtra = IsExtraStat(column);
	
	if (isExtra && !ExtrasEnabled()) {
		Debug("Skipping stat update for '%s'. Feature is disabled.", column);
		return;
	}
	
	if (!IS_VALID_HUMAN(client)) {
		Error("Skipping update stat '%s'. Client is not valid: %N", column, client);
		return;
	}
	
	if (!isInitialized(client)) {
		Error("Skipping update stat '%s'. Client is not initialized %N", column, client);
		return;
	}
	
	char steamId[255];
	if (!GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId))) {
		Error("UpdateStat :: Invalid steam id for %N = %s. Skipping stat update '%s'", client, steamId, column);
		return;
	}
	
	char name[255];
	GetClientName(client, name, sizeof(name));
	
	int len = strlen(steamId) * 2 + 1;
	char[] qSteamId = new char[len];
	SQL_EscapeString(g_hDatabase, steamId, qSteamId, len);
	
	len = strlen(column) * 2 + 1;
	char[] qColumnName = new char[len];
	SQL_EscapeString(g_hDatabase, column, qColumnName, len);
	
	len = strlen(name) * 2 + 1;
	char[] qName = new char[len];
	SQL_EscapeString(g_hDatabase, name, qName, len);
	
	char query[255];
	FormatEx(query, sizeof(query), "UPDATE STATS_PLAYERS SET %s = %s + %i, last_known_alias = '%s' WHERE steam_id = '%s'", qColumnName, qColumnName, amount, qName, qSteamId);
	
	DataPack pack = new DataPack();
	pack.WriteString(column);
	pack.WriteCell(client);
	pack.WriteCell(amount);
	
	g_hDatabase.Query(TQ_UpdateStat, query, pack);
}

public void TQ_UpdateStat(Database db, DBResultSet results, const char[] error, any data) {
	if (results == null) {
		Error("TQ_UpdateStat :: Query failed (Reason: %s)", error);
		return;
	}
	
	DataPack pack = data;
	char column[128];
	
	pack.Reset();
	pack.ReadString(column, sizeof(column));
	int clientId = pack.ReadCell();
	int points = pack.ReadCell();
	
	if (results.AffectedRows > 0) {
		Debug("Stat '%s' updated for %N (Points: %i)", column, clientId, points);
	}
	else {
		Debug("Stat '%s' not updated for %N (Points: %i)", column, clientId, points);
	}
	
	delete pack;
}

public void PrintSqlVersion() {
	DBResultSet tmpQuery = SQL_Query(g_hDatabase, "select VERSION()");
	if (tmpQuery == null)
	{
		char error[255];
		SQL_GetError(g_hDatabase, error, sizeof(error));
		Debug("Failed to query (error: %s)", error);
	}
	else
	{
		if (SQL_FetchRow(tmpQuery)) {
			char version[255];
			SQL_FetchString(tmpQuery, 0, version, sizeof(version));
			Debug("SQL DB VERSION: %s", version);
		}
		/* Free the Handle */
		delete tmpQuery;
	}
}

/*********************** START: SKILL DETECTION *********************/

// START OF SURVIVOR SKILLS

public void OnBoomerPop(int survivor, int victim, int shoveCount, float timeAlive) {
	if (!ExtrasEnabled()) {
		Debug("Stat 'OnBoomerPop' is skipped. Extra stat recording is disabled");
		return;
	}
	
	if (!IS_HUMAN_SURVIVOR(survivor)) {
		Debug("Skipping stat update '%s'. Survivor is a bot", STATS_EXTRA_SURV_BOOMER_POP);
		return;
	}
	
	//If record bots is 0 and victim is a BOT, do not proceed
	if (!RecordBots() && !IS_HUMAN_INFECTED(victim)) {
		Debug("Skipping stat update '%s' for %N. Victim is a bot", STATS_EXTRA_SURV_BOOMER_POP, survivor);
		return;
	}
	
	Debug("Boomer has been popped (Attacker: %N, Victim: %N)", survivor, victim);
	UpdateStat(survivor, STATS_EXTRA_SURV_BOOMER_POP, 1);
}

public void OnSkeet(int survivor, int hunter) {
	if (!ExtrasEnabled()) {
		Debug("Stat 'OnSkeet' is skipped. Extra stat recording is disabled");
		return;
	}
	
	if (!IS_HUMAN_SURVIVOR(survivor)) {
		Debug("Skipping stat update '%s'. Survivor is a bot", STATS_EXTRA_SURV_SKEET_HUNTER_SHOTGUN);
		return;
	}
	
	//If record bots is 0 and victim is a BOT, do not proceed
	if (!RecordBots() && !IS_HUMAN_INFECTED(hunter)) {
		Debug("Skipping stat update '%s' for %N. Victim is a bot", STATS_EXTRA_SURV_SKEET_HUNTER_SHOTGUN, survivor);
		return;
	}
	
	Debug("Hunter has been skeeted (Attacker: %N, Victim: %N)", survivor, hunter);
	UpdateStat(survivor, STATS_EXTRA_SURV_SKEET_HUNTER_SHOTGUN, 1);
}

public void OnSkeetMelee(int survivor, int hunter) {
	if (!ExtrasEnabled()) {
		Debug("Stat 'OnSkeetMelee' is skipped. Extra stat recording is disabled");
		return;
	}
	
	if (!IS_HUMAN_SURVIVOR(survivor)) {
		Debug("Skipping stat update '%s'. Survivor is a bot", STATS_EXTRA_SURV_SKEET_HUNTER_MELEE);
		return;
	}
	
	//If record bots is 0 and victim is a BOT, do not proceed
	if (!RecordBots() && !IS_HUMAN_INFECTED(hunter)) {
		Debug("Skipping stat update '%s' for %N. Victim is a bot", STATS_EXTRA_SURV_SKEET_HUNTER_MELEE, survivor);
		return;
	}
	
	Debug("Hunter has been MELEE skeeted (Attacker: %N, Victim: %N)", survivor, hunter);
	UpdateStat(survivor, STATS_EXTRA_SURV_SKEET_HUNTER_MELEE, 1);
}

public void OnSkeetSniper(int survivor, int hunter, int damage, bool isOverkill) {
	if (!ExtrasEnabled()) {
		Debug("Stat 'OnSkeetSniper' is skipped. Extra stat recording is disabled");
		return;
	}
	
	if (!IS_HUMAN_SURVIVOR(survivor)) {
		Debug("Skipping stat update '%s'. Survivor is a bot", STATS_EXTRA_SURV_SKEET_HUNTER_SNIPER);
		return;
	}
	
	//If record bots is 0 and victim is a BOT, do not proceed
	if (!RecordBots() && !IS_HUMAN_INFECTED(hunter)) {
		Debug("Skipping stat update '%s' for %N. Victim is a bot", STATS_EXTRA_SURV_SKEET_HUNTER_SNIPER, survivor);
		return;
	}
	
	Debug("%N sniper skeeted %N (Damage: %i)", survivor, hunter, damage);
	UpdateStat(survivor, STATS_EXTRA_SURV_SKEET_HUNTER_SNIPER, 1);
}

public void OnChargerLevel(int survivor, int charger) {
	if (!ExtrasEnabled()) {
		Debug("Stat 'OnChargerLevel' is skipped. Extra stat recording is disabled");
		return;
	}
	
	if (!IS_HUMAN_SURVIVOR(survivor)) {
		Debug("Skipping stat update '%s'. Survivor is a bot", STATS_EXTRA_SURV_CHARGER_LEVEL);
		return;
	}
	
	//If record bots is 0 and victim is a BOT, do not proceed
	if (!RecordBots() && !IS_HUMAN_INFECTED(charger)) {
		Debug("Skipping stat update '%s' for %N. Victim is a bot", STATS_EXTRA_SURV_CHARGER_LEVEL, survivor);
		return;
	}
	
	Debug("%N has leveled %N", survivor, charger);
	UpdateStat(survivor, STATS_EXTRA_SURV_CHARGER_LEVEL, 1);
}

public void OnHunterDeadstop(int survivor, int hunter) {
	if (!ExtrasEnabled()) {
		Debug("Stat 'OnHunterDeadstop' is skipped. Extra stat recording is disabled");
		return;
	}
	
	if (!IS_HUMAN_SURVIVOR(survivor)) {
		Debug("Skipping stat update '%s'. Survivor is a bot", STATS_EXTRA_SURV_HUNTER_DEADSTOP);
		return;
	}
	
	//If record bots is 0 and victim is a BOT, do not proceed
	if (!RecordBots() && !IS_HUMAN_INFECTED(hunter)) {
		Debug("Skipping stat update '%s' for %N. Victim is a bot", STATS_EXTRA_SURV_HUNTER_DEADSTOP, survivor);
		return;
	}
	
	Debug("%N deadstop hunter %N", survivor, hunter);
	UpdateStat(survivor, STATS_EXTRA_SURV_HUNTER_DEADSTOP, 1);
}

public void OnTongueCut(int survivor, int smoker) {
	if (!ExtrasEnabled()) {
		Debug("Stat 'OnTongueCut' is skipped. Extra stat recording is disabled");
		return;
	}
	
	if (!IS_HUMAN_SURVIVOR(survivor)) {
		Debug("Skipping stat update '%s'. Survivor is a bot", STATS_EXTRA_SURV_SMOKER_TONGUE_CUT);
		return;
	}
	
	//If record bots is 0 and victim is a BOT, do not proceed
	if (!RecordBots() && !IS_HUMAN_INFECTED(smoker)) {
		Debug("Skipping stat update '%s' for %N. Victim is a bot", STATS_EXTRA_SURV_SMOKER_TONGUE_CUT, survivor);
		return;
	}
	
	Debug("%N cut tongue of %N", survivor, smoker);
	UpdateStat(survivor, STATS_EXTRA_SURV_SMOKER_TONGUE_CUT, 1);
}

public void OnTankRockSkeeted(int survivor, int tank) {
	if (!ExtrasEnabled()) {
		Debug("Stat 'OnTankRockSkeeted' is skipped. Extra stat recording is disabled");
		return;
	}
	
	if (!IS_HUMAN_SURVIVOR(survivor)) {
		Debug("Skipping stat update '%s'. Survivor is a bot", STATS_EXTRA_SURV_SKEET_TANK_ROCK);
		return;
	}
	
	//If record bots is 0 and victim is a BOT, do not proceed
	if (!RecordBots() && !IS_HUMAN_INFECTED(tank)) {
		Debug("Skipping stat update '%s' for %N. Opponent is a bot", STATS_EXTRA_SURV_SKEET_TANK_ROCK, survivor);
		return;
	}
	
	Debug("%N has skeeted a tank rock by %N", survivor, tank);
	UpdateStat(survivor, STATS_EXTRA_SURV_SKEET_TANK_ROCK, 1);
}

public void OnWitchCrown(int survivor, int damage) {
	if (!ExtrasEnabled()) {
		Debug("Stat 'OnWitchCrown' is skipped. Extra stat recording is disabled");
		return;
	}
	
	if (!IS_HUMAN_SURVIVOR(survivor)) {
		Debug("Skipping stat update '%s'. Survivor is a bot", STATS_EXTRA_SURV_WITCH_CROWN_STD);
		return;
	}
	
	//We do not need to check if RecordBots() here since the witch is an NPC
	
	Debug("%N has crowned witch (Damage: %i)", survivor, damage);
	UpdateStat(survivor, STATS_EXTRA_SURV_WITCH_CROWN_STD, 1);
}

public void OnWitchDrawCrown(int survivor, int damage, int chipDamage) {
	if (!ExtrasEnabled()) {
		Debug("Stat 'OnWitchDrawCrown' is skipped. Extra stat recording is disabled");
		return;
	}
	
	if (!IS_HUMAN_SURVIVOR(survivor)) {
		Debug("Skipping stat update '%s'. Survivor is a bot", STATS_EXTRA_SURV_WITCH_CROWN_DRAW);
		return;
	}
	
	Debug("%N has DRAW CROWNED witch (Damage: %i, Chip Damage: %i)", survivor, damage, chipDamage);
	UpdateStat(survivor, STATS_EXTRA_SURV_WITCH_CROWN_DRAW, 1);
}

// START OF SI SKILLS

public void OnDeathCharge(int charger, int victim, float height, float distance, bool wasCarried) {
	if (!ExtrasEnabled()) {
		Debug("Stat 'OnDeathCharge' is skipped. Extra stat recording is disabled");
		return;
	}
	
	if (!IS_HUMAN_INFECTED(charger)) {
		Debug("Skipping stat update '%s'. SI Charger is a bot", STATS_EXTRA_SI_DEATHCHARGE);
		return;
	}
	
	//If record bots is 0 and victim is a BOT, do not proceed
	if (!RecordBots() && !IS_HUMAN_SURVIVOR(victim)) {
		Debug("Skipping stat update '%s' for %N. Victim is a bot", STATS_EXTRA_SI_DEATHCHARGE, charger);
		return;
	}
	
	Debug("%N has death charged %N (Height: %f, Distance: %f)", charger, victim, height, distance);
	UpdateStat(charger, STATS_EXTRA_SI_DEATHCHARGE, 1);
}

public void OnHunterHighPounce(int hunter, int victim, int actualDamage, float calculatedDamage, float height, bool bReportedHigh, bool bPlayerIncapped) {
	if (!ExtrasEnabled()) {
		Debug("Stat 'OnHunterHighPounce' is skipped. Extra stat recording is disabled");
		return;
	}
	
	if (calculatedDamage < 25)
		return;
	
	if (!IS_HUMAN_INFECTED(hunter)) {
		Debug("Skipping stat update '%s'. SI Hunter is a bot", STATS_EXTRA_SI_HUNTER_25);
		return;
	}
	
	//If record bots is 0 and victim is a BOT, do not proceed
	if (!RecordBots() && !IS_HUMAN_SURVIVOR(victim)) {
		Debug("Skipping stat update '%s' for %N. Victim is a bot", STATS_EXTRA_SI_HUNTER_25, hunter);
		return;
	}
	
	Debug("Hunter high pounce (Hunter: %N, Victim: %N, Damage: %i, Calculated Damage: %f, Height: %f)", hunter, victim, actualDamage, calculatedDamage, height);
	UpdateStat(hunter, STATS_EXTRA_SI_HUNTER_25, 1);
}

public void OnTankRockEaten(int tank, int survivor) {
	if (!ExtrasEnabled()) {
		Debug("Stat 'OnTankRockEaten' is skipped. Extra stat recording is disabled");
		return;
	}
	
	if (!IS_HUMAN_INFECTED(tank)) {
		Debug("Skipping stat update '%s'. SI Tank is a bot", STATS_EXTRA_SI_TANK_ROCK_HITS);
		return;
	}
	
	//If record bots is 0 and victim is a BOT, do not proceed
	if (!RecordBots() && !IS_HUMAN_SURVIVOR(survivor)) {
		Debug("Skipping stat update '%s' for %N. Victim is a bot", STATS_EXTRA_SI_TANK_ROCK_HITS, tank);
		return;
	}
	
	Debug("%N has eaten a rock thrown by tank %N", survivor, tank);
	UpdateStat(tank, STATS_EXTRA_SI_TANK_ROCK_HITS, 1);
}

public void OnBoomerVomitLanded(int boomer, int amount) {
	if (!ExtrasEnabled()) {
		Debug("Stat 'OnBoomerVomitLanded' is skipped. Extra stat recording is disabled");
		return;
	}
	
	if (amount != 4) {
		return;
	}
	
	if (!IS_HUMAN_INFECTED(boomer)) {
		Debug("Skipping stat update '%s'. SI Boomer is a bot", STATS_EXTRA_SI_BOOMER_QUAD);
		return;
	}
	
	//We will require at least 1 human survivor
	if (!RecordBots() && GetHumanSurvivorCount() == 0) {
		Debug("Skipping stat update '%s' for %N. All survivors are BOTS. At least one should be a human player", STATS_EXTRA_SI_BOOMER_QUAD, boomer);
		return;
	}
	
	Debug("%N has landed a quad boom on %i surviors", boomer, amount);
	UpdateStat(boomer, STATS_EXTRA_SI_BOOMER_QUAD, 1);
}

// ================ MISC (Untracked) =================

public void OnChargerLevelHurt(int survivor, int charger, int damage) {
	if (!ExtrasEnabled()) {
		Debug("Stat 'OnChargerLevelHurt' is skipped. Extra stat recording is disabled");
		return;
	}
	Debug("OnChargerLevelHurt() %N by %N (Damage: %i)", charger, survivor, damage);
}

public void OnWitchCrownHurt(int survivor, int damage, int chipdamage) {
	if (!ExtrasEnabled()) {
		Debug("Stat 'OnWitchCrownHurt' is skipped. Extra stat recording is disabled");
		return;
	}
	Debug("%N crowned witch by hurting (Damage: %i, Chip Damage: %i)", survivor, damage, chipdamage);
}

public void OnSkeetGL(int survivor, int hunter) {
	if (!ExtrasEnabled()) {
		Debug("Stat 'OnSkeetGL' is skipped. Extra stat recording is disabled");
		return;
	}
	Debug("%N skeeted %N with a Grenade Launcher", survivor, hunter);
}

public void OnBunnyHopStreak(int survivor, int streak, float maxVelocity) {
	if (!ExtrasEnabled()) {
		Debug("Stat 'OnBunnyHopStreak' is skipped. Extra stat recording is disabled");
		return;
	}
	Debug("%N had a BHOP stream of %i (Speed: %.2f)", survivor, streak, maxVelocity);
}

/************* END: SKILL DETECTION *********************/


public void GetServerName(char[] buffer, int size) {
	g_sServerName.GetString(buffer, size);
}

/**
* Checks if the stat key belongs to the basic stats group
*/
public bool IsBasicStat(const char[] name) {
	for (int i = 0; i < sizeof(g_sBasicStats); i++) {
		if (StrEqual(g_sBasicStats[i], name, false)) {
			return true;
		}
	}
	return false;
}

/**
* Checks if the stat key belongs to the extra stats group
*/
public bool IsExtraStat(const char[] name) {
	for (int i = 0; i < sizeof(g_sExtraStats); i++) {
		if (StrEqual(g_sExtraStats[i], name, false)) {
			return true;
		}
	}
	return false;
}

/**
* Checks if we should also record victim bots (e.g. Human survivor kills Bot Hunter).
*
* Note: Attacker bots are disregarded and not recorded.
*/
public bool RecordBots() {
	return g_bRecordBots.BoolValue;
}

/**
* Checks if the plugin should collect/record statistics.
*
* This will return false if:
* - Cvar 'pstats_enabled' is 0
* - Cvar 'pstats_versus_exclusive' is 1 and game mode is not versus
*/
public bool AllowCollectStats() {
	//Check if plugin is enabled
	if (PluginDisabled()) {
		Debug("Player stats is currently disabled. Stats will not be recorded");
		return false;
	}
	
	char gameMode[255];
	g_sGameMode.GetString(gameMode, sizeof(gameMode));
	
	//If its not exclusive to versus, then just return true
	if (!VersusExclusive())
		return true;
	
	if (!StrEqual(gameMode, "versus")) {
		Debug("Player stats is currently exclusive to versus game mode only. Stats will not be recorded (Current game mode: %s)", gameMode);
		return false;
	}
	return true;
}

/**
* Checks if the skill detect plugin is loaded
*/
public bool SkillDetectLoaded() {
	return g_bSkillDetectLoaded;
}

/**
* Checks if extra special stats should be recorded too :)
*/
public bool ExtrasEnabled() {
	if (g_bEnableExtraStats.BoolValue && !SkillDetectLoaded()) {
		Error("Extra stats are enabled but a required plugin dependency is not loaded (skill_detect). Extra stats have been disabled");
	}
	return SkillDetectLoaded() && g_bEnableExtraStats.BoolValue;
}

/**
* Check if connect announce is enabled
*/
public bool CAnnounceEnabled() {
	return g_bConnectAnnounceEnabled.BoolValue;
}

/**
* Checks if the plugin should record stats on versus mode only
*/
public bool VersusExclusive() {
	return g_bVersusExclusive.BoolValue;
}

/**
* Check if the plugin is in disabled state.
*/
public bool PluginDisabled() {
	return !g_bEnabled.BoolValue;
}

/**
* Checks if the plugin is in debug mode
*/
public bool DebugEnabled() {
	return g_bDebug.BoolValue;
}

/**
* Check if we should show the player rank to the user when he/she connects to the server
*/
public bool ShowRankOnConnect() {
	return g_bShowRankOnConnect.BoolValue;
}

/**
* Check if the string is blank
*/
stock bool StringBlank(const char[] text) {
	int len = strlen(text);
	char[] tmp = new char[len];
	String_Trim(text, tmp, len);
	return StrEqual(tmp, "");
}

/**
* Print and log plugin error messages. Error messages will also be printed to chat for admins in the server.
*/
public void Error(const char[] format, any...)
{
	int len = strlen(format) + 255;
	char[] formattedString = new char[len];
	VFormat(formattedString, len, format, 2);
	
	len = len + 8;
	char[] debugMessage = new char[len];
	Format(debugMessage, len, "[ERROR] %s", formattedString);
	
	PrintToServer(debugMessage);
	LogError(debugMessage);
	
	//Display error messages to root admins if debug is enabled
	for (int i = 1; i <= MAX_CLIENTS; i++) {
		if (IS_VALID_HUMAN(i) && Client_IsAdmin(i) && Client_HasAdminFlags(i, ADMFLAG_ROOT)) {
			PrintToConsole(i, debugMessage);
			if (!DebugEnabled())
				continue;
			Client_PrintToChat(i, true, "{R}[ERROR]{N} %s", formattedString);
		}
	}
}

/**
* Print and log plugin notify messages to the client
*/
public void Notify(int client, const char[] format, any...)
{
	int len = strlen(format) + 255;
	char[] formattedString = new char[len];
	VFormat(formattedString, len, format, 2);
	
	len = len + 8;
	char[] debugMessage = new char[len];
	
	if (client == 0) {
		Format(debugMessage, len, "[%s] %s", DEFAULT_PLUGIN_TAG, formattedString);
		PrintToServer(debugMessage);
	} else if (client > 0 && IS_VALID_HUMAN(client)) {
		Format(debugMessage, len, "{N}[{L}%s{N}] {O}%s", DEFAULT_PLUGIN_TAG, formattedString);
		Client_PrintToChat(client, true, "%s", debugMessage);
	} else {
		return;
	}
	
	LogAction(client, -1, debugMessage);
	
	//Display info messages to root admins
	for (int i = 1; i <= MAX_CLIENTS; i++) {
		if (IS_VALID_HUMAN(i) && Client_IsAdmin(i) && Client_HasAdminFlags(i, ADMFLAG_ROOT)) {
			PrintToConsole(i, debugMessage);
		}
	}
}

/**
* Print and log plugin info messages
*/
public void Info(const char[] format, any...)
{
	int len = strlen(format) + 255;
	char[] formattedString = new char[len];
	VFormat(formattedString, len, format, 2);
	
	len = len + 8;
	char[] debugMessage = new char[len];
	Format(debugMessage, len, "[INFO] %s", formattedString);
	
	PrintToServer(debugMessage);
	LogMessage(debugMessage);
	
	//Display info messages to root admins
	for (int i = 1; i <= MAX_CLIENTS; i++) {
		if (IS_VALID_HUMAN(i) && Client_IsAdmin(i) && Client_HasAdminFlags(i, ADMFLAG_ROOT)) {
			PrintToConsole(i, debugMessage);
		}
	}
}

/**
* Print and log plugin debug messages. This does not display messages when debug mode is disabled.
*/
public void Debug(const char[] format, any...)
{
	#if defined DEBUG
	if (!DebugEnabled()) {
		return;
	}
	
	int len = strlen(format) + 255;
	char[] formattedString = new char[len];
	VFormat(formattedString, len, format, 2);
	
	len = len + 8;
	char[] debugMessage = new char[len];
	Format(debugMessage, len, "[DEBUG] %s", formattedString);
	
	PrintToServer(debugMessage);
	LogMessage(debugMessage);
	
	//Display debug messages to root admins
	for (int i = 1; i <= MAX_CLIENTS; i++) {
		if (IS_VALID_HUMAN(i) && Client_IsAdmin(i) && Client_HasAdminFlags(i, ADMFLAG_ROOT))
			PrintToConsole(i, debugMessage);
	}
	#endif
} 