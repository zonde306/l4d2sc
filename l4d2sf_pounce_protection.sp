#pragma semicolon 1
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <l4d2_skill_framework>
#include <left4dhooks>
#include <infected_ability_touch_hook>
#include "modules/l4d2ps.sp"

#define PLUGIN_VERSION "1.2"
#define PLUGIN_AUTHOR "dcx2, cravenge, zonde306"
#define PLUGIN_NAME "防抢控"

/*
new Handle:ppEnable = INVALID_HANDLE;
new Handle:ppSmokerDamage = INVALID_HANDLE;
new Handle:ppSmokerDamageIncap = INVALID_HANDLE;

new g_ProtectPin[MAXPLAYERS+1] = 0;
*/

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = "防止舌头和猴子被抢控",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?p=1973444"
};

int g_iSlotAbility;
int g_iLevelProtection[MAXPLAYERS+1];

public OnPluginStart()
{
	/*
	CreateConVar("pounce_protection_version", PLUGIN_VERSION, "Pounce Protection Version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	ppEnable = CreateConVar("pounce_protection_enable", "1", "Enable/Disable Plugin", FCVAR_NOTIFY);
	ppSmokerDamage = CreateConVar("pounce_protection_smoker_damage", "10.0", "Damage Dealt To Smoker Protected Victims", FCVAR_NOTIFY);
	ppSmokerDamageIncap = CreateConVar("pounce_protection_smoker_damage_incap", "20.0", "Damage Dealt To Smoker Protected Incapacitated Victims", FCVAR_NOTIFY);
	*/
	
	/*
	HookEvent("tongue_grab", OnEnableProtection);
	HookEvent("jockey_ride", OnEnableProtection);
	HookEvent("tongue_release", OnDisableProtection);
	HookEvent("jockey_ride_end", OnDisableProtection);
	HookEvent("player_bot_replace", OnProtectionCheck);
	HookEvent("bot_player_replace", OnProtectionCheck);
	*/
	
	LoadTranslations("l4d2sf_pounce_protection.phrases.txt");
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_first_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("bot_player_replace", Event_PlayerReplaceBot);
	HookEvent("player_bot_replace", Event_BotReplacePlayer);
	
	g_iSlotAbility = L4D2SF_RegSlot("ability");
	L4D2SF_RegPerk(g_iSlotAbility, "trap_protect", 2, 25, 5, 2.0);
}

public Action L4D2SF_OnGetPerkName(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "trap_protect"))
		FormatEx(result, maxlen, "%T", "防抢控", client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public Action L4D2SF_OnGetPerkDescription(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "trap_protect"))
		FormatEx(result, maxlen, "%T", tr("防抢控%d", IntBound(level, 1, 2)), client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public void L4D2SF_OnPerkPost(int client, int level, const char[] perk)
{
	if(!strcmp(perk, "trap_protect"))
		g_iLevelProtection[client] = level;
}

public void L4D2SF_OnLoad(int client)
{
	g_iLevelProtection[client] = L4D2SF_GetClientPerk(client, "trap_protect");
}

public void Event_PlayerSpawn(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	g_iLevelProtection[client] = L4D2SF_GetClientPerk(client, "trap_protect");
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

public void Event_PlayerReplaceBot(Event event, const char[] eventName, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("player"));
	int bot = GetClientOfUserId(event.GetInt("bot"));
	
	SDKUnhook(bot, SDKHook_OnTakeDamage, EntHook_OnTakeDamage);
	SDKHook(player, SDKHook_OnTakeDamage, EntHook_OnTakeDamage);
}

public void Event_BotReplacePlayer(Event event, const char[] eventName, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("player"));
	int bot = GetClientOfUserId(event.GetInt("bot"));
	
	SDKUnhook(player, SDKHook_OnTakeDamage, EntHook_OnTakeDamage);
	SDKHook(bot, SDKHook_OnTakeDamage, EntHook_OnTakeDamage);
}

