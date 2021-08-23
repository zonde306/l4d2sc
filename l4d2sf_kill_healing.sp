#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2_skill_framework>

#define PLUGIN_VERSION			"0.0.1"
#include "modules/l4d2ps.sp"

public Plugin myinfo =
{
	name = "技能：击杀回血",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/",
};

int g_iSlotHealing;
int g_iLevelHeadshot[MAXPLAYERS+1], g_iLevelMelee[MAXPLAYERS+1];

ConVar g_cvHeadshotAmount, g_cvMeleeAmount, g_cvHeadshotTemp, g_cvMeleeTemp, g_cvHeadshotLimit, g_cvMeleeLimit,
	g_cvHeadshotCommon, g_cvMeleeCommon, g_cvHeadshotConv, g_cvMeleeConv, g_cvHeadshotOverflow, g_cvMeleeOverflow;

public OnPluginStart()
{
	g_cvHeadshotAmount = CreateConVar("l4d2sf_headshot_amount", "5", "爆头回血量", CVAR_FLAGS, true, 0.0, true, 100.0);
	g_cvMeleeAmount = CreateConVar("l4d2sf_melee_amount", "10", "近战回血量", CVAR_FLAGS, true, 0.0, true, 100.0);
	g_cvHeadshotTemp = CreateConVar("l4d2sf_headshot_temp", "1", "爆头回复临时生命值", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_cvMeleeTemp = CreateConVar("l4d2sf_melee_temp", "1", "近战回复临时生命值", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_cvHeadshotLimit = CreateConVar("l4d2sf_headshot_limit", "20", "爆头回血上限", CVAR_FLAGS, true, 0.0, true, 100.0);
	g_cvMeleeLimit = CreateConVar("l4d2sf_melee_limit", "40", "近战回血上限", CVAR_FLAGS, true, 0.0, true, 100.0);
	g_cvHeadshotCommon = CreateConVar("l4d2sf_headshot_common", "99", "爆头回复允许对普感生效的最小等级", CVAR_FLAGS, true, 0.0, true, 99.0);
	g_cvMeleeCommon = CreateConVar("l4d2sf_melee_common", "99", "近战回复允许对普感生效的最小等级", CVAR_FLAGS, true, 0.0, true, 99.0);
	g_cvHeadshotConv = CreateConVar("l4d2sf_headshot_conv", "2", "爆头回复允许转换的最小等级", CVAR_FLAGS, true, 0.0, true, 99.0);
	g_cvMeleeConv = CreateConVar("l4d2sf_melee_conv", "2", "近战回复允许转换的最小等级", CVAR_FLAGS, true, 0.0, true, 99.0);
	g_cvHeadshotOverflow = CreateConVar("l4d2sf_headshot_overflow", "5", "爆头回血溢出量", CVAR_FLAGS, true, 0.0, true, 100.0);
	g_cvMeleeOverflow = CreateConVar("l4d2sf_melee_overflow", "10", "近战回血溢出量", CVAR_FLAGS, true, 0.0, true, 100.0);
	AutoExecConfig(true, "l4d2sf_kill_healing");
	
	LoadTranslations("l4d2sf_headshot_healing.phrases.txt");
	
	g_iSlotHealing = L4D2SF_RegSlot("healing");
	L4D2SF_RegPerk(g_iSlotHealing, "headshot_healing", 1, 45, 5, 1.0);
	L4D2SF_RegPerk(g_iSlotHealing, "melee_healing", 1, 30, 5, 1.0);
	
	CvarHook_UpdateCache(null, "", "");
	g_cvHeadshotAmount.AddChangeHook(CvarHook_UpdateCache);
	g_cvMeleeAmount.AddChangeHook(CvarHook_UpdateCache);
	g_cvHeadshotTemp.AddChangeHook(CvarHook_UpdateCache);
	g_cvMeleeTemp.AddChangeHook(CvarHook_UpdateCache);
	g_cvMeleeTemp.AddChangeHook(CvarHook_UpdateCache);
	g_cvHeadshotLimit.AddChangeHook(CvarHook_UpdateCache);
	g_cvMeleeLimit.AddChangeHook(CvarHook_UpdateCache);
	g_cvHeadshotCommon.AddChangeHook(CvarHook_UpdateCache);
	g_cvHeadshotConv.AddChangeHook(CvarHook_UpdateCache);
	g_cvMeleeConv.AddChangeHook(CvarHook_UpdateCache);
	g_cvHeadshotOverflow.AddChangeHook(CvarHook_UpdateCache);
	g_cvMeleeOverflow.AddChangeHook(CvarHook_UpdateCache);
	
	HookEvent("player_death", Event_PlayerDeath);
	// HookEvent("infected_death", Event_InfectedDeath);
}

int g_iHeadAmount, g_iMeleeAmount, g_iHeadMax, g_iMeleeMax, g_iHeadCI, g_iMeleeCI, g_iHeadConv, g_iMeleeConv, g_iHeadOverflow, g_iMeleeOverflow;
float g_fHeadTemp, g_fMeleeTemp;

public Action L4D2SF_OnGetPerkName(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "headshot_healing"))
		FormatEx(result, maxlen, "%T", "爆头回血", client, level);
	else if(!strcmp(name, "melee_healing"))
		FormatEx(result, maxlen, "%T", "近战回血", client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public Action L4D2SF_OnGetPerkDescription(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "headshot_healing"))
		FormatEx(result, maxlen, "%T", tr("爆头回血%d", IntBound(level, 1, 1)), client, level, g_iHeadAmount * level, MaxHealthBound(client, g_iHeadMax * level, g_iHeadOverflow * level));
	if(!strcmp(name, "melee_healing"))
		FormatEx(result, maxlen, "%T", tr("近战回血%d", IntBound(level, 1, 1)), client, level, g_iMeleeAmount * level, MaxHealthBound(client, g_iMeleeMax * level, g_iMeleeOverflow * level));
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public void L4D2SF_OnPerkPost(int client, int level, const char[] perk)
{
	if(!strcmp(perk, "headshot_healing"))
		g_iLevelHeadshot[client] = level;
	else if(!strcmp(perk, "melee_healing"))
		g_iLevelMelee[client] = level;
}

public void L4D2SF_OnLoad(int client)
{
	g_iLevelHeadshot[client] = L4D2SF_GetClientPerk(client, "headshot_healing");
	g_iLevelMelee[client] = L4D2SF_GetClientPerk(client, "melee_healing");
}

int IntBound(int v, int min, int max)
{
	if(v < min)
		v = min;
	if(v > max)
		v = max;
	return v;
}

public void CvarHook_UpdateCache(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	g_iHeadAmount = g_cvHeadshotAmount.IntValue;
	g_iMeleeAmount = g_cvMeleeAmount.IntValue;
	g_fHeadTemp = g_cvHeadshotTemp.FloatValue;
	g_fMeleeTemp = g_cvMeleeTemp.FloatValue;
	g_iHeadMax = g_cvHeadshotLimit.IntValue;
	g_iMeleeMax = g_cvMeleeLimit.IntValue;
	g_iHeadCI = g_cvHeadshotCommon.IntValue;
	g_iMeleeCI = g_cvMeleeCommon.IntValue;
	g_iHeadConv = g_cvHeadshotConv.IntValue;
	g_iMeleeConv = g_cvMeleeConv.IntValue;
	g_iHeadOverflow = g_cvHeadshotOverflow.IntValue;
	g_iMeleeOverflow = g_cvMeleeOverflow.IntValue;
}

public void Event_PlayerDeath(Event event, const char[] eventName, bool dontBoardcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if(!IsValidAliveClient(attacker))
		return;
	
	int team = GetClientTeam(attacker);
	int victim = GetClientOfUserId(event.GetInt("userid"));
	bool headshot = event.GetBool("headshot");
	
	static char weapon[64];
	event.GetString("weapon", weapon, sizeof(weapon));
	bool melee = !strcmp(weapon, "melee", false);
	
	if(IsValidClient(victim))
	{
		if(team == GetClientTeam(victim))
			return;
		
		if(melee && g_iLevelMelee[attacker] > 0)
			HandleMelee(attacker);
		if(headshot && g_iLevelHeadshot[attacker] > 0)
			HandleHeadshot(attacker);
	}
	else if(GetClientTeam(attacker) == 2)
	{
		victim = event.GetInt("entityid");
		if(victim <= MaxClients || !IsValidEntity(victim))
			return;
		
		GetEdictClassname(victim, weapon, sizeof(weapon));
		if(!strcmp(weapon, "witch", false))
		{
			if(melee && g_iLevelMelee[attacker] > 0)
				HandleMelee(attacker);
			if(headshot && g_iLevelHeadshot[attacker] > 0)
				HandleHeadshot(attacker);
		}
		else if(!strcmp(weapon, "infected", false))
		{
			if(melee && g_iLevelMelee[attacker] >= g_iMeleeCI)
				HandleMelee(attacker);
			if(headshot && g_iLevelHeadshot[attacker] > g_iHeadCI)
				HandleHeadshot(attacker);
		}
	}
}

int MaxHealthBound(int client, int max, int overflow)
{
	int maxHealth = GetEntProp(client, Prop_Data, "m_iMaxHealth");
	if(max > maxHealth) max = maxHealth;
	if(max < 0) max = 0;
	if(overflow < 0) overflow = 0;
	if(max < maxHealth) overflow = 0;
	return max + overflow;
}

void HandleHeadshot(int client)
{
	int level = g_iLevelHeadshot[client];
	int max = MaxHealthBound(client, g_iHeadMax * level, g_iHeadOverflow * level);
	AddHealth(client, g_iHeadAmount * level, true, level >= g_iHeadConv, max);
}

void HandleMelee(int client)
{
	int level = g_iLevelMelee[client];
	int max = MaxHealthBound(client, g_iMeleeMax * level, g_iMeleeOverflow * level);
	AddHealth(client, g_iMeleeAmount * level, true, level >= g_iMeleeConv, max);
}

bool AddHealth(int client, int amount, bool limit = true, bool conv = false, int max = 0)
{
	if(!IsValidAliveClient(client))
		return false;
	
	int team = GetClientTeam(client);
	int health = GetEntProp(client, Prop_Data, "m_iHealth");
	int maxHealth = (max > 0 ? max : GetEntProp(client, Prop_Data, "m_iMaxHealth"));
	
	int oldHealth = health;
	if(team == 2 && !GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) && !GetEntProp(client, Prop_Send, "m_isHangingFromLedge", 1))
	{
		float buffer = GetPlayerTempHealth(client) * 1.0;
		float oldBuffer = buffer;
		
		buffer += amount;
		
		if(conv)
		{
			int cv = (health + RoundToZero(buffer)) - maxHealth;
			if(cv > 0)
			{
				if(cv > buffer)
					cv = RoundToZero(buffer);
				
				buffer -= cv;
				health += cv;
			}
		}
		
		if(limit)
		{
			if(health + RoundToZero(buffer) > maxHealth)
				buffer = float(maxHealth - health);
			if(health > maxHealth)
				health = maxHealth;
			if(buffer < 0.0)
				buffer = 0.0;
		}
		
		// 确定是否真的有效增加或有效减少
		if((amount > 0 && (health > oldHealth || buffer > oldBuffer)) || (amount < 0 && (oldHealth > health || oldBuffer > buffer)))
		{
			/*
			if(buffer > 200.0)
			{
				ConVar painPillsDecayCvar;
				if (painPillsDecayCvar == null)
					painPillsDecayCvar = FindConVar("pain_pills_decay_rate");
				
				// 通过时间来扩展上限
				float time = (200.0 - buffer) / painPillsDecayCvar.FloatValue;
				SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 200.0);
				SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime() + time);
			}
			else
			*/
			{
				SetEntPropFloat(client, Prop_Send, "m_healthBuffer", buffer);
				SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
			}
		}
	}
	else/* if(team == 3)*/
	{
		health += amount;
		if(limit)
		{
			if(health > maxHealth)
				health = maxHealth;
		}
	}
	
	// 确定是否真的有效增加或有效减少
	if((amount > 0 && health > oldHealth) || (amount < 0 && oldHealth > health))
		SetEntProp(client, Prop_Data, "m_iHealth", health);
	
	return true;
}

int GetPlayerTempHealth(int client)
{
	if(GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) || GetEntProp(client, Prop_Send, "m_isHangingFromLedge", 1))
		return 0;
	
	ConVar painPillsDecayCvar;
	if (painPillsDecayCvar == null)
		painPillsDecayCvar = FindConVar("pain_pills_decay_rate");
	
	int tempHealth = RoundToCeil(
		GetEntPropFloat(client, Prop_Send, "m_healthBuffer") -
		((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) *
		painPillsDecayCvar.FloatValue)) - 1;
	
	return tempHealth < 0 ? 0 : tempHealth;
}
