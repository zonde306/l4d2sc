#include <sourcemod>
#include <sdktools>
#include <geoipcity>
#include <geoip>

#define SQL_DRIV	"mysql"
#define SQL_DATA	"source_game"
#define SQL_HOST	"zonde306.site"
#define SQL_USER	"srcgame"
#define SQL_PASS	"abby6382"
#define SQL_PORT	"3306"

#define PLUGIN_VERSION "0.1"
public Plugin myinfo = 
{
	name = "玩家信息统计",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/"
}

#define IsValidClient(%1)	((1 <= %1 <= MaxClients) && IsClientInGame(%1))
#define CVAR_FLAGS			FCVAR_PLUGIN|FCVAR_NOTIFY
#define COIN_GIVE_TIME		30.0

ConVar	gCvarAllow, gCvarKillZombie, gCvarKillTeam, gCvarKillHeadShot, gCvarEscape, gCvarEvent, gCvarFireTeam, gCvarWaveSucces,
		gCvarAliveCoin, gCvarCoin, gCvarTime, gCvarPasswd;

Database gDatabase;
Handle hTimerAutoKilled;
int iClientKill[MAXPLAYERS + 1] = {0, ...}, iClientHeadShot[MAXPLAYERS + 1] = {0, ...}, iClientUserID[MAXPLAYERS + 1] = {-1, ...};

enum()
{
	point = 0,
	killed,
	death,
	used,
	attack,
	complete,
	wave,
	escape,
	headshot,
	killteam,
	passwd
}

