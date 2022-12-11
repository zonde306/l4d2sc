#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

public Plugin myinfo =
{
	name = "背景音乐",
	author = "zonde306",
	description = "",
	version = "0.1",
	url = ""
};

bool g_bLateLoad = false;
ArrayList g_TankBGM, g_WitchBGM;
char g_szBGMPlaying[PLATFORM_MAX_PATH];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_TankBGM = CreateArray(PLATFORM_MAX_PATH);
	g_WitchBGM = CreateArray(PLATFORM_MAX_PATH);
	
	HookEvent("tank_spawn", Event_TankSpawn);
	HookEvent("tank_killed", Event_TankKilled);
	HookEvent("zombie_ignited", Event_ZombieIgnited);
	// HookEvent("witch_spawn", Event_WitchSpawn);
	HookEvent("witch_killed", Event_WitchKilled);
	HookEvent("witch_harasser_set", Event_WitchAngry);
	
	if(g_bLateLoad && IsServerProcessing())
	{
		
	}
}

void LoadPreset()
{
	char buffer[PLATFORM_MAX_PATH];
	
	BuildPath(Path_SM, buffer, sizeof(buffer), "data/tank_bgm.txt");
	if(FileExists(buffer))
	{
		File file = OpenFile(buffer, "rt");
		g_TankBGM.Clear();
		
		while(!file.EndOfFile())
		{
			file.ReadLine(buffer, sizeof(buffer));
			g_TankBGM.PushString(buffer);
		}
		
		delete file;
	}
	
	BuildPath(Path_SM, buffer, sizeof(buffer), "data/witch_bgm.txt");
	if(FileExists(buffer))
	{
		File file = OpenFile(buffer, "rt");
		g_WitchBGM.Clear();
		
		while(!file.EndOfFile())
		{
			file.ReadLine(buffer, sizeof(buffer));
			g_WitchBGM.PushString(buffer);
		}
		
		delete file;
	}
}

public void OnMapStart()
{
	LoadPreset();
	
	char buffer[PLATFORM_MAX_PATH];
	for(int i = 0; i < g_TankBGM.Length; ++i)
	{
		g_TankBGM.GetString(i, buffer, sizeof(buffer));
		AddFileToDownloadsTable(buffer);
	}
	for(int i = 0; i < g_WitchBGM.Length; ++i)
	{
		g_WitchBGM.GetString(i, buffer, sizeof(buffer));
		AddFileToDownloadsTable(buffer);
	}
}

public void Event_TankSpawn(Event event, const char[] eventName, bool dontBoardcast)
{
	if(g_TankBGM.Length <= 0)
		return;
	
	char sound[PLATFORM_MAX_PATH];
	g_TankBGM.GetString(GetRandomInt(0, g_TankBGM.Length - 1), sound, sizeof(sound));
	
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) != 2)
			continue;
		
		L4D_StopMusic(i, "Event.Tank");
		L4D_StopMusic(i, "Event.TankMidpoint");
		L4D_StopMusic(i, "Event.TankBrothers");
		L4D_StopMusic(i, "C2M5.RidinTank1");
		L4D_StopMusic(i, "C2M5.RidinTank2");
		L4D_StopMusic(i, "C2M5.BadManTank1");
		L4D_StopMusic(i, "C2M5.BadManTank2");
	}
}

public void Event_WitchAngry(Event event, const char[] eventName, bool dontBoardcast)
{
	if(g_WitchBGM.Length <= 0)
		return;
	
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) != 2)
			continue;
		
		L4D_StopMusic(i, "Event.WitchAttack");
	}
}

public void Event_ZombieIgnited(Event event, const char[] eventName, bool dontBoardcast)
{
	if(g_WitchBGM.Length <= 0)
		return;
	
	char victimname[16];
	event.GetString("victimname", victimname, sizeof(victimname));
	if(strcmp(victimname, "Witch", false))
		return;
	
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) != 2)
			continue;
		
		L4D_StopMusic(i, "Event.WitchBurning");
	}
}
