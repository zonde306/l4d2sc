#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <colors>

public Plugin myinfo =
{
	name = "广告",
	author = "zonde306",
	description = "",
	version = "0.1",
	url = ""
};

bool g_b_LateLoad = false;
Handle g_Timer_New[MAXPLAYERS+1], g_Timer_Roll;
int g_n_NewAdvertPoll[MAXPLAYERS+1], g_n_RollAdvertPoll = 0;
ArrayList g_Array_Advert, g_Array_AdvertNew, g_Array_AdvertNewPoll[MAXPLAYERS+1];
ConVar g_CV_Allow, g_CV_Interval, g_CV_Delay, g_CV_NewInterval, g_CV_RollMode, g_CV_NewMode;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_b_LateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_CV_Allow = CreateConVar("l4d2_advert_allow", "0", "是否开启插件", FCVAR_NONE, true, 0.0, true, 1.0);
	g_CV_Interval = CreateConVar("l4d2_advert_interval", "30", "滚动广告间隔", FCVAR_NONE, true, 1.0, true, 65535.0);
	g_CV_RollMode = CreateConVar("l4d2_advert_random", "1", "滚动广告随机化", FCVAR_NONE, true, 0.0, true, 1.0);
	g_CV_Delay = CreateConVar("l4d2_advert_start_delay", "15", "开局首次滚动广告延迟", FCVAR_NONE, true, 1.0, true, 65535.0);
	g_CV_NewInterval = CreateConVar("l4d2_advert_new_interval", "9", "新玩家广告间隔", FCVAR_NONE, true, 1.0, true, 65535.0);
	g_CV_NewMode = CreateConVar("l4d2_advert_new_random", "0", "新玩家广告随机化", FCVAR_NONE, true, 0.0, true, 1.0);
	AutoExecConfig(true, "l4d2_advert");
	
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("mission_lost", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("round_start_pre_entity", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("round_start_post_nav", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("finale_vehicle_leaving", Event_RoundEnd, EventHookMode_PostNoCopy);
	
	g_Array_Advert = CreateArray();
	g_Array_AdvertNew = CreateArray();
	
	if(g_b_LateLoad)
	{
		LoadRollAdvert();
		LoadNewAdvert();
		Event_RoundStart(null, "", false);
	}
}

public void OnMapEnd()
{
	for(int i = 1; i <= MaxClients; ++i)
		g_Timer_New[i] = null;
	g_Timer_Roll = null;
}

public void OnMapStart()
{
	g_n_RollAdvertPoll = 0;
	
	LoadRollAdvert();
	LoadNewAdvert();
	
	for(int i = 1; i <= MaxClients; ++i)
		g_Timer_New[i] = null;
	
	if(g_CV_RollMode.BoolValue)
		g_Array_Advert.Sort(Sort_Random, Sort_Integer);
}

public void OnClientConnected(int client)
{
	g_Timer_New[client] = null;
	g_n_NewAdvertPoll[client] = 0;
	g_Array_AdvertNewPoll[client] = g_Array_AdvertNew.Clone();
	
	if(g_CV_NewMode.BoolValue)
		g_Array_AdvertNewPoll[client].Sort(Sort_Random, Sort_Integer);
}

public void OnClientDisconnect(int client)
{
	if(g_Timer_New[client] != null)
		KillTimer(g_Timer_New[client]);
	if(g_Array_AdvertNewPoll[client] != null)
		delete g_Array_AdvertNewPoll[client];
	g_Timer_New[client] = null;
	g_Array_AdvertNewPoll[client] = null;
}

public void Event_RoundStart(Event event, const char[] eventName, bool dontBroadcast)
{
	if(g_Timer_Roll == null)
		CreateTimer(g_CV_Delay.FloatValue, Timer_PrintRollAdvertFirst, 0, TIMER_FLAG_NO_MAPCHANGE);
	
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsClientInGame(i) || GetClientTeam(i) <= 1)
			continue;
		
		if(g_Timer_New[i] == null)
			g_Timer_New[i] = CreateTimer(g_CV_NewInterval.FloatValue, Timer_PrintNewAdvert, i, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	}
}

public void Event_RoundEnd(Event event, const char[] eventName, bool dontBroadcast)
{
	if(g_Timer_Roll != null)
		KillTimer(g_Timer_Roll);
	g_Timer_Roll = null;
	
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(g_Timer_New[i] != null)
			KillTimer(g_Timer_New[i]);
		g_Timer_New[i] = null;
	}
}