public OnPluginStart()
{
	CreateConVar("nmp_status_version", PLUGIN_VERSION, "插件版本", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	gCvarAllow = CreateConVar("nmp_status_enable", "1", "是否开启插件", CVAR_FLAGS, true, 0.0, true, 1.0);
	gCvarKillZombie =	CreateConVar("nmp_status_kill_zombie", "1", "击杀僵尸获得多少积分", CVAR_FLAGS);
	gCvarKillTeam =		CreateConVar("nmp_status_kill_team", "-100", "击杀队友获得多少积分", CVAR_FLAGS);
	gCvarKillHeadShot =	CreateConVar("nmp_status_kill_headshot", "1", "爆头击杀获得多少积分", CVAR_FLAGS);
	gCvarEscape =		CreateConVar("nmp_status_escape", "100", "逃脱获得多少积分", CVAR_FLAGS);
	gCvarEvent =		CreateConVar("nmp_status_event", "5", "完成任务获得多少积分", CVAR_FLAGS);
	gCvarFireTeam =		CreateConVar("nmp_status_friendlyfire", "-10", "攻击队友获得多少积分", CVAR_FLAGS);
	gCvarWaveSucces =	CreateConVar("nmp_status_wave", "10", "守住一波获得多少积分", CVAR_FLAGS);
	gCvarPasswd =		CreateConVar("nmp_status_passwd", "5", "输入正确的密码获得多少积分", CVAR_FLAGS);
	
	gCvarTime =			CreateConVar("nmp_status_time", "16.0", "自动获得硬币的 【延时】", CVAR_FLAGS, true, 1.0);
	gCvarCoin =			CreateConVar("nmp_status_coin", "1", "每隔 【延时】 秒获得多少硬币", CVAR_FLAGS, true, 0.0);
	gCvarAliveCoin =	CreateConVar("nmp_status_coin_alive", "2", "活着每隔 【延时】 秒获得多少硬币", CVAR_FLAGS, true, 0.0);
	
	AutoExecConfig(true, "nmp_status");
	
	hTimerAutoKilled = CreateTimer(30.0, Timer_CheckKillInfo, _, TIMER_REPEAT);
	CreateTimer(1.0, Timer_AutoGiveCoin, _, TIMER_REPEAT);
	HookConVarChange(gCvarAllow, ConVar_OnAllowChange);
	//HookConVarChange(gCvarTime, ConVar_OnTimeChange);
	
	RegConsoleCmd("sm_showinfo", Cmd_ShowInfo, "显示玩家信息");
	ConnectDataBase();
	
	if(gCvarAllow.IntValue >= 1)
	{
		HookEventEx("player_spawn", Event_PlayerSpawn);
		HookEventEx("player_hurt", Event_PlayerHurt);
		HookEventEx("player_death", Event_PlayerDeath);
		HookEventEx("npc_killed", Event_ZombieDeath);
		HookEventEx("zombie_killed_by_fire", Event_ZombieDeathFire);
		HookEventEx("zombie_head_split", Event_ZombieHeadShot);
		HookEventEx("player_extracted", Event_PlayerEscape);
		HookEventEx("objective_complete", Event_MissionComplete);
		HookEventEx("player_changename", Event_PlayerChangeName);
		HookEventEx("wave_complete", Event_SurvivalWaveComplete);
		HookEventEx("keycode_enter", Event_PasswordEnter);
		HookEventEx("zombie_killed", Event_ZombieKilled);
		HookEventEx("game_win", Event_RoundWin);
	}
	
	HookEventEx("state_change", Event_StateChange);
	HookEventEx("nmrih_round_begin", Event_RoundStart);
	HookEventEx("teamplay_round_start", Event_RoundStart);
	HookEventEx("game_round_restart", Event_RoundStart);
	
	// HookEventEx("safe_zone_heal", Event_SafeZoneHeal);
	// HookEventEx("safe_zone_damage", Event_SafeZoneHurt);
	// HookEventEx("safe_zone_deactivate", Event_SafeZoneKilled);
	// HookEventEx("cure", Event_FirstAidUsed);
	// HookEventEx("pills_taken", Event_PillsUsed);
	// HookEventEx("player_contemplate_suicide", Event_PlayerSuicide);
	
}

public Action Cmd_ShowInfo(int client, int args)
{
	if(!IsValidClient(client))
		return Plugin_Continue;
	
	if(iClientUserID[client] < 0)
		LoadPlayerInfo(client);
	
	if(iClientUserID[client] < 0)
	{
		PrintToChat(client, "\x03[提示]\x01 无法读取到你的信息！");
		return Plugin_Continue;
	}
	
	StringMap trie = GetClientStatus(client);
	if(trie.Size <= 0)
	{
		PrintToChat(client, "\x03[提示]\x01 什么也没找到！");
		return Plugin_Continue;
	}
	
	int tmp;
	trie.GetValue("killed", tmp);
	PrintToChat(client, "\x03 killed = %d", tmp);
	trie.GetValue("killteam", tmp);
	PrintToChat(client, "\x03 killteam = %d", tmp);
	trie.GetValue("headshot", tmp);
	PrintToChat(client, "\x03 headshot = %d", tmp);
	trie.GetValue("death", tmp);
	PrintToChat(client, "\x03 death = %d", tmp);
	trie.GetValue("point", tmp);
	PrintToChat(client, "\x03 point = %d", tmp);
	trie.GetValue("used", tmp);
	PrintToChat(client, "\x03 used = %d", tmp);
	trie.GetValue("escape", tmp);
	PrintToChat(client, "\x03 escape = %d", tmp);
	trie.GetValue("complete", tmp);
	PrintToChat(client, "\x03 complete = %d", tmp);
	trie.GetValue("wave", tmp);
	PrintToChat(client, "\x03 wave = %d", tmp);
	trie.GetValue("attack", tmp);
	PrintToChat(client, "\x03 attack = %d", tmp);
	
	return Plugin_Continue;
}

public OnClientDisconnect(int client)
{
	if(1 <= client <= MaxClients)
	{
		TriggerTimer(hTimerAutoKilled, true);
		iClientUserID[client] = -1;
	}
}

public OnClientConnected(int client)
{
	if(!IsValidClient(client) || IsFakeClient(client))
		return;
	
	char auth[64], name[128], ip[64], country[64];
	GetClientName(client, name, 128);
	GetClientIP(client, ip, 64);
	GetClientAuthId(client, AuthId_SteamID64, auth, 64, false);
	GeoipCountry(ip, country, 64);
	
	char auth2[64], auth3[64];
	GetClientAuthId(client, AuthId_Steam2, auth2, 64, false);
	GetClientAuthId(client, AuthId_Steam3, auth3, 64, false);
	ReplaceString(auth2, 64, "STEAM_0:", "STEAM_1:");
	ReplaceString(auth3, 64, "[", "");
	ReplaceString(auth3, 64, "]", "");
	
	EasyQuery("insert ignore into user_info (name, sid, ip, sid2, sid3, country) values ('%s', '%s', '%s', '%s', '%s', '%s');",
		name, auth, ip, auth2, auth3, country);
	
	log("[统计] 玩家 %s 正在连接... 来自于：%s", name, country);
}

/*
public void ConVar_OnTimeChange(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	if(hTimerAutoGave != INVALID_HANDLE)
	{
		KillTimer(hTimerAutoGave);
		hTimerAutoGave = INVALID_HANDLE;
	}
	
	float time = StringToFloat(newValue);
	if(time <= 0.0)
		return;
	
	hTimerAutoGave = CreateTimer(time, Timer_AutoGiveCoin, _, TIMER_REPEAT);
}
*/

public void ConVar_OnAllowChange(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	if(gCvarAllow.IntValue >= 1)
	{
		HookEventEx("player_spawn", Event_PlayerSpawn);
		HookEventEx("player_hurt", Event_PlayerHurt);
		HookEventEx("player_death", Event_PlayerDeath);
		HookEventEx("npc_killed", Event_ZombieDeath);
		HookEventEx("zombie_killed_by_fire", Event_ZombieDeathFire);
		HookEventEx("zombie_head_split", Event_ZombieHeadShot);
		HookEventEx("player_extracted", Event_PlayerEscape);
		HookEventEx("objective_complete", Event_MissionComplete);
		HookEventEx("player_changename", Event_PlayerChangeName);
		HookEventEx("wave_complete", Event_SurvivalWaveComplete);
		//HookEvent("state_change", Event_StateChange);
	}
	else
	{
		UnhookEvent("player_spawn", Event_PlayerSpawn);
		UnhookEvent("player_hurt", Event_PlayerHurt);
		UnhookEvent("player_death", Event_PlayerDeath);
		UnhookEvent("npc_killed", Event_ZombieDeath);
		UnhookEvent("zombie_killed_by_fire", Event_ZombieDeathFire);
		UnhookEvent("zombie_head_split", Event_ZombieHeadShot);
		UnhookEvent("player_extracted", Event_PlayerEscape);
		UnhookEvent("objective_complete", Event_MissionComplete);
		UnhookEvent("player_changename", Event_PlayerChangeName);
		UnhookEvent("wave_complete", Event_SurvivalWaveComplete);
		//UnhookEvent("state_change", Event_StateChange);
	}
}

public void Event_PlayerHurt(Event event, const char[] eventName, bool copy)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	if(!IsValidClient(victim) || !IsValidClient(attacker) || GetClientTeam(victim) != GetClientTeam(attacker) || victim == attacker)
		return;
	
	//ChangeClientAttack(attacker);
	//ChangeClientPoint(attacker, gCvarFireTeam.IntValue);
	
	int penalty = gCvarFireTeam.IntValue;
	ChangeClientInfo(attacker, attack);
	ChangeClientInfo(attacker, point, penalty);
	log("玩家 %N 攻击了队友 %N %s了 %d 积分。", attacker, victim, (penalty >= 0 ? "获得" : "失去"), abs(penalty));
}

