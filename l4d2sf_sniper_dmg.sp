#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2_skill_framework>

#define PLUGIN_VERSION			"0.0.1"
#include "modules/l4d2ps.sp"

public Plugin myinfo =
{
	name = "技能树伤害类技能",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/",
};

const int g_iMaxLevel = 1;
const int g_iMinLevel = 3;
const int g_iMinSkillLevel = 15;
const float g_fLevelFactor = 1.0;

int g_iSlotSniper;
ConVar g_cvScoutDamage, g_cvAwpDamage;

public OnPluginStart()
{
	InitPlugin("sfsd");
	g_cvScoutDamage = CreateConVar("l4d2_sfsd_scout", "180", "Scout伤害", CVAR_FLAGS, true, 0.0);
	g_cvAwpDamage = CreateConVar("l4d2_sfsd_awp", "325", "AWP伤害", CVAR_FLAGS, true, 0.0);
	AutoExecConfig(true, "l4d2_sfsd");
	
	OnCvarChanged_UpdateCache(null, "", "");
	g_cvScoutDamage.AddChangeHook(OnCvarChanged_UpdateCache);
	g_cvAwpDamage.AddChangeHook(OnCvarChanged_UpdateCache);
	
	LoadTranslations("l4d2sf_sniper_dmg.phrases.txt");
	
	g_iSlotSniper = L4D2SF_RegSlot("sniper");
	L4D2SF_RegPerk(g_iSlotSniper, "scout_dmg", g_iMaxLevel, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotSniper, "awp_dmg", g_iMaxLevel, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_first_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
}

float g_fScoutDamage, g_fAwpDamage;

public Action L4D2SF_OnGetPerkName(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "scout_dmg"))
		FormatEx(result, maxlen, "%T", "鸟狙伤害", client, level);
	else if(!strcmp(name, "awp_dmg"))
		FormatEx(result, maxlen, "%T", "大鸟伤害", client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public Action L4D2SF_OnGetPerkDescription(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(level <= 0 || level > g_iMaxLevel)
		return Plugin_Continue;
	
	if(!strcmp(name, "scout_dmg"))
		FormatEx(result, maxlen, "%T", tr("鸟狙伤害%d", level), client, level, g_fScoutDamage);
	else if(!strcmp(name, "awp_dmg"))
		FormatEx(result, maxlen, "%T", tr("大鸟伤害%d", level), client, level, g_fAwpDamage);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public void OnCvarChanged_UpdateCache(ConVar cvar, const char[] ov, const char[] nv)
{
	g_fScoutDamage = g_cvScoutDamage.FloatValue;
	g_fAwpDamage = g_cvAwpDamage.FloatValue;
}

int g_iLevelScout[MAXPLAYERS+1], g_iLevelAwp[MAXPLAYERS+1];

public void L4D2SF_OnPerkPost(int client, int level, const char[] perk)
{
	if(!strcmp(perk, "scout_dmg"))
		g_iLevelScout[client] = level;
	else if(!strcmp(perk, "awp_dmg"))
		g_iLevelAwp[client] = level;
}

public void L4D2SF_OnLoad(int client)
{
	g_iLevelScout[client] = L4D2SF_GetClientPerk(client, "scout_dmg");
	g_iLevelAwp[client] = L4D2SF_GetClientPerk(client, "awp_dmg");
}

public void Event_PlayerSpawn(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	g_iLevelScout[client] = L4D2SF_GetClientPerk(client, "scout_dmg");
	g_iLevelAwp[client] = L4D2SF_GetClientPerk(client, "awp_dmg");
	
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

public void OnEntityCreated(int entity, const char[] classname)
{
	if(!strcmp(classname, "infected", false) || !strcmp(classname, "witch", false))
	{
		SDKUnhook(entity, SDKHook_OnTakeDamage, EntHook_OnTakeDamage);
		SDKHook(entity, SDKHook_OnTakeDamage, EntHook_OnTakeDamage);
	}
}

public void OnEntityDestroyed(int entity)
{
	SDKUnhook(entity, SDKHook_OnTakeDamage, EntHook_OnTakeDamage);
}

public Action EntHook_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damageType, int &weapon,
	float damageForce[3], float damagePosition[3], int damageCustom)
{
	if(!IsValidClient(attacker) || damage <= 0.0)
		return Plugin_Continue;
	
	int teamAttacker = GetClientTeam(attacker);
	int teamVictim = GetEntProp(victim, Prop_Data, "m_iTeamNum");
	if(teamAttacker == teamVictim)
		return Plugin_Continue;
	
	static char classname[64];
	if(weapon > MaxClients && IsValidEdict(weapon))
		GetEdictClassname(weapon, classname, sizeof(classname));
	else if(inflictor > MaxClients && IsValidEdict(inflictor))
		GetEdictClassname(inflictor, classname, sizeof(classname));
	else
		return Plugin_Continue;
	
	if(teamAttacker == 2 && teamVictim == 3 && (damageType & DMG_BULLET))
	{
		if(g_iLevelScout[attacker] >= 1 && !strcmp(classname, "weapon_sniper_scout", false))
		{
			damage = g_fScoutDamage;
			return Plugin_Changed;
		}
		if(g_iLevelAwp[attacker] >= 1 && !strcmp(classname, "weapon_sniper_awp", false))
		{
			damage = g_fAwpDamage;
			return Plugin_Changed;
		}
	}
	
	return Plugin_Changed;
}
