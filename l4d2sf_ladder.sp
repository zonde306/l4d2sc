#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2_skill_framework>

#define PLUGIN_VERSION			"0.0.1"
#include "modules/l4d2ps.sp"

public Plugin myinfo =
{
	name = "技能：梯子相关",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/",
};

const int g_iMaxLevel = 1;
const int g_iMinLevel = 3;
const int g_iMinSkillLevel = 20;
const float g_fLevelFactor = 1.0;

int g_iSlotSurvival;
int g_iLevelLadderGun[MAXPLAYERS+1], g_iLevelLadderPush[MAXPLAYERS+1];

public OnPluginStart()
{
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_first_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("bot_player_replace", Event_PlayerReplaceBot);
	HookEvent("player_bot_replace", Event_BotReplacePlayer);
	
	LoadTranslations("l4d2sf_ladder.phrases.txt");
	
	g_iSlotSurvival = L4D2SF_RegSlot("survival");
	L4D2SF_RegPerk(g_iSlotSurvival, "ladder_guns", g_iMaxLevel, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotSurvival, "ladder_push", g_iMaxLevel, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
}

public Action L4D2SF_OnGetPerkName(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "ladder_guns"))
		FormatEx(result, maxlen, "%T", "梯子上掏枪", client, level);
	else if(!strcmp(name, "ladder_push"))
		FormatEx(result, maxlen, "%T", "爬梯推开阻碍", client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public Action L4D2SF_OnGetPerkDescription(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "ladder_guns"))
		FormatEx(result, maxlen, "%T", tr("梯子上掏枪%d", IntBound(level, 1, g_iMaxLevel)), client, level);
	else if(!strcmp(name, "ladder_push"))
		FormatEx(result, maxlen, "%T", tr("爬梯推开阻碍%d", IntBound(level, 1, g_iMaxLevel)), client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public void L4D2SF_OnPerkPost(int client, int level, const char[] perk)
{
	if(!strcmp(perk, "ladder_guns"))
		g_iLevelLadderGun[client] = level;
	else if(!strcmp(perk, "ladder_push"))
		g_iLevelLadderPush[client] = level;
}

MoveType g_eOldMoveType[MAXPLAYERS+1];

public void Event_PlayerSpawn(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	g_iLevelLadderGun[client] = L4D2SF_GetClientPerk(client, "ladder_guns");
	g_iLevelLadderPush[client] = L4D2SF_GetClientPerk(client, "ladder_push");
	
	SDKHook(client, SDKHook_TouchPost, EntHook_TouchPost);
}

public void Event_PlayerDeath(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	SDKUnhook(client, SDKHook_TouchPost, EntHook_TouchPost);
}

public void Event_PlayerReplaceBot(Event event, const char[] eventName, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("player"));
	int bot = GetClientOfUserId(event.GetInt("bot"));
	
	g_eOldMoveType[player] = g_eOldMoveType[bot];
	SDKUnhook(bot, SDKHook_TouchPost, EntHook_TouchPost);
	SDKHook(player, SDKHook_TouchPost, EntHook_TouchPost);
}

public void Event_BotReplacePlayer(Event event, const char[] eventName, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("player"));
	int bot = GetClientOfUserId(event.GetInt("bot"));
	
	g_eOldMoveType[bot] = g_eOldMoveType[player];
	SDKUnhook(player, SDKHook_TouchPost, EntHook_TouchPost);
	SDKHook(bot, SDKHook_TouchPost, EntHook_TouchPost);
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3],
	int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if(g_iLevelLadderGun[client] <= 0 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_isGhost", 1))
		return Plugin_Continue;
	
	MoveType moveType = GetEntityMoveType(client);
	if(moveType == MOVETYPE_FLY)
	{
		if(g_eOldMoveType[client] != MOVETYPE_LADDER)
			return Plugin_Continue;
		
		if(IsMoving(client))
			SetEntityMoveType(client, MOVETYPE_LADDER);
		
		return Plugin_Continue;
	}
	
	if(moveType == MOVETYPE_LADDER)
	{
		if(!IsMoving(client))
		{
			if(g_eOldMoveType[client] == MOVETYPE_FLY)
				return Plugin_Continue;
			
			SetEntityMoveType(client, MOVETYPE_FLY);
		}
	}
	
	g_eOldMoveType[client] = moveType;
	return Plugin_Continue;
}

public void EntHook_TouchPost(int client, int other)
{
	if(g_iLevelLadderPush[client] <= 0 || !IsGuyTroll(client, other))
		return;
	
	if(IsChargerCharging(other))
		return;
	
	if(IsOnLadder(other))
	{
		float origin[3];
		if(IsValidClient(other))
			GetClientAbsOrigin(other, origin);
		else
			GetEntPropVector(other, Prop_Send, "m_vecOrigin", origin);
		
		origin[2] += 2.5;
		TeleportEntity(other, origin, NULL_VECTOR, NULL_VECTOR);
	}
	else
	{
		TeleportEntity(other, NULL_VECTOR, NULL_VECTOR, view_as<float>({0.0, 0.0, 251.0}));
	}
}

int IntBound(int v, int min, int max)
{
	if(v < min)
		v = min;
	if(v > max)
		v = max;
	return v;
}

bool IsMoving(int client)
{
	float fVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fVelocity);
	return (GetVectorLength(fVelocity) > 0.0);
}

bool IsGuyTroll(int client, int other)
{
	bool onLadder = IsOnLadder(client);
	bool sameTeam = GetClientTeam(client) == GetEntProp(other, Prop_Data, "m_iTeamNum");
	
	float origin[3];
	if(IsValidClient(other))
		origin[2] = GetEntPropFloat(other, Prop_Send, "m_vecOrigin[2]");
	else
		GetEntPropVector(other, Prop_Send, "m_vecOrigin", origin);
	
	bool inBottom = GetEntPropFloat(client, Prop_Send, "m_vecOrigin[2]") < origin[2];
	
	return (onLadder && !sameTeam && inBottom);
}

bool IsChargerCharging(int client)
{
	if( IsValidAliveClient(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == Z_CHARGER )
	{
		int ability = GetEntPropEnt(client, Prop_Send, "m_customAbility"); // ability_charge
		if( ability > 0 && IsValidEdict(ability) && GetEntProp(ability, Prop_Send, "m_isCharging") )
		{
			return true;
		}
	}
	
	return false;
}

bool IsOnLadder(int entity)
{
    return GetEntityMoveType(entity) == MOVETYPE_LADDER;
}