public void Event_PlayerSpawn(Event event, const char[] eventName, bool copy)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(!IsValidClient(client))
		return;
	
	LoadPlayerInfo(client);
}

public Action Timer_CheckKillInfo(Handle timer, any data)
{
	int kill = gCvarKillZombie.IntValue;
	int head = gCvarKillHeadShot.IntValue;
	int totalKill, totalHeadShot, totalPoint;
	totalKill = totalHeadShot = totalPoint = 0;
	
	int idx[MAXPLAYERS + 1] = {-1, ...};
	int max = GetClientList(idx);
	int bonus = 0;
	
	for(int i = 0; i < max; i++)
	{
		bonus = iClientKill[idx[i]] * kill + iClientHeadShot[idx[i]] * head;
		EasyQuery("update nmrih_status set killed = killed + %d, headshot = headshot + %d, point = point + %d where uid = %d;",
			iClientKill[idx[i]], iClientHeadShot[idx[i]], bonus, iClientUserID[idx[i]]);
		
		totalPoint += bonus;
		totalKill += iClientKill[idx[i]];
		totalHeadShot += iClientHeadShot[idx[i]];
		
		iClientKill[idx[i]] = 0;
		iClientHeadShot[idx[i]] = 0;
	}
	
	/*
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsValidClient(i))
			continue;
		
		totalPlayer++;
		//ChangeClientKill(i, iClientKill[i]);
		//ChangeClientPoint(i, iClientKill[i] * gCvarKillZombie.IntValue);
		//ChangeClientHeadShot(i, iClientHeadShot[i]);
		//ChangeClientPoint(i, iClientHeadShot[i] * gCvarKillHeadShot.IntValue);
		ChangeClientInfo(i, killed, iClientKill[i]);
		ChangeClientInfo(i, point, iClientKill[i] * kill);
		ChangeClientInfo(i, headshot, iClientKill[i]);
		ChangeClientInfo(i, point, iClientKill[i] * head);
		
		totalPoint += iClientKill[i] * kill + iClientKill[i] * head;
		totalKill += iClientKill[i];
		totalHeadShot += iClientHeadShot[i];
		iClientKill[i] = 0;
		iClientHeadShot[i] = 0;
	}
	*/
	PrintToServer("[统计] 击杀统计 一共有 %d 名玩家，总计 击杀(%d)|爆头(%d)|积分(%d)",
		max, totalKill, totalHeadShot, totalPoint);
	
}

