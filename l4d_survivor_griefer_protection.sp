/* >>> CHANGELOG <<< //
[ v1.0 ]
Initial Release

[ v1.1 ]
Fixed - Corrected some mistakes with client checks

[ v1.2 ]
Fixed - Admins are now completely immune (mikaelangelis)

[ v1.3 ]
Feature - Added KickType option to cfg [1 = Immediate] [2 = Vote Kick] (edwinvega86)

[ v1.4 ]
Feature - Added late load support
		  Added admin cmd fft to disable and enable plugin
		  Added protection method for players switching teams or disconnecting
		  Added message to chat when trigger votekick, so it doesn't feel random(MasterMe)
		  Added message to regular kick so others know why someone was instant kicked.

Fixed - Ledge jump griefing protection was completely broken
		Callvote wasn't working correctly (MasterMe)

[ v1.5 ]
Feature - Added ban support(permanent and timed)

[ v1.6 ]
Feature - Added do not grief warning when close to being kicked or banned
Fixed - An error with ban support(permanent and timed) has been corrected
		Being charged, ridden, smoked etc. no longer triggers griefer protection

[ v1.6 ]
Fixed - Corrected an issue with admins triggering jump protection
// >>> CHANGELOG <<< */

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

EngineVersion game;
int iAttempts[MAXPLAYERS+1], iReviveHealth[MAXPLAYERS+1], iReviveCount[MAXPLAYERS+1];
bool bFirstSpawn[MAXPLAYERS+1], bLateLoad;
float fFirstSpawn[MAXPLAYERS+1], fFirstSpawnImmunity[MAXPLAYERS+1], fOrigin[MAXPLAYERS+1][3],
		fDamageLimit[MAXPLAYERS+1], fReviveHealthBuff[MAXPLAYERS+1], fHasDominator[MAXPLAYERS+1];
char sMessage[32];

ConVar JumpAttempts, DamageAllowance, WaitTime, KickMessage, KickType, TimedBan;

public Plugin myinfo =
{
	name = "幸存者捣乱保护",
	author = "MasterMind420",
	description = "Prevent Friendly Fire From Newly Connected Players For A Period Of Time",
	version = "1.6",
	url = ""
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	game = GetEngineVersion();

	if (game != Engine_Left4Dead && game != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}

	bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	RegAdminCmd("sm_sgpreset", ResetCmd, ADMFLAG_GENERIC, "");

	WaitTime = CreateConVar("l4d_wait_time", "180", "保护持续时间", FCVAR_NOTIFY);
	KickType = CreateConVar("l4d_kick_type", "1", "惩罚方式.1=踢出.2=封禁.3=起票", FCVAR_NOTIFY);
	KickMessage = CreateConVar("l4d_kick_message", "不准捣乱", "踢出理由", FCVAR_NOTIFY);
	JumpAttempts = CreateConVar("l4d_attempts", "3", "跳楼多少次要受到惩罚.0=禁用", FCVAR_NOTIFY);
	DamageAllowance = CreateConVar("l4d_damage_allowance", "150.0", "黑枪多少伤害要受到惩罚.0=禁用", FCVAR_NOTIFY);
	TimedBan = CreateConVar("l4d_timed_ban", "0", "封禁时长.0=永久", FCVAR_NOTIFY);

	AutoExecConfig(true, "l4d_survivor_griefer_protection");

	HookEvent("player_team", eEvents);
	HookEvent("player_disconnect", eEvents);

	if (bLateLoad)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
				OnClientPutInServer(i);
		}
	}
}

public Action ResetCmd(int client, int args)
{
	if (IsValidClient(client))
	{
		iAttempts[client] = 0;
		fDamageLimit[client] = 0.0;
		fFirstSpawn[client] = GetEngineTime() + float(GetConVarInt(WaitTime));
	}
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
		fFirstSpawnImmunity[client] = GetEngineTime() + 5.0;
		fFirstSpawn[client] = GetEngineTime() + float(GetConVarInt(WaitTime));
	}

	SDKHook(client, SDKHook_PreThink, OnPreThink);
	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamage);
}

