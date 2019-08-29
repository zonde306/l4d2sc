#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <regex>
#include <left4downtown>

#define PLUGIN_VERSION			"1.0"
#define CVAR_FLAGS				FCVAR_NONE
#define IsValidClient(%1) 		((1 <= %1 <= MaxClients) && IsClientInGame(%1))
#define IsValidAliveClient(%1)	(IsValidClient(%1) && IsPlayerAlive(%1))

// #define _USE_NATIVE_VOTE_

#if defined _USE_NATIVE_VOTE_
#include <nativevotes>
// #include "nativevotes/game.sp"
#endif

public Plugin myinfo = 
{
	name = "战役结束换图",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = "http://www.sourcemod.net"
};

enum(<<=1)
{
	GMF_NONE = 0,
	GMF_COOP = (1 << 0),
	GMF_SURVIVAL = (1 << 1),
	GMF_VERSUS = (1 << 2),
	GMF_SCAVENGE = (1 << 4)
};

bool g_bHasFirstMap = true;
float g_fNextVoteAllow = 0.0;
ArrayList g_hVoteMapList, g_hEndMapList;
char g_szNextMap[64], g_szNextMapName[128];
int g_iGameModeFlags, g_iTotalVoted, g_iTotalNeedVote, g_iRoundLosted;
bool g_bHasVoteSkipOuttro[MAXPLAYERS+1], g_bHasFinaleRescue, g_bHasFinaleStart, g_bHasFirstRound;
Handle g_hTimerVoteStarting, g_hTimerChangeMap, g_hTimerCheckGameMode, g_hTimerSupply, g_hTimerIdleChange;
ConVar g_pCvarAllow, g_pCvarGameMode, g_pCvarVoteDelay, g_pCvarStartHeal, g_pCvarStartAmmo, g_pCvarStartWeapon,
	g_pCvarCount, g_pCvarDuration, g_pCvarFaliure, g_pCvarFaliureDelay, g_pCvarForceChange, g_pCvarStartRespawn,
	g_pCvarIdleChange, g_pCvarIdleDelay, g_pCvarIdleMap, g_pCvarStartRevive, g_pCvarVoteInterval, g_pCvarOnlyValve;

