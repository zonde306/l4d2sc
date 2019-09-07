#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <geoip>
#include <geoipcity>

#define PLUGIN_VERSION			"0.1"
#include "modules/l4d2ps.sp"

public Plugin myinfo =
{
	name = "玩家加入提示",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

#define MAX_MODE_NAME		32
#define MAX_MODE_LENGTH		32
new const String:g_szModeName[MAX_MODE_NAME][2][MAX_MODE_LENGTH] =
{
	// 合作类
	{"coop", "战役模式"},
	{"realism", "写实模式"},
	{"mutation4", "绝境求生"},
	{"community5", "死亡之门"},
	{"community1", "特感速递"},
	{"community2", "感染季节"},
	{"mutation2", "猎头者"},
	{"mutation3", "血流不止"},
	{"mutation7", "电锯帮"},
	{"mutation5", "四剑客"},
	{"mutation14", "四分五裂"},
	{"mutation20", "治疗侏儒"},
	{"mutation16", "狩猎盛宴"},
	{"mutation8", "钢铁侠"},
	{"mutation9", "侏儒卫队"},
	{"mutation10", "单人房间"},
	
	// 生存类
	{"survival", "生存模式"},
	{"community4", "写实生存"},
	{"mutation15", "对抗生存"},
	{"holdout", "建造和防御"},
	
	// 对抗类
	{"versus", "对抗模式"},
	{"teamversus", "团队模式"},
	{"community6", "专业对抗"},
	{"mutation11", "没有救赎"},
	{"mutation12", "写实对抗"},
	{"mutation19", "坦克对抗"},
	{"mutation15", "生存对抗"},
	{"mutation18", "失血对抗"},
	{"community3", "乘骑派对"},
	
	// 清道夫类
	{"scavenge", "清道夫模式"},
	{"mutation13", "限量发放"},
	{"teamscavenge", "团队清道夫"},
};

StringMap g_hGameModeList;
ArrayList g_hHostNameList;
char g_szOriginalHostName[255] = {EOS, ...};
ConVar g_hCvarGameMode, g_hCvarDifficulty, g_hCvarHostName;
ConVar g_pCvarConnect, g_pCvarDisconnect, g_pCvarHostName, g_pCvarChangeTeam, g_pCvarNonSteamIdKick;
int g_iOldTeam[MAXPLAYERS+1], g_iNewTeam[MAXPLAYERS+1], g_iPrevTeam[MAXPLAYERS+1];

public void OnPluginStart()
{
	InitPlugin("ch");
	g_pCvarNonSteamIdKick = CreateConVar("l4d2_ch_kick_non_steamid", "1", "没有有效的 SteamID 客户端禁止加入游戏", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarConnect = CreateConVar("l4d2_ch_connect", "31", "玩家加入提示.0=关闭.1=显示名字(必须).2=显示SteamID.4=显示IP地址.8=显示所在国家.16=显示所在城市", CVAR_FLAGS, true, 0.0, true, 31.0);
	g_pCvarDisconnect = CreateConVar("l4d2_ch_disconnect", "63", "玩家离开提示.0=关闭.1=显示名字(必须).2=显示SteamID.4=显示IP地址.8=显示所在国家.16=显示所在城市.32=显示原因", CVAR_FLAGS, true, 0.0, true, 63.0);
	g_pCvarHostName = CreateConVar("l4d2_ch_hostname", "7", "服务器名字设置.0=关闭.1=普通模式(必须).2=显示游戏模式.4=显示游戏难度(如果可以)", CVAR_FLAGS, true, 0.0, true, 7.0);
	g_pCvarChangeTeam = CreateConVar("l4d2_ch_changeteam", "2", "切换队伍提示.0=关闭.1=普通模式.2=延迟模式", CVAR_FLAGS, true, 0.0, true, 2.0);
	AutoExecConfig(true, "l4d2_connect_hint");
	
	g_hGameModeList = CreateTrie();
	g_hHostNameList = CreateArray(255);
	g_hCvarGameMode = FindConVar("mp_gamemode");
	g_hCvarDifficulty = FindConVar("z_difficulty");
	g_hCvarHostName = FindConVar("hostname");
	g_hCvarDifficulty.AddChangeHook(ConVarHook_OnInfoUpdate);
	
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_connect", Event_PlayerConnect);
	HookEvent("player_disconnect", Event_PlayerDisconnect);
	HookEvent("round_start", Event_RoundStart);
	
	// 测试
	RegConsoleCmd("sm_testconn", Cmd_TestConnect);
	RegConsoleCmd("sm_testdisc", Cmd_TestDisconnect);
}

public Action Cmd_TestConnect(int client, int argc)
{
	if(!IsValidClient(client))
		return Plugin_Continue;
	
	Event event = CreateEvent("player_connect");
	event.SetInt("userid", GetClientUserId(client));
	event.SetInt("index", client - 1);
	event.SetInt("bot", IsFakeClient(client));
	
	char steamId[64], name[MAX_NAME_LENGTH];
	GetClientName(client, name, MAX_NAME_LENGTH);
	GetClientAuthId(client, AuthId_Engine, steamId, 64, false);
	event.SetString("networkid", steamId);
	event.SetString("address", "203.15.22.0:27015");
	event.SetString("name", name);
	event.Fire();
	
	return Plugin_Handled;
}

public Action Cmd_TestDisconnect(int client, int argc)
{
	if(!IsValidClient(client))
		return Plugin_Continue;
	
	Event event = CreateEvent("player_disconnect");
	event.SetInt("userid", GetClientUserId(client));
	event.SetInt("index", client - 1);
	event.SetInt("bot", IsFakeClient(client));
	
	char steamId[64], name[MAX_NAME_LENGTH];
	GetClientName(client, name, MAX_NAME_LENGTH);
	GetClientAuthId(client, AuthId_Engine, steamId, 64, false);
	event.SetString("networkid", steamId);
	event.SetString("name", name);
	event.SetString("reason", "测试");
	event.Fire();
	
	return Plugin_Handled;
}

/*
public bool OnClientConnect(int client, char[] kickMessage, int msgLength)
{
	if(!g_pCvarNonSteamIdKick.BoolValue || IsFakeClient(client))
		return true;
	
	char steamId[64];
	if(!GetClientAuthId(client, AuthId_Engine, steamId, 64, false) || steamId[0] == EOS ||
		StrEqual(steamId, "BOT", false) || StrEqual(steamId, "STEAM_1:0:0", false))
	{
		FormatEx(kickMessage, msgLength, "你的 SteamID 无效：%s", steamId);
		return false;
	}
	
	return true;
}
*/

public void OnClientPutInServer(int client)
{
	ClearPlayerTeamInfo(client);
	OnClientPostAdminCheck(client);
}

public void OnClientPostAdminCheck(int client)
{
	if(!g_pCvarNonSteamIdKick.BoolValue || IsFakeClient(client))
		return;
	
	char steamId[64];
	if(!GetClientAuthId(client, AuthId_Engine, steamId, 64, false) || steamId[0] == EOS ||
		StrEqual(steamId, "BOT", false) || StrEqual(steamId, "STEAM_1:0:0", false))
		KickClient(client, "你的 SteamID 无效：%s", steamId);
}

public void OnMapStart()
{
	PrecacheHostNameList();
	PrecacheGameModeList();
	// g_szOriginalHostName[0] = EOS;
	LoadHostName();
}

public void Event_PlayerConnect(Event event, const char[] eventName, bool dontBroadcast)
{
	if(!IsPluginAllow())
		return;
	
	int mode = g_pCvarConnect.IntValue;
	if(event.GetInt("bot") || mode <= 0)
		return;
	
	char steamId[64];
	event.GetString("networkid", steamId, 64);
	if(StrEqual(steamId, "BOT", true))
		return;
	
	char name[MAX_NAME_LENGTH], ip[32];
	event.GetString("name", name, MAX_NAME_LENGTH);
	event.GetString("address", ip, 32);
	SplitString(ip, ":", ip, 32);
	
	char buffer[255];
	if(mode & 1)
		FormatEx(buffer, 255, "\x03[提示]\x01 玩家 \x04%s\x01 ", name);
	else
		FormatEx(buffer, 255, "\x03[提示]\x01 不知名的玩家 ");
	
	if(mode & 2)
		StrCat(buffer, 255, tr("(\x05%s\x01) ", steamId));
	
	StrCat(buffer, 255, "\x04正在连接\x01...");
	PrintToChatAll(buffer);
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(StrContains(ip, "192.168.", false) == 0 || StrEqual(ip, "loopback", false) ||
		StrContains(ip, "0.0.0.", false) == 0)
	{
		if(IsValidClient(client) && (GetUserFlagBits(client) & ADMFLAG_ROOT))
			strcopy(ip, 32, "203.15.22.2");
		else
			return;
	}
	
	buffer[0] = EOS;
	if(mode & 4)
		FormatEx(buffer, 255, "\x05IP:\x01 %s ", ip);
	
	if(mode & 24)
	{
		char country[45], region[45], city[45], code[3], code3[4];
		if(GeoipGetRecord(ip, city, region, country, code, code3))
		{
			if(mode & 8)
				StrCat(buffer, 255, tr("\x04来自于: \x03%s\x01 ", country));
			if(mode & 16)
				StrCat(buffer, 255, tr("\x05%s \x04%s\x01 ", region, city));
		}
	}
	
	if(buffer[0] != EOS)
		PrintToChatAll(buffer);
}

public void Event_PlayerDisconnect(Event event, const char[] eventName, bool dontBroadcast)
{
	if(!IsPluginAllow())
		return;
	
	int mode = g_pCvarDisconnect.IntValue;
	if(event.GetInt("bot") || mode <= 0)
		return;
	
	char steamId[64];
	event.GetString("networkid", steamId, 64);
	if(StrEqual(steamId, "BOT", true))
		return;
	
	char name[MAX_NAME_LENGTH], reason[255], ip[32];
	event.GetString("name", name, MAX_NAME_LENGTH);
	event.GetString("reason", reason, 255);
	ReplaceString(reason, 255, "\n", " ");
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(IsValidClient(client))
		GetClientIP(client, ip, 32, true);
	else
		strcopy(ip, 32, "203.15.22.1");
	
	char buffer[255];
	
	if(mode & 1)
		FormatEx(buffer, 255, "\x03[提示]\x01 玩家 \x04%s\x01 ", name);
	else
		FormatEx(buffer, 255, "\x03[提示]\x01 不知名的玩家 ");
	
	if(mode & 2)
		StrCat(buffer, 255, tr("(\x05%s\x01) ", steamId));
	
	StrCat(buffer, 255, "\x04离开了游戏\x01...");
	PrintToChatAll(buffer);
	
	buffer[0] = EOS;
	if(mode & 32)
	{
		FormatEx(buffer, 255, "\x05原因:\x01 %s", reason);
		PrintToChatAll(buffer);
	}
	
	if(StrContains(ip, "192.168.", false) == 0 || StrEqual(ip, "loopback", false) ||
		StrContains(ip, "0.0.0.", false) == 0)
	{
		if(IsValidClient(client) && (GetUserFlagBits(client) & ADMFLAG_ROOT))
			strcopy(ip, 32, "203.15.22.3");
		else
			return;
	}
	
	buffer[0] = EOS;
	if(mode & 4)
		FormatEx(buffer, 255, "\x05IP:\x01 %s ", ip);
	
	if(mode & 24)
	{
		char country[45], region[45], city[45], code[3], code3[4];
		if(GeoipGetRecord(ip, city, region, country, code, code3))
		{
			if(mode & 8)
				StrCat(buffer, 255, tr("\x04来自于: \x03%s\x01 ", country));
			if(mode & 16)
				StrCat(buffer, 255, tr("\x05%s \x04%s\x01 ", region, city));
		}
	}
	
	if(buffer[0] != EOS)
		PrintToChatAll(buffer);
}

public void Event_PlayerTeam(Event event, const char[] eventName, bool dontBroadcast)
{
	if(!IsPluginAllow())
		return;
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client) || IsFakeClient(client))
		return;
	
	int mode = g_pCvarChangeTeam.IntValue;
	if(event.GetBool("disconnect") || event.GetBool("isbot") || mode <= 0)
		return;
	
	int oldTeam = event.GetInt("oldteam");
	int newTeam = event.GetInt("team");
	
	if(oldTeam == 0 || newTeam == 0)
		return;
	
	if(g_iPrevTeam[client] <= 0)
		g_iPrevTeam[client] = oldTeam;
	g_iOldTeam[client] = oldTeam;
	g_iNewTeam[client] = newTeam;
	
	if(mode == 1)
		ShowPlayerTeam(client);
	else
		RequestFrame(ShowPlayerTeam, client);
}