public void Event_StateChange(Event event, const char[] eventName, bool copy)
{
	int survival = event.GetInt("game_type");
	int state = event.GetInt("state");
	static Event ev;
	
	log("[状态] 游戏模式：%d 游戏状态：%d", survival, state);
	switch(state)
	{
		case 1:
		{
			// 地图开始？不确定
			log("[状态] 地图开始");
		}
		case 2:
		{
			// 练习时间结束
			log("[状态] 等待玩家载入时间结束");
		}
		case 3:
		{
			// 回合开始
			log("[状态] 回合开始");
			
			ev = CreateEvent("round_start", true);
			ev.Fire();
		}
		case 5, 8:
		{
			// 全部玩家死亡或者上救援了
			// 5 == 全部玩家死亡 | 8 == 回合结束
			log("[状态] 回合结束");
			
			ev = CreateEvent("round_end", true);
			ev.Fire();
		}
		case 6:
		{
			// 救援到时间离开了
			log("[状态] 救援离开了");
		}
	}
}

public void Event_RoundWin(Event event, const char[] eventName, bool copy)
{
	char map[64];
	event.GetString("strMapName", map, 64);
	
	int difficulty = event.GetInt("difficulty");
	int wave = event.GetInt("wave");
	int live = event.GetInt("livingplayers");
	
	log("[回合] 当前地图 %s，当前波数 %d，当前难度 %d，当前存活玩家数 %d", map, wave, difficulty, live);
}

public void Event_RoundStart(Event event, const char[] eventName, bool copy)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
			LoadPlayerInfo(i);
	}
}

public void Event_PlayerChangeName(Event event, const char[] eventName, bool copy)
{
	char newName[128];
	int client = GetClientOfUserId(event.GetInt("userid"));
	event.GetString("userid", newName, 128);
	
	if(!IsValidClient(client) || iClientUserID[client] < 0)
		return;
	
	//EasyQuery("update nmrih_status set name = '%s' where uid = %d;", newName, iClientUserID[client]);
	//EasyQuery("update user_online set name = '%s' where uid = %d;", newName, iClientUserID[client]);
	EasyQuery("update user_info set name = '%s' where uid = %d;", newName, iClientUserID[client]);
}

public void Event_PasswordEnter(Event event, const char[] eventName, bool copy)
{
	char code[8] = "", password[8] = "";
	int client = event.GetInt("player");
	int keypad = event.GetInt("keypad_idx");
	event.GetString("code", code, 8);
	
	if(!IsValidClient(client) || iClientUserID[client] < 0 || !IsValidEntity(keypad) || code[0] == '\0')
		return;
	
	int bonus = gCvarPasswd.IntValue;
	GetEntPropString(keypad, Prop_Data, "m_pszCode", password, 8, 0);
	if(strcmp(code, password, false) == 0)
	{
		log("[密码] 玩家 %N 输入了正确的密码：%s。获得 %d 积分", client, password, bonus);
		ChangeClientInfo(client, point, bonus);
		ChangeClientInfo(client, passwd);
	}
	else
		log("[密码] 玩家 %N 输入了错误的密码：%s 正确的是：%s", client, code, password);
}

public void Event_SurvivalWaveComplete(Event event, const char[] eventName, bool copy)
{
	int boo = gCvarWaveSucces.IntValue, totalPlayer, totalCoin, totalAlive;
	totalPlayer = totalCoin = totalAlive = 0;
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			totalPlayer++;
			if(IsPlayerAlive(i))
			{
				totalAlive++;
				totalCoin += boo;
				ChangeClientInfo(i, wave);
				ChangeClientInfo(i, point, boo);
			}
			//ChangeClientWave(i);
			//ChangeClientPoint(i, gCvarWaveSucces.IntValue);
		}
	}
	
	log("[统计] 生存成功守住 目前有 %d 名玩家在线，其中有 %d 名存活，共获得了 %d 积分。", totalPlayer, totalAlive, totalCoin);
}

public void Event_MissionComplete(Event event, const char[] eventName, bool copy)
{
	int bonus = gCvarEvent.IntValue, totalPlayer, totalCoin, totalAlive;
	totalPlayer = totalCoin = totalAlive = 0;
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			//ChangeClientComplete(i);
			//ChangeClientPoint(i, gCvarEvent.IntValue);
			totalPlayer++;
			if(IsPlayerAlive(i))
			{
				totalAlive++;
				totalCoin += bonus;
				ChangeClientInfo(i, complete);
				ChangeClientInfo(i, point, bonus);
			}
		}
	}
	
	PrintToServer("[统计] 跑图任务完成 目前有 %d 名玩家在线，其中有 %d 名存活，共获得了 %d 积分。", totalPlayer, totalAlive, totalCoin);
}