/*
public OnClientPostAdminCheck(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, ProtectedDamageFix);
}

public Action:OnEnableProtection(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(ppEnable))
	{
		return Plugin_Continue;
	}
	
	new attacker = GetClientOfUserId(GetEventInt(event, "userid"));
	new victim = GetClientOfUserId(GetEventInt(event, "victim"));
	if (!attacker || !victim || g_iLevelProtection[attacker] <= 0)
	{
		return Plugin_Continue;
	}
	
	g_ProtectPin[attacker] = victim;
	SetEntPropEnt(victim, Prop_Send, "m_pounceAttacker", attacker);
	if (StrEqual(name, "jockey_ride"))
	{
		SetEntityMoveType(attacker, MOVETYPE_ISOMETRIC);
	}
	
	return Plugin_Continue;
}

public Action:OnDisableProtection(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(ppEnable))
	{
		return Plugin_Continue;
	}
	
	new attacker = GetClientOfUserId(GetEventInt(event, "userid"));
	new victim = GetClientOfUserId(GetEventInt(event, "victim"));
	if (!attacker || !victim)
	{
		return Plugin_Continue;
	}
	
	g_ProtectPin[attacker] = 0;
	SetEntPropEnt(victim, Prop_Send, "m_pounceAttacker", -1);
	SetEntPropEnt(attacker, Prop_Send, "m_pounceVictim", -1);
	if (StrEqual(name, "jockey_ride_end"))
	{
		SetEntityMoveType(attacker, MOVETYPE_CUSTOM);
	}
	
	return Plugin_Continue;
}

public Action:OnProtectionCheck(Handle:event, const String:name[], bool:dontBroadcast)
{
	new bot = GetClientOfUserId(GetEventInt(event, "bot"));
	if (GetActualAttacker(bot) == 0)
	{
		return Plugin_Continue;
	}
	
	g_ProtectPin[GetActualAttacker(bot)] = 0;
	SetEntPropEnt(bot, Prop_Send, "m_pounceAttacker", -1);
	SetEntPropEnt(GetActualAttacker(bot), Prop_Send, "m_pounceVictim", -1);
	
	new player = GetClientOfUserId(GetEventInt(event, "player"));
	if (player <= 0 || !IsClientInGame(player) || IsFakeClient(player))
	{
		return Plugin_Continue;
	}
	
	if (GetActualAttacker(player) == 0)
	{
		return Plugin_Continue;
	}
	
	g_ProtectPin[GetActualAttacker(player)] = 0;
	SetEntPropEnt(player, Prop_Send, "m_pounceAttacker", -1);
	SetEntPropEnt(GetActualAttacker(player), Prop_Send, "m_pounceVictim", -1);
}

public Action:ProtectedDamageFix(victim, &attacker, &inflictor, &Float:damage, &damageType, &weapon, Float:damageForce[3], Float:damagePosition[3])
{
	if (!GetConVarBool(ppEnable))
	{
		return Plugin_Continue;
	}
	
	if (!IsSurvivor(victim) || !IsInfected(attacker) || GetEntProp(attacker, Prop_Send, "m_zombieClass") != 1)
	{
		return Plugin_Continue;
	}
	
	damage = (IsIncapacitated(victim)) ? GetConVarFloat(ppSmokerDamageIncap) : GetConVarFloat(ppSmokerDamage);
	return Plugin_Changed;
}

GetActualAttacker(victim)
{
	new attacker = 0;
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && g_ProtectPin[i] == victim) 
		{
			attacker = i;
			break;
		}
	}
	
	return attacker;
}

stock bool:IsSurvivor(client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2);
}

stock bool:IsIncapacitated(client)
{
	if (GetEntProp(client, Prop_Send, "m_isIncapacitated", 1))
	{
		return true;
	}
	
	return false;
}

stock bool:IsInfected(client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3);
}
*/

public Action OnAbilityTouch(const char[] ability, int attacker, int& victim)
{
	if(!IsValidAliveClient(attacker) || !IsValidAliveClient(victim))
		return Plugin_Continue;
	
	// 酸液、呕吐不会导致掉控
	if(!strcmp(ability, "ability_spit") || !strcmp(ability, "ability_vomit"))
		return Plugin_Continue;
	
	int owner = GetCurrentAttacker(victim);
	if(!IsValidAliveClient(owner) || g_iLevelProtection[owner] < 1)
		return Plugin_Continue;
	
	return Plugin_Handled;
}

public Action L4D2_OnStagger(int target, int source)
{
	if(!IsValidAliveClient(target) || g_iLevelProtection[target] < 2)
		return Plugin_Continue;
	
	if(IsValidAliveClient(source) && GetClientTeam(source) == 2)
		return Plugin_Continue;
	
	int victim = GetCurrentVictim(target);
	if(!IsValidAliveClient(victim))
		return Plugin_Continue;
	
	return Plugin_Handled;
}

public Action EntHook_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damageType, int &weapon,
	float damageForce[3], float damagePosition[3], int damageCustom)
{
	if(!IsValidAliveClient(victim) || g_iLevelProtection[victim] < 2 || !IsValidAliveClient(attacker) ||
		GetClientTeam(victim) != 3 || GetClientTeam(attacker) != 3 || damage <= 0.0)
		return Plugin_Continue;
	
	return Plugin_Handled;
}

int IntBound(int v, int min, int max)
{
	if(v < min)
		v = min;
	if(v > max)
		v = max;
	return v;
}

stock int GetCurrentAttacker(int client)
{
	if(!IsValidAliveClient(client))
		return -1;
	
	int attacker = GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker");
	if(IsValidAliveClient(attacker))
		return attacker;
	
	attacker = GetEntPropEnt(client, Prop_Send, "m_pummelAttacker");
	if(IsValidAliveClient(attacker))
		return attacker;
	
	attacker = GetEntPropEnt(client, Prop_Send, "m_pounceAttacker");
	if(IsValidAliveClient(attacker))
		return attacker;
	
	attacker = GetEntPropEnt(client, Prop_Send, "m_tongueOwner");
	if(IsValidAliveClient(attacker))
		return attacker;
	
	attacker = GetEntPropEnt(client, Prop_Send, "m_carryAttacker");
	if(IsValidAliveClient(attacker))
		return attacker;
	
	return -1;
}

stock int GetCurrentVictim(int client)
{
	if(!IsValidAliveClient(client))
		return -1;
	
	int victim = GetEntPropEnt(client, Prop_Send, "m_jockeyVictim");
	if(IsValidAliveClient(victim))
		return victim;
	
	victim = GetEntPropEnt(client, Prop_Send, "m_pummelVictim");
	if(IsValidAliveClient(victim))
		return victim;
	
	victim = GetEntPropEnt(client, Prop_Send, "m_pounceVictim");
	if(IsValidAliveClient(victim))
		return victim;
	
	victim = GetEntPropEnt(client, Prop_Send, "m_tongueVictim");
	if(IsValidAliveClient(victim))
		return victim;
	
	victim = GetEntPropEnt(client, Prop_Send, "m_carryVictim");
	if(IsValidAliveClient(victim))
		return victim;
	
	return -1;
}