public void OnPluginStart()
{
	CreateConVar("l4d2_mp_version", PLUGIN_VERSION, "插件版本", CVAR_FLAGS);
	g_pCvarAllow = CreateConVar("l4d2_mc_allow", "1", "是否开启插件", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarGameMode = CreateConVar("l4d2_mc_allow_mode", "15", "开启插件的模式\n0=禁用.1=战役/写实.2=生存.4=对抗.8=清道夫.15=全部", CVAR_FLAGS, true, 0.0, true, 15.0);
	g_pCvarVoteDelay = CreateConVar("l4d2_mc_vote_delay", "3", "离开安全室多久启动投票选图", CVAR_FLAGS, true, 0.0);
	g_pCvarForceChange = CreateConVar("l4d2_mc_skip_duration", "30", "结束多少秒未完成投票强制换图", CVAR_FLAGS, true, 0.0);
	g_pCvarCount = CreateConVar("l4d2_mc_vote_count", "7", "投票有多少个选项", CVAR_FLAGS, true, 0.0, true, 7.0);
	g_pCvarDuration = CreateConVar("l4d2_mc_vote_duration", "16", "投票持续时间", CVAR_FLAGS, true, 0.0, true, 60.0);
	g_pCvarFaliure = CreateConVar("l4d2_mc_failure", "3", "失败多少次强制换图", CVAR_FLAGS, true, 0.0);
	g_pCvarFaliureDelay = CreateConVar("l4d2_mc_failure_delay", "3", "失败强制换图延迟", CVAR_FLAGS, true, 0.0);
	g_pCvarStartHeal = CreateConVar("l4d2_mc_start_heal", "1", "是否开启开局回血", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarStartAmmo = CreateConVar("l4d2_mc_start_ammo", "1", "是否开启开局补子弹", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarStartWeapon = CreateConVar("l4d2_mc_start_weapon", "1", "是否开启开局给武器", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarStartRespawn = CreateConVar("l4d2_mc_respawn", "1", "是否开启开局复活死亡玩家", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarStartRevive = CreateConVar("l4d2_mc_revive", "1", "是否开启开局救起倒地玩家", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarIdleChange = CreateConVar("l4d2_mc_idle_change", "1", "是否开启没人时换成官图", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarIdleDelay = CreateConVar("l4d2_mc_idle_delay", "120", "没人多少秒换成官图", CVAR_FLAGS, true, 0.0);
	g_pCvarIdleMap = CreateConVar("l4d2_mc_idle_map", "c2m1_highway", "没人换成官图的地图", CVAR_FLAGS);
	g_pCvarVoteInterval = CreateConVar("l4d2_mc_vote_interval", "120", "两次投票最小间隔", CVAR_FLAGS, true, 0.0);
	g_pCvarOnlyValve = CreateConVar("l4d2_mc_autovote_valve", "1", "自动投票选图只有官图", CVAR_FLAGS, true, 0.0, true, 1.0);
	AutoExecConfig(true, "l4d2_map_changer");
	
	g_hVoteMapList = CreateArray();
	g_hEndMapList = CreateArray(64);
	
	RegConsoleCmd("sm_votemap", Command_VoteMapMenu);
	RegConsoleCmd("sm_mapvote", Command_VoteMapMenu);
	RegConsoleCmd("sm_nextmap", Command_NextMap);
	
	AddCommandListener(Command_SkipOuttro, "SkipOuttro");
	AddCommandListener(Command_OuttroDone, "outtro_stats_done");
	
	HookEvent("round_start", Event_RoundStart);
	HookEvent("finale_win", Event_FinalWin);
	HookEvent("finale_start", Event_FinalStart);
	HookEvent("finale_rush", Event_FinalStart);
	HookEvent("finale_escape_start", Event_FinalStart);
	HookEvent("finale_vehicle_ready", Event_FinalStart);
	HookEvent("finale_radio_start", Event_FinalStart);
	HookEvent("mission_lost", Event_FinalLost);
	HookEvent("final_reportscreen", Event_FinalReport);
	HookEvent("player_left_start_area", Event_StartPlay);
	HookEvent("player_first_spawn", Event_RoundStartEx);
}

public void OnMapStart()
{
	g_szNextMap[0] = EOS;
	g_szNextMapName[0] = EOS;
	g_iTotalVoted = 0;
	g_iTotalNeedVote = 65535;
	g_bHasFinaleRescue = false;
	g_iRoundLosted = 0;
	g_hTimerVoteStarting = null;
	g_bHasFinaleStart = false;
	g_hTimerChangeMap = null;
	g_hTimerIdleChange = null;
	g_bHasFirstRound = true;
	g_fNextVoteAllow = 0.0;
	
	g_hEndMapList.Clear();
	g_hVoteMapList.Clear();
	LoadVoteMapList();
	
	if(g_bHasFirstMap)
	{
		g_bHasFirstMap = false;
		CheckEmptyServer(0);
	}
}

public void OnMapEnd()
{
	if(g_hTimerChangeMap != null)
	{
		KillTimer(g_hTimerChangeMap);
		g_hTimerChangeMap = null;
	}
	
	if(g_hTimerIdleChange != null)
	{
		KillTimer(g_hTimerIdleChange);
		g_hTimerIdleChange = null;
	}
}

public void OnClientDisconnect(int client)
{
	if(!IsPluginAllow() || IsFakeClient(client))
		return;
	
	RequestFrame(CheckEmptyServer);
	
	if(g_bHasFinaleRescue && !g_bHasVoteSkipOuttro[client])
		Command_SkipOuttro(client, "SkipOuttro", 0);
}

public void OnClientConnected(int client)
{
	if(IsFakeClient(client))
		return;
	
	if(g_hTimerIdleChange != null)
	{
		KillTimer(g_hTimerIdleChange);
		g_hTimerIdleChange = null;
		PrintToServer("server not empty...");
	}
}

public void CheckEmptyServer(any unused)
{
	if(!g_pCvarIdleChange.BoolValue)
		return;
	
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidClient(i) || IsFakeClient(i))
			continue;
		
		return;
	}
	
	if(g_hTimerIdleChange == null)
		g_hTimerIdleChange = CreateTimer(g_pCvarIdleDelay.FloatValue, Timer_ChangeLevelEmpty);
	
	PrintToServer("server is empty...");
}

public Action Timer_ChangeLevelEmpty(Handle timer, any unused)
{
	g_hTimerIdleChange = null;
	
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidClient(i) || IsFakeClient(i))
			continue;
		
		return Plugin_Stop;
	}
	
	char map[64];
	g_pCvarIdleMap.GetString(map, 64);
	ServerCommand("changelevel %s", map);
	return Plugin_Continue;
}

public Action Command_NextMap(int client, int argc)
{
	if(!IsPluginAllow())
		return Plugin_Continue;
	
	if(!IsValidClient(client))
	{
		ReplyToCommand(client, "nextmap: %s", g_szNextMap);
		return Plugin_Continue;
	}
	
	if(g_szNextMapName[0] != EOS)
	{
		PrintToChat(client, "\x03[提示]\x01 下一张地图：\x05%s", g_szNextMapName);
		PrintToChat(client, "\x03[提示]\x01 聊天框输入 \x04!mapvote\x01 可以投票立即换图。");
	}
	else
	{
		PrintToChat(client, "\x03[提示]\x01 下一张地图未选择。");
		PrintToChat(client, "\x03[提示]\x01 聊天框输入 \x04!mapvote\x01 可以投票选图。");
	}
	
	return Plugin_Continue;
}

public Action Command_VoteMapMenu(int client, int argc)
{
	if(!IsPluginAllow())
		return Plugin_Continue;
	
	if(!IsValidClient(client))
	{
		ReplyToCommand(client, "Commands may only be used in-game on a dedicated server...");
		return Plugin_Continue;
	}
	
	if(g_bHasFinaleRescue)
	{
		PrintToChat(client, "\x03[提示]\x01 现在无法发起投票。");
		return Plugin_Continue;
	}
	
	float time = GetEngineTime();
	if(g_szNextMap[0] == EOS || g_szNextMapName[0] == EOS)
	{
		ShowMapListMenu(client);
		// Timer_StartVoteMapEx(null, 0);
		// PrintToChatAll("\x03[提示]\x01 玩家 \x04%N\x01 发起了 \x05选择地图\x01 投票。", client);
	}
	else if(g_fNextVoteAllow <= time)
	{
		Timer_StartForceChangeVote(null, 0);
		g_fNextVoteAllow = time + g_pCvarVoteInterval.FloatValue;
		PrintToChatAll("\x03[提示]\x01 玩家 \x04%N\x01 发起了 \x05更换地图\x01 投票。", client);
	}
	else
	{
		PrintToChat(client, "\x03[提示]\x01 无法连续进行投票，请等一会再试。");
		return Plugin_Continue;
	}
	
	return Plugin_Continue;
}

public Action Command_SkipOuttro(int client, const char[] command, int argc)
{
	if(!IsPluginAllow())
		return Plugin_Continue;
	
	if(!g_bHasFinaleRescue || !g_bHasFinaleStart)
		return Plugin_Continue;
	
	if(client < 1 || client > MaxClients)
		return Plugin_Continue;
	
	if(g_bHasVoteSkipOuttro[client])
		return Plugin_Continue;
	
	++g_iTotalVoted;
	g_bHasVoteSkipOuttro[client] = true;
	
	if(g_iTotalVoted >= g_iTotalNeedVote)
	{
		if(g_hTimerChangeMap != null)
			KillTimer(g_hTimerChangeMap);
		
		g_hTimerChangeMap = CreateTimer(0.1, Timer_ChangeLevel);
		PrintToChatAll("\x03[提示]\x01 投票完成，更换地图：\x05%s", g_szNextMapName);
	}
	else
	{
		PrintToChatAll("\x03[提示]\x01 投票进度：\x05%d\x01/\x04%d\x01。", g_iTotalVoted, g_iTotalNeedVote);
	}
	
	return Plugin_Continue;
}

public Action Command_OuttroDone(int client, const char[] command, int argc)
{
	if(g_hTimerChangeMap != null)
		KillTimer(g_hTimerChangeMap);
	
	Timer_ChangeLevel(null, 0);
	PrintToChatAll("\x03[提示]\x01 展示结束，更换地图：\x05%s", g_szNextMapName);
	return Plugin_Continue;
}

public void Event_RoundStart(Event event, const char[] eventName, bool dontBroadcast)
{
	if(g_hTimerCheckGameMode != null)
		KillTimer(g_hTimerCheckGameMode);
	
	if(g_hTimerSupply != null)
		KillTimer(g_hTimerSupply);
	
	g_hTimerCheckGameMode = CreateTimer(1.0, Timer_CheckGameMode);
	g_hTimerSupply = CreateTimer(1.5, Timer_GivePlayerItem);
}

public void Event_RoundStartEx(Event event, const char[] eventName, bool dontBroadcast)
{
	if(!IsPluginAllow())
		return;
	
	if(!g_bHasFirstRound)
		return;
	
	if(g_hTimerSupply != null)
		KillTimer(g_hTimerSupply);
	
	g_bHasFirstRound = false;
	g_hTimerSupply = CreateTimer(1.5, Timer_GivePlayerItem);
}

public Action Timer_GivePlayerItem(Handle timer, any unused)
{
	g_hTimerSupply = null;
	
	if(!IsPluginAllow())
		return Plugin_Continue;
	
	bool heal = g_pCvarStartHeal.BoolValue;
	bool ammo = g_pCvarStartAmmo.BoolValue;
	bool weapon = g_pCvarStartWeapon.BoolValue;
	bool respawn = g_pCvarStartRespawn.BoolValue;
	bool revive = g_pCvarStartRevive.BoolValue;
	
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidClient(i) || GetClientTeam(i) != 2)
			continue;
		
		if(respawn)
			CheatCommand(i, "script", "GetPlayerFromUserID(%d).ReviveByDefib()", GetClientUserId(i));
		if(revive)
			CheatCommand(i, "script", "GetPlayerFromUserID(%d).ReviveFromIncap()", GetClientUserId(i));
		if(weapon)
			GiveRandomWeapon(i);
		if(ammo)
			CheatCommand(i, "give", "ammo");
		if(heal)
			GiveFullHealth(i);
	}
	
	return Plugin_Continue;
}

void GiveRandomWeapon(int client)
{
	if(GetPlayerWeaponSlot(client, 0) != -1)
		return;
	
	SetRandomSeed(client + RoundFloat(GetGameTime()));
	int number = GetRandomInt(1, 6);
	switch(number)
	{
		case 1:
			CheatCommand(client, "give", "smg");
		case 2:
			CheatCommand(client, "give", "smg_silenced");
		case 3:
			CheatCommand(client, "give", "pumpshotgun");
		case 4:
			CheatCommand(client, "give", "shotgun_chrome");
		case 5:
			CheatCommand(client, "give", "smg_mp5");
		case 6:
			CheatCommand(client, "give", "sniper_scout");
	}
}

void GiveFullHealth(int client)
{
	int maxHealth = GetEntProp(client, Prop_Data, "m_iMaxHealth");
	SetEntProp(client, Prop_Data, "m_iHealth", maxHealth);
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", 0.0);
	SetEntProp(client, Prop_Send, "m_currentReviveCount", 0);
	SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 0);
}

