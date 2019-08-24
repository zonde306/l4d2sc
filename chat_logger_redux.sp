#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.1.2"

Handle ConVars[14];
Handle Path_handle;

bool sv_bEnabled;
char cv_sTimeFormat[64];
bool sv_bTriggers;
bool sv_bSay;
bool sv_bChat;
bool sv_bCsay;
bool sv_bTsay;
bool sv_bMsay;
bool sv_bHsay;
bool sv_bPsay;
bool sv_bFormatting;
bool sv_bConsole;
char cv_sFolder[64];

bool IsHooked;

public Plugin myinfo = 
{
	name = "聊天记录",
	author = "McFlurry, Keith Warren (Shaders Allen)",
	description = "Logs chat for all players and RCON information.",
	version = PLUGIN_VERSION,
	url = "http://www.shadersallen.com/"
}

public void OnPluginStart()
{
	ConVars[0] = CreateConVar("chat_log_redux_version", PLUGIN_VERSION, "插件版本", FCVAR_NOTIFY|FCVAR_REPLICATED|FCVAR_DONTRECORD);
	ConVars[1] = CreateConVar("sm_chat_log_enable", "1", "是否开启插件", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	ConVars[2] = CreateConVar("sm_chat_log_timeformat", "%b %d |%H:%M:%S| %Y", "时间前缀", FCVAR_NOTIFY);
	ConVars[3] = CreateConVar("sm_chat_log_triggers", "1", "是否记录命令", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	ConVars[4] = CreateConVar("sm_chat_log_sm_say", "1", "是否记录 sm_say", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	ConVars[5] = CreateConVar("sm_chat_log_sm_chat", "1", "是否记录 sm_chat", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	ConVars[6] = CreateConVar("sm_chat_log_sm_csay", "1", "是否记录 sm_csay", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	ConVars[7] = CreateConVar("sm_chat_log_sm_tsay", "1", "是否记录 sm_tsay", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	ConVars[8] = CreateConVar("sm_chat_log_sm_msay", "1", "是否记录 sm_msay", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	ConVars[9] = CreateConVar("sm_chat_log_sm_hsay", "1", "是否记录 sm_hsay?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	ConVars[10] = CreateConVar("sm_chat_log_sm_psay", "1", "是否记录 sm_psay", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	ConVars[11] = CreateConVar("sm_chat_log_rtf_format", "0", "记录模式.0=txt.1=rtf", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	ConVars[12] = CreateConVar("sm_chat_log_console", "1", "记录控制台", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	ConVars[13] = CreateConVar("sm_chat_log_folder", "chat", "文件名", FCVAR_NOTIFY);
		
	for (int i = 0; i < sizeof(ConVars); i++)
	{
		HookConVarChange(ConVars[i], HandleCvars);
	}
	
	// AddCommandListener(Say, "say");
	// AddCommandListener(SayTeam, "say_team");
	AddCommandListener(SMSay, "sm_say");
	AddCommandListener(SMChat, "sm_chat");
	AddCommandListener(SMCSay, "sm_csay");
	AddCommandListener(SMTSay, "sm_tsay");
	AddCommandListener(SMMSay, "sm_msay");
	AddCommandListener(SMHSay, "sm_hsay");
	AddCommandListener(SMPSay, "sm_psay");
		
	TriggerTimer(CreateTimer(15.0, NewFCheck, _, TIMER_REPEAT));
	HookEventEx("player_connect", Event_PlayerConnect);
	HookEventEx("player_disconnect", Event_PlayerDisconnect);
	
	AutoExecConfig(true, "chat_logger_redux");
}

public void OnConfigsExecuted()
{
	sv_bEnabled = GetConVarBool(ConVars[1]);
	GetConVarString(ConVars[2], cv_sTimeFormat, sizeof(cv_sTimeFormat));
	sv_bTriggers = GetConVarBool(ConVars[3]);
	sv_bSay = GetConVarBool(ConVars[4]);
	sv_bChat = GetConVarBool(ConVars[5]);
	sv_bCsay = GetConVarBool(ConVars[6]);
	sv_bTsay = GetConVarBool(ConVars[7]);
	sv_bMsay = GetConVarBool(ConVars[8]);
	sv_bHsay = GetConVarBool(ConVars[9]);
	sv_bPsay = GetConVarBool(ConVars[10]);
	sv_bFormatting = GetConVarBool(ConVars[11]);
	sv_bConsole = GetConVarBool(ConVars[12]);
	GetConVarString(ConVars[13], cv_sFolder, sizeof(cv_sFolder));
}

public int HandleCvars (Handle cvar, const char[] oldValue, const char[] newValue)
{
	if (StrEqual(newValue, oldValue))
	{
		return;
	}
	
	int iValue = StringToInt(newValue);
	bool bValue = view_as<bool>(iValue);

	if (cvar == ConVars[0])
	{
		SetConVarString(ConVars[0], PLUGIN_VERSION);
	}
	else if (cvar == ConVars[1])
	{
		sv_bEnabled = bValue;
	}
	else if (cvar == ConVars[2])
	{
		strcopy(cv_sTimeFormat, sizeof(cv_sTimeFormat), newValue);
	}
	else if (cvar == ConVars[3])
	{
		sv_bTriggers = bValue;
	}
	else if (cvar == ConVars[4])
	{
		sv_bSay = bValue;
	}
	else if (cvar == ConVars[5])
	{
		sv_bChat = bValue;
	}
	else if (cvar == ConVars[6])
	{
		sv_bCsay = bValue;
	}
	else if (cvar == ConVars[7])
	{
		sv_bTsay = bValue;
	}
	else if (cvar == ConVars[8])
	{
		sv_bMsay = bValue;
	}
	else if (cvar == ConVars[9])
	{
		sv_bHsay = bValue;
	}
	else if (cvar == ConVars[10])
	{
		sv_bPsay = bValue;
	}
	else if (cvar == ConVars[11])
	{
		sv_bFormatting = bValue;
	}
	else if (cvar == ConVars[12])
	{
		sv_bConsole = bValue;
	}
	else if (cvar == ConVars[13])
	{
		strcopy(cv_sFolder, sizeof(cv_sFolder), newValue);
	}
}

public Action NewFCheck(Handle timer, any unused)
{
	char sDirPath[PLATFORM_MAX_PATH];
	Format(sDirPath, sizeof(sDirPath), "addons/sourcemod/logs/%s", cv_sFolder);
	
	if (!DirExists(sDirPath))
	{
		LogMessage("Directory '%s' does not exist under logs, recreating it.", cv_sFolder);
		CreateDirectory(sDirPath, 511);
	}
	
	char sPath[PLATFORM_MAX_PATH]; char sTime[PLATFORM_MAX_PATH];
	
	FormatTime(sTime, sizeof(sTime), "%Y-%m-%d");
	switch (sv_bFormatting)
	{
		case true:	Format(sTime, sizeof(sTime), "logs/%s/date_%s.rtf", cv_sFolder, sTime);
		case false:	Format(sTime, sizeof(sTime), "logs/%s/date_%s.txt", cv_sFolder, sTime);
	}
	
	BuildPath(Path_SM, sPath, sizeof(sPath), sTime);
	
	if (Path_handle != INVALID_HANDLE)
	{
		CloseHandle(Path_handle);
		Path_handle = INVALID_HANDLE;
	}
	
	Path_handle = OpenFile(sPath, "a+");
	
	if (Path_handle == INVALID_HANDLE)
	{
		LogError("Error opening file via path '%s'.", sPath);
		IsHooked = false;
		return Plugin_Continue;
	}
	
	if (sv_bFormatting && FileSize(sPath) < 1)
	{
		WriteFileLine(Path_handle, "{\\rtf1\\ansi\\ansicpg1252\\deff0\\deflang1033{\\fonttbl{\\f0\\fnil\\fcharset0 Calibri;}}");
		WriteFileLine(Path_handle, "{\\colortbl ;\\red204\\green180\\blue0;\\red0\\green77\\blue187;\\red255\\green0\\blue0;}");
		WriteFileLine(Path_handle, "{\\*\\generator Msftedit 5.41.21.2509;}\\viewkind4\\uc1\\pard\\sa200\\sl276\\slmult1\\lang9\\f0\\fs22");
	}
	
	IsHooked = true;
	return Plugin_Continue;
}

public void OnMapStart()
{
	char map[64];
	GetCurrentMap(map, 64);
	
	char sTime[256];
	FormatTime(sTime, sizeof(sTime), cv_sTimeFormat);
	
	char buffer[255];
	FormatEx(buffer, 255, "[%s] map starting: %s", sTime, map);
	
	WriteFileLine(Path_handle, buffer);
	FlushFile(Path_handle);
}

public void OnMapEnd()
{
	char map[64];
	GetCurrentMap(map, 64);
	
	char sTime[256];
	FormatTime(sTime, sizeof(sTime), cv_sTimeFormat);
	
	char buffer[255];
	FormatEx(buffer, 255, "[%s] map ending: %s", sTime, map);
	
	WriteFileLine(Path_handle, buffer);
	FlushFile(Path_handle);
}

public void Event_PlayerConnect(Event event, const char[] eventName, bool unknown)
{
	char name[MAX_NAME_LENGTH], ip[32], steamId[32];
	event.GetString("name", name, MAX_NAME_LENGTH);
	event.GetString("address", ip, 32);
	event.GetString("networkid", steamId, 32);
	
	if(steamId[0] == EOS || StrEqual(steamId, "BOT", false))
		return;
	
	char sTime[256];
	FormatTime(sTime, sizeof(sTime), cv_sTimeFormat);
	
	char buffer[255];
	FormatEx(buffer, 255, "[%s] player %s (%s) connecting... from %s", sTime, name, steamId, ip);
	
	WriteFileLine(Path_handle, buffer);
	FlushFile(Path_handle);
}

public void Event_PlayerDisconnect(Event event, const char[] eventName, bool unknown)
{
	char name[MAX_NAME_LENGTH], reason[255], steamId[32];
	event.GetString("name", name, MAX_NAME_LENGTH);
	event.GetString("reason", reason, 255);
	event.GetString("networkid", steamId, 32);
	
	if(steamId[0] == EOS || StrEqual(steamId, "BOT", false))
		return;
	
	char sTime[256];
	FormatTime(sTime, sizeof(sTime), cv_sTimeFormat);
	
	char buffer[255];
	FormatEx(buffer, 255, "[%s] player %s (%s) disconnected... with: %s", sTime, name, steamId, reason);
	
	WriteFileLine(Path_handle, buffer);
	FlushFile(Path_handle);
}
/*
public void OnClientConnected(int client)
{
	if(IsFakeClient(client))
		return;
	
	char sTime[256];
	FormatTime(sTime, sizeof(sTime), cv_sTimeFormat);
	
	char name[255];
	GetClientName(client, name, 255);
	Format(name, 255, "[%s] %s connected", sTime, name);
	
	WriteFileLine(Path_handle, name);
	FlushFile(Path_handle);
}

public void OnClientDisconnect(int client)
{
	if(IsFakeClient(client))
		return;
	
	char sTime[256];
	FormatTime(sTime, sizeof(sTime), cv_sTimeFormat);
	
	char name[255];
	GetClientName(client, name, 255);
	Format(name, 255, "[%s] %s disconnected", sTime, name);
	
	WriteFileLine(Path_handle, name);
	FlushFile(Path_handle);
}
*/
public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
	if (!sv_bEnabled || !IsHooked)
	{
		return;
	}
	
	if (strlen(sArgs) == 0)
	{
		return;
	}
	
	char sTime[256];
	FormatTime(sTime, sizeof(sTime), cv_sTimeFormat);
	
	char sFormat[512];
	if (client > 0 && client <= MaxClients)
	{
		char sName[MAX_NAME_LENGTH];
		GetClientName(client, sName, sizeof(sName));
		
		char sAuth[32];
		GetClientAuthId(client, AuthId_Steam2, sAuth, sizeof(sAuth));
		
		if (sv_bFormatting)
		{
			char sColor[12];
			
			if (IsClientInGame(client))
			{
				switch(GetClientTeam(client))
				{
					case 1: strcopy(sColor, sizeof(sColor), "");
					case 2: strcopy(sColor, sizeof(sColor), "\\cf3");
					case 3: strcopy(sColor, sizeof(sColor), "\\cf2");
				}
			}
			
			Format(sFormat, sizeof(sFormat), "[%s] %s %s (%s)\\cf0", sTime, sColor, sName, sAuth);
		}
		else
		{
			Format(sFormat, sizeof(sFormat), "[%s] %s (%s)", sTime, sName, sAuth);
		}
	}
	else if (sv_bConsole)
	{
		Format(sFormat, sizeof(sFormat), "[%s] Console", sTime);
	}
	else
	{
		return;
	}
	
	char sPrint[512];
	Format(sPrint, sizeof(sPrint), "%s: %s%s", sFormat, sArgs, sv_bFormatting ? "\\par" : "");
	
	if (!sv_bTriggers && IsChatTrigger())
	{
		return;
	}
	
	WriteFileLine(Path_handle, sPrint);
	FlushFile(Path_handle);
}

public Action Say(int client, const char[] command, int args)
{
	if(!sv_bEnabled || !sv_bSay || !IsHooked) return;
	
	char Chat[256];
	GetCmdArgString(Chat, sizeof(Chat));
	
	if (strlen(Chat) == 0)
	{
		return;
	}
	
	char sTime[256];
	FormatTime(sTime, sizeof(sTime), cv_sTimeFormat);
	
	char sFormat[512];
	if (client > 0 && client <= MaxClients)
	{
		char sName[MAX_NAME_LENGTH];
		GetClientName(client, sName, sizeof(sName));
		
		char sAuth[256];
		GetClientAuthId(client, AuthId_Steam2, sAuth, sizeof(sAuth));
		
		switch (sv_bFormatting)
		{
			case true: Format(sFormat, sizeof(sFormat), "[%s] \\cf1 (ALL)%s (%s)\\cf0", sTime, sName, sAuth);
			case false: Format(sFormat, sizeof(sFormat), "[%s] (ALL)%s (%s)", sTime, sName, sAuth);
		}
	}	
	else if (sv_bConsole)
	{
		switch (sv_bFormatting)
		{
			case true: Format(sFormat, sizeof(sFormat), "[%s] \\cf1 (ALL)Console\\cf0", sTime);
			case false: Format(sFormat, sizeof(sFormat), "[%s] (ALL)Console", sTime);
		}
	}
	else
	{
		return;
	}
	
	char sPrint[512];
	switch (sv_bFormatting)
	{
		case true: Format(sPrint, sizeof(sPrint), "%s: %s\\par", sFormat, Chat);
		case false: Format(sPrint, sizeof(sPrint), "%s: %s", sFormat, Chat);
	}
	
	WriteFileLine(Path_handle, sPrint);
	FlushFile(Path_handle);
}

public Action SayTeam(int client, const char[] command, int args)
{
	if(!sv_bEnabled || !sv_bSay || !IsHooked) return;
	
	char Chat[256];
	GetCmdArgString(Chat, sizeof(Chat));
	
	if (strlen(Chat) == 0)
	{
		return;
	}
	
	char sTime[256];
	FormatTime(sTime, sizeof(sTime), cv_sTimeFormat);
	
	char sFormat[512];
	if (client > 0 && client <= MaxClients)
	{
		char sName[MAX_NAME_LENGTH];
		GetClientName(client, sName, sizeof(sName));
		
		char sAuth[256];
		GetClientAuthId(client, AuthId_Steam2, sAuth, sizeof(sAuth));
		
		char sTeam[32];
		switch(GetClientTeam(client))
		{
			case 1:
				strcopy(sTeam, 32, "Spec");
			case 2:
				strcopy(sTeam, 32, "Survivor");
			case 3:
				strcopy(sTeam, 32, "Infected");
			case 4:
				strcopy(sTeam, 32, "L4D1Survivor");
			default:
				strcopy(sTeam, 32, "Unknown");
		}
		
		switch (sv_bFormatting)
		{
			case true: Format(sFormat, sizeof(sFormat), "[%s] \\cf1 (%s)%s (%s)\\cf0", sTime, sTeam, sName, sAuth);
			case false: Format(sFormat, sizeof(sFormat), "[%s] (%s)%s (%s)", sTime, sTeam, sName, sAuth);
		}
	}	
	else if (sv_bConsole)
	{
		switch (sv_bFormatting)
		{
			case true: Format(sFormat, sizeof(sFormat), "[%s] \\cf1 (ALL)Console\\cf0", sTime);
			case false: Format(sFormat, sizeof(sFormat), "[%s] (ALL)Console", sTime);
		}
	}
	else
	{
		return;
	}
	
	char sPrint[512];
	switch (sv_bFormatting)
	{
		case true: Format(sPrint, sizeof(sPrint), "%s: %s\\par", sFormat, Chat);
		case false: Format(sPrint, sizeof(sPrint), "%s: %s", sFormat, Chat);
	}
	
	WriteFileLine(Path_handle, sPrint);
	FlushFile(Path_handle);
}

public Action SMSay(int client, const char[] command, int args)
{
	if(!sv_bEnabled || !sv_bSay || !IsHooked) return;
	
	char Chat[256];
	GetCmdArgString(Chat, sizeof(Chat));
	
	if (strlen(Chat) == 0)
	{
		return;
	}
	
	char sTime[256];
	FormatTime(sTime, sizeof(sTime), cv_sTimeFormat);
	
	char sFormat[512];
	if (client > 0 && client <= MaxClients)
	{
		char sName[MAX_NAME_LENGTH];
		GetClientName(client, sName, sizeof(sName));
		
		char sAuth[256];
		GetClientAuthId(client, AuthId_Steam2, sAuth, sizeof(sAuth));
		
		switch (sv_bFormatting)
		{
			case true: Format(sFormat, sizeof(sFormat), "[%s] \\cf1 (ALL)%s (%s)\\cf0", sTime, sName, sAuth);
			case false: Format(sFormat, sizeof(sFormat), "[%s] (ALL)%s (%s)", sTime, sName, sAuth);
		}
	}	
	else if (sv_bConsole)
	{
		switch (sv_bFormatting)
		{
			case true: Format(sFormat, sizeof(sFormat), "[%s] \\cf1 (ALL)Console\\cf0", sTime);
			case false: Format(sFormat, sizeof(sFormat), "[%s] (ALL)Console", sTime);
		}
	}
	else
	{
		return;
	}
	
	char sPrint[512];
	switch (sv_bFormatting)
	{
		case true: Format(sPrint, sizeof(sPrint), "%s: %s\\par", sFormat, Chat);
		case false: Format(sPrint, sizeof(sPrint), "%s: %s", sFormat, Chat);
	}
	
	WriteFileLine(Path_handle, sPrint);
	FlushFile(Path_handle);
}

public Action SMChat(int client, const char[] command, int args)
{
	if(!sv_bEnabled || !sv_bChat || !IsHooked) return;
	
	char Chat[256];
	GetCmdArgString(Chat, sizeof(Chat));
	
	if (strlen(Chat) == 0)
	{
		return;
	}
	
	char sTime[256];
	FormatTime(sTime, sizeof(sTime), cv_sTimeFormat);
	
	char sFormat[512];
	if (client > 0 && client <= MaxClients)
	{
		char sName[MAX_NAME_LENGTH];
		GetClientName(client, sName, sizeof(sName));
		
		char sAuth[256];
		GetClientAuthId(client, AuthId_Steam2, sAuth, sizeof(sAuth));
		
		switch (sv_bFormatting)
		{
			case true: Format(sFormat, sizeof(sFormat), "[%s] \\cf1 (ADMINS)%s (%s)\\cf0", sTime, sName, sAuth);
			case false: Format(sFormat, sizeof(sFormat), "[%s] (ADMINS)%s (%s)", sTime, sName, sAuth);
		}
	}	
	else if (sv_bConsole)
	{
		switch (sv_bFormatting)
		{
			case true: Format(sFormat, sizeof(sFormat), "[%s] \\cf1 (ADMINS)Console\\cf0", sTime);
			case false: Format(sFormat, sizeof(sFormat), "[%s] (ADMINS)Console", sTime);
		}
	}
	else
	{
		return;
	}
	
	char sPrint[512];
	switch (sv_bFormatting)
	{
		case true: Format(sPrint, sizeof(sPrint), "%s: %s\\par", sFormat, Chat);
		case false: Format(sPrint, sizeof(sPrint), "%s: %s", sFormat, Chat);
	}
	
	WriteFileLine(Path_handle, sPrint);
	FlushFile(Path_handle);
}

public Action SMCSay(int client, const char[] command, int args)
{
	if(!sv_bEnabled || !sv_bCsay || !IsHooked) return;
	
	char Chat[256];
	GetCmdArgString(Chat, sizeof(Chat));
	
	if (strlen(Chat) == 0)
	{
		return;
	}
	
	char sTime[256];
	FormatTime(sTime, sizeof(sTime), cv_sTimeFormat);
	
	char sFormat[512];
	if (client > 0 && client <= MaxClients)
	{
		char sName[MAX_NAME_LENGTH];
		GetClientName(client, sName, sizeof(sName));
		
		char sAuth[256];
		GetClientAuthId(client, AuthId_Steam2, sAuth, sizeof(sAuth));
		
		switch (sv_bFormatting)
		{
			case true: Format(sFormat, sizeof(sFormat), "[%s] \\cf1 (Center-Text)%s (%s)\\cf0", sTime, sName, sAuth);
			case false: Format(sFormat, sizeof(sFormat), "[%s] (Center-Text)%s (%s)", sTime, sName, sAuth);
		}
	}	
	else if (sv_bConsole)
	{
		switch (sv_bFormatting)
		{
			case true: Format(sFormat, sizeof(sFormat), "[%s] \\cf1 (Center-Text)Console\\cf0", sTime);
			case false: Format(sFormat, sizeof(sFormat), "[%s] (Center-Text)Console", sTime);
		}
	}
	
	char sPrint[512];
	switch (sv_bFormatting)
	{
		case true: Format(sPrint, sizeof(sPrint), "%s: %s\\par", sFormat, Chat);
		case false: Format(sPrint, sizeof(sPrint), "%s: %s", sFormat, Chat);
	}
	
	WriteFileLine(Path_handle, sPrint);
	FlushFile(Path_handle);
}

public Action SMTSay(int client, const char[] command, int args)
{
	if(!sv_bEnabled || !sv_bTsay || !IsHooked) return;
	
	char Chat[256];
	GetCmdArgString(Chat, sizeof(Chat));
	
	if (strlen(Chat) == 0)
	{
		return;
	}
	
	char sTime[256];
	FormatTime(sTime, sizeof(sTime), cv_sTimeFormat);
	
	char sFormat[512];
	if (client > 0 && client <= MaxClients)
	{
		char sName[MAX_NAME_LENGTH];
		GetClientName(client, sName, sizeof(sName));
		
		char sAuth[256];
		GetClientAuthId(client, AuthId_Steam2, sAuth, sizeof(sAuth));
		
		switch (sv_bFormatting)
		{
			case true: Format(sFormat, sizeof(sFormat), "[%s] \\cf1 (Corner)%s (%s)\\cf0", sTime, sName, sAuth);
			case false: Format(sFormat, sizeof(sFormat), "[%s] (Corner)%s (%s)", sTime, sName, sAuth);
		}
	}	
	else if (sv_bConsole)
	{
		switch (sv_bFormatting)
		{
			case true: Format(sFormat, sizeof(sFormat), "[%s] \\cf1 (Corner)Console\\cf0", sTime);
			case false: Format(sFormat, sizeof(sFormat), "[%s] (Corner)Console", sTime);
		}
	}
	
	char sPrint[512];
	switch (sv_bFormatting)
	{
		case true: Format(sPrint, sizeof(sPrint), "%s: %s\\par", sFormat, Chat);
		case false: Format(sPrint, sizeof(sPrint), "%s: %s", sFormat, Chat);
	}
	
	WriteFileLine(Path_handle, sPrint);
	FlushFile(Path_handle);
}

public Action SMMSay(int client, const char[] command, int args)
{
	if(!sv_bEnabled || !sv_bMsay || !IsHooked) return;
	
	char Chat[256];
	GetCmdArgString(Chat, sizeof(Chat));
	
	if (strlen(Chat) == 0)
	{
		return;
	}
	
	char sTime[256];
	FormatTime(sTime, sizeof(sTime), cv_sTimeFormat);
	
	char sFormat[512];
	if (client > 0 && client <= MaxClients)
	{
		char sName[MAX_NAME_LENGTH];
		GetClientName(client, sName, sizeof(sName));
		
		char sAuth[256];
		GetClientAuthId(client, AuthId_Steam2, sAuth, sizeof(sAuth));
		
		switch (sv_bFormatting)
		{
			case true: Format(sFormat, sizeof(sFormat), "[%s] \\cf1 (Panel)%s (%s)\\cf0", sTime, sName, sAuth);
			case false: Format(sFormat, sizeof(sFormat), "[%s] (Panel)%s (%s)", sTime, sName, sAuth);
		}
	}	
	else if (sv_bConsole)
	{
		switch (sv_bFormatting)
		{
			case true: Format(sFormat, sizeof(sFormat), "[%s] \\cf1 (Panel)Console\\cf0", sTime);
			case false: Format(sFormat, sizeof(sFormat), "[%s] (Panel)Console", sTime);
		}
	}
	else
	{
		return;
	}
	
	char sPrint[512];
	switch (sv_bFormatting)
	{
		case true: Format(sPrint, sizeof(sPrint), "%s: %s\\par", sFormat, Chat);
		case false: Format(sPrint, sizeof(sPrint), "%s: %s", sFormat, Chat);
	}
	
	WriteFileLine(Path_handle, sPrint);
	FlushFile(Path_handle);
}

public Action SMHSay(int client, const char[] command, int args)
{
	if(!sv_bEnabled || !sv_bHsay || !IsHooked) return;
	
	char Chat[256];
	GetCmdArgString(Chat, sizeof(Chat));
	
	if (strlen(Chat) == 0)
	{
		return;
	}
	
	char sTime[256];
	FormatTime(sTime, sizeof(sTime), cv_sTimeFormat);
	
	char sFormat[512];
	if (client > 0 && client <= MaxClients)
	{
		char sName[MAX_NAME_LENGTH];
		GetClientName(client, sName, sizeof(sName));
		
		char sAuth[256];
		GetClientAuthId(client, AuthId_Steam2, sAuth, sizeof(sAuth));
		
		switch (sv_bFormatting)
		{
			case true: Format(sFormat, sizeof(sFormat), "[%s] \\cf1 (Hint)%s (%s)\\cf0", sTime, sName, sAuth);
			case false: Format(sFormat, sizeof(sFormat), "[%s] (Hint)%s (%s)", sTime, sName, sAuth);
		}
	}	
	else if (sv_bConsole)
	{
		switch (sv_bFormatting)
		{
			case true: Format(sFormat, sizeof(sFormat), "[%s] \\cf1 (Hint)Console\\cf0", sTime);
			case false: Format(sFormat, sizeof(sFormat), "[%s] (Hint)Console", sTime);
		}
	}
	else
	{
		return;
	}
	
	char sPrint[512];
	switch (sv_bFormatting)
	{
		case true: Format(sPrint, sizeof(sPrint), "%s: %s\\par", sFormat, Chat);
		case false: Format(sPrint, sizeof(sPrint), "%s: %s", sFormat, Chat);
	}
	
	WriteFileLine(Path_handle, sPrint);
	FlushFile(Path_handle);
}

public Action SMPSay(int client, const char[] command, int args)
{
	if(!sv_bEnabled || !sv_bPsay || !IsHooked) return;
	
	char Chat[256];
	GetCmdArgString(Chat, sizeof(Chat));
	
	if (strlen(Chat) == 0)
	{
		return;
	}
	
	char sTime[256];
	FormatTime(sTime, sizeof(sTime), cv_sTimeFormat);
	
	char Target[MAX_NAME_LENGTH];
	
	if (args == 2)
	{
		GetCmdArg(1, Target, sizeof(Target));
	}
	
	char sFormat[512];
	if (client > 0 && client <= MaxClients)
	{
		char sName[MAX_NAME_LENGTH];
		GetClientName(client, sName, sizeof(sName));
		
		char sAuth[256];
		GetClientAuthId(client, AuthId_Steam2, sAuth, sizeof(sAuth));
		
		switch (sv_bFormatting)
		{
			case true: Format(sFormat, sizeof(sFormat), "[%s] \\cf1 (Private: %s)%s (%s)\\cf0", sTime, Target, sName, sAuth);
			case false: Format(sFormat, sizeof(sFormat), "[%s] (Private: %s)%s (%s)", sTime, Target, sName, sAuth);
		}
	}	
	else if (sv_bConsole)
	{
		switch (sv_bFormatting)
		{
			case true: Format(sFormat, sizeof(sFormat), "[%s] (Private: %s)Console", sTime, Target);
			case false: Format(sFormat, sizeof(sFormat), "[%s] \\cf1 (Private: %s)Console\\cf0", sTime, Target);
		}
	}
	else
	{
		return;
	}
	
	char sPrint[512];
	switch (sv_bFormatting)
	{
		case true: Format(sPrint, sizeof(sPrint), "%s: %s\\par", sFormat, Chat);
		case false: Format(sPrint, sizeof(sPrint), "%s: %s", sFormat, Chat);
	}
	
	WriteFileLine(Path_handle, sPrint);
	FlushFile(Path_handle);
}