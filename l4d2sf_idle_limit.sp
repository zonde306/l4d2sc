#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <l4d2_skill_framework>

#define PLUGIN_VERSION			"0.0.1"
#include "modules/l4d2ps.sp"

public Plugin myinfo =
{
	name = "闲置限制",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/",
};

ConVar g_cvIdleDelay, g_cvIdleInterval, g_cvIdleWithTrapped, g_cvIdleWithGettingUp, g_cvIdleWithThrowing, g_cvIdleWithBile, g_cvIdleWithStaggering;
int g_iSlotSurvival;
int g_iLevelIdle[MAXPLAYERS+1];

public OnPluginStart()
{
	InitPlugin("sfil");
	g_cvIdleDelay = CreateConVar("l4d2_sfil_delay", "3.0", "闲置延迟", CVAR_FLAGS, true, 0.0);
	g_cvIdleInterval = CreateConVar("l4d2_sfil_interval", "30.0", "闲置最小间隔", CVAR_FLAGS, true, 0.0);
	g_cvIdleWithTrapped = CreateConVar("l4d2_sfil_trapped", "0", "是否允许被控时闲置", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_cvIdleWithGettingUp = CreateConVar("l4d2_sfil_getting_up", "0", "是否允许起身时闲置", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_cvIdleWithThrowing = CreateConVar("l4d2_sfil_throwing", "0", "是否允许投掷手雷时闲置", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_cvIdleWithBile = CreateConVar("l4d2_sfil_bile", "0", "是否允许胆汁状态时闲置", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_cvIdleWithStaggering = CreateConVar("l4d2_sfil_staggering", "0", "是否允许失衡时闲置", CVAR_FLAGS, true, 0.0, true, 1.0);
	AutoExecConfig(true, "l4d2_sf_idle_limit");
	
	AddCommandListener(Command_GoAwayBlocker, "go_away_from_keyboard");
	RegConsoleCmd("sm_away", Cmd_GoAway);
	
	LoadTranslations("l4d2sf_idle.phrases.txt");
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_first_spawn", Event_PlayerSpawn);
	
	g_iSlotSurvival = L4D2SF_RegSlot("survival");
	L4D2SF_RegPerk(g_iSlotSurvival, "idle", 3, 20, 3, 1.0);
}

public Action L4D2SF_OnGetPerkName(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "idle"))
		FormatEx(result, maxlen, "%T", "闲置", client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public Action L4D2SF_OnGetPerkDescription(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "idle"))
		FormatEx(result, maxlen, "%T", tr("闲置%d", IntBound(level, 1, 1)), client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public void L4D2SF_OnPerkPost(int client, int level, const char[] perk)
{
	if(!strcmp(perk, "idle"))
		g_iLevelIdle[client] = level;
}

public void Event_PlayerSpawn(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	g_iLevelIdle[client] = L4D2SF_GetClientPerk(client, "idle");
}

int IntBound(int v, int min, int max)
{
	if(v < min)
		v = min;
	if(v > max)
		v = max;
	return v;
}

Handle g_hTimerIdle[MAXPLAYERS+1];
float g_fNextIdleTime[MAXPLAYERS+1];

public Action Command_GoAwayBlocker(int client, const char[] command, int argc)
{
	return Cmd_GoAway(client, argc);
}

public Action Cmd_GoAway(int client, int argc)
{
	if(!IsValidAliveClient(client) || GetClientTeam(client) != 2)
		return Plugin_Continue;
	
	if(g_iLevelIdle[client] >= 3)
	{
		Timer_GoIdle(null, client);
		return Plugin_Handled;
	}
	
	float time = GetEngineTime();
	if(g_fNextIdleTime[client] > time)
		return Plugin_Handled;
	
	if(g_iLevelIdle[client] < 2 && !IsAllowIdle(client))
		return Plugin_Handled;
	
	if(g_hTimerIdle[client] != null)
		return Plugin_Handled;
	
	if(g_iLevelIdle[client] >= 1)
		g_hTimerIdle[client] = CreateTimer(1.0, Timer_GoIdle, client, TIMER_FLAG_NO_MAPCHANGE);
	else
		g_hTimerIdle[client] = CreateTimer(g_cvIdleDelay.FloatValue, Timer_GoIdle, client, TIMER_FLAG_NO_MAPCHANGE);
	
	return Plugin_Handled;
}

public Action Timer_GoIdle(Handle timer, any client)
{
	g_hTimerIdle[client] = null;
	
	if(!IsValidAliveClient(client))
		return Plugin_Continue;
	
	L4D_ReplaceWithBot(client);
	return Plugin_Continue;
}

bool IsAllowIdle(int client)
{
	if(!g_cvIdleWithTrapped.BoolValue && IsTrapped(client))
		return false;
	
	if(!g_cvIdleWithGettingUp.BoolValue && IsGettingUp(client))
		return false;
	
	if(!g_cvIdleWithBile.BoolValue && IsInBile(client))
		return false;
	
	if(!g_cvIdleWithStaggering.BoolValue && IsStaggering(client))
		return false;
	
	
}

bool IsInBile(int client)
{
	char result[64];
	L4D2_GetVScriptOutput(tr("PlayerInstanceFromIndex(%d).IsIT()", client), result, sizeof(result));
	return !strcmp(result, "true");
}

bool IsTrapped(int client)
{
	char result[64];
	L4D2_GetVScriptOutput(tr("PlayerInstanceFromIndex(%d).IsDominatedBySpecialInfected()", client), result, sizeof(result));
	return !strcmp(result, "true");
}

bool IsGettingUp(int client)
{
	char result[64];
	L4D2_GetVScriptOutput(tr("PlayerInstanceFromIndex(%d).IsGettingUp()", client), result, sizeof(result));
	return !strcmp(result, "true");
}

bool IsStaggering(int client)
{
	char result[64];
	L4D2_GetVScriptOutput(tr("PlayerInstanceFromIndex(%d).IsStaggering()", client), result, sizeof(result));
	return !strcmp(result, "true");
}