public void Event_PlayerTeam(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int disconnect = event.GetInt("disconnect");
	bool bot = event.GetBool("isbot");
	if(client <= 0 || !IsClientInGame(client) || bot || disconnect)
		return;
	
	int newTeam = event.GetInt("team");
	int oldTeam = event.GetInt("oldteam");
	if(newTeam > 1 && oldTeam <= 1)
	{
		if(g_Timer_New[client] == null)
			g_Timer_New[client] = CreateTimer(g_CV_NewInterval.FloatValue, Timer_PrintNewAdvert, client, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	}
	else if(newTeam <= 1 && oldTeam > 1)
	{
		if(g_Timer_New[client] != null)
			KillTimer(g_Timer_New[client]);
		g_Timer_New[client] = null;
	}
}

public Action Timer_PrintRollAdvertFirst(Handle timer, any unused)
{
	if(g_Timer_Roll == null)
		g_Timer_Roll = CreateTimer(g_CV_Interval.FloatValue, Timer_PrintRollAdvert, 0, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	return Timer_PrintRollAdvert(timer, unused);
}

public Action Timer_PrintRollAdvert(Handle timer, any unused)
{
	if(!g_CV_Allow.BoolValue)
		return Plugin_Continue;
	
	if(g_Array_Advert == null || g_Array_Advert.Length <= 0)
		return Plugin_Continue;
	
	int index = g_n_RollAdvertPoll;
	if(index >= g_Array_Advert.Length)
	{
		index -= g_Array_Advert.Length;
		if(g_CV_RollMode.BoolValue)
			g_Array_Advert.Sort(Sort_Random, Sort_Integer);
	}
	
	ArrayList messages = view_as<ArrayList>(g_Array_Advert.Get(index));
	for(int i = 0; i < messages.Length; ++i)
	{
		static char buffer[255];
		if(messages.GetString(index, buffer, sizeof(buffer)) > 0)
			CPrintToChatAll(buffer);
	}
	
	g_n_RollAdvertPoll = index + 1;
	return Plugin_Continue;
}

public Action Timer_PrintNewAdvert(Handle timer, any client)
{
	if(!g_CV_Allow.BoolValue)
		return Plugin_Continue;
	
	if(!IsClientInGame(client))
		return Plugin_Stop;
	
	if(g_Array_AdvertNewPoll[client] == null || g_Array_AdvertNewPoll[client].Length <= 0)
		return Plugin_Continue;
	
	int index = g_n_NewAdvertPoll[client];
	if(index >= g_Array_AdvertNewPoll[client].Length)
		return Plugin_Stop;
	
	ArrayList messages = view_as<ArrayList>(g_Array_AdvertNewPoll[client].Get(index));
	for(int i = 0; i < messages.Length; ++i)
	{
		static char buffer[255];
		if(messages.GetString(index, buffer, sizeof(buffer)) > 0)
			CPrintToChat(client, buffer);
	}
	
	g_n_NewAdvertPoll[client] = index + 1;
	return Plugin_Continue;
}

void LoadRollAdvert()
{
	char buffer[255];
	BuildPath(Path_SM, buffer, sizeof(buffer), "data/advert.txt");
	if(!FileExists(buffer))
		return;
	
	// 检查文件是否被更改
	static int timestamp = 0;
	int currentTimestamp = GetFileTime(buffer, FileTime_LastChange);
	if(timestamp == currentTimestamp)
		return;
	timestamp = currentTimestamp;
	
	g_Array_Advert.Clear();
	File file = OpenFile(buffer, "rt");
	ArrayList messages = CreateArray(sizeof(buffer));
	while(!file.EndOfFile() && file.ReadLine(buffer, sizeof(buffer)))
	{
		if(buffer[0] == EOS)
		{
			if(messages.Length > 0)
				g_Array_Advert.Push(messages);
			
			messages = CreateArray(sizeof(buffer));
			continue;
		}
		
		messages.PushString(buffer);
	}
	
	delete file;
}

void LoadNewAdvert()
{
	char buffer[255];
	BuildPath(Path_SM, buffer, sizeof(buffer), "data/advert_new.txt");
	if(!FileExists(buffer))
		return;
	
	// 检查文件是否被更改
	static int timestamp = 0;
	int currentTimestamp = GetFileTime(buffer, FileTime_LastChange);
	if(timestamp == currentTimestamp)
		return;
	timestamp = currentTimestamp;
	
	g_Array_AdvertNew.Clear();
	File file = OpenFile(buffer, "rt");
	ArrayList messages = CreateArray(sizeof(buffer));
	while(!file.EndOfFile() && file.ReadLine(buffer, sizeof(buffer)))
	{
		if(buffer[0] == EOS)
		{
			if(messages.Length > 0)
				g_Array_AdvertNew.Push(messages);
			
			messages = CreateArray(sizeof(buffer));
			continue;
		}
		
		messages.PushString(buffer);
	}
	
	delete file;
}
