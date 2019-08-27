#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma semicolon 1

#define L4D2 Nightmarish Common
#define PLUGIN_VERSION "1.1"
#define DEBUG 0

new Handle:cvarNightmareChance;

new Handle:cvarType1Size;
new Handle:cvarType1HPMin;
new Handle:cvarType1HPMax;
new Handle:cvarType1SpeedMin;
new Handle:cvarType1SpeedMax;
new Handle:cvarType1Damage;
new Handle:cvarType1Armor;

new Handle:cvarType2Size;
new Handle:cvarType2HPMin;
new Handle:cvarType2HPMax;
new Handle:cvarType2SpeedMin;
new Handle:cvarType2SpeedMax;
new Handle:cvarType2Damage;
new Handle:cvarType2Armor;

new Handle:cvarType3Size;
new Handle:cvarType3HPMin;
new Handle:cvarType3HPMax;
new Handle:cvarType3SpeedMin;
new Handle:cvarType3SpeedMax;
new Handle:cvarType3Damage;
new Handle:cvarType3Armor;

new Handle:cvarType4Size;
new Handle:cvarType4HPMin;
new Handle:cvarType4HPMax;
new Handle:cvarType4SpeedMin;
new Handle:cvarType4SpeedMax;
new Handle:cvarType4Damage;
new Handle:cvarType4Armor;

new CommonType[4097];
new bool:isMapRunning = false;
new Handle:PluginStartTimer = INVALID_HANDLE;

new laggedMovementOffset = 0;

public Plugin:myinfo = 
{
    name = "[L4D2] Nightmarish Common",
    author = "Mortiegama",
    description = "Empowering the lowest of the infected to make sure that hordes become your worst nightmare.",
    version = PLUGIN_VERSION,
    url = ""
}

	//AtomicStryker - Damage Mod (SDK Hooks):
	//https://forums.alliedmods.net/showthread.php?p=1184761
	
	//Bacardi - Cleaning up code:
	//https://forums.alliedmods.net/showpost.php?p=2128853&postcount=4
	
	
