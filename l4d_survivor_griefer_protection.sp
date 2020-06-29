/* >>> CHANGELOG <<< //
[ v1.0 ]
Initial Release

[ v1.1 ]
Fixed - Corrected some mistakes with client checks

[ v1.2 ]
Fixed - Admins are now completely immune (mikaelangelis)

[ v1.3 ]
Feature - Added KickType option to cfg(delete old cfg) [1 = Immediate] [2 = Vote Kick] (edwinvega86)
// >>> CHANGELOG <<< */

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

static int iAttempts[MAXPLAYERS+1];
static bool bFirstSpawn[MAXPLAYERS+1];
static float fFirstSpawn[MAXPLAYERS+1], fOrigin[MAXPLAYERS+1][3], fDamageLimit[MAXPLAYERS+1];
static char sMessage[32];

ConVar JumpAttempts, DamageAllowance, WaitTime, KickMessage, KickType;

public Plugin myinfo =
{
	name = "防加入就黑枪跳楼",
	author = "MasterMind420",
	description = "Prevent Friendly Fire From Newly Connected Players For A Period Of Time",
	version = "1.3",
	url = ""
}

public void OnPluginStart()
{
	WaitTime = CreateConVar("l4d_wait_time", "45", "Friendly Fire Threshold In Seconds", FCVAR_NOTIFY);
	KickType = CreateConVar("l4d_kick_type", "1", "[1 = Immediate Kick] [2 = Vote Kick]", FCVAR_NOTIFY);
	KickMessage = CreateConVar("l4d_kick_message", "禁止捣乱", "Auto Kick Message", FCVAR_NOTIFY);
	JumpAttempts = CreateConVar("l4d_attempts", "3", "[0 = NoKick] Attempts When Jumping Off Ledge Before Kick", FCVAR_NOTIFY);
	DamageAllowance = CreateConVar("l4d_damage_allowance", "200.0", "[0.0 = NoKick] Amount Of Damage Allowed Before Kick", FCVAR_NOTIFY);

	HookEvent("player_disconnect", eEvents);

	AutoExecConfig(true, "l4d_survivor_griefer_protection");
}

public void OnConfigsExecuted()
{
	GetConVarString(KickMessage, sMessage, sizeof(sMessage));
}

public void OnClientPutInServer(int client)
{
	if (!bFirstSpawn[client])
	{
		bFirstSpawn[client] = true;
		fFirstSpawn[client] = GetEngineTime() + float(GetConVarInt(WaitTime));
	}

	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (IsClientInGame(client) && !IsFakeClient(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2)
	{
		if (GetEntProp(client, Prop_Data, "m_afButtonPressed") & 2)
			GetClientAbsOrigin(client, fOrigin[client]);
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if (IsValidClient(attacker) && IsClientInGame(attacker) && GetClientTeam(attacker) == 2 && !IsClientAdmin(attacker) || attacker == 0)
	{
		if (IsValidClient(victim) && IsClientInGame(victim) && GetClientTeam(victim) == 2)
		{
			if (damagetype & DMG_FALL && GetEngineTime() < fFirstSpawn[victim])
			{
				iAttempts[victim] += 1;
				CreateTimer(0.1, Teleport, GetClientUserId(victim), TIMER_FLAG_NO_MAPCHANGE);
				return Plugin_Handled;
			}

			if (damage <= 0.0 || GetEngineTime() < fFirstSpawn[attacker])
			{
				fDamageLimit[attacker] += damage;

				if (GetConVarFloat(DamageAllowance) > 0.0 && fDamageLimit[attacker] > GetConVarFloat(DamageAllowance))
				{
					fDamageLimit[attacker] = 0.0;

					if (GetConVarInt(KickType) == 1)
						KickClient(attacker, sMessage);
					else if (GetConVarInt(KickType) == 2)
						FakeClientCommand(attacker, "callvote kick %d", GetClientUserId(attacker));
				}

				return Plugin_Handled;
			}
		}
	}

	return Plugin_Continue;
}

public Action Teleport(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);

	if (IsValidClient(client) && IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2)
	{
		TeleportEntity(client, fOrigin[client], NULL_VECTOR, NULL_VECTOR);

		if (GetConVarInt(JumpAttempts) > 0 && iAttempts[client] == GetConVarInt(JumpAttempts))
		{
			iAttempts[client] = 0;
			fDamageLimit[client] = 0.0;
			bFirstSpawn[client] = false;
			KickClient(client, sMessage);
		}
	}
}

public void eEvents(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	iAttempts[client] = 0;
	fDamageLimit[client] = 0.0;
	bFirstSpawn[client] = false;
}

stock bool IsValidClient(int client)
{
	return (client > 0 && client <= MaxClients);
}

stock bool IsClientAdmin(int client)
{
    return CheckCommandAccess(client, "generic_admin", ADMFLAG_GENERIC, false);
}