public void Event_RoundStart(Event event, const char[] eventName, bool dontBroadcast)
{
	if(!IsPluginAllow())
		return;
	
	CreateTimer(1.1, Timer_UpdateHostName);
}

public void ConVarHook_OnInfoUpdate(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	if(!IsPluginAllow())
		return;
	
	LoadHostName();
}

public Action Timer_UpdateHostName(Handle timer, any unused)
{
	if(!IsPluginAllow())
		return Plugin_Stop;
	
	LoadHostName();
	return Plugin_Continue;
}

public void ShowPlayerTeam(any client)
{
	if(g_iPrevTeam[client] == g_iNewTeam[client])
	{
		ClearPlayerTeamInfo(client);
		return;
	}
	
	PrintToChatAll("\x03[提示]\x01 玩家 \x04%N\x01 从 \x05%s\x01 转到了 \x05%s\x01。",
		client, GetTeamNameEx(g_iOldTeam[client]), GetTeamNameEx(g_iNewTeam[client]));
	
	ClearPlayerTeamInfo(client);
}

void ClearPlayerTeamInfo(int client)
{
	g_iPrevTeam[client] = 0;
	g_iOldTeam[client] = 0;
	g_iNewTeam[client] = 0;
}

char GetTeamNameEx(int team, char[] out = "", int outLen = 0)
{
	char buffer[64];
	switch(team)
	{
		case 0:
			strcopy(buffer, 64, "无队伍");
		case 1:
			strcopy(buffer, 64, "观察者");
		case 2:
			strcopy(buffer, 64, "生还者");
		case 3:
			strcopy(buffer, 64, "感染者");
		case 4:
			strcopy(buffer, 64, "幸存者");
	}
	
	if(outLen > 0)
		strcopy(out, outLen, buffer);
	
	return buffer;
}