public Action L4D2_OnChangeFinaleStage(int& finaleType, const char[] arg)
{
	if(finaleType == 1)
		Event_FinalStart(null, "", false);
}

public void Event_FinalLost(Event event, const char[] eventName, bool dontBroadcast)
{
	if(!IsPluginAllow())
		return;
	
	if(!g_bHasFinaleStart)
		return;
	
	++g_iRoundLosted;
	int count = g_pCvarFaliure.IntValue;
	PrintToChatAll("\x03[提示]\x01 救援关失败：\x05%d\x01/\x04%d\x01。", g_iRoundLosted, g_pCvarFaliure.IntValue);
	
	if(count <= 0)
		return;
	
	if(g_iRoundLosted >= count && g_hTimerChangeMap == null)
		g_hTimerChangeMap = CreateTimer(g_pCvarFaliureDelay.FloatValue, Timer_ChangeLevel);
}

public void Event_FinalStart(Event event, const char[] eventName, bool dontBroadcast)
{
	if(!IsPluginAllow())
		return;
	
	g_bHasFinaleStart = true;
	if((g_szNextMap[0] == EOS || g_szNextMapName[0] == EOS) && g_hTimerVoteStarting == null)
		g_hTimerVoteStarting = CreateTimer(g_pCvarVoteDelay.FloatValue, Timer_StartVoteMap);
}

