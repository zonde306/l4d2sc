#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION			"0.1"
#include "modules/l4d2ps.sp"

public Plugin myinfo =
{
	name = "伪装模式",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

bool g_bLateLoad;
ConVar g_hCvarHostName, g_hCvarLan, g_hCvarMaxPlayers;
ConVar g_pCvarMinPing, g_pCvarMaxPing, g_pCvarOffsetPing, g_pCvarMaxHealth, g_pCvarStatus, g_pCvarServer,
	g_pCvarMinPlayTime, g_pCvarMaxPlayTime, g_pCvarVersion;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	InitPlugin("fs");
	
	g_pCvarMinPing = CreateConVar("l4d2_fs_min_ping", "35", "最小 ping 值", CVAR_FLAGS, true, 0.0, true, 999.0);
	g_pCvarMaxPing = CreateConVar("l4d2_fs_max_ping", "65", "最大 ping 值", CVAR_FLAGS, true, 0.0, true, 999.0);
	g_pCvarOffsetPing = CreateConVar("l4d2_fs_offset_ping", "15", "ping 差异", CVAR_FLAGS, true, 0.0, true, 999.0);
	g_pCvarMaxHealth = CreateConVar("l4d2_fs_fake_health", "1", "是否缩放血量上限到 100", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarStatus = CreateConVar("l4d2_fs_fake_status", "1", "是否伪装 status 命令", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarServer = CreateConVar("l4d2_fs_fake_server", "Linux Listen", "伪装 status 中的服务器内容", CVAR_FLAGS);
	g_pCvarMinPlayTime = CreateConVar("l4d2_fs_min_playtime", "", "伪装 status 中的在线时间最小值", CVAR_FLAGS, true, 0.0, true, 2147483647.0);
	g_pCvarMaxPlayTime = CreateConVar("l4d2_fs_max_playtime", "", "伪装 status 中的在线时间最小值", CVAR_FLAGS, true, 0.0, true, 2147483647.0);
	g_pCvarVersion = CreateConVar("l4d2_fs_fake_version", "", "伪装 status 中的游戏版本", CVAR_FLAGS);
	
	AutoExecConfig(true, "l4d2_fake_server");
	
	g_hCvarHostName = FindConVar("hostname");
	g_hCvarLan = FindConVar("sv_lan");
	g_hCvarMaxPlayers = FindConVar("sv_visiblemaxplayers");
	AddCommandListener(Command_Status, "status");
	RegAdminCmd("sm_status", Command_Status2, ADMFLAG_ROOT);
	
	CvarHook_OnChanged(null, "", "");
	g_pCvarMinPing.AddChangeHook(CvarHook_OnChanged);
	g_pCvarMaxPing.AddChangeHook(CvarHook_OnChanged);
	g_pCvarOffsetPing.AddChangeHook(CvarHook_OnChanged);
	g_pCvarMaxHealth.AddChangeHook(CvarHook_OnChanged);
	g_pCvarStatus.AddChangeHook(CvarHook_OnChanged);
	g_pCvarServer.AddChangeHook(CvarHook_OnChanged);
	g_pCvarMinPlayTime.AddChangeHook(CvarHook_OnChanged);
	g_pCvarMaxPlayTime.AddChangeHook(CvarHook_OnChanged);
	
	if(g_bLateLoad)
	{
		int entity = FindEntityByClassname(MaxClients + 1, "terror_player_manager");
		if(entity > MaxClients)
			SDKHook(entity, SDKHook_ThinkPost, EntityHook_ThinkPost);
		entity = FindEntityByClassname(MaxClients + 1, "player_manager");
		if(entity > MaxClients)
			SDKHook(entity, SDKHook_ThinkPost, EntityHook_ThinkPost);
	}
}

bool g_bReplaceStatus, g_bScaleHealth;
char g_sStatusServer[64], g_sStatusVersion[64];
int g_iMinPing, g_iMaxPing, g_iOffsetPing, g_iMinPlayTime, g_iMaxPlayTime;

public void CvarHook_OnChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	g_iMinPing = g_pCvarMinPing.IntValue;
	g_iMaxPing = g_pCvarMaxPing.IntValue;
	g_iOffsetPing = g_pCvarOffsetPing.IntValue;
	g_bScaleHealth = g_pCvarMaxHealth.BoolValue;
	g_bReplaceStatus = g_pCvarStatus.BoolValue;
	g_pCvarServer.GetString(g_sStatusServer, sizeof(g_sStatusServer));
	g_iMinPlayTime = g_pCvarMinPlayTime.IntValue;
	g_iMaxPlayTime = g_pCvarMaxPlayTime.IntValue;
	g_pCvarVersion.GetString(g_sStatusVersion, sizeof(g_sStatusVersion));
}

bool g_bFakeClient[MAXPLAYERS+1][MAXPLAYERS+1];
int g_iClientPing[MAXPLAYERS+1], g_iClientPlayTime[MAXPLAYERS+1], g_iCurrentPing[MAXPLAYERS+1];

public void OnClientConnected(int client)
{
	SetRandomSeed(GetSysTickCount() - client);
	g_iClientPing[client] = GetRandomInt(g_iMinPing, g_iMaxPing);
	g_iClientPlayTime[client] = GetRandomInt(g_iMinPlayTime, g_iMaxPlayTime);
	g_iCurrentPing[client] = 0;
	
	for(int i = 1; i <= MaxClients; ++i)
		g_bFakeClient[client][i] = (i != client && IsClientInGame(i));
}

public Action Command_Status2(int client, int argc)
{
	if(client <= 0 || client >= MaxClients || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Continue;
	
	PrintStatusInfo(client);
	return Plugin_Continue;
}

public Action Command_Status(int client, const char[] command, int argc)
{
	if(!g_bReplaceStatus)
		return Plugin_Continue;
	
	if(client <= 0 || client >= MaxClients || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Continue;
	
	PrintStatusInfo(client);
	return Plugin_Handled;
}

void PrintStatusInfo(int client)
{
	static char sHostName[64];
	if(IsDedicatedServer())
		g_hCvarHostName.GetString(sHostName, sizeof(sHostName));
	else
		strcopy(sHostName, sizeof(sHostName), "Left 4 Dead 2");
	
	static char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));
	
	float vOrigin[3];
	GetClientAbsOrigin(client, vOrigin);
	
	/*
		hostname: Left 4 Dead 2
		version : 2.2.0.4 8011 insecure  
		udp/ip  : 192.168.1.196:27015 [ public n/a ]
		os      : Windows Listen
		map     : c8m5_rooftop at ( 5294, 8429, 5598 )
		players : 1 humans, 0 bots (4 max) (not hibernating) (unreserved)
	*/
	
	PrintToConsole(client, "hostname: %s", sHostName);
	PrintToConsole(client, "version : %s secure (unknown)", g_sStatusVersion);
	PrintToConsole(client, "udp/ip  : 127.0.0.1:27015 [ public 192.168.1.100:27015 ] ");
	PrintToConsole(client, "os      : %s", g_sStatusServer);
	PrintToConsole(client, "map     : %s at ( %.0f, %.0f, %.0f )", sMap, vOrigin[0], vOrigin[1], vOrigin[2]);
	PrintToConsole(client, "players : %d humans, %d bots (%d max) (not hibernating) (unreserved)", GetClientCount2(false), GetClientCount2(true), GetMaxClients2());
	
	PrintToConsole(client, " ");	// NEW LINE
	PrintToConsole(client, "# userid name uniqueid connected ping loss state rate adr");
	
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsClientConnected(i) || IsClientInvis(i))
			continue;
		
		int team = GetClientTeam(i);
		bool bot = IsFakeClient(i);
		if(bot && team != 2)
			continue;
		
		/*
			# userid name uniqueid connected ping loss state rate adr
			#  2 1 "unnamed" STEAM_1:0:0 00:11 34 0 active 30000 loopback
			# 4 "Zoey" BOT active
			# 5 "Bill" BOT active
			# 7 "Louis" BOT active
			# 9 "Francis" BOT active
			#end
		*/
		
		if(bot)
		{
			PrintToConsole(i, "# %d \"%N\" BOT active",
				GetClientUserId(i),		// userid
				i						// name
			);
		}
		else
		{
			static char time[64];
			if(g_bFakeClient[i][client])
				FormatShortTime(g_iClientPlayTime[i] + RoundToZero(GetClientTime(i)), time, sizeof(time));
			else
				FormatShortTime(RoundToZero(GetClientTime(i)), time, sizeof(time));
			
			static char auth[64];
			GetClientAuthId(i, AuthId_Steam2, auth, sizeof(auth), false);
			
			int ping = (g_iCurrentPing[i] > 0 ? g_iCurrentPing[i] : RoundToFloor(GetClientAvgLatency(i, NetFlow_Both) * 1000.0));
			int loss = RoundToFloor(GetClientAvgLoss(i, NetFlow_Both) * 100.0);
			
			static char state[64];
			if(IsClientInGame(i))
				strcopy(state, sizeof(state), "active");
			else
				strcopy(state, sizeof(state), "spawnning");
			
			static char ip[32];
			GetClientIP(i, ip, sizeof(ip), false);
			
			if(IsClientAdmin(i))
			{
				FormatEx(auth, sizeof(auth), "STEAM_1:0:%9d", GetRandomInt(100000000, 999999999));
				
				if(IsDedicatedServer())
					FormatEx(ip, sizeof(ip), "%d.%d.%d.%d:27005", GetRandomInt(0, 255), GetRandomInt(0, 255), GetRandomInt(0, 255), GetRandomInt(0, 255));
				else if(g_hCvarLan.BoolValue)
					FormatEx(ip, sizeof(ip), "%d.%d.%d.%d:27005", GetRandomInt(0, 255), GetRandomInt(0, 255), GetRandomInt(0, 255), GetRandomInt(0, 255));
				else
					FormatEx(ip, sizeof(ip), "0.0.0.%d:27005", GetRandomInt(0, 255));
			}
			
			PrintToConsole(i, "# %d %d \"%N\" %s %s %d %d %s %d %s",
				GetClientUserId(i),		// userid
				i,						// idx
				i,						// name
				auth,					// uniqueid
				time,					// connected
				ping,					// ping
				loss,					// loss
				state,					// state
				GetClientDataRate(i),	// rate
				ip						// adr
			);
		}
	}
	
	PrintToConsole(client, "#end");
	
	PrintToServer("client %N query status");
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrEqual(classname, "terror_player_manager", false) || StrEqual(classname, "player_manager", false))
		SDKHook(entity, SDKHook_ThinkPost, EntityHook_ThinkPost);
}

