#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2_skill_framework>

#define PLUGIN_VERSION			"0.0.1"
#include "modules/l4d2ps.sp"

public Plugin myinfo =
{
	name = "技能：临时血量转换",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/",
};

int g_iSlotHealing;
int g_iLevelTemp[MAXPLAYERS+1], g_iLevelConv[MAXPLAYERS+1];
ConVar g_cvHurtDelay, g_cvConvInterval;

public OnPluginStart()
{
	InitPlugin("sfth");
	g_cvHurtDelay = CreateConVar("l4d2_sfth_hurt_delay", "5.0", "受伤暂停时间", CVAR_FLAGS, true, 0.0);
	g_cvConvInterval = CreateConVar("l4d2_sfth_interval", "0.29", "转换间隔", CVAR_FLAGS, true, 0.0);
	AutoExecConfig(true, "l4d2_sfth");
	
	LoadTranslations("l4d2sf_temp_health.phrases.txt");
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_first_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("bot_player_replace", Event_PlayerReplaceBot);
	HookEvent("player_bot_replace", Event_BotReplacePlayer);
	HookEvent("player_incapacitated", Event_PlayerIncapacitated);
	HookEvent("revive_success", Event_ReviveSuccess);
	
	g_iSlotHealing = L4D2SF_RegSlot("healing");
	L4D2SF_RegPerk(g_iSlotHealing, "temp_damage", 5, 40, 5, 1.0);
	L4D2SF_RegPerk(g_iSlotHealing, "temp_conv", 5, 80, 5, 1.0);
}

public Action L4D2SF_OnGetPerkName(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "temp_damage"))
		FormatEx(result, maxlen, "%T", "虚血承担", client, level);
	else if(!strcmp(name, "temp_conv"))
		FormatEx(result, maxlen, "%T", "虚血转换", client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public Action L4D2SF_OnGetPerkDescription(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "temp_damage"))
		FormatEx(result, maxlen, "%T", tr("虚血承担%d", IntBound(level, 1, 1)), client, level);
	else if(!strcmp(name, "temp_conv"))
		FormatEx(result, maxlen, "%T", tr("虚血转换%d", IntBound(level, 1, 1)), client, level, g_cvHurtDelay.FloatValue);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public void L4D2SF_OnPerkPost(int client, int level, const char[] perk)
{
	if(!strcmp(perk, "temp_damage"))
		g_iLevelTemp[client] = level;
	else if(!strcmp(perk, "temp_conv"))
		g_iLevelConv[client] = level;
}

float g_fNextConv[MAXPLAYERS+1];
Handle g_hConvTimer[MAXPLAYERS+1];

public void Event_PlayerSpawn(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	g_iLevelTemp[client] = L4D2SF_GetClientPerk(client, "temp_damage");
	g_iLevelConv[client] = L4D2SF_GetClientPerk(client, "temp_conv");
	
	SDKHook(client, SDKHook_OnTakeDamageAlive, EntHook_OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamageAlivePost, EntHook_OnTakeDamagePost);
	
	if(g_hConvTimer[client] != null)
		KillTimer(g_hConvTimer[client]);
	g_hConvTimer[client] = CreateTimer(g_cvConvInterval.FloatValue, Timer_ConvHealth, client, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}

public void Event_PlayerDeath(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	SDKUnhook(client, SDKHook_OnTakeDamageAlive, EntHook_OnTakeDamage);
	SDKUnhook(client, SDKHook_OnTakeDamageAlivePost, EntHook_OnTakeDamagePost);
}

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int damage = event.GetInt("dmg_health");
	
	if(!IsValidClient(victim) || damage <= 0 || GetClientTeam(victim) != 2)
		return;
	
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if(!IsValidClient(attacker))
		attacker = event.GetInt("attackerentid");
	if(!IsValidEdict(attacker) || GetEntProp(attacker, Prop_Data, "m_iTeamNum") != 3)
		return;
	
	g_fNextConv[victim] = GetEngineTime() + g_cvHurtDelay.FloatValue;
}