public void Event_FinalWin(Event event, const char[] eventName, bool dontBroadcast)
{
	if(!IsPluginAllow())
		return;
	
	g_bHasFinaleRescue = true;
	for(int i = 1; i <= MaxClients; ++i)
		g_bHasVoteSkipOuttro[i] = false;
	
	if(g_hTimerChangeMap != null)
		KillTimer(g_hTimerChangeMap);
	
	if(g_szNextMap[0] == EOS)
		g_pCvarIdleMap.GetString(g_szNextMap, sizeof(g_szNextMap));
	
	g_hTimerChangeMap = CreateTimer(g_pCvarForceChange.FloatValue, Timer_ChangeLevel);
	
	g_iTotalVoted = 0;
	g_iTotalNeedVote = 0;
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(IsValidClient(i) && !IsFakeClient(i))
			++g_iTotalNeedVote;
	}
	
	if(g_szNextMapName[0] != EOS)
		PrintToChatAll("\x03[提示]\x01 下一张地图：\x05%s", g_szNextMapName);
}

public Action Timer_ChangeLevel(Handle timer, any unused)
{
	g_hTimerChangeMap = null;
	
	if(g_szNextMap[0] == EOS)
		g_pCvarIdleMap.GetString(g_szNextMap, sizeof(g_szNextMap));
	
	ServerCommand("changelevel %s", g_szNextMap);
	return Plugin_Continue;
}

