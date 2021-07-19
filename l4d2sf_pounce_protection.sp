#pragma semicolon 1
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <l4d2_skill_framework>
#include <left4dhooks>
#include "modules/l4d2ps.sp"

#define PLUGIN_VERSION "1.2"
#define PLUGIN_AUTHOR "dcx2, cravenge"
#define PLUGIN_NAME "防抢控"

new Handle:ppEnable = INVALID_HANDLE;
new Handle:ppSmokerDamage = INVALID_HANDLE;
new Handle:ppSmokerDamageIncap = INVALID_HANDLE;

new g_ProtectPin[MAXPLAYERS+1] = 0;

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
	CreateConVar("pounce_protection_version", PLUGIN_VERSION, "Pounce Protection Version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	ppEnable = CreateConVar("pounce_protection_enable", "1", "Enable/Disable Plugin", FCVAR_NOTIFY);
	ppSmokerDamage = CreateConVar("pounce_protection_smoker_damage", "10.0", "Damage Dealt To Smoker Protected Victims", FCVAR_NOTIFY);
	ppSmokerDamageIncap = CreateConVar("pounce_protection_smoker_damage_incap", "20.0", "Damage Dealt To Smoker Protected Incapacitated Victims", FCVAR_NOTIFY);
	
	HookEvent("tongue_grab", OnEnableProtection);
	HookEvent("jockey_ride", OnEnableProtection);
	HookEvent("tongue_release", OnDisableProtection);
	HookEvent("jockey_ride_end", OnDisableProtection);
	HookEvent("player_bot_replace", OnProtectionCheck);
	HookEvent("bot_player_replace", OnProtectionCheck);
	
	LoadTranslations("l4d2sf_pounce_protection.phrases.txt");
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_first_spawn", Event_PlayerSpawn);
	
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

public void Event_PlayerSpawn(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	g_iLevelProtection[client] = L4D2SF_GetClientPerk(client, "trap_protect");
}

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

public Action L4D2_OnStagger(int target, int source)
{
	if(!IsValidClient(target) || g_iLevelProtection[target] < 2)
		return Plugin_Continue;
	
	if(IsValidClient(source) && GetClientTeam(source) == 2)
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