public void OnEntityDestroyed(int entity)
{
	SDKUnhook(entity, SDKHook_ThinkPost, EntityHook_ThinkPost);
}

public void EntityHook_ThinkPost(int entity)
{
	for(int i = 1; i <= 32; ++i)
	{
		if(!IsClientInGame(i) || IsFakeClient(i))
			continue;
		
		int team = GetClientTeam(i);
		if(team != 2 && team != 3)
			continue;
		
		// FAKE PING
		if(g_iClientPing[i] > 0)
		{
			SetRandomSeed(GetSysTickCount() + i);
			g_iCurrentPing[i] = g_iClientPing[i] + GetRandomInt(-g_iOffsetPing, g_iOffsetPing);
			SetEntProp(entity, Prop_Send, "m_iPing", g_iCurrentPing[i], 2, i);
		}
		
		// FAKE HEALTH
		if(g_bScaleHealth && team == 2)
		{
			int maxHealth = GetEntProp(i, Prop_Data, "m_iMaxHealth");
			int health = GetEntProp(i, Prop_Data, "m_iHealth");
			
			if(maxHealth > 100)
			{
				float scale = maxHealth / 100.0;
				SetEntProp(entity, Prop_Send, "m_maxHealth", RoundToZero(maxHealth / scale), 2, i);
				SetEntProp(entity, Prop_Send, "m_iHealth", RoundToZero(health / scale), 2, i);
			}
			else if(health > maxHealth)
			{
				SetEntProp(entity, Prop_Send, "m_iHealth", 100, 2, i);
			}
		}
		
		// HIDDEN
		if(IsClientInvis(i))
		{
			SetEntProp(entity, Prop_Send, "m_bConnected", 0, 1, i);
			SetEntProp(entity, Prop_Send, "m_iTeam", 0, 1, i);
			SetEntProp(entity, Prop_Send, "m_bAlive", 0, 1, i);
			SetEntProp(entity, Prop_Send, "m_isGhost", 0, 1, i);
			SetEntProp(entity, Prop_Send, "m_isIncapacitated", 0, 1, i);
			SetEntProp(entity, Prop_Send, "m_wantsToPlay", 0, 1, i);
			SetEntProp(entity, Prop_Send, "m_zombieClass", Z_SURVIVOR, 1, i);
		}
		
		SetEntProp(entity, Prop_Send, "m_listenServerHost", 0, 1, i);
	}
}

