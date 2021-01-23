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
ConVar g_hCvarHostName, g_hCvarLan, g_hCvarMaxPlayers, g_hCvarIncapHealth;
ConVar g_pCvarMinPing, g_pCvarMaxPing, g_pCvarOffsetPing, g_pCvarServer, g_pCvarFakeHealth,
	g_pCvarMinPlayTime, g_pCvarMaxPlayTime, g_pCvarVersion, g_pCvarFakeCoop, g_pCvarFakePing, g_pCvarFakeStatus;

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
	g_pCvarServer = CreateConVar("l4d2_fs_fake_server", "Linux Listen", "伪装 status 中的服务器内容", CVAR_FLAGS);
	g_pCvarMinPlayTime = CreateConVar("l4d2_fs_min_playtime", "", "伪装 status 中的在线时间最小值", CVAR_FLAGS, true, 0.0, true, 2147483647.0);
	g_pCvarMaxPlayTime = CreateConVar("l4d2_fs_max_playtime", "", "伪装 status 中的在线时间最小值", CVAR_FLAGS, true, 0.0, true, 2147483647.0);
	g_pCvarVersion = CreateConVar("l4d2_fs_fake_version", "", "伪装 status 中的游戏版本", CVAR_FLAGS);
	g_pCvarFakeCoop = CreateConVar("l4d2_fs_fake_coop", "1", "合作模式伪装特感.0=关闭.1=仅对管理员生效.2=对所有玩家生效", CVAR_FLAGS, true, 0.0, true, 2.0);
	g_pCvarFakePing = CreateConVar("l4d2_fs_fake_ping", "1", "是否开启伪装延迟.0=关闭.1=仅对管理员生效.2=对所有玩家生效", CVAR_FLAGS, true, 0.0, true, 2.0);
	g_pCvarFakeStatus = CreateConVar("l4d2_fs_fake_status", "1", "是否开启伪装status命令.0=关闭.1=仅对非管理员生效.2=对所有玩家生效", CVAR_FLAGS, true, 0.0, true, 2.0);
	g_pCvarFakeHealth = CreateConVar("l4d2_fs_fake_health", "1", "是否开启血量.0=关闭.1=仅对管理员生效.2=对所有玩家生效", CVAR_FLAGS, true, 0.0, true, 2.0);
	
	AutoExecConfig(true, "l4d2_fake_server");
	
	g_hCvarHostName = FindConVar("hostname");
	g_hCvarLan = FindConVar("sv_lan");
	g_hCvarMaxPlayers = FindConVar("sv_visiblemaxplayers");
	g_hCvarIncapHealth = FindConVar("survivor_incap_health");
	AddCommandListener(Command_Status, "status");
	RegAdminCmd("sm_status", Command_Status2, ADMFLAG_ROOT);
	
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);
	HookEvent("player_hurt_concise", Event_PlayerHurtConcise, EventHookMode_Pre);
	HookEvent("zombie_death", Event_ZombieDeath, EventHookMode_Pre);
	HookEvent("player_incapacitated", Event_PlayerIncapacitated, EventHookMode_Pre);
	HookEvent("player_incapacitated_start", Event_PlayerIncapacitatedStart, EventHookMode_Pre);
	HookEvent("revive_success", Event_ReviveSuccess, EventHookMode_Pre);
	HookEvent("revive_begin", Event_ReviveBegin);
	HookEvent("award_earned", Event_AwardEarned, EventHookMode_Pre);
	HookEvent("defibrillator_used", Event_DefibrillatorUsed, EventHookMode_Pre);
	HookEvent("defibrillator_begin", Event_DefibrillatorBegin);
	HookEvent("heal_success", Event_HealSuccess, EventHookMode_Pre);
	HookEvent("heal_begin", Event_HealBegin);
	HookEvent("survivor_rescued", Event_SurvivorRescued, EventHookMode_Pre);
	HookUserMessage(GetUserMessageId("TextMsg"), OnUserMsg_TextMsg, true);
	HookUserMessage(GetUserMessageId("HintText"), OnUserMsg_HintText, true);
	
	CvarHook_OnChanged(null, "", "");
	g_pCvarMinPing.AddChangeHook(CvarHook_OnChanged);
	g_pCvarMaxPing.AddChangeHook(CvarHook_OnChanged);
	g_pCvarOffsetPing.AddChangeHook(CvarHook_OnChanged);
	g_pCvarServer.AddChangeHook(CvarHook_OnChanged);
	g_pCvarMinPlayTime.AddChangeHook(CvarHook_OnChanged);
	g_pCvarMaxPlayTime.AddChangeHook(CvarHook_OnChanged);
	g_pCvarFakeCoop.AddChangeHook(CvarHook_OnChanged);
	g_pCvarFakePing.AddChangeHook(CvarHook_OnChanged);
	g_pCvarFakeStatus.AddChangeHook(CvarHook_OnChanged);
	g_pCvarFakeHealth.AddChangeHook(CvarHook_OnChanged);
	g_pCvarVersion.AddChangeHook(CvarHook_OnChanged);
	g_hCvarIncapHealth.AddChangeHook(CvarHook_OnChanged);
	
	if(g_bLateLoad)
	{
		int entity = FindEntityByClassname(MaxClients + 1, "terror_player_manager");
		if(entity > MaxClients)
			SDKHook(entity, SDKHook_ThinkPost, EntityHook_ThinkPost);
		entity = FindEntityByClassname(MaxClients + 1, "player_manager");
		if(entity > MaxClients)
			SDKHook(entity, SDKHook_ThinkPost, EntityHook_ThinkPost);
		
		for(int i = 1; i <= MaxClients; ++i)
			if(IsClientConnected(i))
				OnClientConnected(i);
	}
}