public void Event_FinalReport(Event event, const char[] eventName, bool dontBroadcast)
{
	if(!IsPluginAllow())
		return;
	
	g_bHasFinaleRescue = true;
	for(int i = 1; i <= MaxClients; ++i)
		g_bHasVoteSkipOuttro[i] = false;
}

public void Event_StartPlay(Event event, const char[] eventName, bool dontBroadcast)
{
	if(!IsPluginAllow())
		return;
	
	char current[64];
	GetCurrentMap(current, 64);
	if(g_hEndMapList.FindString(current) == -1 && FindFinaleEntity() == -1)
		return;
	
	if((g_szNextMap[0] == EOS || g_szNextMapName[0] == EOS) && g_hTimerVoteStarting == null)
		g_hTimerVoteStarting = CreateTimer(g_pCvarVoteDelay.FloatValue, Timer_StartVoteMap);
}

public Action Timer_StartVoteMap(Handle timer, any unused)
{
	g_hTimerVoteStarting = null;
	SortADTArray(g_hVoteMapList, Sort_Random, Sort_Integer);
	
	int count = g_pCvarCount.IntValue;
	if(count > g_hVoteMapList.Length)
		count = g_hVoteMapList.Length;
	
	Menu menu = CreateMenu(MenuHandler_VoteMap);
	menu.SetTitle("投票选择下一个战役");
	
	char current[64];
	GetCurrentMap(current, 64);
	
	StringMap map = null;
	char info[64], display[128], end[64];
	bool onlyValve = g_pCvarOnlyValve.BoolValue;
	for(int i = 0; i < count && menu.ItemCount < count; ++i)
	{
		map = view_as<StringMap>(g_hVoteMapList.Get(i));
		if(map == null)
			continue;
		
		if(!map.GetString("display", display, 128) ||
			!map.GetString("start", info, 64))
			continue;
		
		if(map.GetString("end", end, 64) && StrEqual(end, current, false))
		{
			// --i;
			continue;
		}
		
		if(onlyValve)
		{
			static Regex re;
			if(re == null)
				re = CompileRegex("^[cC](?:[1-9]|1[0123])[mM][1-5]_[a-zA-Z0-9_]+$");
			
			if(re.Match(info) < 1)
			{
				// --i;
				continue;
			}
		}
		
		menu.AddItem(info, display);
	}
	
	menu.ExitButton = false;
	menu.ExitBackButton = false;
	
	if(menu.ItemCount <= 0)
		PrintToChatAll("\x03[提示]\x01 没有地图可投票。");
	else
		menu.DisplayVoteToAll(g_pCvarDuration.IntValue);
	
	return Plugin_Continue;
}

void ShowMapListMenu(int client)
{
	SortADTArray(g_hVoteMapList, Sort_Random, Sort_Integer);
	
	int count = g_hVoteMapList.Length;
	Menu menu = CreateMenu(MenuHandler_SelectMap);
	menu.SetTitle("选择一个战役");
	
	char current[64];
	GetCurrentMap(current, 64);
	
	StringMap map = null;
	char info[64], display[128], end[64];
	for(int i = 0; i < count; ++i)
	{
		map = view_as<StringMap>(g_hVoteMapList.Get(i));
		if(map == null)
			continue;
		
		if(!map.GetString("display", display, 128) ||
			!map.GetString("start", info, 64))
			continue;
		
		if(map.GetString("end", end, 64) && StrEqual(end, current, false))
		{
			// --i;
			continue;
		}
		
		menu.AddItem(info, display);
	}
	
	menu.ExitButton = true;
	menu.ExitBackButton = false;
	
	if(menu.ItemCount <= 0)
		PrintToChatAll("\x03[提示]\x01 没有地图可选择。");
	else
		menu.Display(client, MENU_TIME_FOREVER);
}