stock void FormatShortTime(int time, char[] outTime, int size)
{
	int s = time % 60;
	int m = (time % 3600) / 60;
	int h = (time % 86400) / 3600;
	if(h > 0)
		FormatEx(outTime, size, "%02d:%02d:%02d", h, m, s);
	else
		FormatEx(outTime, size, "%02d:%02d", m, s);
}

stock int GetClientCount2(bool bot)
{
	int nClients = 0;
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsClientConnected(i) || IsClientInvis(i))
			continue;
		
		if(IsFakeClient(i))
		{
			if(bot)
				nClients += 1;
		}
		else
		{
			if(!bot)
				nClients += 1;
		}
	}
	
	return nClients;
}

stock int GetMaxClients2()
{
	// L4DToolz
	if(g_hCvarMaxPlayers && g_hCvarMaxPlayers.IntValue > 0)
		return g_hCvarMaxPlayers.IntValue;
	
	int nClients = 4;
	if(g_iGameModeFlags == GMF_VERSUS || g_iGameModeFlags == GMF_SCAVENGE)
		nClients += 4;
	
	return nClients;
}

stock bool IsClientInvis(int client)
{
	if(!IsClientInGame(client))
		return false;
	
	if(g_iGameModeFlags == GMF_COOP || g_iGameModeFlags == GMF_SURVIVAL)
		if(GetClientTeam(client) == 3)
			return true;
	
	return false;
}

stock bool IsClientAdmin(int client)
{
	if(GetUserFlagBits(client) != 0)
		return true;
	
	return false;
}








