public void Event_PlayerEscape(Event event, const char[] eventName, bool copy)
{
	int client = event.GetInt("player_id"), bonus = gCvarEscape.IntValue;
	
	if(IsValidClient(client))
	{
		//ChangeClientEscape(client);
		//ChangeClientPoint(client, gCvarEscape.IntValue);
		ChangeClientInfo(client, escape);
		ChangeClientInfo(client, point, bonus);
		log("[统计] 玩家 %N 成功逃脱，获得了 %d 积分。", client, bonus);
	}
}

public void Event_ZombieHeadShot(Event event, const char[] eventName, bool copy)
{
	int client = event.GetInt("player_id");
	
	if(IsValidClient(client))
		iClientHeadShot[client]++;
}

public void Event_ZombieDeathFire(Event event, const char[] eventName, bool copy)
{
	int client = event.GetInt("igniter_id");
	
	if(IsValidClient(client))
		iClientKill[client]++;
}

public void Event_ZombieDeath(Event event, const char[] eventName, bool copy)
{
	int client = event.GetInt("killeridx");
	
	if(IsValidClient(client))
		iClientKill[client]++;
}

public void Event_ZombieKilled(Event event, const char[] eventName, bool copy)
{
	int client = event.GetInt("entindex_attacker");
	
	if(IsValidClient(client))
		iClientKill[client]++;
}

public void Event_PlayerDeath(Event event, const char[] eventName, bool copy)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	if(!IsValidClient(victim) || !IsValidEntity(attacker) || victim == attacker)
		return;
	
	int penalty = gCvarKillTeam.IntValue;
	if(IsValidClient(attacker))
	{
		//ChangeClientKillTeam(attacker);
		//ChangeClientPoint(attacker, gCvarKillTeam.IntValue);
		ChangeClientInfo(attacker, killteam);
		ChangeClientInfo(attacker, point, penalty);
		log("[统计] 玩家 %N 杀死了 %N %s了 %d 积分。", attacker, victim, (penalty >= 0 ? "获得" : "失去"), abs(penalty));
	}
	else
	{
		//ChangeClientDeath(client);
		ChangeClientInfo(victim, death);
		log("[统计] 玩家 %N 死亡。", victim);
	}
}

void ConnectDataBase()
{
	Handle kv = CreateKeyValues("");
	KvSetString(kv, "driver", SQL_DRIV);
	KvSetString(kv, "host", SQL_HOST);
	KvSetString(kv, "database", SQL_DATA);
	KvSetString(kv, "user", SQL_USER);
	KvSetString(kv, "pass", SQL_PASS);
	KvSetString(kv, "port", SQL_PORT);
	
	char err[255];
	gDatabase = SQL_ConnectCustom(kv, err, 255, true);
	CloneHandle(kv);
	
	if(gDatabase == INVALID_HANDLE)
	{
		log("连接数据库失败：%s", err);
		//PrintToServer("\x03[提示]\x01 连接数据库失败...");
		CreateTimer(3.0, Timer_reConnectDataBase);
	}
}

public Action Timer_reConnectDataBase(Handle timer, any data)
{
	log("正在尝试重新连接数据库...");
	ConnectDataBase();
	return Plugin_Continue;
}

public OnClientPutInServer(int client)
{
	if(!IsValidClient(client))
		return;
	
	LoadPlayerInfo(client);
	CreateTimer(3.0, Timer_KickCheck, client);
}

public bool OnClientConnect(int client, char[] reject, int len)
{
	if(!IsValidClient(client))
		return true;
	
	LoadPlayerInfo(client);
	return true;
}

public Action Timer_KickCheck(Handle timer, any client)
{
	if(!IsValidClient(client) || iClientUserID[client] < 0)
		return Plugin_Continue;
	
	int kill = 0;
	if(!GetClientStatus(client).GetValue("killteam", kill))
		return Plugin_Continue;
	
	if(kill >= 5)
	{
		log("[统计] 玩家 %N 杀死过 %d 名队友，应该让它自己退出。", client, kill);
		ClientCommand(client, "quit");
		ClientCommand(client, "exit");
		FakeClientCommand(client, "quit");
		FakeClientCommand(client, "exit");
		FakeClientCommandEx(client, "quit");
		FakeClientCommandEx(client, "exit");
		ClientCommand(client, "disconnect");
		FakeClientCommand(client, "disconnect");
		FakeClientCommandEx(client, "disconnect");
	}
	
	return Plugin_Continue;
}