public Action Timer_StartForceChangeVote(Handle timer, any unused)
{
	if(g_szNextMap[0] == EOS || g_szNextMapName[0] == EOS)
		return Plugin_Continue;
	
#if defined _USE_NATIVE_VOTE_
	NativeVote nv = NativeVotes_Create(MenuHandler_VoteChangeMap,
		NativeVotesType_ChgCampaign, NATIVEVOTES_ACTIONS_DEFAULT);
	nv.SetTitle("投票换图：%s", g_szNextMapName);
	nv.SetDetails(g_szNextMapName);
	nv.DisplayVoteToAll(g_pCvarDuration.IntValue);
#else
	Menu menu = CreateMenu(MenuHandler_VoteChangeMap);
	menu.SetTitle("投票立即更换战役\n%s", g_szNextMapName);
	menu.AddItem("yes", "同意");
	menu.AddItem("no", "反对");
	menu.ExitButton = false;
	menu.ExitBackButton = false;
	menu.DisplayVoteToAll(g_pCvarDuration.IntValue);
#endif
	
	return Plugin_Continue;
}

public int MenuHandler_VoteMap(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_VoteCancel)
	{
		if(param1 != VoteCancel_NoVotes)
		{
			PrintToChatAll("\x03[提示]\x01 取消投票选地图。");
			return 0;
		}
		
		// 无人投票，随机选择一项
		param1 = GetRandomInt(0, menu.ItemCount - 1);
	}
	else if(action != MenuAction_VoteEnd)
		return 0;
	
	menu.GetItem(param1, g_szNextMap, 64, _, g_szNextMapName, 128);
	PrintToChatAll("\x03[提示]\x01 下一张地图：\x05%s", g_szNextMapName);
	PrintToChatAll("\x03[提示]\x01 下一张地图已选择，聊天框输入 \x04!mapvote\x01 可以投票立即换图。");
	return 0;
}

public int MenuHandler_SelectMap(Menu menu, MenuAction action, int client, int selected)
{
	if(action != MenuAction_Select)
		return 0;
	
	char map[64], mapName[128];
	menu.GetItem(selected, map, 64, _, mapName, 128);
	
#if defined _USE_NATIVE_VOTE_
	NativeVote nv = NativeVotes_Create(MenuHandler_VoteChangeMap2,
		NativeVotesType_ChgCampaign, NATIVEVOTES_ACTIONS_DEFAULT);
	nv.SetTitle("投票换图：%s", mapName);
	nv.SetDetails(mapName);
	nv.SetString("map", map);
	nv.SetString("mapname", mapName);
	nv.DisplayVoteToAll(g_pCvarDuration.IntValue);
#else
	Menu m = CreateMenu(MenuHandler_VoteChangeMap2);
	m.SetTitle("投票更换战役\n%s", mapName);
	m.AddItem(map, "同意");
	m.AddItem("no", "反对");
	m.ExitButton = false;
	m.ExitBackButton = false;
	m.DisplayVoteToAll(g_pCvarDuration.IntValue);
#endif

	return 0;
}

#if defined _USE_NATIVE_VOTE_
public int MenuHandler_VoteChangeMap(NativeVote menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_VoteCancel)
	{
		if(param1 == VoteCancel_NoVotes)
		{
			menu.DisplayFail(NativeVotesFail_NotEnoughVotes);
			PrintToChatAll("\x03[提示]\x01 投票人数不足，不进行换图。");
		}
		else
		{
			menu.DisplayFail(NativeVotesFail_Generic);
			PrintToChatAll("\x03[提示]\x01 取消投票换地图。");
		}
		
		// 无人投票不换图
		return 0;
	}
	else if(action == MenuAction_End)
	{
		menu.Close();
		return 0;
	}
	else if(action != MenuAction_VoteEnd)
		return 0;
	
	if(param1 != 0 || g_szNextMap[0] == EOS || g_szNextMapName[0] == EOS)
	{
		PrintToChatAll("\x03[提示]\x01 投票立即换图失败。");
		menu.DisplayFail(NativeVotesFail_Loses);
		return 0;
	}
	
	menu.DisplayPassEx(NativeVotesPass_ChgCampaign, "更换地图：\x05%s", g_szNextMapName);
	// menu.DisplayPass("更换地图：\x05%s", g_szNextMapName);
	
	if(g_hTimerChangeMap != null)
		KillTimer(g_hTimerChangeMap);
	
	g_hTimerChangeMap = CreateTimer(3.0, Timer_ChangeLevel);
	PrintToChatAll("\x03[提示]\x01 投票通过，更换地图：\x05%s", g_szNextMapName);
	return 0;
}