public OnPluginStart()
{
	CreateConVar("l4d_ncm_version", PLUGIN_VERSION, "Nightmarish Common Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

	cvarNightmareChance = CreateConVar("l4d_ncm_nightmarechance", "90", "Chance that the common infected will be turned into Nightmares. (Def 90)", FCVAR_PLUGIN, true, 0.0, false, _);

	cvarType1Size= CreateConVar("l4d_ncm_type1size", "0.7", "Type 1: Size of common. (Def 0.7)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarType1HPMin= CreateConVar("l4d_ncm_type1hpmin", "20", "Type 1: Minimum HP for the Common. (Def 20)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarType1HPMax= CreateConVar("l4d_ncm_type1hpmax", "40", "Type 1: Maximum HP for the Common. (Def 40)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarType1SpeedMin= CreateConVar("l4d_ncm_type1speedmin", "1.5", "Type 1: Minimum speed adjustment for the Common. (Def 1.5)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarType1SpeedMax= CreateConVar("l4d_ncm_type1speedmax", "1.8", "Type 1: Maximum speed adjustment for the Common. (Def 1.8)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarType1Damage= CreateConVar("l4d_ncm_type1damage", "1.5", "Type 1: Multiplier for damage done to the Survivors (Def 1.5)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarType1Armor= CreateConVar("l4d_ncm_type1armor", "1.8", "Type 1: Multiplier for damage done by the Survivors. (Def 1.2)", FCVAR_PLUGIN, true, 0.0, false, _);

	cvarType2Size= CreateConVar("l4d_ncm_type1size", "0.9", "Type 2: Size of zombie. (Def 0.9)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarType2HPMin= CreateConVar("l4d_ncm_type2hpmin", "65", "Type 2: Minimum HP for the Common. (Def 65)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarType2HPMax= CreateConVar("l4d_ncm_type2hpmax", "85", "Type 2: Maximum HP for the Common. (Def 85)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarType2SpeedMin= CreateConVar("l4d_ncm_type2speedmin", "1.2", "Type 2: Minimum speed adjustment for the Common. (Def 1.2)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarType2SpeedMax= CreateConVar("l4d_ncm_type2speedmax", "1.6", "Type 2: Maximum speed adjustment for the Common. (Def 1.6)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarType2Damage= CreateConVar("l4d_ncm_type2damage", "0.8", "Type 2: Multiplier for damage done to the Survivors (Def 0.8)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarType2Armor= CreateConVar("l4d_ncm_type2armor", "0.7", "Type 2: Multiplier for damage done by the Survivors. (Def 0.7)", FCVAR_PLUGIN, true, 0.0, false, _);

	cvarType3Size= CreateConVar("l4d_ncm_type3size", "1.1", "Type 3: Size of zombie. (Def 1.1)", FCVAR_PLUGIN, true, 0.0, false, _);	
	cvarType3HPMin= CreateConVar("l4d_ncm_type3hpmin", "30", "Type 3: Minimum HP for the Common. (Def 30)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarType3HPMax= CreateConVar("l4d_ncm_type3hpmax", "60", "Type 3: Maximum HP for the Common. (Def 60)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarType3SpeedMin= CreateConVar("l4d_ncm_type3speedmin", "1.1", "Type 3: Minimum speed adjustment for the Common. (Def 1.1)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarType3SpeedMax= CreateConVar("l4d_ncm_type3speedmax", "1.5", "Type 3: Maximum speed adjustment for the Common. (Def 1.5)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarType3Damage= CreateConVar("l4d_ncm_type3damage", "1.3", "Type 3: Multiplier for damage done to the Survivors (Def 1.3)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarType3Armor= CreateConVar("l4d_ncm_type3armor", "1.1", "Type 3: Multiplier for damage done by the Survivors. (Def 1.1)", FCVAR_PLUGIN, true, 0.0, false, _);

	cvarType4Size= CreateConVar("l4d_ncm_type4size", "1.2", "Type 4: Size of zombie. (Def 1.2)", FCVAR_PLUGIN, true, 0.0, false, _);	
	cvarType4HPMin= CreateConVar("l4d_ncm_type4hpmin", "80", "Type 4: Minimum HP for the Common. (Def 80)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarType4HPMax= CreateConVar("l4d_ncm_type4hpmax", "110", "Type 4: Maximum HP for the Common. (Def 110)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarType4SpeedMin= CreateConVar("l4d_ncm_type4speedmin", "0.4", "Type 4: Minimum speed adjustment for the Common. (Def 0.4)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarType4SpeedMax= CreateConVar("l4d_ncm_type4speedmax", "0.7", "Type 4: Maximum speed adjustment for the Common. (Def 0.7)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarType4Damage= CreateConVar("l4d_ncm_type4damage", "0.6", "Type 4: Multiplier for damage done to the Survivors (Def 0.6)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarType4Armor= CreateConVar("l4d_ncm_type4armor", "0.5", "Type 4: Multiplier for damage done by the Survivors. (Def 0.5)", FCVAR_PLUGIN, true, 0.0, false, _);

	AutoExecConfig(true, "plugin.L4D2.NightmarishCommon");
	PluginStartTimer = CreateTimer(3.0, OnPluginStart_Delayed);
}

public Action:OnPluginStart_Delayed(Handle:timer)
{	

	if(PluginStartTimer != INVALID_HANDLE)
	{
 		KillTimer(PluginStartTimer);
		PluginStartTimer = INVALID_HANDLE;
	}
	
	return Plugin_Stop;
}

public OnMapStart()
{
	isMapRunning = true;
}

public OnClientPostAdminCheck(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage_Survivor);
}

public OnEntityCreated(entity, const String:classname[])
{
	if (!isMapRunning || IsServerProcessing() == false) return;

	if (StrEqual(classname, "infected", false))
	{
		CreateTimer(0.5, Timer_CommonSpawn, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:Timer_CommonSpawn(Handle:timer, any:ref)
{
	new entity = EntRefToEntIndex(ref);

	if(entity == INVALID_ENT_REFERENCE || !IsValidEntity(entity) || !IsValidEdict(entity))
	{
		return Plugin_Stop;
	}

	new NightmareChance = GetRandomInt(0, 99);
	new NightmarePercent = (GetConVarInt(cvarNightmareChance));
	
	if (NightmareChance < NightmarePercent)
	{
		new integer = GetRandomInt(1, 4); 

		#if DEBUG
		PrintToChatAll("Entity is a common infected, type %i.", integer);
		#endif

		new iHP;
		new Float:iSpeed;
		new Float:iScale;

		switch (integer)
		{
			case 1:
			{
				#if DEBUG
				PrintToChatAll("Zombie type small strong fast low.");
				#endif

				iHP = GetRandomInt(GetConVarInt(cvarType1HPMin), GetConVarInt(cvarType1HPMax));
				iSpeed = GetRandomFloat(GetConVarFloat(cvarType1SpeedMin), GetConVarFloat(cvarType1SpeedMax));
				iScale = GetConVarFloat(cvarType1Size);
				CommonType[entity] = 1;
			}

			case 2:
			{
				#if DEBUG
				PrintToChatAll("Zombie type small weak quick sturdy.");
				#endif

				iHP = GetRandomInt(GetConVarInt(cvarType2HPMin), GetConVarInt(cvarType2HPMax));
				iSpeed = GetRandomFloat(GetConVarFloat(cvarType2SpeedMin), GetConVarFloat(cvarType2SpeedMax));
				iScale = GetConVarFloat(cvarType2Size);
				CommonType[entity] = 2;
			}

			case 3:
			{
				#if DEBUG
				PrintToChatAll("Zombie type big tough quick weak.");
				#endif

				iHP = GetRandomInt(GetConVarInt(cvarType3HPMin), GetConVarInt(cvarType3HPMax));
				iSpeed = GetRandomFloat(GetConVarFloat(cvarType3SpeedMin), GetConVarFloat(cvarType3SpeedMax));
				iScale = GetConVarFloat(cvarType3Size);
				CommonType[entity] = 3;
			}

			case 4:
			{
				#if DEBUG
				PrintToChatAll("Zombie type large titanic slow titanic.");
				#endif

				iHP = GetRandomInt(GetConVarInt(cvarType4HPMin), GetConVarInt(cvarType4HPMax));
				iSpeed = GetRandomFloat(GetConVarFloat(cvarType4SpeedMin), GetConVarFloat(cvarType4SpeedMax));
				iScale = GetConVarFloat(cvarType4Size);
				CommonType[entity] = 4;
			}
		}

		SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage_Infected);
		SetEntPropFloat(entity, Prop_Send, "m_flModelScale", iScale);
		SetEntProp(entity, Prop_Data, "m_iMaxHealth", iHP);//Set max and 
		SetEntProp(entity, Prop_Data, "m_iHealth", iHP); //current health of witch to defined health.
		AcceptEntityInput(entity, "Disable"); 
		SetEntPropFloat(entity, Prop_Data, "m_flSpeed", 1.0*iSpeed);
		AcceptEntityInput(entity, "Enable");
	}
	
	return Plugin_Continue;
}  

public Action:OnTakeDamage_Infected(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if (!isMapRunning || IsServerProcessing() == false) return Plugin_Stop;
	
	if (IsValidCommon(victim))
	{
		switch (CommonType[victim])
		{
			case 1:
			{
				new Float:damagemod = GetConVarFloat(cvarType1Armor);
				
				#if DEBUG
				PrintToChatAll("Damage Caught: %f damage times %f mod.", damage, damagemod);
				#endif
			
				if (FloatCompare(damagemod, 1.0) != 0)
				{
					damage = damage * damagemod;
				}
			}
			
			case 2:
			{
				new Float:damagemod = GetConVarFloat(cvarType2Armor);

				#if DEBUG
				PrintToChatAll("Damage Caught: %f damage times %f mod.", damage, damagemod);
				#endif
			
			if (FloatCompare(damagemod, 1.0) != 0)
			{
					damage = damage * damagemod;
				}
			}
			
			case 3:
			{
				new Float:damagemod = GetConVarFloat(cvarType3Armor);

				#if DEBUG
				PrintToChatAll("Damage Caught: %f damage times %f mod.", damage, damagemod);
				#endif
			
				if (FloatCompare(damagemod, 1.0) != 0)
				{
					damage = damage * damagemod;
				}
			}
			
			case 4:
			{
				new Float:damagemod = GetConVarFloat(cvarType4Armor);

				#if DEBUG
				PrintToChatAll("Damage Caught: %f damage times %f mod.", damage, damagemod);
				#endif
				
				if (FloatCompare(damagemod, 1.0) != 0)
				{
					damage = damage * damagemod;
				}
			}
		}
	}
	
	return Plugin_Changed;
}

public Action:OnTakeDamage_Survivor(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if (!isMapRunning || IsServerProcessing() == false) return Plugin_Stop;
	
	if (IsValidCommon(attacker))
	{
		if (IsValidClient(victim) && GetClientTeam(victim) == 2)
		{
				switch (CommonType[attacker])
				{
					case 1:
					{
						new Float:damagemod = GetConVarFloat(cvarType1Damage);
					
						#if DEBUG
						PrintToChatAll("Survivor damage Caught: %f damage times %f mod.", damage, damagemod);
						#endif
					
						if (FloatCompare(damagemod, 1.0) != 0)
						{
							damage = damage * damagemod;
						}
					}
				
					case 2:
					{
						new Float:damagemod = GetConVarFloat(cvarType2Damage);
			
						#if DEBUG
						PrintToChatAll("Survivor damage Caught: %f damage times %f mod.", damage, damagemod);
						#endif
					
						if (FloatCompare(damagemod, 1.0) != 0)
						{
							damage = damage * damagemod;
						}
					}
					
					case 3:
					{
						new Float:damagemod = GetConVarFloat(cvarType3Damage);

						#if DEBUG
						PrintToChatAll("Survivor damage Caught: %f damage times %f mod.", damage, damagemod);
						#endif
					
						if (FloatCompare(damagemod, 1.0) != 0)
						{
							damage = damage * damagemod;
						}
					}
					
					case 4:
					{
						new Float:damagemod = GetConVarFloat(cvarType4Damage);

						#if DEBUG
						PrintToChatAll("Survivor damage Caught: %f damage times %f mod.", damage, damagemod);
						#endif
						
						if (FloatCompare(damagemod, 1.0) != 0)
						{
							damage = damage * damagemod;
						}
					}
				}
			
		}
	}
	
	return Plugin_Changed;
}

public OnMapEnd()
{
	isMapRunning = false;
}

IsValidCommon(common)
{
	if(common > MaxClients && IsValidEdict(common) && IsValidEntity(common))
	{
		decl String:classname[32];
		GetEdictClassname(common, classname, sizeof(classname));
		if(StrEqual(classname, "infected"))
		{
			return true;
		}
	}
	
	return false;
}

public IsValidClient(client)
{
	if (client <= 0)
		return false;
		
	if (client > MaxClients)
		return false;
		
	if (!IsClientInGame(client))
		return false;
		
	if (!IsPlayerAlive(client))
		return false;

	return true;
}