void LoadPlayerInfo(int client)
{
	if(!IsValidClient(client))
		ThrowError("这个玩家无效！");
	
	char auth[64], name[128], ip[64], country[64];
	GetClientName(client, name, 128);
	GetClientIP(client, ip, 64);
	GetClientAuthId(client, AuthId_SteamID64, auth, 64, false);
	GeoipCountry(ip, country, 64);
	
	char auth2[64], auth3[64];
	GetClientAuthId(client, AuthId_Steam2, auth2, 64, false);
	GetClientAuthId(client, AuthId_Steam3, auth3, 64, false);
	ReplaceString(auth2, 64, "STEAM_0:", "STEAM_1:");
	ReplaceString(auth3, 64, "[", "");
	ReplaceString(auth3, 64, "]", "");
	
	EasyQuery("insert ignore into user_info (name, sid, ip, sid2, sid3, country) values ('%s', '%s', '%s', '%s', '%s', '%s');",
		name, auth, ip, auth2, auth3, country);
	
	dbQuery(client, QCB_LoadPlayer, "select uid from user_info where sid = '%s' or sid2 = '%s' or sid3 = '%s';", auth, auth2, auth3);
}

stock dbQuery(client, SQLQueryCallback callback, const char[] query, any:...)
{
	char line[2048];
	VFormat(line, 2048, query, 4);
	gDatabase.Query(callback, line, client);
}

public void QCB_LoadPlayer(Database database, DBResultSet res, const char[] error, any client)
{
	if(!IsValidClient(client))
		ThrowError("这个玩家无效！");
	
	char auth[64], name[128], ip[64], country[64];
	GetClientName(client, name, 128);
	GetClientIP(client, ip, 64);
	GetClientAuthId(client, AuthId_SteamID64, auth, 64, false);
	GeoipCountry(ip, country, 64);
	
	if(res == INVALID_HANDLE || res.RowCount <= 0 || !res.FetchRow())
	{
		log("找不到这个玩家！");
		
		if(IsValidClient(client))
			LoadPlayerInfo(client);
		
		return;
	}
	
	if(error[0] != '\0')
		ThrowError("读取玩家错误：%s", error);
	
	iClientUserID[client] = res.FetchInt(0);
	//EasyQuery("insert ignore into nmrih_status (uid, name, sid, ip) values ('%d', '%s', '%s', '%s');", iClientUserID[client], name, auth, ip);
	//EasyQuery("update nmrih_status set name = '%s', ip = '%s' where uid = %d;", name, ip, iClientUserID[client]);
	//EasyQuery("update user_online set name = '%s', ip = '%s' where uid = %d;", name, ip, iClientUserID[client]);
	
	EasyQuery("insert ignore into user_online (uid) values ('%d');", iClientUserID[client]);
	EasyQuery("insert ignore into nmrih_status (uid) values ('%d');", iClientUserID[client]);
	EasyQuery("update user_info set name = '%s', ip = '%s', country = '%s' where uid = %d;",
		name, ip, country, iClientUserID[client]);
	
	char city[45], region[45], country_name[45], country_code[3], country_code3[4];
	if(GeoipGetRecord(ip, city, region, country_name, country_code, country_code3))
	{
		EasyQuery("update user_online set country_name = '%s', region = '%s', city = '%s', code = '%s', code3 = '%s' where uid = %d;",
			country_name, region, city, country_code, country_code3, iClientUserID[client]);
	}
	
	log("玩家 %s 进入了游戏，他的 uid 为 %d", name, iClientUserID[client]);
	log("[玩家信息] 国家：%s 区域：%s 城市：%s IP地址：%s", country_name, region, city, ip);
}

DBResultSet SQLQuery(const char[] query, any:...)
{
	char line[2048];
	VFormat(line, 2048, query, 2);
	return SQL_Query(gDatabase, line);
}

void ChangeClientInfo(int client, int type, int count = 1)
{
	if(iClientUserID[client] < 0)
	{
		ThrowError("这个玩家没有被加载！");
		return;
	}
	
	char line[32];
	
	switch(type)
	{
		case point:		strcopy(line, 32, "point");
		case killed:	strcopy(line, 32, "killed");
		case death:		strcopy(line, 32, "death");
		case used:		strcopy(line, 32, "used");
		case attack:	strcopy(line, 32, "attack");
		case complete:	strcopy(line, 32, "complete");
		case wave:		strcopy(line, 32, "wave");
		case escape:	strcopy(line, 32, "escape");
		case headshot:	strcopy(line, 32, "headshot");
		case killteam:	strcopy(line, 32, "killteam");
		case passwd:	strcopy(line, 32, "passwd");
		default:		strcopy(line, 32, "");
	}
	
	if(line[0] != '\0')
		EasyQuery("update nmrih_status set %s = %s + %d where uid = %d;", line, line, count, iClientUserID[client]);
}