public void OnPreThink(int client)
{
	if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2)
	{
		if (HasDominator(client))
			fHasDominator[client] = GetEngineTime() + 1.0;
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (IsClientInGame(client) && !IsFakeClient(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2)
	{
		if (GetEntProp(client, Prop_Data, "m_afButtonPressed") & IN_JUMP && !(GetEntityFlags(client) & FL_ONGROUND))
		{
			iReviveCount[client] = GetEntProp(client, Prop_Send, "m_currentReviveCount");
			iReviveHealth[client] = GetEntProp(client, Prop_Data, "m_iHealth");
			fReviveHealthBuff[client] = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
			GetClientAbsOrigin(client, fOrigin[client]);
		}
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if (IsValidClient(victim) && IsClientInGame(victim) && GetClientTeam(victim) == 2)
	{
		if (!IsClientAdmin(victim) && !IsFakeClient(victim))
		{
			if (GetEngineTime() >= fHasDominator[victim])
			{
				if (damagetype & DMG_FALL && GetEngineTime() < fFirstSpawn[victim])
				{
					iAttempts[victim] += 1;

					if (iAttempts[victim] == (GetConVarInt(JumpAttempts) - 1))
						PrintToChat(victim, "\x05跳楼警告");

					CreateTimer(0.1, Teleport, GetClientUserId(victim), TIMER_FLAG_NO_MAPCHANGE);
					return Plugin_Handled;
				}
			}
		}

		if (IsValidClient(attacker) && IsClientInGame(attacker) && GetClientTeam(attacker) == 2 && !IsClientAdmin(attacker) && !IsFakeClient(attacker))
		{
			if (damage <= 0.0 || GetEngineTime() < fFirstSpawn[attacker])
			{
				if (attacker == victim || GetEngineTime() < fFirstSpawnImmunity[attacker])
					return Plugin_Handled;

				fDamageLimit[attacker] += damage;

				if (fDamageLimit[attacker] >= (GetConVarFloat(DamageAllowance) - 50.0))
					PrintToChat(victim, "\x05黑枪警告");

				if (GetConVarFloat(DamageAllowance) > 0.0 && fDamageLimit[attacker] > GetConVarFloat(DamageAllowance))
				{
					fDamageLimit[attacker] = 0.0;
					HandleClient(attacker);
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

		HealthCheat(client);
		SetEntProp(client, Prop_Send, "m_reviveOwner", 0);
		SetEntProp(client, Prop_Send, "m_isIncapacitated", 0);
		SetEntProp(client, Prop_Send, "m_isHangingFromLedge", 0);
		SetEntProp(client, Prop_Send, "m_currentReviveCount", iReviveCount[client]);
		SetEntProp(client, Prop_Data, "m_iHealth", iReviveHealth[client]);
		SetEntPropFloat(client, Prop_Send, "m_healthBuffer", fReviveHealthBuff[client]);

		if (GetConVarInt(JumpAttempts) > 0 && iAttempts[client] == GetConVarInt(JumpAttempts))
		{
			iAttempts[client] = 0;
			fDamageLimit[client] = 0.0;
			bFirstSpawn[client] = false;

			if (GetEngineTime() < fFirstSpawnImmunity[client])
				return;

			HandleClient(client);
		}
	}
}

public void eEvents(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (StrEqual(name, "player_team"))
	{
		int iTeam = event.GetInt("team");
		int iOldTeam = event.GetInt("oldteam");
		bool bDisconnect = event.GetBool("disconnect");

		if (iOldTeam == 2 || iTeam == 2 && bDisconnect)
		{
			// int entity = -1;
			char sClsName[32];
			int maxEntity = GetMaxEntities();

			// while((entity = FindEntityByClassname(entity, "*")) != -1)
			for(int entity = MaxClients + 1; entity <= maxEntity; ++entity)
			{
				if(!IsValidEntity(entity))
					continue;
				
				if (!GetEntityClassname(entity, sClsName, sizeof(sClsName)))
					continue;

				if (StrContains(sClsName, "_projectile", false) == -1 && !StrEqual(sClsName, "inferno", false))
					continue;

				if (client == GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"))
					AcceptEntityInput(entity, "Kill");
			}
		}
	}
	else if (StrEqual(name, "player_disconnect"))
	{
		iAttempts[client] = 0;
		fDamageLimit[client] = 0.0;
		bFirstSpawn[client] = false;
	}
}

stock void HandleClient(int client)
{
	if (GetConVarInt(KickType) == 1)
	{
		PrintToChatAll("\x05玩家 \x04%N \x05因为搞事情而被送走", client);
		KickClient(client, sMessage);	
	}
	else if (GetConVarInt(KickType) == 2)
	{
		char sClsName[32];

		if (GetConVarInt(TimedBan) > 0)
		{
			PrintToChatAll("\x05玩家 \x04%N 因为搞事情而被禁止 \x05%i 分钟", client, GetConVarInt(TimedBan));
			Format(sClsName, sizeof(sClsName), "sm_ban #%N %i Other", client, GetConVarInt(TimedBan));
		}
		else
		{
			PrintToChatAll("\x05玩家 \x04%N \x05因为搞事情而被永久禁止", client);
			Format(sClsName, sizeof(sClsName), "sm_ban #%N 0 Other", client);
		}

		ServerCommand(sClsName);
	}
	else if (GetConVarInt(KickType) == 3)
	{
		PrintToChatAll("\x05玩家 \x04%N 因为搞事情而被起票", client);
		FakeClientCommand(client, "callvote kick %d", GetClientUserId(client));
	}
}

void HealthCheat(int client)
{
	int userflags = GetUserFlagBits(client);
	int cmdflags = GetCommandFlags("give");
	SetUserFlagBits(client, ADMFLAG_ROOT);
	SetCommandFlags("give", cmdflags & ~FCVAR_CHEAT);
	FakeClientCommand(client,"give health");
	SetCommandFlags("give", cmdflags);
	SetUserFlagBits(client, userflags);
}

stock bool HasDominator(int client)
{
	if (IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client))
	{
		if (GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0)
			return true;
		else if (GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0)
			return true;
		else if (GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0)
			return true;
		else if (GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0)
			return true;
		else if (GetEntPropEnt(client, Prop_Send, "m_carryAttacker" ) > 0)
			return true;
	}

	return false;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (entity > 0 && IsValidEntity(entity))
    {
        char sClsName[32];
        GetEntityClassname(entity, sClsName, sizeof(sClsName));

        if (StrContains(sClsName, "point_deathfall_camera") > -1)
			SDKHook(entity, SDKHook_SpawnPost, SpawnPost);
    }
}

public void SpawnPost(int entity)
{
	SDKUnhook(entity, SDKHook_SpawnPost, SpawnPost);
	RequestFrame(NextFrame, entity);
}

public void NextFrame(int entity)
{
	AcceptEntityInput(entity, "Kill");
}

stock bool IsValidClient(int client)
{
	return (client > 0 && client <= MaxClients);
}

stock bool IsClientAdmin(int client)
{
    return CheckCommandAccess(client, "generic_admin", ADMFLAG_GENERIC, false);
}