public int MenuHandler_VoteChangeMap2(NativeVote menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_VoteCancel)
	{
		if(param1 == VoteCancel_NoVotes)
		{
			menu.DisplayFail(NativeVotesFail_NotEnoughVotes);
			PrintToChatAll("\x03[提示]\x01 投票人数不足，不进行换图。");
		}
		else
		{
			menu.DisplayFail(NativeVotesFail_Generic);
			PrintToChatAll("\x03[提示]\x01 取消投票换地图。");
		}
		
		// 无人投票不换图
		return 0;
	}
	else if(action == MenuAction_End)
	{
		menu.Close();
		return 0;
	}
	else if(action != MenuAction_VoteEnd)
		return 0;
	
	char map[64], mapName[128];
	menu.GetString("map", map);
	menu.GetString("mapname", mapName);
	
	if(param1 != 0 || map[0] == EOS || mapName[0] == EOS)
	{
		PrintToChatAll("\x03[提示]\x01 投票立即换图失败。");
		menu.DisplayFail(NativeVotesFail_Loses);
		return 0;
	}
	
	menu.DisplayPassEx(NativeVotesPass_ChgCampaign, "更换地图：\x05%s", mapName);
	// menu.DisplayPass("更换地图：\x05%s", g_szNextMapName);
	
	if(g_hTimerChangeMap != null)
		KillTimer(g_hTimerChangeMap);
	
	strcopy(g_szNextMap, sizeof(g_szNextMap), map);
	g_hTimerChangeMap = CreateTimer(3.0, Timer_ChangeLevel);
	PrintToChatAll("\x03[提示]\x01 投票通过，更换地图：\x05%s", mapName);
	return 0;
}

#else

public int MenuHandler_VoteChangeMap(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_VoteCancel)
	{
		if(param1 != VoteCancel_NoVotes)
		{
			PrintToChatAll("\x03[提示]\x01 取消投票换地图。");
			return 0;
		}
		
		// 无人投票不换图
		return 0;
	}
	else if(action != MenuAction_VoteEnd)
		return 0;
	
	if(param1 != 0 || g_szNextMap[0] == EOS || g_szNextMapName[0] == EOS)
	{
		PrintToChatAll("\x03[提示]\x01 投票立即换图不通过。");
		return 0;
	}
	
	if(g_hTimerChangeMap != null)
		KillTimer(g_hTimerChangeMap);
	
	g_hTimerChangeMap = CreateTimer(3.0, Timer_ChangeLevel);
	PrintToChatAll("\x03[提示]\x01 投票通过，更换地图：\x05%s", g_szNextMapName);
	return 0;
}

public int MenuHandler_VoteChangeMap2(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_VoteCancel)
	{
		if(param1 != VoteCancel_NoVotes)
		{
			PrintToChatAll("\x03[提示]\x01 取消投票换地图。");
			return 0;
		}
		
		// 无人投票不换图
		return 0;
	}
	else if(action != MenuAction_VoteEnd)
		return 0;
	
	char map[64], mapName[128];
	menu.GetItem(param1, map, 64);
	menu.GetTitle(mapName, 128);
	ReplaceString(mapName, 128, "投票更换战役\n", "", false);
	
	if(param1 != 0 || map[0] == EOS || mapName[0] == EOS)
	{
		PrintToChatAll("\x03[提示]\x01 投票立即换图不通过。");
		return 0;
	}
	
	if(g_hTimerChangeMap != null)
		KillTimer(g_hTimerChangeMap);
	
	strcopy(g_szNextMap, sizeof(g_szNextMap), map);
	g_hTimerChangeMap = CreateTimer(3.0, Timer_ChangeLevel);
	PrintToChatAll("\x03[提示]\x01 投票通过，更换地图：\x05%s", mapName);
	return 0;
}

#endif