void EasyQuery(const char[] query, any:...)
{
	char line[1024];
	VFormat(line, 1024, query, 2);
	
	SQL_FastQuery(gDatabase, line);
}

StringMap GetClientStatus(int client)
{
	StringMap trie = CreateTrie();
	
	if(iClientUserID[client] < 0)
	{
		ThrowError("这个玩家没有被加载！");
		return trie;
	}
	
	DBResultSet res = SQLQuery("select killed, killteam, headshot, death, point, used, escape, complete, wave, attack, passwd from nmrih_status where uid = %d;", iClientUserID[client]);
	if(res.RowCount <= 0 || !res.FetchRow())
	{
		res.Close();
		ThrowError("这个玩家没有记录！");
		return trie;
	}
	
	trie.SetValue("killed", res.FetchInt(0), true);
	trie.SetValue("killteam", res.FetchInt(1), true);
	trie.SetValue("headshot", res.FetchInt(2), true);
	trie.SetValue("death", res.FetchInt(3), true);
	trie.SetValue("point", res.FetchInt(4), true);
	trie.SetValue("used", res.FetchInt(5), true);
	trie.SetValue("escape", res.FetchInt(6), true);
	trie.SetValue("complete", res.FetchInt(7), true);
	trie.SetValue("wave", res.FetchInt(8), true);
	trie.SetValue("attack", res.FetchInt(9), true);
	trie.SetValue("passwd", res.FetchInt(10), true);
	res.Close();
	
	return trie;
}

int GetClientList(int[] arr, int len = MAXPLAYERS + 1)
{
	int idx[MAXPLAYERS + 1] = -1, max = 0;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsValidClient(i) || iClientUserID[i] < 0)
			continue;
		idx[max++] = i;
	}
	
	for(int i = 0; (i < len && i <= MaxClients) ; i++)
		arr[i] = idx[i];
	
	return max;
}

public Action Timer_AutoGiveCoin(Handle timer, any data)
{
	int idx[MAXPLAYERS + 1] = {-1, ...};
	int max = GetClientList(idx);
	
	char tbl[255] = "";
	for(int i = 0; i < max; i++)
	{
		// 把多次相同的 update 合并到一次
		if(tbl[0] == '\0')
			IntToString(iClientUserID[idx[i]], tbl, 255);
		else
			Format(tbl, 255, "%s, %d", tbl, iClientUserID[idx[i]]);
	}
	
	EasyQuery("update user_online set online = date_add(online, interval 1 second) where uid in (%s);", tbl);
	
	static float last;
	float now = GetEngineTime();
	if(now - last < gCvarTime.FloatValue)
		return Plugin_Continue;
	last = now;
	int totalCoin = 0, die = gCvarCoin.IntValue, ali = gCvarAliveCoin.IntValue;
	
	for(int i = 0; i < max; i++)
	{
		if(IsPlayerAlive(idx[i]))
		{
			EasyQuery("update user_online set coin = coin + %d where uid = %d;", ali, iClientUserID[idx[i]]);
			totalCoin += ali;
		}
		else
		{
			EasyQuery("update user_online set coin = coin + %d where uid = %d;", die, iClientUserID[idx[i]]);
			totalCoin += die;
		}
	}
	
	/*
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsValidClient(i) || iClientUserID[i] < 0)
			continue;
		
		totalPlayer++;
		if(IsPlayerAlive(i))
		{
			EasyQuery("update user_online set coin = coin + %d , online = date_add(online, interval %d second) where uid = %d;",
				gCvarAliveCoin.IntValue, gCvarTime.IntValue, iClientUserID[i]);
			totalCoin += gCvarAliveCoin.IntValue;
		}
		else
		{
			
			EasyQuery("update user_online set coin = coin + %d , online = date_add(online, interval %d second) where uid = %d;",
				gCvarCoin.IntValue, gCvarTime.IntValue, iClientUserID[i]);
			totalCoin += gCvarCoin.IntValue;
		}
	}
	*/
	PrintToServer("[统计] 在线结算 总计 %d 名玩家 获得了 %d 硬币", max, totalCoin);
	
	return Plugin_Continue;
}

/*
public OnGameFrame()
{
	static float time;
	float now = GetEngineTime();
	if(now - time < COIN_GIVE_TIME)
		return;
	time = now;
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsValidClient(i) || iClientUserID[i] < 0)
			continue;
		
		if(IsPlayerAlive(i))
			EasyQuery("update user_online set coin = coin + %d where uid = %d;", gCvarAliveCoin.IntValue, iClientUserID[i]);
		else
			EasyQuery("update user_online set coin = coin + %d where uid = %d;", gCvarCoin.IntValue, iClientUserID[i]);
	}
}
*/