char g_sStatusServer[64], g_sStatusVersion[64];
int g_iMinPing, g_iMaxPing, g_iOffsetPing, g_iMinPlayTime, g_iMaxPlayTime, g_iFakeCoop, g_iFakePing, g_iFakeStatus, g_iFakeHealth, g_iIncapHealth;

public void CvarHook_OnChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	g_iMinPing = g_pCvarMinPing.IntValue;
	g_iMaxPing = g_pCvarMaxPing.IntValue;
	g_iOffsetPing = g_pCvarOffsetPing.IntValue;
	g_pCvarServer.GetString(g_sStatusServer, sizeof(g_sStatusServer));
	g_iMinPlayTime = g_pCvarMinPlayTime.IntValue;
	g_iMaxPlayTime = g_pCvarMaxPlayTime.IntValue;
	g_pCvarVersion.GetString(g_sStatusVersion, sizeof(g_sStatusVersion));
	g_iFakeCoop = g_pCvarFakeCoop.IntValue;
	g_iFakePing = g_pCvarFakePing.IntValue;
	g_iFakeStatus = g_pCvarFakeStatus.IntValue;
	g_iFakeHealth = g_pCvarFakeHealth.IntValue;
	g_iIncapHealth = g_hCvarIncapHealth.IntValue;
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
	if(client <= 0 || client >= MaxClients || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Continue;
	
	if(g_iFakeStatus == 0 || (g_iFakeStatus == 1 && IsClientAdmin(client)))
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
	
	PrintToServer("client %N query status", client);
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
	// 数组上限就是这么大
	for(int i = 1; i <= 32; ++i)
	{
		if(!IsClientInGame(i))
			continue;
		
		int team = GetClientTeam(i);
		if(team != 2 && team != 3)
			continue;
		
		// FAKE HEALTH
		if(team == 2 && g_iFakeHealth == 2 || (g_iFakeHealth == 1 && IsClientAdmin(i)))
		{
			int maxHealth = GetEntProp(i, Prop_Data, "m_iMaxHealth");
			int health = GetEntProp(i, Prop_Data, "m_iHealth");
			
			int rawMaxHealth = 100;
			if(GetEntProp(i, Prop_Send, "m_isIncapacitated") || GetEntProp(i, Prop_Send, "m_isHangingFromLedge"))
				rawMaxHealth = g_iIncapHealth;
			
			if(maxHealth > rawMaxHealth)
			{
				float scale = maxHealth / 100.0;
				SetEntProp(entity, Prop_Send, "m_maxHealth", RoundToZero(maxHealth / scale), 2, i);
				SetEntProp(entity, Prop_Send, "m_iHealth", RoundToZero(health / scale), 2, i);
			}
			else if(health > maxHealth)
			{
				SetEntProp(entity, Prop_Send, "m_iHealth", rawMaxHealth, 2, i);
			}
		}
		
		if(!IsFakeClient(i))
		{
			// FAKE PING
			if(g_iClientPing[i] > 0 && g_iFakePing == 2 || (g_iFakePing == 1 && IsClientAdmin(i)))
			{
				SetRandomSeed(GetSysTickCount() + i);
				g_iCurrentPing[i] = g_iClientPing[i] + GetRandomInt(-g_iOffsetPing, g_iOffsetPing);
				SetEntProp(entity, Prop_Send, "m_iPing", g_iCurrentPing[i], 2, i);
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
				SetEntProp(entity, Prop_Send, "m_zombieClass", Z_COMMON, 1, i);
			}
		}
		
		// 设置1可以防止被起票？
		SetEntProp(entity, Prop_Send, "m_listenServerHost", 0, 1, i);
	}
}