void LoadVoteMapList()
{
	char path[255];
	BuildPath(Path_SM, path, 255, "data/l4d2_map_changer.ini");
	if(!FileExists(path))
		return;
	
	StringMap map = null;
	char line[255], keyValue[2][128];
	File file = OpenFile(path, "r");
	while(!file.EndOfFile())
	{
		if(!file.ReadLine(line, 255))
			continue;
		
		SplitString(line, ";", line, 255);
		TrimString(line);
		
		if(line[0] == '[' && line[strlen(line) - 1] == ']')
		{
			if(map != null)
			{
				if(map.GetString("display", "", 0) && map.GetString("start", "", 0))
					g_hVoteMapList.Push(map);
				
				if(map.GetString("end", keyValue[1], 128))
					g_hEndMapList.PushString(keyValue[1]);
			}
			
			map = CreateTrie();
			continue;
		}
		
		if(map == null)
			continue;
		
		if(FindCharInString(line, '=') > -1)
		{
			ExplodeString(line, "=", keyValue, 2, 128);
			ReplaceString(keyValue[0], 128, "\"", "");
			ReplaceString(keyValue[1], 128, "\"", "");
			TrimString(keyValue[0]);
			TrimString(keyValue[1]);
			map.SetString(keyValue[0], keyValue[1]);
		}
	}
	file.Close();
	
	if(map != null)
	{
		if(map.GetString("display", "", 0) && map.GetString("start", "", 0))
			g_hVoteMapList.Push(map);
		
		if(map.GetString("end", keyValue[1], 128))
			g_hEndMapList.PushString(keyValue[1]);
	}
	
	PrintToServer("LoadVoteMapList: got %d maps", g_hVoteMapList.Length);
}

bool IsPluginAllow()
{
	if(!g_pCvarAllow.BoolValue)
		return false;
	
	if(!(g_pCvarGameMode.IntValue & g_iGameModeFlags))
		return false;
	
	return true;
}

public Action Timer_CheckGameMode(Handle timer, any unused)
{
	g_hTimerCheckGameMode = null;
	
	int entity = CreateEntityByName("info_gamemode");
	if(!IsValidEntity(entity))
		return Plugin_Continue;
	
	DispatchSpawn(entity);
	HookSingleEntityOutput(entity, "OnCoop", OnOutput_OnGamemode, true);
	HookSingleEntityOutput(entity, "OnSurvival", OnOutput_OnGamemode, true);
	HookSingleEntityOutput(entity, "OnVersus", OnOutput_OnGamemode, true);
	HookSingleEntityOutput(entity, "OnScavenge", OnOutput_OnGamemode, true);
	AcceptEntityInput(entity, "PostSpawnActivate");
	AcceptEntityInput(entity, "Kill");
	return Plugin_Continue;
}

public void OnOutput_OnGamemode(const char[] output, int caller, int activator, float delay)
{
	switch(output[3])
	{
		case 'o':
			g_iGameModeFlags = GMF_COOP;
		case 'u':
			g_iGameModeFlags = GMF_SURVIVAL;
		case 'e':
			g_iGameModeFlags = GMF_VERSUS;
		case 'c':
			g_iGameModeFlags = GMF_SCAVENGE;
		default:
			g_iGameModeFlags = GMF_NONE;
	}
}

stock bool CheatCommand(int client = 0, const char[] command, const char[] arguments = "", any ...)
{
	char fmt[1024];
	VFormat(fmt, 1024, arguments, 4);

	int cmdFlags = GetCommandFlags(command);
	SetCommandFlags(command, cmdFlags & ~FCVAR_CHEAT);

	if(IsValidClient(client))
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

stock bool CheatCommandEx(int client = 0, const char[] command, const char[] arguments = "", any ...)
{
	char fmt[1024];
	VFormat(fmt, 1024, arguments, 4);

	int cmdFlags = GetCommandFlags(command);
	SetCommandFlags(command, cmdFlags & ~FCVAR_CHEAT);

	if(IsValidClient(client))
	{
		int adminFlags = GetUserFlagBits(client);
		SetUserFlagBits(client, ADMFLAG_ROOT);
		FakeClientCommand(client, "%s %s", command, fmt);
		SetUserFlagBits(client, adminFlags);
	}
	else
	{
		ServerCommand("%s %s", command, fmt);
	}

	SetCommandFlags(command, cmdFlags);

	return true;
}

int FindFinaleEntity()
{
	return FindEntityByClassname(-1, "trigger_finale");
}