stock log(char[] text, any ...)
{
	char line[1024];
	VFormat(line, 1024, text, 2);
	if(line[0] == '\0')
		return;
	
	static char path[255];
	if(path[0] == '\0')
	{
		char date[128];
		FormatTime(date, 128, "%d%m%y");
		BuildPath(Path_SM, path, 255, "logs/status_%s.log", date);
		if(!FileExists(path))
		{
			File file = OpenFile(path, "a+");
			file.WriteLine("");
			file.Close();
		}
	}
	
	LogToFileEx(path, line);
}

int abs(int number)
{
	if(number < 0)
		return -number;
	return number;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("nmrih_status");
	CreateNative("NMS_GetPoint", Native_GetClientPoint);
	CreateNative("NMS_SetPoint", Native_SetClientPoint);
	CreateNative("NMS_ChangePoint", Native_ChangeClientPoint);
	CreateNative("NMS_GetStatus", Native_GetClientInfo);
	CreateNative("NMS_ChangeStatus", Native_SetClientInfo);
	CreateNative("NMS_GetCoin", Native_GetClientCoin);
	CreateNative("NMS_ChangeCoin", Native_ChangeClientCoin);
	CreateNative("NMS_IsClientValid", Native_IsClientValid);
	
	return APLRes_Success;
}

public int Native_IsClientValid(Handle plugin, int param)
{
	if(param != 1)
		ThrowNativeError(1, "你提供的参数数量不对！");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client) || iClientUserID[client] < 0)
		return false;
	
	return true;
}

public int Native_ChangeClientCoin(Handle plugin, int param)
{
	if(param != 2)
		ThrowNativeError(1, "你提供的参数数量不对！");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client) || iClientUserID[client] < 0)
		ThrowNativeError(1, "你提供的玩家不正确！");
	
	int count = GetNativeCell(2);
	EasyQuery("update user_online set coin = coin + %d where uid = %d;", count, iClientUserID[client]);
	
	if(count < 0)
		EasyQuery("update user_online set used = used + %d where uid = %d;", -count, iClientUserID[client]);
}

public int Native_GetClientCoin(Handle plugin, int param)
{
	if(param != 1)
		ThrowNativeError(1, "你提供的参数数量不对！");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client) || iClientUserID[client] < 0)
		ThrowNativeError(1, "你提供的玩家不正确！");
	
	DBResultSet res = SQLQuery("select coin from user_online where uid = %d;", iClientUserID[client]);
	if(res.RowCount <= 0 || !res.FetchRow())
	{
		res.Close();
		ThrowNativeError(1, "这个玩家没有记录！");
		return 0;
	}
	
	return res.FetchInt(0);
}

public int Native_SetClientInfo(Handle plugin, int param)
{
	if(param != 3)
		ThrowNativeError(1, "你提供的参数数量不对！");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client) || iClientUserID[client] < 0)
		ThrowNativeError(1, "你提供的玩家不正确！");
	
	ChangeClientInfo(client, GetNativeCell(2), GetNativeCell(3));
}

public int Native_GetClientInfo(Handle plugin, int param)
{
	if(param != 1)
		ThrowNativeError(1, "你提供的参数数量不对！");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client) || iClientUserID[client] < 0)
		ThrowNativeError(1, "你提供的玩家不正确！");
	
	return GetClientStatus(client);
}

public int Native_ChangeClientPoint(Handle plugin, int param)
{
	if(param != 2)
		ThrowNativeError(1, "你提供的参数数量不对！");
	
	int client = GetNativeCell(1), count = GetNativeCell(2);
	if(!IsValidClient(client) || iClientUserID[client] < 0)
		ThrowNativeError(1, "你提供的玩家不正确！");
	
	//ChangeClientPoint(client, count);
	ChangeClientInfo(client, point, count);
	
	if(count < 0)
	{
		//ChangeClientUsed(client, count);
		ChangeClientInfo(client, used, -count);
	}
	
	return 0;
}

public int Native_SetClientPoint(Handle plugin, int param)
{
	if(param != 2)
		ThrowNativeError(1, "你提供的参数数量不对！");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client) || iClientUserID[client] < 0)
		ThrowNativeError(1, "你提供的玩家不正确！");
	
	EasyQuery("update nmrih_status set point = %d where uid = %d;", GetNativeCell(2), iClientUserID[client]);
	return 0;
}

public int Native_GetClientPoint(Handle plugin, int param)
{
	if(param != 1)
		ThrowNativeError(1, "你提供的参数数量不对！");
	
	StringMap trie = GetClientStatus(GetNativeCell(1));
	if(trie.Size <= 0)
		return 0;
	
	int tmp;
	trie.GetValue("point", tmp);
	return tmp;
}