char GetGameModeName(char[] out = "", int outLen = 0)
{
	char gamemode[32], buffer[64];
	g_hCvarGameMode.GetString(gamemode, 32);
	
	if(!g_hGameModeList.GetString(gamemode, buffer, 64))
	{
		int index = FindGameMode(gamemode);
		if(index != -1)
			strcopy(buffer, 64, g_szModeName[index][1]);
	}
	
	if(outLen > 0)
		strcopy(out, outLen, buffer);
	
	return buffer;
}

int FindGameMode(const char[] modeName)
{
	for(int i = 0; i < MAX_MODE_NAME; ++i)
	{
		if(StrEqual(g_szModeName[i][0], modeName, false))
			return i;
	}
	
	return -1;
}

char GetDifficultyName(char[] out = "", int outLen = 0)
{
	char difficulty[32], buffer[64];
	g_hCvarDifficulty.GetString(difficulty, 32);
	
	if(StrEqual(difficulty, "impossible", false))
		strcopy(buffer, 64, "专家");
	else if(StrEqual(difficulty, "hard", false))
		strcopy(buffer, 64, "困难");
	else if(StrEqual(difficulty, "normal", false))
		strcopy(buffer, 64, "普通");
	else if(StrEqual(difficulty, "easy", false))
		strcopy(buffer, 64, "简单");
	
	if(outLen > 0)
		strcopy(out, outLen, buffer);
	
	return buffer;
}