public void Event_PlayerReplaceBot(Event event, const char[] eventName, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("player"));
	int bot = GetClientOfUserId(event.GetInt("bot"));
	
	if(g_hConvTimer[bot] != null)
	{
		KillTimer(g_hConvTimer[bot]);
		g_hConvTimer[bot] = null;
	}
	
	if(g_hConvTimer[player] != null)
		KillTimer(g_hConvTimer[player]);
	if(IsValidAliveClient(player) || IsValidAliveClient(bot))
		g_hConvTimer[player] = CreateTimer(g_cvConvInterval.FloatValue, Timer_ConvHealth, player, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}

public void Event_BotReplacePlayer(Event event, const char[] eventName, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("player"));
	int bot = GetClientOfUserId(event.GetInt("bot"));
	
	if(g_hConvTimer[player] != null)
	{
		KillTimer(g_hConvTimer[player]);
		g_hConvTimer[player] = null;
	}
	
	if(g_hConvTimer[bot] != null)
		KillTimer(g_hConvTimer[bot]);
	if(IsValidAliveClient(player) || IsValidAliveClient(bot))
		g_hConvTimer[bot] = CreateTimer(g_cvConvInterval.FloatValue, Timer_ConvHealth, bot, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}

public void Event_PlayerIncapacitated(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	if(g_hConvTimer[client] != null)
		KillTimer(g_hConvTimer[client]);
	g_hConvTimer[client] = null;
}

public void Event_ReviveSuccess(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("subject"));
	if(!IsValidClient(client))
		return;
	
	if(g_hConvTimer[client] != null)
		KillTimer(g_hConvTimer[client]);
	g_hConvTimer[client] = CreateTimer(g_cvConvInterval.FloatValue, Timer_ConvHealth, client, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	g_fNextConv[client] = GetEngineTime() + g_cvHurtDelay.FloatValue;
}

int g_iHealth[MAXPLAYERS+1], g_iBufferHealth[MAXPLAYERS+1];

public Action EntHook_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon,
	float damageForce[3], float damagePosition[3], int damagecustom)
{
	g_iHealth[victim] = GetEntProp(victim, Prop_Data, "m_iHealth");
	g_iBufferHealth[victim] = GetPlayerTempHealth(victim);
	return Plugin_Continue;
}

public void EntHook_OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon,
	const float damageForce[3], const float damagePosition[3], int damagecustom)
{
	if(g_iLevelTemp[victim] <= 0)
		return;
	
	int health = GetEntProp(victim, Prop_Data, "m_iHealth");
	int buffer = GetPlayerTempHealth(victim);
	
	int newHealth = g_iHealth[victim];
	int newBuffer = g_iBufferHealth[victim] - RoundToFloor(damage);
	
	if(newBuffer < 0)
	{
		newHealth += newBuffer;
		newBuffer = 0;
	}
	
	SetEntProp(victim, Prop_Data, "m_iHealth", newHealth);
	SetEntPropFloat(victim, Prop_Data, "m_healthBuffer", float(newBuffer));
	SetEntPropFloat(victim, Prop_Send, "m_healthBufferTime", GetGameTime());
}

public void OnMapEnd()
{
	for(int i = 1; i <= MaxClients; ++i)
	{
		g_hConvTimer[i] = null;
		g_fNextConv[i] = 0.0;
	}
}

public Action Timer_ConvHealth(Handle timer, any client)
{
	if(!IsValidAliveClient(client))
	{
		g_hConvTimer[client] = null;
		return Plugin_Stop;
	}
	
	if(g_fNextConv[client] > GetEngineTime())
		return Plugin_Continue;
	
	int buffer = GetPlayerTempHealth(client);
	if(buffer <= 0)
		return Plugin_Continue;
	
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", float(buffer - 1));
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
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
