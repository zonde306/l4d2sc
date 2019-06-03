/*
V1.0
Initial Release

V1.1
!pb command now accepts time argument.
Added cvar l4d_max_time (Admins are immune to this).
Added l4d_pipebomb_duration.cfg for setting max allowable timer.

V1.2
Added cvar l4d_admin_only to set admin only access.
*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

float Duration[MAXPLAYERS+1];

ConVar MaxTime;
ConVar AdminOnly;

public Plugin myinfo =
{
	name = "土雷持续时间",
	author = "MasterMind420",
	description = "Modifies Pipebomb Duration Per Player",
	version = "1.2",
	url = ""
}

public void OnPluginStart()
{
	MaxTime = CreateConVar("l4d_max_time", "10", "Maximum Allowed Duration");
	AdminOnly = CreateConVar("l4d_admin_only", "0", "Allow Admins Only");

	HookEvent("weapon_fire", Event_WeaponFire, EventHookMode_Pre);

	RegConsoleCmd("sm_pb", cmdTime, "Set Pipebomb Timer");

	float duration = FindConVar("pipe_bomb_timer_duration").FloatValue;
	for (int i = 1; i <= MAXPLAYERS; i++)
		Duration[i] = duration;

	AutoExecConfig(true, "l4d_pipebomb_duration");
}

public Action cmdTime(int client, int args)
{
	if (args < 1)
		return Plugin_Handled;

	if (!IsAdmin(client) && GetConVarInt(AdminOnly) == 1)
		return Plugin_Handled;

	char arg[PLATFORM_MAX_PATH];
	GetCmdArg(1, arg, sizeof(arg));
	int Time = StringToInt(arg);

	if(IsAdmin(client))
	{
		Duration[client] = Time;
		ReplyToCommand(client, "\x04[Pipebomb] \x01Timer Set To %d", Time);
		return Plugin_Handled;
	}
	else if (Time > GetConVarInt(MaxTime))
		return Plugin_Handled;

	Duration[client] = Time;
	ReplyToCommand(client, "\x04[Pipebomb] \x01Timer Set To %d", Time);

	return Plugin_Handled;
}

public Action Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (!IsSurvivor(client) || !IsPlayerAlive(client))
		return Plugin_Continue;

	char item[10];
	GetEventString(event, "weapon", item, sizeof(item));

	if(!StrEqual(item, "pipe_bomb"))
		return Plugin_Continue;
	else
		SetConVarFloat(FindConVar("pipe_bomb_timer_duration"), Duration[client]);

	return Plugin_Continue;
}

stock bool IsSurvivor(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2);
}

stock bool IsAdmin(int client)
{
	if (GetUserFlagBits(client) & ADMFLAG_ROOT)
		return true;
	return false;
}