void LoadHostName()
{
	int mode = g_pCvarHostName.IntValue;
	if(mode <= 0)
		return;
	
	if(g_szOriginalHostName[0] == EOS)
		g_hCvarHostName.GetString(g_szOriginalHostName, 255);
	
	char gamemode[64], difficulty[64], hostname[64];
	GetGameModeName(gamemode, 64);
	GetDifficultyName(difficulty, 64);
	
	if(g_hHostNameList.Length > 0)
	{
		SortADTArray(g_hHostNameList, Sort_Random, Sort_String);
		g_hHostNameList.GetString(0, hostname, 64);
	}
	
	char buffer[128];
	buffer[0] = EOS;
	
	if(mode & 2)
	{
		strcopy(buffer, 128, gamemode);
	}
	
	// 只有合作模式才能选择难度
	if((mode & 4) && g_iGameModeFlags == GMF_COOP)
	{
		if(buffer[0] != EOS)
			StrCat(buffer, 128, "丨");
		StrCat(buffer, 128, difficulty);
	}
	
	if(buffer[0] != EOS)
		Format(buffer, 128, "【%s】", buffer);
	
	if(mode & 1)
		g_hCvarHostName.SetString(tr("%s%s", hostname, buffer));
	else
		g_hCvarHostName.SetString(tr("%s%s", g_szOriginalHostName, buffer));
}

