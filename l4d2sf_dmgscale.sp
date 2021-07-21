#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2_skill_framework>

#define PLUGIN_VERSION			"0.0.1"
#include "modules/l4d2ps.sp"

public Plugin myinfo =
{
	name = "技能：伤害缩放",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/",
};

const int g_iMaxLevel = 3;
const int g_iMinLevel = 20;
const int g_iMinSkillLevel = 30;
const float g_fLevelFactor = 1.0;

int g_iSlotSurvival;
int g_iLevelInScale[MAXPLAYERS+1], g_iLevelOutScale[MAXPLAYERS+1];
ConVar g_cvDiffFac[4], g_cvBaseFac, g_cvNextDiff, g_cvDiff;

public OnPluginStart()
{
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_first_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	
	g_cvDiffFac[0] = FindConVar("z_non_head_damage_factor_easy");
	g_cvDiffFac[1] = FindConVar("z_non_head_damage_factor_normal");
	g_cvDiffFac[2] = FindConVar("z_non_head_damage_factor_hard");
	g_cvDiffFac[3] = FindConVar("z_non_head_damage_factor_expert");
	g_cvBaseFac = FindConVar("z_non_head_damage_factor_multiplier");
	g_cvNextDiff = FindConVar("z_use_next_difficulty_damage_factor");
	g_cvDiff = FindConVar("z_difficulty");
	
	OnDifficultyChanged(null, "", "");
	g_cvDiff.AddChangeHook(OnDifficultyChanged);
	g_cvDiffFac[0].AddChangeHook(OnDifficultyChanged);
	g_cvDiffFac[1].AddChangeHook(OnDifficultyChanged);
	g_cvDiffFac[2].AddChangeHook(OnDifficultyChanged);
	g_cvDiffFac[3].AddChangeHook(OnDifficultyChanged);
	g_cvBaseFac.AddChangeHook(OnDifficultyChanged);
	g_cvNextDiff.AddChangeHook(OnDifficultyChanged);
	
	LoadTranslations("l4d2sf_dmgscale.phrases.txt");
	
	g_iSlotSurvival = L4D2SF_RegSlot("survival");
	L4D2SF_RegPerk(g_iSlotSurvival, "inscale", g_iMaxLevel, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotSurvival, "outscale", g_iMaxLevel + 1, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
}

float g_fScaleOut[4], g_fScaleIn[3];

public void OnDifficultyChanged(ConVar cvar, const char[] ov, const char[] nv)
{
	char diff[16];
	g_cvDiff.GetString(diff, sizeof(diff));
	
	int diffVal = 0;
	if(!strcmp(nv, "easy", false))
		diffVal = 0;
	else if(!strcmp(nv, "normal", false))
		diffVal = 1;
	else if(!strcmp(nv, "hard", false))
		diffVal = 2;
	else if(!strcmp(nv, "impossible", false))
		diffVal = 3;
	
	if(g_cvNextDiff.BoolValue)
		diffVal += 1;
	
	diffVal = IntBound(diffVal, 0, 3);
	float mul = FloatBound(g_cvBaseFac.FloatValue, 0.1, 1.0);
	float base[4];
	for(int i = 0; i < 4; ++i)
		base[i] = g_cvDiffFac[i].FloatValue;
	
	g_fScaleOut[0] = 1.0 / mul;
	g_fScaleOut[1] = 1.0 / mul;
	g_fScaleOut[2] = 1.0 / mul;
	g_fScaleOut[3] = 1.0 / mul;
	g_fScaleIn[0] = 1.0;
	g_fScaleIn[1] = 1.0;
	g_fScaleIn[2] = 1.0;
	
	switch(diffVal)
	{
		case 1:
		{
			// 普通到简单
			g_fScaleOut[3] = 1.0 / mul / base[1] * base[0];
			g_fScaleIn[2] = 0.5;
		}
		case 2:
		{
			// 困难到简单
			g_fScaleOut[3] = 1.0 / mul / base[2] * base[0];
			g_fScaleIn[2] = 0.2;
			
			// 困难到普通
			g_fScaleOut[2] = 1.0 / mul / base[2];
			g_fScaleIn[1] = 0.4;
		}
		case 3:
		{
			// 专家到简单
			g_fScaleOut[3] = 1.0 / mul / base[3] * base[0];
			g_fScaleIn[2] = 0.05;
			
			// 专家到普通
			g_fScaleOut[2] = 1.0 / mul / base[3];
			g_fScaleIn[1] = 0.1;
			
			// 专家到困难
			g_fScaleOut[1] = 1.0 / mul / base[3] * base[2];
			g_fScaleIn[0] = 0.25;
		}
	}
}

public Action L4D2SF_OnGetPerkName(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "inscale"))
		FormatEx(result, maxlen, "%T", "受伤修正", client, level);
	else if(!strcmp(name, "outscale"))
		FormatEx(result, maxlen, "%T", "伤害修正", client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public Action L4D2SF_OnGetPerkDescription(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "inscale"))
	{
		level = IntBound(level, 1, 3);
		FormatEx(result, maxlen, "%T", tr("受伤修正%d", level), client, level, 100 - g_fScaleIn[level - 1] * 100);
	}
	else if(!strcmp(name, "outscale"))
	{
		level = IntBound(level, 1, 4);
		FormatEx(result, maxlen, "%T", tr("伤害修正%d", level), client, level, g_fScaleOut[level - 1] * 100 - 100);
	}
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public void L4D2SF_OnPerkPost(int client, int level, const char[] perk)
{
	if(!strcmp(perk, "inscale"))
		g_iLevelInScale[client] = level;
	else if(!strcmp(perk, "outscale"))
		g_iLevelOutScale[client] = level;
}

public void L4D2SF_OnLoad(int client)
{
	g_iLevelInScale[client] = L4D2SF_GetClientPerk(client, "inscale");
	g_iLevelOutScale[client] = L4D2SF_GetClientPerk(client, "outscale");
}

public void Event_PlayerSpawn(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	g_iLevelInScale[client] = L4D2SF_GetClientPerk(client, "inscale");
	g_iLevelOutScale[client] = L4D2SF_GetClientPerk(client, "outscale");
	
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
	
	if(teamVictim == 2 && teamAttacker == 3 && IsValidClient(victim))
	{
		// 生还者被感染者攻击(特感+普感+萌妹)
		if(g_iLevelInScale[victim] > 0)
		{
			damage *= g_fScaleIn[g_iLevelInScale[victim] - 1];
			return Plugin_Changed;
		}
	}
	else if(teamAttacker == 2 && teamVictim == 3 && victim > MaxClients && IsValidClient(attacker))
	{
		// 生还者攻击普感(普感+萌妹)
		if(g_iLevelOutScale[attacker] > 0)
		{
			damage *= g_fScaleOut[g_iLevelInScale[attacker] - 1];
			return Plugin_Changed;
		}
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

float FloatBound(float v, float min, float max)
{
	if(v < min)
		v = min;
	if(v > max)
		v = max;
	return v;
}
