#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2_skill_framework>

#define PLUGIN_VERSION			"0.0.1"
#include "modules/l4d2ps.sp"

public Plugin myinfo =
{
	name = "技能：救人调整",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/",
};

const int g_iMaxLevel = 1;
const int g_iMinLevel = 10;
const int g_iMinSkillLevel = 50;
const float g_fLevelFactor = 1.0;

int g_iSlotHealing, g_iSlotSurvival;
int g_iLevelReviveStop[MAXPLAYERS+1], g_iLevelMoveStop[MAXPLAYERS+1];

public OnPluginStart()
{
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_first_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	
	LoadTranslations("l4d2sf_revive.phrases.txt");
	
	g_iSlotHealing = L4D2SF_RegSlot("healing");
	g_iSlotSurvival = L4D2SF_RegSlot("survival");
	L4D2SF_RegPerk(g_iSlotHealing, "revivenonstop", g_iMaxLevel, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotSurvival, "movenonstop", g_iMaxLevel, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
}

public Action L4D2SF_OnGetPerkName(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "revivenonstop"))
		FormatEx(result, maxlen, "%T", "救人不中断", client, level);
	else if(!strcmp(name, "movenonstop"))
		FormatEx(result, maxlen, "%T", "移动不中断", client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public Action L4D2SF_OnGetPerkDescription(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "revivenonstop"))
		FormatEx(result, maxlen, "%T", tr("救人不中断%d", IntBound(level, 1, g_iMaxLevel)), client, level);
	else if(!strcmp(name, "movenonstop"))
		FormatEx(result, maxlen, "%T", tr("移动不中断%d", IntBound(level, 1, g_iMaxLevel)), client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public void L4D2SF_OnPerkPost(int client, int level, const char[] perk)
{
	if(!strcmp(perk, "revivenonstop"))
		g_iLevelReviveStop[client] = level;
	else if(!strcmp(perk, "movenonstop"))
		g_iLevelMoveStop[client] = level;
}

public void Event_PlayerSpawn(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	g_iLevelReviveStop[client] = L4D2SF_GetClientPerk(client, "revivenonstop");
	g_iLevelMoveStop[client] = L4D2SF_GetClientPerk(client, "movenonstop");
	
	SDKUnhook(client, SDKHook_OnTakeDamage, EntHook_OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamage, EntHook_OnTakeDamage);
}

public void Event_PlayerDeath(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	SDKUnhook(client, SDKHook_OnTakeDamage, EntHook_OnTakeDamage);
}

public Action EntHook_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damageType, int &weapon,
	float damageForce[3], float damagePosition[3], int damageCustom)
{
	if(GetClientTeam(victim) != 2)
		return Plugin_Continue;
	
	if(GetEntProp(victim, Prop_Send, "m_isIncapacitated", 1))
	{
		int reviver = GetEntPropEnt(victim, Prop_Send, "m_reviveOwner");
		if(!IsValidClient(reviver))
			return Plugin_Continue;
		
		if(g_iLevelReviveStop[victim] >= 1 || g_iLevelReviveStop[reviver] >= 1)
		{
			damageType = (DMG_ENERGYBEAM | DMG_RADIATION);
			return Plugin_Changed;
		}
	}
	else if(g_iLevelMoveStop[victim] >= 1 && attacker > MaxClients)
	{
		static char classname[64];
		if(!GetEdictClassname(attacker, classname, sizeof(classname)) || strcmp(classname, "infected", false))
			return Plugin_Continue;
		
		attacker = inflictor = 0;
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

int IntBound(int v, int min, int max)
{
	if(v < min)
		v = min;
	if(v > max)
		v = max;
	return v;
}