void PrecacheHostNameList()
{
	char hostNamePath[255];
	BuildPath(Path_SM, hostNamePath, 255, "configs/hostname.ini");
	if(!FileExists(hostNamePath))
	{
		File file = OpenFile(hostNamePath, "w");
		file.WriteLine("; 这是服务器名字文件");
		file.WriteLine("; 名字一行一个，有多个会随机选一个");
		file.WriteLine("; 开头带 ; 为注释，会被忽略");
		file.WriteLine("这是一个服务器");
		file.Close();
		return;
	}
	
	char line[255];
	File file = OpenFile(hostNamePath, "r");
	g_hHostNameList.Clear();
	
	while(!file.EndOfFile())
	{
		if(!file.ReadLine(line, 255))
			continue;
		
		SplitString(line, ";", line, 255);
		TrimString(line);
		
		if(line[0] == EOS)
			continue;
		
		g_hHostNameList.PushString(line);
	}
	
	// file.Close();
	delete file;
	LogMessage("total %d hostname cached.", g_hHostNameList.Length);
	PrintToServer("total %d hostname cached.", g_hHostNameList.Length);
}

void PrecacheGameModeList()
{
	char gameModePath[255];
	BuildPath(Path_SM, gameModePath, 255, "data/l4d_votemode.cfg");
	if(!FileExists(gameModePath))
	{
		File file = OpenFile(gameModePath, "w");
		file.WriteLine("\"gamemodes\"");
		file.WriteLine("{");
		file.WriteLine("}");
		file.Close();
		return;
	}
	
	SMCParser parser = new SMCParser();
	SMC_SetReaders(parser, Config_NewSection, Config_KeyValue, Config_EndSection);
	parser.OnEnd = Config_End;
	
	// 错误检查
	g_hGameModeList.Clear();
	parser.ParseFile(gameModePath);
	delete parser;
}

public SMCResult Config_NewSection(Handle parser, const char[] section, bool quotes)
{
	return SMCParse_Continue;
}

public SMCResult Config_KeyValue(Handle parser, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
	g_hGameModeList.SetString(value, key);
	return SMCParse_Continue;
}

public SMCResult Config_EndSection(Handle parser)
{
	return SMCParse_Continue;
}

public void Config_End(Handle parser, bool halted, bool failed)
{
	LogMessage("total %d gamemode cached.", g_hGameModeList.Size);
	PrintToServer("total %d gamemode cached.", g_hGameModeList.Size);
}
