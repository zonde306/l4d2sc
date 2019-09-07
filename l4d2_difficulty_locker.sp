#pragma semicolon 1
#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION			"0.1"
#include "modules/l4d2ps.sp"

public Plugin myinfo =
{
	name = "难度锁定",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

int g_iMissionLost = 0;
ConVar g_hCvarDifficulty;
ConVar g_pCvarDifficulty, g_pCvarLostDemote, g_pCvarMinDifficulty, g_pCvarBlockDifficulty, g_pCvarBlockReturn, g_pCvarBlockRestart;

public void OnPluginStart()
{
	InitPlugin("dl");
	g_pCvarDifficulty = CreateConVar("l4d2_dl_default", "4", "默认难度等级.0=禁用.1=简单.2=普通.3=困难.4=专家", CVAR_FLAGS, true, 0.0, true, 4.0);
	g_pCvarMinDifficulty = CreateConVar("l4d2_dl_min", "2", "最小难度等级.0=禁用.1=简单.2=普通.3=困难.4=专家", CVAR_FLAGS, true, 0.0, true, 4.0);
	g_pCvarLostDemote = CreateConVar("l4d2_dl_demote", "3", "失败多少次降级难度.0=禁用", CVAR_FLAGS, true, 0.0, true, 5.0);
	g_pCvarBlockDifficulty = CreateConVar("l4d2_dl_block_difficulty", "1", "禁止难度投票", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarBlockReturn = CreateConVar("l4d2_dl_block_return", "1", "禁止返回大厅投票", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarBlockRestart = CreateConVar("l4d2_dl_block_restart", "1", "禁止重启战役投票", CVAR_FLAGS, true, 0.0, true, 1.0);
	AutoExecConfig(true, "l4d2_difficulty_locker");
	
	g_hCvarDifficulty = FindConVar("z_difficulty");
	g_hCvarDifficulty.AddChangeHook(ConVarHooked_OnDifficultyChanged);
	AddCommandListener(Cmd_CallVote, "callvote");
	
	HookEvent("round_start", Event_RoundStart);
	HookEvent("player_left_start_area", Event_RoundStart);
	HookEvent("door_unlocked", Event_DoorUnlocked);
	// HookEvent("round_end", Event_RoundEnd);
	HookEvent("map_transition", Event_RoundEnd);
	HookEvent("mission_lost", Event_MissionLost);
	HookEvent("finale_win", Event_RoundEnd);
}

public void Event_RoundStart(Event event, const char[] eventName, bool dontBroadcast)
{
	if(!IsPluginAllow())
		return;
	
	UpdateDifficultyLock(0);
}

public void Event_DoorUnlocked(Event event, const char[] eventName, bool dontBroadcast)
{
	if(!event.GetBool("checkpoint"))
		return;
	
	Event_RoundStart(event, eventName, dontBroadcast);
}

public void Event_RoundEnd(Event event, const char[] eventName, bool dontBroadcast)
{
	g_iMissionLost = 0;
}

public void Event_MissionLost(Event event, const char[] eventName, bool dontBroadcast)
{
	if(!IsPluginAllow())
		return;
	
	g_iMissionLost += 1;
	
	int lossLevel = g_pCvarLostDemote.IntValue;
	while(g_iMissionLost > lossLevel)
		lossLevel += g_iMissionLost;
	
	PrintToChatAll("\x03[DL]\x01 当前失败累计：%d/%d", g_iMissionLost, lossLevel);
}

public void OnMapStart()
{
	g_iMissionLost = 0;
	UpdateDifficultyLock(0);
}

public void OnMapEnd()
{
	g_iMissionLost = 0;
}

public Action Cmd_CallVote(int client, const char[] command, int argc)
{
	if(!IsPluginAllow() || argc < 2)
		return Plugin_Continue;
	
	char voteType[32];
	GetCmdArg(1, voteType, 32);
	UpdateDifficultyLock(0);
	
	if(g_pCvarBlockDifficulty.BoolValue && StrEqual(voteType, "ChangeDifficulty", false))
		return Plugin_Handled;
	
	if(g_pCvarBlockReturn.BoolValue && StrEqual(voteType, "ReturnToLobby", false))
		return Plugin_Handled;
	
	if(g_pCvarBlockRestart.BoolValue && StrEqual(voteType, "RestartGame", false))
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public void ConVarHooked_OnDifficultyChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	if(!IsPluginAllow())
		return;
	
	// 防止无限递归
	RequestFrame(UpdateDifficultyLock, 0);
}

public void UpdateDifficultyLock(any unused)
{
	int level = GetCurrentDifficulty();
	if(level > 0 && level != GetDifficultyLevel())
		SetDifficultyLevel(level);
}

int GetCurrentDifficulty()
{
	int baseLevel = g_pCvarDifficulty.IntValue;
	int lossLevel = g_pCvarLostDemote.IntValue;
	int minLevel = g_pCvarMinDifficulty.IntValue;
	
	if(baseLevel <= 0)
		baseLevel = GetDifficultyLevel();
	
	if(lossLevel > 0)
		baseLevel -= g_iMissionLost / lossLevel;
	
	if(baseLevel < minLevel)
		baseLevel = minLevel;
	
	return baseLevel;
}

int GetDifficultyLevel()
{
	char difficulty[32];
	g_hCvarDifficulty.GetString(difficulty, 32);
	switch(difficulty[0])
	{
		case 'e', 'E':
			return 1;
		case 'n', 'N':
			return 2;
		case 'h', 'H':
			return 3;
		case 'i', 'I':
			return 4;
	}
	
	return 0;
}

void SetDifficultyLevel(int level)
{
	switch(level)
	{
		case 1:
			g_hCvarDifficulty.SetString("easy");
		case 2:
			g_hCvarDifficulty.SetString("normal");
		case 3:
			g_hCvarDifficulty.SetString("hard");
		case 4:
			g_hCvarDifficulty.SetString("impossible");
	}
}
