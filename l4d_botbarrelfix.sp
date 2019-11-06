#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin:myinfo =
{
	name = "禁止机器人打爆油桶",
	author = "tRololo312312",
	description = "Prevents bots from exploding fuel barrels.",
	version = "1.0",
	url = "http://www.sourcemod.net/"
};

public OnEntityCreated(entity, const String:classname[])
{
	if(StrEqual(classname, "prop_fuel_barrel"))
	{
		if(IsValidEntity(entity))
		{
			SDKHook(entity, SDKHook_OnTakeDamage, FuelDamage);
		}
	}
}

public Action:FuelDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3])
{
	if(IsValidClient(attacker))
	{
		if(IsFakeClient(attacker) && GetClientTeam(attacker) == 2)
		{
			damage = 0.0;
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}

stock bool:IsValidClient(client)
{
	if(!(1 <= client <= MaxClients ) || !IsClientInGame(client)) 
		return false; 
	return true; 
}