public Action Event_PlayerDeath(Event event, const char[] eventName, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if(IsValidClient(victim) && IsClientInvis(victim))
		return Plugin_Handled;
	
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if(IsValidClient(attacker) && IsClientInvis(attacker))
	{
		event.SetInt("attacker", 0);
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public Action Event_PlayerHurt(Event event, const char[] eventName, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if(IsValidClient(victim) && IsClientInvis(victim))
		return Plugin_Handled;
	
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if(IsValidClient(attacker) && IsClientInvis(attacker))
	{
		event.SetInt("attacker", 0);
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public Action Event_PlayerHurtConcise(Event event, const char[] eventName, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if(IsValidClient(victim) && IsClientInvis(victim))
		return Plugin_Handled;
	
	int attacker = event.GetInt("attackerentid");
	if(IsValidClient(attacker) && IsClientInvis(attacker))
	{
		event.SetInt("attackerentid", 0);
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public Action Event_ZombieDeath(Event event, const char[] eventName, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("victim"));
	if(IsValidClient(victim) && IsClientInvis(victim))
		return Plugin_Handled;
	
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if(IsValidClient(attacker) && IsClientInvis(attacker))
	{
		event.SetInt("attacker", 0);
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public Action Event_PlayerIncapacitated(Event event, const char[] eventName, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("victim"));
	if(IsValidClient(victim) && IsClientInvis(victim))
		return Plugin_Handled;
	
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if(IsValidClient(attacker) && IsClientInvis(attacker))
	{
		event.SetInt("attacker", 0);
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public Action Event_PlayerIncapacitatedStart(Event event, const char[] eventName, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("victim"));
	if(IsValidClient(victim) && IsClientInvis(victim))
		return Plugin_Handled;
	
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if(IsValidClient(attacker) && IsClientInvis(attacker))
	{
		event.SetInt("attacker", 0);
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public Action Event_ReviveSuccess(Event event, const char[] eventName, bool dontBroadcast)
{
	int revivee = GetClientOfUserId(event.GetInt("subject"));
	if(IsValidClient(revivee) && IsClientInvis(revivee))
		return Plugin_Handled;
	
	int reviver = GetClientOfUserId(event.GetInt("userid"));
	if(IsValidClient(reviver) && IsClientInvis(reviver))
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public void Event_ReviveBegin(Event event, const char[] eventName, bool dontBroadcast)
{
	int helpee = GetClientOfUserId(event.GetInt("subject"));
	int helper = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(helpee) || !IsValidClient(helper) || helpee == helper)
		return;
	
	if(IsClientInvis(helpee))
	{
		SetEntProp(helper, Prop_Send, "m_flProgressBarStartTime", GetGameTime());
		SetEntProp(helper, Prop_Send, "m_flProgressBarDuration", 0.0);
	}
	if(IsClientInvis(helper))
	{
		SetEntProp(helpee, Prop_Send, "m_flProgressBarStartTime", GetGameTime());
		SetEntProp(helpee, Prop_Send, "m_flProgressBarDuration", 0.0);
	}
}

public Action Event_AwardEarned(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(IsValidClient(client) && IsClientInvis(client))
		return Plugin_Handled;
	
	int subject = event.GetInt("subjectentid");
	if(IsValidClient(subject) && IsClientInvis(subject))
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public Action Event_DefibrillatorUsed(Event event, const char[] eventName, bool dontBroadcast)
{
	int helper = GetClientOfUserId(event.GetInt("userid"));
	if(IsValidClient(helper) && IsClientInvis(helper))
		return Plugin_Handled;
	
	int helpee = GetClientOfUserId(event.GetInt("subject"));
	if(IsValidClient(helpee) && IsClientInvis(helpee))
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public void Event_DefibrillatorBegin(Event event, const char[] eventName, bool dontBroadcast)
{
	int helpee = GetClientOfUserId(event.GetInt("subject"));
	int helper = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(helpee) || !IsValidClient(helper) || helpee == helper)
		return;
	
	if(IsClientInvis(helpee))
	{
		SetEntProp(helper, Prop_Send, "m_flProgressBarStartTime", GetGameTime());
		SetEntProp(helper, Prop_Send, "m_flProgressBarDuration", 0.0);
	}
}

public Action Event_HealSuccess(Event event, const char[] eventName, bool dontBroadcast)
{
	int helper = GetClientOfUserId(event.GetInt("userid"));
	if(IsValidClient(helper) && IsClientInvis(helper))
		return Plugin_Handled;
	
	int helpee = GetClientOfUserId(event.GetInt("subject"));
	if(IsValidClient(helpee) && IsClientInvis(helpee))
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public void Event_HealBegin(Event event, const char[] eventName, bool dontBroadcast)
{
	int helpee = GetClientOfUserId(event.GetInt("subject"));
	int helper = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(helpee) || !IsValidClient(helper) || helpee == helper)
		return;
	
	if(IsClientInvis(helpee))
	{
		SetEntProp(helper, Prop_Send, "m_flProgressBarStartTime", GetGameTime());
		SetEntProp(helper, Prop_Send, "m_flProgressBarDuration", 0.0);
	}
	if(IsClientInvis(helper))
	{
		SetEntProp(helpee, Prop_Send, "m_flProgressBarStartTime", GetGameTime());
		SetEntProp(helpee, Prop_Send, "m_flProgressBarDuration", 0.0);
	}
}

public Action Event_SurvivorRescued(Event event, const char[] eventName, bool dontBroadcast)
{
	int helper = GetClientOfUserId(event.GetInt("rescuer"));
	if(IsValidClient(helper) && IsClientInvis(helper))
		return Plugin_Handled;
	
	int helpee = GetClientOfUserId(event.GetInt("victim"));
	if(IsValidClient(helpee) && IsClientInvis(helpee))
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public Action OnUserMsg_TextMsg(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	static char message[256], name[MAX_NAME_LENGTH];
	msg.ReadString(message, sizeof(message), false);
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsClientConnected(i) || !IsClientInvis(i))
			continue;
		
		GetClientName(i, name, sizeof(name));
		if(StrContains(message, name, true) != -1)
			return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action OnUserMsg_HintText(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	static char message[256], name[MAX_NAME_LENGTH];
	msg.ReadByte();
	msg.ReadString(message, sizeof(message), false);
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsClientConnected(i) || !IsClientInvis(i))
			continue;
		
		GetClientName(i, name, sizeof(name));
		if(StrContains(message, name, true) != -1)
			return Plugin_Handled;
	}
	
	return Plugin_Continue;
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
	if(g_iFakeCoop == 0 || (g_iFakeCoop == 1 && !IsClientAdmin(client)))
		return false;
	
	if(!IsClientInGame(client) || IsFakeClient(client))
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
